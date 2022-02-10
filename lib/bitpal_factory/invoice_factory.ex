defmodule BitPalFactory.InvoiceFactory do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Invoices` context.
  """
  import BitPalFactory.UtilFactory
  import Ecto.Changeset
  alias BitPal.Addresses
  alias BitPal.InvoiceSupervisor
  alias BitPal.Invoices
  alias BitPal.Repo
  alias BitPalApi.Authentication.BasicAuth
  alias BitPalFactory.AddressFactory
  alias BitPalFactory.CurrencyFactory
  alias BitPalFactory.SettingsFactory
  alias BitPalFactory.StoreFactory
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.Store

  def valid_pos_data do
    %{"ref" => Faker.random_between(0, 1_000_000)}
  end

  def valid_invoice_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      amount: rand_pos_float(),
      exchange_rate: rand_pos_float(),
      currency_id: CurrencyFactory.unique_currency_id() |> Atom.to_string(),
      fiat_currency: CurrencyFactory.fiat_currency(),
      description: Faker.Commerce.product_name(),
      email: Faker.Internet.email(),
      required_confirmations: Faker.random_between(0, 3),
      status: Enum.random([:draft, :open, :processing, :uncollectible, :void, :paid])
    })
    |> add_pos_data()
    |> Map.take([
      :amount,
      :fiat_currency,
      :fiat_amount,
      :exchange_rate,
      :currency_id,
      :description,
      :email,
      :status,
      :status_reason,
      :pos_data,
      :required_confirmations
    ])
  end

  defp add_pos_data(attrs = %{pos_data: _}) do
    attrs
  end

  defp add_pos_data(attrs) do
    if rand_pos_float() < 0.75 do
      Map.merge(%{pos_data: valid_pos_data()}, attrs)
    else
      attrs
    end
  end

  @doc """
  Create an invoice.
  """
  @spec create_invoice :: Invoice.t()
  def create_invoice do
    create_invoice(%{})
  end

  @doc """
  Create an invoice.
  """
  @spec create_invoice(map | keyword) :: Invoice.t()
  def create_invoice(params) when (is_map(params) and not is_struct(params)) or is_list(params) do
    params = Enum.into(params, %{})

    StoreFactory.get_or_create_store_id(params)
    |> create_invoice(Map.drop(params, [:store, :store_id]))
  end

  @doc """
  Create an invoice.
  """
  @spec create_invoice(Store.t() | Store.id() | Plug.Conn.t(), map | keyword) :: Invoice.t()
  def create_invoice(store_ref, params \\ %{})

  def create_invoice(conn = %Plug.Conn{}, params) do
    {:ok, store_id} = BasicAuth.parse(conn)
    create_invoice(store_id, params)
  end

  def create_invoice(store = %Store{}, params) do
    create_invoice(store.id, params)
  end

  def create_invoice(store_id, params) when is_integer(store_id) do
    invoice_params = valid_invoice_attributes(params)
    {:ok, invoice} = Invoices.register(store_id, invoice_params)

    if address_key = params[:address_key] do
      SettingsFactory.ensure_address_key!(
        store_id: store_id,
        currency_id: invoice.currency_id,
        data: address_key
      )
    end

    params = Enum.into(params, %{})

    invoice
    |> change_status(invoice_params)
    |> change_address(params)
    |> ensure_consistency()
  end

  @spec finalize_and_track(Invoice.t()) :: Invoice.t()
  def finalize_and_track(invoice = %Invoice{}) do
    {:ok, invoice} = InvoiceSupervisor.finalize_invoice(invoice)
    invoice
  end

  @spec change_status(Invoice.t(), map) :: Invoice.t()
  defp change_status(invoice, params = %{status: status}) do
    status_reason =
      params[:status_reason] ||
        case status do
          :processing ->
            if invoice.required_confirmations == 0 do
              :verifying
            else
              :confirming
            end

          :uncollectible ->
            Enum.random([:expired, :canceled, :timed_out, :double_spent])

          :void ->
            Enum.random([:expired, :canceled, :timed_out, :double_spent, nil])

          _ ->
            nil
        end

    change(invoice, status: status, status_reason: status_reason)
    |> Repo.update!()
  end

  defp change_status(invoice, _), do: invoice

  @spec change_address(Invoice.t(), map) :: Invoice.t()
  defp change_address(invoice, %{address_id: address_id}) do
    with_address(invoice, %{address_id: address_id})
  end

  defp change_address(invoice, _) do
    invoice
  end

  @spec ensure_consistency(Invoice.t()) :: Invoice.t()
  defp ensure_consistency(invoice) do
    if !invoice.address_id && Invoices.finalized?(invoice) do
      create_address(invoice)
    else
      invoice
    end
  end

  @doc """
  Assign an address to an invoice.

  The address can either be specified with :address, otherwise an address will be created
  unless the invoice already has an address.
  """
  @spec with_address(Invoice.t(), map | keyword) :: Invoice.t()
  def with_address(invoice, opts \\ %{})

  def with_address(invoice, opts) when is_list(opts) do
    with_address(invoice, Enum.into(opts, %{}))
  end

  def with_address(invoice, %{address_id: address_id}) when is_binary(address_id) do
    address_key = SettingsFactory.get_or_create_address_key(invoice)

    address =
      if address = Addresses.get(address_id) do
        address
      else
        {:ok, address} = Addresses.register_next_address(address_key, address_id)
        address
      end

    assoc_address(invoice, address)
  end

  def with_address(invoice = %{address_id: address_id}, _) when is_binary(address_id) do
    invoice
  end

  def with_address(invoice, _) do
    create_address(invoice)
  end

  defp create_address(invoice) do
    address = AddressFactory.create_address(invoice)
    # Add address references without going bock to the db
    %{invoice | address: address, address_id: address.id}
  end

  @doc """
  Associates an address with an invoice, bypassing validation checks.
  """
  @spec assoc_address(Invoice.t(), Address.t()) :: Invoice.t()
  def assoc_address(invoice, address) do
    invoice =
      invoice
      |> change(%{address_id: address.id})
      |> Repo.update!()

    %{invoice | address: address}
  end
end
