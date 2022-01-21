defmodule BitPal.ServerSetupTest do
  use BitPal.DataCase, async: false
  import BitPal.ServerSetup

  describe "set_setup_state" do
    test "ensure status is set" do
      assert !setup_completed?()
      set_setup_state(:completed)
      assert setup_state() == :completed
      assert setup_completed?()
    end

    test "next" do
      assert setup_state() == :create_server_admin
      next_state()
      assert setup_state() == :enable_backends
      next_state()
      assert setup_state() == :create_store
      next_state()
      assert setup_state() == :completed
      next_state()
      assert setup_state() == :completed
    end
  end
end
