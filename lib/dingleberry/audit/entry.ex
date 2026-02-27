defmodule Dingleberry.Audit.Entry do
  @moduledoc "Ecto schema for audit log entries."

  use Ecto.Schema
  import Ecto.Changeset

  schema "audit_entries" do
    field :command, :string
    field :source, :string, default: "unknown"
    field :risk, :string
    field :decision, :string
    field :matched_rule, :string
    field :session_id, :string
    field :decided_by, :string
    field :reason, :string
    field :metadata, :map

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(command risk decision)a
  @optional_fields ~w(source matched_rule session_id decided_by reason metadata)a

  def changeset(entry, attrs) do
    entry
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:risk, ~w(safe warn block))
    |> validate_inclusion(:decision, ~w(approved rejected timed_out auto_approved auto_blocked))
  end
end
