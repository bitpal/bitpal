defmodule BitPal.BCH.Cashaddress do
  use Bitwise
  alias BitPal.Crypto.Base32

  @moduledoc """
  Address management. Allows converting between different BCH address types.
  """

  @doc """
  Decode a BCH url. Returns the public key, or :error
  Note: This is actually easier to decode than the legacy base52 format.
  Note: This url seems to be more reliable https://documentation.cash/protocol/blockchain/encoding/cashaddr
  than this url: https://www.bitcoincash.org/spec/cashaddr.html
  Note: The implementation in Flowee seems to follow the incorrect URL. That results in a non-zero
  padding of the base32 encoding.
  Returns { type, key }
  """
  def decode_cash_url(url) do
    # Check so that we have a decent prefix.
    "bitcoincash:" <> <<data::binary>> = url

    # Decode and check the checksum
    prefix_5bit = <<0x02, 0x09, 0x14, 0x03, 0x0F, 0x09, 0x0E, 0x03, 0x01, 0x13, 0x08, 0x00>>

    payload =
      case Base32.decode(data, insert: prefix_5bit) do
        :error -> raise("Invalid checksum!")
        x -> x
      end

    <<info, hash::binary>> = payload

    # The first 8 bits (76543210) indicate:
    # 7: reserved, always zero
    # 6543: type of address. Either 0 or 1 (other sources say 0 or 8, but I think they account for zeros below)
    # 210: size.

    type = info >>> 3 &&& 0xF
    size_bits = cash_hash_size(info &&& 0x07)

    # Check the size. All hash sizes are divisible by 8.
    if size_bits != 8 * byte_size(hash) do
      raise(
        "Incorrect payload size. Expected " <>
          inspect(size_bits) <> " bits, but got " <> inspect(8 * byte_size(hash)) <> " bits."
      )
    end

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
end
