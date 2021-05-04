defmodule BitPal.Crypto.EC do
  @moduledoc """
  This module implements the core elliptic curve (EC) functionality needed to generate
  and derive keys in Bitcoin and Bitcoin Cash. The wrappers in here make a nice and uniform
  Elixir interface, as the underlying library is quite C-like.

  This implementation relies on libsecp256k1, which in turn depends on secp256k1 which is
  specifically designed for crypto currencies.
  """

  @doc """
  Convert a private key (an integer) to a public key (a point).
  """
  def to_public(key) do
    {ok, pub} = :libsecp256k1.ec_pubkey_create(key, :compressed)

    if ok do
      pub
    else
      :error
    end
  end

  @doc """
  Add N times the generator to a point.
  """
  def pubkey_add(key, n) do
    {ok, pub} = :libsecp256k1.ec_pubkey_tweak_add(key, n)

    if ok do
      pub
    else
      :error
    end
  end

  @doc """
  Add N to the private key (modulo the ring's moduli).
  """
  def privkey_add(key, n) do
    {ok, pub} = :libsecp256k1.ec_privkey_tweak_add(key, n)

    if ok do
      pub
    else
      :error
    end
  end
end
