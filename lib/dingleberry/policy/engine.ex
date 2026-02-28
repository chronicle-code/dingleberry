defmodule Dingleberry.Policy.Engine do
  @moduledoc """
  GenServer that holds loaded policy rules and classifies commands.
  """

  use GenServer

  require Logger

  alias Dingleberry.Policy.{Loader, Rule}
  alias Dingleberry.LLM

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Classify a command string.

  Returns `{:ok, :safe | :warn | :block, rule_name | nil}` for regex matches,
  or `{:ok, :safe | :warn | :block, "llm_classified", llm_analysis}` when the
  LLM tier classifies an unmatched command.
  """
  def classify(command, opts \\ []) do
    GenServer.call(__MODULE__, {:classify, command, opts})
  end

  @doc "Reload policy rules from disk"
  def reload do
    GenServer.call(__MODULE__, :reload)
  end

  @doc "Get all loaded rules"
  def rules do
    GenServer.call(__MODULE__, :rules)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    policy_path = Keyword.get(opts, :policy_path) || resolve_policy_path()
    {:ok, %{rules: [], llm_policies: [], policy_path: policy_path}, {:continue, :load_rules}}
  end

  @impl true
  def handle_continue(:load_rules, state) do
    {rules, llm_policies} = load_rules(state.policy_path)
    {:noreply, %{state | rules: rules, llm_policies: llm_policies}}
  end

  @impl true
  def handle_call({:classify, command, opts}, _from, state) do
    result = do_classify(command, state.rules, state.llm_policies, opts)
    {:reply, result, state}
  end

  def handle_call(:reload, _from, state) do
    {rules, llm_policies} = load_rules(state.policy_path)
    {:reply, {:ok, length(rules)}, %{state | rules: rules, llm_policies: llm_policies}}
  end

  def handle_call(:rules, _from, state) do
    {:reply, state.rules, state}
  end

  # Private

  defp do_classify(command, rules, llm_policies, opts) do
    # Check rules in priority order: block > warn > safe
    regex_result =
      Enum.reduce_while([:block, :warn, :safe], {:ok, :safe, nil}, fn action, default ->
        case find_matching_rule(command, rules, action, opts) do
          nil -> {:cont, default}
          rule -> {:halt, {:ok, rule.action, rule.name}}
        end
      end)

    case regex_result do
      {:ok, _risk, rule_name} = result when rule_name != nil ->
        # Regex rule matched — emit signal and return
        emit_policy_signal(command, rule_name, result, opts)
        result

      {:ok, :safe, nil} ->
        # No regex match — try LLM classification if enabled
        maybe_llm_classify(command, llm_policies, opts)
    end
  end

  defp maybe_llm_classify(command, llm_policies, _opts) do
    llm_config = LLM.Config.get()

    if llm_config.enabled do
      {:ok, %{risk: risk, confidence: confidence} = analysis} =
        LLM.Classifier.classify(command, policies: llm_policies)

      # If confidence is below threshold, escalate to :warn
      final_risk =
        if confidence < llm_config.confidence_threshold and risk == :safe do
          :warn
        else
          risk
        end

      # Emit LLM classified signal
      Dingleberry.Signals.emit_llm_classified(%{
        command: command,
        risk: to_string(final_risk),
        reason: analysis.reason,
        confidence: analysis.confidence,
        model: analysis.model,
        latency_ms: analysis.latency_ms,
        cached: analysis[:cached] || false
      })

      {:ok, final_risk, "llm_classified", analysis}
    else
      {:ok, :safe, nil}
    end
  end

  defp emit_policy_signal(command, rule_name, {:ok, risk, _}, opts) do
    Dingleberry.Signals.emit_policy_matched(%{
      command: command,
      rule_name: rule_name,
      risk: to_string(risk),
      scope: to_string(Keyword.get(opts, :scope, :all))
    })
  end

  defp find_matching_rule(command, rules, action, opts) do
    rules
    |> Enum.filter(&(&1.action == action))
    |> Enum.find(&Rule.matches?(&1, command, opts))
  end

  defp load_rules(policy_path) do
    case Loader.load_file(policy_path) do
      {:ok, rules, llm_policies} ->
        {rules, llm_policies}

      {:error, reason} ->
        Logger.warning("Failed to load policy from #{policy_path}: #{inspect(reason)}")
        {[], []}
    end
  end

  defp resolve_policy_path do
    user_policy = Dingleberry.Config.default_policy_file()

    if File.exists?(user_policy) do
      user_policy
    else
      Application.app_dir(:dingleberry, "priv/policies/default.yml")
    end
  end
end
