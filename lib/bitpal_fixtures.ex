defmodule BitPalFixtures do
  defmacro __using__(_) do
    quote do
      use BitPalFactory

      alias BitPalFixtures.SettingsFixtures
      alias BitPalFixtures.AddressFixtures
      alias BitPalFixtures.InvoiceFixtures
      alias BitPalFixtures.TransactionFixtures
    end
  end
end
