defmodule BitPalSchemas.InvoiceStatus do
  @doc """
  Defines a type to track the status of an invoice and to persist it to db.

  The type is represented by either an atom or a tuple of atoms, for example:

  - `:open`
  - `{:uncollectible, :expired}`

  And persists this as a map in the db.


  # Status and status reasons

  The definition of the status and status_reason is as follows:

  - `:draft`
    The invoice has been created, but all fields (except the primary key) can still be changed.

  - `:open`
    The invoice has been finalized, and is now awaiting payment.
    When finalizing the invoice the payment currency will be fixed and cannot be changed.
    An address will be generated and will be watched for payments that will be counted
    towards the invoice.

  - `:processing`
    The invoice has received the payment but it's not considered paid yet.

    See `status_reason`:
    - `:verifying`
      The tx(s) are being verified for 0-conf security.
    - `:confirming`
      The tx(s) are waiting for additional confirmations.
      See `confirmations_due` for how many confirmations are left before it's considered paid.

  - `:uncollectible`
    The payment couldn't be processed.

    See `status_reason`:
    - `:expired`
      No tx was seen and the invoice timed out.
    - `:canceled`
      The payee canceled the payment.
    - `:double_spent`
      A double spend was detected and the invoice payment was canceled.
    - `:timed_out`
      A payment was seen, but it wasn't confirmed fast enough so the invoice timed out.
    - `:failed`
      The tx was accepted but for some reason it's not valid.
      For example if an unreasonable unlock time is set for Monero.

  - `:void`
    The invoice was canceled by the merchant.
    `status_reason` will retain it's previous value, so you can void an uncollectible invoice
    and still see that it was timed out for example.

  - :`paid`
    The invoice was fully paid.

    See `@valid_combinations`.


    # Transitions

    Transitions between arbitrary states isn't supported. See `@valid_transitions`.
  """
  use Ecto.Type

  @type status :: :draft | :open | :processing | :uncollectible | :void | :paid

  @type processing_reason :: :verifying | :confirming
  @type uncollectible_reason :: :expired | :canceled | :timed_out | :double_spent | :failed
  @type status_reason :: processing_reason() | uncollectible_reason() | nil

  @type t ::
          :draft
          | :open
          | {:processing, processing_reason()}
          | {:uncollectible, uncollectible_reason()}
          | {:void, status_reason}
          | :void
          | :paid

  # state => reason (can be nil)
  @valid_combinations %{
    :draft => nil,
    :open => nil,
    :processing => [:verifying, :confirming],
    :uncollectible => [:expired, :canceled, :timed_out, :double_spent, :failed],
    :void => [
      :verifying,
      :confirming,
      :expired,
      :canceled,
      :timed_out,
      :double_spent,
      :failed,
      nil
    ],
    :paid => nil
  }

  @valid_transitions %{
    :draft => [:open],
    :open => [:processing, :paid, :uncollectible, :void],
    :processing => [:paid, :uncollectible],
    :uncollectible => [:paid, :void]
  }

  def state(state) when is_atom(state), do: state
  def state({state, _}) when is_atom(state), do: state

  def reason(state) when is_atom(state), do: nil
  def reason({_, reason}) when is_atom(reason), do: reason

  def split(x) do
    {state(x), reason(x)}
  end

  def cast!(x) do
    {:ok, res} = cast(x)
    res
  end

  @spec validate_transition(t(), t()) :: {:ok, t()} | {:error, String.t()}
  def validate_transition(curr_status, next_status) do
    with {:ok, next_status} <- cast(next_status),
         {curr_state, _curr_reason} <- split(curr_status),
         {next_state, next_reason} <- split(next_status),
         :ok <- validate_state_transition(curr_state, next_state) do
      next_status =
        if next_reason do
          {next_state, next_reason}
        else
          next_state
        end

      {:ok, next_status}
    else
      :error ->
        {:error, "invalid state: `#{inspect(next_status)}`"}

      {:error, msg} ->
        {:error, msg}
    end
  end

  @spec validate_state_transition(status, status) :: :ok | {:error, String.t()}
  def validate_state_transition(curr_state, next_state)
      when is_atom(curr_state) and is_atom(next_state) do
    if valid_transition?(curr_state, next_state) do
      :ok
    else
      {:error, "invalid transition from `#{curr_state}` to `#{next_state}`"}
    end
  end

  defp valid_transition?(state, state), do: true

  defp valid_transition?(from, to) do
    case Map.get(@valid_transitions, from) do
      nil ->
        false

      transitions ->
        Enum.member?(transitions, to)
    end
  end

  # EctoType impl

  @impl true
  def type, do: :map

  @impl true
  def cast(state) when is_atom(state) do
    case Map.get(@valid_combinations, state, :not_found) do
      :not_found ->
        :error

      nil ->
        {:ok, state}

      valid_reasons ->
        if Enum.member?(valid_reasons, nil) do
          {:ok, state}
        else
          :error
        end
    end
  end

  def cast({state, nil}) when is_atom(state) do
    cast(state)
  end

  def cast({state, reason}) when is_atom(state) and is_atom(reason) do
    case Map.get(@valid_combinations, state) do
      nil ->
        :error

      valid_reasons ->
        if Enum.member?(valid_reasons, reason) do
          {:ok, {state, reason}}
        else
          :error
        end
    end
  end

  def cast(%{state: state, reason: reason}) when is_atom(state) and is_atom(reason) do
    cast({state, reason})
  end

  def cast(%{state: state}) when is_atom(state) do
    cast(state)
  end

  def cast(_), do: :error

  @impl true
  def load(data) when is_map(data) do
    for {key, val} <- data do
      {String.to_existing_atom(key), String.to_existing_atom(val)}
    end
    |> Map.new()
    |> cast()
  end

  @impl true
  def dump(state) when is_atom(state) do
    {:ok, %{state: state}}
  end

  def dump({state, reason}) when is_atom(state) and is_atom(reason) do
    {:ok, %{state: state, reason: reason}}
  end

  def dump(%{state: state, reason: reason})
      when is_atom(state) and is_atom(reason) and not is_nil(reason) do
    {:ok, %{state: state, reason: reason}}
  end

  def dump(%{state: state}) when is_atom(state) do
    {:ok, %{state: state}}
  end

  def dump(_), do: :error
end
