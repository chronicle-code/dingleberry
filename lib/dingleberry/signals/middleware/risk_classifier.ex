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

  @impl true
  def before_dispatch(signal, _subscriber, _context, state) do
    if signal.type == "dingleberry.command.intercepted" do
      risk = get_in(signal.data, [:risk]) || get_in(signal.data, ["risk"])

      if risk do
        risk_metadata = %{
          risk_level: risk,
          risk_score: risk_score(risk),
          classified_at: DateTime.utc_now() |> DateTime.to_iso8601()
        }

        enriched = Map.update(signal, :extensions, %{"risk.metadata" => risk_metadata}, fn exts ->
          Map.put(exts || %{}, "risk.metadata", risk_metadata)
        end)

        {:cont, enriched, state}
      else
        {:cont, signal, state}
      end
    else
      {:cont, signal, state}
    end
  end

  defp risk_score(:block), do: 1.0
  defp risk_score("block"), do: 1.0
  defp risk_score(:warn), do: 0.5
  defp risk_score("warn"), do: 0.5
  defp risk_score(_), do: 0.0

  defp enrich_with_risk(signal, state, _context) do
    risk = get_in(signal.data, [:risk]) || get_in(signal.data, ["risk"])

    if state.log_classifications && risk do
      Logger.info("RiskClassifier: #{risk} — #{inspect(signal.data[:command] || signal.data["command"])}")
    end

    signal
  end
end
