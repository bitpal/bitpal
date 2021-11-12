defmodule BitPalApi.TransactionControllerTest do
  use BitPalApi.ConnCase, async: true
  alias BitPalApi.Authentication.BasicAuth

  test "index", %{conn: conn} do
    {:ok, store_id} = BasicAuth.parse(conn)
    _ = TransactionFixtures.generate_txs(store_id, 3)

    other_store = insert(:store)
    _ = TransactionFixtures.generate_txs(other_store.id, 1)

    conn = get(conn, "/v1/transactions/")
    assert txs = json_response(conn, 200)
    assert length(txs) == 3
  end

  @tag do: true
  test "show", %{conn: conn} do
    {:ok, store_id} = BasicAuth.parse(conn)

    [txid] = TransactionFixtures.generate_txs(store_id, 1)

    conn = get(conn, "/v1/transactions/#{txid}")
    assert %{"txid" => ^txid, "amount" => _, "address" => _} = json_response(conn, 200)
  end

  test "not found", %{conn: conn} do
    {_, _, response} =
      assert_error_sent(404, fn ->
        get(conn, "/v1/transactions/not-found")
      end)

    assert %{
             "type" => "invalid_request_error",
             "code" => "resource_missing",
             "param" => "txid",
             "message" => _
           } = Jason.decode!(response)
  end

  test "tx to other store not found", %{conn: conn} do
    other_store = insert(:store)
    [txid] = TransactionFixtures.generate_txs(other_store.id, 1)

    {_, _, response} =
      assert_error_sent(404, fn ->
        get(conn, "/v1/transactions/#{txid}")
      end)

    assert %{
             "type" => "invalid_request_error",
             "code" => "resource_missing",
             "param" => "txid",
             "message" => _
           } = Jason.decode!(response)
  end
end
