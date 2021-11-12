defmodule BitPal.DevSeeds do
  use BitPalFixtures

  def seed do
    user1()
  end

  def user1 do
    user = AccountFixtures.user_fixture(email: "test@bitpal.dev", password: "test_test_test_test")
    store1(user)
    store2(user)
  end

  def store1(user) do
    store = StoreFixtures.store_fixture(user: user, label: "Seed store")

    AuthFixtures.token_fixture(
      store,
      data: "SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk"
    )

    generate_invoices1(store)
  end

  def store2(user) do
    _store = StoreFixtures.store_fixture(user: user, label: "Other store")
  end

  def generate_invoices1(store) do
    # InvoiceFixtures.invoice_fixture(store,
    #   amount: 1,
    #   exchange_rate: 438.75,
    #   currency: "BCH",
    #   fiat_currency: "USD"
    # )
    #
    # InvoiceFixtures.invoice_fixture(store,
    #   amount: 2,
    #     exchange_rate: 438.75,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :open
    #   )
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 2,
    #     exchange_rate: 438.75,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :open
    #   )
    #   |> create_invoice_transaction!(amount: 1)
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 3,
    #     exchange_rate: 438.75,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :paid
    #   )
    #   |> create_invoice_transaction!()
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 4,
    #     exchange_rate: 438.75,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :uncollectible
    #   )
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 5,
    #     exchange_rate: 438.15,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :paid
    #   )
    #   |> create_invoice_transaction!(amount: 3)
    #   |> create_invoice_transaction!(amount: 2)
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 6,
    #     exchange_rate: 438.15,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :paid
    #   )
    #   |> create_invoice_transaction!(amount: 10)
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 100,
    #     exchange_rate: 438.15,
    #     currency: "BCH",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :void
    #   )
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 0.1,
    #     exchange_rate: 198.52,
    #     currency: "XMR",
    #     fiat_currency: "USD",
    #     address: :auto,
    #     status: :paid
    #   )
    #
    #   InvoiceFixtures.invoice_fixture(store,
    #     amount: 0.2,
    #     exchange_rate: 168.58,
    #     currency: "XMR",
    #     fiat_currency: "EUR",
    #     address: :auto,
    #     status: :paid
    #   )
  end
end

BitPal.DevSeeds.seed()
