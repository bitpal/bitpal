defmodule BitPalApi.ExchangeRateController do
  use BitPalApi, :controller
  alias BitPal.Currencies
  alias BitPal.ExchangeRate
  alias BitPal.ExchangeRates

  def index(conn, _) do
    rates =
      ExchangeRates.all_exchange_rates()
      |> Enum.group_by(
        fn %ExchangeRate{pair: {base, _}} -> base end,
        fn v -> v end
      )

    render(conn, "index.json", rates: rates)
  end

  def base(conn, %{"base" => base}) do
    base = cast_currency!(base, "base")
    rates = ExchangeRates.fetch_exchange_rates_with_base(base)

    if Enum.any?(rates) do
      render(conn, "show.json", base: base, rates: rates)
    else
      raise NotFoundError,
        param: "base",
        message: "Exchange rate for `#{base}` not found"
    end
  end

  def pair(conn, %{"base" => base, "quote" => xquote}) do
    with base <- cast_currency!(base, "base"),
         xquote <- cast_currency!(xquote, "quote"),
         {:ok, rate} <- ExchangeRates.fetch_exchange_rate({base, xquote}) do
      render(conn, "show.json", rate: rate)
    else
      _ ->
        raise NotFoundError,
          param: "pair",
          message:
            "Exchange rate for pair `#{String.upcase(base)}-#{String.upcase(xquote)}` not found"
    end
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
