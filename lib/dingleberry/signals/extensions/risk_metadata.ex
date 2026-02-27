defmodule Dingleberry.Signals.Extensions.RiskMetadata do
  @moduledoc "Signal extension for risk classification metadata."

  use Jido.Signal.Ext,
    namespace: "risk.metadata",
    schema: [
      risk_level: [type: :atom, required: true, doc: "Risk classification (:safe, :warn, :block)"],
      risk_score: [type: :float, doc: "Numeric risk score (0.0 to 1.0)"],
      classified_at: [type: :string, doc: "ISO 8601 timestamp of classification"]
    ]
end
