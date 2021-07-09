defmodule BitPalApi.InvoiceController do
  use BitPalApi, :controller
  alias BitPal.InvoiceManager
  alias BitPal.Invoices
  alias Ecto.Changeset

  def create(conn, params) do
    with {:ok, invoice} <- Invoices.register(params),
         {:ok, invoice} <- finalize_if(invoice, params) do
      render(conn, "show.json", invoice: invoice)
    else
      {:error, changeset} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  defp finalize_if(invoice, params) do
    if params["finalize"] do
      InvoiceManager.finalize_invoice(invoice)
    else
      {:ok, invoice}
    end
  end

  def show(conn, %{"id" => id}) do
    case Invoices.fetch(id) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      :error ->
        raise NotFoundError, param: id
    end
  end

  def update(conn, params = %{"id" => id}) do
    case Invoices.update(id, params) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      {:error, :not_found} ->
        raise NotFoundError, param: id

      {:error, :finalized} ->
        raise RequestFailedError,
          code: "invoice_not_editable",
          message: "Cannot update a finalized invoice"

      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  def delete(conn, %{"id" => id}) do
    case Invoices.delete(id) do
      {:ok, _} ->
        render(conn, "deleted.json", id: id, deleted: true)

      {:error, :not_found} ->
        raise NotFoundError, param: id

      {:error, :finalized} ->
        raise RequestFailedError,
          code: "invoice_not_editable",
          message: "Cannot delete a finalized invoice"

      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  def finalize(conn, %{"id" => id}) do
    with {:ok, invoice} <- Invoices.fetch(id),
         {:ok, invoice} <- InvoiceManager.finalize_invoice(invoice) do
      render(conn, "show.json", invoice: invoice)
    else
      :error ->
        raise NotFoundError, param: id

      {:error, changeset = %Changeset{}} ->
        raise RequestFailedError, changeset: changeset
    end
  end

  def pay(conn, %{"id" => id}) do
    case Invoices.pay_from_void(id) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      {:error, :not_found} ->
        raise NotFoundError, param: id

      {:error, :no_block_height} ->
        raise InternalServerError

      {:error, changeset = %Changeset{}} ->
        transition_error(changeset)
    end
  end

  def void(conn, %{"id" => id}) do
    case Invoices.void(id) do
      {:ok, invoice} ->
        render(conn, "show.json", invoice: invoice)

      {:error, :not_found} ->
        raise NotFoundError, param: id

      {:error, changeset = %Changeset{}} ->
        transition_error(changeset)
    end
  end

  def index(conn, _params) do
    render(conn, "index.json", invoices: Invoices.all())
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
