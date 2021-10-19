defmodule BitPalApi.CurrencyControllerTest do
  use BitPalApi.ConnCase

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
    a = create_invoice!(conn, address: :auto)
    b = create_invoice!(conn, address: :auto)

    # Should not show up
    _ = create_invoice!(address: :auto)
    _ = create_invoice!(currency: :LTC, address: :auto)

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
end
