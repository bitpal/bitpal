defmodule BitPal.ServerSetupTest do
  use BitPal.DataCase, async: true
  alias BitPal.ServerSetup

  setup tags do
    name = unique_server_name()

    start_supervised!(
      {BitPal.ServerSetup,
       name: name, id: sequence_int(:server_setup), state: :create_server_admin, parent: self()}
    )

    Map.put(tags, :name, name)
  end

  describe "set_setup_state" do
    test "ensure status is set", %{name: name} do
      assert ServerSetup.current_state(name) == :create_server_admin
      assert !ServerSetup.completed?(name)
      ServerSetup.set_state(name, :completed)
      assert ServerSetup.current_state(name) == :completed
      assert ServerSetup.completed?(name)
    end

    test "next", %{name: name} do
      assert ServerSetup.current_state(name) == :create_server_admin
      ServerSetup.set_next(name)
      assert ServerSetup.current_state(name) == :enable_backends
      ServerSetup.set_next(name)
      assert ServerSetup.current_state(name) == :create_store
      ServerSetup.set_next(name)
      assert ServerSetup.current_state(name) == :completed
      ServerSetup.set_next(name)
      assert ServerSetup.current_state(name) == :completed
    end
  end
end
