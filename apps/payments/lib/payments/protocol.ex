defmodule Payments.Protocol do
  use Bitwise

  # Constants for the protocol.
  defp tag_positive() do 0 end
  defp tag_negative() do 1 end
  defp tag_string() do 2 end
  defp tag_byte_array() do 3 end
  defp tag_true() do 4 end
  defp tag_false() do 5 end
  defp tag_double() do 6 end

  def serialize(key, val) do
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
        IO.puts "DOUBLE"
    end
  end

  def make(message) do
    case message do
      [{key, val} | rest] -> serialize(key, val) <> make(rest)
      [] -> << >>
    end
  end

  def version_request() do
    make([{1, 0}, {16, 0}, {0, true}])
  end

  defp encode_token_header(key, type) do
      if key < 31 do
        << (key <<< 3) ||| type >>
      else
        # This case is unclear in the spec...
        << (31 <<< 3) ||| type >> <> encode_int(key)
      end
  end

  defp encode_int(value) do
    if value < 0x80 do
      << value >>
    else
      << (value &&& 0x7F) ||| 0x80 >> <> encode_int(value >>> 7)
    end
  end
end
