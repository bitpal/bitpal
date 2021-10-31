defmodule BitPalFixtures do
  defmacro __using__(_) do
    quote do
      alias BitPalFixtures.AccountFixtures
      alias BitPalFixtures.AddressFixtures
      alias BitPalFixtures.AuthFixtures
      alias BitPalFixtures.CurrencyFixtures
      alias BitPalFixtures.InvoiceFixtures
      alias BitPalFixtures.StoreFixtures
    end
  end
end
