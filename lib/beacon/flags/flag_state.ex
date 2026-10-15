defmodule Beacon.Flags.FlagState do
  @moduledoc """
  Whether a flag is on, and at what rollout percentage, in one
  environment. There is at most one of these per (flag, environment)
  pair — no row yet means "off, 0%", the same as an explicit one would.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "flag_states" do
    field :enabled, :boolean, default: false
    field :rollout_percentage, :integer, default: 0

    belongs_to :flag, Beacon.Flags.Flag
    belongs_to :environment, Beacon.Flags.Environment

    timestamps(type: :utc_datetime)
  end

  @doc "Builds a changeset for a flag's state in one environment."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(flag_state, attrs) do
    flag_state
    |> cast(attrs, [:enabled, :rollout_percentage])
    |> validate_required([:enabled, :rollout_percentage])
    |> validate_number(:rollout_percentage,
      greater_than_or_equal_to: 0,
      less_than_or_equal_to: 100
    )
    |> unique_constraint([:flag_id, :environment_id])
  end
end
