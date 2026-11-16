defmodule Beacon.Repo.Migrations.AddExpiresAtToFlagStates do
  use Ecto.Migration

  def change do
    alter table(:flag_states) do
      add :expires_at, :utc_datetime
    end
  end
end
