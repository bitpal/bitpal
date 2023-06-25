defmodule BitPalFactory.InvoiceFactoryTest do
  use BitPal.DataCase, async: true
  alias BitPalSchemas.Address
  alias BitPalSchemas.InvoiceStatus
  alias BitPalSettings.StoreSettings

  setup _tags do
    %{store: create_store()}
  end

  describe "adds valid payment setup to invoice attributes" do
    setup _tags do
      %{
        price: Money.parse!(4.2, :USD),
        payment_currency_id: :BCH,
        rates: %{BCH: %{USD: Decimal.from_float(2.0)}},
        expected_payment: Money.parse!(2.1, :BCH)
      }
    end

    test "specify all", %{
      price: price,
      payment_currency_id: payment_currency_id,
      rates: rates,
      expected_payment: expected_payment
    } do
      gotten =
        valid_invoice_attributes(%{
          price: price,
          payment_currency_id: payment_currency_id,
          rates: rates,
          expected_payment: expected_payment
        })

      assert gotten.price == price
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates == rates
      assert gotten.expected_payment == expected_payment
    end

    test "with expected_payment", %{
      price: price,
      payment_currency_id: payment_currency_id,
      rates: rates,
      expected_payment: expected_payment
    } do
      gotten =
        valid_invoice_attributes(%{
          price: price,
          expected_payment: expected_payment
        })

      assert gotten.price == price
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates[payment_currency_id][price.currency] != nil
      assert gotten.expected_payment == expected_payment

      gotten =
        valid_invoice_attributes(%{
          expected_payment: expected_payment,
          rates: rates
        })

      assert gotten.price == price
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates == rates
      assert gotten.expected_payment == expected_payment
    end

    test "with rates and price", %{
      price: price,
      payment_currency_id: payment_currency_id,
      rates: rates,
      expected_payment: expected_payment
    } do
      gotten =
        valid_invoice_attributes(%{
          price: price,
          payment_currency_id: payment_currency_id,
          rates: rates
        })

      assert gotten.price == price
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates == rates
      assert gotten.expected_payment == expected_payment

      gotten =
        valid_invoice_attributes(%{
          price: price,
          rates: rates
        })

      assert gotten.price == price
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates[payment_currency_id][price.currency] != nil
      # assert gotten.expected_payment == expected_payment
    end

    test "with rates", %{
      price: price,
      payment_currency_id: payment_currency_id,
      rates: rates
    } do
      gotten =
        valid_invoice_attributes(%{
          rates: rates,
          payment_currency_id: payment_currency_id
        })

      assert gotten.price != nil
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates[payment_currency_id][price.currency] != nil

      gotten =
        valid_invoice_attributes(%{
          rates: rates
        })

      assert gotten.price != nil
      assert gotten.payment_currency_id == payment_currency_id
      assert gotten.rates[payment_currency_id][price.currency] != nil
    end

    test "with price", %{
      price: price,
      payment_currency_id: payment_currency_id
    } do
      gotten =
        valid_invoice_attributes(%{
          price: price,
          payment_currency_id: payment_currency_id
        })

      assert gotten.price == price
      assert gotten.payment_currency_id == payment_currency_id

      gotten =
        valid_invoice_attributes(%{
          price: price
        })

      assert gotten.price == price
      assert gotten.payment_currency_id != nil
    end

    test "priced in crypto" do
      price = Money.parse!(1, :BCH)

      gotten = valid_invoice_attributes(%{price: price})

      assert gotten.price == price
      assert gotten.payment_currency_id == price.currency
    end

    test "with payment_currency_id", %{
      payment_currency_id: payment_currency_id
    } do
      gotten =
        valid_invoice_attributes(%{
          payment_currency_id: payment_currency_id
        })

      assert gotten.price != nil
      assert gotten.payment_currency_id == payment_currency_id

      gotten = valid_invoice_attributes()

      assert gotten.price != nil
      assert gotten.payment_currency_id != nil
    end

    test "block payment setup" do
      gotten =
        valid_invoice_attributes(%{
          payment_currency_id: nil
        })

      assert Map.has_key?(gotten, :payment_currency_id) == false
      assert Map.has_key?(gotten, :expected_payment) == false
    end
  end

  describe "create_invoice/2" do
    test "inserts into db", %{store: store} do
      invoice = create_invoice(store: store)
      assert {:ok, _} = BitPal.Invoices.fetch(invoice.id)
    end

    test "different ways of specifying store", %{store: store} do
      assert create_invoice(store).store_id == store.id
      assert create_invoice(store: store).store_id == store.id
      assert create_invoice(store_id: store.id).store_id == store.id
    end

    test "create store if not specified" do
      assert create_invoice().store_id != nil
    end

    test "assigns existing address", %{store: store} do
      currency_id = :XMR
      address = create_address(store_id: store.id, currency_id: currency_id)
      invoice = create_invoice(store, address_id: address.id, payment_currency_id: currency_id)
      assert invoice.address_id == address.id
    end

    test "assigns address_id and creates an Address", %{store: store} do
      address_id = unique_address_id()
      invoice = create_invoice(store, address_id: address_id)

      assert Repo.get!(Address, address_id)
      assert invoice.address_id == address_id
    end

    test "generates address with auto", %{store: store} do
      invoice = create_invoice(store, address_id: :auto)
      assert invoice.address_id != nil
      assert Repo.get!(Address, invoice.address_id)
    end

    test "specify currency" do
      currency_id = :XMR
      assert create_invoice(payment_currency_id: currency_id).payment_currency_id == currency_id
    end

    test "specify expected_payment" do
      currency_id = :XMR
      expected = Money.parse!(1.3, currency_id)
      invoice = create_invoice(expected_payment: expected)
      assert invoice.payment_currency_id == currency_id
      assert invoice.expected_payment == expected
    end

    test "specify xpub", %{store: store} do
      xpub = "xpubtest"
      invoice = create_invoice(store: store, address_key: %{xpub: xpub}, unique_currency: true)
      address_key = StoreSettings.fetch_address_key!(store.id, invoice.payment_currency_id)

      assert address_key.data == %{xpub: xpub}
      {:ok, got_address_key} = Invoices.address_key(invoice)
      assert got_address_key.id == address_key.id
    end

    test "specify status generates status_reason", %{store: store} do
      assert InvoiceStatus.reason(create_invoice(store, status: :draft).status) == nil
      assert InvoiceStatus.reason(create_invoice(store, status: :open).status) == nil

      assert InvoiceStatus.reason(create_invoice(store, status: :processing).status) in [
               :verifying,
               :confirming
             ]

      assert InvoiceStatus.reason(create_invoice(store, status: :uncollectible).status) in [
               :expired,
               :canceled,
               :timed_out,
               :double_spent
             ]

      assert InvoiceStatus.reason(create_invoice(store, status: :void).status) in [
               :expired,
               :canceled,
               :timed_out,
               :double_spent,
               nil
             ]

      assert InvoiceStatus.reason(create_invoice(store, status: :paid).status) == nil
    end

    test "specify valid_until" do
      date = DateTime.new!(~D[2000-01-02], ~T[12:30:10], "Etc/UTC")
      invoice = create_invoice(valid_until: date)
      assert invoice.valid_until == date
    end
  end

  describe "with_address/2" do
    setup %{store: store} do
      %{store: store, invoice: create_invoice(store)}
    end

    test "pass through existing address", %{store: store, invoice: invoice} do
      address = create_address(store_id: store.id, currency_id: invoice.payment_currency_id)

      invoice = with_address(invoice, address_id: address.id)
      assert invoice.address_id == address.id
    end

    test "create address_id", %{invoice: invoice} do
      address_id = unique_address_id()
      invoice = with_address(invoice, address_id: address_id)
      assert invoice.address_id == address_id
      assert Repo.get!(Address, address_id)
    end

    test "generates an address if nothing specified", %{invoice: invoice} do
      invoice = with_address(invoice)
      assert invoice.address_id != nil
      assert Repo.get!(Address, invoice.address_id)
    end
  end
end
