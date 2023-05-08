defmodule BitPal.Backend.Monero.WalletRPC do
  alias BitPal.Files
  alias JSONRPC2.Clients.HTTP

  # FIXME usr/password and configurable
  @port 8332
  @url "http://localhost:#{@port}/json_rpc"
  @daemon_ip "192.168.1.121"
  @daemon_port "18081"
  @password ""

  def open_wallet(filename) do
    start(["--wallet-file", filename])
  end

  def generate_from_json(json_file) do
    # FIXME add restore height from daemon
    start(["--generate-from-json", json_file])
  end

  defp start(args) do
    Port.open({:spawn_executable, Files.process_monitor_path()}, [
      :binary,
      args:
        [
          System.find_executable("monero-wallet-rpc"),
          "--daemon-address",
          "#{@daemon_ip}:#{@daemon_port}",
          "--rpc-bind-port",
          "#{@port}",
          "--disable-rpc-login",
          "--log-file",
          "/var/log/monero/bitpal.log",
          "--log-level",
          "2",
          "--password",
          @password,
          "--tx-notify",
          "#{Files.notify_path()} monero:tx-notify %s"
        ] ++ args
    ])
  end

  @spec stop(port) :: true
  def stop(port) do
    close_wallet()
    Port.close(port)
  end

  def create_account do
  end

  def get_accounts do
    call("get_accounts", [])
  end

  def get_address(account_index, subaddress_indices \\ []) do
    call("get_address", %{account_index: account_index, address_index: subaddress_indices})
  end

  @spec close_wallet() :: {:ok, any} | {:error, any}
  def close_wallet do
    call("close_wallet", [])
  end

  @spec create_address(non_neg_integer) :: {:ok, any} | {:error, any}
  def create_address(account_index) do
    call("create_address", %{account_index: account_index})
  end

  @spec get_balance(non_neg_integer, [non_neg_integer]) :: {:ok, any} | {:error, any}
  def get_balance(account_index, subaddress_indices \\ []) do
    call("get_balance", %{account_index: account_index, adress_indices: subaddress_indices})
  end

  @spec incoming_transfers(non_neg_integer, [non_neg_integer]) :: {:ok, any} | {:error, any}
  def incoming_transfers(account_index, subaddress_indices \\ []) do
    call("incoming_transfers", %{
      account_index: account_index,
      subaddr_indices: subaddress_indices
    })
  end

  # get_transfers, gets a ton of things at the same time
  # also a bunch of other options
  def get_transfers(account_index, subaddress_indices \\ []) do
    call(
      "get_transfers",
      %{
        in: true,
        pending: true,
        failed: true,
        pool: true,
        account_index: account_index,
        subadd_indices: subaddress_indices
      }
    )
  end

  @spec get_transfer_by_txid(non_neg_integer, [non_neg_integer]) :: {:ok, any} | {:error, any}
  def get_transfer_by_txid(txid, account_index) do
    call("get_transfer_by_txid", %{txid: txid, account_index: account_index})
  end

  def validate_address do
  end

  defp call(method, params) do
    HTTP.call(@url, method, params)
  end
end
