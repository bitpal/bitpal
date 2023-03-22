defmodule BitPalApi.ApiHelpers do
  alias BitPal.Currencies

  @spec cast_crypto(term) :: {:ok, Currency.t()} | {:error, String.t()}
  def cast_crypto(currency) do
    with {:ok, id} <- cast_currency(currency),
         true <- Currencies.is_crypto(id) do
      {:ok, id}
    else
      false -> {:error, "not a supported cryptocurrency"}
      err -> err
    end
  end

  @spec cast_currency(term) :: {:ok, Currency.t()} | {:error, String.t()}
  def cast_currency(currency) do
    case Currencies.cast(currency) do
      {:ok, id} ->
        {:ok, id}

      _ ->
        {:error, "is invalid or not supported"}
    end
  end

  def keys_to_snake(params) do
    Recase.Enumerable.convert_keys(params, &Recase.to_snake/1)
  end

  def keys_to_camel(params) do
    Recase.Enumerable.convert_keys(params, &Recase.to_camel/1)
  end

  def transform_errors(changeset, fun) do
    %{
      changeset
      | errors:
          Enum.reduce(changeset.errors, %{}, fn val, acc ->
            case fun.(val) do
              nil -> acc
              {key, val} -> Map.put(acc, key, val)
            end
          end)
    }
  end

  def has_error?(changeset, key, code) do
    case Keyword.get(changeset.errors, key) do
      {_, [code: ^code]} -> true
      _ -> false
    end
  end
end
