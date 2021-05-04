defmodule BitPal do
  alias BitPal.BackendManager
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias BitPalSchemas.Invoice

  @spec register_invoice(Invoices.register_params()) ::
          {:ok, Invoice.id()} | {:error, Ecto.Changeset.t()}
  def register_invoice(params) do
    InvoiceManager.register_invoice(params)
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
