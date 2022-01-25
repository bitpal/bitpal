defmodule BitPalFactory.FactoryHelpers do
  alias BitPalFactory.Sequencer

  @spec sequence(String.t()) :: String.t()
  def sequence(name) when is_binary(name) do
    Sequencer.next(name, &(name <> to_string(&1)))
  end

  @spec sequence(term, (integer -> term)) :: term
  def sequence(name, formatter) do
    Sequencer.next(name, formatter)
  end

  def pretty_sequence(name) when is_binary(name) do
    Sequencer.next(name, fn
      0 -> name
      count -> "#{name} #{count}"
    end)
  end

  @spec sequence_int(atom) :: integer
  def sequence_int(name) when is_atom(name) do
    Sequencer.next(name, & &1)
  end
end
