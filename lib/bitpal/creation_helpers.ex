defmodule BitPal.CreationHelpers do
  use BitPalFixtures
  alias BitPal.Accounts
  alias BitPal.Addresses
  alias BitPal.Authentication.Tokens
  alias BitPal.Invoices
  alias BitPal.Stores
  alias BitPal.Transactions
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Store
  alias BitPalSchemas.TxOutput
  alias Ecto.UUID

  # FIXME move over to fixtures

  # Creation helpers

  @spec generate_txid :: String.t()
  def generate_txid, do: "txid:#{UUID.generate()}"

  @spec generate_address_id :: String.t()
  def generate_address_id, do: "address:#{UUID.generate()}"

  @spec generate_email :: String.t()
  def generate_email, do: AccountFixtures.unique_user_email()

  @spec create_user!(keyword | map) :: User.t()
  def create_user!(params \\ %{}), do: AccountFixtures.user_fixture(params)

  @spec create_store! :: Store.t()
  def create_store!(params \\ []) do
    user = user(params)

    params =
      params
      |> Enum.into(%{})
      |> Map.put_new_lazy(:label, fn -> StoreFixtures.unique_store_label() end)
      |> Map.drop([:user_id, :user])

    {:ok, store} = Stores.create(user, params)

    if token = params[:token] do
      create_token!(store, token)
    end

    store
  end

  @spec create_token!(Store.t()) :: AccessToken.t()
  def create_token!(store) do
    Tokens.create_token!(store).data
  end

  @spec create_token!(Store.t(), String.t()) :: AccessToken.t()
  def create_token!(store, token_data) do
    Tokens.insert_token!(store, token_data)
  end

  @spec create_auth! :: %{store_id: Store.id(), token: String.t()}
  def create_auth! do
    store = create_store!()
    token = create_token!(store)

    %{
      store_id: store.id,
      token: token
    }
  end

  @spec create_invoice!(keyword) :: Invoice.t()
  def create_invoice!(params \\ []) do
    store_id = store_id(params)

    params =
      Map.merge(
        %{
          amount: 1.2,
          exchange_rate: 2.0,
          currency: "BCH",
          fiat_currency: "USD"
        },
        Enum.into(params, %{})
      )

    {:ok, invoice} = Invoices.register(store_id, Map.delete(params, :address))

    invoice
    |> assign_address(params)
    |> change_status(params)
  end

  defp user(params) do
    cond do
      user = params[:user] ->
        user

      user_id = params[:user_id] ->
        Accounts.get_user!(user_id)

      true ->
        create_user!()
    end
  end

  defp store_id(params) do
    if store_id = params[:store_id] do
      store_id
    else
      create_store!().id
    end
  end

  defp assign_address(invoice, %{address: :auto}) do
    id = generate_address_id()
    assign_address(invoice, %{address: id})
  end

  defp assign_address(invoice, %{address: address_id}) do
    {:ok, address} = Addresses.register_next_address(invoice.currency_id, address_id)
    {:ok, invoice} = Invoices.assign_address(invoice, address)
    invoice
  end

  defp assign_address(invoice, _), do: invoice

  defp change_status(invoice, %{status: status}) do
    Invoices.set_status!(invoice, status)
  end

  defp change_status(invoice, _), do: invoice

  @spec create_transaction!(keyword) :: TxOutput.txid()
  def create_transaction!(params \\ []) do
    invoice = create_invoice!(Keyword.put_new(params, :address, :auto))
    txid = generate_txid()
    :ok = Transactions.seen(txid, [{invoice.address_id, invoice.amount}])
    txid
  end

  @spec create_invoice_transaction!(Invoice.t(), keyword) :: Invoice.t()
  def create_invoice_transaction!(invoice, params \\ []) do
    txid = generate_txid()

    amount =
      if val = params[:amount] do
        Money.parse!(val, invoice.currency_id)
      else
        invoice.amount
      end

    :ok = Transactions.seen(txid, [{invoice.address_id, amount}])
    invoice
  end
end
