defmodule Dingleberry.Signals.LLMClassified do
  @moduledoc "Signal emitted when a command is classified by the LLM security guard."

  use Jido.Signal,
    type: "dingleberry.llm.classified",
    default_source: "/dingleberry/llm_classifier",
    schema: [
      command: [type: :string, required: true, doc: "The classified command"],
      risk: [type: :string, required: true, doc: "Risk classification (safe/warn/block)"],
      reason: [type: :string, required: true, doc: "LLM's reasoning for classification"],
      confidence: [type: :float, required: true, doc: "Confidence score (0.0-1.0)"],
      model: [type: :string, required: true, doc: "Model that performed classification"],
      latency_ms: [type: :integer, doc: "Classification latency in milliseconds"],
      cached: [type: :boolean, doc: "Whether result was from cache"]
    ]
end
