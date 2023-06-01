defmodule BitPal.Security do
  def strong_rand_string do
    strong_rand_string(64)
  end

  def strong_rand_string(length) when length > 31 do
    :crypto.strong_rand_bytes(length) |> Base.encode64() |> binary_part(0, length)
  end

  def strong_rand_string(_), do: raise("A strong string must be at least 32 long")
end
