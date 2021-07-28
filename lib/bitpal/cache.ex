defmodule BitPal.Cache do
  @moduledoc """
  """

  @spec start_link(ConCache.options()) :: Supervisor.on_start()
  def start_link(opts) do
    Process.flag(:trap_exit, true)

    ConCache.start_link(
      name: Keyword.get(opts, :name, __MODULE__),
      ttl_check_interval: Keyword.fetch!(opts, :ttl_check_interval),
      global_ttl: Keyword.get(opts, :ttl)
    )
  end

  @spec child_spec(keyword) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: Keyword.get(opts, :name, __MODULE__),
      start: {__MODULE__, :start_link, [opts]}
    }
  end

  @spec put(atom, term, term) :: :ok
  def put(name \\ __MODULE__, key, val) do
    ConCache.put(name, key, val)
  end

  @spec get(atom, term) :: term | nil
  def get(name \\ __MODULE__, key) do
    ConCache.get(name, key)
  end

  @spec fetch(atom, term) :: {:ok, term} | :error
  def fetch(name \\ __MODULE__, key) do
    if val = ConCache.get(name, key) do
      {:ok, val}
    else
      :error
    end
  end

  @spec fetch!(atom, term) :: term
  def fetch!(name \\ __MODULE__, key) do
    {:ok, val} = fetch(name, key)
    val
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
end
