defmodule BitPalWeb.ServerSetupLiveTest do
  use BitPalWeb.ConnCase, async: true
  alias BitPal.Repo
  alias BitPal.ServerSetup
  alias BitPalFactory.AccountFactory
  alias BitPalFactory.StoreFactory

  setup tags = %{conn: conn} do
    admin = AccountFactory.create_user()
    Map.merge(tags, %{conn: log_in_user(conn, admin), admin: admin})
  end

  describe "renders html" do
    @tag server_setup_state: :enable_backends
    test "backends", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/server/setup/wizard")

      assert html =~ "Setup backends"
    end

    @tag server_setup_state: :create_store
    test "create store", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/server/setup/wizard")

      assert html =~ "Create a store"
    end

    @tag server_setup_state: :completed
    test "completed", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/server/setup/wizard")

      assert html =~ "Setup completed"
    end
  end

  describe "skip stages" do
    @tag server_setup_state: :enable_backends
    test "skip all", %{conn: conn, test_server_setup: server_name} do
      {:ok, view, _html} = live(conn, ~p"/server/setup/wizard")

      view
      |> element(~s{.skip[phx-click="skip"})
      |> render_click()

      assert ServerSetup.current_state(server_name) == :create_store

      rendered =
        view
        |> element(~s{.skip[phx-click="skip"})
        |> render_click()

      assert ServerSetup.current_state(server_name) == :completed
      assert rendered =~ "Setup completed"
    end
  end

  describe "store creation" do
    @tag server_setup_state: :create_store
    test "creates a store and continues to next state", %{
      conn: conn,
      admin: admin,
      test_server_setup: server_name
    } do
      {:ok, view, _html} = live(conn, ~p"/server/setup/wizard")

      label = StoreFactory.unique_store_label()

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: label}})

      assert ServerSetup.current_state(server_name) == :completed
      assert rendered =~ "Setup completed"

      admin = admin |> Repo.preload(:stores)
      assert length(admin.stores) == 1
      assert hd(admin.stores).label == label
    end

    @tag server_setup_state: :create_store
    test "renders errors if invalid", %{conn: conn, test_server_setup: server_name} do
      {:ok, view, _html} = live(conn, ~p"/server/setup/wizard")

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: ""}})

      assert ServerSetup.current_state(server_name) == :create_store

      assert rendered =~ html_string("can't be blank")
    end
  end
end
