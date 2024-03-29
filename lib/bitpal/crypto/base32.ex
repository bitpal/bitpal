defmodule BitPal.Crypto.Base32 do
  @moduledoc """
  This module implements the Base32 scheme used in various places in various
  cryptocurrencies. Note that this is *not* the standard Base32 encoding, the
  alphabet used here is different.

  In addition to Base32 encoding/decoding, we also provide checksums using the
  polymod function usually used in Bitcoin/Bitcoin Cash if desired. It is
  convenient to provide this functionality alongside the encoding/decoding since
  checksumming is done on the 5-bit chunks rather than 8-bit chunks.
  """

  import Bitwise

  @doc """
  Decode a base32-string into a binary representation. No checksumming.
  """
  def decode(data) do
    from_5bit(from_ascii(data))
  end

  @doc """
  Decode a base32-string into a binary representation. Use checksum as specified:
  - :none - no checksum
  - :polymod - default for Bitcoin Cash
  """
  def decode(data, checksum) do
    decode(data, checksum, insert: <<>>)
  end

  @doc """
  Decode a base32-string into a binary representation with the given checksum.

  There are two variants: either provide a prefix that is expected to be found
  in the beginning of "data" (prefix:), or assume that some data was already in
  the beginning (insert:). None of the two are included in the decoded data,'

  Returns: :error on failure.
  """
  def decode(data, checksum, prefix: prefix) do
    prefix_size = byte_size(prefix)
    <<first::binary-size(prefix_size), rest::binary>> = data

    if first == prefix do
      decode(rest, checksum, insert: prefix)
    else
      :error
    end
  end

  def decode(data, checksum, insert: insert) do
    data = from_ascii(data)
    s = byte_size(data) - hash_size(checksum)

    if s <= 0 do
      :error
    else
      <<payload::binary-size(s), hash::binary>> = data

      if hash_message(checksum, insert <> payload) == hash do
        from_5bit(payload)
      else
        :error
      end
    end
  end

  @doc """
  Encode some data into a base32-string. Appends a checksum using the polymod functionality.
  """
  def encode(data) do
    to_ascii(to_5bit(data))
  end

  @doc """
  Encode data into a base32-string with some checksum:
  - :none - no checksum
  - :polymod - default for Bitcoin cash
  """
  def encode(data, checksum) do
    encode(data, checksum, insert: <<>>)
  end

  @doc """
  Encode data into a base32-string with the given checksum.

  There are two variants: either provide a prefix that is expected to be found
  in the beginning of "data" (prefix:), or assume that some data was already in
  the beginning (insert:). None of the two are included in the decoded data,'

  Returns: :error on failure.
  """
  def encode(data, checksum, prefix: prefix) do
    prefix <> encode(data, checksum, insert: prefix)
  end

  def encode(data, checksum, insert: insert) do
    data = to_5bit(data)
    to_ascii(data <> hash_message(checksum, insert <> data))
  end

  # Hash size (base32 encoded size)
  def hash_size(:none), do: 0
  def hash_size(:polymod), do: 8

  # Hash data.
  def hash_message(:none, _message) do
    <<>>
  end

  def hash_message(:polymod, message) do
    checksum = polymod(message <> <<0, 0, 0, 0, 0, 0, 0, 0>>)

    to_5bit(<<
      checksum >>> (4 * 8) &&& 0xFF,
      checksum >>> (3 * 8) &&& 0xFF,
      checksum >>> (2 * 8) &&& 0xFF,
      checksum >>> (1 * 8) &&& 0xFF,
      checksum >>> (0 * 8) &&& 0xFF
    >>)
  end

  @doc """
  Decode base32 into 5-bit numbers. This is a semi low-level operation, but it
  is useful as a building block for other primitives in case the standard
  polymod checksum is not suitable for some reason.
  """
  def from_ascii(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn x -> digit_to_num(x) end)
    |> :binary.list_to_bin()
  end

  @doc """
  Convert a binary of 5-bit numbers to a binary with 8-bit numbers. Raises an error on non-zero padding.
  """
  def from_5bit(binary) do
    from_5bit_i(binary, 0, 0)
  end

  # Helper to 'from_5bit'
  defp from_5bit_i(numbers, bits_from_prev, val_from_prev) do
    case numbers do
      <<first, rest::binary>> ->
        bits = bits_from_prev + 5
        val = (val_from_prev <<< 5) + first

        if bits >= 8 do
          here = val >>> (bits - 8)
          <<here>> <> from_5bit_i(rest, bits - 8, val &&& (1 <<< (bits - 8)) - 1)
        else
          from_5bit_i(rest, bits, val)
        end

      <<>> ->
        # Check so that the padding is zero!
        if val_from_prev != 0 do
          raise("Invalid base32 data! Padding must be zero: " <> inspect(val_from_prev))
        end

        <<>>
    end
  end

  @doc """
  Convert a sequence of 8-byte elements to a sequence of 5-byte tuples. Insert padding as necessary.
  """
  def to_5bit(binary) do
    to_5bit_i(binary, 0, 0)
  end

  # Helper
  defp to_5bit_i(binary, spare_bits, spare_count) do
    # Shave off any bits that are too large.
    spare_bits = spare_bits &&& (1 <<< spare_count) - 1

    case binary do
      <<first, rest::binary>> ->
        spare_bits = spare_bits <<< 8 ||| first
        spare_count = spare_count + 8

        if spare_count >= 10 do
          insert = spare_bits >>> (spare_count - 10)
          <<insert >>> 5, insert &&& 0x1F>> <> to_5bit_i(rest, spare_bits, spare_count - 10)
        else
          insert = spare_bits >>> (spare_count - 5)
          <<insert>> <> to_5bit_i(rest, spare_bits, spare_count - 5)
        end

      <<>> ->
        # Add padding if needed.
        if spare_count > 0 do
          <<spare_bits <<< (5 - spare_count)>>
        else
          <<>>
        end
    end
  end

  @doc """
  Encode a sequence of 5-bit numbers into the base32 alphabet.
  """
  def to_ascii(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.map(fn x -> num_to_digit(x) end)
    |> :binary.list_to_bin()
  end

  @doc """
  Compute the checksum typically used in Bitcoin/Bitcoin Cash (Polymod).
  From here: https://www.bitcoincash.org/spec/cashaddr.html
  Operates on a binary of 5-bit integers and returns a 64-bit integer.
  """
  def polymod(binary) do
    polymod_i(binary, 1)
  end

  # Helper for the polymod function.
  defp polymod_i(binary, c) do
    case binary do
      <<first, rest::binary>> ->
        c0 = c >>> 35 &&& 0xFF
        # Note: We support binaries containing something other than 5-bit numbers by
        # slicing anything higher than 0x1F off.
        c = bxor((c &&& 0x07FFFFFFFF) <<< 5, first &&& 0x1F)

        c = if (c0 &&& 0x01) != 0, do: bxor(c, 0x98F2BC8E61), else: c
        c = if (c0 &&& 0x02) != 0, do: bxor(c, 0x79B76D99E2), else: c
        c = if (c0 &&& 0x04) != 0, do: bxor(c, 0xF33E5FB3C4), else: c
        c = if (c0 &&& 0x08) != 0, do: bxor(c, 0xAE2EABE2A8), else: c
        c = if (c0 &&& 0x10) != 0, do: bxor(c, 0x1E4F43E470), else: c

        polymod_i(rest, c)

      <<>> ->
        bxor(c, 1)
    end
  end

  # Decode a single base32 digit as specified by Bitcoin and Bitcoin Cash.
  defp digit_to_num(value) do
    case value do
      ?q -> 0
      ?p -> 1
      ?z -> 2
      ?r -> 3
      ?y -> 4
      ?9 -> 5
      ?x -> 6
      ?8 -> 7
      ?g -> 8
      ?f -> 9
      ?2 -> 10
      ?t -> 11
      ?v -> 12
      ?d -> 13
      ?w -> 14
      ?0 -> 15
      ?s -> 16
      ?3 -> 17
      ?j -> 18
      ?n -> 19
      ?5 -> 20
      ?4 -> 21
      ?k -> 22
      ?h -> 23
      ?c -> 24
      ?e -> 25
      ?6 -> 26
      ?m -> 27
      ?u -> 28
      ?a -> 29
      ?7 -> 30
      ?l -> 31
    end
  end

  # Encode a single base32 digit as specified by Bitcoin and Bitcoin Cash.
  defp num_to_digit(value) do
    case value do
      0 -> ?q
      1 -> ?p
      2 -> ?z
      3 -> ?r
      4 -> ?y
      5 -> ?9
      6 -> ?x
      7 -> ?8
      8 -> ?g
      9 -> ?f
      10 -> ?2
      11 -> ?t
      12 -> ?v
      13 -> ?d
      14 -> ?w
      15 -> ?0
      16 -> ?s
      17 -> ?3
      18 -> ?j
      19 -> ?n
      20 -> ?5
      21 -> ?4
      22 -> ?k
      23 -> ?h
      24 -> ?c
      25 -> ?e
      26 -> ?6
      27 -> ?m
      28 -> ?u
      29 -> ?a
      30 -> ?7
      31 -> ?l
    end
  end
end
