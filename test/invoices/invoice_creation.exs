defmodule InvoiceCreationTest do
  use BitPal.IntegrationCase, db: true, async: true
  alias BitPal.Addresses
  alias BitPal.Currencies
  alias BitPal.Invoices
  alias BitPalSchemas.Address

  setup do
    Currencies.register!([:xmr, :bch])
  end

  test "invoice registration" do
    assert {:ok, invoice} =
             Invoices.register(%{
               currency: :bch,
               amount: 1.2,
               exchange_rate: {1.1, "USD"}
             })

    invoice = Repo.preload(invoice, :currency)

    assert invoice.id != nil
    assert invoice.amount == Decimal.from_float(1.2)
    assert invoice.status == :pending
    assert invoice.currency_id == "BCH"
    assert invoice.currency.id == "BCH"
    assert invoice.address_id == nil
    assert invoice.exchange_rate == {Decimal.from_float(1.1), "USD"}

    assert {:error, changeset} = Invoices.register(%{amount: 1.2, exchange_rate: {1.1, "USD"}})

    assert "can't be blank" in errors_on(changeset).currency

    assert {:error, changeset} =
             Invoices.register(%{currency: "no-no", amount: 1.2, exchange_rate: {1.1, "USD"}})

    assert "does not exist" in errors_on(changeset).currency

    assert {:error, changeset} =
             Invoices.register(%{currency: :bch, amount: "xxx", exchange_rate: {1.1, "USD"}})

    assert "is invalid" in errors_on(changeset).amount
  end

  test "address assigning" do
    assert {:ok, invoice} =
             Invoices.register(%{currency: :bch, amount: 1.2, exchange_rate: {1.1, "USD"}})

    assert {:ok, address} = Addresses.register(:bch, "bch:0", 0)

    assert {:ok, invoice} = Invoices.assign_address(invoice, address)
    assert invoice.address == address

    assert {:error, _} =
             Invoices.assign_address(invoice, %Address{
               id: "not-in-db",
               generation_index: 1,
               currency_id: "BCH"
             })
  end

  @tag do: true
  test "amount calculations" do
    assert {:ok, invoice} =
             Invoices.register(%{
               currency: :bch,
               amount: 1.2,
               exchange_rate: {2.0, "USD"}
             })

    assert invoice.amount == Decimal.from_float(1.2)
    assert invoice.fiat_amount == Decimal.from_float(2.4)

    assert {:ok, invoice} =
             Invoices.register(%{
               currency: :bch,
               fiat_amount: 1.2,
               exchange_rate: {2.0, "USD"}
             })

    assert invoice.amount == Decimal.from_float(0.6)
    assert invoice.fiat_amount == Decimal.from_float(1.2)

    assert {:error, changeset} =
             Invoices.register(%{
               currency: :bch,
               amount: 1,
               fiat_amount: 1.2
             })

    assert "must provide an exchange rate" in errors_on(changeset).exchange_rate

    assert {:error, changeset} =
             Invoices.register(%{
               currency: :bch,
               exchange_rate: {2.0, "USD"}
             })

    assert "must provide amount in either crypto or fiat" in errors_on(changeset).amount
    assert "must provide amount in either crypto or fiat" in errors_on(changeset).fiat_amount
  end
end
