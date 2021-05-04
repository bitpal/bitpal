defmodule BitPal.BCH.Cashaddress do
  @moduledoc """
  Address management. Allows converting between different BCH address types.
  """

  use Bitwise
  alias BitPal.Crypto.Base32

  # ASCII prefix for BCH URL:s.
  @ascii_prefix "bitcoincash:"

  # Bytes used in checksumming
  @checksum_prefix <<0x02, 0x09, 0x14, 0x03, 0x0F, 0x09, 0x0E, 0x03, 0x01, 0x13, 0x08, 0x00>>

  @doc """
  Decode a BCH url. Returns the public key, or :error
  Note: This is actually easier to decode than the legacy base52 format.
  Note: This url seems to be more reliable https://documentation.cash/protocol/blockchain/encoding/cashaddr
  than this url: https://www.bitcoincash.org/spec/cashaddr.html
  Returns { type, key }
  """
  def decode_cash_url(url) do
    # Check so that we have a decent prefix.
    @ascii_prefix <> <<data::binary>> = url

    # Decode and check the checksum
    payload =
      case Base32.decode(data, :polymod, insert: @checksum_prefix) do
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
      0 -> {:p2pkh, hash}
      1 -> {:p2sh, hash}
    end
  end

  @doc """
  Encode a wallet address into a BCH url. The inverse of decode_cash_url.
  """
  def encode_cash_url(hash) do
    {type, hash} = hash

    type =
      case type do
        :p2pkh -> 0
        :p2sh -> 1
      end

    size =
      case byte_size(hash) * 8 do
        160 -> 0
        192 -> 1
        224 -> 2
        256 -> 3
        320 -> 4
        384 -> 5
        448 -> 6
        512 -> 7
      end

    info = type <<< 3 ||| size
    @ascii_prefix <> Base32.encode(<<info>> <> hash, :polymod, insert: @checksum_prefix)
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
  def create_hashed_output_script({:p2pkh, pubkey}) do
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
