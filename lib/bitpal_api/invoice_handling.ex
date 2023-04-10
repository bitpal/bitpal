defmodule BitPalApi.InvoiceHandling do
  use BitPalApi.Errors
  import Ecto.Changeset
  import BitPalApi.ApiHelpers
  alias BitPal.Invoices
  alias BitPal.InvoiceSupervisor
  alias Ecto.Changeset
  alias BitPal.Stores
  alias BitPal.Repo
  alias BitPalApi.ErrorView

  # Dialyzer complains about "The pattern can never match the type" for Invoice fetching and updating,
  # even though the specs looks correct to me...
  @dialyzer :no_match

  # Invoice actions

  def create(store, params) do
    with {:ok, validated} <- validate_create_params(params),
         {:ok, invoice} <- Invoices.register(store, validated),
         {:ok, invoice} <- finalize_if(invoice, params) do
      invoice
    else
      {:error, changeset = %Changeset{}} ->
        handle_changeset_error(changeset)
    end
  end

  def get(store, id) do
    case Invoices.fetch(id, store) do
      {:ok, invoice} ->
        invoice

      {:error, _} ->
        raise NotFoundError, param: "id"
    end
  end

  def update(store, params = %{"id" => id}) do
    update(store, id, params)
  end

  def update(store, id, params) do
    with {:ok, invoice} <- Invoices.fetch(id, store),
         {:ok, params} <- validate_update_params(params),
         {:ok, invoice} <- Invoices.update(invoice, params) do
      invoice
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, :finalized} ->
        raise RequestFailedError,
          code: "invoice_not_editable",
          message: "cannot update a finalized invoice"

      {:error, changeset = %Changeset{}} ->
        handle_changeset_error(changeset)
    end
  end

  def delete(store, id) do
    with {:ok, invoice} <- Invoices.fetch(id, store),
         {:ok, invoice} <- Invoices.delete(invoice) do
      invoice
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, :finalized} ->
        raise RequestFailedError,
          code: "invoice_not_editable",
          message: "cannot delete a finalized invoice"

      {:error, changeset = %Changeset{}} ->
        handle_changeset_error(changeset)
    end
  end

  def finalize(store, id) do
    with {:ok, invoice} <- Invoices.fetch(id, store),
         {:ok, invoice} <- InvoiceSupervisor.finalize_invoice(invoice) do
      invoice
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, changeset = %Changeset{}} ->
        handle_changeset_error(changeset)
    end
  end

  def pay(store, id) do
    with {:ok, invoice} <- Invoices.fetch(id, store),
         {:ok, invoice} <- Invoices.pay_unchecked(invoice) do
      invoice
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, :no_block_height} ->
        raise InternalServerError

      {:error, changeset = %Changeset{}} ->
        transition_error(changeset)
    end
  end

  def void(store, id) do
    with {:ok, invoice} <- Invoices.fetch(id, store),
         {:ok, invoice} <- Invoices.void(invoice) do
      invoice
    else
      {:error, :not_found} ->
        raise NotFoundError, param: "id"

      {:error, changeset = %Changeset{}} ->
        transition_error(changeset)
    end
  end

  def all_invoices(store) do
    store = Stores.fetch!(store) |> Repo.preload([:invoices])
    store.invoices
  end

  # Internals

  defp finalize_if(invoice, params) do
    if params["finalize"] do
      InvoiceSupervisor.finalize_invoice(invoice)
    else
      {:ok, invoice}
    end
  end

  @spec transition_error(Changeset.t()) :: no_return()
  defp transition_error(changeset) do
    case changeset_error(changeset, :status) do
      nil ->
        handle_changeset_error(changeset)

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

  defp validate_create_params(params) do
    spec = %{
      price: :decimal,
      sub_price: :integer,
      price_currency: :string,
      payment_currency: :string,
      description: :string,
      email: :string,
      order_id: :string,
      pos_data: :map
    }

    {%{}, spec}
    |> cast(keys_to_snake(params), Map.keys(spec))
    |> validate_required([:price_currency])
    |> validate_currency(:price_currency)
    |> validate_price_required()
    |> update_price()
    |> validate_currency(:payment_currency)
    |> Changeset.apply_action(:validate)
    |> transform_keys()
  end

  defp validate_update_params(params) do
    spec = %{
      price: :decimal,
      sub_price: :integer,
      price_currency: :string,
      payment_currency: :string,
      description: :string,
      email: :string,
      order_id: :string,
      pos_data: :map
    }

    {%{}, spec}
    |> cast(keys_to_snake(params), Map.keys(spec))
    |> validate_price_currency_required_if_price_changed()
    |> validate_currency(:price_currency)
    |> update_price()
    |> validate_currency(:payment_currency)
    |> Changeset.apply_action(:validate)
    |> transform_keys()
  end

  defp update_price(changeset = %Changeset{changes: %{price: _, sub_price: _}}) do
    add_both_price_error(changeset)
  end

  defp update_price(
         changeset = %Changeset{changes: %{price: price, price_currency: currency}, valid?: true}
       ) do
    case Money.parse(price, currency) do
      {:ok, price} ->
        changeset
        |> force_change(:price, price)
        |> delete_change(:price_currency)

      _ ->
        add_error(changeset, :price, "is invalid")
    end
  end

  defp update_price(
         changeset = %Changeset{
           changes: %{sub_price: amount, price_currency: currency},
           valid?: true
         }
       ) do
    changeset
    |> force_change(:price, Money.new(amount, currency))
    |> delete_change(:sub_price)
    |> delete_change(:price_currency)
  end

  defp update_price(changeset = %Changeset{changes: %{price_currency: _}}) do
    add_must_provide_either_price_error(changeset)
  end

  defp update_price(changeset) do
    changeset
  end

  defp validate_price_required(changeset) do
    price_error? = empty_change?(changeset, :price) && empty_change?(changeset, :sub_price)

    if price_error? do
      add_must_provide_either_price_error(changeset)
    else
      changeset
    end
  end

  defp validate_price_currency_required_if_price_changed(changeset) do
    has_price? = get_change(changeset, :price) != nil || get_change(changeset, :sub_price) != nil
    has_price_currency? = get_change(changeset, :price_currency) != nil

    if has_price? and !has_price_currency? do
      add_error(
        changeset,
        :price_currency,
        "can't be empty if either `price` or `subPrice` is set"
      )
    else
      changeset
    end
  end

  defp validate_currency(changeset, key) do
    if id = get_change(changeset, key) do
      case cast_currency(id) do
        {:ok, id} ->
          force_change(changeset, key, id)

        {:error, msg} ->
          add_error(changeset, key, msg)
      end
    else
      changeset
    end
  end

  defp add_both_price_error(changeset) do
    msg = "both `price` and `sub_price` cannot be provided"

    changeset
    |> add_error(:price, msg)
    |> add_error(:subPrice, msg)
  end

  defp add_must_provide_either_price_error(changeset) do
    msg = "either `price` or `subPrice` must be provided"

    changeset
    |> add_error(:price, msg)
    |> add_error(:sub_price, msg)
  end

  defp empty_change?(changeset, key) do
    !Keyword.has_key?(changeset.errors, key) && !get_change(changeset, key)
  end

  # Some keys are mismatched from what invoices expect.

  defp transform_keys({:ok, params}) do
    transforms = %{payment_currency: :payment_currency_id}

    {:ok,
     Map.new(params, fn {key, val} ->
       {transforms[key] || key, val}
     end)}
  end

  defp transform_keys(err), do: err

  defp handle_changeset_error(changeset) do
    changeset =
      transform_errors(changeset, fn
        {:payment_currency_id, {_, [code: :same_price_error]}} ->
          nil

        {:price, msg = {_, [code: :same_price_error]}} ->
          {:price_currency, msg}

        x ->
          x
      end)

    raise RequestFailedError, changeset: changeset
  end
end
