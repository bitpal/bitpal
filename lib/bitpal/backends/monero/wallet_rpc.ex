defmodule BitPal.Backend.Monero.WalletRPC do
  import BitPal.Backend.Monero.Settings
  import BitPal.RenderHelpers, only: [put_unless_nil: 3]
  require Logger

  def get_accounts(client) do
    call(client, "get_accounts")
  end

  def get_address(client, account_index, subaddress_indices \\ []) do
    call(client, "get_address", %{account_index: account_index, address_index: subaddress_indices})
  end

  @spec close_wallet(module) :: {:ok, any} | {:error, any}
  def close_wallet(client) do
    call(client, "close_wallet")
  end

  @spec store(module) :: {:ok, any} | {:error, any}
  def store(client) do
    call(client, "store")
  end

  @spec create_address(module, non_neg_integer) :: {:ok, any} | {:error, any}
  def create_address(client, account_index) do
    call(client, "create_address", %{account_index: account_index})
  end

  @spec get_balance(module, non_neg_integer, [non_neg_integer]) :: {:ok, any} | {:error, any}
  def get_balance(client, account_index, subaddress_indices \\ []) do
    call(client, "get_balance", %{
      account_index: account_index,
      adress_indices: subaddress_indices
    })
  end

  @spec incoming_transfers(module, non_neg_integer, [non_neg_integer]) ::
          {:ok, any} | {:error, any}
  def incoming_transfers(client, account_index, subaddress_indices \\ []) do
    call(client, "incoming_transfers", %{
      transfer_type: "all",
      account_index: account_index,
      subaddr_indices: subaddress_indices
    })
  end

  def get_transfers(client, account_index, subaddress_indices \\ []) do
    call(
      client,
      "get_transfers",
      %{
        in: true,
        pending: true,
        failed: true,
        pool: true,
        account_index: account_index,
        subaddr_indices: subaddress_indices
      }
    )
  end

  @spec get_transfer_by_txid(module, String.t(), non_neg_integer) ::
          {:ok, any} | {:error, any}
  def get_transfer_by_txid(client, txid, account_index) do
    call(client, "get_transfer_by_txid", %{txid: txid, account_index: account_index})
  end

  def make_uri(client, address, amount, recipient_name \\ nil, tx_description \\ nil) do
    params =
      %{address: address, amount: amount}
      |> put_unless_nil(:recipient_name, recipient_name)
      |> put_unless_nil(:tx_description, tx_description)

    call(client, "make_uri", params)
  end

  def validate_address(client, address) do
    call(client, "validate_address", %{address: address})
  end

  def get_height(client) do
    call(client, "get_height")
  end

  def get_version(client) do
    call(client, "get_version")
  end

  defp call(client, method, params \\ %{}) do
    # Logger.notice("#{method}  #{inspect(params)}")
    client.call(wallet_uri(), method, params)
  end
end
