defmodule BitPalFactory.Invoices do
  alias BitPal.Invoices
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Address

  def assign_address(invoice = %Invoice{}, address = %Address{}) do
    {:ok, _} = Invoices.assign_address(invoice, address)
    invoice
  end
end
