defmodule Dingleberry.Signals.Extensions.LLMClassification do
  @moduledoc "Signal extension for LLM classification metadata."

  use Jido.Signal.Ext,
    namespace: "llm.classification",
    schema: [
      model: [type: :string, required: true, doc: "Model used for classification"],
      confidence: [type: :float, required: true, doc: "Classification confidence (0.0-1.0)"],
      reason: [type: :string, required: true, doc: "LLM's reasoning"],
      latency_ms: [type: :integer, doc: "Classification latency in milliseconds"],
      cached: [type: :boolean, doc: "Whether result was from cache"]
    ]
end
