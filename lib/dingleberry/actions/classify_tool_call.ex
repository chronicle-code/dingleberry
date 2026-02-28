defmodule Dingleberry.Actions.ClassifyToolCall do
  @moduledoc "Jido Action: Classifies an MCP tool call against the policy engine."

  use Jido.Action,
    name: "classify_tool_call",
    description: "Classifies an MCP tool call against YAML policy rules",
    category: "policy",
    tags: ["classification", "mcp", "policy"],
    vsn: "1.0.0",
    schema: [
      name: [type: :string, required: true, doc: "The MCP tool name"],
      arguments: [type: :map, default: %{}, doc: "The tool call arguments"]
    ],
    output_schema: [
      risk: [type: :atom, required: true, doc: "Risk level (:safe, :warn, :block)"],
      rule_name: [type: :string, doc: "Name of the matched policy rule"],
      description: [type: :string, required: true, doc: "Human-readable tool call description"]
    ]

  alias Dingleberry.Policy.Engine, as: PolicyEngine
  alias Dingleberry.MCP.Codec

  @impl true
  def run(params, _context) do
    tool_info = %{name: params.name, arguments: params.arguments}
    description = Codec.tool_call_description(tool_info)

    case PolicyEngine.classify(description, scope: :mcp) do
      {:ok, risk, rule_name, _llm_analysis} ->
        {:ok, %{risk: risk, rule_name: rule_name, description: description}}

      {:ok, risk, rule_name} ->
        {:ok, %{risk: risk, rule_name: rule_name, description: description}}
    end
  end
end
