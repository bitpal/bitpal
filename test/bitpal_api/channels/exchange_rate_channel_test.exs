defmodule BitPalApi.ExchangeRateChannelTest do
  use BitPalApi.ChannelCase

  @rate Decimal.from_float(815.27)

  setup do
    {:ok, _, socket} =
      BitPalApi.StoreSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(BitPalApi.ExchangeRateChannel, "exchange_rate:BCH-USD")

    %{socket: socket}
  end

  test "async request", %{socket: socket} do
    push(socket, "async_request", %{"from" => "BCH", "to" => "USD"})
    assert_broadcast("rate", %{rate: @rate})
  end

  test "sync request", %{socket: socket} do
    ref = push(socket, "request", %{"from" => "BCH", "to" => "USD"})
    assert_reply(ref, :ok, %{rate: @rate})
  end

  test "invalid currency", %{socket: socket} do
    ref = push(socket, "request", %{"from" => "XXX", "to" => "USD"})

    assert_reply(ref, :error, %{
      message: "Invalid exchange rate 'XXX-USD'",
      type: "invalid_request_error"
    })
  end
end
