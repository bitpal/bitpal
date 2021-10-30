defmodule BitPalFixtures do
  defmacro __using__(_) do
    quote do
      alias BitPalFixtures.AccountFixtures
      alias BitPalFixtures.StoreFixtures
      alias BitPalFixtures.InvoiceFixtures
    end
  end
end