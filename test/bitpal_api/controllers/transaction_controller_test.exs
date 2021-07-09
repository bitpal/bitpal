defmodule BitPalApi.TransactionControllerTest do
  use BitPalApi.ConnCase, async: true
  alias BitPal.Addresses
  alias BitPal.Transactions

  test "index", %{conn: conn} do
    _ = txs(3)
    conn = get(conn, "/v1/transactions/")
    assert txs = json_response(conn, 200)
    assert length(txs) == 3
  end

  test "show", %{conn: conn} do
    [txid] = txs(1)
    conn = get(conn, "/v1/transactions/#{txid}")
    assert %{"txid" => ^txid, "amount" => "1.0", "address" => _} = json_response(conn, 200)
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

  defp txs(count) do
    Enum.map(1..count, fn amount ->
      txid = generate_txid()
      address_id = generate_address_id()
      {:ok, _} = Addresses.register_next_address(:BCH, address_id)
      :ok = Transactions.seen(txid, [{address_id, Money.parse!(amount, :BCH)}])
      txid
    end)
  end
end
