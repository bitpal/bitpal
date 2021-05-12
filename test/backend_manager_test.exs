defmodule BackendManagerTest do
  use BitPal.IntegrationCase, db: true

  alias BitPal.Backend
  alias BitPal.BackendManager
  alias BitPal.BackendMock

  test "initialize and restart" do
    pid = start_supervised!({BackendManager, backends: [BackendMock]})

    %{active: 1} = DynamicSupervisor.count_children(pid)

    [{_, child_pid, _, _}] = DynamicSupervisor.which_children(pid)

    assert_shutdown(child_pid)

    [{_, new_child_pid, _, _}] = DynamicSupervisor.which_children(pid)
    assert child_pid != new_child_pid
  end

  test "backend currency support" do
    assert Backend.supported_currency?(:BCH, [:BCH, :XMR])
    assert !Backend.supported_currency?([:BCH, :XMR], [:BCH, :btc])

    start_supervised!(
      {BackendManager,
       backends: [
         {BitPal.BackendMock, name: Bitcoin.Backend, currencies: [:BCH, :btc]},
         {BitPal.BackendMock, name: Monero.Backend, currencies: [:XMR]}
       ]}
    )

    assert BackendManager.backend_status(Bitcoin.Backend) == :ok
    assert BackendManager.backend_status(Monero.Backend) == :ok
    assert BackendManager.backend_status(XXX.Backend) == :not_found

    assert BackendManager.currency_status(:BCH) == :ok
    assert BackendManager.currency_status("BCH") == :ok
    assert BackendManager.currency_status(:bsv) == :not_found

    assert {:ok, bit} = BackendManager.get_backend(Bitcoin.Backend)
    assert {:ok, ^bit} = BackendManager.get_currency_backend(:BCH)
    assert {:ok, ^bit} = BackendManager.get_currency_backend("BCH")
    assert {:error, :not_found} = BackendManager.get_currency_backend(:bsv)

    assert BackendManager.currency_list() === ["BCH", "BTC", "XMR"]
  end

  test "change config" do
    start_supervised!(
      {BackendManager,
       backends: [
         {BitPal.BackendMock, name: Bitcoin.Backend, currencies: [:BCH]},
         {BitPal.BackendMock, name: Litecoin.Backend, currencies: [:ltc]}
       ]}
    )

    assert {:ok, bit} = BackendManager.get_backend(Bitcoin.Backend)
    assert {:ok, ^bit} = BackendManager.get_currency_backend(:BCH)
    assert {:error, :not_found} = BackendManager.get_currency_backend(:btc)
    assert {:ok, ltc} = BackendManager.get_backend(Litecoin.Backend)
    assert {:ok, ^ltc} = BackendManager.get_currency_backend(:ltc)

    BackendManager.configure(
      backends: [
        {BitPal.BackendMock, name: Bitcoin.Backend, currencies: [:BCH, :btc]},
        {BitPal.BackendMock, name: Monero.Backend, currencies: [:XMR]}
      ]
    )

    # Doesn't restart the existing backend
    assert {:ok, ^bit} = BackendManager.get_currency_backend(:BCH)
    assert {:ok, ^bit} = BackendManager.get_currency_backend(:btc)
    # Removes a backend
    assert {:error, :not_found} = BackendManager.get_currency_backend(:ltc)
    # Adds a new backend
    assert {:ok, xmr} = BackendManager.get_backend(Monero.Backend)
    assert {:ok, ^xmr} = BackendManager.get_currency_backend(:XMR)
    assert BackendManager.backends() |> Enum.count() == 2
  end
end
