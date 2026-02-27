defmodule Dingleberry.Signals do
  @moduledoc """
  Convenience functions for emitting Jido signals through the Dingleberry signal bus.

  All interceptions, classifications, and decisions flow through the bus as
  CloudEvents-compliant signals, processed by the middleware pipeline
  (RiskClassifier -> AuditLogger -> Logger).
  """

  alias Dingleberry.Signals.{BusConfig, CommandIntercepted, CommandDecided, PolicyMatched}

  require Logger

  @doc "Emit a command.intercepted signal when a command is caught by the proxy or shell."
  def emit_intercepted(attrs) do
    case CommandIntercepted.new(normalize(attrs)) do
      {:ok, signal} ->
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

  defp normalize(attrs) when is_map(attrs), do: attrs
  defp normalize(attrs) when is_list(attrs), do: Map.new(attrs)
end
