defmodule Dingleberry.Actions.JidoFeaturesTest do
  use Dingleberry.DataCase

  alias Dingleberry.Actions.{
    ClassifyCommand,
    ClassifyToolCall,
    ApproveRequest,
    RejectRequest,
    RecordAudit
  }

  describe "output_schema/0" do
    test "ClassifyCommand has output_schema with risk, rule_name, command" do
      schema = ClassifyCommand.output_schema()
      assert Keyword.has_key?(schema, :risk)
      assert Keyword.has_key?(schema, :rule_name)
      assert Keyword.has_key?(schema, :command)
      assert schema[:risk][:required] == true
      assert schema[:command][:required] == true
    end

    test "ClassifyToolCall has output_schema with risk, rule_name, description" do
      schema = ClassifyToolCall.output_schema()
      assert Keyword.has_key?(schema, :risk)
      assert Keyword.has_key?(schema, :rule_name)
      assert Keyword.has_key?(schema, :description)
      assert schema[:risk][:required] == true
      assert schema[:description][:required] == true
    end

    test "ApproveRequest has output_schema with decision" do
      schema = ApproveRequest.output_schema()
      assert Keyword.has_key?(schema, :decision)
      assert schema[:decision][:required] == true
      assert schema[:decision][:type] == :map
    end

    test "RejectRequest has output_schema with decision" do
      schema = RejectRequest.output_schema()
      assert Keyword.has_key?(schema, :decision)
      assert schema[:decision][:required] == true
    end

    test "RecordAudit has output_schema with entry_id" do
      schema = RecordAudit.output_schema()
      assert Keyword.has_key?(schema, :entry_id)
      assert schema[:entry_id][:required] == true
      assert schema[:entry_id][:type] == :integer
    end

    test "all actions have non-empty output_schema" do
      for module <- [ClassifyCommand, ClassifyToolCall, ApproveRequest, RejectRequest, RecordAudit] do
        schema = module.output_schema()
        assert is_list(schema) and length(schema) > 0,
               "#{inspect(module)} should have a non-empty output_schema"
      end
    end
  end

  describe "lifecycle hooks" do
    test "ClassifyCommand.on_before_validate_params/1 trims command whitespace" do
      {:ok, result} = ClassifyCommand.on_before_validate_params(%{command: "  ls -la  ", scope: :shell})
      assert result.command == "ls -la"
    end

    test "ClassifyCommand.on_before_validate_params/1 handles non-string command" do
      {:ok, result} = ClassifyCommand.on_before_validate_params(%{scope: :shell})
      refute Map.has_key?(result, :command)
    end

    test "RecordAudit.on_after_run/1 passes through success" do
      success = {:ok, %{entry_id: 42}}
      assert RecordAudit.on_after_run(success) == success
    end

    test "RecordAudit.on_after_run/1 passes through error" do
      error = {:error, :some_error}
      assert RecordAudit.on_after_run(error) == error
    end

    test "RecordAudit.on_error/4 returns error tuple" do
      result = RecordAudit.on_error(%{command: "test"}, :db_error, %{}, [])
      assert {:error, :db_error} = result
    end
  end

  describe "to_tool/0" do
    test "ClassifyCommand generates a valid tool definition" do
      tool = ClassifyCommand.to_tool()
      assert tool.name == "classify_command"
      assert is_binary(tool.description)
      assert is_function(tool.function, 2)
      assert is_map(tool.parameters_schema)
      assert tool.parameters_schema["type"] == "object"
      assert Map.has_key?(tool.parameters_schema["properties"], "command")
    end

    test "ClassifyToolCall generates a valid tool definition" do
      tool = ClassifyToolCall.to_tool()
      assert tool.name == "classify_tool_call"
      assert Map.has_key?(tool.parameters_schema["properties"], "name")
    end

    test "ApproveRequest generates a valid tool definition" do
      tool = ApproveRequest.to_tool()
      assert tool.name == "approve_request"
      assert Map.has_key?(tool.parameters_schema["properties"], "request_id")
    end

    test "RejectRequest generates a valid tool definition" do
      tool = RejectRequest.to_tool()
      assert tool.name == "reject_request"
      assert Map.has_key?(tool.parameters_schema["properties"], "request_id")
    end

    test "RecordAudit generates a valid tool definition" do
      tool = RecordAudit.to_tool()
      assert tool.name == "record_audit"
      assert Map.has_key?(tool.parameters_schema["properties"], "command")
      assert Map.has_key?(tool.parameters_schema["properties"], "risk")
    end

    test "all tools have required fields in schema" do
      for module <- [ClassifyCommand, ClassifyToolCall, ApproveRequest, RejectRequest, RecordAudit] do
        tool = module.to_tool()
        assert is_list(tool.parameters_schema["required"]),
               "#{inspect(module)}.to_tool() should list required params"
      end
    end
  end

  describe "Jido.Exec.run/3 integration" do
    test "executes ClassifyCommand via Exec with full validation" do
      {:ok, result} = Jido.Exec.run(ClassifyCommand, %{command: "ls -la"}, %{})
      assert result.risk == :safe
      assert result.command == "ls -la"
    end

    test "executes ClassifyCommand with whitespace-trimmed command" do
      {:ok, result} = Jido.Exec.run(ClassifyCommand, %{command: "  git status  "}, %{})
      assert result.command == "git status"
      assert result.risk == :safe
    end

    test "Exec validates output schema on ClassifyCommand" do
      # Running through Exec applies output_schema validation
      {:ok, result} = Jido.Exec.run(ClassifyCommand, %{command: "rm -rf /"}, %{})
      assert is_atom(result.risk)
      assert is_binary(result.command)
    end

    test "executes RecordAudit via Exec" do
      # timeout: 0 avoids spawning a Task, keeping DB sandbox ownership
      {:ok, result} =
        Jido.Exec.run(RecordAudit, %{
          command: "test_exec_cmd",
          risk: "safe",
          decision: "auto_approved",
          source: "test"
        }, %{}, timeout: 0)

      assert is_integer(result.entry_id)
    end
  end

  describe "validate_params/1" do
    test "ClassifyCommand validates required command field" do
      assert {:error, _} = ClassifyCommand.validate_params(%{})
    end

    test "ClassifyCommand accepts valid params" do
      assert {:ok, params} = ClassifyCommand.validate_params(%{command: "ls", scope: :shell})
      assert params.command == "ls"
    end

    test "RecordAudit validates required fields" do
      assert {:error, _} = RecordAudit.validate_params(%{command: "test"})
    end

    test "RecordAudit accepts valid params" do
      assert {:ok, _} =
               RecordAudit.validate_params(%{
                 command: "test",
                 risk: "safe",
                 decision: "approved"
               })
    end
  end

  describe "validate_output/1" do
    test "ClassifyCommand validates output with required fields" do
      assert {:ok, _} =
               ClassifyCommand.validate_output(%{risk: :safe, command: "ls", rule_name: "safe_cmd"})
    end

    test "ClassifyCommand rejects output missing required field" do
      assert {:error, _} = ClassifyCommand.validate_output(%{rule_name: "test"})
    end

    test "RecordAudit validates output" do
      assert {:ok, _} = RecordAudit.validate_output(%{entry_id: 1})
    end

    test "RecordAudit rejects output missing entry_id" do
      assert {:error, _} = RecordAudit.validate_output(%{})
    end
  end
end
