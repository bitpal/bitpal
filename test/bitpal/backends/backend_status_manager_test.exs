defmodule BitPal.BackendStatusManagerTest do
  use ExUnit.Case, async: true
  use BitPal.CaseHelpers
  alias BitPal.BackendStatusManager
  alias BitPal.BackendEvents

  setup tags do
    name = unique_server_name()
    # Yeah technically not a currency, but it doesn't matter.
    id = sequence("status_manager")

    start_supervised!(
      {BackendStatusManager,
       name: name,
       currency_id: id,
       rate_limit: tags[:rate_limit] || 1,
       status: tags[:status],
       parent: self()}
    )

    %{name: name, id: id}
  end

  test "status changes", %{name: name} do
    assert BackendStatusManager.status(name) == :initiailizing

    BackendStatusManager.recovering(name, 1, 10)
    assert BackendStatusManager.status(name) == {:recovering, 1, 10}

    BackendStatusManager.syncing(name, 0.5)
    assert BackendStatusManager.status(name) == {:syncing, 0.5}

    BackendStatusManager.error(name, :econnerror)
    assert BackendStatusManager.status(name) == {:error, :econnerror}

    BackendStatusManager.ready(name)
    assert BackendStatusManager.status(name) == :ready

    BackendStatusManager.stopped(name)
    assert BackendStatusManager.status(name) == :stopped
  end

  test "status events", %{name: name, id: id} do
    BackendEvents.subscribe(id)

    BackendStatusManager.recovering(name, 1, 10)
    assert_receive {{:backend, {:recovering, 1, 10}}, ^id}

    BackendStatusManager.ready(name)
    assert_receive {{:backend, :ready}, ^id}
  end

  @tag rate_limit: 20
  test "rate limited events", %{name: name, id: id} do
    BackendEvents.subscribe(id)

    Enum.each(0..10, fn i ->
      BackendStatusManager.recovering(name, i, 10)
    end)

    # We recieve the first instantly.
    assert_receive {{:backend, {:recovering, 0, 10}}, ^id}

    # Then we'll get another one delayed.
    assert_receive {{:backend, {:recovering, 10, 10}}, ^id}

    # The other ones shouldn't be sent.
    Enum.each(1..9, fn i ->
      refute_received {{:backend, {:recovering, ^i, 10}}, ^id}
    end)
  end

  @tag status: :stopped
  test "no event when changing to the same state", %{name: name, id: id} do
    BackendEvents.subscribe(id)

    BackendStatusManager.stopped(name)
    BackendStatusManager.stopped(name)

    refute_receive {{:backend, :stopped}, ^id}
  end
end
