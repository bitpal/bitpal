defmodule BitPalWeb.ServerSetupLiveTest do
  use BitPalWeb.ConnCase, async: true
  import BitPal.ServerSetup
  alias BitPal.Repo
  alias BitPalFactory.StoreFactory

  setup tags = %{conn: conn, state: state} do
    admin = server_setup_state(state)
    Map.merge(tags, %{conn: log_in_user(conn, admin), admin: admin})
  end

  describe "renders html" do
    @tag state: :enable_backends
    test "backends", %{conn: conn} do
      {:ok, _view, html} = live(conn, Routes.server_setup_path(conn, :wizard))

      assert html =~ "Setup backends"
    end

    @tag state: :create_store
    test "create store", %{conn: conn} do
      {:ok, _view, html} = live(conn, Routes.server_setup_path(conn, :wizard))

      assert html =~ "Create a store"
    end

    @tag state: :completed
    test "completed", %{conn: conn} do
      {:ok, _view, html} = live(conn, Routes.server_setup_path(conn, :wizard))

      assert html =~ "Setup completed"
    end
  end

  describe "skip stages" do
    @tag state: :enable_backends
    test "skip all", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.server_setup_path(conn, :wizard))

      view
      |> element(~s{.skip[phx-click="skip"})
      |> render_click()

      assert setup_state() == :create_store

      rendered =
        view
        |> element(~s{.skip[phx-click="skip"})
        |> render_click()

      assert setup_state() == :completed
      assert rendered =~ "Setup completed"
    end
  end

  describe "store creation" do
    @tag state: :create_store
    test "creates a store and continues to next state", %{conn: conn, admin: admin} do
      {:ok, view, _html} = live(conn, Routes.server_setup_path(conn, :wizard))

      label = StoreFactory.unique_store_label()

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: label}})

      assert setup_state() == :completed
      assert rendered =~ "Setup completed"

      admin = admin |> Repo.preload(:stores)
      assert length(admin.stores) == 1
      assert hd(admin.stores).label == label
    end

    @tag state: :create_store
    test "renders errors if invalid", %{conn: conn} do
      {:ok, view, _html} = live(conn, Routes.server_setup_path(conn, :wizard))

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: ""}})

      assert setup_state() == :create_store

      assert rendered =~ html_string("can't be blank")
    end
  end
end
