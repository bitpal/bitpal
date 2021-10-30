defmodule BitPalFixtures.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Accounts` context.
  """

  def unique_user_email, do: Faker.Internet.email()
  def valid_user_password, do: Faker.String.base64(Faker.random_between(12, 20))

  def valid_user_attributes(attrs \\ %{}) do
    Enum.into(attrs, %{
      email: unique_user_email(),
      password: valid_user_password()
    })
  end

  def user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> valid_user_attributes()
      |> BitPal.Accounts.register_user()

    user
  end

  def extract_user_token(fun) do
    {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
    [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
    token
  end
end
