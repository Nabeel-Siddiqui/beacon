defmodule Beacon.Flags.Flag do
  @moduledoc """
  A feature a user is toggling. The flag itself has no on/off state —
  that's per environment, held in `Beacon.Flags.FlagState`.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @key_pattern ~r/^[a-z0-9][a-z0-9_-]*$/

  @type t :: %__MODULE__{}

  schema "flags" do
    field :key, :string
    field :description, :string

    belongs_to :user, Beacon.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc "Builds a changeset for a flag owned by a user."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(flag, attrs) do
    flag
    |> cast(attrs, [:key, :description])
    |> validate_required([:key])
    |> validate_format(:key, @key_pattern,
      message: "must be lowercase letters, numbers, underscores, or hyphens"
    )
    |> validate_length(:key, max: 100)
    |> unique_constraint(:key, name: :flags_user_id_key_index)
  end
end
