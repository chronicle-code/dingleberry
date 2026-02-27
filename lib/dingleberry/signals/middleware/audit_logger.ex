defmodule Dingleberry.Signals.Middleware.AuditLogger do
  @moduledoc """
  Jido Signal Bus middleware that logs all Dingleberry signals
  to the SQLite audit trail.
  """

  use Jido.Signal.Bus.Middleware

  require Logger

  alias Dingleberry.Audit.Log

  @impl true
  def init(opts) do
    {:ok, %{
      log_safe: Keyword.get(opts, :log_safe, false),
      signal_count: 0
    }}
  end

  @impl true
  def after_publish(signals, _context, state) do
    Enum.each(signals, fn signal ->
      maybe_record(signal, state)
    end)

    {:cont, signals, %{state | signal_count: state.signal_count + length(signals)}}
  end

  @impl true
  def after_dispatch(signal, subscriber, result, _context, state) do
    case result do
      :ok ->
        Logger.debug("AuditLogger: Dispatched #{signal.type} to subscriber #{inspect(subscriber.id)}")

      {:error, reason} ->
        Logger.warning("AuditLogger: Failed dispatching #{signal.type} to subscriber #{inspect(subscriber.id)}: #{inspect(reason)}")
    end

    {:cont, state}
  end

  defp maybe_record(%{type: "dingleberry.command.decided"} = signal, _state) do
    data = signal.data

    Log.create_entry(%{
      command: data[:command] || data["command"],
      source: data[:source] || data["source"] || "unknown",
      risk: data[:risk] || data["risk"] || "unknown",
      decision: data[:decision] || data["decision"],
      matched_rule: data[:matched_rule] || data["matched_rule"],
      session_id: data[:session_id] || data["session_id"],
      decided_by: data[:decided_by] || data["decided_by"]
    })
  end

  defp maybe_record(%{type: "dingleberry.command.intercepted"} = signal, state) do
    risk = signal.data[:risk] || signal.data["risk"]

    if risk != "safe" || state.log_safe do
      Logger.debug("AuditLogger: Intercepted #{risk} command")
    end
  end

  defp maybe_record(_signal, _state), do: :ok
end
