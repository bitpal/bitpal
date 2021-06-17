defmodule BitPalApi.InvoiceController do
  use BitPalApi, :controller
  alias BitPal.Invoices

  def index(conn, _params) do
    render(conn, "index.json")
  end

  def create(conn, params) do
    case Invoices.register(params) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      {:error, _changeset} ->
        raise BadRequestError
    end
  end

  def show(conn, %{"id" => id}) do
    case Invoices.fetch(id) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      :error ->
        raise NotFoundError
    end
  end
end
