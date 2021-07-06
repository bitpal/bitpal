defmodule InvoiceCreationTest do
  use BitPal.IntegrationCase, db: true, async: false
  alias BitPal.Addresses
  alias BitPal.ExchangeRate
  alias BitPal.Invoices
  alias BitPalSchemas.Address

  @tag do: true
  test "invoice registration" do
    # we don't have to provide fiat_amount
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: "1.2",
               currency: "BCH",
               exchange_rate: "2.0",
               fiat_currency: "USD"
             })

    invoice = Repo.preload(invoice, :currency)

    assert invoice.id != nil
    assert invoice.amount == Money.parse!(1.2, :BCH)
    assert invoice.fiat_amount == Money.parse!(2.4, :USD)
    assert invoice.status == :draft
    assert invoice.currency_id == :BCH
    assert invoice.currency.id == :BCH
    assert invoice.address_id == nil

    assert invoice.exchange_rate == %ExchangeRate{
             rate: Decimal.from_float(2.0),
             pair: {:BCH, :USD}
           }

    assert in_db = Invoices.fetch!(invoice.id)
    assert in_db.id == invoice.id

    # it's fine to skip fiat_amount + exchange_rate
    assert {:ok, invoice} = Invoices.register(%{amount: 1.2, currency: :BCH})

    assert Money.to_decimal(invoice.amount) == Decimal.from_float(1.2)
    assert invoice.fiat_amount == nil
    assert invoice.exchange_rate == nil

    # We must supply currency
    assert {:error, changeset} = Invoices.register(%{amount: 1.2})
    assert "cannot be empty" in errors_on(changeset).currency

    # Currency must be valid
    assert {:error, changeset} = Invoices.register(%{amount: 1.2, currency: "crap"})
    assert "is invalid" in errors_on(changeset).currency
    assert {:error, changeset} = Invoices.register(%{amount: 1.2, fiat_currency: "crap"})
    assert "is invalid" in errors_on(changeset).fiat_currency

    # But fiat alone isn't enough
    assert {:error, changeset} = Invoices.register(%{fiat_amount: 1.2, fiat_currency: "USD"})
    assert "must provide either amount or exchange rate" in errors_on(changeset).amount

    # Only exchange rate isn't enough either
    assert {:error, changeset} =
             Invoices.register(%{
               currency: "BCH",
               fiat_currency: "USD",
               exchange_rate: 2.0
             })

    assert "must provide amount in either crypto or fiat" in errors_on(changeset).amount

    # Other invalid inputs
    assert {:error, changeset} =
             Invoices.register(%{
               currency: "BCH",
               fiat_currency: "USD",
               amount: -2.5,
               exchange_rate: -2.0
             })

    assert "must be greater than 0" in errors_on(changeset).amount
    assert "is invalid" in errors_on(changeset).exchange_rate

    assert {:error, changeset} =
             Invoices.register(%{
               currency: "BCH",
               fiat_currency: "USD",
               amount: "13bad",
               exchange_rate: "xxx"
             })

    assert "is invalid" in errors_on(changeset).amount
    assert "is invalid" in errors_on(changeset).exchange_rate
  end

  test "address assigning" do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: 1.2,
               exchange_rate: 2.0,
               currency: :BCH,
               fiat_amount: :USD
             })

    assert {:ok, address} = Addresses.register(:BCH, "bch:0", Addresses.next_address_index(:BCH))

    assert {:ok, invoice} = Invoices.assign_address(invoice, address)
    assert invoice.address == address

    assert {:error, _} =
             Invoices.assign_address(invoice, %Address{
               id: "not-in-db",
               generation_index: 1,
               currency_id: :BCH
             })
  end

  test "ensuring addresses" do
    assert {:ok, inv} =
             Invoices.register(%{
               amount: 1.2,
               exchange_rate: 2.0,
               currency: :BCH,
               fiat_amount: :USD
             })

    assert {:ok, one = %{address_id: "one"}} =
             Invoices.ensure_address(inv, fn _ ->
               "one"
             end)

    assert {:ok, ^one} =
             Invoices.ensure_address(one, fn _ ->
               "xxx"
             end)

    assert {:error, _} =
             Invoices.ensure_address(inv, fn _ ->
               "one"
             end)

    assert {:ok, %{address_id: "two"}} =
             Invoices.ensure_address(inv, fn _ ->
               "two"
             end)

    ind = Addresses.next_address_index(:BCH)

    assert {:ok, _} =
             Invoices.register(%{
               amount: 1.2,
               currency: :BCH,
               exchange_rate: 2.0,
               fiat_currency: :USD
             })

    assert {:ok, %{address_id: "three"}} =
             Invoices.ensure_address(inv, fn _ ->
               "three"
             end)

    assert Addresses.next_address_index(:BCH) != ind
  end

  test "amount calculations" do
    # fiat amount will be calculated from amount * exchange_rate
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: "1.2",
               currency: "BCH",
               exchange_rate: "2.0",
               fiat_currency: "USD"
             })

    assert Money.to_decimal(invoice.fiat_amount) == Decimal.from_float(2.4)

    # amount will be calculated from fiat_amount / exchange_rate
    assert {:ok, invoice} =
             Invoices.register(%{
               fiat_amount: 2.4,
               exchange_rate: 2.0,
               currency: "BCH",
               fiat_currency: "USD"
             })

    assert Money.to_decimal(invoice.amount) == Decimal.from_float(1.2)

    # exchange_rate will be calculated from fiat amount / amount
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: 1.2,
               fiat_amount: 2.4,
               currency: "BCH",
               fiat_currency: "USD"
             })

    assert invoice.exchange_rate == %ExchangeRate{
             rate: Decimal.new(2),
             pair: {:BCH, :USD}
           }

    # if we provide them all, they must match
    assert {:ok, _} =
             Invoices.register(%{
               amount: 1.2,
               fiat_amount: 2.4,
               exchange_rate: 2.0,
               currency: "BCH",
               fiat_currency: "USD"
             })

    assert {:error, _} =
             Invoices.register(%{
               amount: 3000,
               fiat_amount: 2.4,
               exchange_rate: 2.0,
               currency: "BCH",
               fiat_currency: "USD"
             })
  end

  test "large amounts" do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: "127000000000.00000001",
               exchange_rate: "2000000",
               currency: :DGC,
               fiat_currency: :USD
             })

    assert invoice = Invoices.fetch!(invoice.id)
    assert Money.to_decimal(invoice.amount) == Decimal.from_float(127_000_000_000.000_000_01)

    assert Money.to_decimal(invoice.fiat_amount) ==
             Decimal.from_float(254_000_000_000_000_000.000_000_02)
  end
end
