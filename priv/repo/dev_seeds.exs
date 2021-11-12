defmodule BitPal.DevSeeds do
  use BitPalFactory
  alias BitPal.Currencies

  def seed do
    currencies = [:BCH, :XMR]
    Currencies.ensure_exists!(currencies)

    user = create_user(email: "test@bitpal.dev", password: "test_test_test_test")

    create_store(user: user, label: "Reputable store")
    |> with_token(
      data: "SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk"
    )
    |> with_invoices(invoice_count: 100, currencies: currencies, txs: :auto)

    create_store(user: user, label: "Shady store")
    |> with_invoices(invoice_count: 12, currencies: currencies, txs: :auto)
  end

  # def user1 do
  #   user = create_user(email: "test@bitpal.dev", password: "test_test_test_test")
  #   store1(user)
  #   store2(user)
  # end
  #
  # def store1(user) do
  #   store = create_store(user: user, label: "Seed store")
  #
  #   AuthFixtures.token_fixture(
  #     store,
  #     data: "SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk"
  #   )
  #
  #   generate_invoices1(store)
  # end
  #
  # def store2(user) do
  #   store = create_store(user: user, label: "Other store")
  # end
  #
  # def generate_invoices1(store) do
  #   create_invoice(store,
  #     amount: 1,
  #     exchange_rate: 438.75,
  #     currency: "BCH",
  #     fiat_currency: "USD"
  #   )
  #
  #   create_invoice(store,
  #     amount: 2,
  #     exchange_rate: 438.75,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :open
  #   )
  #
  #   create_invoice(store,
  #     amount: 2,
  #     exchange_rate: 438.75,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :open
  #   )
  #   |> create_invoice_transaction!(amount: 1)
  #
  #   create_invoice(store,
  #     amount: 3,
  #     exchange_rate: 438.75,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :paid
  #   )
  #   |> create_invoice_transaction!()
  #
  #   create_invoice(store,
  #     amount: 4,
  #     exchange_rate: 438.75,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :uncollectible
  #   )
  #
  #   create_invoice(store,
  #     amount: 5,
  #     exchange_rate: 438.15,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :paid
  #   )
  #   |> create_invoice_transaction!(amount: 3)
  #   |> create_invoice_transaction!(amount: 2)
  #
  #   create_invoice(store,
  #     amount: 6,
  #     exchange_rate: 438.15,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :paid
  #   )
  #   |> create_invoice_transaction!(amount: 10)
  #
  #   create_invoice(store,
  #     amount: 100,
  #     exchange_rate: 438.15,
  #     currency: "BCH",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :void
  #   )
  #
  #   create_invoice(store,
  #     amount: 0.1,
  #     exchange_rate: 198.52,
  #     currency: "XMR",
  #     fiat_currency: "USD",
  #     address_id: :auto,
  #     status: :paid
  #   )
  #
  #   create_invoice(store,
  #     amount: 0.2,
  #     exchange_rate: 168.58,
  #     currency: "XMR",
  #     fiat_currency: "EUR",
  #     address_id: :auto,
  #     status: :paid
  #   )
  # end
end

BitPal.DevSeeds.seed()
