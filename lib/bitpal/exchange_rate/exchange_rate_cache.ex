defmodule BitPal.ExchangeRateCache do
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateEvents
  alias BitPalSchemas.Currency
  alias BitPalSettings.ExchangeRateSettings

  defmodule Rate do
    @type t :: %__MODULE__{
            prio: non_neg_integer,
            source: module(),
            rate: ExchangeRate.t(),
            updated: NaiveDateTime.t()
          }

    defstruct [:prio, :source, :rate, :updated]
  end

  @spec update_exchange_rate(module, Rate.t()) :: :ok
  def update_exchange_rate(cache \\ __MODULE__, rate) do
    Cache.update(cache, rate.rate.pair, fn existing ->
      broadcast_raw_change(rate.rate.pair)
      cache_update(existing, rate)
    end)
  end

  defp cache_update(nil, rate) do
    # First rate of this pair
    broadcast_updated_rate(rate)
    {:ok, [rate]}
  end

  defp cache_update(existing, rate) do
    existing = filter_expired(existing)

    # If the source exists, we should replace it, otherwise insert it sorted.
    # Having it all be list based may seem inefficient, but the count will be low as
    # I don't expect us to have a lot of sources.
    replace_i = Enum.find_index(existing, fn stored -> stored.source == rate.source end)

    if replace_i do
      if replace_i == 0 do
        # This is the highest prio source, issue an updated event.
        broadcast_updated_rate(rate)
      end

      # An existing source is here, replace it.
      {:ok, List.replace_at(existing, replace_i, rate)}
    else
      # First source, insert it sorted.
      insert_i = Enum.find_index(existing, fn stored -> rate.prio > stored.prio end)

      if insert_i == 0 do
        # This is the highest prio source, issue an updated event.
        broadcast_updated_rate(rate)
      end

      if insert_i do
        {:ok, List.insert_at(existing, insert_i, rate)}
      else
        {:ok, Enum.reverse([rate | existing])}
      end
    end
  end

  defp broadcast_updated_rate(rate) do
    ExchangeRateEvents.broadcast({{:exchange_rate, :update}, rate.rate})
  end

  defp broadcast_raw_change(pair) do
    ExchangeRateEvents.broadcast_raw({{:exchange_rate, :raw_update}, pair})
  end

  @spec fetch_raw_exchange_rates(term, ExchangeRate.pair()) :: {:ok, [Rate.t()]} | :error
  def fetch_raw_exchange_rates(cache \\ __MODULE__, pair) do
    case Cache.fetch(cache, pair) do
      {:ok, rates} ->
        {:ok, filter_expired(rates)}

      _ ->
        :error
    end
  end

  @spec fetch_raw_exchange_rate(term, ExchangeRate.pair()) :: {:ok, Rate.t()} | :error
  def fetch_raw_exchange_rate(cache \\ __MODULE__, pair) do
    case fetch_raw_exchange_rates(cache, pair) do
      {:ok, [rate | _rest]} ->
        {:ok, rate}

      _ ->
        :error
    end
  end

  @spec fetch_exchange_rate(term, ExchangeRate.pair()) :: {:ok, ExchangeRate.t()} | :error
  def fetch_exchange_rate(cache \\ __MODULE__, pair) do
    case fetch_raw_exchange_rate(cache, pair) do
      {:ok, %{rate: rate}} -> {:ok, rate}
      :error -> :error
    end
  end

  @spec fetch_exchange_rates_with_base(term, Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates_with_base(name \\ __MODULE__, base) do
    all_exchange_rates(name)
    |> Enum.filter(fn
      %ExchangeRate{pair: {^base, _}} -> true
      _ -> false
    end)
  end

  @spec all_raw_exchange_rates(term) :: [Rate.t()]
  def all_raw_exchange_rates(cache \\ __MODULE__) do
    Cache.all(cache)
    |> Enum.flat_map(fn {_key, val} -> val end)
    |> filter_expired()
  end

  @spec all_exchange_rates(term) :: [ExchangeRate.t()]
  def all_exchange_rates(cache \\ __MODULE__) do
    all_raw_exchange_rates(cache)
    |> Enum.map(fn rate -> rate.rate end)
  end

  @spec delete_all(term) :: true
  def delete_all(cache \\ __MODULE__) do
    Cache.delete_all(cache)
  end

  @spec start_link(ConCache.options()) :: Supervisor.on_start()
  def start_link(opts) do
    Cache.start_link(
      name: Keyword.get(opts, :name, __MODULE__),
      ttl_check_interval: false,
      global_ttl: :infinity
    )
  end

  @spec child_spec(keyword) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec filter_expired([Rate.t()]) :: [Rate.t()]
  def filter_expired(
        rates,
        now \\ NaiveDateTime.utc_now(),
        ttl \\ ExchangeRateSettings.rates_ttl()
      ) do
    Enum.filter(rates, fn rate ->
      not expired?(rate, now, ttl)
    end)
  end

  @spec expired?(Rate.t(), NaiveDateTime.t()) :: boolean
  def expired?(rate, now \\ NaiveDateTime.utc_now(), ttl \\ ExchangeRateSettings.rates_ttl()) do
    NaiveDateTime.diff(now, rate.updated, :millisecond) > ttl
  end
end
