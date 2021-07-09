defmodule BitPal.ViewHelpers do
  def put_unless_nil(map, _key, nil), do: map
  def put_unless_nil(map, key, val), do: Map.put(map, key, val)

  def put_unless_nil(map, _key, nil, fun) when is_function(fun, 1), do: map

  def put_unless_nil(map, key, val, fun) when is_function(fun, 1) do
    Map.put(map, key, fun.(val))
  end
end
