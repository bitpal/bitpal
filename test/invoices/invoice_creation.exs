defmodule InvoiceCreationTest do
  use BitPal.DataCase, async: true
  alias BitPal.Addresses
  alias BitPal.Currencies
  alias BitPal.Invoices
  alias BitPalSchemas.Address

  setup do
    Currencies.register!([:xmr, :bch])
  end

  test "invoice registration" do
    assert {:ok, invoice} = Invoices.register(%{currency: :bch, amount: 1.2})

    invoice = Repo.preload(invoice, :currency)

    assert invoice.id != nil
    assert invoice.amount == Decimal.from_float(1.2)
    assert invoice.status == :pending
    assert invoice.currency_id == "BCH"
    assert invoice.currency.ticker == "BCH"
    assert invoice.address_id == nil

    assert {:error, changeset} = Invoices.register(%{amount: 1.2})

    assert "can't be blank" in errors_on(changeset).currency

    assert {:error, changeset} = Invoices.register(%{currency: "no-no", amount: 1.2})

    assert "does not exist" in errors_on(changeset).currency

    assert {:error, changeset} = Invoices.register(%{currency: :bch, amount: "xxx"})

    assert "is invalid" in errors_on(changeset).amount
  end

  test "address assigning" do
    assert {:ok, invoice} = Invoices.register(%{currency: :bch, amount: 1.2})

    assert {:ok, address} = Addresses.register(:bch, "bch:0", 0)

    assert {:ok, invoice} = Invoices.assign_address(invoice, address)
    assert invoice.address == address

    assert {:error, _} =
             Invoices.assign_address(invoice, %Address{
               address: "not-in-db",
               address_index: 1
             })
  end
end
