defmodule BitPalFactory do
  use ExMachina.Ecto, repo: BitPal.Repo

  use BitPalFactory.AccountFactory
  use BitPalFactory.AuthFactory
  use BitPalFactory.CurrencyFactory
  use BitPalFactory.StoreFactory
end
