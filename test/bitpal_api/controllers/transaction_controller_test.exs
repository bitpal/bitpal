defmodule BitPalApi.TransactionControllerTest do
  use BitPalApi.ConnCase
  alias BitPalApi.Authentication.BasicAuth

  test "index", %{conn: conn} do
    {:ok, store_id} = BasicAuth.parse(conn)
    _ = txs(store_id, 3)

    other_store = StoreFixtures.store_fixture()
    _ = txs(other_store.id, 1)

    conn = get(conn, "/v1/transactions/")
    assert txs = json_response(conn, 200)
    assert length(txs) == 3
  end

  @tag do: true
  test "show", %{conn: conn} do
    {:ok, store_id} = BasicAuth.parse(conn)
    [txid] = txs(store_id, 1)

    conn = get(conn, "/v1/transactions/#{txid}")
    assert %{"txid" => ^txid, "amount" => "1.00000000", "address" => _} = json_response(conn, 200)
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
    other_store = StoreFixtures.store_fixture()
    [txid] = txs(other_store.id, 1)

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

  defp txs(store_id, count) do
    Enum.map(1..count, fn amount ->
      create_transaction!(store_id: store_id, amount: amount)
    end)
  end
end
