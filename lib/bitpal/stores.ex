defmodule BitPal.Stores do
  alias BitPal.Repo
  alias BitPalSchemas.Store

  @spec fetch(non_neg_integer) :: {:ok, Store.t()} | :error
  def fetch(id) do
    if store = Repo.get(Store, id) do
      {:ok, store}
    else
      :error
    end
  end

  @spec fetch!(non_neg_integer) :: Store.t()
  def fetch!(id) do
    {:ok, store} = fetch(id)
    store
  end

  @spec create! :: Store.t()
  def create! do
    Repo.insert!(%Store{})
  end

  @spec all :: [Store.t()]
  def all do
    Repo.all(Store)
  end
end
