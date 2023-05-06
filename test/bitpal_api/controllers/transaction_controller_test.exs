defmodule BitPalApi.TransactionControllerTest do
  use BitPalApi.ConnCase, async: true, integration: true
  alias BitPal.Stores
  alias BitPalApi.Authentication.BasicAuth

  setup tags = %{conn: conn} do
    {:ok, store_id} = BasicAuth.parse(conn)
    store = Stores.fetch!(store_id)
    Map.put(tags, :store, store)
  end

  test "index", %{conn: conn, store: store, currency_id: currency_id} do
    create_invoice(store, status: :open)
    |> with_txs(tx_count: 2, currency_id: currency_id)

    create_store()
    |> with_invoices(txs: :auto, payment_currency_id: currency_id)

    conn = get(conn, "/api/v1/transactions/")
    assert txs = json_response(conn, 200)
    assert length(txs) == 2
  end

  test "show", %{conn: conn, store: store, currency_id: currency_id} do
    tx = create_tx(store, currency_id: currency_id)
    txid = tx.txid
    amount = tx.amount.amount

    conn = get(conn, "/api/v1/transactions/#{txid}")

    assert %{"txid" => ^txid, "outputDisplay" => _, "outputSubAmount" => ^amount, "address" => _} =
             json_response(conn, 200)
  end

  test "not found", %{conn: conn} do
    {_, _, response} =
      assert_error_sent(404, fn ->
        get(conn, "/api/v1/transactions/not-found")
      end)

    assert %{
             "type" => "invalid_request_error",
             "code" => "resource_missing",
             "param" => "txid",
             "message" => _
           } = Jason.decode!(response)
  end

  test "tx to other store not found", %{conn: conn, currency_id: currency_id} do
    other_store = create_store()
    tx = create_tx(other_store, currency_id: currency_id)
    txid = tx.txid

    {_, _, response} =
      assert_error_sent(404, fn ->
        get(conn, "/api/v1/transactions/#{txid}")
      end)

    assert %{
             "type" => "invalid_request_error",
             "code" => "resource_missing",
             "param" => "txid",
             "message" => _
           } = Jason.decode!(response)
  end
end
