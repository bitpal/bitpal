defmodule BitPalWeb.StoreLiveTest do
  use BitPalWeb.ConnCase, integration: true
  alias BitPal.BackendMock

  setup tags do
    tags
    |> register_and_log_in_user()
    |> create_store()
  end

  describe "invoice updates" do
    @tag backends: true
    test "show new invoice", %{conn: conn, store: store} do
      {:ok, view, html} = live(conn, Routes.store_path(conn, :show, store.slug))
      assert html =~ store.label
      assert html =~ "There are no invoices here yet"

      _invoice =
        InvoicesFixtures.invoice_fixture(store.id,
          description: "A draft invoice"
        )

      assert render_eventually(view, "A draft invoice")
    end

    @tag backends: true
    test "invoice is updated and finally marked as paid", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, Routes.store_path(conn, :show, store))

      {:ok, invoice, _, _} =
        HandlerSubscriberCollector.create_invoice(
          store_id: store.id,
          address: :auto,
          required_confirmations: 3
        )

      render_eventually(view, "open")

      BackendMock.tx_seen(invoice)

      render_eventually(view, "processing")

      BackendMock.confirmed_in_new_block(invoice)

      render_eventually(view, "processing")

      BackendMock.issue_blocks(2)

      render_eventually(view, "paid")
    end
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        AccountsFixtures.user_fixture()
        |> StoresFixtures.store_fixture()

      {:error, {:redirect, %{to: "/"}}} = live(conn, Routes.store_path(conn, :show, other_store))
    end
  end
end
