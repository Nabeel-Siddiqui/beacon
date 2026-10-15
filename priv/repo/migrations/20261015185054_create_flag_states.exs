defmodule Beacon.Repo.Migrations.CreateFlagStates do
  use Ecto.Migration

  def change do
    create table(:flag_states) do
      add :enabled, :boolean, null: false, default: false
      add :rollout_percentage, :integer, null: false, default: 0
      add :flag_id, references(:flags, on_delete: :delete_all), null: false
      add :environment_id, references(:environments, on_delete: :delete_all), null: false

      timestamps(type: :utc_datetime)
    end

    create unique_index(:flag_states, [:flag_id, :environment_id])
  end
end
