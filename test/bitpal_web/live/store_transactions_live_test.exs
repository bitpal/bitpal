defmodule BitPalWeb.StoreTransacionsLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock
  alias BitPal.Blocks
  alias BitPal.Repo

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "show" do
    @tag skip: true
    test "show tx with invoice", %{conn: conn, store: store} do
      invoice =
        create_invoice(store,
          status: :paid,
          address: :auto
        )
        |> with_txs()
        |> Repo.preload(address: :tx_outputs)

      {:ok, _view, html} = live(conn, ~p"/stores/#{store}/transactions")
      assert html =~ store.label |> html_string()
      assert html =~ invoice.address_id
    end
  end

  describe "update" do
    @tag skip: true
    test "add tx", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, html} = live(conn, ~p"/stores/#{store}/transactions")
      assert html =~ "There are no transactions here yet"

      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          payment_currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      BackendMock.tx_seen(invoice)

      assert render_eventually(view, invoice.address_id)
    end

    @tag skip: true
    test "update tx confirmed height", %{conn: conn, store: store, currency_id: currency_id} do
      height = Faker.random_between(0, 1_000)

      :ok = Blocks.new(currency_id, height)

      invoice =
        create_invoice(
          store_id: store.id,
          required_confirmations: 3,
          payment_currency_id: currency_id,
          status: :draft,
          address: :auto
        )
        |> finalize_and_track()

      BackendMock.tx_seen(invoice)

      {:ok, view, _html} = live(conn, ~p"/stores/#{store}/transactions")
      render_eventually(view, "Unconfirmed", ".tx-status .unconfirmed")

      BackendMock.confirmed_in_new_block(invoice)

      render_eventually(
        view,
        "Block #{Integer.to_string(height + 1)}",
        ".tx-status .block-height"
      )
    end
  end

  describe "security" do
    @tag skip: true
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/stores/#{other_store}/transactions")
    end
  end
end
