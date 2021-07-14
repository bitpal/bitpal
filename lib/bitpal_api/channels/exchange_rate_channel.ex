defmodule BitPalApi.ExchangeRateChannel do
  use BitPalApi, :channel
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateEvents
  alias BitPal.ExchangeRateSupervisor

  @impl true
  def join("exchange_rate:" <> pair, payload, socket) do
    with :authorized <- authorized?(payload),
         {:ok, pair} <- ExchangeRate.parse_pair(pair),
         :ok <- ExchangeRateEvents.subscribe(pair) do
      {:ok, socket}
    else
      :unauthorized ->
        render_error(%UnauthorizedError{})

      {:error, :bad_pair} ->
        invalid_exchange_rate_error(pair)

      _ ->
        render_error(%InternalServerError{})
    end
  end

  @impl true
  def handle_in("async_request", %{"from" => from, "to" => to}, socket) do
    case ExchangeRate.parse_pair({from, to}) do
      {:ok, pair} ->
        ExchangeRateSupervisor.async_request(pair)
        {:reply, :ok, socket}

      {:error, :bad_pair} ->
        {:reply, invalid_exchange_rate_error(from, to), socket}
    end
  end

  @impl true
  def handle_in("request", %{"from" => from, "to" => to}, socket) do
    with {:ok, pair} <- ExchangeRate.parse_pair({from, to}),
         {:ok, rate} <- ExchangeRateSupervisor.request(pair) do
      {:reply, {:ok, %{rate: rate.rate}}, socket}
    else
      {:error, :bad_pair} ->
        {:reply, invalid_exchange_rate_error(from, to), socket}

      _ ->
        render_error(%InternalServerError{})
    end
  end

  @impl true
  def handle_info({:exchange_rate, %ExchangeRate{rate: rate, pair: {from, to}}}, socket) do
    broadcast!(socket, "rate", %{rate: rate, pair: "#{from}-#{to}"})
    {:noreply, socket}
  end

  defp invalid_exchange_rate_error(from, to) do
    invalid_exchange_rate_error("#{from}-#{to}")
  end

  defp invalid_exchange_rate_error(pair) do
    render_error(%BadRequestError{
      code: "invalid_exchange_rate",
      message: "Invalid exchange rate '#{pair}'"
    })
  end

  defp authorized?(_payload) do
    :authorized
  end
end
