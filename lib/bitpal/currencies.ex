defmodule BitPal.Currencies do
  import Ecto.Query, only: [from: 2]
  alias BitPal.Repo
  alias BitPalSchemas.Currency

  @type id :: atom | String.t()

  @spec get(id) :: Currency.t()
  def get(id) do
    Repo.one(from(c in Currency, where: c.id == ^normalize(id)))
  end

  @spec register!([Currency.id()]) :: :ok
  def register!(ids) when is_list(ids) do
    Enum.each(ids, &register!/1)
  end

  @spec register!(Currency.id()) :: :ok
  def register!(id) do
    Repo.insert!(%Currency{id: normalize(id)}, on_conflict: :nothing)
  end

  @spec normalize(atom | String.t()) :: String.t()
  def normalize(id) when is_binary(id) do
    id |> String.upcase()
  end

  def normalize(id) when is_atom(id) do
    Atom.to_string(id) |> String.upcase()
  end
end
