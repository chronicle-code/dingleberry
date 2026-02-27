defmodule Dingleberry.Signals.CommandDecided do
  @moduledoc "Signal emitted when a human decision is made on an intercepted command."

  use Jido.Signal,
    type: "dingleberry.command.decided",
    default_source: "/dingleberry/approval",
    schema: [
      command: [type: :string, required: true, doc: "The intercepted command"],
      decision: [type: :string, required: true, doc: "Decision (approved/rejected/timed_out)"],
      decided_by: [type: :string, doc: "Who made the decision"],
      risk: [type: :string, doc: "Original risk classification"],
      matched_rule: [type: :string, doc: "Name of the matched policy rule"],
      session_id: [type: :string, doc: "Proxy session ID"]
    ]
end
