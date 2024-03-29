defmodule BitPalWeb.StoreAddressesLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "show" do
    test "show address with invoice", %{conn: conn, store: store, currency_id: currency_id} do
      invoice =
        create_invoice(store.id,
          payment_curency_id: currency_id,
          status: :open,
          address: :auto
        )

      {:ok, _view, html} = live(conn, ~p"/stores/#{store}/addresses")
      assert html =~ store.label |> html_string()
      assert html =~ invoice.address_id
    end

    test "show address without invoice", %{conn: conn, store: store, currency_id: currency_id} do
      address_key = get_or_create_address_key(store.id, currency_id)
      address = create_address(address_key)

      {:ok, _view, html} = live(conn, ~p"/stores/#{store}/addresses")
      assert html =~ store.label |> html_string()
      assert html =~ address.id
    end
  end

  describe "updates" do
    test "add address when invoice created & finalized", %{
      conn: conn,
      store: store,
      currency_id: currency_id
    } do
      {:ok, view, html} = live(conn, ~p"/stores/#{store}/addresses")
      assert html =~ "There are no addresses here yet"

      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          payment_currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      assert render_eventually(view, invoice.address_id)
    end

    test "add tx", %{conn: conn, store: store, currency_id: currency_id} do
      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          payment_currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      {:ok, view, _html} = live(conn, ~p"/stores/#{store}/addresses")

      txid = BackendMock.tx_seen(invoice)
      render_eventually(view, txid)
    end
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/stores/#{other_store}/addresses")
    end
  end
end
