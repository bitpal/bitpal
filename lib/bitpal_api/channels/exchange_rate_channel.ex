defmodule BitPalApi.ExchangeRateChannel do
  use BitPalApi, :channel
  alias BitPal.Currencies
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateEvents
  alias BitPal.ExchangeRateSupervisor

  @impl true
  def join("exchange_rate:" <> pair, payload, socket) do
    with :ok <- authorized?(payload),
         {:ok, pair} <- parse_pair(pair),
         :ok <- ExchangeRateEvents.subscribe(pair) do
      {:ok, socket}
    else
      _ ->
        render_error(:bad_request)
    end
  end

  @impl true
  def handle_in("async_request", %{"from" => from, "to" => to}, socket) do
    case parse_pair({from, to}) do
      {:ok, pair} ->
        ExchangeRateSupervisor.async_request(pair)
        {:reply, :ok, socket}

      {:error, :invalid_currency} ->
        {:reply, render_error(:bad_request), socket}
    end
  end

  @impl true
  def handle_in("request", %{"from" => from, "to" => to}, socket) do
    with {:ok, pair} <- parse_pair({from, to}),
         {:ok, rate} <- ExchangeRateSupervisor.request(pair) do
      {:reply, {:ok, %{rate: rate.rate}}, socket}
    else
      {:error, _} ->
        {:reply, render_error(:bad_request), socket}
    end
  end

  @impl true
  def handle_info({:exchange_rate, %ExchangeRate{rate: rate, pair: {from, to}}}, socket) do
    broadcast!(socket, "rate", %{rate: rate, pair: "#{from}-#{to}"})
    {:noreply, socket}
  end

  defp authorized?(_payload) do
    :ok
  end

  defp parse_pair(pair) when is_binary(pair) do
    case String.split(pair, "-") do
      [from, to] ->
        parse_pair({from, to})

      _ ->
        {:error, :malformed_pair}
    end
  end

  defp parse_pair({from, to}) do
    {:ok, from} = Currencies.cast(from)
    {:ok, to} = Currencies.cast(to)
    {:ok, {from, to}}
  rescue
    _ ->
      {:error, :invalid_currency}
  end
end
