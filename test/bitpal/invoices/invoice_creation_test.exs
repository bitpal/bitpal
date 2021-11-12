defmodule InvoiceCreationTest do
  use BitPal.DataCase, async: true
  alias BitPal.Addresses
  alias BitPal.ExchangeRate
  alias BitPal.Invoices
  alias BitPalSchemas.Address
  alias BitPalSchemas.Store

  setup do
    store = insert(:store)
    %{store_id: store.id}
  end

  describe "register/2" do
    test "basic invoice registration", %{store_id: store_id} do
      # we don't have to provide fiat_amount
      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 amount: "1.2",
                 currency_id: "BCH",
                 exchange_rate: "2.0",
                 fiat_currency: "USD",
                 email: "test@bitpal.dev",
                 description: "My awesome invoice",
                 pos_data: %{
                   "some" => "data",
                   "other" => %{"even_more" => 0}
                 }
               })

      invoice = Repo.preload(invoice, :currency)

      assert invoice.id != nil
      assert invoice.amount == Money.parse!(1.2, :BCH)
      assert invoice.fiat_amount == Money.parse!(2.4, :USD)
      assert invoice.status == :draft
      assert invoice.currency_id == :BCH
      assert invoice.currency.id == :BCH
      assert invoice.address_id == nil
      assert invoice.email == "test@bitpal.dev"
      assert invoice.description == "My awesome invoice"

      assert invoice.pos_data == %{
               "some" => "data",
               "other" => %{"even_more" => 0}
             }

      assert invoice.exchange_rate == %ExchangeRate{
               rate: Decimal.from_float(2.0),
               pair: {:BCH, :USD}
             }

      assert in_db = Invoices.fetch!(invoice.id)
      assert in_db.id == invoice.id

      # it's fine to skip fiat_amount + exchange_rate
      assert {:ok, invoice} = Invoices.register(store_id, %{amount: 1.2, currency_id: :BCH})

      assert Money.to_decimal(invoice.amount) == Decimal.new("1.20000000")
      assert invoice.fiat_amount == nil
      assert invoice.exchange_rate == nil

      # We must supply currency
      assert {:error, changeset} = Invoices.register(store_id, %{amount: 1.2})
      assert "cannot be empty" in errors_on(changeset).currency_id

      # Currency must be valid
      assert {:error, changeset} =
               Invoices.register(store_id, %{amount: 1.2, currency_id: "crap"})

      assert "is invalid" in errors_on(changeset).currency_id

      assert {:error, changeset} =
               Invoices.register(store_id, %{amount: 1.2, fiat_currency: "crap"})

      assert "is invalid" in errors_on(changeset).fiat_currency

      # But fiat alone isn't enough
      assert {:error, changeset} =
               Invoices.register(store_id, %{fiat_amount: 1.2, fiat_currency: "USD"})

      assert "must provide either amount or exchange rate" in errors_on(changeset).amount

      # Only exchange rate isn't enough either
      assert {:error, changeset} =
               Invoices.register(store_id, %{
                 currency_id: "BCH",
                 fiat_currency: "USD",
                 exchange_rate: 2.0
               })

      assert "must provide amount in either crypto or fiat" in errors_on(changeset).amount

      # Other invalid inputs
      assert {:error, changeset} =
               Invoices.register(store_id, %{
                 currency_id: "BCH",
                 fiat_currency: "USD",
                 amount: -2.5,
                 exchange_rate: -2.0
               })

      assert "must be greater than 0" in errors_on(changeset).amount
      assert "is invalid" in errors_on(changeset).exchange_rate

      assert {:error, changeset} =
               Invoices.register(store_id, %{
                 currency_id: "BCH",
                 fiat_currency: "USD",
                 amount: "13bad",
                 exchange_rate: "xxx"
               })

      assert "is invalid" in errors_on(changeset).amount
      assert "is invalid" in errors_on(changeset).exchange_rate

      assert {:error, _changeset} =
               Invoices.register(store_id, %{
                 amount: "1.2",
                 currency_id: "BCH",
                 exchange_rate: "2.0",
                 fiat_currency: "USD",
                 email: "bad email"
               })
    end

    test "store invoice association", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(
                 store_id,
                 %{
                   amount: "1.2",
                   currency_id: unique_currency_id(),
                   exchange_rate: "2.0",
                   fiat_currency: unique_fiat()
                 }
               )

      store = Repo.get!(Store, store_id) |> Repo.preload([:invoices])
      assert length(store.invoices) == 1
      assert invoice.store_id == store.id
    end

    test "amount calculations", %{store_id: store_id} do
      # fiat amount will be calculated from amount * exchange_rate
      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 amount: "1.2",
                 currency_id: "BCH",
                 exchange_rate: "2.0",
                 fiat_currency: "USD"
               })

      assert Money.to_decimal(invoice.fiat_amount) == Decimal.new("2.40")

      # amount will be calculated from fiat_amount / exchange_rate
      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 fiat_amount: 2.4,
                 exchange_rate: 2.0,
                 currency_id: "BCH",
                 fiat_currency: "USD"
               })

      assert Money.to_decimal(invoice.amount) == Decimal.new("1.20000000")

      # exchange_rate will be calculated from fiat amount / amount
      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 amount: 1.2,
                 fiat_amount: 2.4,
                 currency_id: "BCH",
                 fiat_currency: "USD"
               })

      assert invoice.exchange_rate == %ExchangeRate{
               rate: Decimal.new(2),
               pair: {:BCH, :USD}
             }

      # if we provide them all, they must match
      assert {:ok, _} =
               Invoices.register(store_id, %{
                 amount: 1.2,
                 fiat_amount: 2.4,
                 exchange_rate: 2.0,
                 currency_id: "BCH",
                 fiat_currency: "USD"
               })

      assert {:error, _} =
               Invoices.register(store_id, %{
                 amount: 3000,
                 fiat_amount: 2.4,
                 exchange_rate: 2.0,
                 currency_id: "BCH",
                 fiat_currency: "USD"
               })
    end

    test "large amounts", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 amount: "127000000000.00000001",
                 exchange_rate: "2000000",
                 currency_id: :DGC,
                 fiat_currency: :USD
               })

      assert invoice = Invoices.fetch!(invoice.id)
      assert Money.to_decimal(invoice.amount) == Decimal.new("127000000000.00000001")

      assert Money.to_decimal(invoice.fiat_amount) ==
               Decimal.new("254000000000000000.02")
    end
  end

  describe "assign_address/2" do
    @tag do: true
    test "address assigning", %{store_id: store_id} do
      assert {:ok, invoice} =
               Invoices.register(store_id, %{
                 amount: 1.2,
                 exchange_rate: 2.0,
                 currency_id: :BCH,
                 fiat_amount: :USD
               })

      assert address =
               AddressFixtures.address_fixture(
                 currency_id: invoice.currency_id,
                 store_id: invoice.store_id
               )

      assert {:ok, invoice} = Invoices.assign_address(invoice, address)
      assert invoice.address == address

      assert {:error, _} =
               Invoices.assign_address(invoice, %Address{
                 id: "not-in-db",
                 address_index: 1,
                 currency_id: :BCH
               })
    end
  end

  describe "ensure_address/2" do
    test "ensuring addresses", %{store_id: store_id} do
      assert {:ok, inv} =
               Invoices.register(store_id, %{
                 amount: 1.2,
                 exchange_rate: 2.0,
                 currency_id: :BCH,
                 fiat_amount: :USD
               })

      SettingsFixtures.address_key_fixture(inv)

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

      {:ok, address_key} = Invoices.address_key(inv)
      ind = Addresses.next_address_index(address_key)

      assert {:ok, _} =
               Invoices.register(store_id, %{
                 amount: 1.2,
                 currency_id: :BCH,
                 exchange_rate: 2.0,
                 fiat_currency: :USD
               })

      assert {:ok, %{address_id: "three"}} =
               Invoices.ensure_address(inv, fn _ ->
                 "three"
               end)

      assert Addresses.next_address_index(address_key) != ind
    end
  end
end
