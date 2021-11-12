defmodule BitPalFixtures do
  defmacro __using__(_) do
    quote do
      import BitPalFactory.Factory

      alias BitPalFixtures.SettingsFixtures
      alias BitPalFixtures.AccountFixtures
      alias BitPalFixtures.AddressFixtures
      alias BitPalFixtures.AuthFixtures
      alias BitPalFixtures.CurrencyFixtures
      alias BitPalFixtures.InvoiceFixtures
      alias BitPalFixtures.StoreFixtures
      alias BitPalFixtures.TransactionFixtures
    end
  end
end
