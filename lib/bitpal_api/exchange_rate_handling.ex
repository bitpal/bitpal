defmodule BitPalApi.ExchangeRateHandling do
  use BitPalApi.Errors
  import BitPalApi.ApiHelpers
  alias BitPal.ExchangeRates

  def fetch_with_base!(base) do
    with base <- cast_base!(base),
         rates <- ExchangeRates.fetch_exchange_rates_with_base(base),
         true <- Enum.any?(rates) do
      rates
    else
      _ ->
        raise NotFoundError,
          param: "base",
          message: "Exchange rate for `#{base}` not found"
    end
  end

  def fetch_with_pair!(base, xquote) do
    with base <- cast_base!(base),
         xquote <- cast_quote!(xquote),
         {:ok, rate} <- ExchangeRates.fetch_exchange_rate({base, xquote}) do
      rate
    else
      _ ->
        raise NotFoundError,
          param: "pair",
          message:
            "Exchange rate for pair `#{String.upcase(base)}-#{String.upcase(xquote)}` not found"
    end
  end

  defp cast_base!(id) do
    case cast_crypto(id) do
      {:ok, id} ->
        id

      {:error, msg} ->
        raise RequestFailedError,
          message: msg,
          param: "base",
          code: "invalid_currency"
    end
  end

  defp cast_quote!(id) do
    case cast_currency(id) do
      {:ok, id} ->
        id

      {:error, msg} ->
        raise RequestFailedError,
          message: msg,
          param: "quote",
          code: "invalid_currency"
    end
  end
end
