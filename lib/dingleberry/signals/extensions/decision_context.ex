defmodule Dingleberry.Signals.Extensions.DecisionContext do
  @moduledoc "Signal extension for decision-making context."

  use Jido.Signal.Ext,
    namespace: "decision.context",
    schema: [
      decision_time_ms: [type: :non_neg_integer, doc: "Time taken to make decision in milliseconds"],
      approver_id: [type: :string, doc: "Identifier of the person/system that made the decision"]
    ]
end
