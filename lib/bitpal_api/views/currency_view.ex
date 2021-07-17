defmodule BitPalApi.CurrencyView do
  use BitPalApi, :view

  def render("index.json", %{currencies: currencies}) do
    Enum.map(currencies, &Atom.to_string/1)
  end

  def render("show.json", %{
        currency_id: currency_id,
        status: status,
        addresses: addresses,
        invoices: invoices
      }) do
    %{
      code: Atom.to_string(currency_id),
      name: Money.Currency.name!(currency_id),
      addresses:
        Enum.map(addresses, fn address ->
          address.id
        end),
      status: Atom.to_string(status),
      invoices:
        Enum.map(invoices, fn invoice ->
          invoice.id
        end)
    }
  end
end
