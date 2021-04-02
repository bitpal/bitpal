defmodule BackendManagerTest do
  use BitPal.BackendCase

  alias BitPal.Backend
  alias BitPal.BackendManager
  alias BitPal.BackendStub

  @tag :dry
  test "initialize and restart" do
    pid = start_supervised!({BackendManager, [BackendStub]})

    %{active: 1} = DynamicSupervisor.count_children(pid)

    [{_, child_pid, _, _}] = DynamicSupervisor.which_children(pid)

    assert_shutdown(child_pid)

    [{_, new_child_pid, _, _}] = DynamicSupervisor.which_children(pid)
    assert child_pid != new_child_pid
  end

  @tag :dry
  test "backend currency support" do
    assert Backend.supported_currency?(:bch, [:bch, :xmr])
    assert !Backend.supported_currency?([:bch, :xmr], [:bch, :btc])

    start_supervised!(
      {BackendManager,
       [
         {BitPal.BackendStub, name: Bitcoin.Backend, currencies: [:bch, :btc]},
         {BitPal.BackendStub, name: Monero.Backend, currencies: [:xmr]}
       ]}
    )

    assert BackendManager.backend_status(Bitcoin.Backend) == :ok
    assert BackendManager.backend_status(Monero.Backend) == :ok
    assert BackendManager.backend_status(XXX.Backend) == :not_found

    assert BackendManager.currency_status(:bch) == :ok
    assert BackendManager.currency_status(:bsv) == :not_found

    assert {:ok, bit} = BackendManager.get_backend(Bitcoin.Backend)
    assert {:ok, ^bit} = BackendManager.get_currency_backend(:bch)
    assert {:error, :not_found} = BackendManager.get_currency_backend(:bsv)

    assert BackendManager.currency_list() === [:bch, :btc, :xmr]
  end
end
