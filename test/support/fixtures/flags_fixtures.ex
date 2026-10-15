defmodule Beacon.FlagsFixtures do
  @moduledoc """
  Test helpers that build flag records through the `Beacon.Flags`
  context.
  """

  alias Beacon.Flags

  import Beacon.AccountsFixtures

  def environment_fixture(user \\ nil, attrs \\ %{}) do
    user = user || user_fixture()
    {:ok, environment} = Flags.create_environment(user, Enum.into(attrs, %{name: "production"}))
    environment
  end

  def flag_fixture(user \\ nil, attrs \\ %{}) do
    user = user || user_fixture()
    {:ok, flag} = Flags.create_flag(user, Enum.into(attrs, %{key: "new-dashboard"}))
    flag
  end
end
