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
          required_confirmations: non_neg_integer
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
    |> cast(params, [:amount, :fiat_amount, :exchange_rate, :required_confirmations])
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
    |> validate_change(key, fn ^key, val ->
      List.flatten([
        currency_exists?.(val.a),
        currency_exists?.(val.b),
        non_neg_dec(key, val.rate)
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

  def render_qrcode(invoice, opts \\ []) do
    invoice
    |> address_with_meta
    |> EQRCode.encode()
    |> EQRCode.svg(opts)
  end

  @doc """
  Encodes amount, label and message into a [BIP-21 URI](https://github.com/bitcoin/bips/blob/master/bip-0021.mediawiki):

      bitcoin:<address>[?amount=<amount>][?label=<label>][?message=<message>]

  """
  # @spec address_with_meta(t) :: address
  def address_with_meta(invoice) do
    uri_encode(uri_address(invoice.address), uri_query(invoice))
  end

  defp uri_encode(address, ""), do: address
  defp uri_encode(address, query), do: address <> "?" <> query

  defp uri_address(address = "bitcoincash:" <> _), do: address
  defp uri_address(address), do: "bitcoincash:" <> address

  defp uri_query(request) do
    %{"amount" => request.amount, "label" => request.label, "message" => request.message}
    |> encode_query
  end

  @spec encode_query(Enum.t()) :: binary
  def encode_query(enumerable) do
    enumerable
    |> Enum.filter(fn {_key, value} -> value && value != "" end)
    |> Enum.map_join("&", &encode_kv_pair/1)
  end

  defp encode_kv_pair({key, value}) do
    URI.encode(Kernel.to_string(key)) <> "=" <> URI.encode(Kernel.to_string(value))
  end
end
