defmodule Dingleberry.Signals do
  @moduledoc """
  Convenience functions for emitting Jido signals through the Dingleberry signal bus.

  All interceptions, classifications, and decisions flow through the bus as
  CloudEvents-compliant signals, processed by the middleware pipeline
  (RiskClassifier -> AuditLogger -> Logger).
  """

  alias Dingleberry.Signals.{BusConfig, CommandIntercepted, CommandDecided, PolicyMatched, LLMClassified}

  require Logger

  @doc "Emit a command.intercepted signal when a command is caught by the proxy or shell."
  def emit_intercepted(attrs) do
    case CommandIntercepted.new(normalize(attrs)) do
      {:ok, signal} ->
        signal = attach_audit_context(signal, attrs)
        BusConfig.publish(signal)

      {:error, reason} ->
        Logger.warning("Failed to create intercepted signal: #{inspect(reason)}")
        :ok
    end
  end

  @doc "Emit a command.decided signal when a human (or auto-policy) makes a decision."
  def emit_decided(attrs) do
    case CommandDecided.new(normalize(attrs)) do
      {:ok, signal} ->
        signal = attach_audit_context(signal, attrs)
        BusConfig.publish(signal)

      {:error, reason} ->
        Logger.warning("Failed to create decided signal: #{inspect(reason)}")
        :ok
    end
  end

  @doc "Emit a policy.matched signal when a rule matches during classification."
  def emit_policy_matched(attrs) do
    case PolicyMatched.new(normalize(attrs)) do
      {:ok, signal} ->
        BusConfig.publish(signal)

      {:error, reason} ->
        Logger.warning("Failed to create policy_matched signal: #{inspect(reason)}")
        :ok
    end
  end

  @doc "Emit an llm.classified signal when the LLM classifier makes a decision."
  def emit_llm_classified(attrs) do
    case LLMClassified.new(normalize(attrs)) do
      {:ok, signal} ->
        signal = attach_audit_context(signal, attrs)
        signal = attach_llm_classification(signal, attrs)
        BusConfig.publish(signal)

      {:error, reason} ->
        Logger.warning("Failed to create llm_classified signal: #{inspect(reason)}")
        :ok
    end
  end

  defp attach_audit_context(signal, attrs) do
    attrs = normalize(attrs)
    audit_context = %{
      session_id: Map.get(attrs, :session_id) || Map.get(attrs, "session_id"),
      hostname: hostname(),
      request_id: Map.get(attrs, :request_id) || Map.get(attrs, "request_id") || generate_request_id()
    }

    Map.update(signal, :extensions, %{"audit.context" => audit_context}, fn exts ->
      Map.put(exts || %{}, "audit.context", audit_context)
    end)
  end

  defp hostname do
    {:ok, name} = :inet.gethostname()
    List.to_string(name)
  end

  defp generate_request_id do
    Base.hex_encode32(:crypto.strong_rand_bytes(8), case: :lower, padding: false)
  end

  defp attach_llm_classification(signal, attrs) do
    attrs = normalize(attrs)
    llm_meta = %{
      model: Map.get(attrs, :model) || Map.get(attrs, "model") || "unknown",
      confidence: Map.get(attrs, :confidence) || Map.get(attrs, "confidence") || 0.0,
      reason: Map.get(attrs, :reason) || Map.get(attrs, "reason") || "",
      latency_ms: Map.get(attrs, :latency_ms) || Map.get(attrs, "latency_ms"),
      cached: Map.get(attrs, :cached) || Map.get(attrs, "cached") || false
    }

    Map.update(signal, :extensions, %{"llm.classification" => llm_meta}, fn exts ->
      Map.put(exts || %{}, "llm.classification", llm_meta)
    end)
  end

  defp normalize(attrs) when is_map(attrs), do: attrs
  defp normalize(attrs) when is_list(attrs), do: Map.new(attrs)
end
