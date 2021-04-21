defmodule BitPal.ConfigHelpers do
  def update_state(state, opts, keys) when is_list(keys) do
    Enum.reduce(keys, state, fn key, state ->
      update_state(state, opts, key)
    end)
  end

  def update_state(state, opts, keyword) when is_map(opts) and is_atom(keyword) do
    if Map.has_key?(opts, keyword) do
      Map.put(state, keyword, Map.get(opts, keyword))
    else
      state
    end
  end

  def update_state(state, opts, keyword) when is_list(opts) and is_atom(keyword) do
    if Keyword.has_key?(opts, keyword) do
      Map.put(state, keyword, Keyword.get(opts, keyword))
    else
      state
    end
  end
end
