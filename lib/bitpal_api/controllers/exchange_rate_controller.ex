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
      rates =
        supported
        |> Enum.map(fn currency ->
          ExchangeRateSupervisor.async_request({basecurrency, currency})
          currency
        end)
        |> Enum.flat_map(fn currency ->
          case ExchangeRateSupervisor.request({basecurrency, currency}) do
            {:ok, rate} -> [rate]
            _ -> []
          end
        end)

      render(conn, "index.json", rates: rates)
    else
      _ ->
        raise NotFoundError, param: "basecurrency"
    end
  end

  def show(conn, %{"basecurrency" => from, "currency" => to}) do
    with {:ok, pair} <- ExchangeRate.parse_pair({from, to}),
         {:ok, rate} <- ExchangeRateSupervisor.request(pair) do
      render(conn, "show.json", rate: rate)
    else
      _ ->
        raise NotFoundError, param: "basecurrency"
    end
  end
end
