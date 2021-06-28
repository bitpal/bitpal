defmodule BitPal.ExchangeRate do
  alias BitPal.Currencies
  alias BitPalSchemas.Currency

  @type pair :: {Currency.id(), Currency.id()}
  @type t :: %__MODULE__{
          rate: Decimal.t(),
          pair: pair
        }

  defstruct [:rate, :pair]

  # Creation

  @spec new!(Money.t(), Money.t()) :: t
  @spec new!(Decimal.t(), pair) :: t
  def new!(x, y) do
    case new(x, y) do
      {:ok, res} -> res
      _ -> raise ArgumentError, "invalid params to ExchangeRate.new"
    end
  end

  @spec new(Decimal.t(), pair) :: {:ok, t} | :error
  def new(_, {a, a}) do
    :error
  end

  def new(rate, {a, b}) do
    with false <- Decimal.lt?(rate, Decimal.new(0)),
         {:ok, a} <- Currencies.cast(a),
         {:ok, b} <- Currencies.cast(b) do
      {:ok,
       %__MODULE__{
         rate: rate,
         pair: {a, b}
       }}
    else
      _ -> :error
    end
  end

  @spec new(Money.t(), Money.t()) :: {:ok, t} | :error
  def new(a, b) do
    cond do
      a.currency == b.currency ->
        :error

      Money.zero?(a) ->
        :error

      true ->
        {:ok,
         %__MODULE__{
           rate: Decimal.div(Money.to_decimal(b), Money.to_decimal(a)),
           pair: {a.currency, b.currency}
         }}
    end
  end

  # Handling

  @spec normalize(t, Money.t(), Money.t()) ::
          {:ok, Money.t(), Money.t()}
          | {:error, :mismatched_exchange_rate}
          | {:error, :bad_params}
  def normalize(exchange_rate, a, b) do
    {ex_a, ex_b} = exchange_rate.pair

    case {a, b} do
      {%Money{currency: ^ex_a}, nil} ->
        {:ok, a,
         Money.parse!(
           Decimal.mult(exchange_rate.rate, Money.to_decimal(a)),
           elem(exchange_rate.pair, 1)
         )}

      {nil, %Money{currency: ^ex_b}} ->
        {:ok,
         Money.parse!(
           Decimal.div(Money.to_decimal(b), exchange_rate.rate),
           elem(exchange_rate.pair, 0)
         ), b}

      {%Money{currency: ^ex_b}, %Money{currency: ^ex_a}} ->
        normalize(exchange_rate, b, a)

      {%Money{currency: ^ex_a}, %Money{currency: ^ex_b}} ->
        case new(a, b) do
          {:ok, rate} ->
            if eq?(exchange_rate, rate) do
              {:ok, a, b}
            else
              {:error, :mismatched_exchange_rate}
            end

          _ ->
            {:error, :bad_params}
        end

      _ ->
        {:error, :bad_params}
    end
  end

  @spec eq?(t, t) :: boolean
  def eq?(a, b) do
    a.pair == b.pair && Decimal.eq?(a.rate, b.rate)
  end
end
