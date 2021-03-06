defmodule BitPal.Invoices do
  import Ecto.Changeset
  import Ecto.Query
  alias BitPal.Addresses
  alias BitPal.Blocks
  alias BitPal.ExchangeRate
  alias BitPal.FSM
  alias BitPal.InvoiceEvents
  alias BitPal.Repo
  alias BitPal.StoreEvents
  alias BitPal.Transactions
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store
  alias BitPalSchemas.TxOutput
  alias BitPalSettings.StoreSettings
  alias Ecto.Changeset
  require Decimal

  # External

  @spec register(Store.id(), map) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def register(store_id, params) do
    res =
      %Invoice{store_id: store_id}
      |> cast(params, [:required_confirmations, :description, :email, :pos_data])
      |> assoc_currency(params)
      |> validate_currency(params, :fiat_currency)
      |> cast_money(params, :amount, :currency_id)
      |> cast_money(params, :fiat_amount, :fiat_currency)
      |> cast_exchange_rate(params)
      |> validate_into_matching_pairs()
      |> validate_required_confirmations()
      |> validate_format(:email, ~r/^.+@.+$/, message: "Must be a valid email")
      |> Repo.insert()

    case res do
      {:ok, invoice} ->
        StoreEvents.broadcast(
          {{:store, :invoice_created}, %{id: invoice.store_id, invoice_id: invoice.id}}
        )

        {:ok, invoice}

      err ->
        err
    end
  end

  @spec fetch(Invoice.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def fetch(id) do
    if invoice = Repo.get(Invoice, id) do
      {:ok, invoice}
    else
      {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @spec fetch(Invoice.id(), Store.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def fetch(id, store_id) do
    invoice = from(i in Invoice, where: i.id == ^id and i.store_id == ^store_id) |> Repo.one()

    if invoice do
      {:ok, invoice}
    else
      {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @spec all :: [Invoice.t()]
  def all do
    Repo.all(Invoice)
  end

  @spec update(Invoice.t(), map) ::
          {:ok, Invoice.t()} | {:error, :finalized} | {:error, Changeset.t()}
  def update(invoice, params) do
    if finalized?(invoice) do
      {:error, :finalized}
    else
      invoice
      |> calculate_exchange_rate!()
      |> cast(params, [:required_confirmations, :description, :email, :pos_data])
      |> assoc_currency(params)
      |> validate_currency(params, :fiat_currency)
      |> cast_money(params, :amount, :currency_id)
      |> cast_money(params, :fiat_amount, :fiat_currency)
      |> cast_exchange_rate(params)
      |> clear_pairs_for_update()
      |> validate_into_matching_pairs(nil_bad_params: true)
      |> validate_required_confirmations()
      |> validate_format(:email, ~r/^.+@.+$/, message: "Must be a valid email")
      |> Repo.update()
    end
  end

  @spec delete(Invoice.t()) ::
          {:ok, Invoice.t()} | {:error, :finalized} | {:error, Changeset.t()}
  def delete(invoice) do
    with false <- finalized?(invoice),
         {:ok, invoice} <- Repo.delete(invoice) do
      InvoiceEvents.broadcast({{:invoice, :deleted}, %{id: invoice.id, status: invoice.status}})
      {:ok, invoice}
    else
      true ->
        {:error, :finalized}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @spec finalize(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
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
        InvoiceEvents.broadcast({{:invoice, :finalized}, invoice})
        {:ok, invoice}

      err ->
        err
    end
  end

  @spec void(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def void(invoice) do
    case transition(invoice, :void) do
      {:ok, invoice} ->
        InvoiceEvents.broadcast({{:invoice, :voided}, %{id: invoice.id, status: invoice.status}})
        {:ok, invoice}

      err ->
        err
    end
  end

  @spec pay_unchecked(Invoice.t()) ::
          {:ok, Invoice.t()}
          | {:error, :no_block_height}
          | {:error, Changeset.t()}
  def pay_unchecked(invoice = %Invoice{}) do
    with {:ok, height} <- Blocks.fetch_block_height(invoice.currency_id),
         invoice <- update_info_from_txs(invoice, height),
         {:ok, invoice} <- transition(invoice, :paid) do
      InvoiceEvents.broadcast({{:invoice, :paid}, %{id: invoice.id, status: invoice.status}})
      {:ok, invoice}
    else
      :error ->
        {:error, :no_block_height}

      err ->
        err
    end
  end

  @spec has_status?(Invoice.t(), Invoice.status()) :: :ok | {:error, :invalid_status}
  def has_status?(invoice, status) do
    if invoice.status == status do
      :ok
    else
      {:error, :invalid_status}
    end
  end

  # Settings

  @spec address_key(Invoice.t()) :: {:ok, AddressKey.t()} | {:error, :not_found}
  def address_key(invoice) do
    StoreSettings.fetch_address_key(invoice.store_id, invoice.currency_id)
  end

  @spec double_spend_timeout(Invoice.t()) :: non_neg_integer
  def double_spend_timeout(invoice) do
    StoreSettings.get_double_spend_timeout(invoice.store_id, invoice.currency_id)
  end

  # Fetching

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

  @spec all_open() :: [Invoice.t()]
  def all_open do
    Invoice
    |> with_status(:open)
    |> select([i], i)
    |> Repo.all()
  end

  @spec finalized?(Invoice.t()) :: boolean
  def finalized?(invoice) do
    invoice.status != :draft
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

  # Internal updates

  @spec finalize!(Invoice.t()) :: Invoice.t()
  def finalize!(invoice) do
    {:ok, invoice} = finalize(invoice)
    invoice
  end

  @spec process(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def process(invoice) do
    reason =
      if invoice.required_confirmations == 0 do
        :verifying
      else
        :confirming
      end

    case transition(invoice, :processing, reason) do
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

  @spec pay!(Invoice.t()) :: Invoice.t()
  def pay!(invoice) do
    if target_amount_reached?(invoice) == :underpaid do
      raise "target amount not reached"
    end

    invoice =
      FSM.transition_changeset(invoice, :paid)
      |> Repo.update!()

    InvoiceEvents.broadcast({{:invoice, :paid}, %{id: invoice.id, status: invoice.status}})
    invoice
  end

  @spec mark_uncollectible!(Invoice.t(), InvoiceEvents.uncollectible_reason()) :: Invoice.t()
  defp mark_uncollectible!(invoice, reason) do
    {:ok, invoice} = transition(invoice, :uncollectible, reason)

    InvoiceEvents.broadcast(
      {{:invoice, :uncollectible}, %{id: invoice.id, status: invoice.status, reason: reason}}
    )

    invoice
  end

  defp transition(invoice, new_state, status_reason \\ nil) do
    FSM.transition_changeset(invoice, new_state)
    |> change(status_reason: status_reason)
    |> Repo.update()
  end

  @spec set_status!(Invoice.t(), Invoice.status()) :: Invoice.t()
  def set_status!(invoice, status) do
    change(invoice, status: status)
    |> Repo.update!()
  end

  # Updates

  @spec assign_address(Invoice.t(), Address.t()) ::
          {:ok, Invoice.t()} | {:error, Changeset.t()}
  def assign_address(invoice, address) do
    invoice
    |> Repo.preload(:address)
    |> change
    |> validate_in_draft()
    |> put_assoc(:address, address)
    |> assoc_constraint(:address)
    |> Repo.update()
  end

  @spec ensure_address(Invoice.t(), Addresses.address_generator()) ::
          {:ok, Invoice.t()} | {:error, Changeset.t()} | {:error, :address_key_not_assigned}
  def ensure_address(invoice = %{address_id: address_id}, _address_generator)
      when is_binary(address_id) do
    {:ok, invoice}
  end

  def ensure_address(invoice, address_generator) do
    with {:ok, address_key} <- address_key(invoice),
         {:ok, address} <- Addresses.generate_address(address_key, address_generator) do
      assign_address(invoice, address)
    else
      {:error, :not_found} -> {:error, :address_key_not_assigned}
      err -> err
    end
  end

  # Aux data

  def calculate_exchange_rate!(invoice) do
    cond do
      invoice.exchange_rate ->
        invoice

      invoice.amount && invoice.fiat_amount ->
        %{invoice | exchange_rate: ExchangeRate.new!(invoice.amount, invoice.fiat_amount)}

      true ->
        invoice
    end
  end

  @spec target_amount_reached?(Invoice.t()) :: :ok | :underpaid | :overpaid
  def target_amount_reached?(%Invoice{amount_paid: nil}) do
    :underpaid
  end

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

  @spec update_info_from_txs(Invoice.t()) :: Invoice.t()
  def update_info_from_txs(invoice) do
    curr_height = Blocks.fetch_block_height!(invoice.currency_id)
    update_info_from_txs(invoice, curr_height)
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

  # Broadcasting

  @spec broadcast_processing(Invoice.t()) :: :ok | {:error, term}
  def broadcast_processing(invoice) do
    reason =
      case invoice.status_reason do
        :confirming ->
          {:confirming, invoice.confirmations_due}

        :verifying ->
          :verifying
      end

    InvoiceEvents.broadcast(
      {{:invoice, :processing},
       %{
         id: invoice.id,
         status: invoice.status,
         reason: reason,
         txs: invoice.tx_outputs
       }}
    )
  end

  @spec broadcast_underpaid(Invoice.t()) :: :ok | {:error, term}
  def broadcast_underpaid(invoice) do
    InvoiceEvents.broadcast(
      {{:invoice, :underpaid},
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
      {{:invoice, :overpaid},
       %{
         id: invoice.id,
         status: invoice.status,
         overpaid_amount: Money.subtract(invoice.amount_paid, invoice.amount),
         txs: invoice.tx_outputs
       }}
    )
  end

  # Query helpers

  def with_status(query, statuses) when is_list(statuses) do
    Enum.reduce(statuses, query, fn status, query ->
      from(i in query, or_where: i.status == ^Atom.to_string(status))
    end)
  end

  def with_status(query, status) do
    from(i in query, where: i.status == ^Atom.to_string(status))
  end

  def with_currency(query, currency_id) do
    from(i in query, where: i.currency_id == ^Atom.to_string(currency_id))
  end

  def with_address(query, address_id) do
    from(i in query, where: i.address_id == ^address_id)
  end

  # Validotions

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
    currency =
      get_param(params, :currency_id) ||
        get_field(changeset, :currency_id)

    if currency do
      changeset
      |> change(%{currency_id: Money.Currency.to_atom(currency)})
      |> assoc_constraint(:currency)
    else
      add_error(changeset, :currency_id, "cannot be empty")
    end
  rescue
    _ -> add_error(changeset, :currency_id, "is invalid")
  end

  defp cast_money(changeset, params, key, currency_key) do
    val = get_param(params, key)
    currency = get_currency(changeset, params, key, currency_key)

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

  defp get_currency(changeset, params, key, currency_key) do
    in_params = get_param(params, currency_key)

    if in_params do
      in_params
    else
      case get_field(changeset, key) do
        %Money{currency: currency} ->
          currency

        _ ->
          nil
      end
    end
  end

  defp cast_exchange_rate(changeset, params) do
    currency = get_currency(changeset, params, :amount, :currency_id)
    fiat_currency = get_currency(changeset, params, :fiat_amount, :fiat_currency)
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

  defp clear_pairs_for_update(changeset) do
    amount = get_change(changeset, :amount)
    fiat_amount = get_change(changeset, :fiat_amount)
    exchange_rate = get_change(changeset, :exchange_rate)

    cond do
      amount && fiat_amount && exchange_rate ->
        changeset

      amount && exchange_rate ->
        change(changeset, fiat_amount: nil)

      amount && fiat_amount ->
        change(changeset, exchange_rate: nil)

      fiat_amount && exchange_rate ->
        change(changeset, amount: nil)

      exchange_rate ->
        change(changeset, fiat_amount: nil)

      amount ->
        change(changeset, fiat_amount: nil)

      fiat_amount ->
        change(changeset, amount: nil)

      true ->
        changeset
    end
  end

  defp validate_into_matching_pairs(changeset, opts \\ []) do
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
            |> change(amount: amount, fiat_amount: fiat_amount)

          {:error, :mismatched_exchange_rate} ->
            add_error(
              changeset,
              :exchange_rate,
              "invalid exchange rate"
            )

          {:error, :bad_params} ->
            if opts[:nil_bad_params] do
              changeset
              |> change(exchange_rate: nil, fiat_amount: nil)
            else
              add_error(
                changeset,
                :exchange_rate,
                "invalid exchange rate pairs"
              )
            end
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

  defp validate_required_confirmations(changeset) do
    case get_change(changeset, :required_confirmations) do
      nil ->
        store_id = get_field(changeset, :store_id)
        currency_id = get_field(changeset, :currency_id)
        confs = StoreSettings.get_required_confirmations(store_id, currency_id)

        changeset
        |> change(required_confirmations: confs)

      _ ->
        changeset
        |> validate_number(:required_confirmations, greater_than_or_equal_to: 0)
    end
  end
end
