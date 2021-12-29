defmodule BackendManagerTest do
  use BitPal.DataCase, async: true
  alias BitPal.BackendManager
  alias BitPal.BackendMock

  describe "init backends" do
    test "initialize and restart" do
      pid =
        start_supervised!(
          {BackendManager,
           backends: [{BackendMock, currency_id: unique_currency_id(), parent: self()}],
           name: unique_server_name(),
           parent: self()}
        )

      %{active: 1} = DynamicSupervisor.count_children(pid)

      [{_, child_pid, _, _}] = DynamicSupervisor.which_children(pid)

      assert_shutdown(child_pid)

      [{_, new_child_pid, _, _}] = DynamicSupervisor.which_children(pid)
      assert child_pid != new_child_pid
    end

    test "setup and fetch" do
      [c0, c1, c2] = unique_currency_ids(3)

      start_supervised!(
        {BackendManager,
         backends: [
           {BackendMock, currency_id: c0},
           {BackendMock, currency_id: c1}
         ],
         parent: self(),
         name: unique_server_name()}
      )

      assert {:ok, {_pid, BackendMock}} = BackendManager.fetch_backend(c0)
      assert {:ok, {_pid, BackendMock}} = BackendManager.fetch_backend(c1)
      assert {:error, :not_found} = BackendManager.fetch_backend(c2)
    end
  end

  describe "currency_list/0" do
    test "list multiple" do
      name = unique_server_name()
      [c0, c1] = unique_currency_ids(2)

      start_supervised!(
        {BackendManager,
         backends: [
           {BackendMock, currency_id: c0},
           {BackendMock, currency_id: c1}
         ],
         parent: self(),
         name: name}
      )

      assert Enum.sort(BackendManager.currency_list(name)) === Enum.sort([c0, c1])
    end
  end

  describe "status/1" do
    test "Finding status" do
      currency_id = unique_currency_id()

      start_supervised!(
        {BackendManager,
         parent: self(),
         backends: [{BackendMock, currency_id: currency_id}],
         name: unique_server_name()}
      )

      assert :ok == BackendManager.status(currency_id)
    end
  end

  describe "config_change/1" do
    test "change config" do
      name = unique_server_name()

      [c0, c1, c2] = unique_currency_ids(3)

      start_supervised!(
        {BackendManager,
         parent: self(),
         backends: [
           {BackendMock, currency_id: c0},
           {BackendMock, currency_id: c1}
         ],
         name: name}
      )

      assert {:ok, pid0} = BackendManager.fetch_backend(c0)
      assert {:ok, _} = BackendManager.fetch_backend(c1)
      assert {:error, :not_found} = BackendManager.fetch_backend(c2)

      BackendManager.config_change(
        name,
        backends: [
          {BackendMock, currency_id: c0, parent: self()},
          {BackendMock, currency_id: c2, parent: self()}
        ]
      )

      # Doesn't restart the existing backend
      assert {:ok, ^pid0} = BackendManager.fetch_backend(c0)

      # Removes a backend
      assert eventually(fn ->
               {:error, :not_found} == BackendManager.fetch_backend(c1)
             end)

      # Adds a new backend
      eventually(fn ->
        assert {:ok, _} = BackendManager.fetch_backend(c2)
      end)

      assert BackendManager.backends(name) |> Enum.count() == 2
    end
  end
end
