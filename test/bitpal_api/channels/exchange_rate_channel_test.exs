defmodule BitPalApi.ExchangeRateChannelTest do
  use BitPalApi.ChannelCase, async: true, integration: false
  alias BitPal.ExchangeRates

  setup do
    {:ok, reply, socket} =
      BitPalApi.StoreSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(BitPalApi.ExchangeRateChannel, "exchange_rates")

    c1 = unique_currency_id()
    %{socket: socket, c1: c1, reply: reply}
  end

  describe "getting" do
    test "get rate update", %{c1: c1} do
      rate = ExchangeRates.update_exchange_rate(rate_params(base: c1, quote: :USD))

      dec = Decimal.to_float(rate.rate)
      assert_broadcast "updated_exchange_rate", %{^c1 => %{USD: ^dec}}
    end

    test "get all", %{socket: socket, c1: c1} do
      usd_rate = ExchangeRates.update_exchange_rate(rate_params(base: c1, quote: :USD))
      eur_rate = ExchangeRates.update_exchange_rate(rate_params(base: c1, quote: :EUR))

      ref = push(socket, "get", %{})

      usd_rate = Decimal.to_float(usd_rate.rate)
      eur_rate = Decimal.to_float(eur_rate.rate)

      assert_reply(ref, :ok, %{
        ^c1 => %{
          :USD => ^usd_rate,
          :EUR => ^eur_rate
        }
      })
    end

    test "get base", %{socket: socket, c1: c1} do
      usd_rate = ExchangeRates.update_exchange_rate(rate_params(base: c1, quote: :USD))
      eur_rate = ExchangeRates.update_exchange_rate(rate_params(base: c1, quote: :EUR))

      ref = push(socket, "get", %{"base" => Atom.to_string(c1)})

      usd_rate = Decimal.to_float(usd_rate.rate)
      eur_rate = Decimal.to_float(eur_rate.rate)

      assert_reply(ref, :ok, %{
        ^c1 => %{
          :USD => ^usd_rate,
          :EUR => ^eur_rate
        }
      })
    end

    test "get pair", %{socket: socket, c1: c1} do
      rate = ExchangeRates.update_exchange_rate(rate_params(base: c1, quote: :USD))

      ref = push(socket, "get", %{"base" => Atom.to_string(c1), "quote" => "USD"})
      dec = Decimal.to_float(rate.rate)
      assert_reply(ref, :ok, %{^c1 => %{:USD => ^dec}})
    end

    test "get not found base", %{socket: socket, c1: c1} do
      ref = push(socket, "get", %{"base" => Atom.to_string(c1)})

      msg = "Exchange rate for `#{c1}` not found"

      assert_reply(
        ref,
        :error,
        {:error,
         %{
           message: ^msg,
           param: "base",
           type: "invalid_request_error",
           code: "resource_missing"
         }}
      )
    end

    test "get not found pair", %{socket: socket, c1: c1} do
      ref = push(socket, "get", %{"base" => Atom.to_string(c1), "quote" => "SEK"})

      msg = "Exchange rate for pair `#{c1}-SEK` not found"

      assert_reply(
        ref,
        :error,
        {:error,
         %{
           message: ^msg,
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
           message: "is invalid or not supported",
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
           message: "is invalid or not supported",
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
           message: "is invalid or not supported",
           param: "quote",
           type: "invalid_request_error",
           code: "invalid_currency"
         }}
      )
    end
  end

  describe "rate updates" do
    test "update a single rate", %{c1: c1} do
      rate = rate_params(base: c1, rate: Decimal.from_float(1.1))
      ExchangeRates.update_exchange_rate(rate)

      {_, f1} = rate.pair
      dec_rate = Decimal.to_float(rate.rate)

      assert_broadcast("updated_exchange_rate", %{
        ^c1 => %{^f1 => ^dec_rate}
      })
    end

    test "multiple rate updates", %{c1: c1} do
      c2 = unique_currency_id()

      ExchangeRates.update_exchange_rates(
        rates_params(
          rates: %{
            c1 => %{
              SEK: Decimal.from_float(1.0),
              USD: Decimal.from_float(2.0)
            },
            c2 => %{
              SEK: Decimal.from_float(3.0)
            }
          }
        )
      )

      assert_broadcast("updated_exchange_rate", %{
        ^c1 => %{
          SEK: 1.0,
          USD: 2.0
        },
        ^c2 => %{
          SEK: 3.0
        }
      })
    end
  end

  describe "reply on join" do
    test "replies with all rates", %{reply: reply} do
      assert Enum.count(reply) > 0
    end
  end
end
