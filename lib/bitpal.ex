defmodule BitPal do
  alias BitPal.Invoice
  alias BitPal.InvoiceManager
  alias BitPal.BackendManager

  @spec init_invoice(Invoice.t()) :: {:ok, pid}
  def init_invoice(invoice) do
    InvoiceManager.create_invoice_and_subscribe(invoice)
  end

  @spec configure(keyword) :: :ok
  def configure(opts) do
    if double_spend_timeout = Keyword.get(opts, :double_spend_timeout) do
      InvoiceManager.configure(double_spend_timeout: double_spend_timeout)
    end

    if backends = Keyword.get(opts, :backends) do
      BackendManager.configure(backends: backends)
    end

    :ok
  end
end
