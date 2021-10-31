defmodule BitPalApi.CurrencyControllerTest do
  use BitPalApi.ConnCase, async: true

  @backends [
    BitPal.BackendMock,
    BitPal.BackendMock
  ]

  @tag backends: @backends
  test "list available", %{conn: conn, currencies: currencies} do
    conn = get(conn, "/v1/currencies")
    gotten_currencies = Enum.into(json_response(conn, 200), MapSet.new())

    # Note that we're testing this async, so there will be a lot more currency backends available
    # as the async tests share the same manager.
    # This just checks that the unique currencies for this particular test are shown.
    for currency_id <- currencies do
      assert !(currency_id in gotten_currencies),
             "Did not list a currency #{currency_id}, got: #{inspect(gotten_currencies)}"
    end
  end

  @tag backends: @backends
  test "show", %{conn: conn, currencies: [c0, c1]} do
    a = InvoiceFixtures.invoice_fixture(conn, address: :auto, currency_id: c0)
    b = InvoiceFixtures.invoice_fixture(conn, address: :auto, currency_id: c0)

    # Should not show up
    _ = InvoiceFixtures.invoice_fixture(address: :auto)
    _ = InvoiceFixtures.invoice_fixture(currency_id: c1, address: :auto)

    conn = get(conn, "/v1/currencies/#{c0}")

    c0s = to_string(c0)

    assert %{
             "addresses" => addresses,
             "code" => ^c0s,
             "name" => "Testcrypto" <> _num,
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
