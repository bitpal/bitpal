defmodule BitPal.Authentication.Tokens do
  import Ecto.Changeset
  import Ecto.Query
  alias BitPal.Repo
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.Store
  alias Ecto.Changeset

  @secret_key_base Application.compile_env!(:bitpal, :secret_key_base)
  @salt "access tokens"

  @spec authenticate_token(String.t()) ::
          {:ok, Store.id()} | {:error, :not_found} | {:error, :invalid} | {:error, :expired}
  def authenticate_token(token_data) do
    with {:ok, store_id} <-
           Phoenix.Token.verify(@secret_key_base, @salt, token_data, max_age: :infinity),
         :ok <- valid_token?(store_id, token_data) do
      {:ok, store_id}
    else
      err -> err
    end
  end

  @spec valid_token?(Store.id(), String.t()) :: :ok | {:error, :not_found}
  def valid_token?(store_id, token_data) do
    token =
      from(t in AccessToken, where: t.store_id == ^store_id and t.data == ^token_data)
      |> Repo.one()

    if token do
      :ok
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
    |> Ecto.build_assoc(:access_tokens, data: params[:data] || create_token_data(store))
    |> cast(params, [:label])
    |> validate_required(:label)
    |> validate_length(:label, min: 1)
    |> unique_constraint(:data, name: :access_tokens_data_index)
    |> Repo.insert()
  end

  @spec create_token!(Store.t()) :: AccessToken.t()
  def create_token!(store) do
    token_data = Phoenix.Token.sign(@secret_key_base, @salt, store.id)
    insert_token!(store, token_data)
  end

  @spec insert_token!(Store.t(), String.t()) :: AccessToken.t()
  def insert_token!(store, token_data) do
    store
    |> Ecto.build_assoc(:access_tokens, data: token_data)
    |> Repo.insert!()
  end

  @spec delete_token!(AccessToken.t()) :: :ok
  def delete_token!(token) do
    Repo.delete!(token)
  end

  defp create_token_data(store) do
    Phoenix.Token.sign(@secret_key_base, @salt, store.id)
  end
end
