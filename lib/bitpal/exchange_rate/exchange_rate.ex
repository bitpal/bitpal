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
           rate: calculate_rate(a, b),
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
        {:ok, a, calculate_quote(exchange_rate.rate, a, ex_b)}

      {nil, %Money{currency: ^ex_b}} ->
        {:ok, calculate_base(exchange_rate.rate, ex_a, b), b}

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

  @spec calculate_base(Decimal.t(), atom, Money.t()) :: Money.t()
  def calculate_base(rate, base_id, xquote) do
    Money.parse!(
      Decimal.div(Money.to_decimal(xquote), rate),
      base_id
    )
  end

  @spec calculate_quote(Decimal.t(), Money.t(), atom) :: Money.t()
  def calculate_quote(rate, base, quote_id) do
    Money.parse!(
      Decimal.mult(rate, Money.to_decimal(base)),
      quote_id
    )
  end

  @spec calculate_rate(Money.t(), Money.t()) :: Decimal.t()
  def calculate_rate(base, xquote) do
    Decimal.div(Money.to_decimal(xquote), Money.to_decimal(base))
  end

  @spec eq?(t, t) :: boolean
  def eq?(a, b) do
    a.pair == b.pair && Decimal.eq?(a.rate, b.rate)
  end

  @spec basecurrency(t) :: Currency.id()
  def basecurrency(rate) do
    elem(rate.pair, 0)
  end

  @spec currency(t) :: Currency.id()
  def currency(rate) do
    elem(rate.pair, 1)
  end

  # Parsing

  @spec parse_pair(binary | {atom | String.t(), atom | String.t()}) ::
          {:ok, pair} | {:error, :bad_pair}
  def parse_pair(pair) when is_binary(pair) do
    case String.split(pair, "-") do
      [base, xquote] ->
        parse_pair({base, xquote})

      _ ->
        {:error, :bad_pair}
    end
  end

  def parse_pair({base, xquote}) do
    {:ok, base} = Currencies.cast(base)
    {:ok, xquote} = Currencies.cast(xquote)
    {:ok, {base, xquote}}
  rescue
    _ ->
      {:error, :bad_pair}
  end
end
