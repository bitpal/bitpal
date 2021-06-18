defmodule BitPalApi.InvoiceView do
  use BitPalApi, :view
  alias BitPalSchemas.Invoice

  def render("show.json", %{invoice: invoice = %Invoice{}}) do
    # IO.puts(binding())

    %{
      id: invoice.id,
      amount: Money.to_decimal(invoice.amount),
      currency: invoice.currency_id,
      fiat_amount: Money.to_decimal(invoice.fiat_amount),
      fiat_currency: invoice.fiat_amount.currency,
      address: invoice.address_id,
      status: invoice.status,
      required_confirmations: invoice.required_confirmations
    }
  end
end
