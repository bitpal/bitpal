defmodule BitPal.ExchangeRate do
  alias BitPal.Currencies
  @type pair :: {Currencies.id(), Currencies.id()}
  @type t :: %__MODULE__{
          rate: Decimal.t(),
          a: atom,
          b: atom
        }

  defstruct [:rate, :a, :b]

  @spec new!(Decimal.t(), pair) :: t
  @spec new!(Money.t(), Money.t()) :: t
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
         {:ok, a} <- normalize_currency(a),
         {:ok, b} <- normalize_currency(b) do
      {:ok,
       %__MODULE__{
         rate: rate,
         a: a,
         b: b
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
           a: a.currency,
           b: b.currency
         }}
    end
  end

  @spec normalize(t, Money.t(), Money.t()) ::
          {:ok, Money.t(), Money.t()}
          | {:error, :mismatched_exchange_rate}
          | {:error, :bad_params}
  def normalize(exchange_rate, a, b) do
    ex_a = exchange_rate.a
    ex_b = exchange_rate.b

    case {a, b} do
      {%Money{currency: ^ex_a}, nil} ->
        {:ok, a,
         Money.parse!(Decimal.mult(exchange_rate.rate, Money.to_decimal(a)), exchange_rate.b)}

      {nil, %Money{currency: ^ex_b}} ->
        {:ok, Money.parse!(Decimal.div(Money.to_decimal(b), exchange_rate.rate), exchange_rate.a),
         b}

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

  def eq?(a, b) do
    a.a == b.a && a.b == b.b && Decimal.eq?(a.rate, b.rate)
  end

  @spec normalize_currency(Currencies.id()) :: {:ok, atom} | :error
  defp normalize_currency(currency) do
    {:ok, Money.Currency.to_atom(currency)}
  rescue
    _ -> :error
  end
end
