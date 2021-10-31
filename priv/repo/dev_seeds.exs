defmodule Seeder do
  import BitPal.CreationHelpers
  alias BitPal.Currencies

  def seed do
    Currencies.ensure_exists!([:BCH, :XMR])
    user1()
  end

  def user1 do
    user = create_user!(email: "test@bitpal.dev", password: "test_test_test_test")
    store1(user)
    store2(user)
  end

  def store1(user) do
    store = create_store!(user: user, label: "Seed store")

    create_token!(
      store,
      "SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk"
    )

    generate_invoices1(store)
  end

  def store2(user) do
    store = create_store!(user: user, label: "Other store")
  end

  def generate_invoices1(store) do
    create_invoice!(
      store_id: store.id,
      amount: 1,
      exchange_rate: 438.75,
      currency: "BCH",
      fiat_currency: "USD"
    )

    create_invoice!(
      store_id: store.id,
      amount: 2,
      exchange_rate: 438.75,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :open
    )

    create_invoice!(
      store_id: store.id,
      amount: 2,
      exchange_rate: 438.75,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :open
    )
    |> create_invoice_transaction!(amount: 1)

    create_invoice!(
      store_id: store.id,
      amount: 3,
      exchange_rate: 438.75,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :paid
    )
    |> create_invoice_transaction!()

    create_invoice!(
      store_id: store.id,
      amount: 4,
      exchange_rate: 438.75,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :uncollectible
    )

    create_invoice!(
      store_id: store.id,
      amount: 5,
      exchange_rate: 438.15,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :paid
    )
    |> create_invoice_transaction!(amount: 3)
    |> create_invoice_transaction!(amount: 2)

    create_invoice!(
      store_id: store.id,
      amount: 6,
      exchange_rate: 438.15,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :paid
    )
    |> create_invoice_transaction!(amount: 10)

    create_invoice!(
      store_id: store.id,
      amount: 100,
      exchange_rate: 438.15,
      currency: "BCH",
      fiat_currency: "USD",
      address: :auto,
      status: :void
    )

    create_invoice!(
      store_id: store.id,
      amount: 0.1,
      exchange_rate: 198.52,
      currency: "XMR",
      fiat_currency: "USD",
      address: :auto,
      status: :paid
    )

    create_invoice!(
      store_id: store.id,
      amount: 0.2,
      exchange_rate: 168.58,
      currency: "XMR",
      fiat_currency: "EUR",
      address: :auto,
      status: :paid
    )
  end
end

Seeder.seed()
