defmodule Beacon.Flags.AuditLogEntry do
  @moduledoc """
  An immutable record of what a flag's state became, in one environment,
  and who changed it. Never updated or deleted — only ever inserted
  alongside the `FlagState` row it describes, in the same transaction.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "audit_log_entries" do
    field :enabled, :boolean
    field :rollout_percentage, :integer

    belongs_to :flag, Beacon.Flags.Flag
    belongs_to :environment, Beacon.Flags.Environment
    belongs_to :user, Beacon.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Builds a changeset for one audit entry. Not meant to be edited after insert."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(entry, attrs) do
    entry
    |> cast(attrs, [:enabled, :rollout_percentage])
    |> validate_required([:enabled, :rollout_percentage])
  end
end
