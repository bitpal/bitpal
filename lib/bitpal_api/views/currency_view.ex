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
      status: readable_status(status),
      invoices:
        Enum.map(invoices, fn invoice ->
          invoice.id
        end)
    }
  end

  defp readable_status(:initializing), do: "initializing"
  defp readable_status(:ready), do: "ready"
  defp readable_status({:recovering, _, _}), do: "recovering"
  defp readable_status({:syncing, _}), do: "syncing"
  defp readable_status(:stopped), do: "stopped"
  defp readable_status(:not_found), do: "not_found"
end
