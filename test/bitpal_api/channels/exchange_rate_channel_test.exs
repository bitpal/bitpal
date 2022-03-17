defmodule BitPalApi.ExchangeRateChannelTest do
  # This must be async: false, otherwise mailbox might be cleared by other tests.
  # Maybe we could solve this somehow...
  use BitPalApi.ChannelCase, async: false
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateSupervisor
  alias BitPal.ExchangeRate.Sources.Empty

  setup do
    {:ok, _, socket} =
      BitPalApi.StoreSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(BitPalApi.ExchangeRateChannel, "exchange_rate")

    cache = ExchangeRateSupervisor.cache_name()
    ExchangeRateCache.delete_all(cache)

    %{socket: socket, cache: cache}
  end

  test "get rate update", %{cache: cache} do
    rate = cache_rate(pair: {:DGC, :XXX}, source: Empty, prio: 1_000)
    ExchangeRateCache.update_exchange_rate(cache, rate)

    dec = rate.rate.rate
    assert_broadcast "updated_exchange_rate", %{base: "DGC", quote: "XXX", rate: ^dec}
  end

  test "get all", %{socket: socket, cache: cache} do
    usd_rate = cache_rate(pair: {:DGC, :USD}, source: Empty, prio: 1_000)
    eur_rate = cache_rate(pair: {:DGC, :EUR}, source: Empty, prio: 1_000)
    ExchangeRateCache.update_exchange_rate(cache, usd_rate)
    ExchangeRateCache.update_exchange_rate(cache, eur_rate)

    ref = push(socket, "get", %{})

    usd_rate = usd_rate.rate.rate
    eur_rate = eur_rate.rate.rate

    assert_reply(ref, :ok, [
      %{
        base: "DGC",
        rates: %{
          "USD" => ^usd_rate,
          "EUR" => ^eur_rate
        }
      }
    ])
  end

  test "get base", %{socket: socket, cache: cache} do
    usd_rate = cache_rate(pair: {:DGC, :USD}, source: Empty, prio: 1_000)
    eur_rate = cache_rate(pair: {:DGC, :EUR}, source: Empty, prio: 1_000)
    ExchangeRateCache.update_exchange_rate(cache, usd_rate)
    ExchangeRateCache.update_exchange_rate(cache, eur_rate)

    ref = push(socket, "get", %{"base" => "DGC"})

    usd_rate = usd_rate.rate.rate
    eur_rate = eur_rate.rate.rate

    assert_reply(ref, :ok, %{
      base: "DGC",
      rates: %{
        "USD" => ^usd_rate,
        "EUR" => ^eur_rate
      }
    })
  end

  test "get pair", %{socket: socket, cache: cache} do
    rate = cache_rate(pair: {:DGC, :USD}, source: Empty, prio: 1_000)
    ExchangeRateCache.update_exchange_rate(cache, rate)

    ref = push(socket, "get", %{"base" => "DGC", "quote" => "USD"})
    dec = rate.rate.rate
    assert_reply(ref, :ok, %{base: "DGC", quote: "USD", rate: ^dec})
  end

  test "get not found base", %{socket: socket} do
    ref = push(socket, "get", %{"base" => "BTC"})

    assert_reply(
      ref,
      :error,
      {:error,
       %{
         message: "Exchange rate for `BTC` not found",
         param: "base",
         type: "invalid_request_error",
         code: "resource_missing"
       }}
    )
  end

  test "get not found pair", %{socket: socket} do
    ref = push(socket, "get", %{"base" => "BTC", "quote" => "SEK"})

    assert_reply(
      ref,
      :error,
      {:error,
       %{
         message: "Exchange rate for pair `BTC-SEK` not found",
         param: "pair",
         type: "invalid_request_error",
         code: "resource_missing"
       }}
    )
  end

  test "get bad base", %{socket: socket} do
    ref = push(socket, "get", %{"base" => "XXX"})

    assert_reply(
      ref,
      :error,
      {:error,
       %{
         message: "Currency `XXX` is invalid or not supported",
         param: "base",
         type: "invalid_request_error",
         code: "invalid_currency"
       }}
    )
  end

  test "get bad pair base", %{socket: socket} do
    ref = push(socket, "get", %{"base" => "XXX", "quote" => "SEK"})

    assert_reply(
      ref,
      :error,
      {:error,
       %{
         message: "Currency `XXX` is invalid or not supported",
         param: "base",
         type: "invalid_request_error",
         code: "invalid_currency"
       }}
    )
  end

  test "get bad pair quote", %{socket: socket} do
    ref = push(socket, "get", %{"base" => "BTC", "quote" => "XXX"})

    assert_reply(
      ref,
      :error,
      {:error,
       %{
         message: "Currency `XXX` is invalid or not supported",
         param: "quote",
         type: "invalid_request_error",
         code: "invalid_currency"
       }}
    )
  end
end
