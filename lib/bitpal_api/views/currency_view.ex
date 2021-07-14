defmodule BitPalApi.CurrencyView do
  use BitPalApi, :view

  def render("index.json", %{currencies: currencies}) do
    Enum.map(currencies, &Atom.to_string/1)
  end

  def render("show.json", %{currency: currency, status: status}) do
    %{
      code: Atom.to_string(currency.id),
      name: Money.Currency.name!(currency.id),
      addresses:
        Enum.map(currency.addresses, fn address ->
          address.id
        end),
      status: Atom.to_string(status),
      invoices:
        Enum.map(currency.invoices, fn invoice ->
          invoice.id
        end)
    }
  end
end
