defmodule BitPal.Invoices do
  import Ecto.Changeset
  import Ecto.Query
  alias BitPal.Addresses
  alias BitPal.Blocks
  alias BitPal.Currencies
  alias BitPal.ExchangeRate
  alias BitPal.FSM
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Currency
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.TxOutput
  require Decimal

  @type register_params :: %{
          amount: Money.t(),
          fiat_amount: Money.t(),
          exchange_rate: ExchangeRate.t(),
          required_confirmations: non_neg_integer,
          description: String.t()
        }

  @spec register(register_params) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def register(params) do
    %Invoice{}
    |> cast(params, [:amount, :fiat_amount, :exchange_rate, :required_confirmations, :description])
    |> validate_amount(:amount)
    |> validate_amount(:fiat_amount)
    |> validate_exchange_rate(:exchange_rate)
    |> validate_into_matching_pairs()
    |> with_default_lazy(:required_confirmations, fn ->
      Application.fetch_env!(:bitpal, :required_confirmations)
    end)
    |> assoc_currency()
    |> Repo.insert()
  end

  @spec fetch(Invoice.id()) :: {:ok, Invoice.t()} | :error
  def fetch(id) do
    invoice =
      from(i in Invoice, where: i.id == ^id)
      |> Repo.one()

    if invoice do
      {:ok, invoice}
    else
      :error
    end
  rescue
    _ -> :error
  end

  @spec fetch!(Invoice.id()) :: Invoice.t()
  def fetch!(id) do
    case fetch(id) do
      {:ok, invoice} -> invoice
      _ -> raise("invoice #{id} not found!")
    end
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

  @spec active_addresses(Currency.id()) :: [Address.t()]
  def active_addresses(currency_id) do
    Invoice
    |> with_status([:open, :processing])
    |> with_currency(currency_id)
    |> select([i], i.address_id)
    |> Repo.all()
  end

  @spec open_addresses(Currency.id()) :: [Address.t()]
  def open_addresses(currency_id) do
    Invoice
    |> with_status(:open)
    |> with_currency(currency_id)
    |> select([i], i.address_id)
    |> Repo.all()
  end

  @spec all_open() :: [Invoice.t()]
  def all_open do
    Invoice
    |> with_status(:open)
    |> select([i], i)
    |> Repo.all()
  end

  @spec is_address_open?(Address.t()) :: boolean
  def is_address_open?(address_id) do
    "invoices"
    |> with_status(:open)
    |> with_address(address_id)
    |> Repo.exists?()
  end

  defp with_status(query, statuses) when is_list(statuses) do
    Enum.reduce(statuses, query, fn status, query ->
      from(i in query, or_where: i.status == ^Atom.to_string(status))
    end)
  end

  defp with_status(query, status) do
    from(i in query, where: i.status == ^Atom.to_string(status))
  end

  defp with_currency(query, currency_id) do
    from(i in query, where: i.currency_id == ^Currencies.normalize(currency_id))
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
    curr_height = Blocks.get_block_height(invoice.currency_id)

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

  @spec update_amount_paid(Invoice.t()) :: Invoice.t()
  def update_amount_paid(invoice) do
    invoice = Repo.preload(invoice, :tx_outputs, force: true)
    %{invoice | amount_paid: calculate_amount_paid(invoice)}
  end

  @spec calculate_amount_paid(Invoice.t()) :: Money.t()
  def calculate_amount_paid(invoice) do
    invoice.tx_outputs
    |> Enum.reduce(Money.new(0, invoice.currency_id), fn tx, sum ->
      Money.add(tx.amount, sum)
    end)
  end

  @spec delete(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def delete(invoice) do
    if finalized?(invoice) do
      change(invoice)
      |> add_error(:status, "cannot delete a finalized invoice")
    else
      Repo.delete(invoice)
    end
  end

  @spec finalize!(Invoice.t()) :: Invoice.t()
  def finalize!(invoice) do
    {:ok, invoice} = finalize(invoice)
    invoice
  end

  @spec finalize(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def finalize(invoice) do
    FSM.transition_changeset(invoice, :open)
    |> validate_required([
      :amount,
      :fiat_amount,
      :currency_id,
      :required_confirmations
    ])
    |> Repo.update()
  end

  @spec process(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def process(invoice) do
    transition(invoice, :processing)
  end

  @spec process!(Invoice.t()) :: Invoice.t()
  def process!(invoice) do
    {:ok, invoice} = process(invoice)
    invoice
  end

  @spec double_spent(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def double_spent(invoice) do
    # Double spend state can be seen from transactions
    transition(invoice, :uncollectible)
  end

  @spec expire(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def expire(invoice) do
    # Timeout can be calculated from transaction timestamp
    transition(invoice, :uncollectible)
  end

  @spec invalidate(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def invalidate(invoice) do
    transition(invoice, :uncollectible)
  end

  @spec void(Invoice.t()) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def void(invoice) do
    transition(invoice, :void)
  end

  @spec pay!(Invoice.t()) :: Invoice.t()
  def pay!(invoice) do
    case target_amount_reached?(invoice) do
      :underpaid ->
        raise "target amount not reached"

      _ ->
        FSM.transition_changeset(invoice, :paid)
        |> Repo.update!()
    end
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

  defp validate_exchange_rate(changeset, key) do
    currency_exists? = fn cur ->
      if Money.Currency.exists?(cur) do
        []
      else
        [{key, "money #{cur} doesn't exish"}]
      end
    end

    changeset
    |> validate_change(key, fn ^key, %ExchangeRate{rate: rate, pair: {a, b}} ->
      List.flatten([
        currency_exists?.(a),
        currency_exists?.(b),
        non_neg_dec(key, rate)
      ])
    end)
  end

  defp validate_amount(changeset, key) do
    changeset
    |> validate_change(key, fn
      ^key, val ->
        non_neg_dec(key, val.amount)
    end)
  end

  defp non_neg_dec(key, val) do
    if Decimal.lt?(val, Decimal.new(0)) do
      [{key, "cannot be negative"}]
    else
      []
    end
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

  defp assoc_currency(changeset) do
    amount = get_field(changeset, :amount)

    if amount && amount.currency do
      changeset
      |> change(%{currency_id: Currencies.normalize(amount.currency)})
      |> assoc_constraint(:currency)
    else
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
