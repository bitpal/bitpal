defmodule BitPal.Backend.Flowee.Connection do
  @moduledoc """
  This is the low-level API to flowee.

  Allows connecting to a Flowee server and communicating with it. This module
  handles the packet-based API with Flowee, and handles serialization and
  deserialization of the binary format. The binary format essentially consists
  of a list of key-value tuples, where keys are integers with pre-defined
  meaning, and values are of any of a few supported data types (integers, strings
  binaries or floats).

  The responsibilities of this module ends where these tuples are to be interpreted
  as a higher-level data structure, with meanings specific to some part of Flowee.
  This is instead handled by the Protocol module.

  Call connect\3 to create a connection, then send\2 and recv\1 to send and receive
  messages.

  Messages are described by the RawMsg struct, and to distinguish between binaries
  and strings, binaries are wrapped in the Binary struct (since strings are binaries
  in Elixir).
  """

  use Bitwise
  alias BitPal.Backend.Flowee.Connection

  # Struct for the connection itself. Create using "connect".
  defstruct client: nil, data: nil

  defmodule Binary do
    @moduledoc """
    Binary value used to distinguish strings from binary values in Elixir.
    """

    defstruct data: <<>>

    def to_string(binary) do
      binary[:data]
    end

    def to_binary(data) do
      %Binary{data: data}
    end
  end

  defmodule RawMsg do
    @moduledoc """
    Raw message to/from Flowee. Holds a deserialized message, including header and data.
    """

    # Note: seq_start och last are only used internally.
    defstruct service: nil,
              message: nil,
              ping: false,
              pong: false,
              seq_start: nil,
              last: nil,
              data: []
  end

  # Tags used in the header
  @header_end 0
  @header_service_id 1
  @header_message_id 2
  @header_sequence_start 3
  @header_last_in_sequence 4
  @header_ping 5
  @header_pong 6

  @doc """
  Connect to a Flowee host using the supplied tcp_client (default is BitPal.TCPClient for plain TCP connections).

  Returns a connection object that can be passed to send and recv in here.
  """
  def connect(tcp_client, host \\ {127, 0, 0, 1}, port \\ 1235) do
    # Would be nice if we could get a packet in little endian mode. Now, we need to handle that ourselves...
    {:ok, c} = tcp_client.connect(host, port, [:binary, {:packet, 0}, {:active, false}])
    %Connection{client: tcp_client, data: c}
  end

  @doc """
  Close the connection.
  """
  def close(connection) do
    connection.client.close(connection.data)
  end

  @doc """
  Send a raw message.
  """
  def send(connection, msg) do
    send_packet(connection, serialize(msg))
  end

  @doc """
  Receive a high-level message. We will parse the header here since we need to merge long messages, etc.
  Returns a RawMsg with the appropriate fields set.
  """
  def recv(connection) do
    data = recv_packet(connection)
    # IO.puts("received: #{inspect(data, limit: :infinity)}")
    {header, rem} = parse_header(data)
    recv(connection, header, rem)
  end

  # Internal helper for receiving messages.
  defp recv(connection, header, data) do
    if header.last == false do
      # More data... Ignore the next header mostly.
      {new_header, more_data} = parse_header(recv_packet(connection))
      # Note: It might be important to check the header here since there might be other messages
      # that are interleaved with chained messages. The docs does not state if this is a
      # possibility, but from a quick glance at the code, I don't think so.
      recv(connection, %{header | last: new_header.last}, data <> more_data)
    else
      # Last packet! Either header.last == true or header.last == nil
      %{header | data: deserialize(data)}
    end
  end

  # Send a message (a binary)
  defp send_packet(connection, message) do
    size = byte_size(message) + 2
    size_msg = <<rem(size, 256), div(size, 256)>>
    connection.client.send(connection.data, size_msg <> message)
  end

  # Receive a packet.
  defp recv_packet(connection) do
    case connection.client.recv(connection.data, 2) do
      {:ok, <<size_low, size_high>>} ->
        size = size_high * 256 + size_low
        {:ok, data} = connection.client.recv(connection.data, size - 2)
        data

      {:error, msg} ->
        msg
    end
  end

  # Low-level serialization/deserialization.

  # Constants for the protocol.
  @tag_positive 0
  @tag_negative 1
  @tag_string 2
  @tag_byte_array 3
  @tag_true 4
  @tag_false 5
  @tag_double 6

  defp serialize(key, val) when is_integer(val) and val >= 0 do
    encode_token_header(key, @tag_positive) <> encode_int(val)
  end

  defp serialize(key, val) when is_integer(val) and val < 0 do
    encode_token_header(key, @tag_positive) <> encode_int(-val)
  end

  defp serialize(key, val) when is_binary(val) do
    encode_token_header(key, @tag_string) <> encode_int(byte_size(val)) <> val
  end

  defp serialize(key, %Binary{data: data}) do
    encode_token_header(key, @tag_byte_array) <> encode_int(byte_size(data)) <> data
  end

  defp serialize(key, val) when val == true do
    encode_token_header(key, @tag_true)
  end

  defp serialize(key, val) when val == false do
    encode_token_header(key, @tag_false)
  end

  defp serialize(key, val) when is_float(val) do
    # Should be exactly 8 bytes, little endian "native double"
    encode_token_header(key, @tag_double) <> <<val::little-float>>
  end

  # Serialize a sequence of {key, val} tuples.
  defp serialize_data(message) do
    case message do
      [{key, val} | rest] -> serialize(key, val) <> serialize_data(rest)
      [] -> <<>>
    end
  end

  # Serialize a header into tuples (including the data)
  defp msg_to_tuples(%RawMsg{service: svc, message: msg, ping: ping, pong: pong, data: data}) do
    # End of header
    result = [{@header_end, true} | data]

    # Ping/pong?
    result = if pong, do: [{@header_pong, true} | result], else: result
    result = if ping, do: [{@header_ping, true} | result], else: result

    # Message id?
    result = if msg != nil, do: [{@header_message_id, msg} | result], else: result

    # Service id?
    result = if svc != nil, do: [{@header_service_id, svc} | result], else: result
    result
  end

  # Serialize an entire RawMsg
  defp serialize(rawMsg) do
    serialize_data(msg_to_tuples(rawMsg))
  end

  defp encode_token_header(key, type) do
    if key < 31 do
      <<key <<< 3 ||| type>>
    else
      # This case is unclear in the spec...
      <<31 <<< 3 ||| type>> <> encode_int(key)
    end
  end

  def encode_int(value) do
    encode_int1(value, false)
  end

  defp encode_int1(value, mark) do
    here = (value &&& 0x7F) ||| if mark, do: 0x80, else: 0x00

    if value < 0x80 do
      <<here>>
    else
      prev = encode_int1((value >>> 7) - 1, true)
      prev <> <<here>>
    end
  end

  # Parse only the data part of the header. Returns { header, remaining data }
  defp parse_header(data) do
    parse_header(data, %RawMsg{})
  end

  defp parse_header(data, header) do
    case decode_tuple(data) do
      {remaining, {@header_end, _}} ->
        # Done!
        {header, remaining}

      {remaining, {@header_service_id, svc}} ->
        parse_header(remaining, %{header | service: svc})

      {remaining, {@header_message_id, msg}} ->
        parse_header(remaining, %{header | message: msg})

      {remaining, {@header_sequence_start, s}} ->
        parse_header(remaining, %{header | seq_start: s})

      {remaining, {@header_last_in_sequence, l}} ->
        parse_header(remaining, %{header | last: l})

      {remaining, {@header_ping, p}} ->
        parse_header(remaining, %{header | ping: p})

      {remaining, {@header_pong, p}} ->
        parse_header(remaining, %{header | pong: p})
    end
  end

  defp deserialize(data) do
    if byte_size(data) > 0 do
      {rem, tuple} = decode_tuple(data)
      [tuple | deserialize(rem)]
    else
      []
    end
  end

  # Decode a single tuple. Returns { remaining, { key, data } }
  defp decode_tuple(data) do
    {data, key, tag} = decode_token_header(data)

    cond do
      tag == @tag_positive ->
        {rem, val} = decode_int(data)
        {rem, {key, val}}

      tag == @tag_negative ->
        {rem, val} = decode_int(data)
        {rem, {key, -val}}

      tag == @tag_string ->
        {rem, len} = decode_int(data)
        <<str::binary-size(len), rest::binary>> = rem
        {rest, {key, str}}

      tag == @tag_byte_array ->
        {rem, len} = decode_int(data)
        <<str::binary-size(len), rest::binary>> = rem
        {rest, {key, %Binary{data: str}}}

      tag == @tag_true ->
        {data, {key, true}}

      tag == @tag_false ->
        {data, {key, false}}

      tag == @tag_double ->
        <<v::little-float, rest::binary>> = data
        {rest, {key, v}}

        # true ->
        #   IO.inspect tag
        #   IO.inspect data
    end
  end

  # Returns { remaining data, key, tag }
  defp decode_token_header(message) do
    <<first, rest::binary>> = message
    key = (first &&& 0xF8) >>> 3
    tag = first &&& 0x7

    if key == 31 do
      {rest, key} = decode_int(rest)
      {rest, key, tag}
    else
      {rest, key, tag}
    end
  end

  # Decode an integer value. Returns { remaining data, value }
  def decode_int(message) do
    decode_int1(message, -1)
  end

  defp decode_int1(message, prev_val) do
    <<first, rest::binary>> = message
    value = (prev_val + 1) <<< 7 ||| (first &&& 0x7F)

    if first >= 0x80 do
      decode_int1(rest, value)
    else
      {rest, value}
    end
  end
end
