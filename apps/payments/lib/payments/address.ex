defmodule Payments.Address do
  # Address management. Allows converting between different BCH address types.

  # Decode a BCH url. Returns the public key, or :error
  def decodeCashUrl(url) do
    :error
    # I will do this later...
    # bitcoincash = "bitcoincash"
    # case url do
    #   <<
    # end
  end

  # Create a hashed output script for a public key. This is what Flowee wants.
  def createHashedOutputScript(pubkey) do
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
end
