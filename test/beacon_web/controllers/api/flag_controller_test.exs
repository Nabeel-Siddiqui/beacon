defmodule BeaconWeb.API.FlagControllerTest do
  use BeaconWeb.ConnCase, async: true

  import Beacon.FlagsFixtures

  alias Beacon.Accounts
  alias Beacon.Flags
  alias Beacon.Flags.Cache

  setup %{conn: conn} do
    user = Beacon.AccountsFixtures.user_fixture()
    token = Accounts.create_user_api_token(user)

    conn = put_req_header(conn, "authorization", "Bearer #{token}")

    %{conn: conn, user: user, token: token}
  end

  describe "GET /api/flags/:key/enabled" do
    test "returns false for a flag with no recorded state", %{conn: conn} do
      conn = get(conn, ~p"/api/flags/unknown-flag/enabled?environment=production&subject=u1")

      assert json_response(conn, 200) == %{
               "flag" => "unknown-flag",
               "environment" => "production",
               "subject" => "u1",
               "enabled" => false
             }
    end

    test "returns true once the flag is fully enabled", %{conn: conn, user: user} do
      flag = flag_fixture(user)
      environment = environment_fixture(user, %{name: "production"})

      {:ok, _state} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 100})

      Cache.sync()

      conn =
        get(conn, ~p"/api/flags/#{flag.key}/enabled?environment=production&subject=u1")

      assert %{"enabled" => true} = json_response(conn, 200)
    end

    test "evaluates the token's own owner's flags, not another user's", %{conn: conn} do
      other_user = Beacon.AccountsFixtures.user_fixture()
      flag = flag_fixture(other_user, %{key: "other-users-flag"})
      environment = environment_fixture(other_user, %{name: "production"})

      {:ok, _state} =
        Flags.set_flag_state(other_user, flag, environment, %{
          enabled: true,
          rollout_percentage: 100
        })

      Cache.sync()

      conn =
        get(conn, ~p"/api/flags/other-users-flag/enabled?environment=production&subject=u1")

      assert %{"enabled" => false} = json_response(conn, 200)
    end

    test "requires the environment param", %{conn: conn} do
      conn = get(conn, ~p"/api/flags/some-flag/enabled?subject=u1")

      assert json_response(conn, 400)["error"] =~ "environment"
    end

    test "requires the subject param", %{conn: conn} do
      conn = get(conn, ~p"/api/flags/some-flag/enabled?environment=production")

      assert json_response(conn, 400)["error"] =~ "subject"
    end

    test "rejects a request with no token" do
      conn = Phoenix.ConnTest.build_conn()
      conn = get(conn, ~p"/api/flags/some-flag/enabled?environment=production&subject=u1")

      assert json_response(conn, 401)["error"] =~ "token"
    end

    test "rejects a request with an invalid token", %{conn: conn} do
      conn =
        conn
        |> put_req_header("authorization", "Bearer not-a-real-token")
        |> get(~p"/api/flags/some-flag/enabled?environment=production&subject=u1")

      assert json_response(conn, 401)["error"] =~ "token"
    end

    test "rejects a request using a revoked token", %{conn: conn, user: user} do
      [%{id: id}] = Accounts.list_user_api_tokens(user)
      :ok = Accounts.delete_user_api_token(user, id)

      conn = get(conn, ~p"/api/flags/some-flag/enabled?environment=production&subject=u1")

      assert json_response(conn, 401)
    end
  end
end
