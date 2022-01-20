defmodule BitPal.ServerSetup do
  alias BitPal.Accounts

  @type state :: :none | :completed

  def setup_stage do
    if Accounts.any_user() do
      :completed
    else
      :none
    end
  end

  def setup_completed? do
    setup_stage() == :completed
  end
end
