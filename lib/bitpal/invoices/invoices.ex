defmodule BitPal.Invoices do
  import Ecto.Changeset
  import Ecto.Query
  alias BitPal.Addresses
  alias BitPal.Blocks
  alias BitPal.Currencies
  alias BitPal.ExchangeRates
  alias BitPal.InvoiceEvents
  alias BitPal.Repo
  alias BitPal.StoreEvents
  alias BitPal.Transactions
  alias BitPal.RenderHelpers
  alias BitPalApi.ApiHelpers
  alias BitPalSchemas.Address
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Transaction
  alias BitPalSchemas.InvoiceRates
  alias BitPalSchemas.InvoiceStatus
  alias BitPalSchemas.Store
  alias BitPalSchemas.TxOutput
  alias BitPalSettings.StoreSettings
  alias Ecto.Changeset
  require Decimal
  require Logger

  # External

  @spec register(Store.id(), map) :: {:ok, Invoice.t()} | {:error, Changeset.t()}
  def register(store_id, params) do
    res =
      %Invoice{store_id: store_id, status: :draft}
      |> change_validation(params)
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

  @spec update(Invoice.t(), map) ::
          {:ok, Invoice.t()} | {:error, :finalized} | {:error, Changeset.t()}
  def update(invoice, params) do
    if finalized?(invoice) do
      {:error, :finalized}
    else
      invoice
      |> change_validation(params)
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
      invoice
      |> finalize_validation()
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
    status =
      if reason = InvoiceStatus.reason(invoice.status) do
        {:void, reason}
      else
        :void
      end

    case transition(invoice, status) do
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
    with {:ok, height} <- Blocks.fetch_height(invoice.payment_currency_id),
         invoice <- update_info_from_txs(invoice, height),
         {:ok, invoice} <- transition(invoice, :paid) do
      broadcast_paid(invoice)
      {:ok, invoice}
    else
      :error ->
        {:error, :no_block_height}

      err ->
        err
    end
  end

  @spec has_status?(Invoice.t(), InvoiceStatus.t()) :: :ok | {:error, :invalid_status}
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
    StoreSettings.fetch_address_key(invoice.store_id, invoice.payment_currency_id)
  end

  @spec double_spend_timeout(Invoice.t()) :: non_neg_integer
  def double_spend_timeout(invoice) do
    StoreSettings.get_double_spend_timeout(invoice.store_id, invoice.payment_currency_id)
  end

  # Fetching

  @spec fetch!(Invoice.id()) :: Invoice.t()
  def fetch!(id) do
    {:ok, invoice} = fetch(id)
    invoice
  end

  @spec fetch(Invoice.id(), Store.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def fetch(id, store_id) do
    invoice = from(i in Invoice, where: i.id == ^id and i.store_id == ^store_id) |> Repo.one()

    if invoice do
      {:ok, update_expected_payment(invoice)}
    else
      {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @spec fetch(Invoice.id()) :: {:ok, Invoice.t()} | {:error, :not_found}
  def fetch(id) do
    if invoice = Repo.get(Invoice, id) do
      {:ok, update_expected_payment(invoice)}
    else
      {:error, :not_found}
    end
  rescue
    _ -> {:error, :not_found}
  end

  @spec all :: [Invoice.t()]
  def all do
    Repo.all(Invoice)
    |> Enum.map(&update_expected_payment/1)
  end

  @spec fetch_by_address(Address.id()) :: {:ok, Invoice.t()} | :error
  def fetch_by_address(address_id) do
    invoice =
      from(i in Invoice, where: i.address_id == ^address_id)
      |> Repo.one()

    if invoice do
      {:ok, update_expected_payment(invoice)}
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
    |> Enum.map(&update_expected_payment/1)
  end

  @spec finalized?(Invoice.t()) :: boolean
  def finalized?(invoice) do
    invoice.status != :draft
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

    case transition(invoice, {:processing, reason}) do
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
      transition_validation(invoice, :paid)
      |> Repo.update!()

    broadcast_paid(invoice)
    invoice
  end

  @spec mark_uncollectible!(Invoice.t(), InvoiceStatus.uncollectible_reason()) :: Invoice.t()
  defp mark_uncollectible!(invoice, reason) do
    {:ok, invoice} = transition(invoice, {:uncollectible, reason})

    InvoiceEvents.broadcast(
      {{:invoice, :uncollectible}, %{id: invoice.id, status: invoice.status}}
    )

    invoice
  end

  defp transition(invoice, next_status) do
    transition_validation(invoice, next_status)
    |> Repo.update()
  end

  @spec set_status!(Invoice.t(), InvoiceStatus.t()) :: Invoice.t()
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

  def rate(invoice = %Invoice{}) do
    invoice.rates[invoice.payment_currency_id][invoice.price.currency]
  end

  def rate!(invoice = %Invoice{}) do
    case rate(invoice) do
      nil -> raise("rate not found in invoice: #{inspect(invoice)}")
      x -> x
    end
  end

  # If we get more virtual fields (that don't depend on more preloads) consider
  # merging them with this.
  def update_expected_payment(invoice = %Invoice{}) do
    case calculate_expected_payment(invoice) do
      {:ok, expected} ->
        %{invoice | expected_payment: expected}

      _ ->
        invoice
    end
  end

  def calculate_expected_payment(invoice = %Invoice{}) do
    calculate_expected_payment(invoice.price, invoice.payment_currency_id, invoice.rates)
  end

  def calculate_expected_payment(_price, nil, _rates) do
    {:error, "invoice must have payment_currency"}
  end

  def calculate_expected_payment(price = %Money{currency: currency}, currency, _rates) do
    if Currencies.is_crypto(price.currency) do
      {:ok, price}
    else
      {:error, "if price.currency == payment_currency then it must be a crypto"}
    end
  end

  def calculate_expected_payment(
        price = %Money{currency: price_currency},
        payment_currency,
        rates
      ) do
    case get_rate(price, payment_currency, rates) do
      nil ->
        {:error, "could not find rate #{payment_currency}-#{price_currency} in #{inspect(rates)}"}

      rate ->
        {:ok, ExchangeRates.calculate_base(rate, payment_currency, price)}
    end
  end

  defp get_rate(_price, nil, _rates) do
    nil
  end

  defp get_rate(%Money{currency: price_currency}, payment_currency, rates) do
    InvoiceRates.get_rate(rates, payment_currency, price_currency)
  end

  @spec target_amount_reached?(Invoice.t()) :: :ok | :underpaid | :overpaid
  def target_amount_reached?(%Invoice{amount_paid: nil}) do
    :underpaid
  end

  def target_amount_reached?(invoice) do
    case Money.cmp(invoice.amount_paid, invoice.expected_payment) do
      :lt -> :underpaid
      :gt -> :overpaid
      :eq -> :ok
    end
  end

  @spec update_info_from_txs(Invoice.t()) :: Invoice.t()
  def update_info_from_txs(invoice = %{payment_currency_id: nil}) do
    invoice
  end

  def update_info_from_txs(invoice) do
    curr_height = Blocks.get_height(invoice.payment_currency_id)
    update_info_from_txs(invoice, curr_height)
  end

  @spec update_info_from_txs(Invoice.t(), non_neg_integer) :: Invoice.t()
  def update_info_from_txs(invoice, block_height) do
    %{
      invoice
      | amount_paid: calculate_amount_paid(invoice),
        confirmations_due: calculate_confirmations_due(invoice, block_height)
    }
  end

  @spec calculate_amount_paid(Invoice.t()) :: Money.t()
  def calculate_amount_paid(invoice) do
    Addresses.amount_paid(invoice.address_id, invoice.payment_currency_id)
  end

  @spec calculate_confirmations_due(Invoice.t()) :: non_neg_integer
  def calculate_confirmations_due(invoice) do
    curr_height = Blocks.get_height(invoice.payment_currency_id)
    calculate_confirmations_due(invoice, curr_height)
  end

  @spec calculate_confirmations_due(Invoice.t(), non_neg_integer) :: non_neg_integer
  def calculate_confirmations_due(%Invoice{required_confirmations: 0}, _) do
    0
  end

  def calculate_confirmations_due(%Invoice{required_confirmations: required}, nil) do
    required
  end

  def calculate_confirmations_due(invoice, block_height) do
    max(invoice.required_confirmations - num_confirmations(invoice, block_height), 0)
  end

  @spec num_confirmations(Invoice.t()) :: non_neg_integer
  def num_confirmations(invoice) do
    curr_height = Blocks.fetch_height!(invoice.payment_currency_id)
    num_confirmations(invoice, curr_height)
  end

  @spec num_confirmations(Invoice.t(), non_neg_integer | nil) :: non_neg_integer
  def num_confirmations(%Invoice{address_id: nil}, _), do: 0

  def num_confirmations(invoice, block_height) do
    case from(t in Transaction,
           left_join: out in TxOutput,
           on: out.transaction_id == t.id,
           where: out.address_id == ^invoice.address_id,
           # If any tx has height == 0, then we should treat it as no confirmations.
           select: fragment("
              CASE
                WHEN (?) = 0 THEN 0
                ELSE (?)
              END
           ", min(t.height), min(^block_height - t.height + 1))
         )
         |> Repo.one() do
      nil -> 0
      x when x < 0 -> 0
      x -> x
    end
  end

  # Broadcasting

  @spec broadcast_processing(Invoice.t()) :: :ok | {:error, term}
  def broadcast_processing(invoice) do
    confirmations_due =
      case InvoiceStatus.reason(invoice.status) do
        :confirming ->
          invoice.confirmations_due

        :verifying ->
          nil
      end

    InvoiceEvents.broadcast(
      {{:invoice, :processing},
       %{
         id: invoice.id,
         status: invoice.status,
         txs: Transactions.address_tx_info(invoice.address_id)
       }
       |> RenderHelpers.put_unless_nil(:confirmations_due, confirmations_due)}
    )
  end

  @spec broadcast_underpaid(Invoice.t()) :: :ok | {:error, term}
  def broadcast_underpaid(invoice) do
    InvoiceEvents.broadcast(
      {{:invoice, :underpaid},
       %{
         id: invoice.id,
         status: invoice.status,
         amount_paid: invoice.amount_paid,
         txs: Transactions.address_tx_info(invoice.address_id)
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
         amount_paid: invoice.amount_paid,
         txs: Transactions.address_tx_info(invoice.address_id)
       }}
    )
  end

  @spec broadcast_paid(Invoice.t()) :: :ok | {:error, term}
  def broadcast_paid(invoice) do
    InvoiceEvents.broadcast(
      {{:invoice, :paid},
       %{
         id: invoice.id,
         status: invoice.status,
         amount_paid: invoice.amount_paid,
         txs: Transactions.address_tx_info(invoice.address_id)
       }}
    )
  end

  # Query helpers

  def with_status(query, statuses) when is_list(statuses) do
    Enum.reduce(statuses, query, fn status, query ->
      from(i in query, or_where: fragment("(?)->>'state'", i.status) == ^Atom.to_string(status))
    end)
  end

  def with_status(query, status) do
    from(i in query, where: fragment("(?)->>'state'", i.status) == ^Atom.to_string(status))
  end

  def with_currency(query, currency_id) do
    from(i in query, where: i.payment_currency_id == ^Atom.to_string(currency_id))
  end

  def with_address(query, address_id) do
    from(i in query, where: i.address_id == ^address_id)
  end

  # Validotions

  defp change_validation(invoice = %Invoice{}, params) do
    invoice
    |> cast(params, [
      :description,
      :email,
      :order_id,
      :pos_data,
      :price,
      :rates,
      :required_confirmations
    ])
    |> validate_price()
    |> assoc_payment_currency(params)
    |> validate_rates()
    |> validate_expected_payment()
    |> validate_required_confirmations()
    |> validate_email()
  end

  defp finalize_validation(invoice = %Invoice{}) do
    transition_validation(invoice, :open)
    |> ensure_required_confirmations()
    |> validate_required([
      :price,
      :rates,
      :payment_currency_id,
      :address_id,
      :required_confirmations
    ])
    # Technically these validations shouldn't be necessary as all invoice changes should
    # pass through register() or update(), but we try to be extra safe.
    |> validate_price()
    |> validate_payment_currency()
    |> validate_rates()
    |> validate_expected_payment()
    |> validate_required_confirmations()
    |> validate_email()
  end

  defp validate_in_draft(changeset) do
    case get_field(changeset, :status) do
      :draft ->
        changeset

      _ ->
        add_error(changeset, :status, "cannot edit a finalized invoice")
    end
  end

  @spec transition_validation(Invoice.t(), InvoiceStatus.t()) :: Changeset.t()
  defp transition_validation(invoice = %Invoice{}, next_status) do
    case InvoiceStatus.validate_transition(invoice.status, next_status) do
      {:ok, next_status} ->
        invoice
        |> Changeset.change()
        |> Changeset.put_change(:status, next_status)

      {:error, msg} ->
        invoice
        |> Changeset.change()
        |> Changeset.add_error(:status, msg)
    end
  end

  defp validate_price(changeset) do
    if price = get_field(changeset, :price) do
      if price.amount > 0 do
        changeset
      else
        add_error(changeset, :price, "must be greater than 0")
      end
    else
      add_error(changeset, :price, "must provide a price")
    end
  end

  defp assoc_payment_currency(changeset, params) do
    price_currency =
      if price = get_field(changeset, :price) do
        price.currency
      else
        nil
      end

    payment_currency_id =
      get_param(params, :payment_currency_id) || get_field(changeset, :payment_currency_id)

    case {price_currency, payment_currency_id} do
      {nil, _} ->
        changeset

      {c, c} ->
        change_payment_currency(changeset, c)

      {price, nil} ->
        if Currencies.is_crypto(price) do
          change_payment_currency(changeset, price)
        else
          changeset
        end

      {price, payment} ->
        if Currencies.is_crypto(price) do
          add_same_price_error(changeset, price, payment)
        else
          change_payment_currency(changeset, payment)
        end
    end
  end

  defp add_same_price_error(changeset, price_currency, payment_currency) do
    changeset
    |> add_error(
      :price,
      "must be the same as payment currency `#{payment_currency}` when priced in crypto",
      code: :same_price_error
    )
    |> add_error(
      :payment_currency_id,
      "must be the same as price currency `#{price_currency}` when priced in crypto",
      code: :same_price_error
    )
  end

  defp change_payment_currency(changeset, currency_id) do
    if Currencies.is_crypto(currency_id) do
      changeset
      |> change(%{payment_currency_id: Money.Currency.to_atom(currency_id)})
      |> assoc_constraint(:payment_currency)
    else
      add_error(
        changeset,
        :payment_currency_id,
        "must be a cryptocurrency"
      )
    end
  end

  defp validate_rates(changeset) do
    cond do
      rates = get_change(changeset, :rates) ->
        validate_rates_change(changeset, rates)

      rates = get_field(changeset, :rates) ->
        if update_rates?(changeset, rates) do
          update_rates(changeset)
        else
          changeset
        end

      true ->
        update_rates(changeset)
    end
  end

  defp update_rates?(changeset = %Changeset{valid?: false}, _rates) do
    changeset
  end

  defp update_rates?(changeset, rates) do
    !valid_rates?(changeset, rates) || !expired_rates?(changeset)
  end

  defp valid_rates?(changeset, rates) do
    price_currency = get_field(changeset, :price).currency
    payment_currency = get_field(changeset, :payment_currency_id)

    case {price_currency, payment_currency} do
      {c, c} ->
        false

      {price_currency, nil} ->
        InvoiceRates.find_base_with_rate(rates, price_currency) == :not_found

      _ ->
        InvoiceRates.has_rate?(rates, payment_currency, price_currency)
    end
  end

  defp expired_rates?(changeset = %Changeset{}) do
    if updated_at = get_field(changeset, :rates_updated_at) do
      expired_rates?(updated_at)
    else
      # No field means a new invoice is being created, so it's not old.
      false
    end
  end

  defp expired_rates?(updated_at = %NaiveDateTime{}) do
    ExchangeRates.expired?(updated_at)
  end

  defp validate_rates_change(changeset = %Changeset{valid?: false}, _rates) do
    changeset
  end

  defp validate_rates_change(changeset, rates) do
    case InvoiceRates.cast(rates) do
      {:ok, rates} ->
        price_currency = get_field(changeset, :price).currency
        payment_currency = get_field(changeset, :payment_currency_id)

        case {price_currency, payment_currency} do
          {price_currency, nil} ->
            if InvoiceRates.find_base_with_rate(rates, price_currency) != :not_found do
              put_rates(changeset, rates)
            else
              add_error(
                changeset,
                :rates,
                "could not find rate with #{price_currency} in #{inspect(rates)}"
              )
            end

          _ ->
            if InvoiceRates.has_rate?(rates, payment_currency, price_currency) do
              put_rates(changeset, rates)
            else
              add_error(
                changeset,
                :rates,
                "could not find rate #{payment_currency}-#{price_currency} in #{inspect(rates)}"
              )
            end
        end

      _ ->
        add_error(
          changeset,
          :rates,
          "invalid format"
        )
    end
  end

  defp update_rates(changeset) do
    snapshot = snapshot_rates(changeset)
    put_rates(changeset, snapshot)
  end

  defp put_rates(changeset, rates) do
    now = NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)

    changeset
    |> put_change(:rates, rates)
    |> put_change(:rates_updated_at, now)
  end

  defp snapshot_rates(%Changeset{valid?: false}) do
    # Implementation is easier if we can assume that we have currencies correctly setup.
    %{}
  end

  defp snapshot_rates(changeset) do
    price_currency = get_field(changeset, :price).currency
    payment_currency_id = get_field(changeset, :payment_currency_id)

    if price_currency == payment_currency_id do
      # Specified in crypto, no need for exchange rates
      # (one could maybe generate exchange rates between crypto, but that's a task for another day).
      %{}
    else
      rates = ExchangeRates.fetch_exchange_rates(payment_currency_id, price_currency)

      if Enum.empty?(rates) do
        if payment_currency_id do
          Logger.warning(
            "No rates found in Invoices with #{payment_currency_id}-#{price_currency}"
          )
        else
          Logger.warning("No rates found in Invoices for #{price_currency}")
        end
      end

      InvoiceRates.bundle_rates(rates)
    end
  end

  defp validate_payment_currency(changeset) do
    payment_currency = get_field(changeset, :payment_currency_id)

    cond do
      payment_currency == nil ->
        changeset

      Currencies.is_crypto(payment_currency) ->
        changeset

      true ->
        add_error(
          changeset,
          :payment_currency_id,
          "must be a cryptocurrency"
        )
    end
  end

  defp validate_expected_payment(changeset) do
    # This is a bit of a complex validation and does a few things:
    # - validates that we have a supported exchange rate for the priced currency
    # - if we also have a payment currency, that we have a matching exchange rate
    # - calculates expected payment if we find a rate
    # - as a special case allows us to ignore exchange rates if we specify the price in crypto
    price = get_field(changeset, :price)
    payment_currency = get_field(changeset, :payment_currency_id)
    rates = get_field(changeset, :rates)

    cond do
      price == nil ->
        # No price, error is handled elsewhere.
        changeset

      Currencies.is_crypto(price.currency) ->
        if payment_currency == price.currency do
          # Price is in crypto, exchange rates doesn't matter.
          put_change(changeset, :expected_payment, price)
        else
          # Avoid duplicate errors from `assoc_payment_currency`.
          if ApiHelpers.has_error?(changeset, :price, :same_price_error) do
            changeset
          else
            add_same_price_error(changeset, price.currency, payment_currency)
          end
        end

      changeset.valid? && payment_currency == nil ->
        # No payment currency yet, we just need to check that the currency price exists anywhere in rates.
        if fiat_in_rates?(rates, price.currency) do
          changeset
        else
          add_error(
            changeset,
            :price,
            "unsupported fiat currency without matching exchange rate"
          )
        end

      rates == nil ->
        # This is an error, but it's handled by `validate_rates`
        changeset

      changeset.valid? ->
        # Both currencies exists, so we can even calculate the expected_payment here.
        case calculate_expected_payment(price, payment_currency, rates) do
          {:ok, expected_payment} ->
            put_change(changeset, :expected_payment, expected_payment)

          {:error, msg} ->
            add_error(
              changeset,
              :rates,
              msg
            )
        end

      true ->
        changeset
    end
  end

  defp fiat_in_rates?(rates, fiat) do
    Enum.any?(rates, fn {_crypto, quotes} ->
      Enum.any?(quotes, fn
        {^fiat, _} -> true
        _ -> false
      end)
    end)
  end

  defp get_param(params, key) when is_atom(key) do
    params[key] || params[Atom.to_string(key)]
  end

  defp validate_email(changeset) do
    changeset
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> validate_length(:email, max: 160)
  end

  defp ensure_required_confirmations(changeset) do
    cond do
      get_field(changeset, :required_confirmations) ->
        changeset

      currency = get_field(changeset, :payment_currency_id) ->
        put_change(
          changeset,
          :required_confirmations,
          StoreSettings.get_required_confirmations(changeset.data.store_id, currency)
        )

      true ->
        changeset
    end
  end

  defp validate_required_confirmations(changeset) do
    changeset
    |> validate_number(:required_confirmations, greater_than_or_equal_to: 0)
  end
end
