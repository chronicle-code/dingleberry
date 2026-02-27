defmodule Dingleberry.Actions.RejectRequest do
  @moduledoc "Jido Action: Rejects a pending approval request."

  use Jido.Action,
    name: "reject_request",
    description: "Rejects a pending command in the approval queue",
    category: "approval",
    tags: ["approval", "human-in-the-loop"],
    vsn: "1.0.0",
    schema: [
      request_id: [type: :string, required: true, doc: "The approval request ID"],
      decided_by: [type: :string, default: "human", doc: "Who made the decision"],
      reason: [type: :string, doc: "Reason for rejection"]
    ],
    output_schema: [
      decision: [type: :map, required: true, doc: "The rejection decision struct as a map"]
    ]

  alias Dingleberry.Approval.Queue

  @impl true
  def run(params, _context) do
    opts = [decided_by: params.decided_by]
    opts = if Map.get(params, :reason), do: Keyword.put(opts, :reason, params.reason), else: opts

    case Queue.reject(params.request_id, opts) do
      {:ok, decision} -> {:ok, %{decision: decision}}
      {:error, reason} -> {:error, reason}
    end
  end
end
