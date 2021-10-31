defmodule BitPal.BackendTest do
  use ExUnit.Case, async: true
  alias BitPal.Backend

  describe "supported_currency?/2" do
    test "Calculate" do
      assert Backend.supported_currency?(:BCH, [:BCH, :XMR])
      assert !Backend.supported_currency?([:BCH, :XMR], [:BCH, :BTC])
    end
  end
end
