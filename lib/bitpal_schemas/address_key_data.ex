defmodule BitPalSchemas.AddressKeyData do
  use Ecto.Type
  import Ecto.Changeset

  @type t ::
          %{xpub: String.t()}
          | %{viewkey: String.t(), address: String.t(), account: non_neg_integer}

  @impl true
  def type, do: :map

  @impl true
  def cast(data) do
    # Only one of xpub and viewkey can be specified at the same time
    xpub = cast_xpub(data)
    viewkey = cast_viewkey(data)

    case {xpub, viewkey} do
      {{:ok, res}, {:error, _}} -> {:ok, res}
      {{:error, _}, {:ok, res}} -> {:ok, res}
      _ -> :error
    end
  end

  defp cast_xpub(data) do
    entries = %{xpub: :string}

    {%{}, entries}
    |> cast(data, Map.keys(entries))
    |> validate_required(:xpub)
    |> apply_action(:cast)
  end

  defp cast_viewkey(data) do
    entries = %{viewkey: :string, address: :string, account: :integer}

    {%{}, entries}
    |> cast(data, Map.keys(entries))
    |> validate_required([:viewkey, :address, :account])
    |> validate_number(:account, greater_than_or_equal_to: 0)
    |> apply_action(:cast)
  end

  @impl true
  def load(%{"xpub" => xpub}) do
    {:ok, %{xpub: xpub}}
  end

  def load(%{"viewkey" => viewkey, "address" => address, "account" => account}) do
    {:ok, %{viewkey: viewkey, address: address, account: account}}
  end

  @impl true
  def dump(data) when is_map(data) do
    {:ok, data}
  end
end
