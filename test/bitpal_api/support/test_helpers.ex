defmodule BitPalApi.TestHelpers do
  import BitPal.TestHelpers
  alias BitPalApi.Authentication.BasicAuth

  def create_invoice(context = %{conn: conn}, params) do
    invoice = create_invoice(conn, params)

    context
    |> Map.put_new(:invoice_id, invoice.id)
    |> Map.put_new(:store_id, invoice.store_id)
    |> Map.put_new(:address_id, invoice.address_id)
  end

  def create_invoice(conn = %Plug.Conn{}, params) do
    {:ok, store_id} = BasicAuth.parse(conn)

    params
    |> Keyword.put_new(:store_id, store_id)
    |> create_invoice()
  end
end
