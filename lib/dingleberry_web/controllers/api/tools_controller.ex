defmodule DingleberryWeb.API.ToolsController do
  use DingleberryWeb, :controller

  alias Dingleberry.Actions.{ClassifyCommand, ClassifyToolCall, ApproveRequest, RejectRequest, RecordAudit}

  @actions %{
    "classify_command" => ClassifyCommand,
    "classify_tool_call" => ClassifyToolCall,
    "approve_request" => ApproveRequest,
    "reject_request" => RejectRequest,
    "record_audit" => RecordAudit
  }

  @doc "GET /api/v1/tools — List all actions as LLM tool definitions"
  def index(conn, _params) do
    tools =
      @actions
      |> Enum.map(fn {_name, module} -> module.to_tool() end)
      |> Enum.sort_by(& &1.name)

    json(conn, %{tools: Enum.map(tools, &serialize_tool/1)})
  end

  @doc "GET /api/v1/tools/:name — Get a single tool definition"
  def show(conn, %{"name" => name}) do
    case Map.get(@actions, name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Unknown tool: #{name}"})

      module ->
        tool = module.to_tool()
        json(conn, %{tool: serialize_tool(tool)})
    end
  end

  @doc "POST /api/v1/tools/:name/run — Execute a named tool via Jido.Exec"
  def run(conn, %{"name" => name} = params) do
    case Map.get(@actions, name) do
      nil ->
        conn
        |> put_status(:not_found)
        |> json(%{error: "Unknown tool: #{name}"})

      module ->
        tool_params =
          params
          |> Map.get("params", %{})
          |> Jido.Action.Tool.convert_params_using_schema(module.schema())

        case Jido.Exec.run(module, tool_params, %{}) do
          {:ok, result} ->
            json(conn, %{ok: true, result: result})

          {:error, error} when is_exception(error) ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{ok: false, error: Exception.message(error)})

          {:error, reason} ->
            conn
            |> put_status(:unprocessable_entity)
            |> json(%{ok: false, error: inspect(reason)})
        end
    end
  end

  defp serialize_tool(tool) do
    %{
      name: tool.name,
      description: tool.description,
      parameters_schema: tool.parameters_schema
    }
  end
end
