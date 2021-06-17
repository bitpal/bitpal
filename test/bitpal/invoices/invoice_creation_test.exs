defmodule InvoiceCreationTest do
  use BitPal.IntegrationCase, db: true, async: false
  alias BitPal.Addresses
  alias BitPal.ExchangeRate
  alias BitPal.Invoices
  alias BitPalSchemas.Address

  test "invoice registration" do
    # we don't have to provide fiat_amount
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    invoice = Repo.preload(invoice, :currency)

    assert invoice.id != nil
    assert invoice.amount == Money.parse!(1.2, "BCH")
    assert invoice.fiat_amount == Money.parse!(2.4, "USD")
    assert invoice.status == :draft
    assert invoice.currency_id == "BCH"
    assert invoice.currency.id == "BCH"
    assert invoice.address_id == nil

    assert invoice.exchange_rate == %ExchangeRate{
             rate: Decimal.from_float(2.0),
             pair: {:BCH, :USD}
           }

    assert in_db = Invoices.fetch!(invoice.id)
    assert in_db.id == invoice.id

    # it's fine to skip fiat_amount + exchange_rate
    assert {:ok, invoice} = Invoices.register(%{amount: Money.parse!(1.2, "BCH")})

    assert Money.to_decimal(invoice.amount) == Decimal.from_float(1.2)
    assert invoice.fiat_amount == nil
    assert invoice.exchange_rate == nil

    # but we must have either amount or exchange_rate, otherwise we don't
    # know how much crypto to ask for
    assert {:error, changeset} = Invoices.register(%{fiat_amount: Money.parse!(1.2, "BCH")})

    assert "must provide either amount or exchange rate" in errors_on(changeset).amount

    # only exchange rate isn't enough either
    assert {:error, changeset} =
             Invoices.register(%{
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert "must provide amount in either crypto or fiat" in errors_on(changeset).amount

    # other invalid inputs
    assert {:error, changeset} =
             Invoices.register(%{
               amount: Money.parse!(-2.5, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert "cannot be negative" in errors_on(changeset).amount

    assert {:error, changeset} =
             Invoices.register(%{
               amount: "BORK",
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert "is invalid" in errors_on(changeset).amount
  end

  test "address assigning" do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:ok, address} = Addresses.register(:BCH, "bch:0", Addresses.next_address_index("BCH"))

    assert {:ok, invoice} = Invoices.assign_address(invoice, address)
    assert invoice.address == address

    assert {:error, _} =
             Invoices.assign_address(invoice, %Address{
               id: "not-in-db",
               generation_index: 1,
               currency_id: "BCH"
             })
  end

  test "ensuring addresses" do
    assert {:ok, inv} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
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
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:ok, %{address_id: "three"}} =
             Invoices.ensure_address(inv, fn _ ->
               "three"
             end)

    assert Addresses.next_address_index(:BCH) != ind
  end

  test "amount calculations" do
    # fiat amount will be calculated from amount + exchange_rate
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert Money.to_decimal(invoice.fiat_amount) == Decimal.from_float(2.4)

    # amount will be calculated from fiat_amount + exchange_rate
    assert {:ok, invoice} =
             Invoices.register(%{
               fiat_amount: Money.parse!(2.4, :USD),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert Money.to_decimal(invoice.amount) == Decimal.from_float(1.2)

    # exchange_rate will be calculated from amount + fiat_amount
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               fiat_amount: Money.parse!(2.4, :USD)
             })

    assert invoice.exchange_rate == %ExchangeRate{
             rate: Decimal.new(2),
             pair: {:BCH, :USD}
           }

    # if we provide them all, they must match
    assert {:ok, _} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               fiat_amount: Money.parse!(2.4, :USD),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:error, _} =
             Invoices.register(%{
               amount: Money.parse!(3000, "BCH"),
               fiat_amount: Money.parse!(2.4, :USD),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:error, _} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               fiat_amount: Money.parse!(2.4, :USD),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "EUR"})
             })
  end

  test "large amounts" do
    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(127_000_000_000.000_000_01, :DGC),
               exchange_rate: ExchangeRate.new!(Decimal.new(2_000_000), {"DGC", "USD"})
             })

    assert invoice = Invoices.fetch!(invoice.id)
    assert Money.to_decimal(invoice.amount) == Decimal.from_float(127_000_000_000.000_000_01)

    assert Money.to_decimal(invoice.fiat_amount) ==
             Decimal.from_float(254_000_000_000_000_000.000_000_02)
  end

  @tag backends: true
  test "register via finalize" do
    assert {:ok, _} =
             BitPal.register_and_finalize(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:ok, invoice} =
             Invoices.register(%{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:ok, _} = BitPal.finalize(invoice)

    assert {:error, _} =
             BitPal.finalize(%Invoice{
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    assert {:error, _} =
             BitPal.finalize(%Invoice{
               id: Ecto.UUID.bingenerate(),
               amount: Money.parse!(1.2, "BCH"),
               exchange_rate: ExchangeRate.new!(Decimal.from_float(2.0), {"BCH", "USD"})
             })

    Process.sleep(200)
  end
end
