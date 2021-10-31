defmodule BitPalWeb.StoreLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock
  alias Phoenix.HTML

  setup tags do
    tags
    |> register_and_log_in_user()
    |> create_store()
  end

  describe "invoice updates" do
    test "show new invoice", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, html} = live(conn, Routes.store_path(conn, :show, store.slug))
      assert html =~ store.label |> HTML.html_escape() |> HTML.safe_to_string()

      assert html =~ "There are no invoices here yet"

      _invoice =
        InvoiceFixtures.invoice_fixture(store.id,
          description: "A draft invoice",
          curency_id: currency_id
        )

      assert render_eventually(view, "A draft invoice")
    end

    test "invoice is updated and finally marked as paid", %{
      conn: conn,
      store: store,
      currency_id: currency_id
    } do
      {:ok, view, _html} = live(conn, Routes.store_path(conn, :show, store))

      {:ok, invoice, _, _} =
        HandlerSubscriberCollector.create_invoice(
          store_id: store.id,
          address: :auto,
          required_confirmations: 3,
          currency_id: currency_id
        )

      render_eventually(view, "open")

      BackendMock.tx_seen(invoice)

      render_eventually(view, "processing")

      BackendMock.confirmed_in_new_block(invoice)

      render_eventually(view, "processing")

      BackendMock.issue_blocks(currency_id, 2)

      render_eventually(view, "paid")
    end
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        AccountFixtures.user_fixture()
        |> StoreFixtures.store_fixture()

      {:error, {:redirect, %{to: "/"}}} = live(conn, Routes.store_path(conn, :show, other_store))
    end
  end
end
