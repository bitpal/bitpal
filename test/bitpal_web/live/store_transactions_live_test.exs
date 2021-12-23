defmodule BitPalWeb.StoreTransacionsLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock
  alias BitPal.Blocks
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias BitPal.Repo
  alias Phoenix.HTML

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "show" do
    test "show tx with invoice", %{conn: conn, store: store, currency_id: currency_id} do
      invoice =
        create_invoice(store,
          status: :paid,
          address: :auto
        )
        |> with_txs()
        |> Repo.preload(address: :tx_outputs)

      {:ok, _view, html} = live(conn, Routes.store_transactions_path(conn, :show, store.slug))
      assert html =~ store.label |> HTML.html_escape() |> HTML.safe_to_string()
      assert html =~ invoice.address_id
    end
  end

  describe "update" do
    test "add tx", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, html} = live(conn, Routes.store_transactions_path(conn, :show, store.slug))
      assert html =~ "There are no transactions here yet"

      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      BackendMock.tx_seen(invoice)

      assert render_eventually(view, invoice.address_id)
    end

    test "update tx confirmed height", %{conn: conn, store: store, currency_id: currency_id} do
      height = Faker.random_between(0, 1_000)

      :ok = Blocks.set_block_height(currency_id, height)

      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      BackendMock.tx_seen(invoice)

      {:ok, view, html} = live(conn, Routes.store_transactions_path(conn, :show, store.slug))
      render_eventually(view, "Unconfirmed", ".confirmed_height")

      BackendMock.confirmed_in_new_block(invoice)
      render_eventually(view, Integer.to_string(height + 1), ".confirmed_height")
    end
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} =
        live(conn, Routes.store_transactions_path(conn, :show, other_store))
    end
  end
end
