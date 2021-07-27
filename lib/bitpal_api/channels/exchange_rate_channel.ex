defmodule BitPalApi.ExchangeRateChannel do
  use BitPalApi, :channel
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor
  alias BitPalApi.ExchangeRateView
  require Logger

  @impl true
  def join("exchange_rate:" <> pair, payload, socket) do
    with :authorized <- authorized?(payload),
         {:ok, _pair} <- ExchangeRate.parse_pair(pair) do
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
  def handle_in("rate", %{"from" => from, "to" => to}, socket) do
    case ExchangeRate.parse_pair({from, to}) do
      {:ok, pair} ->
        handle_rate_request(pair, socket)

      {:error, :bad_pair} ->
        {:reply, invalid_exchange_rate_error(from, to), socket}
    end
  end

  @impl true
  def handle_in(event, _params, socket) do
    Logger.error("unhandled event #{event}")
    {:noreply, socket}
  end

  defp handle_rate_request(pair, socket) do
    case ExchangeRateSupervisor.request(pair) do
      # We have a cached rate, we can reply directly
      {:cached, rate} ->
        {:reply, response(rate)}

      # We need to update the exchange rate, reply in an async manner
      :updating ->
        Task.Supervisor.start_child(
          BitPal.TaskSupervisor,
          __MODULE__,
          :reply_request,
          [pair, socket_ref(socket)]
        )

        {:noreply, socket}
    end
  end

  def reply_request(pair, ref) do
    rate = ExchangeRateSupervisor.await_request!(pair)
    reply(ref, response(rate))
  end

  defp response(rate) do
    {:ok, ExchangeRateView.render("rate_response.json", %{rate: rate})}
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
