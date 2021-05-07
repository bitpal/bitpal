defmodule BitPal.ExchangeRate do
  alias BitPal.Currencies
  alias BitPal.ExchangeRateSupervisor
  alias Phoenix.PubSub

  @pubsub BitPal.PubSub

  @type pair :: {Currencies.id(), Currencies.id()}
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
         {:ok, a} <- normalize_currency(a),
         {:ok, b} <- normalize_currency(b) do
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

  # Requests

  @spec request(pair(), keyword) :: {:ok, t()} | {:error, term}
  def request(pair, opts \\ []) do
    ExchangeRateSupervisor.request(pair, opts)
  end

  @spec request!(pair(), keyword) :: t()
  def request!(pair, opts \\ []) do
    ExchangeRateSupervisor.request!(pair, opts)
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

  # Subscriptions

  @spec subscribe(ExchangeRate.pair()) :: :ok
  def subscribe(pair, opts \\ []) do
    :ok = PubSub.subscribe(@pubsub, topic(pair))
    ExchangeRateSupervisor.async_request(pair, opts)
    :ok
  end

  @spec unsubscribe(ExchangeRate.pair()) :: :ok
  def unsubscribe(pair) do
    PubSub.unsubscribe(@pubsub, topic(pair))
  end

  @spec broadcast(ExchangeRate.pair(), Result.t()) :: :ok | {:error, term}
  def broadcast(pair, res) do
    PubSub.broadcast(@pubsub, topic(pair), {:exchange_rate, res.rate})
  end

  defp topic({from, to}) do
    Atom.to_string(__MODULE__) <> Atom.to_string(from) <> Atom.to_string(to)
  end

  @spec normalize_currency(Currencies.id()) :: {:ok, atom} | :error
  defp normalize_currency(currency) do
    {:ok, Money.Currency.to_atom(currency)}
  rescue
    _ -> :error
  end
end
