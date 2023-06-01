defmodule BitPal.PortsHandlerTest do
  use ExUnit.Case, async: true
  alias BitPal.PortsHandler

  test "assign different ports" do
    test_port = PortsHandler.assign_port()

    t = Task.async(fn -> PortsHandler.assign_port() end)
    task_port = Task.await(t)

    assert is_integer(test_port)
    assert is_integer(task_port)
    assert test_port != task_port

    # This process should still be registered
    assert PortsHandler.get_assigned_process(test_port) == {:ok, self()}

    # The task has shut down
    # Note that this is an async test so the port can be assgined
    Task.shutdown(t)
    assert PortsHandler.get_assigned_process(task_port) != {:ok, task_port}
  end
end
