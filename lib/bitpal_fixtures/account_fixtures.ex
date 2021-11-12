defmodule BitPalFixtures.AccountFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `BitPal.Accounts` context.
  """

  # alias BitPalFactory.Factory

  # def unique_user_email, do: Faker.Internet.email()
  # def valid_user_password, do: Faker.String.base64(Faker.random_between(12, 20))
  #
  # @spec valid_user_attributes(map | keyword) :: map
  # def valid_user_attributes(attrs \\ %{}) do
  #   Factory.valid_user_attributes(attrs)
  # end
  #
  # @spec user_fixture(map | keyword) :: User.t()
  # def user_fixture(attrs \\ %{}) do
  #   Factory.insert(:user, attrs)
  # end

  # def extract_user_token(fun) do
  #   {:ok, captured_email} = fun.(&"[TOKEN]#{&1}[TOKEN]")
  #   [_, token | _] = String.split(captured_email.text_body, "[TOKEN]")
  #   token
  # end
end
