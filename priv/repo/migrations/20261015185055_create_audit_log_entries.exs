defmodule Beacon.Repo.Migrations.CreateAuditLogEntries do
  use Ecto.Migration

  def change do
    create table(:audit_log_entries) do
      add :enabled, :boolean, null: false
      add :rollout_percentage, :integer, null: false
      add :flag_id, references(:flags, on_delete: :delete_all), null: false
      add :environment_id, references(:environments, on_delete: :delete_all), null: false
      add :user_id, references(:users, on_delete: :nilify_all)

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:audit_log_entries, [:flag_id, :inserted_at])
  end
end
