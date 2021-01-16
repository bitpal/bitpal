defmodule Payments.Address do
  # Address management. Allows converting between different BCH address types.
  alias Payments.Connection.Binary

  # Decode a BCH url. Returns the public key, or :error
  def decode_cash_url(url) do
    :error
    # I will do this later...
    # bitcoincash = "bitcoincash"
    # case url do
    #   <<
    # end
  end

  # Create a hashed output script for a public key. This is what Flowee wants.
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
    binary |> :binary.bin_to_list |> Enum.reverse |> :binary.list_to_bin
  end

end
