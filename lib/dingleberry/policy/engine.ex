defmodule Dingleberry.Policy.Engine do
  @moduledoc """
  GenServer that holds loaded policy rules and classifies commands.
  """

  use GenServer

  alias Dingleberry.Policy.{Loader, Rule}

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc "Classify a command string. Returns {:ok, :safe | :warn | :block, rule_name | nil}"
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
    {:ok, %{rules: [], policy_path: policy_path}, {:continue, :load_rules}}
  end

  @impl true
  def handle_continue(:load_rules, state) do
    rules = load_rules(state.policy_path)
    {:noreply, %{state | rules: rules}}
  end

  @impl true
  def handle_call({:classify, command, opts}, _from, state) do
    result = do_classify(command, state.rules, opts)
    {:reply, result, state}
  end

  def handle_call(:reload, _from, state) do
    rules = load_rules(state.policy_path)
    {:reply, {:ok, length(rules)}, %{state | rules: rules}}
  end

  def handle_call(:rules, _from, state) do
    {:reply, state.rules, state}
  end

  # Private

  defp do_classify(command, rules, opts) do
    # Check rules in priority order: block > warn > safe
    result =
      Enum.reduce_while([:block, :warn, :safe], {:ok, :safe, nil}, fn action, default ->
        case find_matching_rule(command, rules, action, opts) do
          nil -> {:cont, default}
          rule -> {:halt, {:ok, rule.action, rule.name}}
        end
      end)

    # Emit policy.matched signal through the Jido signal bus
    case result do
      {:ok, risk, rule_name} when rule_name != nil ->
        Dingleberry.Signals.emit_policy_matched(%{
          command: command,
          rule_name: rule_name,
          risk: to_string(risk),
          scope: to_string(Keyword.get(opts, :scope, :all))
        })

      _ ->
        :ok
    end

    result
  end

  defp find_matching_rule(command, rules, action, opts) do
    rules
    |> Enum.filter(&(&1.action == action))
    |> Enum.find(&Rule.matches?(&1, command, opts))
  end

  defp load_rules(policy_path) do
    case Loader.load_file(policy_path) do
      {:ok, rules} ->
        rules

      {:error, reason} ->
        require Logger
        Logger.warning("Failed to load policy from #{policy_path}: #{inspect(reason)}")
        []
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
