defmodule Payments.Connection do
  use Bitwise

  # Connect to localhost.
  def connect() do
    # According to the doc, we should be able to give it some kind of string....
    connect({127, 0, 0, 1}, 1235)
  end

  # Connect to host + post. Host seems to be a tuple of an IPv4 address (possibly IPv6 also)
  def connect(host, port) do
    # Would be nice if we could get a packet in little endian mode. Now, we need to handle that ourselves...
    opts = [:binary, {:packet, 0}, {:active, false}]
    {:ok, connection} = :gen_tcp.connect(host, port, opts)
    connection
  end

  # Send a message (a binary)
  defp send_bytes(connection, message) do
    size = byte_size(message) + 2
    size_msg = <<rem(size, 256), div(size, 256)>>
    :gen_tcp.send(connection, size_msg <> message)
  end

  # Receive a message.
  defp recv_bytes(connection) do
    case :gen_tcp.recv(connection, 2) do
      {:ok, <<size_low, size_high>>} ->
        size = size_high * 256 + size_low
        {:ok, data} = :gen_tcp.recv(connection, size - 2)
        data

      {:error, msg} ->
        msg
    end
  end

  # Close the connection.
  def close(connection) do
    :gen_tcp.close(connection)
  end

  # Send a high-level message (a list of key-val tuples)
  def send(connection, msg) do
    send_bytes(connection, serialize(msg))
  end

  # Receive a high-level message (a list of key-val tuples)
  def recv(connection) do
    deserialize(recv_bytes(connection))
  end

  # Low-level serialization/deserialization.

  # Constants for the protocol.
  defp tag_positive() do
    0
  end

  defp tag_negative() do
    1
  end

  defp tag_string() do
    2
  end

  defp tag_byte_array() do
    3
  end

  defp tag_true() do
    4
  end

  defp tag_false() do
    5
  end

  defp tag_double() do
    6
  end

  defp serialize(key, val) do
    cond do
      is_integer(val) and val >= 0 ->
        encode_token_header(key, tag_positive()) <> encode_int(val)

      is_integer(val) and val < 0 ->
        encode_token_header(key, tag_positive()) <> encode_int(-val)

      is_binary(val) ->
        # This is eiter a string or a byte array... We assume string as that is more likely for now.
        encode_token_header(key, tag_string()) <> encode_int(byte_size(val)) <> val

      val == true ->
        encode_token_header(key, tag_true())

      val == false ->
        encode_token_header(key, tag_false())

      is_float(val) ->
        # Should be exactly 8 bytes, little endian "native double"
        encode_token_header(key, tag_double()) <> <<val::little-float>>
    end
  end

  # Serialize a sequence of {key, val} tuples.
  defp serialize(message) do
    case message do
      [{key, val} | rest] -> serialize(key, val) <> serialize(rest)
      [] -> <<>>
    end
  end

  defp encode_token_header(key, type) do
    if key < 31 do
      <<key <<< 3 ||| type>>
    else
      # This case is unclear in the spec...
      <<31 <<< 3 ||| type>> <> encode_int(key)
    end
  end

  defp encode_int(value) do
    if value < 0x80 do
      <<value>>
    else
      <<(value &&& 0x7F) ||| 0x80>> <> encode_int(value >>> 7)
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
      tag == tag_positive() ->
        {rem, val} = decode_int(data)
        {rem, {key, val}}

      tag == tag_negative() ->
        {rem, val} = decode_int(data)
        {rem, {key, -val}}

      tag == tag_string() ->
        {rem, len} = decode_int(data)
        <<str::binary-size(len), rest::binary>> = rem
        {rest, {key, str}}

      tag == tag_byte_array() ->
        {rem, len} = decode_int(data)
        <<str::binary-size(len), rest::binary>> = rem
        {rest, {key, str}}

      tag == tag_true() ->
        {data, {key, true}}

      tag == tag_false() ->
        {data, {key, false}}

      tag == tag_double() ->
        <<v::little-float, rest::binary>> = data
        {rest, {key, v}}
    end
  end

  # Returns { remaining data, key, tag }
  defp decode_token_header(message) do
    <<first, rest::binary>> = message
    key = (first &&& 0xF8) >>> 3
    tag = first &&& 0x7

    cond do
      tag == 31 ->
        {rest, key} = decode_int(rest)
        {rest, key, tag}

      true ->
        {rest, key, tag}
    end
  end

  # Decode an integer value. Returns { remaining data, value }
  defp decode_int(message) do
    <<first, rest::binary>> = message
    value = first &&& 0x7F

    if first >= 0x80 do
      {rest, more} = decode_int(rest)
      {rest, value ||| more <<< 7}
    else
      {rest, value}
    end
  end
end
