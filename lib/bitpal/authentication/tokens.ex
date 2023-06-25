defmodule BitPal.Authentication.Tokens do
  import Ecto.Changeset
  alias BitPal.Repo
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Store
  alias Ecto.Changeset

  @salt "access tokens"

  @spec authenticate_token(String.t()) ::
          {:ok, Store.id()} | {:error, :invalid} | {:error, :expired}
  def authenticate_token(token_data) do
    with {:ok, token} <- get_token(token_data),
         {:ok, store_id} <-
           Phoenix.Token.verify(Application.get_env(:bitpal, :secret_key_base), @salt, token_data,
             max_age: valid_age(token)
           ) do
      if token.store_id == store_id do
        update_last_accessed(token)
        {:ok, store_id}
      else
        {:error, :invalid}
      end
    else
      {:error, :not_found} -> {:error, :invalid}
      err -> err
    end
  end

  @spec valid_age(AccessToken.t()) :: integer | :infinity
  def valid_age(token) do
    if token.valid_until do
      DateTime.diff(token.valid_until, DateTime.utc_now())
    else
      :infinity
    end
  end

  @spec get_token(String.t()) :: {:ok, AccessToken.t()} | {:error, :not_found}
  def get_token(token_data) do
    token = Repo.get_by(AccessToken, data: token_data)

    if token do
      {:ok, token}
    else
      {:error, :not_found}
    end
  rescue
    _ ->
      {:error, :not_found}
  end

  @spec create_token(Store.t(), map) :: {:ok, AccessToken.t()} | {:error, Changeset.t()}
  def create_token(store = %Store{}, params) do
    store
    |> Ecto.build_assoc(:access_tokens,
      data: params[:data] || create_token_data(store, signed_at: params[:signed_at])
    )
    |> cast(params, [:label])
    |> cast_datetime(params, :valid_until)
    |> validate_required(:label)
    |> validate_length(:label, min: 1)
    |> unique_constraint(:data, name: :access_tokens_data_index)
    |> Repo.insert()
  end

  defp cast_datetime(changeset, params, key) do
    val = params[key] || params[Atom.to_string(key)]

    if val && val != "" do
      case parse_datetime(val) do
        {:ok, dt} ->
          force_change(changeset, key, dt)

        {:error, error} ->
          add_error(changeset, key, "bad date format: #{error}")
      end
    else
      changeset
    end
  end

  defp parse_datetime(val) when is_binary(val) do
    # NOTE this will always parse as UTC
    case Timex.parse(val, "%Y-%m-%d", :strftime) do
      {:ok, datetime} ->
        {:ok,
         datetime
         |> Timex.set(hour: 23, minute: 59, second: 59)
         |> Timex.to_datetime("Etc/UTC")
         |> DateTime.truncate(:second)}

      err ->
        err
    end
  end

  defp parse_datetime(val = %DateTime{}) do
    {:ok, val |> DateTime.truncate(:second)}
  end

  @spec delete_token!(AccessToken.t()) :: :ok
  def delete_token!(token) do
    Repo.delete!(token)
  end

  defp create_token_data(store, opts) do
    Phoenix.Token.sign(Application.get_env(:bitpal, :secret_key_base), @salt, store.id, opts)
  end

  defp update_last_accessed(token) do
    change(token, last_accessed: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update!()
  end
end
