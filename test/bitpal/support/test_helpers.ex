defmodule BitPal.TestHelpers do
  import ExUnit.Assertions

  def eventually(func, timeout \\ 1_000) do
    task = Task.async(fn -> _eventually(func) end)
    Task.await(task, timeout)
  end

  defp _eventually(func) do
    try do
      if func.() do
        true
      else
        Process.sleep(10)
        _eventually(func)
      end
    rescue
      _ ->
        Process.sleep(10)
        _eventually(func)
    end
  end

  def assert_shutdown(pid) do
    ref = Process.monitor(pid)
    Process.unlink(pid)
    Process.exit(pid, :kill)

    assert_receive {:DOWN, ^ref, :process, ^pid, :killed}
  end

  @doc """
  A helper that transforms changeset errors into a map of messages.

      assert {:error, changeset} = Accounts.create_user(%{password: "short"})
      assert "password is too short" in errors_on(changeset).password
      assert %{password: ["password is too short"]} = errors_on(changeset)

  """
  def errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {message, opts} ->
      Regex.replace(~r"%{(\w+)}", message, fn _, key ->
        opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
      end)
    end)
  end

  @spec decimal_eq(Decimal.t(), Decimal.t(), float) :: boolean
  def decimal_eq(a, b, tolerance \\ 0.1) do
    diff = Decimal.sub(a, b) |> Decimal.abs()
    Decimal.compare(diff, Decimal.from_float(tolerance)) == :lt
  end
end
