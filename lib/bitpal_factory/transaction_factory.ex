defmodule BitPalFactory.TransactionFactory do
  import Ecto.Changeset
  import BitPalFactory.UtilFactory
  import BitPalFactory.InvoiceFactory
  alias BitPal.Invoices
  alias BitPal.Repo
  alias BitPalFactory.CurrencyFactory
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  alias BitPalSchemas.TxOutput

  @spec unique_txid :: String.t()
  def unique_txid do
    :crypto.hash(:sha256, to_string(System.unique_integer())) |> Base.encode16()
  end

  @spec create_tx(Store.t() | Invoice.t() | Address.t() | Address.id(), keyword | map) ::
          TxOutput.t()
  def create_tx(ref, params \\ %{})

  def create_tx(store = %Store{}, params) do
    create_invoice(store)
    |> with_address()
    |> create_tx(params)
  end

  def create_tx(invoice = %Invoice{}, params) do
    params = Enum.into(params, %{amount: invoice.expected_payment})
    invoice = with_address(invoice)
    create_tx(invoice.address_id, invoice.payment_currency_id, params)
  end

  def create_tx(address = %Address{}, params) do
    create_tx(address.id, address.currency_id, params)
  end

  defp create_tx(address_id, currency_id, params) when is_binary(address_id) do
    txid = params[:txid] || unique_txid()
    amount = params[:amount] || create_money(currency_id)

    %TxOutput{address_id: address_id, txid: txid, amount: amount}
    |> change()
    |> cast(Enum.into(params, %{}), [:double_spent, :confirmed_height])
    |> Repo.insert!()
  end

  @spec with_txs(Invoice.t(), map | keyword) :: Invoice.t()
  def with_txs(invoice, opts \\ %{})

  def with_txs(invoice = %Invoice{status: :draft}, _opts) do
    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: :open}, opts) do
    tx_count = opts[:tx_count] || pick([{90, 0}, {9, 1}, {1, 2}])

    _txids =
      rand_money_lt(invoice.expected_payment, tx_count)
      |> Enum.map(fn amount ->
        create_tx(invoice, amount: amount)
      end)

    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: {:processing, _}}, _opts) do
    create_tx(invoice,
      amount: paid_or_overpaid_amount(invoice)
    )

    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: {_, :expired}}, _opts) do
    # No txs here, invoice was started but was never paid.
    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: {_, :canceled}}, _opts) do
    # No txs here, invoice was canceled.
    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: {_, :timed_out}}, _opts) do
    if invoice.required_confirmations > 0 do
      # One tx here that didn't confirm.
      create_tx(invoice, amount: invoice.expected_payment)
    end

    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: {_, :double_spent}}, _opts) do
    # One tx that was double spent.
    create_tx(invoice, amount: invoice.expected_payment, double_spent: true)
    invoice |> update_info_from_txs()
  end

  def with_txs(invoice = %Invoice{status: :void}, _opts) do
    # Vaid may have the same status_reasons as above, but can also be from open.
    # Having no txs is fine for this case.
    invoice |> update_info_from_txs()
  end

  # Paid may also be overpaid
  def with_txs(invoice = %Invoice{status: :paid}, _opts) do
    amount =
      case pick([{75, :paid}, {25, :overpaid}]) do
        :paid ->
          invoice.expected_payment

        :overpaid ->
          paid_or_overpaid_amount(invoice)
      end

    confirmed_height =
      if invoice.required_confirmations > 0 do
        CurrencyFactory.block_height(invoice.payment_currency_id,
          min: invoice.required_confirmations
        ) -
          invoice.required_confirmations
      else
        nil
      end

    create_tx(invoice, amount: amount, confirmed_height: confirmed_height)
    invoice |> update_info_from_txs()
  end

  defp paid_or_overpaid_amount(invoice) do
    create_money(invoice.expected_payment.currency,
      min: invoice.expected_payment.amount,
      max: round(invoice.expected_payment.amount * 1.2)
    )
  end

  defp update_info_from_txs(invoice) do
    Invoices.update_info_from_txs(
      invoice,
      CurrencyFactory.block_height(invoice.payment_currency_id)
    )
  end
end
