defmodule BitPalApi.InvoiceController do
  use BitPalApi, :controller
  alias BitPalApi.InvoiceHandling

  def action(conn, _) do
    args = [conn, conn.params, conn.assigns.current_store]
    apply(__MODULE__, action_name(conn), args)
  end

  def create(conn, params, store) do
    invoice = InvoiceHandling.create(store, params)
    render(conn, :show, invoice: invoice)
  end

  def show(conn, %{"id" => id}, store) do
    invoice = InvoiceHandling.get(store, id)
    render(conn, :show, invoice: invoice)
  end

  def update(conn, params, store) do
    invoice = InvoiceHandling.update(store, params)
    render(conn, :show, invoice: invoice)
  end

  def delete(conn, %{"id" => id}, store) do
    invoice = InvoiceHandling.delete(store, id)
    render(conn, :deleted, id: invoice.id)
  end

  def finalize(conn, %{"id" => id}, store) do
    invoice = InvoiceHandling.finalize(store, id)
    render(conn, :show, invoice: invoice)
  end

  def pay(conn, %{"id" => id}, store) do
    invoice = InvoiceHandling.pay(store, id)
    render(conn, :show, invoice: invoice)
  end

  def void(conn, %{"id" => id}, store) do
    invoice = InvoiceHandling.void(store, id)
    render(conn, :show, invoice: invoice)
  end

  def index(conn, _params, store) do
    invoices = InvoiceHandling.all_invoices(store)
    render(conn, :index, invoices: invoices)
  end
end
