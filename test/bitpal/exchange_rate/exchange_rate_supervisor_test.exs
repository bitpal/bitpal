defmodule BitPal.ExchangeRateSupervisorTest do
  use BitPal.DataCase, async: false
  use BitPal.CaseHelpers
  import Mox
  alias BitPal.ExchangeRateSupervisor
  alias BitPal.ExchangeRates

  setup :set_mox_from_context
  setup :verify_on_exit!

  setup _tags do
    setup_mock(BitPal.ExchangeRate.MockSource, 1)
    setup_mock(BitPal.ExchangeRate.MockSource2, 2)

    name = unique_server_name()

    start_supervised!(
      {ExchangeRateSupervisor,
       name: name,
       sources: [
         {BitPal.ExchangeRate.MockSource, prio: 50},
         {BitPal.ExchangeRate.MockSource2, prio: 100}
       ]}
    )

    %{name: name}
  end

  defp setup_mock(name, 1) do
    name
    |> expect(:supported, fn ->
      %{
        BCH: MapSet.new([:EUR, :USD]),
        XMR: MapSet.new([:EUR, :SEK])
      }
    end)

    name
    |> stub(:rate_limit_settings, fn ->
      %{
        timeframe: 10,
        timeframe_max_requests: 10,
        timeframe_unit: :milliseconds
      }
    end)

    name
    |> stub(:request_type, fn -> :multi end)

    name
    |> stub(:name, fn -> "Mock" end)

    name
    |> stub(:rates, fn _ ->
      %{
        BCH: %{EUR: Decimal.new("1.1"), USD: Decimal.new("1.4")},
        XMR: %{EUR: Decimal.new("1.15"), SEK: Decimal.new("10")}
      }
    end)
  end

  defp setup_mock(name, 2) do
    name
    |> expect(:supported, fn ->
      %{
        XMR: MapSet.new([:EUR, :USD])
      }
    end)

    name
    |> stub(:rate_limit_settings, fn ->
      %{
        timeframe: 10,
        timeframe_max_requests: 10,
        timeframe_unit: :milliseconds
      }
    end)

    name
    |> stub(:request_type, fn -> :multi end)

    name
    |> stub(:name, fn -> "Mock" end)

    name
    |> stub(:rates, fn _ ->
      %{
        XMR: %{EUR: Decimal.new("2.1"), USD: Decimal.new("2.4")}
      }
    end)
  end

  test "updates rates" do
    dec = Decimal.new("1.1")

    assert eventually(fn ->
             {:ok, %{rate: ^dec}} = ExchangeRates.fetch_exchange_rate({:BCH, :EUR})
           end)

    dec = Decimal.new("2.1")

    assert eventually(fn ->
             {:ok, %{rate: ^dec}} = ExchangeRates.fetch_exchange_rate({:XMR, :EUR})
           end)
  end

  test "all supported", %{name: name} do
    assert eventually(fn ->
             ExchangeRateSupervisor.all_supported(name) ==
               %{
                 BCH: MapSet.new([:EUR, :USD]),
                 XMR: MapSet.new([:EUR, :USD, :SEK])
               }
           end)
  end
end
