defmodule Beacon.Flags.Environment do
  @moduledoc """
  A place a flag can be evaluated in — "production", "staging", and so
  on. Each flag has its own, independent state per environment.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "environments" do
    field :name, :string

    belongs_to :user, Beacon.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @doc "Builds a changeset for an environment owned by a user."
  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(environment, attrs) do
    environment
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> validate_length(:name, max: 50)
    |> unique_constraint(:name, name: :environments_user_id_name_index)
  end
end
