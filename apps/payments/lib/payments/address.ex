defmodule Payments.Address do
  # Address management. Allows converting between different BCH address types.
  use Bitwise

  # Decode a BCH url. Returns the public key, or :error
  # Note: This is actually easier to decode than the legacy base52 format.
  # Returns { type, key }
  def decode_cash_url(url) do
    "bitcoincash:" <> <<data::binary>> = url

    raw = decode_base32(String.downcase(data))
    type_tag = :binary.at(raw, 0)
    # Either 0 or 8.
    type = type_tag &&& 0x07
    hash_size = div(cash_hash_size(type_tag >>> 3 &&& 0x0F), 8)
    checksum_size = div(40, 8)

    # Check the checksum. That is done in the 5-bit representation.
    # five_bit_data = data |> :binary.bin_to_list() |> Enum.map(fn x -> decode_base32_digit(x) end) |> :binary.list_to_bin()
    # bitcoincash_lowbits = <<0x02, 0x09, 0x14, 0x03, 0x0F, 0x09, 0x0E, 0x03, 0x01, 0x13, 0x08, 0x00>>
    # IO.inspect(compute_poly_mod(bitcoincash_lowbits <> five_bit_data))
    # The value from poly_mod should be zero. It does not work at the moment.

    <<_, hash::binary-size(hash_size), _checksum::binary-size(checksum_size)>> = raw

    case type do
      0 -> {:p2kh, hash}
      8 -> {:p2sh, hash}
    end
  end

  # Find the cash hash size in bits.
  defp cash_hash_size(data) do
    case data do
      0 -> 160
      1 -> 192
      2 -> 224
      3 -> 256
      4 -> 320
      5 -> 384
      6 -> 448
      7 -> 512
    end
  end

  # Create a hashed output script for a public key. This is what Flowee wants.
  # Accepts what "decode_cash_url" produces.
  def create_hashed_output_script({:p2kh, pubkey}) do
    # OP_DUP OP_HASH160, 20-byte push
    p2pkhPrefix = <<0x76, 0xA9, 20>>
    # OP_EQUALVERIFY OP_CHECKSIG
    p2pkhPostfix = <<0x88, 0xAC>>

    to_hash = p2pkhPrefix <> binary_part(pubkey, 0, 20) <> p2pkhPostfix

    :crypto.hash(:sha256, to_hash)
  end

  def create_hashed_output_script({:p2sh, pubkey}) do
    # OP_HASH160, 20-byte push
    p2shPrefix = <<0xA9, 20>>
    # OP_EQUAL
    p2shPostfix = <<0x87>>

    to_hash = p2shPrefix <> binary_part(pubkey, 0, 20) <> p2shPostfix

    :crypto.hash(:sha256, to_hash)
  end

  def create_hashed_output_script(pubkey) do
    # Note: I have no idea why we're doing this. It is ported directly from chashaddr.cpp in Flowee.

    # OP_DUP OP_HASH160, 20-byte push
    p2pkhPrefix = <<0x76, 0xA9, 20>>
    # OP_HASH160, 20-byte push
    # p2shPrefix = <<0xA9, 20>>
    # OP_EQUALVERIFY OP_CHECKSIG
    p2pkhPostfix = <<0x88, 0xAC>>
    # OP_EQUAL
    # p2shPostfix = <<0x87>>

    # If this was a SCRIPT_TYPE (whatever that is), we should use *sh* instead of *phk*
    to_hash = p2pkhPrefix <> binary_part(pubkey, 0, 20) <> p2pkhPostfix

    :crypto.hash(:sha256, to_hash)
  end

  # Decode a hex string into a binary. Reverses the bytes to match the format used by Flowee (it
  # seems like it uses little endian for some reason).
  def hex_to_binary(string) do
    reverse_binary(Base.decode16!(String.upcase(string)))
  end

  # Binary to hex string. Reverses the hex bytes as "hex_to_binary" does.
  def binary_to_hex(binary) do
    Base.encode16(reverse_binary(binary), case: :lower)
  end

  defp reverse_binary(binary) do
    binary |> :binary.bin_to_list() |> Enum.reverse() |> :binary.list_to_bin()
  end

  # Decode a base32 number into a binary
  def decode_base32(str) do
    numbers = str |> :binary.bin_to_list() |> Enum.map(fn x -> decode_base32_digit(x) end)
    IO.inspect(numbers)
    b32_to_numbers(numbers, 0, 0)
  end

  defp b32_to_numbers(numbers, bits_from_prev, val_from_prev) do
    case numbers do
      [first | rest] ->
        bits = bits_from_prev + 5
        val = (val_from_prev <<< 5) + first

        if bits > 8 do
          here = val >>> (bits - 8)
          <<here>> <> b32_to_numbers(rest, bits - 8, val &&& (1 <<< (bits - 8)) - 1)
        else
          b32_to_numbers(rest, bits, val)
        end

      [] ->
        # Check so that the padding is zero.
        if val_from_prev != 0 do
          # Note: It seems like this happens in the wild. We still get a valid address from it...
          # raise("Invalid base32 data! Padding must be zero: " <> inspect(val_from_prev))
          IO.puts("Note: non-zero padding: " <> inspect(val_from_prev))
          nil
        end

        <<>>
    end
  end

  # Decode a single base32-digit as specified by Bitcoin Cash (not standard).
  defp decode_base32_digit(value) do
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

  # Checksum function for bitcoin cash URL:s. From here: https://www.bitcoincash.org/spec/cashaddr.html
  # Takes a binary and returns a 64-bit integer.
  def compute_poly_mod(bitstring) do
    compute_poly_mod1(bitstring, 1)
  end

  # Checksum step.
  defp compute_poly_mod1(bitstring, c) do
    case bitstring do
      <<first, rest::bitstring>> ->
        c0 = c >>> 35 && 0xFF
        c = ((c &&& 0x07FFFFFFFF) <<< 5) ^^^ first

        c = if (c0 &&& 0x01) != 0, do: c ^^^ 0x98F2BC8E61, else: c
        c = if (c0 &&& 0x02) != 0, do: c ^^^ 0x79B76D99E2, else: c
        c = if (c0 &&& 0x04) != 0, do: c ^^^ 0xF33E5FB3C4, else: c
        c = if (c0 &&& 0x08) != 0, do: c ^^^ 0xAE2EABE2A8, else: c
        c = if (c0 &&& 0x10) != 0, do: c ^^^ 0x1E4F43E470, else: c

        compute_poly_mod1(rest, c)

      <<>> ->
        c ^^^ 1
    end
  end
end
