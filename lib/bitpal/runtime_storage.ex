defmodule BitPal.RuntimeStorage do
  @moduledoc """
  Runtime storage as a simple wrapper around ets tables.
  """

  use GenServer

  @spec put(atom, term, term) :: :ok
  def put(name \\ __MODULE__, key, value) do
    true = :ets.insert(name, {key, value})
    :ok
  end

  @spec fetch(atom, term) :: {:ok, term} | :error
  def fetch(name \\ __MODULE__, key) do
    {:ok, :ets.lookup_element(name, key, 2)}
  rescue
    ArgumentError ->
      :error
  end

  @spec get_or_put_lazy(atom, term, (() -> term)) :: term
  def get_or_put_lazy(name \\ __MODULE__, key, default) do
    case fetch(name, key) do
      {:ok, res} ->
        res

      _ ->
        value = default.()
        :ok = put(name, key, value)
        value
    end
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    {:ok, %{table: new_table(opts[:name])}}
  end

  def child_spec(arg) do
    id = Keyword.get(arg, :name) || __MODULE__

    %{
      id: id,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  defp new_table(name) do
    name
    |> :ets.new([
      :set,
      :named_table,
      :public,
      read_concurrency: true,
      write_concurrency: true
    ])
  end
end
