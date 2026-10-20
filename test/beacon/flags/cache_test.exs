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

  describe "propagation via broadcast" do
    test "set_flag_state/4 broadcasts, and this node's cache updates from it — not a direct call" do
      user = user_fixture()
      flag = flag_fixture(user, %{key: "prop-flag"})
      environment = environment_fixture(user, %{name: "prop-env"})

      {:ok, _state} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 60})

      # A round trip after the broadcast: GenServer processes its mailbox
      # in order, so if this call's reply has come back, the broadcast
      # message — sent from this same test process, earlier — has
      # already been handled.
      :ok = Cache.sync()

      assert Cache.lookup(user.id, "prop-env", "prop-flag") ==
               {:ok, %{enabled: true, rollout_percentage: 60}}
    end

    test "a second, independently-named cache instance updates too — standing in for a second node" do
      user = user_fixture()
      flag = flag_fixture(user, %{key: "prop-flag-2"})
      environment = environment_fixture(user, %{name: "prop-env-2"})

      node_b = :"beacon_cache_test_node_#{System.unique_integer([:positive])}"
      start_supervised!({Cache, name: node_b})

      {:ok, _state} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 15})

      :ok = Cache.sync()
      :ok = Cache.sync(node_b)

      assert Cache.lookup(user.id, "prop-env-2", "prop-flag-2") ==
               {:ok, %{enabled: true, rollout_percentage: 15}}

      assert Cache.lookup(node_b, user.id, "prop-env-2", "prop-flag-2") ==
               {:ok, %{enabled: true, rollout_percentage: 15}}
    end

    test "a later change propagates too, not just the first one for a flag" do
      user = user_fixture()
      flag = flag_fixture(user, %{key: "prop-flag-3"})
      environment = environment_fixture(user, %{name: "prop-env-3"})

      {:ok, _} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 10})

      {:ok, _} =
        Flags.set_flag_state(user, flag, environment, %{enabled: false, rollout_percentage: 0})

      :ok = Cache.sync()

      assert Cache.lookup(user.id, "prop-env-3", "prop-flag-3") ==
               {:ok, %{enabled: false, rollout_percentage: 0}}
    end
  end
end
