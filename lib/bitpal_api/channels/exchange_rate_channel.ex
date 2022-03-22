defmodule BitPalApi.ExchangeRateChannel do
  use BitPalApi, :channel
  alias BitPal.Currencies
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateEvents
  alias BitPal.ExchangeRates
  alias BitPalApi.ExchangeRateView
  require Logger

  @impl true
  def join("exchange_rate", _payload, socket) do
    ExchangeRateEvents.subscribe()
    {:ok, socket}
  end

  @impl true
  def handle_info({{:exchange_rate, :update}, rate}, socket) do
    broadcast!(socket, "updated_exchange_rate", ExchangeRateView.render("show.json", rate: rate))
    {:noreply, socket}
  end

  @impl true
  def handle_in(event, params, socket) do
    handle_event(event, params, socket)
  rescue
    error -> {:reply, {:error, render_error(error)}, socket}
  end

  def handle_event("get", %{"base" => base, "quote" => xquote}, socket) do
    with base <- cast_currency!(base, "base"),
         xquote <- cast_currency!(xquote, "quote"),
         {:ok, rate} <- ExchangeRates.fetch_exchange_rate({base, xquote}) do
      {:reply, {:ok, ExchangeRateView.render("show.json", rate: rate)}, socket}
    else
      _ ->
        raise NotFoundError,
          param: "pair",
          message:
            "Exchange rate for pair `#{String.upcase(base)}-#{String.upcase(xquote)}` not found"
    end
  end

  def handle_event("get", %{"base" => base}, socket) do
    base = cast_currency!(base, "base")
    rates = ExchangeRates.fetch_exchange_rates_with_base(base)

    if Enum.any?(rates) do
      {:reply, {:ok, ExchangeRateView.render("show.json", base: base, rates: rates)}, socket}
    else
      raise NotFoundError,
        param: "base",
        message: "Exchange rate for `#{base}` not found"
    end
  end

  def handle_event("get", _params, socket) do
    rates =
      ExchangeRates.all_exchange_rates()
      |> Enum.group_by(
        fn %ExchangeRate{pair: {base, _}} -> base end,
        fn v -> v end
      )

    {:reply, {:ok, ExchangeRateView.render("index.json", rates: rates)}, socket}
  end

  def handle_event(event, _params, socket) do
    Logger.error("unhandled event #{event}")
    {:noreply, socket}
  end

  defp cast_currency!(currency, param) do
    case Currencies.cast(currency) do
      {:ok, id} ->
        id

      _ ->
        raise RequestFailedError,
          param: param,
          message: "Currency `#{currency}` is invalid or not supported",
          code: "invalid_currency"
    end
  end
end
