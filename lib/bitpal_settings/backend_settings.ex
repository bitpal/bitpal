defmodule BitPalSettings.BackendSettings do
  import Ecto.Query
  alias Ecto.Changeset
  alias BitPal.Repo
  alias BitPalSchemas.BackendSettings

  @spec is_enabled(Currency.id()) :: boolean
  def is_enabled(currency_id) do
    case Repo.get_by(BackendSettings, currency_id: currency_id) do
      nil ->
        %BackendSettings{}.enabled

      settings ->
        settings.enabled
    end
  end

  @spec is_enabled_state([Currency.id()]) :: %{Currency.id() => boolean}
  def is_enabled_state(currencies) do
    defaults =
      Enum.map(currencies, fn id -> {id, %BackendSettings{}.enabled} end)
      |> Enum.into(%{})

    existing =
      from(s in BackendSettings,
        where: s.currency_id in ^currencies,
        select: {s.currency_id, s.enabled}
      )
      |> Repo.all()
      |> Enum.into(%{})

    Map.merge(defaults, existing)
  end

  @spec enable(Currency.id()) :: BackendSettings.t()
  def enable(currency_id) do
    set_enabled(currency_id, true)
  end

  @spec disable(Currency.id()) :: BackendSettings.t()
  def disable(currency_id) do
    set_enabled(currency_id, false)
  end

  @spec set_enabled(Currency.id(), boolean) :: BackendSettings.t()
  defp set_enabled(currency_id, enabled?) do
    case Repo.get_by(BackendSettings, currency_id: currency_id) do
      nil -> %BackendSettings{currency_id: currency_id}
      settings -> settings
    end
    |> Changeset.change(enabled: enabled?)
    |> Repo.insert_or_update!()
  end
end
