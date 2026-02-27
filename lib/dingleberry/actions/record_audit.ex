defmodule Dingleberry.Actions.RecordAudit do
  @moduledoc "Jido Action: Records an audit log entry."

  use Jido.Action,
    name: "record_audit",
    description: "Records a command interception event to the audit log",
    category: "audit",
    tags: ["audit", "logging", "persistence"],
    vsn: "1.0.0",
    schema: [
      command: [type: :string, required: true, doc: "The intercepted command"],
      source: [type: :string, default: "unknown", doc: "Command source (shell/mcp)"],
      risk: [type: :string, required: true, doc: "Risk level (safe/warn/block)"],
      decision: [type: :string, required: true, doc: "Decision made (approved/rejected/etc)"],
      matched_rule: [type: :string, doc: "Name of the matched policy rule"],
      session_id: [type: :string, doc: "Proxy session ID"],
      decided_by: [type: :string, doc: "Who made the decision"],
      reason: [type: :string, doc: "Decision reason"]
    ]

  alias Dingleberry.Audit.Log

  @impl true
  def run(params, _context) do
    attrs =
      params
      |> Map.take([:command, :source, :risk, :decision, :matched_rule, :session_id, :decided_by, :reason])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    case Log.create_entry(attrs) do
      {:ok, entry} -> {:ok, %{entry_id: entry.id}}
      {:error, changeset} -> {:error, changeset}
    end
  end
end
