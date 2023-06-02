defmodule BitPalFactory.InvoiceFactory do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Invoices` context.
  """
  import BitPalFactory.UtilFactory
  import Ecto.Changeset
  alias BitPalFactory.TransactionFactory
  alias BitPalFactory.ExchangeRateFactory
  alias BitPal.Currencies
  alias BitPal.Addresses
  alias BitPal.ExchangeRates
  alias BitPal.Invoices
  alias BitPal.InvoiceSupervisor
  alias BitPal.PaymentUri
  alias BitPal.Repo
  alias BitPalApi.Authentication.BasicAuth
  alias BitPalFactory.AddressFactory
  alias BitPalFactory.CurrencyFactory
  alias BitPalFactory.SettingsFactory
  alias BitPalFactory.StoreFactory
  alias BitPalSchemas.Address
  alias BitPalSchemas.Invoice
  alias BitPalSchemas.InvoiceStatus
  alias BitPalSchemas.InvoiceRates
  alias BitPalSchemas.Store
  require Logger

  def valid_invoice_attributes(attrs \\ %{}) do
    required_confirmations = attrs[:required_confirmations] || Faker.random_between(0, 3)

    Enum.into(
      attrs,
      %{
        status: valid_status(required_confirmations),
        required_confirmations: required_confirmations,
        description: Faker.Commerce.product_name(),
        email: Faker.Internet.email(),
        order_id: Faker.Code.isbn()
      }
    )
    |> add_valid_payment_setup()
    |> add_test_currency_rates()
    |> add_pos_data()
    |> Map.take([
      :status,
      :price,
      :rates,
      :payment_currency_id,
      :expected_payment,
      :required_confirmations,
      :description,
      :email,
      :order_id,
      :pos_data,
      :address_id,
      :store_id,
      :payment_uri
    ])
  end

  # These 4 fields must match, and this will fill in the missing ones:
  # - price
  # - payment_currency_id
  # - expected_payment
  # - rates (matching price + payment_currency)
  # expected_payment is ignored during invoice creation and is only sometimes added here.
  # payment_currency is also not required for draft creation, but is added here regardless
  # (unless payment_currency_id: nil is passed)
  defp add_valid_payment_setup(attrs = %{payment_currency_id: nil}) do
    Map.delete(attrs, :payment_currency_id)
  end

  defp add_valid_payment_setup(
         attrs = %{price: price, payment_currency_id: payment_currency_id, rates: rates}
       ) do
    {:ok, expected_payment} =
      Invoices.calculate_expected_payment(price, payment_currency_id, rates)

    if specified = attrs[:expected_payment] do
      if specified != expected_payment do
        raise "expected_payment mismatch got: `#{specified}` expected `#{expected_payment}`"
      end
    end

    # Should be calculated in invoice creation, so we could leave it out too.
    attrs
    |> Map.put(:expected_payment, expected_payment)
  end

  defp add_valid_payment_setup(attrs = %{price: price, expected_payment: expected_payment}) do
    if id = attrs[:payment_currency_id] do
      if id != expected_payment.currency do
        raise "payment_currency mismatch got: `#{id}` expected `#{expected_payment.currency}`"
      end
    end

    rate = ExchangeRates.calculate_rate(price, expected_payment)

    Map.merge(attrs, %{
      rates: %{expected_payment.currency => %{price.currency => rate}},
      payment_currency_id: expected_payment.currency
    })
  end

  defp add_valid_payment_setup(attrs = %{expected_payment: expected_payment}) do
    if id = attrs[:payment_currency_id] do
      if id != expected_payment.currency do
        raise "payment_currency mismatch got: `#{id}` expected `#{expected_payment.currency}`"
      end
    end

    # Round to avoid rounding errors in == some edge-case tests
    # if rates have too many decimals. This appears because we
    # may specify the expected_payment exactly, but when creating the invoice
    # we calculate it from price which is money with (usually) only 2 decimal places,
    # leading to some rounding errors.
    # But crypto can have many more decimals, which may be lost during this conversion.
    # This should not have any effect on regular operation, as this roundabout calculation
    # is only done in some tests.
    rates =
      attrs[:rates] ||
        ExchangeRateFactory.bundled_rates(crypto: expected_payment.currency, decimals: 0)

    {price_currency, rate} = InvoiceRates.find_quote_with_rate(rates, expected_payment.currency)

    price = ExchangeRates.calculate_quote(rate, expected_payment, price_currency)

    Map.merge(attrs, %{
      price: price,
      payment_currency_id: expected_payment.currency,
      rates: rates
    })
  end

  defp add_valid_payment_setup(attrs = %{rates: rates, price: price}) do
    {payment_currency_id, _} = InvoiceRates.find_base_with_rate(rates, price.currency)
    Map.put(attrs, :payment_currency_id, payment_currency_id)
  end

  defp add_valid_payment_setup(attrs = %{rates: rates, payment_currency_id: payment_currency_id}) do
    {price_currency, _} = InvoiceRates.find_quote_with_rate(rates, payment_currency_id)
    Map.put(attrs, :price, create_money(price_currency))
  end

  defp add_valid_payment_setup(attrs = %{rates: rates}) do
    # Have rates but not price and no expected_payment.
    {payment_currency_id, price_currency, _rate} = InvoiceRates.find_any_rate(rates)

    Map.merge(attrs, %{
      price: create_money(price_currency),
      payment_currency_id: payment_currency_id
    })
  end

  defp add_valid_payment_setup(
         attrs = %{price: _price, payment_currency_id: _payment_currency_id}
       ) do
    attrs
  end

  defp add_valid_payment_setup(attrs = %{price: price}) do
    if Currencies.is_crypto(price.currency) do
      payment_currency_id = price.currency
      Map.merge(attrs, %{payment_currency_id: payment_currency_id})
    else
      payment_currency_id = valid_payment_currency(attrs)
      Map.merge(attrs, %{payment_currency_id: payment_currency_id})
    end
  end

  defp add_valid_payment_setup(attrs) do
    # Nothing here except maybe payment_currency_id
    payment_currency_id = valid_payment_currency(attrs)
    price = create_money(CurrencyFactory.fiat_currency_id())
    Map.merge(attrs, %{price: price, payment_currency_id: payment_currency_id})
  end

  def add_test_currency_rates(attrs = %{payment_currency_id: payment_currency}) do
    if Currencies.is_test_currency?(payment_currency) do
      rates = attrs[:rates]

      if !rates || InvoiceRates.find_quote_with_rate(rates, payment_currency) == :not_found do
        add_bundled_rates(payment_currency, attrs)
      else
        attrs
      end
    else
      attrs
    end
  end

  def add_test_currency_rates(attrs) do
    attrs
  end

  defp add_bundled_rates(payment_currency, attrs) do
    Map.put(
      attrs,
      :rates,
      ExchangeRateFactory.bundled_rates(crypto: payment_currency, decimals: 0)
    )
  end

  def valid_status(required_confirmations, blacklist \\ []) do
    state = Faker.Util.pick([:draft, :open, :processing, :uncollectible, :void, :paid], blacklist)

    reason =
      case state do
        :processing ->
          if required_confirmations == 0 do
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

    InvoiceStatus.cast!({state, reason})
  end

  def valid_pos_data do
    %{"ref" => Faker.random_between(0, 1_000_000)}
  end

  def valid_price do
    create_money(Enum.random([:USD, :EUR, :SEK]))
  end

  def valid_payment_currency(attrs \\ %{}) do
    cond do
      currency = attrs[:payment_currency_id] ->
        currency

      attrs[:unique_currency] ->
        CurrencyFactory.unique_currency_id()

      true ->
        Enum.random([:BCH, :XMR, :DGC])
    end
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

    invoice =
      case Invoices.register(store_id, invoice_params) do
        {:ok, invoice} ->
          invoice

        {:error, changeset} ->
          Logger.critical("invoice factory failed to create invoice")
          Logger.critical("  #{inspect(changeset)}")
          Logger.critical("  #{inspect(invoice_params)}")
          raise("bad invoice creation in factory")
      end

    if address_key = params[:address_key] do
      SettingsFactory.ensure_address_key!(
        store_id: store_id,
        currency_id: invoice.payment_currency_id,
        data: address_key
      )
    end

    params = Enum.into(params, %{})

    invoice
    |> change_status(invoice_params)
    |> change_address(params)
    |> ensure_consistency(params)
  end

  @spec finalize_and_track(Invoice.t()) :: Invoice.t()
  def finalize_and_track(invoice = %Invoice{}) do
    {:ok, invoice} = InvoiceSupervisor.finalize_invoice(invoice)
    invoice
  end

  @spec change_status(Invoice.t(), map) :: Invoice.t()
  defp change_status(invoice, %{status: status}) do
    status =
      case status do
        :processing ->
          if invoice.required_confirmations == 0 do
            {:processing, :verifying}
          else
            {:processing, :confirming}
          end

        :uncollectible ->
          {:uncollectible, Enum.random([:expired, :canceled, :timed_out, :double_spent])}

        :void ->
          if reason = Enum.random([:expired, :canceled, :timed_out, :double_spent, nil]) do
            {:void, reason}
          else
            :void
          end

        alone ->
          alone
      end

    change(invoice, status: status)
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

  @spec ensure_consistency(Invoice.t(), keyword | map) :: Invoice.t()
  defp ensure_consistency(invoice, opts) do
    invoice
    |> ensure_address()
    |> generate_payment_uri(opts)
    |> with_txs(opts)
  end

  defp ensure_address(invoice) do
    if !invoice.address_id && Invoices.finalized?(invoice) do
      invoice
      |> create_address()
    else
      invoice
    end
  end

  defp generate_payment_uri(invoice, opts) do
    cond do
      uri = opts[:payment_uri] ->
        %{invoice | payment_uri: uri}

      !invoice.payment_uri && Invoices.finalized?(invoice) ->
        invoice = Repo.preload(invoice, :store)

        %{
          invoice
          | payment_uri:
              PaymentUri.encode_invoice(invoice, %{
                prefix: "test",
                decimal_amount_key: "amount",
                description_key: "description",
                recipient_name_key: "recipient"
              })
        }

      true ->
        invoice
    end
  end

  defp with_txs(invoice, opts) do
    if opts[:txs] do
      invoice
      |> TransactionFactory.with_txs(opts)
    else
      invoice
      |> Repo.preload(:transactions)
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
