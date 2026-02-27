defmodule Dingleberry.Actions.ApproveRequest do
  @moduledoc "Jido Action: Approves a pending approval request."

  use Jido.Action,
    name: "approve_request",
    description: "Approves a pending command in the approval queue",
    category: "approval",
    tags: ["approval", "human-in-the-loop"],
    vsn: "1.0.0",
    schema: [
      request_id: [type: :string, required: true, doc: "The approval request ID"],
      decided_by: [type: :string, default: "human", doc: "Who made the decision"]
    ],
    output_schema: [
      decision: [type: :map, required: true, doc: "The approval decision struct as a map"]
    ]

  alias Dingleberry.Approval.Queue

  @impl true
  def run(params, _context) do
    case Queue.approve(params.request_id, decided_by: params.decided_by) do
      {:ok, decision} -> {:ok, %{decision: decision}}
      {:error, reason} -> {:error, reason}
    end
  end
end
