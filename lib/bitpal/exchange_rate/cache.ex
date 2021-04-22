defmodule BitPal.ExchangeRate.Cache do
  @moduledoc """
  A simple cache as seen in Programming Phoenix >= 1.4
  """

  use GenServer

  @clear_interval :timer.seconds(60)

  def put(name \\ __MODULE__, key, value) do
    true = :ets.insert(name, {key, value})
    :ok
  end

  def fetch(name \\ __MODULE__, key) do
    {:ok, :ets.lookup_element(name, key, 2)}
  rescue
    ArgumentError -> :error
  end

  def start_link(opts) do
    opts = Keyword.put_new(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    state = %{
      interval: opts[:clear_interval] || @clear_interval,
      timer: nil,
      table: new_table(opts[:name])
    }

    {:ok, schedule_clear(state)}
  end

  def child_spec(arg) do
    id = Keyword.get(arg, :name) || __MODULE__

    %{
      id: id,
      start: {__MODULE__, :start_link, [arg]}
    }
  end

  def handle_info(:clear, state) do
    :ets.delete_all_objects(state.table)
    {:noreply, schedule_clear(state)}
  end

  defp schedule_clear(state) do
    if state.interval == :never do
      state
    else
      %{state | timer: Process.send_after(self(), :clear, state.interval)}
    end
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
