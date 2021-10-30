defmodule BitPal.StoresFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Stores` context.
  """

  alias BitPal.Stores
  alias BitPalSchemas.User

  def unique_store_label, do: "Store#{System.unique_integer()}"

  def valid_store_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      label: unique_store_label()
    })
  end

  def store_fixture() do
    {:ok, store} = Stores.create(valid_store_attributes(%{}))
    store
  end

  def store_fixture(user = %User{}, attrs \\ %{}) do
    {:ok, store} =
      user
      |> Stores.create(valid_store_attributes(attrs))

    store
  end
end
