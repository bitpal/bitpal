defmodule BitPalApi.ExchangeRateChannel do
  use BitPalApi, :channel
  import BitPalApi.ExchangeRateJSON
  alias BitPal.ExchangeRateEvents
  alias BitPal.ExchangeRates
  alias BitPalApi.ExchangeRateHandling
  require Logger

  @impl true
  def join("exchange_rates", _payload, socket) do
    ExchangeRateEvents.subscribe()
    rates = ExchangeRates.all_exchange_rates()
    {:ok, show(%{rates: rates}), socket}
  end

  @impl true
  def handle_info({{:exchange_rate, :update}, rates}, socket) do
    broadcast!(
      socket,
      "updated_exchange_rate",
      show(%{rates: rates})
    )

    {:noreply, socket}
  end

  @impl true
  def handle_in(event, params, socket) do
    handle_event(event, params, socket)
  rescue
    error -> {:reply, {:error, render_error(error)}, socket}
  end

  def handle_event("get", %{"base" => base, "quote" => xquote}, socket) do
    rate = ExchangeRateHandling.fetch_with_pair!(base, xquote)
    {:reply, {:ok, show(%{rate: rate})}, socket}
  end

  def handle_event("get", %{"base" => base}, socket) do
    rates = ExchangeRateHandling.fetch_with_base!(base)
    {:reply, {:ok, show(%{rates: rates})}, socket}
  end

  def handle_event("get", _params, socket) do
    rates = ExchangeRates.all_exchange_rates()
    {:reply, {:ok, show(%{rates: rates})}, socket}
  end

  def handle_event(event, _params, socket) do
    Logger.error("unhandled event #{event}")
    {:noreply, socket}
  end
end
