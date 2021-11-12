defmodule BitPalFactory.Factory do
  use ExMachina.Ecto, repo: BitPal.Repo

  use BitPalFactory.StoreFactory
end
