defmodule Beacon.FlagsTest do
  use Beacon.DataCase, async: true

  import Beacon.AccountsFixtures
  import Beacon.FlagsFixtures

  alias Beacon.Flags
  alias Beacon.Flags.FlagState

  describe "create_environment/2" do
    test "creates an environment owned by the user" do
      user = user_fixture()

      assert {:ok, environment} = Flags.create_environment(user, %{name: "production"})
      assert environment.name == "production"
      assert environment.user_id == user.id
    end

    test "requires a name" do
      user = user_fixture()

      assert {:error, changeset} = Flags.create_environment(user, %{})
      assert "can't be blank" in errors_on(changeset).name
    end

    test "rejects a second environment with the same name for the same user" do
      user = user_fixture()
      _first = environment_fixture(user, %{name: "production"})

      assert {:error, changeset} = Flags.create_environment(user, %{name: "production"})
      assert "has already been taken" in errors_on(changeset).name
    end

    test "the same name is fine for a different user" do
      user_a = user_fixture()
      user_b = user_fixture()
      _env_a = environment_fixture(user_a, %{name: "production"})

      assert {:ok, _env_b} = Flags.create_environment(user_b, %{name: "production"})
    end
  end

  describe "get_environment/2" do
    test "returns the environment for its owner" do
      user = user_fixture()
      environment = environment_fixture(user)

      assert {:ok, ^environment} = Flags.get_environment(user, environment.id)
    end

    test "returns :not_found for another user's environment" do
      owner = user_fixture()
      other = user_fixture()
      environment = environment_fixture(owner)

      assert {:error, :not_found} = Flags.get_environment(other, environment.id)
    end

    test "returns :not_found for a malformed id instead of raising" do
      user = user_fixture()

      assert {:error, :not_found} = Flags.get_environment(user, "not-an-id")
    end
  end

  describe "list_environments/1" do
    test "lists only the user's own environments, alphabetically" do
      user = user_fixture()
      other = user_fixture()
      _staging = environment_fixture(user, %{name: "staging"})
      _production = environment_fixture(user, %{name: "production"})
      _theirs = environment_fixture(other, %{name: "production"})

      assert Flags.list_environments(user) |> Enum.map(& &1.name) == ["production", "staging"]
    end
  end

  describe "create_flag/2" do
    test "creates a flag owned by the user" do
      user = user_fixture()

      assert {:ok, flag} =
               Flags.create_flag(user, %{key: "new-dashboard", description: "The redesign"})

      assert flag.key == "new-dashboard"
      assert flag.user_id == user.id
    end

    test "rejects a key with uppercase letters or spaces" do
      user = user_fixture()

      assert {:error, changeset} = Flags.create_flag(user, %{key: "New Dashboard"})
      assert errors_on(changeset).key != nil
    end

    test "rejects a second flag with the same key for the same user" do
      user = user_fixture()
      _first = flag_fixture(user, %{key: "new-dashboard"})

      assert {:error, changeset} = Flags.create_flag(user, %{key: "new-dashboard"})
      assert "has already been taken" in errors_on(changeset).key
    end
  end

  describe "get_flag/2" do
    test "returns the flag for its owner" do
      user = user_fixture()
      flag = flag_fixture(user)

      assert {:ok, ^flag} = Flags.get_flag(user, flag.id)
    end

    test "returns :not_found for another user's flag" do
      owner = user_fixture()
      other = user_fixture()
      flag = flag_fixture(owner)

      assert {:error, :not_found} = Flags.get_flag(other, flag.id)
    end
  end

  describe "list_flags/1" do
    test "lists only the user's own flags, alphabetically by key" do
      user = user_fixture()
      other = user_fixture()
      _b = flag_fixture(user, %{key: "b-flag"})
      _a = flag_fixture(user, %{key: "a-flag"})
      _theirs = flag_fixture(other, %{key: "c-flag"})

      assert Flags.list_flags(user) |> Enum.map(& &1.key) == ["a-flag", "b-flag"]
    end
  end

  describe "get_flag_state/2" do
    test "defaults to off at 0% when no state has ever been set" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)

      state = Flags.get_flag_state(flag, environment)

      assert state.enabled == false
      assert state.rollout_percentage == 0
      refute state.id
    end

    test "returns the persisted state once one has been set" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)

      {:ok, _} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 50})

      state = Flags.get_flag_state(flag, environment)
      assert state.enabled == true
      assert state.rollout_percentage == 50
      assert state.id
    end
  end

  describe "set_flag_state/4" do
    test "creates a state and an audit entry on the first change" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)

      assert {:ok, %FlagState{} = state} =
               Flags.set_flag_state(user, flag, environment, %{
                 enabled: true,
                 rollout_percentage: 25
               })

      assert state.enabled == true
      assert state.rollout_percentage == 25

      assert [entry] = Flags.list_audit_log(flag)
      assert entry.enabled == true
      assert entry.rollout_percentage == 25
      assert entry.user_id == user.id
      assert entry.environment_id == environment.id
    end

    test "updates the same row on a second change instead of creating another" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)

      {:ok, first} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 10})

      {:ok, second} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 90})

      assert first.id == second.id
      assert second.rollout_percentage == 90
      assert length(Flags.list_audit_log(flag)) == 2
    end

    test "rejects a rollout percentage outside 0-100" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)

      assert {:error, changeset} =
               Flags.set_flag_state(user, flag, environment, %{
                 enabled: true,
                 rollout_percentage: 150
               })

      assert "must be less than or equal to 100" in errors_on(changeset).rollout_percentage
    end

    test "refuses to change a flag that belongs to another user" do
      owner = user_fixture()
      other = user_fixture()
      flag = flag_fixture(owner)
      environment = environment_fixture(owner)

      assert {:error, :not_found} =
               Flags.set_flag_state(other, flag, environment, %{
                 enabled: true,
                 rollout_percentage: 0
               })
    end

    test "refuses to change a flag using another user's environment" do
      user = user_fixture()
      other = user_fixture()
      flag = flag_fixture(user)
      their_environment = environment_fixture(other)

      assert {:error, :not_found} =
               Flags.set_flag_state(user, flag, their_environment, %{
                 enabled: true,
                 rollout_percentage: 0
               })
    end
  end

  describe "list_audit_log/1" do
    test "lists entries newest first" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)

      {:ok, _} =
        Flags.set_flag_state(user, flag, environment, %{enabled: false, rollout_percentage: 0})

      {:ok, _} =
        Flags.set_flag_state(user, flag, environment, %{enabled: true, rollout_percentage: 100})

      assert [newest, oldest] = Flags.list_audit_log(flag)
      assert newest.rollout_percentage == 100
      assert oldest.rollout_percentage == 0
    end

    test "doesn't include another flag's entries" do
      user = user_fixture()
      flag = flag_fixture(user, %{key: "mine"})
      other_flag = flag_fixture(user, %{key: "theirs"})
      environment = environment_fixture(user)

      {:ok, _} =
        Flags.set_flag_state(user, other_flag, environment, %{
          enabled: true,
          rollout_percentage: 0
        })

      assert Flags.list_audit_log(flag) == []
    end
  end
end
