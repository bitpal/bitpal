defmodule BitPal.Crypto.Base58 do
  @moduledoc """
  This module implements the Base58 scheme used in various places in Bitcoin and Bitcoin Cash for
  example. Note that there are multiple versions of the Base58 encoding. This module implements the
  encoding specific for Bitcoin (and used in other places). The difference is the order of the
  characters used.

  In addition to raw encoding/decoding, this module also implements checksumming so that the user of
  the module don't have to worry about that.
  """

  use Bitwise

  @doc """
  Encode the binary into base58. No checksumming.
  """
  def encode(data) do
    data
    |> to_base58
    |> to_ascii
  end

  @doc """
  Encode the binary into base58, optionally adding a checksum.

  Checksums available are:
  - :none - no checksum
  - :doublesha - double sha256 - used in Bitcoin
  """
  def encode(data, checksum) do
    encode(data <> hash_message(checksum, data))
  end

  @doc """
  Decode the string from base58 into a binary. No checksumming.
  """
  def decode(string) do
    string
    |> from_ascii
    |> from_base58
  end

  @doc """
  Decode a string with a specified checksum. Returns :error on checksum failure.

  Checksums available are:
  - :none - no checksum
  - :doublesha - double sha256 - used in Bitcoin
  """
  def decode(string, checksum) do
    data = decode(string)
    payload_size = byte_size(data) - hash_size(checksum)

    if payload_size <= 0 do
      :error
    else
      <<payload::binary-size(payload_size), hash::binary>> = data

      if hash == hash_message(checksum, payload) do
        payload
      else
        :error
      end
    end
  end

  # Size of the hash.
  defp hash_size(:none), do: 0
  defp hash_size(:doublesha), do: 4

  # Compute hash.
  defp hash_message(:none, _message), do: <<>>

  defp hash_message(:doublesha, message) do
    <<hash::binary-size(4), _::binary>> = :crypto.hash(:sha256, :crypto.hash(:sha256, message))
    hash
  end

  # Convert a binary to base 58. We interpret "data" as an integer with the most significant byte
  # first. We need to be wary of any leading zero bytes, as they will otherwise be ignored when we
  # convert to an integer.
  # Note: I have seen quite a few implementations that do not seem to handle this case very well,
  # they simply convert to an integer and call it a day (thus discarding leading zeros).
  defp to_base58(data) do
    case data do
      <<0x00, rest::binary>> ->
        <<0>> <> to_base58(rest)

      <<>> ->
        <<>>

      d ->
        to_base58_int(:binary.decode_unsigned(d, :big))
    end
  end

  defp to_base58_int(number) do
    if number > 0 do
      to_base58_int(div(number, 58)) <> <<rem(number, 58)>>
    else
      <<>>
    end
  end

  # Convert a binary with numbers (0-57) into a "regular" binary.
  defp from_base58(data) do
    case data do
      <<0, rest::binary>> ->
        <<0x00>> <> from_base58(rest)

      <<>> ->
        <<>>

      d ->
        num = from_base58_int(d, byte_size(d) - 1)
        :binary.encode_unsigned(num, :big)
    end
  end

  defp from_base58_int(data, pos) do
    result = :binary.at(data, pos)

    if pos == 0 do
      result
    else
      result + from_base58_int(data, pos - 1) * 58
    end
  end

  # Convert from ASCII to a binary of digits.
  defp from_ascii(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn x -> digit_to_num(x) end)
    |> :binary.list_to_bin()
  end

  # Convert from binary of digits to ASCII
  defp to_ascii(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn x -> num_to_digit(x) end)
    |> :binary.list_to_bin()
  end

  @alphabet '123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz'

  # Decode a single base58 digit into an integer.
  defp digit_to_num(value) do
    case Enum.find_index(@alphabet, &(&1 == value)) do
      nil ->
        raise("Unknown character in base58 string.")

      x ->
        x
    end
  end

  # Encode a single base58 digit.
  defp num_to_digit(value) do
    Enum.at(@alphabet, value)
  end
end
