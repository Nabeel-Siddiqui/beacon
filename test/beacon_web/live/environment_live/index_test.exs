defmodule BeaconWeb.EnvironmentLive.IndexTest do
  use BeaconWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Beacon.FlagsFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "lists the user's environments", %{conn: conn, user: user} do
      environment_fixture(user, %{name: "production"})

      {:ok, _view, html} = live(conn, ~p"/environments")

      assert html =~ "production"
    end

    test "shows an empty state with no environments", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/environments")

      assert html =~ "No environments yet"
    end

    test "doesn't show another user's environments", %{conn: conn} do
      other = Beacon.AccountsFixtures.user_fixture()
      environment_fixture(other, %{name: "not-mine"})

      {:ok, _view, html} = live(conn, ~p"/environments")

      refute html =~ "not-mine"
    end

    test "creates a new environment", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/environments")

      view
      |> element(~s|a[href="#{~p"/environments/new"}"]|)
      |> render_click()

      assert_patch(view, ~p"/environments/new")

      view
      |> form("#environment-form", environment: %{name: "staging"})
      |> render_submit()

      assert_patch(view, ~p"/environments")
      assert render(view) =~ "staging"
    end

    test "rejects a second environment with the same name", %{conn: conn, user: user} do
      environment_fixture(user, %{name: "production"})

      {:ok, view, _html} = live(conn, ~p"/environments/new")

      html =
        view
        |> form("#environment-form", environment: %{name: "production"})
        |> render_submit()

      assert html =~ "has already been taken"
    end

    test "redirects if the user is not logged in" do
      conn = Phoenix.ConnTest.build_conn()
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/environments")
    end
  end
end
