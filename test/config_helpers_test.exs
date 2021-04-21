defmodule BitPal.ConfigHelpersTest do
  use ExUnit.Case, async: true
  import BitPal.ConfigHelpers

  test "update state" do
    assert update_state(%{a: 1}, [a: 2, b: 3], :a) == %{a: 2}
    assert update_state(%{a: 1}, [a: 2, b: 3], :b) == %{a: 1, b: 3}
    assert update_state(%{a: 1}, %{a: 2, b: 3}, :b) == %{a: 1, b: 3}
    assert update_state(%{a: 1}, %{a: 2, b: 3}, :c) == %{a: 1}
    assert update_state(%{a: 1}, %{a: 2, b: 3}, [:a, :b]) == %{a: 2, b: 3}
  end
end
