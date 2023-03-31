defmodule BitPalSchemas.InvoiceRates do
  use Ecto.Type
  alias BitPalSchemas.ExchangeRate
  alias BitPalSchemas.Currency
  require Logger

  @type t :: %{Currency.t() => %{Currency.t() => Decimal.t()}}

  # Utility functions

  @doc """
    Transforms a list of exchange rates into a map of maps, like so:

      %{
        base_currency => %{
          c0 => Decimal<1.0>,
          c1 => Decimal<2.3>
        }, ...
      }

  """
  @spec bundle_rates([ExchangeRate.t()]) :: t
  def bundle_rates(rates) do
    rates
    |> Enum.group_by(
      fn %ExchangeRate{base: base} -> base end,
      fn v -> v end
    )
    |> Map.new(fn {base, quotes} ->
      {base,
       Map.new(quotes, fn rate ->
         {rate.quote, rate.rate}
       end)}
    end)
  end

  @spec has_rate?(t, Currency.id(), Currency.id()) :: boolean
  def has_rate?(rates, base, xquote) do
    get_rate(rates, base, xquote) != nil
  end

  @spec get_rate(t, Currency.id(), Currency.id()) :: Decimal.t() | nil
  def get_rate(rates, base, xquote) do
    if quotes = Map.get(rates, base) do
      Map.get(quotes, xquote)
    else
      nil
    end
  end

  @spec find_quote_with_rate(t, Currency.id()) :: {Currency.id(), Decimal.t()} | :not_found
  def find_quote_with_rate(rates, base) do
    case Map.fetch(rates, base) do
      {:ok, quotes} ->
        quotes
        |> Enum.into([])
        |> List.first(:not_found)

      _ ->
        :not_found
    end
  end

  @spec find_base_with_rate(t, Currency.id()) :: {Currency.id(), Decimal.t()} | :not_found
  def find_base_with_rate(rates, xquote) do
    Enum.find_value(rates, :not_found, fn {base, quotes} ->
      rate =
        Enum.find_value(quotes, fn
          {^xquote, rate} -> rate
          _ -> nil
        end)

      if rate do
        {base, rate}
      else
        :not_found
      end
    end)
  end

  @spec find_any_rate(t) :: {Currency.id(), Currency.id(), Decimal.t()} | :not_found
  def find_any_rate(rates) do
    case rates |> Enum.into([]) |> List.first(:not_found) do
      {base, quotes} ->
        case quotes |> Enum.into([]) |> List.first(:not_found) do
          {xquote, rate} ->
            {base, xquote, rate}

          err ->
            err
        end

      err ->
        err
    end
  end

  @spec to_float(t) :: %{Currency.t() => %{Currency.t() => float}}
  def to_float(rates) do
    Enum.reduce(rates, %{}, fn {base, quotes}, acc ->
      Map.put(
        acc,
        base,
        Enum.reduce(quotes, %{}, fn {xquote, rate}, acc ->
          Map.put(acc, xquote, Decimal.to_float(rate))
        end)
      )
    end)
  end

  # Ecto impl

  @impl true
  def type, do: :map

  @impl true
  def cast(data) when is_map(data) do
    {:ok,
     Enum.map(data, fn {base, quotes} ->
       {
         Money.Currency.to_atom(base),
         Enum.map(quotes, fn {xquote, rate} ->
           {Money.Currency.to_atom(xquote), cast_rate!(rate)}
         end)
         |> Map.new()
       }
     end)
     |> Map.new()}
  rescue
    _ -> :error
  end

  def cast(_), do: :error

  def cast_rate!(x) do
    x
    |> cast_decimal!()
    |> ensure_positive!()
  end

  def cast_decimal!(x = %Decimal{}), do: x
  def cast_decimal!(x) when is_binary(x), do: Decimal.new(x)
  def cast_decimal!(x) when is_integer(x), do: Decimal.new(x)
  def cast_decimal!(x) when is_float(x), do: Decimal.from_float(x)

  def ensure_positive!(x) do
    if Decimal.gt?(x, 0) do
      x
    else
      raise("rate must be > 0")
    end
  end

  @impl true
  def load(data) when is_map(data) do
    {:ok,
     Enum.reduce(data, %{}, fn {base, quotes}, acc ->
       Map.put(
         acc,
         String.to_existing_atom(base),
         Enum.reduce(quotes, %{}, fn {xquote, rate}, acc ->
           Map.put(
             acc,
             String.to_existing_atom(xquote),
             cast_rate!(rate)
           )
         end)
       )
     end)}
  end

  @impl true
  def dump(data) when is_map(data) do
    {:ok, to_float(data)}
  end
end
