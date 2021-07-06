defmodule Ecto.Atom do
  @moduledoc """
  Provides a type for Ecto atoms.
  """

  use Ecto.Type

  @type t :: atom

  @impl true
  def type, do: :string

  @impl true
  def cast(x) when is_atom(x), do: {:ok, x}
  def cast(x) when is_binary(x), do: {:ok, String.to_existing_atom(x)}
  def cast(_), do: :error

  @impl true
  def load(x) when is_binary(x), do: {:ok, String.to_existing_atom(x)}

  @impl true
  def dump(x) when is_atom(x), do: {:ok, Atom.to_string(x)}
  def dump(_), do: :error
end
