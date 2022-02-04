defmodule BitPalWeb.StoreSettingsLiveTest do
  # Tests must be async as we're testing for currency existance
  use BitPalWeb.ConnCase, integration: true, async: false
  import Ecto.Query
  alias BitPal.Repo
  alias BitPalSchemas.AccessToken
  alias BitPalSchemas.AddressKey
  alias BitPalSchemas.Store
  alias BitPalSettings.StoreSettings

  setup tags do
    tags
    |> register_and_log_in_user()
    |> add_store()
  end

  describe "update store label" do
    test "set", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :general, store.slug))
      new_label = "new label"

      rendered =
        view
        |> element("#edit-store")
        |> render_submit(%{"store" => %{label: new_label}})

      assert rendered =~ new_label
      assert !(rendered =~ store.label)

      store = Repo.get!(Store, store.id)
      assert store.label == new_label
    end

    test "errors on empty label", %{conn: conn, store: store} do
      {:ok, view, _html} = live(conn, Routes.store_settings_path(conn, :general, store.slug))

      rendered =
        view
        |> element("#edit-store")
        |> render_submit(%{"store" => %{label: ""}})

      assert rendered =~ html_string("can't be blank")
      assert rendered =~ store.label
    end
  end

  describe "tokens" do
    test "show tokens", %{conn: conn, store: store} do
      now = System.system_time(:second)

      store =
        store
        |> with_token(signed_at: now - 1_000)
        |> with_token(signed_at: now)

      {:ok, _view, html} =
        live(conn, Routes.store_settings_path(conn, :access_tokens, store.slug))

      for token <- store.access_tokens do
        assert html =~ token.label
        assert !(html =~ token.data)
      end
    end

    test "create", %{conn: conn, store: store} do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :access_tokens, store.slug))

      label = Faker.StarWars.character()

      rendered =
        view
        |> element("form.create-token")
        |> render_submit(%{"access_token" => %{"label" => label}})

      token =
        from(t in AccessToken, where: t.store_id == ^store.id)
        |> Repo.one!()

      assert rendered =~ token.label
      assert rendered =~ token.data
    end

    test "create errors on missing label", %{conn: conn, store: store} do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :access_tokens, store.slug))

      rendered =
        view
        |> element("form.create-token")
        |> render_submit(%{"access_token" => %{"label" => ""}})

      assert rendered =~ html_string("can't be blank")
    end

    test "create with valid_until", %{conn: conn, store: store} do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :access_tokens, store.slug))

      tomorrow =
        NaiveDateTime.utc_now()
        |> NaiveDateTime.add(60 * 60 * 24, :second)
        |> Timex.format!("{ISOdate}")

      rendered =
        view
        |> element("form.create-token")
        |> render_submit(%{"access_token" => valid_token_attributes(%{"valid_until" => tomorrow})})

      assert rendered =~ tomorrow
    end

    test "revoke token", %{conn: conn, store: store} do
      t0 = create_token(store)

      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :access_tokens, store.slug))

      t1 = create_token(store)

      rendered =
        view
        |> element(~s{button[phx-value-id="#{t0.id}"})
        |> render_click(%{"id" => to_string(t0.id)})

      assert !(rendered =~ to_string(t0.id))
      assert rendered =~ to_string(t1.id)
    end
  end

  describe "display" do
    @tag backends: [BitPal.BackendMock, BitPal.BackendMock]
    test "show currency settings", %{conn: conn, store: store, currencies: currencies} do
      c0 = hd(currencies)

      # Add some settings to one of the currencies, as the rendering
      # logic is different depending on if the settings data exists in db or not.
      {:ok, _} = StoreSettings.set_required_confirmations(store.id, c0, 42)

      {:ok, _view, html} = live(conn, Routes.store_settings_path(conn, :general, store.slug))

      for currency_id <- currencies do
        assert html =~ Money.Currency.name!(currency_id)
      end
    end
  end

  describe "crypto settings" do
    test "set xpub", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :crypto, store.slug, currency_id))

      xpub = unique_address_key_id()

      rendered =
        view
        |> element("form.address-key-form")
        |> render_submit(%{"address_key" => %{data: xpub}})

      assert rendered =~ xpub
      assert rendered =~ "Key updated"

      assert {:ok, %AddressKey{data: ^xpub}} =
               StoreSettings.fetch_address_key(store.id, currency_id)
    end

    test "failed to set xpub", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :crypto, store.slug, currency_id))

      rendered =
        view
        |> element("form", "xpub")
        |> render_submit(%{"address_key" => %{data: ""}})

      assert rendered =~ "Failed to update key"
      assert {:error, :not_found} = StoreSettings.fetch_address_key(store.id, currency_id)
    end

    test "set required confirmations", %{conn: conn, store: store, currency_id: currency_id} do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :crypto, store.slug, currency_id))

      confs = 13

      rendered =
        view
        |> element("form", "confirmations")
        |> render_change(%{"currency_settings" => %{required_confirmations: confs}})

      assert rendered =~ Integer.to_string(confs)
      assert confs == StoreSettings.get_required_confirmations(store.id, currency_id)
    end

    @tag do: true
    test "failed to set required confirmations", %{
      conn: conn,
      store: store,
      currency_id: currency_id
    } do
      {:ok, view, _html} =
        live(conn, Routes.store_settings_path(conn, :crypto, store.slug, currency_id))

      rendered =
        view
        |> element("form", "confirmations")
        |> render_change(%{"currency_settings" => %{required_confirmations: "fail"}})

      assert rendered =~ "is invalid"
    end
  end

  describe "OLD" do
  end

  describe "update required confirmations" do
  end

  describe "security" do
    test "redirect from other store", %{conn: conn, store: _store} do
      other_store =
        create_user()
        |> create_store()

      {:error, {:redirect, %{to: "/"}}} =
        live(conn, Routes.store_settings_path(conn, :general, other_store))
    end
  end
end
