defmodule Payments.ExchangeRate do
  use GenServer
  alias Payments.ExchangeRate.Kraken
  alias Payments.ExchangeRate.Cache
  alias Phoenix.PubSub
  require Logger

  @pubsub Payments.PubSub

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{rate: nil}, name: __MODULE__)
  end

  def request(pair = {:bch, :usd}) do
    GenServer.cast(__MODULE__, {:compute, pair})
  end

  def require(pair = {:bch, :usd}) do
    GenServer.call(__MODULE__, {:compute, pair})
  end

  def subscribe, do: PubSub.subscribe(@pubsub, topic())

  def unsubscribe, do: PubSub.unsubscribe(@pubsub, topic())

  defp broadcast(pair, rate) do
    PubSub.broadcast(@pubsub, topic(), {:exchange_rate, pair, rate})
  end

  defp topic, do: Atom.to_string(__MODULE__)

  @impl true
  def init(state) do
    children = [
      Payments.ExchangeRate.Cache
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Payments.ExchangeRate.Supervisor)

    {:ok, state}
  end

  @impl true
  def handle_cast({:compute, pair}, %{rate: last_rate}) do
    rate = get_rate(pair, last_rate)

    {:noreply, %{rate: rate}}
  end

  @impl true
  def handle_call({:compute, pair}, _, %{rate: last_rate}) do
    rate = get_rate(pair, last_rate)

    {:reply, rate, %{rate: rate}}
  end

  defp get_rate(pair, last_rate) do
    case compute(pair, last_rate) do
      nil ->
        nil

      rate ->
        # Internally we store them as floats, but we expose them as Decimal to the outside world
        rate = Decimal.from_float(rate)
        broadcast(pair, rate)
        rate
    end
  end

  defp compute(pair, last_rate) do
    case Cache.fetch(pair) do
      {:ok, rate} ->
        Logger.info("Cached exchange rate #{inspect(pair)} #{rate}")
        rate

      :error ->
        # Safeguard against exchange rate source being down after we've cleared the cache
        # then serve the last rate we've found.
        rate = get_rate(pair) || last_rate
        Cache.put(pair, rate)
        rate
    end
  end

  defp get_rate(pair) do
    try do
      Kraken.compute(pair)
    catch
      _ -> nil
    end
  end
end
