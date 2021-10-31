defmodule BitPalFixtures.StoreFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Stores` context.
  """

  alias BitPal.Stores
  alias BitPalSchemas.User

  def unique_store_label do
    "#{Faker.Company.name()} #{System.unique_integer()}"
  end

  def valid_store_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      label: unique_store_label()
    })
  end

  @spec store_fixture :: Store.t()
  def store_fixture() do
    {:ok, store} = Stores.create(valid_store_attributes(%{}))
    store
  end

  @spec store_fixture(map) :: Store.t()
  def store_fixture(attrs) when is_list(attrs) or (is_map(attrs) and not is_struct(attrs)) do
    if user = attrs[:user] do
      store_fixture(user, attrs)
    else
      {:ok, store} = Stores.create(valid_store_attributes(attrs))
      store
    end
  end

  @spec store_fixture(User.t(), map | keyword) :: Store.t()
  def store_fixture(user = %User{}, attrs \\ %{}) do
    {:ok, store} =
      user
      |> Stores.create(valid_store_attributes(attrs))

    store
  end
end
