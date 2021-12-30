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

    invalid_time =
      (System.system_time(:second) - 1_000) |> DateTime.from_unix!() |> DateTime.to_naive()

    create_store(user: user, label: "Shady store")
    |> with_token(
      last_accessed: NaiveDateTime.utc_now(),
      valid_until: invalid_time
    )
    |> with_token(
      valid_until: NaiveDateTime.utc_now() |> NaiveDateTime.add(60 * 60 * 24 * 30, :second)
    )
    |> with_invoices(invoice_count: 12, currencies: currencies, txs: :auto)
  end
end

BitPal.DevSeeds.seed()
