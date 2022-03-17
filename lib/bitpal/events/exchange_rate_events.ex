defmodule BitPal.ExchangeRateEvents do
  @moduledoc """
  Exchange rate update events.
  """

  alias BitPal.EventHelpers
  alias BitPal.ExchangeRate

  @type msg :: {{:exchange_rate, :update}, ExchangeRate.t()}

  @spec subscribe :: :ok | {:error, term}
  def subscribe, do: EventHelpers.subscribe(topic())

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg) do
    EventHelpers.broadcast(topic(), msg)
  end

  @spec topic :: binary
  defp topic do
    "exchange_rate"
  end
end
