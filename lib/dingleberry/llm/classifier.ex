defmodule Dingleberry.LLM.Classifier do
  @moduledoc """
  LLM-powered command classifier using Jido.AI.generate_object/3.

  Classifies commands that don't match any regex rule by asking an LLM
  to analyze intent. Results are cached in ETS for configurable TTL.
  """

  require Logger

  alias Dingleberry.LLM.Config

  @cache_table :dingleberry_llm_cache

  @classification_schema %{
    "type" => "object",
    "properties" => %{
      "risk" => %{"type" => "string", "enum" => ["safe", "warn", "block"]},
      "reason" => %{"type" => "string"},
      "confidence" => %{"type" => "number", "minimum" => 0.0, "maximum" => 1.0}
    },
    "required" => ["risk", "reason", "confidence"]
  }

  @doc "Initialize the ETS cache table. Call from Application.start."
  def init_cache do
    if :ets.whereis(@cache_table) == :undefined do
      :ets.new(@cache_table, [:set, :public, :named_table])
    end
    :ok
  end

  @doc """
  Classify a command using the LLM.

  Returns `{:ok, %{risk: atom, reason: String.t(), confidence: float, model: String.t(), latency_ms: integer, cached: boolean}}`
  or `{:error, reason}`.

  Options:
  - `:policies` — list of natural language policy strings
  - `:model` — override model (default from config)
  - `:timeout_ms` — override timeout (default from config)
  - `:temperature` — override temperature (default from config)
  - `:classifier_fn` — override the LLM call for testing (fn command, system_prompt, opts -> {:ok, map} | {:error, reason})
  """
  def classify(command, opts \\ []) do
    config = Config.get()
    cache_key = cache_key(command)

    case check_cache(cache_key, config.cache_ttl_seconds) do
      {:hit, cached_result} ->
        {:ok, Map.put(cached_result, :cached, true)}

      :miss ->
        classify_with_llm(command, config, opts)
    end
  end

  @doc "Clear the classification cache."
  def clear_cache do
    if :ets.whereis(@cache_table) != :undefined do
      :ets.delete_all_objects(@cache_table)
    end
    :ok
  end

  # Private

  defp classify_with_llm(command, config, opts) do
    policies = Keyword.get(opts, :policies, [])
    model = Keyword.get(opts, :model, config.model)
    timeout_ms = Keyword.get(opts, :timeout_ms, config.timeout_ms)
    temperature = Keyword.get(opts, :temperature, config.temperature)
    classifier_fn = Keyword.get(opts, :classifier_fn)

    system_prompt = build_system_prompt(policies)
    start_time = System.monotonic_time(:millisecond)

    result = if classifier_fn do
      classifier_fn.(command, system_prompt, [model: model, temperature: temperature])
    else
      call_llm(command, system_prompt, model: model, temperature: temperature, timeout_ms: timeout_ms)
    end

    latency_ms = System.monotonic_time(:millisecond) - start_time

    case result do
      {:ok, %{"risk" => risk, "reason" => reason, "confidence" => confidence}} ->
        classification = %{
          risk: String.to_existing_atom(risk),
          reason: reason,
          confidence: confidence / 1,
          model: model,
          latency_ms: latency_ms,
          cached: false
        }
        cache_result(cache_key(command), classification)
        {:ok, classification}

      {:ok, %{risk: risk, reason: reason, confidence: confidence}} when is_atom(risk) ->
        classification = %{
          risk: risk,
          reason: reason,
          confidence: confidence / 1,
          model: model,
          latency_ms: latency_ms,
          cached: false
        }
        cache_result(cache_key(command), classification)
        {:ok, classification}

      {:error, :timeout} ->
        Logger.warning("LLM classifier timeout after #{timeout_ms}ms for command: #{inspect(command)}")
        {:ok, fallback_result(config, model, latency_ms, "LLM timeout")}

      {:error, reason} ->
        Logger.warning("LLM classifier error for command #{inspect(command)}: #{inspect(reason)}")
        {:ok, fallback_result(config, model, latency_ms, "LLM error: #{inspect(reason)}")}
    end
  end

  defp call_llm(command, system_prompt, opts) do
    model = Keyword.fetch!(opts, :model)
    temperature = Keyword.get(opts, :temperature, 0.0)
    timeout_ms = Keyword.get(opts, :timeout_ms, 3000)

    task = Task.async(fn ->
      Jido.AI.generate_object(
        "Classify this command:\n```\n#{command}\n```",
        @classification_schema,
        model: model,
        system_prompt: system_prompt,
        temperature: temperature,
        max_tokens: 256
      )
    end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task) do
      {:ok, result} -> result
      nil -> {:error, :timeout}
    end
  end

  defp build_system_prompt(policies) do
    base = """
    You are a security classifier for an AI agent sandbox.
    Your job is to classify shell commands and tool calls into exactly one of three categories:

    - **safe**: Read-only, non-destructive, no side effects. Examples: ls, cat, grep, git status, echo, pwd.
    - **warn**: Potentially destructive or modifying, needs human review. Examples: rm, git push, file writes, network requests to unknown hosts, package installs, permission changes.
    - **block**: Catastrophically destructive, should never execute. Examples: rm -rf /, DROP DATABASE, fork bombs, dd if=/dev/zero, format commands, recursive deletion of system directories.

    When in doubt, classify as **warn** (hold for human review). It is always safer to warn than to allow.

    Respond with a JSON object containing exactly these fields:
    - "risk": one of "safe", "warn", or "block"
    - "reason": a brief explanation of why you classified it this way
    - "confidence": a number from 0.0 to 1.0 indicating how confident you are
    """

    if policies != [] do
      policy_text = policies |> Enum.map_join("\n", &("- #{&1}"))
      base <> "\nThe user has defined these additional policies:\n#{policy_text}\n"
    else
      base
    end
  end

  defp fallback_result(config, model, latency_ms, reason) do
    %{
      risk: config.fallback_action,
      reason: reason,
      confidence: 0.0,
      model: model,
      latency_ms: latency_ms,
      cached: false
    }
  end

  defp cache_key(command) do
    command |> String.trim() |> String.downcase()
  end

  defp check_cache(key, ttl_seconds) do
    if :ets.whereis(@cache_table) != :undefined do
      case :ets.lookup(@cache_table, key) do
        [{^key, result, inserted_at}] ->
          age = System.monotonic_time(:second) - inserted_at
          if age < ttl_seconds do
            {:hit, result}
          else
            :ets.delete(@cache_table, key)
            :miss
          end
        [] ->
          :miss
      end
    else
      :miss
    end
  end

  defp cache_result(key, result) do
    if :ets.whereis(@cache_table) != :undefined do
      :ets.insert(@cache_table, {key, result, System.monotonic_time(:second)})
    end
  end
end
