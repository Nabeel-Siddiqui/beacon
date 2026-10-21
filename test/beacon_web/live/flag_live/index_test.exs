defmodule BeaconWeb.FlagLive.IndexTest do
  use BeaconWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Beacon.FlagsFixtures

  setup :register_and_log_in_user

  describe "Index" do
    test "lists the user's flags", %{conn: conn, user: user} do
      flag_fixture(user, %{key: "new-dashboard", description: "The redesign"})

      {:ok, _view, html} = live(conn, ~p"/flags")

      assert html =~ "new-dashboard"
      assert html =~ "The redesign"
    end

    test "shows an empty state with no flags", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/flags")

      assert html =~ "No flags yet"
    end

    test "doesn't show another user's flags", %{conn: conn} do
      other = Beacon.AccountsFixtures.user_fixture()
      flag_fixture(other, %{key: "not-mine"})

      {:ok, _view, html} = live(conn, ~p"/flags")

      refute html =~ "not-mine"
    end

    test "creates a new flag", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/flags")

      view
      |> element(~s|a[href="#{~p"/flags/new"}"]|)
      |> render_click()

      assert_patch(view, ~p"/flags/new")

      view
      |> form("#flag-form", flag: %{key: "checkout-v2"})
      |> render_submit()

      assert_patch(view, ~p"/flags")
      assert render(view) =~ "checkout-v2"
    end

    test "rejects a key with uppercase letters or spaces", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/flags/new")

      html =
        view
        |> form("#flag-form", flag: %{key: "Checkout V2"})
        |> render_submit()

      assert html =~ "must be lowercase letters, numbers, underscores, or hyphens"
    end

    test "redirects if the user is not logged in" do
      conn = Phoenix.ConnTest.build_conn()
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = live(conn, ~p"/flags")
    end
  end
end
