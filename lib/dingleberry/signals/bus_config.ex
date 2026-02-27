defmodule Dingleberry.Signals.BusConfig do
  @moduledoc """
  Configuration for the Dingleberry signal bus.

  Sets up a Jido.Signal.Bus with middleware for risk classification
  and audit logging. The bus is the central nervous system for all
  Dingleberry events — every interception, classification, and
  decision flows through it as a CloudEvents-compliant signal.
  """

  alias Jido.Signal.Bus

  @bus_name :dingleberry_signal_bus

  def bus_name, do: @bus_name

  @doc "Returns the child_spec for the signal bus supervisor tree entry"
  def child_spec(_opts \\ []) do
    Bus.child_spec(
      name: @bus_name,
      journal_adapter: Jido.Signal.Journal.Adapters.ETS,
      journal_adapter_opts: [],
      max_log_size: 100_000,
      middleware: [
        {Dingleberry.Signals.Middleware.RiskClassifier, [log_classifications: true]},
        {Dingleberry.Signals.Middleware.AuditLogger, [log_safe: false]},
        {Jido.Signal.Bus.Middleware.Logger, [level: :debug, log_dispatch: false]}
      ]
    )
  end

  @doc "Publish signals to the Dingleberry bus"
  def publish(signals) when is_list(signals) do
    Bus.publish(@bus_name, signals)
  end

  def publish(signal) do
    Bus.publish(@bus_name, [signal])
  end

  @doc "Subscribe to signals matching a path pattern"
  def subscribe(path, opts \\ []) do
    dispatch = Keyword.get(opts, :dispatch, {:pid, target: self(), delivery_mode: :async})
    Bus.subscribe(@bus_name, path, dispatch: dispatch)
  end
end
