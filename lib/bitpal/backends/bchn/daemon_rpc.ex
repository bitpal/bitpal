defmodule BitPal.Backend.BCHN.DaemonRPC do
  import BitPal.Backend.BCHN.Settings
  require Logger

  def getrpcinfo(client) do
    call(client, "getrpcinfo")
  end

  def getblockchaininfo(client) do
    call(client, "getblockchaininfo")
  end

  def getnetworkinfo(client) do
    call(client, "getnetworkinfo")
  end

  def estimatefee(client) do
    call(client, "estimatefee")
  end

  # Wallet management

  def listwallets(client) do
    call(client, "listwallets")
  end

  def createwallet(client, file) do
    call(client, "createwallet", %{wallet_name: file, disable_private_keys: true, blank: true})
  end

  def loadwallet(client, file) do
    call(client, "loadwallet", %{filename: file})
  end

  # Wallet specific requests

  def importaddress(client, wallet_file, address) do
    call(client, "importaddress", %{address: address, rescan: false}, wallet_path(wallet_file))
  end

  def listsinceblock(client, wallet_file, block_hash) do
    call(
      client,
      "listsinceblock",
      %{
        blockhash: block_hash,
        include_watchonly: true,
        include_removed: true
      },
      wallet_path(wallet_file)
    )
  end

  def listreceivedbyaddress(client, wallet_file, address) do
    call(
      client,
      "listreceivedbyaddress",
      %{minconf: 0, include_empty: false, include_watchonly: true, address_filter: address},
      wallet_path(wallet_file)
    )
  end

  def gettransaction(client, wallet_file, txid) do
    call(
      client,
      "gettransaction",
      %{
        txid: txid,
        include_watchonly: true
      },
      wallet_path(wallet_file)
    )
  end

  defp wallet_path(wallet_file) do
    "/wallet/#{wallet_file}"
  end

  defp call(client, method, params \\ %{}, path \\ nil)

  defp call(client, method, params, nil) do
    client.call(daemon_uri(), method, params)
  end

  defp call(client, method, params, path) do
    client.call(daemon_uri() <> path, method, params)
  end
end
