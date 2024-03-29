defmodule BitPalWeb.StoreLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "invoice updates" do
    test "show new invoice", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, html} = live(conn, ~p"/stores/#{store}/invoices")
      assert html =~ store.label |> html_string()
      assert html =~ "There are no invoices here yet"

      _invoice =
        create_invoice(store.id,
          description: "A draft invoice",
          payment_curency_id: currency_id
        )

      assert render_eventually(view, "A draft invoice")
    end

    test "invoice is updated and finally marked as paid", %{
      conn: conn,
      store: store,
      currency_id: currency_id
    } do
      {:ok, view, _html} = live(conn, ~p"/stores/#{store}/invoices")

      {:ok, invoice, _, _} =
        HandlerSubscriberCollector.create_invoice(
          store_id: store.id,
          address_id: :auto,
          required_confirmations: 3,
          payment_currency_id: currency_id
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
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/stores/#{other_store}/invoices")
    end
  end
end
