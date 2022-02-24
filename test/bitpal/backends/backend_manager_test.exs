defmodule BackendManagerTest do
  use BitPal.IntegrationCase, async: true
  alias BitPal.BackendStatusSupervisor
  alias BitPal.BackendManager
  alias BitPal.BackendMock
  alias BitPalSettings.BackendSettings

  # Note that a local manager should be used if we use a crashing backend,
  # otherwise there's a risk that we'll crash the global backend supervisor which
  # will cause other tests to fail.

  describe "backends" do
    @tag local_manager: true
    test "initialize and restart", %{manager: manager} do
      [{_, {backend_pid, _}}] = BackendManager.backends(manager)

      assert_shutdown(backend_pid)

      [{_, {new_backend_pid, _}}] = BackendManager.backends(manager)
      assert backend_pid != new_backend_pid
    end

    @tag backends: 2
    test "setup and fetch", %{currencies: [c0, c1]} do
      assert eventually(fn ->
               {:ok, {_pid, BackendMock}} = BackendManager.fetch_backend(c0)
             end)

      assert eventually(fn ->
               {:ok, {_pid, BackendMock}} = BackendManager.fetch_backend(c1)
             end)
    end

    test "stop and start", %{currency_id: c} do
      assert eventually(fn -> BackendManager.status(c) == :ready end)

      assert :ok = BackendManager.stop_backend(c)
      assert eventually(fn -> {:error, :stopped} == BackendManager.fetch_backend(c) end)

      assert {:ok, _} = BackendManager.restart_backend(c)
      assert {:ok, _} = BackendManager.fetch_backend(c)
    end

    @tag local_manager: true, subscribe: true
    test "restart after stop with error", %{manager: manager, currency_id: c} do
      assert eventually(fn -> BackendManager.status(manager, c) == :ready end)

      {:ok, {mock, mock_pid}} = BackendManager.fetch_backend(manager, c)
      mock_ref = Process.monitor(mock_pid)
      BackendMock.stop_with_error(mock, :bang)

      # Make sure the process has stopped
      assert_receive {:DOWN, ^mock_ref, _, _, _}

      # And then wait until it's been restarted again
      assert eventually(fn -> BackendManager.status(manager, c) == :ready end)
    end

    @tag local_manager: true, subscribe: true
    test "restart after crash", %{manager: manager, currency_id: c} do
      assert eventually(fn -> BackendManager.status(manager, c) == :ready end)

      {:ok, {mock, pid}} = BackendManager.fetch_backend(manager, c)
      mock_ref = Process.monitor(pid)
      BackendMock.crash(mock)

      # Make sure the process has crashed
      assert_receive {:DOWN, ^mock_ref, _, _, _}

      # And then wait until it's been restarted again
      assert eventually(fn -> BackendManager.status(manager, c) == :ready end)
    end

    @tag local_manager: true, backends: [{BackendMock, shutdown_init: true}], subscribe: true
    test "init shutdown", %{currency_id: c} do
      # Should be stopped
      assert_receive {{:backend, :status},
                      %{status: {:stopped, {:shutdown, :shutdown_init}}, currency_id: ^c}}

      # Should be restarted
      assert_receive {{:backend, :status}, %{status: :starting, currency_id: ^c}}
    end

    @tag local_manager: true, backends: [{BackendMock, fail_init: true}], subscribe: true
    test "init failed", %{manager: manager, currency_id: c} do
      # The backend should still exist.
      assert eventually(fn -> [{_, {_pid, _}}] = BackendManager.backends(manager) end)

      # Should be restarted
      assert_receive {{:backend, :status}, %{status: :starting, currency_id: ^c}}
    end

    test "plugin not found" do
      assert {:error, :plugin_not_found} == BackendManager.fetch_backend(:not_found)
    end
  end

  describe "enable/disable" do
    test "enable should start backend", %{currency_id: currency_id} do
      BackendManager.stop_backend(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)

      BackendManager.enable_backend(currency_id)
      assert BackendSettings.is_enabled(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)
    end

    test "disable should stop backend", %{currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)

      BackendManager.disable_backend(currency_id)
      assert !BackendSettings.is_enabled(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)
    end

    # Use a local manager to avoid problems with checking repo after the test pid has finished
    @tag local_manager: true, backends: [{BackendMock, shutdown_init: true}], subscribe: true
    test "disable should prevent a delayed restart backend", %{
      manager: manager,
      currency_id: currency_id
    } do
      # Wait for first restart
      assert_receive {{:backend, :status}, %{status: :starting, currency_id: ^currency_id}}

      BackendManager.disable_backend(manager, currency_id)

      # Should no longer restart
      refute_receive {{:backend, :status}, %{status: :starting, currency_id: ^currency_id}}
    end

    @tag subscribe: true, disable: true
    test "initializing a disabled backend should not start it", %{
      currency_id: currency_id
    } do
      refute_receive {{:backend, :status}, %{status: :starting, currency_id: ^currency_id}}
    end
  end

  describe "simple status" do
    test "stopped status", %{currency_id: currency_id} do
      BackendManager.stop_backend(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)
    end

    @tag backends: []
    test "backend not found" do
      assert BackendManager.status(:no_such_backend) == :plugin_not_found
    end
  end

  describe "backend events" do
    @tag subscribe: true
    test "stop and restart", %{currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)

      BackendManager.stop_backend(currency_id)

      assert eventually(fn -> BackendManager.status(currency_id) == :stopped end)

      assert_receive {{:backend, :status},
                      %{status: {:stopped, :shutdown}, currency_id: ^currency_id}}

      BackendManager.restart_backend(currency_id)
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)
      assert_received {{:backend, :status}, %{status: :starting, currency_id: ^currency_id}}
      assert_received {{:backend, :status}, %{status: :ready, currency_id: ^currency_id}}
    end

    @tag local_manager: true, subscribe: true
    test "notify of crash", %{manager: manager, currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)

      {:ok, {mock, _}} = BackendManager.fetch_backend(manager, currency_id)
      BackendMock.crash(mock)

      assert_receive {{:backend, :status},
                      %{status: {:stopped, {:error, :unknown}}, currency_id: ^currency_id}}

      # After a crash it should be restarted.
      assert_receive {{:backend, :status}, %{status: :starting, currency_id: ^currency_id}}
      assert_receive {{:backend, :status}, %{status: :ready, currency_id: ^currency_id}}
    end

    @tag local_manager: true, subscribe: true
    test "stopped error", %{manager: manager, currency_id: currency_id} do
      assert eventually(fn -> BackendManager.status(currency_id) == :ready end)

      {:ok, {mock, _}} = BackendManager.fetch_backend(manager, currency_id)
      BackendMock.stop_with_error(mock, :econnerror)

      assert_receive {{:backend, :status},
                      %{status: {:stopped, {:error, :econnerror}}, currency_id: ^currency_id}}

      # It should get restarted after a short timeout.
      assert_receive {{:backend, :status}, %{status: :starting, currency_id: ^currency_id}}
      assert_receive {{:backend, :status}, %{status: :ready, currency_id: ^currency_id}}
    end
  end

  describe "currencies/0" do
    @tag local_manager: true, backends: 2
    test "list multiple", %{manager: manager} do
      assert [{_, _}, {_, _}] = BackendManager.currencies(manager)
    end
  end

  describe "currency_list/0" do
    @tag local_manager: true, backends: 2
    test "list multiple", %{manager: manager, currencies: [c0, c1]} do
      assert Enum.sort(BackendManager.currency_list(manager)) === Enum.sort([c0, c1])
    end
  end

  describe "status_list/1" do
    @tag local_manager: true, backends: 3
    test "Finding status", %{manager: manager, currencies: [c0, c1, c2]} do
      assert eventually(fn -> BackendManager.status(manager, c0) == :ready end)
      assert eventually(fn -> BackendManager.status(manager, c2) == :ready end)

      BackendManager.stop_backend(manager, c1)
      BackendStatusSupervisor.set_recovering(c2, 1, 2)

      assert eventually(fn -> BackendManager.status(manager, c1) == :stopped end)

      assert eventually(fn ->
               BackendManager.status(manager, c2) == {:recovering, 1, 2}
             end)

      list = BackendManager.status_list(manager)
      assert {^c0, {_, BackendMock}, :ready} = find_status(list, c0)
      assert {^c1, {:undefined, BackendMock}, :stopped} = find_status(list, c1)
      assert {^c2, {_, BackendMock}, {:recovering, 1, 2}} = find_status(list, c2)
    end

    defp find_status(list, currency_id) do
      Enum.find(list, fn
        {^currency_id, _, _} -> true
        _ -> false
      end)
    end
  end

  describe "currency_status/1" do
    @tag local_manager: true
    test "Finding status", %{manager: manager, currency_id: currency_id} do
      assert eventually(fn -> :ready == BackendManager.status(manager, currency_id) end)
    end
  end

  describe "change_backends/1" do
    @tag local_manager: true, backends: 2
    test "change config", %{manager: manager, currencies: [c0, c1]} do
      c2 = unique_currency_id()
      BackendStatusSupervisor.allow_parent(c2, self())

      assert eventually(fn -> :ready == BackendManager.status(manager, c0) end)
      assert eventually(fn -> :ready == BackendManager.status(manager, c1) end)

      assert {:ok, pid0} = BackendManager.fetch_backend(manager, c0)
      assert {:ok, _} = BackendManager.fetch_backend(manager, c1)
      assert {:error, :plugin_not_found} = BackendManager.fetch_backend(manager, c2)

      BackendManager.config_change(
        manager,
        backends: [
          {BackendMock, currency_id: c0, parent: self()},
          {BackendMock, currency_id: c2, parent: self()}
        ]
      )

      # Doesn't restart the existing backend
      assert {:ok, ^pid0} = BackendManager.fetch_backend(manager, c0)

      # Removes a backend
      assert eventually(fn ->
               {:error, :plugin_not_found} == BackendManager.fetch_backend(manager, c1)
             end)

      # Adds a new backend
      eventually(fn ->
        assert {:ok, _} = BackendManager.fetch_backend(manager, c2)
      end)

      assert BackendManager.backends(manager) |> Enum.count() == 2
    end
  end
end
