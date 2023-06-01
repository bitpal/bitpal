defmodule BitPal.Backend.Monero.WalletRPC do
  import BitPal.Backend.Monero.Settings
  import BitPal.RenderHelpers, only: [put_unless_nil: 3]
  require Logger

  @type client :: module
  @type ref :: {client, port}

  def get_accounts(ref) do
    call(ref, "get_accounts")
  end

  def get_address(ref, account_index, subaddress_indices \\ []) do
    call(ref, "get_address", %{account_index: account_index, address_index: subaddress_indices})
  end

  @spec close_wallet(ref) :: {:ok, any} | {:error, any}
  def close_wallet(ref) do
    call(ref, "close_wallet")
  end

  @spec store(ref) :: {:ok, any} | {:error, any}
  def store(ref) do
    call(ref, "store")
  end

  @spec create_address(ref, non_neg_integer) :: {:ok, any} | {:error, any}
  def create_address(ref, account_index) do
    call(ref, "create_address", %{account_index: account_index})
  end

  @spec get_balance(ref, non_neg_integer, [non_neg_integer]) :: {:ok, any} | {:error, any}
  def get_balance(ref, account_index, subaddress_indices \\ []) do
    call(ref, "get_balance", %{
      account_index: account_index,
      adress_indices: subaddress_indices
    })
  end

  @spec incoming_transfers(ref, non_neg_integer, [non_neg_integer]) ::
          {:ok, any} | {:error, any}
  def incoming_transfers(ref, account_index, subaddress_indices \\ []) do
    call(ref, "incoming_transfers", %{
      transfer_type: "all",
      account_index: account_index,
      subaddr_indices: subaddress_indices
    })
  end

  def get_transfers(ref, account_index, subaddress_indices \\ []) do
    call(
      ref,
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

  @spec get_transfer_by_txid(ref, String.t(), non_neg_integer) ::
          {:ok, any} | {:error, any}
  def get_transfer_by_txid(ref, txid, account_index) do
    call(ref, "get_transfer_by_txid", %{txid: txid, account_index: account_index})
  end

  def make_uri(ref, address, amount, recipient_name \\ nil, tx_description \\ nil) do
    params =
      %{address: address, amount: amount}
      |> put_unless_nil(:recipient_name, recipient_name)
      |> put_unless_nil(:tx_description, tx_description)

    call(ref, "make_uri", params)
  end

  def validate_address(ref, address) do
    call(ref, "validate_address", %{address: address})
  end

  def get_height(ref) do
    call(ref, "get_height")
  end

  def get_version(ref) do
    call(ref, "get_version")
  end

  defp call({client, port}, method, params \\ %{}) do
    # Logger.notice("#{method}  #{inspect(params)}")
    client.call(wallet_uri(port), method, params)
  end
end
