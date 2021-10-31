defmodule BitPalApi.ExchangeRateChannelTest do
  # This must be async: false, otherwise mailbox might be cleared by other tests.
  # Maybe we could solve this somehow...
  use BitPalApi.ChannelCase, async: false

  @rate Decimal.from_float(815.27)

  setup do
    {:ok, _, socket} =
      BitPalApi.StoreSocket
      |> socket("user_id", %{some: :assign})
      |> subscribe_and_join(BitPalApi.ExchangeRateChannel, "exchange_rate:BCH-USD")

    %{socket: socket}
  end

  test "async request", %{socket: socket} do
    ref = push(socket, "rate", %{"from" => "BCH", "to" => "USD"})
    assert_reply(ref, :ok, %{rate: @rate})
  end

  test "sync request", %{socket: socket} do
    ref = push(socket, "rate", %{"from" => "BCH", "to" => "USD"})
    assert_reply(ref, :ok, %{rate: @rate})
  end

  test "invalid currency", %{socket: socket} do
    ref = push(socket, "rate", %{"from" => "XXX", "to" => "USD"})

    assert_reply(ref, :error, %{
      message: "Invalid exchange rate 'XXX-USD'",
      type: "invalid_request_error"
    })
  end
end
