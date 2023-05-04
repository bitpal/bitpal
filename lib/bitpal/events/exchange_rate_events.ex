defmodule BitPal.ExchangeRateEvents do
  @moduledoc """
  Exchange rate update events.
  """

  alias BitPal.EventHelpers
  alias BitPalSchemas.ExchangeRate
  alias BitPalSchemas.InvoiceRates

  @type msg :: {{:exchange_rate, :update}, InvoiceRates.t()}
  @type raw_msg :: {{:exchange_rate, :raw_update}, ExchangeRate.bundled()}

  @spec subscribe :: :ok | {:error, term}
  def subscribe, do: EventHelpers.subscribe(topic())

  @spec subscribe_raw :: :ok | {:error, term}
  def subscribe_raw, do: EventHelpers.subscribe(topic_raw())

  @spec broadcast(msg) :: :ok | {:error, term}
  def broadcast(msg) do
    EventHelpers.broadcast(topic(), msg)
  end

  @spec broadcast_raw(raw_msg) :: :ok | {:error, term}
  def broadcast_raw(msg) do
    EventHelpers.broadcast(topic_raw(), msg)
  end

  @spec topic :: binary
  defp topic do
    "exchange_rate"
  end

  @spec topic_raw :: binary
  defp topic_raw do
    "exchange_rate:raw"
  end
end
