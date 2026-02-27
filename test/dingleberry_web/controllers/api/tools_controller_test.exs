defmodule DingleberryWeb.API.ToolsControllerTest do
  use DingleberryWeb.ConnCase

  describe "GET /api/v1/tools" do
    test "lists all 5 tool definitions", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tools")
      assert %{"tools" => tools} = json_response(conn, 200)
      assert length(tools) == 5

      names = Enum.map(tools, & &1["name"])
      assert "classify_command" in names
      assert "classify_tool_call" in names
      assert "approve_request" in names
      assert "reject_request" in names
      assert "record_audit" in names
    end

    test "tools are sorted by name", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tools")
      %{"tools" => tools} = json_response(conn, 200)
      names = Enum.map(tools, & &1["name"])
      assert names == Enum.sort(names)
    end

    test "each tool has name, description, and parameters_schema", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tools")
      %{"tools" => tools} = json_response(conn, 200)

      for tool <- tools do
        assert is_binary(tool["name"]), "tool should have a name"
        assert is_binary(tool["description"]), "tool should have a description"
        assert is_map(tool["parameters_schema"]), "tool should have parameters_schema"
        assert tool["parameters_schema"]["type"] == "object"
      end
    end
  end

  describe "GET /api/v1/tools/:name" do
    test "returns a single tool definition", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tools/classify_command")
      assert %{"tool" => tool} = json_response(conn, 200)
      assert tool["name"] == "classify_command"
      assert is_binary(tool["description"])
      assert is_map(tool["parameters_schema"])
    end

    test "returns 404 for unknown tool", %{conn: conn} do
      conn = get(conn, ~p"/api/v1/tools/nonexistent_tool")
      assert %{"error" => error} = json_response(conn, 404)
      assert error =~ "Unknown tool"
    end
  end

  describe "POST /api/v1/tools/:name/run" do
    test "executes classify_command tool successfully", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/tools/classify_command/run", %{
          "params" => %{"command" => "ls -la"}
        })

      assert %{"ok" => true, "result" => result} = json_response(conn, 200)
      assert result["command"] == "ls -la"
      assert result["risk"] == "safe"
    end

    test "executes record_audit tool successfully", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/tools/record_audit/run", %{
          "params" => %{
            "command" => "test_api_cmd",
            "risk" => "safe",
            "decision" => "auto_approved",
            "source" => "api_test"
          }
        })

      assert %{"ok" => true, "result" => result} = json_response(conn, 200)
      assert is_integer(result["entry_id"])
    end

    test "returns 404 for unknown tool", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/tools/nonexistent/run", %{"params" => %{}})
      assert %{"error" => _} = json_response(conn, 404)
    end

    test "returns 422 when params are invalid", %{conn: conn} do
      conn =
        post(conn, ~p"/api/v1/tools/record_audit/run", %{
          "params" => %{"command" => "test"}
        })

      assert %{"ok" => false, "error" => _} = json_response(conn, 422)
    end

    test "uses default empty params when none provided", %{conn: conn} do
      conn = post(conn, ~p"/api/v1/tools/classify_command/run", %{})
      # Should fail validation since command is required
      assert %{"ok" => false, "error" => _} = json_response(conn, 422)
    end
  end
end
