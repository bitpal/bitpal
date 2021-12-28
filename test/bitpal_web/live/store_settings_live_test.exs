defmodule BitPalWeb.StoreSettingsLiveTest do
  # Tests must be async as we're testing for currency existance
  use BitPalWeb.ConnCase, integration: true, async: false
  import Ecto.Query
  alias BitPal.Repo
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.AddressKey
  alias BitPalSettings.StoreSettings
  alias Phoenix.HTML

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "display" do
    test "show tokens", %{conn: conn, store: store} do
      now = System.system_time(:second)

      store =
        store
        |> with_token(signed_at: now - 1_000)
        |> with_token(signed_at: now)

      {:ok, _view, html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))

      for token <- store.access_tokens do
        assert html =~ token.label
        assert !(html =~ token.data)
      end
    end

    @tag backends: [BitPal.BackendMock, BitPal.BackendMock]
    test "show currency settings", %{conn: conn, store: store, currencies: currencies} do
      c0 = hd(currencies)

      # Add some settings to one of the currencies, as the rendering
      # logic is different depending on if the settings data exists in db or not.
      {:ok, _} = StoreSettings.set_required_confirmations(store.id, c0, 42)

      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))

      for currency_id <- currencies do
        assert view
               |> element(".currency", Atom.to_string(currency_id))
               |> render() =~ Money.Currency.name!(currency_id)
      end
    end
  end

  describe "xpub" do
    test "set", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))
      xpub = unique_address_key_id()

      rendered =
        view
        |> element(".currencies form", "xpub")
        |> render_submit(%{currency_id => %{data: xpub}})

      assert rendered =~ xpub
      assert rendered =~ "Key updated"

      assert {:ok, %AddressKey{data: ^xpub}} =
               StoreSettings.fetch_address_key(store.id, currency_id)
    end

    test "failed to set", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))

      rendered =
        view
        |> element(".currencies form", "xpub")
        |> render_submit(%{currency_id => %{data: ""}})

      assert rendered =~ "Failed to update key"
      assert {:error, :not_found} = StoreSettings.fetch_address_key(store.id, currency_id)
    end
  end

  describe "required confirmations" do
    test "set", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))
      confs = 13

      rendered =
        view
        |> element(".currencies form", "confirmations")
        |> render_change(%{currency_id => %{required_confirmations: confs}})

      assert rendered =~ Integer.to_string(confs)
      assert confs == StoreSettings.get_required_confirmations(store.id, currency_id)
    end

    test "failed to set", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))

      rendered =
        view
        |> element(".currencies form", "confirmations")
        |> render_change(%{currency_id => %{required_confirmations: "fail"}})

      assert rendered =~ "is invalid"
    end
  end

  describe "tokens" do
    test "create", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))
      label = Faker.StarWars.character()

      rendered =
        view
        |> element("#create_token")
        |> render_submit(%{"access_token" => %{label: label}})

      token =
        from(t in AccessToken, where: t.store_id == ^store.id)
        |> Repo.one!()

      assert rendered =~ token.label
      assert rendered =~ token.data
    end

    test "create errors on missing label", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))

      rendered =
        view
        |> element("#create_token")
        |> render_submit(%{"access_token" => %{label: ""}})

      assert rendered =~ HTML.html_escape("can't be blank") |> HTML.safe_to_string()
    end

    test "revoke token", %{conn: conn, store: store} do
      t0 = create_token(store)

      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :show, store.slug))

      t1 = create_token(store)

      rendered =
        view
        |> element(~s{.confirm[phx-value-id="#{t0.id}"})
        |> render_click(%{"id" => to_string(t0.id)})

      assert !(rendered =~ to_string(t0.id))
      assert rendered =~ to_string(t1.id)
    end
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} =
        live(conn, Routes.store_settings_path(conn, :show, other_store))
    end
  end
end
