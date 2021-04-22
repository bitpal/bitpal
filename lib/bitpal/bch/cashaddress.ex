defmodule BitPal.BCH.Cashaddress do
  # Address management. Allows converting between different BCH address types.
  use Bitwise

  # Decode a BCH url. Returns the public key, or :error
  # Note: This is actually easier to decode than the legacy base52 format.
  # Note: This url seems to be more reliable https://documentation.cash/protocol/blockchain/encoding/cashaddr
  # than this url: https://www.bitcoincash.org/spec/cashaddr.html
  # Note: The implementation in Flowee seems to follow the incorrect URL. That results in a non-zero
  # padding of the base32 encoding.
  # Returns { type, key }
  def decode_cash_url(url) do
    "bitcoincash:" <> <<data::binary>> = url
    nums = base32_to_nums(data)

    # Verify the checksum. Conveniently enough, this is done in the 5-bit representation.
    bitcoincash_lowbits =
      <<0x02, 0x09, 0x14, 0x03, 0x0F, 0x09, 0x0E, 0x03, 0x01, 0x13, 0x08, 0x00>>

    if compute_poly_mod(bitcoincash_lowbits <> nums) != 0 do
      raise("Invalid checksum!")
    end

    # The first 8 bits (76543210) indicate:
    # 7: reserved, always zero
    # 6543: type of address. Either 0 or 1 (other sources say 0 or 8, but I think they account for zeros below)
    # 210: size.

    # In base32 encoding (which we have here), they are stored as: 76543 210xx. As such, we can read them as:
    type = :binary.at(nums, 0) &&& 0xF
    size_bits = cash_hash_size(:binary.at(nums, 1) >>> 2)
    # rounding up, hence +4. The info-byte is included here, hence +8.
    size_5 = div(8 + size_bits + 4, 5)

    # Now, we can split it into payload and checksum: The checksum is always fixed in size.
    <<payload::binary-size(size_5), _checksum::binary-size(8)>> = nums

    # The payload is padded with zero bits to an even number of base32 characters. So we can safely decode it.
    <<_info, hash::bitstring>> = convert_5_to_8(payload)

    # Return an appropriate type.
    case type do
      0 -> {:p2kh, hash}
      1 -> {:p2sh, hash}
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
    p2pkh_prefix = <<0x76, 0xA9, 20>>
    # OP_EQUALVERIFY OP_CHECKSIG
    p2pkh_postfix = <<0x88, 0xAC>>

    to_hash = p2pkh_prefix <> binary_part(pubkey, 0, 20) <> p2pkh_postfix

    :crypto.hash(:sha256, to_hash)
  end

  def create_hashed_output_script({:p2sh, pubkey}) do
    # OP_HASH160, 20-byte push
    p2sh_prefix = <<0xA9, 20>>
    # OP_EQUAL
    p2sh_postfix = <<0x87>>

    to_hash = p2sh_prefix <> binary_part(pubkey, 0, 20) <> p2sh_postfix

    :crypto.hash(:sha256, to_hash)
  end

  def create_hashed_output_script(pubkey) do
    # Note: I have no idea why we're doing this. It is ported directly from chashaddr.cpp in Flowee.

    # OP_DUP OP_HASH160, 20-byte push
    p2pkh_prefix = <<0x76, 0xA9, 20>>
    # OP_HASH160, 20-byte push
    # p2sh_prefix = <<0xA9, 20>>
    # OP_EQUALVERIFY OP_CHECKSIG
    p2pkh_postfix = <<0x88, 0xAC>>
    # OP_EQUAL
    # p2sh_postfix = <<0x87>>

    # If this was a SCRIPT_TYPE (whatever that is), we should use *sh* instead of *phk*
    to_hash = p2pkh_prefix <> binary_part(pubkey, 0, 20) <> p2pkh_postfix

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

  # Convert a base32 string into 5-bit numbers
  defp base32_to_nums(str) do
    str
    |> :binary.bin_to_list()
    |> Enum.map(fn x -> decode_base32_digit(x) end)
    |> :binary.list_to_bin()
  end

  # Convert a sequence of 5-bit numbers into 8-bit numbers.
  def convert_5_to_8(str) do
    convert_5_to_8_i(str, 0, 0)
  end

  defp convert_5_to_8_i(numbers, bits_from_prev, val_from_prev) do
    case numbers do
      <<first, rest::bitstring>> ->
        bits = bits_from_prev + 5
        val = (val_from_prev <<< 5) + first

        if bits > 8 do
          here = val >>> (bits - 8)
          <<here>> <> convert_5_to_8_i(rest, bits - 8, val &&& (1 <<< (bits - 8)) - 1)
        else
          convert_5_to_8_i(rest, bits, val)
        end

      <<>> ->
        # Check so that the padding is zero.
        if val_from_prev != 0 do
          raise("Invalid base32 data! Padding must be zero: " <> inspect(val_from_prev))
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
        c0 = c >>> 35 &&& 0xFF
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
