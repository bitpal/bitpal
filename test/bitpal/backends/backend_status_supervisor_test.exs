defmodule BitPal.BackendManagerStatusTest do
  use BitPal.DataCase, async: true
  use BitPal.CaseHelpers
  alias BitPal.BackendEvents
  alias BitPal.BackendStatusSupervisor

  setup _tags do
    currency_id = unique_currency_id()
    BackendStatusSupervisor.allow_parent(currency_id, self())
    %{currency_id: currency_id}
  end

  test "status changes", %{currency_id: currency_id} do
    BackendStatusSupervisor.set_starting(currency_id)
    assert BackendStatusSupervisor.get_status(currency_id) == :starting

    BackendStatusSupervisor.set_recovering(currency_id, 1, 10)
    assert BackendStatusSupervisor.get_status(currency_id) == {:recovering, 1, 10}

    BackendStatusSupervisor.set_syncing(currency_id, 0.5)
    assert BackendStatusSupervisor.get_status(currency_id) == {:syncing, 0.5}

    BackendStatusSupervisor.set_ready(currency_id)
    assert BackendStatusSupervisor.get_status(currency_id) == :ready
  end

  describe "events" do
    setup tags do
      BackendEvents.subscribe(tags.currency_id)
    end

    test "status events", %{currency_id: currency_id} do
      BackendStatusSupervisor.set_recovering(currency_id, 1, 10)

      assert_receive {{:backend, :status},
                      %{status: {:recovering, 1, 10}, currency_id: ^currency_id}}

      BackendStatusSupervisor.set_ready(currency_id)
      assert_receive {{:backend, :status}, %{status: :ready, currency_id: ^currency_id}}
    end

    test "rate limited events", %{currency_id: currency_id} do
      BackendStatusSupervisor.configure_status_handler(currency_id, %{rate_limit: 20})

      Enum.each(0..10, fn i ->
        BackendStatusSupervisor.set_recovering(currency_id, i, 10)
      end)

      # We recieve the first instantly.
      assert_receive {{:backend, :status},
                      %{status: {:recovering, 0, 10}, currency_id: ^currency_id}}

      # Then we'll get another one delayed.
      assert_receive {{:backend, :status},
                      %{status: {:recovering, 10, 10}, currency_id: ^currency_id}}

      # The other ones shouldn't be sent.
      Enum.each(1..9, fn i ->
        refute_received {{:backend, :status},
                         %{status: {:recovering, ^i, 10}, currency_id: ^currency_id}}
      end)
    end

    test "no event when changing to the same state", %{currency_id: currency_id} do
      BackendStatusSupervisor.set_ready(currency_id)
      assert_receive {{:backend, :status}, %{status: :ready, currency_id: ^currency_id}}

      BackendStatusSupervisor.set_ready(currency_id)
      refute_receive {{:backend, :status}, %{status: :ready, currency_id: ^currency_id}}
    end
  end
end
