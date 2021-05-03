defmodule BitPal.BCH.KeyTree do
  alias BitPal.Crypto.EC
  alias BitPal.Crypto.Base58

  @moduledoc """
  This module implements BIP-0032: derivation of private and public keys from a
  public or private master key (see: https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)

  The idea is quite simple. This module implements two functions:
  - to_public(private) - generates a public key from a private key (can't spend coins using the public key).
  - child_key(key, id) - generate a child key derived from key, which may be either a public or a private key.

  Based on these function (mainly, child_key), we can imagine a tree with the root in the master key
  (m for the private key and M for the public key). Each key has 0x7FFFFFFF*2 children. 0..0x7FFFFFF
  are regular child keys, and 0x80000000.. are "hardened keys" (can't derive them from public keys,
  but can be used to derive public keys). In this implementation, we use negative numbers to denote
  hardened keys (the spec uses 1' for a hardened key). Note that 0' is represented as -1, 1' as -2
  and so on.

  In this scheme, it is meaningful to assign each key with a "derivation path" as a sequence of
  numbers, like so: m / 1 / 5 / 8

  These works much like directories in your regular file system, except that we can only use
  numbers. Some of these have a specific meaning. See BIP-0044 or BIP-0043 for more details. This
  module is only concerned with key derivation, so it does not impose any restrictions.

  This module represents a derivation path as a list of numbers. It also contains the ability to
  parse a string in a "standard" representation into a list of numbers that can later be manipulated
  as desired. It is worth noting that this representation does not concern itself with whether or
  not we are talking about public or private keys (i.e. the leading m or M). This is since we want
  it to be easy to take substrings of this representation to divide the derivation into multiple
  steps. This is since we typically don't start with the master key, but a derived key at some
  level. The symbol :public can be used to enforce a public key at some point.
  """

  defmodule Public do
    @moduledoc """
    This is our representation of a public key.
    Note: parent_fingerprint is RIPEMD160 after SHA256 of the parent public key.
    """
    defstruct key: nil,
              chaincode: nil,
              depth: 0,
              child_id: 0,
              parent_fingerprint: <<0x00, 0x00, 0x00, 0x00>>
  end

  defmodule Private do
    @moduledoc """
    This is our representation of a private key.
    Note: parent_fingerprint is RIPEMD160 after SHA256 of the parent public key.
    """
    defstruct key: nil,
              chaincode: nil,
              depth: 0,
              child_id: 0,
              parent_fingerprint: <<0x00, 0x00, 0x00, 0x00>>
  end

  @doc """
  Convert a private key to a public key. A no-op if the key is already a public key.
  """
  def to_public(key = %Public{}) do
    key
  end

  def to_public(key = %Private{}) do
    %Public{
      key: EC.to_public(key.key),
      chaincode: key.chaincode,
      depth: key.depth,
      child_id: key.child_id,
      parent_fingerprint: key.parent_fingerprint
    }
  end

  @doc """
  Derive a child key based on "id". If "id" is negative, we derive a hardened child key (i.e. a key
  which can not be derived from a public key, not even the public part).

  Note: It is possible that some keys are invalid. In that case we return :error and the next key should 
  be used instead. The probability of this happening is 1 in 2^127 according to BIP-0032.
  """
  def child_key(key = %Private{}, id) do
    id =
      if id < 0 do
        -id - 1 + 0x80000000
      else
        id
      end

    seed =
      if id >= 0x80000000 do
        # Hardened key
        <<0x00>> <> key.key <> <<id::32>>
      else
        # Normal key
        EC.to_public(key.key) <> <<id::32>>
      end

    <<nkey::binary-size(32), ncode::binary-size(32)>> = hmac_sha512(key.chaincode, seed)
    nkey = EC.privkey_add(key.key, nkey)

    if nkey == :error do
      # This means that we got zero, or that "nkey" was out of range (larger than modulo)
      :error
    else
      %Private{
        key: nkey,
        chaincode: ncode,
        depth: key.depth + 1,
        child_id: id,
        parent_fingerprint: key_fingerprint(key)
      }
    end
  end

  def child_key(key = %Public{}, id) do
    if id < 0 do
      raise("Can not derive hardened keys from a public key.")
    end

    <<nkey::binary-size(32), ncode::binary-size(32)>> =
      hmac_sha512(key.chaincode, key.key <> <<id::32>>)

    nkey = EC.pubkey_add(key.key, nkey)

    if nkey == :error do
      # This means that we got zero, or that "nkey" was out of range (larger than modulo)
      :error
    else
      %Public{
        key: nkey,
        chaincode: ncode,
        depth: key.depth + 1,
        child_id: id,
        parent_fingerprint: key_fingerprint(key)
      }
    end
  end

  @doc """
  Derive the key specified in the path.
  """
  def derive(key, []), do: key
  def derive(key, [first | rest]), do: derive(apply_part(key, first), rest)
  def derive(key, <<data::binary>>), do: derive(key, parse_path(data))

  @doc """
  Apply a single part of a chain.
  """
  def apply_part(key, :public), do: to_public(key)
  def apply_part(key, id), do: child_key(key, id)

  @doc """
  Compute a key's fingerprint (RIPEMD160 of the SHA256).
  """
  def key_fingerprint(key) do
    {_, hash} = key_hash(key)
    binary_part(hash, 0, 4)
  end

  @doc """
  Compute a key's hash (RIPEMD160 of the SHA256). This is what is typically used as target adresses
  for P2PKH, for example. The returned address is in the format expected by the cashaddress module,
  so it is easy to use that to generate BCH URL:s later on.

  Note: This always computes the public key's hash, even if a private key is passed.
  """
  def key_hash(key) do
    hash = :crypto.hash(:ripemd160, :crypto.hash(:sha256, to_public(key).key))
    {:p2pkh, hash}
  end

  @doc """
  Create a key from a seed (a binary of some length).
  """
  def from_seed(seed) do
    <<key::binary-size(32), chaincode::binary-size(32)>> = hmac_sha512("Bitcoin seed", seed)
    # Note: no parent fingerprint, we're a root key.
    %Private{
      key: key,
      chaincode: chaincode,
      depth: 0,
      child_id: 0
    }
  end

  # Signatures for various subnets.
  @mainnet_pub <<0x04, 0x88, 0xB2, 0x1E>>
  @mainnet_pri <<0x04, 0x88, 0xAD, 0xE4>>

  @doc """
  Load a Base58-encoded key into a suitable representation.
  """
  def import_key(string) do
    <<version::binary-size(4), rest::binary>> = Base58.decode(string, :doublesha)

    case version do
      @mainnet_pub ->
        parse_public(rest)

      @mainnet_pri ->
        parse_private(rest)
    end
  end

  defp parse_public(data) do
    <<
      depth::binary-size(1),
      fingerprint::binary-size(4),
      child_id::binary-size(4),
      chaincode::binary-size(32),
      key::binary-size(33)
    >> = data

    %Public{
      key: key,
      chaincode: chaincode,
      depth: :binary.decode_unsigned(depth),
      child_id: :binary.decode_unsigned(child_id),
      parent_fingerprint: fingerprint
    }
  end

  defp parse_private(data) do
    <<
      depth::binary-size(1),
      fingerprint::binary-size(4),
      child_id::binary-size(4),
      chaincode::binary-size(32),
      0x00,
      key::binary-size(32)
    >> = data

    %Private{
      key: key,
      chaincode: chaincode,
      depth: :binary.decode_unsigned(depth),
      child_id: :binary.decode_unsigned(child_id),
      parent_fingerprint: fingerprint
    }
  end

  @doc """
  Export a Base58 key in the standard format. Note: This is more information than what is needed to
  make payments to a node. Thus, this format is only suitable if we expect to further derive keys
  from this key.
  """
  def export_key(key) do
    {signature, bytes} =
      case key do
        %Public{key: k} ->
          {@mainnet_pub, k}

        %Private{key: k} ->
          {@mainnet_pri, <<0x00>> <> k}
      end

    data =
      signature <>
        <<key.depth::8>> <>
        key.parent_fingerprint <>
        <<
          key.child_id::4*8
        >> <>
        key.chaincode <>
        bytes

    Base58.encode(data, :doublesha)
  end

  @doc """
  Parses a derivation string into a list that we use in the rest of this library.
  """
  def parse_path(string) do
    [first | rest] = String.split(string, "/")

    case String.trim(first) do
      "m" ->
        parse_path_i(rest)

      "M" ->
        parse_path_i(rest) ++ [:public]

      _ ->
        # Consider this as a fragment, and just parse it as if we had a "m/" in the beginning.
        parse_path_i([first | rest])
    end
  end

  defp parse_path_i(parts), do: Enum.map(parts, &convert_part/1)

  defp convert_part(part) do
    part = String.trim(part)

    cond do
      part == "p" or part == "P" ->
        :public

      String.ends_with?(part, "'") ->
        -(String.to_integer(String.slice(part, 0, String.length(part) - 1)) + 1)

      true ->
        String.to_integer(part)
    end
  end

  @doc """
  Convert a path-list into a string.

  Note that paths containing ":public" do not have an exact representation in the standard
  format. We will simply output M if there is a ":public" somewhere, regardless of where it is.
  """
  def inspect_path(path) do
    r = inspect_path_i(Enum.filter(path, &(&1 != :public)))

    if Enum.find(path, &(&1 == :public)) do
      "M" <> r
    else
      "m" <> r
    end
  end

  defp inspect_path_i([first | rest]) do
    p =
      if first >= 0 do
        inspect(first)
      else
        inspect(-first - 1) <> "'"
      end

    "/" <> p <> inspect_path_i(rest)
  end

  defp inspect_path_i([]) do
    ""
  end

  # Perform a HMAC-SHA512.
  defp hmac_sha512(key, data) do
    :crypto.mac(:hmac, :sha512, key, data)
  end
end
