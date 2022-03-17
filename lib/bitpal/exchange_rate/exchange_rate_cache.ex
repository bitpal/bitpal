defmodule BitPal.ExchangeRateCache do
  alias BitPal.Cache
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateEvents

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
    Cache.update(
      cache,
      rate.rate.pair,
      fn
        nil ->
          # First rate we have, issue an updated event.
          broadcast_exchange_rate(rate)

          {:ok, [rate]}

        existing ->
          # If it exists, we should replace it. Otherwise insert it sorted.
          # Having it all be list based may seem inefficient, but the count will be low as
          # I don't expect us to have a lot of exchange rate sources.
          replace_i = Enum.find_index(existing, fn stored -> stored.source == rate.source end)

          if replace_i do
            if replace_i == 0 do
              # This is the highest prio source, issue an updated event.
              broadcast_exchange_rate(rate)
            end

            # An existing source is here, replace it.
            {:ok, List.replace_at(existing, replace_i, rate)}
          else
            # First source, insert it sorted.
            insert_i = Enum.find_index(existing, fn stored -> rate.prio > stored.prio end)

            if insert_i == 0 do
              # This is the highest prio source, issue an updated event.
              broadcast_exchange_rate(rate)
            end

            if insert_i do
              {:ok, List.insert_at(existing, insert_i, rate)}
            else
              {:ok, existing ++ [rate]}
            end
          end
      end
    )
  end

  defp broadcast_exchange_rate(rate) do
    ExchangeRateEvents.broadcast({{:exchange_rate, :update}, rate.rate})
  end

  @spec fetch_raw_exchange_rates(term, ExchangeRate.pair()) :: {:ok, [Rate.t()]} | :error
  def fetch_raw_exchange_rates(cache \\ __MODULE__, pair) do
    Cache.fetch(cache, pair)
  end

  @spec fetch_raw_exchange_rate(term, ExchangeRate.pair()) :: {:ok, Rate.t()} | :error
  def fetch_raw_exchange_rate(cache \\ __MODULE__, pair) do
    case Cache.fetch(cache, pair) do
      # FIXME manual ttl check is needed per source, if we want it
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

  @spec all_raw_exchange_rates(term) :: [ExchangeRate.t()]
  def all_raw_exchange_rates(cache \\ __MODULE__) do
    Cache.all(cache)
    |> Enum.flat_map(fn {_key, val} -> val end)
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
end
