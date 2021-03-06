defmodule BitPal.InvoiceActionsTest do
  use BitPal.IntegrationCase, async: true

  setup tags do
    %{invoice: create_invoice(tags)}
  end

  @tag status: :draft
  test "transitions", %{invoice: invoice} do
    assert invoice.status == :draft

    # Must have an address when finalizing
    assert {:error, _} = Invoices.finalize(invoice)

    assert {:ok, invoice} = Invoices.finalize(%{invoice | address_id: unique_address_id()})
    assert invoice.status == :open
    assert invoice.status_reason == nil

    x = Invoices.double_spent!(invoice)
    assert x.status == :uncollectible
    assert x.status_reason == :double_spent

    x = Invoices.expire!(invoice)
    assert x.status == :uncollectible
    assert x.status_reason == :expired

    x = Invoices.cancel!(invoice)
    assert x.status == :uncollectible
    assert x.status_reason == :canceled

    x = Invoices.timeout!(invoice)
    assert x.status == :uncollectible
    assert x.status_reason == :timed_out
  end

  @tag address_id: :auto, status: :open, required_confirmations: 0
  test "verifying", %{invoice: invoice} do
    invoice = Invoices.process!(invoice)
    assert invoice.status == :processing
    assert invoice.status_reason == :verifying
  end

  @tag address_id: :auto, status: :open, required_confirmations: 3
  test "confirming", %{invoice: invoice} do
    invoice = Invoices.process!(invoice)
    assert invoice.status == :processing
    assert invoice.status_reason == :confirming
  end
end
