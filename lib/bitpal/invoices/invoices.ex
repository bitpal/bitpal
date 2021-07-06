defmodule BitPal.Invoices do
  import Ecto.Changeset
  import Ecto.Query
  alias BitPal.Addresses
  alias BitPal.Blocks
  alias BitPal.ExchangeRate
  alias BitPal.FSM
  alias BitPal.InvoiceEvents
  alias BitPal.Repo
  alias BitPal.Transactions
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  require Decimal

  @spec register(map) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def register(params) do
    %Invoice{}
    |> cast(params, [:required_confirmations, :description])
    |> assoc_currency(params)
    |> validate_currency(params, :fiat_currency)
    |> cast_money(params, :amount, :currency)
    |> cast_money(params, :fiat_amount, :fiat_currency)
    |> cast_exchange_rate(params)
    |> validate_into_matching_pairs()
    |> with_default_lazy(:required_confirmations, fn ->
      Application.fetch_env!(:bitpal, :required_confirmations)
    end)
    |> Repo.insert()
  end

  @spec fetch(Invoice.id()) :: {:ok, Invoice.t()} | :error
  def fetch(id) do
    case Repo.get(Invoice, id) do
      nil -> :error
      invoice -> {:ok, invoice}
    end
  rescue
    _ -> :error
  end

  @spec fetch!(Invoice.id()) :: Invoice.t()
  def fetch!(id) do
    Repo.get!(Invoice, id)
  end

  @spec fetch_by_address(Address.id()) :: {:ok, Invoice.t()} | :error
  def fetch_by_address(address_id) do
    invoice =
      from(i in Invoice, where: i.address_id == ^address_id)
      |> Repo.one()

    if invoice do
      {:ok, invoice}
    else
      :error
    end
  end

  @spec open_addresses(Currency.id()) :: [Address.t()]
  def open_addresses(currency_id) do
    "invoices"
    |> with_status(:open)
    |> with_currency(currency_id)
    |> select([i], i.address_id)
    |> Repo.all()
  end

  @spec all_open() :: [Invoice.t()]
  def all_open do
    "invoices"
    |> with_status(:open)
    |> Repo.all()
  end

  @spec is_address_open?(Address.t()) :: boolean
  def is_address_open?(address_id) do
    "invoices"
    |> with_status(:open)
    |> with_address(address_id)
    |> Repo.exists?()
  end

  defp with_status(query, status) do
    from(i in query, where: i.status == ^Atom.to_string(status))
  end

  defp with_currency(query, currency_id) do
    from(i in query, where: i.currency_id == ^Atom.to_string(currency_id))
  end

  defp with_address(query, address_id) do
    from(i in query, where: i.address_id == ^address_id)
  end

  @spec finalized?(Invoice.t()) :: boolean
  def finalized?(invoice) do
    invoice.status != :draft
  end

  @spec target_amount_reached?(Invoice.t()) :: :ok | :underpaid | :overpaid
  def target_amount_reached?(invoice) do
    case Money.cmp(invoice.amount_paid, invoice.amount) do
      :lt -> :underpaid
      :gt -> :overpaid
      :eq -> :ok
    end
  end

  @spec confirmations_until_paid(Invoice.t()) :: non_neg_integer
  def confirmations_until_paid(invoice) do
    curr_height = Blocks.fetch_block_height!(invoice.currency_id)

    max_height =
      from(t in TxOutput,
        where: t.address_id == ^invoice.address_id,
        select: max(t.confirmed_height)
      )
      |> Repo.one()

    max(invoice.required_confirmations - (curr_height - max_height) - 1, 0)
  rescue
    _ -> invoice.required_confirmations
  end

  @spec one_tx_output(Invoice.t()) :: {:ok, TxOutput.t()} | :error
  def one_tx_output(invoice) do
    invoice = Repo.preload(invoice, :tx_outputs)

    if tx = List.first(invoice.tx_outputs) do
      {:ok, tx}
    else
      :error
    end
  end

  @spec assign_address(Invoice.t(), Address.t()) ::
          {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def assign_address(invoice, address) do
    invoice
    |> Repo.preload(:address)
    |> change
    |> validate_in_draft()
    |> put_assoc(:address, address)
    |> assoc_constraint(:address)
    |> Repo.update()
  end

  @spec ensure_address(Invoice.t(), (Addresses.address_index() -> Address.id())) ::
          {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def ensure_address(invoice = %{address_id: address_id}, _address_generator)
      when is_binary(address_id) do
    {:ok, invoice}
  end

  def ensure_address(invoice, address_generator) do
    case Addresses.register_with(invoice.currency_id, address_generator) do
      {:ok, address} ->
        assign_address(invoice, address)

      err ->
        err
    end
  end

  @spec update_info_from_txs(Invoice.t(), non_neg_integer) :: Invoice.t()
  def update_info_from_txs(invoice, block_height) do
    invoice = Repo.preload(invoice, :tx_outputs, force: true)

    %{
      invoice
      | amount_paid: calculate_amount_paid(invoice),
        confirmations_due: calculate_confirmations_due(invoice, block_height)
    }
  end

  @spec calculate_amount_paid(Invoice.t()) :: Money.t()
  def calculate_amount_paid(invoice) do
    invoice.tx_outputs
    |> Enum.reduce(Money.new(0, invoice.currency_id), fn tx, sum ->
      Money.add(tx.amount, sum)
    end)
  end

  @spec calculate_confirmations_due(Invoice.t(), non_neg_integer) :: non_neg_integer
  def calculate_confirmations_due(%Invoice{required_confirmations: 0}, _height) do
    0
  end

  def calculate_confirmations_due(invoice, height) do
    invoice.tx_outputs
    |> Enum.reduce(0, fn
      tx, max_confs ->
        max(
          invoice.required_confirmations - Transactions.num_confirmations(tx, height),
          max_confs
        )
    end)
  end

  def processing_reason(invoice = %Invoice{status: :processing}) do
    if invoice.required_confirmations == 0 do
      :verifying
    else
      {:confirming, invoice.confirmations_due}
    end
  end

  @spec delete(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def delete(invoice) do
    if finalized?(invoice) do
      change(invoice)
      |> add_error(:status, "cannot delete a finalized invoice")
    else
      case Repo.delete(invoice) do
        {:ok, invoice} ->
          InvoiceEvents.broadcast({:invoice_deleted, %{id: invoice.id, status: invoice.status}})
          {:ok, invoice}

        err ->
          err
      end
    end
  end

  @spec finalize(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def finalize(invoice) do
    res =
      FSM.transition_changeset(invoice, :open)
      |> validate_required([
        :amount,
        :fiat_amount,
        :currency_id,
        :address_id,
        :required_confirmations
      ])
      |> Repo.update()

    case res do
      {:ok, invoice} ->
        InvoiceEvents.broadcast({:invoice_finalized, invoice})
        {:ok, invoice}

      err ->
        err
    end
  end

  @spec finalize!(Invoice.t()) :: Invoice.t()
  def finalize!(invoice) do
    {:ok, invoice} = finalize(invoice)
    invoice
  end

  @spec process(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def process(invoice) do
    case transition(invoice, :processing) do
      {:ok, invoice} ->
        broadcast_processing(invoice)
        {:ok, invoice}

      err ->
        err
    end
  end

  @spec process!(Invoice.t()) :: Invoice.t()
  def process!(invoice) do
    {:ok, invoice} = process(invoice)
    invoice
  end

  @spec double_spent!(Invoice.t()) :: Invoice.t()
  def double_spent!(invoice) do
    # Double spend state can be seen from transactions
    mark_uncollectible!(invoice, :double_spent)
  end

  @spec expire!(Invoice.t()) :: Invoice.t()
  def expire!(invoice) do
    # Timeout can be calculated from transaction timestamp
    mark_uncollectible!(invoice, :expired)
  end

  @spec cancel!(Invoice.t()) :: Invoice.t()
  def cancel!(invoice) do
    mark_uncollectible!(invoice, :canceled)
  end

  @spec timeout!(Invoice.t()) :: Invoice.t()
  def timeout!(invoice) do
    mark_uncollectible!(invoice, :timed_out)
  end

  @spec void(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def void(invoice) do
    transition(invoice, :void)
  end

  @spec pay!(Invoice.t()) :: Invoice.t()
  def pay!(invoice) do
    if target_amount_reached?(invoice) == :underpaid do
      raise "target amount not reached"
    end

    invoice =
      FSM.transition_changeset(invoice, :paid)
      |> Repo.update!()

    InvoiceEvents.broadcast({:invoice_paid, %{id: invoice.id, status: invoice.status}})
    invoice
  end

  @spec broadcast_processing(Invoice.t()) :: :ok | {:error, term}
  def broadcast_processing(invoice) do
    InvoiceEvents.broadcast(
      {:invoice_processing,
       %{
         id: invoice.id,
         status: invoice.status,
         reason: processing_reason(invoice),
         txs: invoice.tx_outputs
       }}
    )
  end

  @spec broadcast_underpaid(Invoice.t()) :: :ok | {:error, term}
  def broadcast_underpaid(invoice) do
    InvoiceEvents.broadcast(
      {:invoice_underpaid,
       %{
         id: invoice.id,
         status: invoice.status,
         amount_due: Money.subtract(invoice.amount, invoice.amount_paid),
         txs: invoice.tx_outputs
       }}
    )
  end

  @spec broadcast_overpaid(Invoice.t()) :: :ok | {:error, term}
  def broadcast_overpaid(invoice) do
    InvoiceEvents.broadcast(
      {:invoice_overpaid,
       %{
         id: invoice.id,
         status: invoice.status,
         overpaid_amount: Money.subtract(invoice.amount_paid, invoice.amount),
         txs: invoice.tx_outputs
       }}
    )
  end

  @spec mark_uncollectible!(Invoice.t(), InvoiceEvents.uncollectible_reason()) :: Invoice.t()
  defp mark_uncollectible!(invoice, reason) do
    {:ok, invoice} = transition(invoice, :uncollectible)

    InvoiceEvents.broadcast(
      {:invoice_uncollectible, %{id: invoice.id, status: invoice.status, reason: reason}}
    )

    invoice
  end

  defp transition(invoice, new_state) do
    FSM.transition_changeset(invoice, new_state)
    |> Repo.update()
  end

  defp validate_in_draft(changeset) do
    case get_field(changeset, :status) do
      :draft ->
        changeset

      _ ->
        add_error(changeset, :status, "cannot edit a finalized invoice")
    end
  end

  defp validate_currency(changeset, params, key) do
    case get_param(params, key) do
      nil ->
        changeset

      currency ->
        if Money.Currency.exists?(currency) do
          changeset
        else
          add_error(changeset, key, "is invalid")
        end
    end
  end

  defp assoc_currency(changeset, params) do
    currency = get_param(params, :currency)

    if currency do
      changeset
      |> change(%{currency_id: Money.Currency.to_atom(currency)})
      |> assoc_constraint(:currency)
    else
      add_error(changeset, :currency, "cannot be empty")
    end
  rescue
    _ -> add_error(changeset, :currency, "is invalid")
  end

  defp cast_money(changeset, params, key, currency_key) do
    val = get_param(params, key)
    currency = get_param(params, currency_key)

    if val && currency do
      with {:ok, dec} <- Decimal.cast(val),
           {:ok, money} <- Money.parse(dec, currency) do
        if money.amount <= 0 do
          add_error(changeset, key, "must be greater than 0")
        else
          force_change(changeset, key, money)
        end
      else
        _ ->
          add_error(changeset, key, "is invalid")
      end
    else
      changeset
    end
  rescue
    # Might happen if we have an invalid currency, error is handled elsewhere
    _ -> changeset
  end

  defp cast_exchange_rate(changeset, params) do
    currency = get_param(params, :currency)
    fiat_currency = get_param(params, :fiat_currency)
    exchange_rate = get_param(params, :exchange_rate)

    if currency && fiat_currency && exchange_rate do
      with {:ok, dec} <- Decimal.cast(exchange_rate),
           {:ok, rate} <- ExchangeRate.new(dec, {currency, fiat_currency}) do
        force_change(changeset, :exchange_rate, rate)
      else
        _ -> add_error(changeset, :exchange_rate, "is invalid")
      end
    else
      changeset
    end
  end

  defp get_param(params, key) when is_atom(key) do
    params[key] || params[Atom.to_string(key)]
  end

  defp validate_into_matching_pairs(changeset) do
    amount = get_field(changeset, :amount)
    fiat_amount = get_field(changeset, :fiat_amount)
    exchange_rate = get_field(changeset, :exchange_rate)

    cond do
      !amount && !fiat_amount ->
        error = "must provide amount in either crypto or fiat"

        changeset
        |> add_error(:amount, error)
        |> add_error(:fiat_amount, error)

      !amount && !exchange_rate ->
        error = "must provide either amount or exchange rate"

        changeset
        |> add_error(:amount, error)
        |> add_error(:exchange_rate, error)

      exchange_rate ->
        case ExchangeRate.normalize(exchange_rate, amount, fiat_amount) do
          {:ok, amount, fiat_amount} ->
            changeset
            |> change(amount: amount)
            |> change(fiat_amount: fiat_amount)

          _ ->
            add_error(
              changeset,
              :exchange_rate,
              "invalid exchange rate"
            )
        end

      amount && fiat_amount ->
        case ExchangeRate.new(amount, fiat_amount) do
          {:ok, rate} ->
            change(changeset, exchange_rate: rate)

          _ ->
            add_error(changeset, :exchange_rate, "invalid exchange rate")
        end

      true ->
        changeset
    end
  end

  defp with_default_lazy(changeset, key, val) do
    if get_change(changeset, key) do
      changeset
    else
      changeset
      |> change(%{key => val.()})
    end
  end
end
