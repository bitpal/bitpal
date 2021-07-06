defmodule BitPalApi.InvoiceController do
  use BitPalApi, :controller
  alias BitPal.InvoiceManager
  alias BitPal.Invoices

  def index(conn, _params) do
    render(conn, "index.json")
  end

  def create(conn, params) do
    with {:ok, invoice} <- Invoices.register(params),
         {:ok, invoice} <- finalize_if(invoice, params) do
      render(conn, "show.json", invoice: invoice)
    else
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

  def finalize(conn, %{"id" => id}) do
    with {:ok, invoice} <- Invoices.fetch(id),
         {:ok, invoice} <- InvoiceManager.finalize_invoice(invoice) do
      render(conn, "show.json", invoice: invoice)
    else
      :error ->
        raise NotFoundError

      {:error, _changeset} ->
        raise BadRequestError
    end
  end

  defp finalize_if(invoice, params) do
    if params["finalize"] || params[:finalize] do
      InvoiceManager.finalize_invoice(invoice)
    else
      {:ok, invoice}
    end
  end
end
