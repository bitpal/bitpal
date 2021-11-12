defmodule BitPalWeb.InvoiceLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: true
  alias BitPal.BackendMock

  setup tags do
    tags
    |> register_and_log_in_user()
    |> create_store()
    |> create_open_invoice(
      description: "My test invoice",
      address: :auto,
      required_confirmations: Map.get(tags, :required_confirmations, 1)
    )
  end

  describe "invoice updates" do
    @tag do: true
    test "invoice is updated and finally marked as paid", %{
      conn: conn,
      invoice: invoice,
      currency_id: currency_id
    } do
      {:ok, view, html} = live(conn, "/invoices/#{invoice.id}")
      assert html =~ invoice.description

      render_eventually(view, "open")

      BackendMock.tx_seen(invoice)

      render_eventually(view, "processing")

      BackendMock.confirmed_in_new_block(invoice)

      render_eventually(view, "processing")

      BackendMock.issue_blocks(currency_id, 2)

      render_eventually(view, "paid")
    end
  end

  describe "security" do
    test "redirect from other invoice", %{conn: conn} do
      other_invoice = InvoiceFixtures.invoice_fixture()

      {:error, {:redirect, %{to: "/"}}} = live(conn, "/invoices/#{other_invoice.id}")
    end
  end
end
