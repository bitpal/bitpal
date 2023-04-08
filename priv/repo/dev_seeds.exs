defmodule BitPal.DevSeeds do
  use BitPalFactory
  alias BitPal.Currencies
  alias BitPal.ServerSetup

  def seed do
    currencies = [:BCH, :XMR]
    Currencies.ensure_exists!(currencies)

    user = create_user(email: "test@bitpal.dev", password: "test_test_test_test")

    create_store(user: user, label: "Main dev store")
    |> with_token(
      data: "SFMyNTY.g2gDYQFuBgDWhevRegFiAAFRgA.fuiV-GbJoBUmKaSS5PW776HyeFh30-L9pgvn7wuQWKk"
    )
    |> with_address_key(
      data:
        "xpub6C23JpFE6ABbBudoQfwMU239R5Bm6QGoigtLq1BD3cz3cC6DUTg89H3A7kf95GDzfcTis1K1m7ypGuUPmXCaCvoxDKbeNv6wRBEGEnt1NV7",
      currency_id: :BCH
    )

    invalid_time =
      (System.system_time(:second) - 1_000) |> DateTime.from_unix!() |> DateTime.to_naive()

    create_store(user: user, label: "Store with random data")
    |> with_token(
      last_accessed: NaiveDateTime.utc_now(),
      valid_until: invalid_time
    )
    |> with_token(
      valid_until: NaiveDateTime.utc_now() |> NaiveDateTime.add(60 * 60 * 24 * 30, :second)
    )
    |> with_invoices(invoice_count: 100, payment_currencies: [:XMR, :BCH], txs: :auto)

    ServerSetup.store_state(0, :completed)
  end
end

BitPal.DevSeeds.seed()
