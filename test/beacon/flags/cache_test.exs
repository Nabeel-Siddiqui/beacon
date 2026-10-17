defmodule Beacon.Flags.CacheTest do
  use Beacon.DataCase, async: true

  import Beacon.AccountsFixtures
  import Beacon.FlagsFixtures

  alias Beacon.Flags
  alias Beacon.Flags.Cache
  alias Ecto.Adapters.SQL.Sandbox

  describe "put/4 and lookup/3" do
    test "a lookup before any put is a cache miss" do
      user = user_fixture()

      assert Cache.lookup(user.id, "production", "new-dashboard") == :error
    end

    test "put/4 makes the value immediately visible to lookup/3" do
      user = user_fixture()

      :ok =
        Cache.put(user.id, "production", "new-dashboard", %{enabled: true, rollout_percentage: 25})

      assert Cache.lookup(user.id, "production", "new-dashboard") ==
               {:ok, %{enabled: true, rollout_percentage: 25}}
    end

    test "a later put for the same key replaces the earlier value" do
      user = user_fixture()

      :ok =
        Cache.put(user.id, "production", "new-dashboard", %{enabled: false, rollout_percentage: 0})

      :ok =
        Cache.put(user.id, "production", "new-dashboard", %{
          enabled: true,
          rollout_percentage: 100
        })

      assert Cache.lookup(user.id, "production", "new-dashboard") ==
               {:ok, %{enabled: true, rollout_percentage: 100}}
    end

    test "different users, environments, and flag keys don't collide" do
      user_a = user_fixture()
      user_b = user_fixture()

      :ok = Cache.put(user_a.id, "production", "x", %{enabled: true, rollout_percentage: 100})
      :ok = Cache.put(user_b.id, "production", "x", %{enabled: false, rollout_percentage: 0})

      assert {:ok, %{enabled: true}} = Cache.lookup(user_a.id, "production", "x")
      assert {:ok, %{enabled: false}} = Cache.lookup(user_b.id, "production", "x")
    end
  end

  describe "warm!/0" do
    test "loads every persisted flag state from Postgres into the cache" do
      # This process needs to lend its sandboxed connection to the Cache
      # GenServer — warm!/0 runs the load from inside that long-lived
      # singleton process, not this test's own process.
      Sandbox.allow(Beacon.Repo, self(), Process.whereis(Cache))

      user = user_fixture()
      flag = flag_fixture(user, %{key: "warm-test-flag"})
      environment = environment_fixture(user, %{name: "warm-test-env"})

      {:ok, _state} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 42})

      :ok = Cache.warm!()

      assert Cache.lookup(user.id, "warm-test-env", "warm-test-flag") ==
               {:ok, %{enabled: true, rollout_percentage: 42}}
    end
  end
end
