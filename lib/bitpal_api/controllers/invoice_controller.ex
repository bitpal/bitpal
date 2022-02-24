defmodule BitPalApi.InvoiceController do
  use BitPalApi, :controller
  alias BitPal.Invoices
  alias BitPal.InvoiceSupervisor
  alias BitPal.Repo
  alias BitPal.Stores
  alias Ecto.Changeset

  # Dialyzer complains about "The pattern can never match the type" for Invoice fetching and updating,
  # even though the specs looks correct to me...
  @dialyzer :no_match

  def action(conn, _) do
    args = [conn, conn.params, conn.assigns.current_store]
    apply(__MODULE__, action_name(conn), args)
  end

  def create(conn, params, current_store) do
    with {:ok, invoice} <- Invoices.register(current_store, params),
         {:ok, invoice} <- finalize_if(invoice, params) do
      render(conn, "show.json", invoice: invoice)
    else
      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  defp finalize_if(invoice, params) do
    if params["finalize"] do
      InvoiceSupervisor.finalize_invoice(invoice)
    else
      {:ok, invoice}
    end
  end

  def show(conn, %{"id" => id}, current_store) do
    case Invoices.fetch(id, current_store) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      {:error, _} ->
        raise NotFoundError, param: "id"
    end
  end

  def update(conn, params = %{"id" => id}, current_store) do
    with {:ok, invoice} <- Invoices.fetch(id, current_store),
         {:ok, invoice} <- Invoices.update(invoice, params) do
      render(conn, "show.json", invoice: invoice)
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, :finalized} ->
        raise RequestFailedError,
          code: "invoice_not_editable",
          message: "Cannot update a finalized invoice"

      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  def delete(conn, %{"id" => id}, current_store) do
    with {:ok, invoice} <- Invoices.fetch(id, current_store),
         {:ok, invoice} <- Invoices.delete(invoice) do
      render(conn, "deleted.json", id: invoice.id, deleted: true)
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, :finalized} ->
        raise RequestFailedError,
          code: "invoice_not_editable",
          message: "Cannot delete a finalized invoice"

      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  def finalize(conn, %{"id" => id}, current_store) do
    with {:ok, invoice} <- Invoices.fetch(id, current_store),
         {:ok, invoice} <- InvoiceSupervisor.finalize_invoice(invoice) do
      render(conn, "show.json", invoice: invoice)
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  def pay(conn, %{"id" => id}, current_store) do
    with {:ok, invoice} <- Invoices.fetch(id, current_store),
         {:ok, invoice} <- Invoices.pay_unchecked(invoice) do
      render(conn, "show.json", invoice: invoice)
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, :no_block_height} ->
        raise InternalServerError

      {:error, changeset = %Changeset{}} ->
        transition_error(changeset)
    end
  end

  def void(conn, %{"id" => id}, current_store) do
    with {:ok, invoice} <- Invoices.fetch(id, current_store),
         {:ok, invoice} <- Invoices.void(invoice) do
      render(conn, "show.json", invoice: invoice)
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, changeset = %Changeset{}} ->
        transition_error(changeset)
    end
  end

  def index(conn, _params, current_store) do
    store = Stores.fetch!(current_store) |> Repo.preload([:invoices])

    render(conn, "index.json", invoices: store.invoices)
  end

  defp transition_error(changeset) do
    case changeset_error(changeset, :status) do
      nil ->
        raise RequestFailedError, changeset: changeset

      message ->
        raise RequestFailedError, code: "invalid_transition", message: message
    end
  end

  defp changeset_error(%Changeset{errors: errors}, param) do
    error = Keyword.get(errors, param)

    if error do
      ErrorView.render_changeset_error(error)
    else
      nil
    end
  end
end
