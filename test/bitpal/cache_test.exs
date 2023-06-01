defmodule BitPal.ExchangeRate.CacheTest do
  use ExUnit.Case, async: false
  import BitPal.TestHelpers
  alias BitPal.Cache
  require Logger

  @moduletag ttl: 100

  setup %{ttl: ttl} do
    # credo:disable-for-next-line Credo.Check.Warning.UnsafeToAtom
    name = Ecto.UUID.generate() |> String.to_atom()

    pid =
      start_supervised!(
        {Cache, name: name, ttl: ttl, ttl_check_interval: 10, log_level: :none},
        restart: :temporary
      )

    {:ok, name: name, pid: pid}
  end

  test "key value pairs can be put and fetched from cache", %{name: name} do
    assert :ok = Cache.put(name, :key1, :value1)
    assert :ok = Cache.put(name, :key2, :value2)

    assert Cache.fetch(name, :key1) == {:ok, :value1}
    assert Cache.fetch(name, :key2) == {:ok, :value2}
  end

  test "unfound entry returns error", %{name: name} do
    assert Cache.fetch(name, :notexists) == :error
  end

  test "clears all entries after clear interval", %{name: name} do
    assert :ok = Cache.put(name, :key1, :value1)
    assert Cache.fetch(name, :key1) == {:ok, :value1}
    assert eventually(fn -> Cache.fetch(name, :key1) == :error end)
  end

  @tag ttl: 60_000
  test "values are cleaned up on exit", %{name: name, pid: pid} do
    # Hack to silence GenServer crash error somewhere inside ConCache
    last_log_level = Logger.level()
    Logger.configure(level: :none)

    assert :ok = Cache.put(name, :key1, :value1)
    assert_shutdown(pid)
    {:ok, _cache} = Cache.start_link(name: name, ttl: 60_000, ttl_check_interval: 10)
    assert Cache.fetch(name, :key1) == :error

    Logger.configure(level: last_log_level)
  end
end
