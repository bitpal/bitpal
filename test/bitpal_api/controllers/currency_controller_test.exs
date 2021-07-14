defmodule BitPalApi.CurrencyControllerTest do
  use BitPalApi.ConnCase
  alias BitPal.Addresses
  alias BitPal.Invoices

  @backends [
    {BitPal.BackendMock, name: Bitcoin.Backend, currency: :BCH},
    {BitPal.BackendMock, name: Litecoin.Backend, currency: :LTC}
  ]

  @tag backends: @backends
  test "list available", %{conn: conn} do
    conn = get(conn, "/v1/currencies")

    assert ["BCH", "LTC"] = json_response(conn, 200)
  end

  @tag backends: @backends
  test "show", %{conn: conn} do
    a = invoice(:BCH)
    b = invoice(:BCH)

    conn = get(conn, "/v1/currencies/BCH")

    assert %{
             "addresses" => addresses,
             "code" => "BCH",
             "name" => "Bitcoin Cash",
             "invoices" => invoices,
             "status" => "ok"
           } = json_response(conn, 200)

    assert length(invoices) == 2
    assert a.id in invoices
    assert b.id in invoices

    assert length(addresses) == 2
    assert a.address_id in addresses
    assert b.address_id in addresses
  end

  defp invoice(currency) do
    {:ok, invoice} =
      %{
        amount: 1.2,
        exchange_rate: 2.0,
        currency: currency,
        fiat_currency: "USD"
      }
      |> Invoices.register()

    {:ok, address} = Addresses.register_next_address(currency, generate_address_id())
    {:ok, invoice} = Invoices.assign_address(invoice, address)
    Invoices.finalize!(invoice)
  end
end
