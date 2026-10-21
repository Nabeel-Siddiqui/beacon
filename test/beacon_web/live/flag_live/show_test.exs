defmodule BeaconWeb.FlagLive.ShowTest do
  use BeaconWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Beacon.FlagsFixtures

  alias Beacon.Flags

  setup :register_and_log_in_user

  describe "Show" do
    test "renders the flag and a prompt to add an environment, with none yet", %{
      conn: conn,
      user: user
    } do
      flag = flag_fixture(user, %{key: "new-dashboard"})

      {:ok, _view, html} = live(conn, ~p"/flags/#{flag}")

      assert html =~ "new-dashboard"
      assert html =~ "No environments yet"
      assert html =~ "No changes recorded yet"
    end

    test "shows each environment with its current (default) state", %{conn: conn, user: user} do
      flag = flag_fixture(user)
      environment_fixture(user, %{name: "production"})

      {:ok, _view, html} = live(conn, ~p"/flags/#{flag}")

      assert html =~ "production"
    end

    test "setting a flag's state updates it and appends to the audit log", %{
      conn: conn,
      user: user
    } do
      flag = flag_fixture(user)
      environment = environment_fixture(user, %{name: "production"})

      {:ok, view, _html} = live(conn, ~p"/flags/#{flag}")

      view
      |> form("form", %{
        "environment_id" => environment.id,
        "enabled" => "true",
        "rollout_percentage" => "50"
      })
      |> render_submit()

      html = render(view)
      assert html =~ "50%"
      assert html =~ user.email

      assert [entry] = Flags.list_audit_log(flag)
      assert entry.enabled == true
      assert entry.rollout_percentage == 50
    end

    test "rejects a rollout percentage outside 0-100", %{conn: conn, user: user} do
      flag = flag_fixture(user)
      environment = environment_fixture(user, %{name: "production"})

      {:ok, view, _html} = live(conn, ~p"/flags/#{flag}")

      html =
        view
        |> form("form", %{
          "environment_id" => environment.id,
          "enabled" => "true",
          "rollout_percentage" => "150"
        })
        |> render_submit()

      assert html =~ "Couldn&#39;t save that"
    end

    test "a change made elsewhere (same flag, another process) shows up live", %{
      conn: conn,
      user: user
    } do
      flag = flag_fixture(user)
      environment = environment_fixture(user, %{name: "production"})

      {:ok, view, _html} = live(conn, ~p"/flags/#{flag}")
      refute render(view) =~ "75%"

      {:ok, _state} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 75})

      assert render(view) =~ "75%"
    end

    test "redirects to the flags list for another user's flag", %{conn: conn} do
      other = Beacon.AccountsFixtures.user_fixture()
      theirs = flag_fixture(other)

      assert {:error, {:live_redirect, %{to: "/flags"}}} = live(conn, ~p"/flags/#{theirs}")
    end

    test "redirects for a nonexistent flag", %{conn: conn} do
      assert {:error, {:live_redirect, %{to: "/flags"}}} = live(conn, ~p"/flags/999999")
    end
  end
end
