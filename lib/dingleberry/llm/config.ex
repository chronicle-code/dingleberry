defmodule Dingleberry.LLM.Config do
  @moduledoc "Configuration for LLM-powered security classification."

  defstruct [
    enabled: false,
    model: "ollama:llama3.2",
    temperature: 0.0,
    max_tokens: 256,
    timeout_ms: 3000,
    fallback_action: :warn,
    confidence_threshold: 0.7,
    cache_ttl_seconds: 300
  ]

  @type t :: %__MODULE__{
    enabled: boolean(),
    model: String.t(),
    temperature: float(),
    max_tokens: integer(),
    timeout_ms: integer(),
    fallback_action: :safe | :warn | :block,
    confidence_threshold: float(),
    cache_ttl_seconds: integer()
  }

  @doc "Load LLM classification config. Returns struct with defaults for missing fields."
  def get do
    config = Dingleberry.Config.load()
    from_map(config.llm_classification || %{})
  end

  @doc "Check if LLM classification is enabled."
  def enabled? do
    get().enabled
  end

  @doc "Build config from a map (used when parsing YAML)."
  def from_map(map) when is_map(map) do
    %__MODULE__{
      enabled: Map.get(map, "enabled", Map.get(map, :enabled, false)),
      model: Map.get(map, "model", Map.get(map, :model, "ollama:llama3.2")),
      temperature: Map.get(map, "temperature", Map.get(map, :temperature, 0.0)) |> to_float(),
      max_tokens: Map.get(map, "max_tokens", Map.get(map, :max_tokens, 256)),
      timeout_ms: Map.get(map, "timeout_ms", Map.get(map, :timeout_ms, 3000)),
      fallback_action: Map.get(map, "fallback_action", Map.get(map, :fallback_action, "warn")) |> to_atom_action(),
      confidence_threshold: Map.get(map, "confidence_threshold", Map.get(map, :confidence_threshold, 0.7)) |> to_float(),
      cache_ttl_seconds: Map.get(map, "cache_ttl_seconds", Map.get(map, :cache_ttl_seconds, 300))
    }
  end

  defp to_float(v) when is_float(v), do: v
  defp to_float(v) when is_integer(v), do: v / 1
  defp to_float(v) when is_binary(v), do: String.to_float(v)
  defp to_float(v), do: v

  defp to_atom_action(v) when is_atom(v), do: v
  defp to_atom_action("safe"), do: :safe
  defp to_atom_action("warn"), do: :warn
  defp to_atom_action("block"), do: :block
  defp to_atom_action(_), do: :warn
end
