defmodule Dingleberry.Actions.RecordAudit do
  @moduledoc "Jido Action: Records an audit log entry."

  require Logger

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
    ],
    output_schema: [
      entry_id: [type: :integer, required: true, doc: "The ID of the created audit entry"]
    ],
    compensation: [enabled: true, max_retries: 2, timeout: 5000]

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

  @impl true
  def on_after_run({:ok, result} = success) do
    Logger.debug("RecordAudit: Successfully wrote audit entry ##{result.entry_id}")
    success
  end

  def on_after_run(error), do: error

  @impl true
  def on_error(failed_params, error, _context, _opts) do
    Logger.warning("RecordAudit: Failed to write audit entry for command=#{inspect(failed_params[:command])}, error=#{inspect(error)}")
    {:error, error}
  end
end
