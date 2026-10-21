defmodule Beacon.SeedsTest do
  use Beacon.DataCase, async: false

  import ExUnit.CaptureIO

  alias Beacon.Flags.{AuditLogEntry, Environment, Flag, FlagState}
  alias Beacon.Repo

  @seeds_path Path.expand("../../priv/repo/seeds.exs", __DIR__)

  test "seeding twice leaves the database exactly as seeding once did" do
    capture_io(fn -> Code.eval_file(@seeds_path) end)

    environments_after_first = Repo.aggregate(Environment, :count)
    flags_after_first = Repo.aggregate(Flag, :count)
    states_after_first = Repo.aggregate(FlagState, :count)
    entries_after_first = Repo.aggregate(AuditLogEntry, :count)

    assert environments_after_first == 2
    assert flags_after_first == 3
    assert states_after_first == 6
    assert entries_after_first == 6

    capture_io(fn -> Code.eval_file(@seeds_path) end)

    assert Repo.aggregate(Environment, :count) == environments_after_first
    assert Repo.aggregate(Flag, :count) == flags_after_first
    assert Repo.aggregate(FlagState, :count) == states_after_first
    assert Repo.aggregate(AuditLogEntry, :count) == entries_after_first
  end
end
