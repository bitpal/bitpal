defmodule BitPal do
  alias BitPal.BackendManager
  alias BitPal.InvoiceEvents
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias BitPalSchemas.Invoice
  alias Ecto.Changeset

  @spec register_invoice(Invoices.register_params()) ::
          {:ok, Invoice.t()} | {:error, Changeset.t()}
  def register_invoice(params) do
    Invoices.register(params)
  end

  @spec finalize(Invoice.t()) :: {:ok, Invoice.id()} | {:error, Changeset.t()}
  def finalize(invoice) do
    case Invoices.fetch(invoice.id) do
      {:ok, invoice} ->
        InvoiceManager.track(invoice)

      :error ->
        {:error,
         invoice
         |> Changeset.change()
         |> Changeset.add_error(:id, "invoice not registered")}
    end
  end

  @spec subscribe(Invoice.id() | Invoice.t()) :: :ok | {:error, term}
  def subscribe(x), do: InvoiceEvents.subscribe(x)

  @spec register_and_finalize(Invoices.register_params()) ::
          {:ok, Invoice.id()} | {:error, Changeset.t()}
  def register_and_finalize(params) do
    case register_invoice(params) do
      {:ok, invoice} ->
        :ok = subscribe(invoice)
        BitPal.finalize(invoice)

      {:error, changeset} ->
        changeset
    end
  end

  @spec configure(keyword) :: :ok
  def configure(opts) do
    if double_spend_timeout = Keyword.get(opts, :double_spend_timeout) do
      InvoiceManager.configure(double_spend_timeout: double_spend_timeout)
    end

    if backends = Keyword.get(opts, :backends) do
      BackendManager.configure(backends: backends)
    end

    # NOTE we want to handle this in a more general way later
    if conf = Keyword.get(opts, :required_confirmations) do
      Application.put_env(:bitpal, :required_confirmations, conf)
    end

    :ok
  end
end
