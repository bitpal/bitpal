defmodule BitPalFixtures.TransactionFixtures do
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPal.Transactions
  alias BitPalFixtures.InvoiceFixtures

  @spec unique_txid :: String.t()
  def unique_txid do
    :crypto.hash(:sha256, to_string(System.unique_integer())) |> Base.encode16()
  end

  @spec money_fixture(Currency.id() | Address.t()) :: Money.t()
  def money_fixture(currency_id) when is_atom(currency_id) do
    Money.new(Faker.Random.Elixir.random_between(1, 10_000_000), currency_id)
  end

  def money_fixture(address = %Address{}) do
    money_fixture(address.currency_id)
  end

  def generate_txs(store_id, count) do
    Enum.map(1..count, fn _ ->
      tx_fixture(store_id: store_id)
    end)
  end

  @spec tx_fixture(keyword) :: TxOutput.txid()
  def tx_fixture(params \\ []) do
    invoice =
      Enum.into(params, %{address: :auto})
      |> InvoiceFixtures.invoice_fixture()
      |> BitPal.Repo.preload(:tx_outputs, force: true)

    txid = unique_txid()
    :ok = Transactions.seen(txid, [{invoice.address_id, invoice.amount}])
    txid
  end
end
