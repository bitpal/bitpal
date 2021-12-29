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
end

BitPal.DevSeeds.seed()
