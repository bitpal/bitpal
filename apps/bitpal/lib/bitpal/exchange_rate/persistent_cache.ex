defmodule BitPal.ExchangeRate.PersistentCache do
  @moduledoc """
  A simple cache that never explicitly clears
  """

  use GenServer

  def put(name \\ __MODULE__, key, value) do
    true = :ets.insert(tab_name(name), {key, value})
    :ok
  end

  def fetch(name \\ __MODULE__, key) do
    {:ok, :ets.lookup_element(tab_name(name), key, 2)}
  rescue
    ArgumentError -> :error
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    state = %{
      table: new_table(opts[:name])
    }

    {:ok, state}
  end

  defp new_table(name) do
    name
    |> tab_name()
    |> :ets.new([
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end

  defp tab_name(name), do: :"#{name}_persistent_cache"
end
