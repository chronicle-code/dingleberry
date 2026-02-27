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
    ]

  alias Dingleberry.Policy.Engine, as: PolicyEngine
  alias Dingleberry.MCP.Codec

  @impl true
  def run(params, _context) do
    tool_info = %{name: params.name, arguments: params.arguments}
    description = Codec.tool_call_description(tool_info)
    {:ok, risk, rule_name} = PolicyEngine.classify(description, scope: :mcp)
    {:ok, %{risk: risk, rule_name: rule_name, description: description}}
  end
end
