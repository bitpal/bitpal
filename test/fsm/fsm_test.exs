defmodule BitPal.FSMTest do
  use ExUnit.Case, async: true
  alias BitPal.FSM

  defmodule Struct do
    use BitPal.FSM.Config,
      state_field: :status,
      transitions: %{
        :a => :b,
        :b => [:one, :two, :three]
      }

    defstruct [:status]
  end

  test "transitions" do
    a = %Struct{status: :a}
    assert {:ok, b = %Struct{status: :b}} = FSM.transition(a, :b)
    assert {:error, _} = FSM.transition(a, :one)

    assert {:ok, %Struct{status: :one}} = FSM.transition(b, :one)
    assert {:ok, %Struct{status: :three}} = FSM.transition(b, :three)
  end

  test "struct changeset" do
    a = %Struct{status: :a}
    assert FSM.transition_changeset(a, :b).valid?
    assert !FSM.transition_changeset(a, :one).valid?
  end

  defmodule Schema do
    use Ecto.Schema

    schema "test_schema" do
      field(:status, Ecto.Enum, values: [:a, :b, :one, :two, :three])
    end

    use BitPal.FSM.Config,
      state_field: :status,
      transitions: %{
        :a => :b,
        :b => [:one, :two, :three]
      }
  end

  test "schema changeset" do
    a = %Schema{status: :a}
    assert FSM.transition_changeset(a, :b).valid?
    assert !FSM.transition_changeset(a, :one).valid?
  end
end
