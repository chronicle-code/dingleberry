defmodule Dingleberry.Repo.Migrations.CreateAuditEntries do
  use Ecto.Migration

  def change do
    create table(:audit_entries) do
      add :command, :text, null: false
      add :source, :string, null: false, default: "unknown"
      add :risk, :string, null: false
      add :decision, :string, null: false
      add :matched_rule, :string
      add :session_id, :string
      add :decided_by, :string
      add :reason, :text
      add :metadata, :map

      timestamps(type: :utc_datetime)
    end

    create index(:audit_entries, [:risk])
    create index(:audit_entries, [:decision])
    create index(:audit_entries, [:session_id])
    create index(:audit_entries, [:inserted_at])
  end
end
