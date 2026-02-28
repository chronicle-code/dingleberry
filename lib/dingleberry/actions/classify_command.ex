defmodule Dingleberry.Actions.ClassifyCommand do
  @moduledoc "Jido Action: Classifies a shell command against the policy engine."

  use Jido.Action,
    name: "classify_command",
    description: "Classifies a shell command against YAML policy rules",
    category: "policy",
    tags: ["classification", "shell", "policy"],
    vsn: "1.0.0",
    schema: [
      command: [type: :string, required: true, doc: "The shell command to classify"],
      scope: [type: :atom, default: :shell, doc: "Classification scope (:shell, :mcp, :all)"]
    ],
    output_schema: [
      risk: [type: :atom, required: true, doc: "Risk level (:safe, :warn, :block)"],
      rule_name: [type: :string, doc: "Name of the matched policy rule"],
      command: [type: :string, required: true, doc: "The original command"]
    ]

  alias Dingleberry.Policy.Engine, as: PolicyEngine

  @impl true
  def on_before_validate_params(params) do
    case Map.get(params, :command) do
      cmd when is_binary(cmd) -> {:ok, %{params | command: String.trim(cmd)}}
      _ -> {:ok, params}
    end
  end

  @impl true
  def run(params, _context) do
    case PolicyEngine.classify(params.command, scope: params.scope) do
      {:ok, risk, rule_name, _llm_analysis} ->
        {:ok, %{risk: risk, rule_name: rule_name, command: params.command}}

      {:ok, risk, rule_name} ->
        {:ok, %{risk: risk, rule_name: rule_name, command: params.command}}
    end
  end
end
