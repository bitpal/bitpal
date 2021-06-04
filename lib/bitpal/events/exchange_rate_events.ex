defmodule BitPal.ExchangeRateEvents do
  alias BitPal.EventHelpers
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor
  alias BitPal.ExchangeRateSupervisor.Result

  @spec subscribe(ExchangeRate.pair(), keyword) :: :ok | {:error, term}
  def subscribe(pair, opts \\ []) do
    case EventHelpers.subscribe(topic(pair)) do
      :ok ->
        ExchangeRateSupervisor.async_request(pair, opts)
        :ok

      err ->
        err
    end
  end

  @spec unsubscribe(ExchangeRate.pair()) :: :ok
  def unsubscribe(pair) do
    EventHelpers.unsubscribe(topic(pair))
  end

  @spec broadcast(ExchangeRate.pair(), Result.t()) :: :ok | {:error, term}
  def broadcast(pair, res) do
    EventHelpers.broadcast(topic(pair), {:exchange_rate, res.rate})
  end

  defp topic({from, to}) do
    Atom.to_string(__MODULE__) <> Atom.to_string(from) <> Atom.to_string(to)
  end
end
