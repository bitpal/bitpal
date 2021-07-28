# 1. Create a store
# 2. Add access token

import BitPal.CreationHelpers
alias BitPal.Authentication.Tokens
alias BitPal.Currencies

Currencies.register!(:BCH)
Currencies.register!(:XMR)

# Create a store with an access token
store = create_store(label: "Seed store")

token =
  Tokens.insert_token!(
    store,
    "SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk"
  )

# Add some invoices just for testing and introspection purposes
create_invoice(
  store_id: store.id,
  amount: 1,
  exchange_rate: 438.75,
  currency: "BCH",
  fiat_currency: "USD"
)

create_invoice(
  store_id: store.id,
  amount: 2,
  exchange_rate: 438.75,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :open
)

create_invoice(
  store_id: store.id,
  amount: 2,
  exchange_rate: 438.75,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :open
)
|> create_invoice_transaction(amount: 1)

create_invoice(
  store_id: store.id,
  amount: 3,
  exchange_rate: 438.75,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :paid
)
|> create_invoice_transaction()

create_invoice(
  store_id: store.id,
  amount: 4,
  exchange_rate: 438.75,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :uncollectible
)

create_invoice(
  store_id: store.id,
  amount: 5,
  exchange_rate: 438.15,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :paid
)
|> create_invoice_transaction(amount: 3)
|> create_invoice_transaction(amount: 2)

create_invoice(
  store_id: store.id,
  amount: 6,
  exchange_rate: 438.15,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :paid
)
|> create_invoice_transaction(amount: 10)

create_invoice(
  store_id: store.id,
  amount: 100,
  exchange_rate: 438.15,
  currency: "BCH",
  fiat_currency: "USD",
  address: :auto,
  status: :void
)

create_invoice(
  store_id: store.id,
  amount: 0.1,
  exchange_rate: 198.52,
  currency: "XMR",
  fiat_currency: "USD",
  address: :auto,
  status: :paid
)

create_invoice(
  store_id: store.id,
  amount: 0.2,
  exchange_rate: 168.58,
  currency: "XMR",
  fiat_currency: "EUR",
  address: :auto,
  status: :paid
)
