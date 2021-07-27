defmodule BitPalApi.ExchangeRateController do
  use BitPalApi, :controller
  alias BitPal.Currencies
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRateSupervisor

  def index(conn, %{"basecurrency" => from}) do
    with {:ok, basecurrency} <- Currencies.cast(from),
         {:ok, supported} <- ExchangeRateSupervisor.supported(basecurrency) do
      # NOTE we need to request many rates, but then our backend might get hung up...
      # For this to be efficient we should have a task that keeps it up to date instead of us polling
      # Or combine rate requests into a single request
      rates =
        supported
        |> Enum.map(fn currency ->
          ExchangeRateSupervisor.request({basecurrency, currency})
          currency
        end)
        |> Enum.flat_map(fn currency ->
          if rate = ExchangeRateSupervisor.await_request!({basecurrency, currency}) do
            [rate]
          else
            []
          end
        end)

      render(conn, "index.json", rates: rates)
    else
      _ ->
        raise NotFoundError, param: "basecurrency"
    end
  end

  def show(conn, %{"basecurrency" => from, "currency" => to}) do
    case ExchangeRate.parse_pair({from, to}) do
      {:ok, pair} ->
        rate = ExchangeRateSupervisor.fetch!(pair)
        render(conn, "show.json", rate: rate)

      _ ->
        raise NotFoundError, param: "basecurrency"
    end
  end
end
