defmodule BitPal.RuntimeStorageTest do
  use ExUnit.Case, async: true
  import BitPal.TestHelpers
  alias BitPal.RuntimeStorage

  setup %{test: name} do
    {:ok, pid} = RuntimeStorage.start_link(name: name)
    {:ok, name: name, pid: pid}
  end

  test "key value pairs can be put and fetched from cache", %{name: name} do
    assert :ok = RuntimeStorage.put(name, :key1, :value1)
    assert :ok = RuntimeStorage.put(name, :key2, :value2)

    assert RuntimeStorage.fetch(name, :key1) == {:ok, :value1}
    assert RuntimeStorage.fetch(name, :key2) == {:ok, :value2}
  end

  test "unfound entry returns error", %{name: name} do
    assert RuntimeStorage.fetch(name, :notexists) == :error
  end

  test "values are cleaned up on exit", %{name: name, pid: pid} do
    assert :ok = RuntimeStorage.put(name, :key1, :value1)
    assert_shutdown(pid)
    {:ok, _cache} = RuntimeStorage.start_link(name: name)
    assert RuntimeStorage.fetch(name, :key1) == :error
  end
end
