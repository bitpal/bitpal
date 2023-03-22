defmodule BitPalApi.ExchangeRateChannel do
  use BitPalApi, :channel
  alias BitPal.ExchangeRateEvents
  alias BitPal.ExchangeRates
  alias BitPalApi.ExchangeRateView
  alias BitPalApi.ExchangeRateHandler
  require Logger

  @impl true
  def join("exchange_rate", _payload, socket) do
    ExchangeRateEvents.subscribe()
    {:ok, socket}
  end

  @impl true
  def handle_info({{:exchange_rate, :update}, rate}, socket) do
    broadcast!(
      socket,
      "updated_exchange_rate",
      ExchangeRateView.render("show.json", rates: [rate])
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
    rate = ExchangeRateHandler.fetch_with_pair!(base, xquote)
    {:reply, {:ok, ExchangeRateView.render("show.json", rates: [rate])}, socket}
  end

  def handle_event("get", %{"base" => base}, socket) do
    rates = ExchangeRateHandler.fetch_with_base!(base)
    {:reply, {:ok, ExchangeRateView.render("show.json", rates: rates)}, socket}
  end

  def handle_event("get", _params, socket) do
    rates = ExchangeRates.all_exchange_rates()
    {:reply, {:ok, ExchangeRateView.render("show.json", rates: rates)}, socket}
  end

  def handle_event(event, _params, socket) do
    Logger.error("unhandled event #{event}")
    {:noreply, socket}
  end
end
