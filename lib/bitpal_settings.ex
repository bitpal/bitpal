defmodule BitPalSettings do
  alias BitPal.BackendManager

  def get_env(key_or_path, default \\ nil) do
    case fetch_env(key_or_path) do
      {:ok, res} -> res
      _ -> default
    end
  end

  def fetch_env(key) when is_atom(key) do
    Application.fetch_env(:bitpal, key)
  end

  def fetch_env([key | rest]) do
    traverse_env(Application.fetch_env(:bitpal, key), rest)
  end

  def fetch_env!(key_or_path) do
    {:ok, res} = fetch_env(key_or_path)
    res
  end

  defp traverse_env(res, []), do: res
  defp traverse_env(:error, _paths), do: :error
  defp traverse_env({:ok, value}, [key | rest]), do: traverse_env(Access.fetch(value, key), rest)

  # FIXME do the same with tcp and rpc clients?
  @spec http_client :: module
  def http_client do
    Application.get_env(:bitpal, :http_client, BitPal.HTTPClient)
  end

  @spec config_change(keyword, keyword, keyword) :: :ok
  def config_change(changed, new, removed) do
    BackendManager.config_change(changed, new, removed)
  end
end
