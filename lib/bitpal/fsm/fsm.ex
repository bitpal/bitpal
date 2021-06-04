defmodule BitPal.FSM do
  alias Ecto.Changeset

  @spec transition(struct, atom) :: {:ok, struct} | {:error, String.t()}
  def transition(struct, new_state) do
    {transitions, state_field, curr_state} = struct_config(struct)

    case validate_transition(curr_state, new_state, transitions) do
      :ok -> {:ok, Map.put(struct, state_field, new_state)}
      err -> err
    end
  end

  @spec transition_changeset(struct, atom) :: Changeset.t()
  def transition_changeset(struct, new_state) do
    {transitions, state_field, curr_state} = struct_config(struct)

    changeset = create_changeset(struct, state_field)

    case validate_transition(curr_state, new_state, transitions) do
      :ok ->
        Changeset.put_change(changeset, state_field, new_state)

      {:error, msg} ->
        Changeset.add_error(changeset, state_field, msg)
    end
  end

  @spec validate_transition(atom, atom, map) :: :ok | {:error, String.t()}
  def validate_transition(curr_state, new_state, transitions) do
    if valid_transition?(curr_state, new_state, transitions) do
      :ok
    else
      {:error, "invalid transition from '#{curr_state}' to '#{new_state}'"}
    end
  end

  defp create_changeset(struct, state_field) do
    struct.__changeset__()
  rescue
    _ -> Changeset.change({struct, %{state_field => :any}})
  else
    _ -> Changeset.change(struct)
  end

  defp valid_transition?(state, new_state, transitions) do
    transitions
    |> Map.get(state, [])
    |> valid_transition?(new_state)
  end

  defp valid_transition?(state, state), do: true

  defp valid_transition?(states, state) when is_list(states) do
    Enum.member?(states, state)
  end

  defp valid_transition?(_, _), do: false

  defp struct_config(struct = %module{}) do
    transitions = module.__fsm__(:transitions)
    state_field = module.__fsm__(:state_field)
    curr_state = Map.fetch!(struct, state_field)

    {transitions, state_field, curr_state}
  end
end
