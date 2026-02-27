defmodule Dingleberry.Signals.Middleware.RiskClassifier do
  @moduledoc """
  Jido Signal Bus middleware that enriches intercepted command signals
  with risk classification metadata from the policy engine.
  """

  use Jido.Signal.Bus.Middleware

  require Logger

  @impl true
  def init(opts) do
    {:ok, %{
      log_classifications: Keyword.get(opts, :log_classifications, true)
    }}
  end

  @impl true
  def before_publish(signals, context, state) do
    enriched =
      Enum.map(signals, fn signal ->
        if signal.type == "dingleberry.command.intercepted" do
          enrich_with_risk(signal, state, context)
        else
          signal
        end
      end)

    {:cont, enriched, state}
  end

  defp enrich_with_risk(signal, state, _context) do
    risk = get_in(signal.data, [:risk]) || get_in(signal.data, ["risk"])

    if state.log_classifications && risk do
      Logger.info("RiskClassifier: #{risk} — #{inspect(signal.data[:command] || signal.data["command"])}")
    end

    signal
  end
end
