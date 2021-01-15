defmodule Payments.ExchangeRate do
  use GenServer
  alias Payments.ExchangeRate.Kraken
  alias Payments.ExchangeRate.Cache
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{rate: nil}, name: __MODULE__)
  end

  def compute(pair = {:bch, :usd}) do
    GenServer.call(__MODULE__, {:compute, pair})
  end

  @impl true
  def init(state) do
    children = [
      Payments.ExchangeRate.Cache
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Payments.ExchangeRate.Supervisor)

    {:ok, state}
  end

  @impl true
  def handle_call({:compute, pair}, _, %{rate: last_rate}) do
    rate = compute(pair, last_rate)
    {:reply, rate, %{rate: rate}}
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
