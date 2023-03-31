defmodule BitPal.ExchangeRates do
  import Ecto.Query
  alias BitPal.ExchangeRateEvents
  alias BitPalSchemas.ExchangeRate
  alias BitPal.Repo
  alias BitPalSchemas.Currency
  alias BitPalSettings.ExchangeRateSettings
  require Logger

  # Rate

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

  # Rates

  @spec update_exchange_rate(%{
          pair: ExchangeRate.pair(),
          rate: Decimal.t(),
          source: module(),
          prio: non_neg_integer
        }) :: ExchangeRate.t()
  def update_exchange_rate(%{
        pair: {base, xquote},
        rate: rate,
        source: source,
        prio: prio
      }) do
    update_exchange_rate({base, xquote}, rate, source, prio)
  end

  @spec update_exchange_rate(ExchangeRate.pair(), Decimal.t(), module(), non_neg_integer) ::
          ExchangeRate.t()
  def update_exchange_rate({base, xquote}, rate, source, prio) do
    highest = get_exchange_rate({base, xquote})

    inserted =
      %ExchangeRate{
        base: base,
        quote: xquote,
        source: source,
        prio: prio,
        rate: rate
      }
      |> Repo.insert!(
        on_conflict: :replace_all,
        conflict_target: [:base, :quote, :source]
      )

    ExchangeRateEvents.broadcast_raw({{:exchange_rate, :raw_update}, inserted})

    if !highest || inserted.prio >= highest.prio do
      ExchangeRateEvents.broadcast({{:exchange_rate, :update}, inserted})
    end

    inserted
  end

  @spec all_exchange_rates :: [ExchangeRate.t()]
  def all_exchange_rates do
    ExchangeRate
    |> filter_valid()
    |> Repo.all()
  end

  @spec fetch_exchange_rate(ExchangeRate.pair()) :: {:ok, ExchangeRate.t()} | {:error, :not_found}
  def fetch_exchange_rate(pair) do
    case get_exchange_rate(pair) do
      nil ->
        {:error, :not_found}

      rate ->
        {:ok, rate}
    end
  end

  @spec get_exchange_rate(ExchangeRate.pair()) :: ExchangeRate.t() | nil
  def get_exchange_rate({base, xquote}) do
    from(r in ExchangeRate,
      where: r.base == ^base and r.quote == ^xquote,
      order_by: [desc: r.prio],
      limit: 1
    )
    |> where_not_expired()
    |> Repo.one()
  end

  @spec fetch_exchange_rates_with_base(Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates_with_base(base) do
    from(r in ExchangeRate, where: r.base == ^base)
    |> filter_valid()
    |> Repo.all()
  end

  @spec fetch_exchange_rates_with_quote(Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates_with_quote(xquote) do
    from(r in ExchangeRate, where: r.quote == ^xquote)
    |> filter_valid()
    |> Repo.all()
  end

  @spec fetch_exchange_rates(Currency.id(), Currency.id()) :: [ExchangeRate.t()]
  def fetch_exchange_rates(base, nil) do
    fetch_exchange_rates_with_base(base)
  end

  def fetch_exchange_rates(nil, xquote) do
    fetch_exchange_rates_with_quote(xquote)
  end

  def fetch_exchange_rates(base, xquote) do
    case fetch_exchange_rate({base, xquote}) do
      {:ok, rate} -> [rate]
      _ -> []
    end
  end

  @spec all_unprioritized_exchange_rates() :: [ExchangeRate.t()]
  def all_unprioritized_exchange_rates do
    from(r in ExchangeRate, order_by: [desc: r.prio])
    |> where_not_expired()
    |> Repo.all()
  end

  @spec fetch_unprioritized_exchange_rates(ExchangeRate.pair()) :: [ExchangeRate.t()]
  def fetch_unprioritized_exchange_rates({base, xquote}) do
    from(r in ExchangeRate,
      where: r.base == ^base and r.quote == ^xquote,
      order_by: [desc: r.prio]
    )
    |> where_not_expired()
    |> Repo.all()
  end

  defp filter_valid(query) do
    # What we want to do is:
    # 1. Group all rates into base/quote buckets
    # 2. Only select the rate in each bucket with the highest prio that hasn't expired yet.
    # This is the way I figured out how to do it, other than writing a pure SQL query.
    max_prio =
      from(r in ExchangeRate,
        group_by: [r.base, r.quote],
        select: %{prio: max(r.prio), base: r.base, quote: r.quote}
      )
      |> where_not_expired()

    from(r in query,
      inner_join: p in subquery(max_prio),
      on: r.prio == p.prio and r.base == p.base and r.quote == p.quote
    )
    |> where_not_expired()
  end

  defp where_not_expired(query) do
    # Maybe there's a way to do this calculation on the postgres side, but this
    # works so I'm content.
    now = NaiveDateTime.utc_now()
    ttl = ExchangeRateSettings.rates_ttl()

    expire_at =
      NaiveDateTime.add(now, -ttl, :millisecond)
      |> NaiveDateTime.truncate(:second)

    from(r in query, where: r.updated_at > ^expire_at)
  end

  def expired?(updated_at = %NaiveDateTime{}) do
    now = NaiveDateTime.utc_now()
    ttl = ExchangeRateSettings.rates_ttl()
    valid_until = NaiveDateTime.add(updated_at, ttl, :millisecond)
    NaiveDateTime.compare(valid_until, now) != :lt
  end
end
