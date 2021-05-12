defmodule BitPal.Invoices do
  import Ecto.Changeset
  import Ecto.Query, only: [from: 2]
  alias BitPal.Currencies
  alias BitPal.ExchangeRate
  alias BitPal.Repo
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice
  require Decimal

  @type register_params :: %{
          amount: Money.t(),
          fiat_amount: Money.t(),
          exchange_rate: ExchangeRate.t(),
          required_confirmations: non_neg_integer,
          description: String.t()
        }

  @spec get(Invoice.id()) :: Invoice.t() | nil
  def get(id) do
    from(i in Invoice, where: i.id == ^id)
    |> Repo.one()
  end

  @spec fetch!(Invoice.id()) :: Invoice.t()
  def fetch!(id) do
    if invoice = get(id) do
      invoice
    else
      raise("invoice #{id} not found!")
    end
  end

  @spec register(register_params) :: {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def register(params) do
    %Invoice{}
    |> cast(params, [:amount, :fiat_amount, :exchange_rate, :required_confirmations, :description])
    |> validate_amount(:amount)
    |> validate_amount(:fiat_amount)
    |> validate_exchange_rate(:exchange_rate)
    |> validate_into_matching_pairs()
    |> assoc_currency()
    |> Repo.insert()
  end

  @spec assign_address(Invoice.t(), Address.t()) ::
          {:ok, Invoice.t()} | {:error, Ecto.Changeset.t()}
  def assign_address(invoice, address) do
    invoice
    |> Repo.preload(:address)
    |> change
    |> put_assoc(:address, address)
    |> assoc_constraint(:address)
    |> Repo.update()
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
end
