defmodule BitPal.ExchangeRateWorkerTest do
  use ExUnit.Case, async: false
  import Mox
  import BitPal.TestHelpers
  alias BitPal.ExchangeRate.MockSource
  alias BitPal.ExchangeRateCache
  alias BitPal.ExchangeRateWorker

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup tags do
    if tags[:fail_first_supported] do
      MockSource
      |> expect(:supported, 1, fn ->
        raise("BOOM!")
      end)
    end

    if tags[:timeout_first_supported] do
      MockSource
      |> expect(:supported, 1, fn ->
        Process.sleep(:infinity)
      end)
    end

    MockSource
    |> expect(:supported, 1, fn ->
      %{
        BCH: MapSet.new([:EUR, :USD]),
        XMR: MapSet.new([:EUR, :USD])
      }
    end)

    request_type = tags[:request_type] || :pair

    MockSource
    |> stub(:request_type, fn -> request_type end)

    MockSource
    |> stub(:rate_limit_settings, fn ->
      %{
        timeframe: 10,
        timeframe_max_requests: 10,
        timeframe_unit: :milliseconds
      }
    end)

    if tags[:fail_first_rates] do
      MockSource
      |> expect(:rates, 1, fn _ ->
        raise("BOOM!")
      end)
    end

    if response = tags[:rates_response] do
      MockSource
      |> expect(:rates, 1, fn _ -> response end)
    end

    if n = tags[:rates_count] do
      MockSource
      |> expect(:rates, n, fn opts -> rates_response(request_type, opts) end)
    else
      MockSource
      |> stub(:rates, fn opts -> rates_response(request_type, opts) end)
    end

    start_supervised!(ExchangeRateCache)

    opts =
      tags
      |> Enum.into([])
      |> Keyword.take([:retry_timeout, :rates_refresh_rate, :supported_refresh_rate])
      |> Keyword.put(:source, MockSource)
      |> Keyword.put(:prio, 50)
      |> Keyword.put(:cache_name, ExchangeRateCache)

    %{
      worker: start_supervised!({ExchangeRateWorker, opts})
    }
  end

  defp rates_response(request_type, opts) do
    case request_type do
      :pair ->
        case {base, xquote} = Keyword.fetch!(opts, :pair) do
          {:BCH, :EUR} -> %{base => %{xquote => Decimal.new("1.1")}}
          {:BCH, :USD} -> %{base => %{xquote => Decimal.new("1.4")}}
          {:XMR, :EUR} -> %{base => %{xquote => Decimal.new("2.1")}}
          {:XMR, :USD} -> %{base => %{xquote => Decimal.new("2.4")}}
        end

      :base ->
        case Keyword.fetch!(opts, :base) do
          :BCH ->
            %{BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")}}

          :XMR ->
            %{XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}}
        end

      :multi ->
        _ = Keyword.fetch!(opts, :base)
        _ = Keyword.fetch!(opts, :quote)

        %{
          BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
          XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
        }
    end
  end

  describe "supported" do
    test "stores supported", %{worker: worker} do
      assert eventually(fn ->
               ExchangeRateWorker.supported(worker) == %{
                 BCH: MapSet.new([:EUR, :USD]),
                 XMR: MapSet.new([:EUR, :USD])
               }
             end)
    end

    @tag fail_first_supported: true, retry_timeout: 10
    test "retries after failure", %{worker: worker} do
      assert eventually(fn ->
               ExchangeRateWorker.supported(worker) == %{
                 BCH: MapSet.new([:EUR, :USD]),
                 XMR: MapSet.new([:EUR, :USD])
               }
             end)
    end

    # Not sure if this is relevant as http requests time out, so we don't need to handle
    # infinitely waiting calls to the plugins.
    #
    # @tag timeout_first_supported: true, retry_timeout: 10
    # test "retries after timeout", %{worker: worker} do
    #   assert eventually(fn ->
    #            ExchangeRateWorker.supported(worker) == %{
    #              BCH: MapSet.new([:EUR, :USD]),
    #              XMR: MapSet.new([:EUR, :USD])
    #            }
    #          end)
    # end
  end

  describe "rate updates" do
    @tag request_type: :pair, rates_count: 4
    test "updates pair", %{worker: worker} do
      assert eventually(fn ->
               ExchangeRateWorker.rates(worker) ==
                 %{
                   BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
                   XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
                 }
             end)
    end

    @tag request_type: :base, rates_count: 2
    test "updates from", %{worker: worker} do
      assert eventually(fn ->
               ExchangeRateWorker.rates(worker) ==
                 %{
                   BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
                   XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
                 }
             end)
    end

    @tag request_type: :multi, rates_count: 1
    test "updates multi", %{worker: worker} do
      assert eventually(fn ->
               ExchangeRateWorker.rates(worker) ==
                 %{
                   BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
                   XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
                 }
             end)
    end

    @tag request_type: :multi,
         rates_response: %{BCH: %{EUR: Decimal.new("42")}},
         rates_refresh_rate: 30
    test "rates refreshes", %{worker: worker} do
      # First it returns our custom
      assert eventually(fn ->
               ExchangeRateWorker.rates(worker) == %{BCH: %{EUR: Decimal.new("42")}}
             end)

      # Next time it updates the usual
      assert eventually(fn ->
               ExchangeRateWorker.rates(worker) ==
                 %{
                   BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
                   XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
                 }
             end)
    end

    @tag request_type: :multi, fail_first_rates: true, rates_refresh_rate: 30, retry_timeout: 10
    test "retries after failed rate update", %{worker: worker} do
      assert eventually(fn ->
               ExchangeRateWorker.rates(worker) ==
                 %{
                   BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
                   XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
                 }
             end)
    end
  end
end
