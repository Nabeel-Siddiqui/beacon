defmodule Beacon.Flags.ExpireFlagsWorkerTest do
  use Beacon.DataCase, async: true
  use Oban.Testing, repo: Beacon.Repo

  import Beacon.AccountsFixtures
  import Beacon.FlagsFixtures

  alias Beacon.Flags
  alias Beacon.Flags.{ExpireFlagsWorker, FlagState}

  describe "perform/1" do
    test "disables every flag state whose expiry has passed" do
      user = user_fixture()
      flag = flag_fixture(user)
      environment = environment_fixture(user)
      future = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, _state} =
        Flags.set_flag_state(user, flag, environment, %{
          enabled: true,
          rollout_percentage: 100,
          expires_at: future
        })

      Repo.update_all(FlagState, set: [expires_at: DateTime.add(future, -7200, :second)])

      assert :ok = perform_job(ExpireFlagsWorker, %{})

      expired = Flags.get_flag_state(flag, environment)
      assert expired.enabled == false
    end
  end
end
