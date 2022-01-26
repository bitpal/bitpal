defmodule BitPalWeb.HomeLiveTest do
  use BitPalWeb.ConnCase, integration: true, async: false
  alias BitPal.Backend
  alias BitPal.BackendMock
  alias BitPal.Stores
  alias BitPal.Repo
  alias BitPalFactory.StoreFactory

  setup tags do
    tags
    |> register_and_log_in_user()
  end

  describe "show on dashboard" do
    test "list stores", %{conn: conn, user: user} do
      s0 = create_store(user)
      s1 = create_store(user)

      {:ok, _view, html} = live(conn, Routes.home_path(conn, :dashboard))
      assert html =~ s0.label |> html_string()
      assert html =~ s1.label |> html_string()
    end

    test "live add created store", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, Routes.home_path(conn, :dashboard))

      {:ok, store} = Stores.create(user, valid_store_attributes())
      assert render_eventually(view, html_string(store.label))
    end
  end

  describe "create store" do
    test "creates a store and lists it", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, Routes.home_path(conn, :dashboard))

      label = StoreFactory.unique_store_label()

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: label}})

      assert rendered =~ html_string(label)

      user = user |> Repo.preload(:stores)
      assert length(user.stores) == 1
      assert hd(user.stores).label == label
    end

    test "renders errors if invalid", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, Routes.home_path(conn, :dashboard))

      rendered =
        view
        |> element("form")
        |> render_submit(%{"store" => %{label: ""}})

      assert rendered =~ html_string("can't be blank")
    end
  end

  describe "backends" do
    @tag backends: [BackendMock, BackendMock, BackendMock]
    test "list backends", %{conn: conn, backends: backends} do
      {:ok, _view, html} = live(conn, Routes.home_path(conn, :dashboard))

      for backend <- backends do
        {:ok, currency_id} = Backend.supported_currency(backend)
        assert html =~ currency_id |> html_string()
      end
    end

    @tag backends: [{BackendMock, status: :stopped, sync_time: 50}]
    test "start and stop backend", %{conn: conn, backend: backend} do
      {:ok, view, _html} = live(conn, Routes.home_path(conn, :dashboard))

      assert view |> element(".status") |> render() =~ "Stopped"

      assert Backend.start(backend) == :ok
      assert render_eventually(view, "Syncing", ".status")
      assert render_eventually(view, "Started", ".status")

      assert Backend.stop(backend) == :ok
      assert render_eventually(view, "Stopped", ".status")
    end
  end

  describe "security" do
    test "don't show other store", %{conn: conn} do
      other_store =
        create_user()
        |> create_store()

      {:ok, _view, html} = live(conn, Routes.home_path(conn, :dashboard))
      assert !(html =~ other_store.label |> html_string())
    end
  end
end
