defmodule BitPalWeb.StoreAddressesLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias Phoenix.HTML

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "show" do
    test "show address with invoice", %{conn: conn, store: store, currency_id: currency_id} do
      invoice =
        create_invoice(store.id,
          curency_id: currency_id,
          status: :open,
          address: :auto
        )

      {:ok, _view, html} = live(conn, Routes.store_addresses_path(conn, :show, store.slug))
      assert html =~ store.label |> HTML.html_escape() |> HTML.safe_to_string()
      assert html =~ invoice.address_id
    end

    test "show address without invoice", %{conn: conn, store: store, currency_id: currency_id} do
      address_key = get_or_create_address_key(store.id, currency_id)
      address = create_address(address_key)

      {:ok, _view, html} = live(conn, Routes.store_addresses_path(conn, :show, store.slug))
      assert html =~ store.label |> HTML.html_escape() |> HTML.safe_to_string()
      assert html =~ address.id
    end
  end

  describe "updates" do
    test "add address when invoice created & finalized", %{
      conn: conn,
      store: store,
      currency_id: currency_id
    } do
      {:ok, view, html} = live(conn, Routes.store_addresses_path(conn, :show, store.slug))
      assert html =~ "There are no addresses here yet"

      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      assert render_eventually(view, invoice.address_id)
    end

    test "update invoice status", %{conn: conn, store: store, currency_id: currency_id} do
      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          currency_id: currency_id,
          status: :draft
        )

      {:ok, view, html} = live(conn, Routes.store_addresses_path(conn, :show, store.slug))

      invoice =
        invoice
        |> with_address()
        |> finalize_and_track()

      assert render_eventually(view, "open")
      assert render_eventually(view, invoice.address_id)

      BackendMock.tx_seen(invoice)
      render_eventually(view, "processing")

      BackendMock.confirmed_in_new_block(invoice)
      render_eventually(view, "processing")

      BackendMock.issue_blocks(currency_id, 2)
      render_eventually(view, "paid")
    end

    test "add incoming tx", %{conn: conn, store: store, currency_id: currency_id} do
    end
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} =
        live(conn, Routes.store_addresses_path(conn, :show, other_store))
    end
  end
end
