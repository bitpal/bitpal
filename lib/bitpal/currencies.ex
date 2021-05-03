defmodule BitPal.Currencies do
  import Ecto.Query, only: [from: 2]
  alias BitPal.Repo
  alias BitPalSchemas.Currency

  @type id :: atom | String.t()

  def get(nil), do: nil

  def get(id) do
    Repo.one(from(c in Currency, where: c.id == ^normalize(id)))
  end

  def register!(ids) when is_list(ids) do
    Enum.each(ids, &register!/1)
  end

  def register!(id) do
    Repo.insert!(%Currency{id: normalize(id)}, on_conflict: :nothing)
  end

  def normalize(nil), do: nil

  def normalize(id) when is_binary(id) do
    id
  end

  def normalize(id) when is_atom(id) do
    Atom.to_string(id) |> String.upcase()
  end
end
