defmodule Dingleberry.MCP.CodecTest do
  use ExUnit.Case, async: true

  alias Dingleberry.MCP.Codec

  describe "decode/1" do
    test "decodes valid JSON-RPC message" do
      json = ~s({"jsonrpc": "2.0", "method": "tools/call", "id": 1, "params": {"name": "read_file", "arguments": {"path": "/tmp/test.txt"}}})
      assert {:ok, msg} = Codec.decode(json)
      assert msg["method"] == "tools/call"
      assert msg["params"]["name"] == "read_file"
    end

    test "returns error for invalid JSON" do
      assert {:error, _} = Codec.decode("not json")
    end
  end

  describe "tool_call?/1" do
    test "returns true for tools/call" do
      assert Codec.tool_call?(%{"method" => "tools/call", "params" => %{}})
    end

    test "returns false for other methods" do
      refute Codec.tool_call?(%{"method" => "tools/list"})
    end

    test "returns false for responses" do
      refute Codec.tool_call?(%{"result" => %{}})
    end
  end

  describe "extract_tool_info/1" do
    test "extracts tool name and arguments" do
      msg = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "write_file",
          "arguments" => %{"path" => "/tmp/test.txt", "content" => "hello"}
        }
      }

      assert {:ok, info} = Codec.extract_tool_info(msg)
      assert info.name == "write_file"
      assert info.arguments["path"] == "/tmp/test.txt"
    end

    test "returns error for non-tool-call" do
      assert {:error, :not_a_tool_call} = Codec.extract_tool_info(%{"method" => "tools/list"})
    end
  end

  describe "tool_call_description/1" do
    test "builds human-readable description" do
      info = %{name: "write_file", arguments: %{"path" => "/tmp/test.txt"}}
      desc = Codec.tool_call_description(info)
      assert desc =~ "write_file"
      assert desc =~ "/tmp/test.txt"
    end
  end

  describe "error_response/3" do
    test "builds valid JSON-RPC error" do
      resp = Codec.error_response(42, -32001, "Blocked")
      assert resp["jsonrpc"] == "2.0"
      assert resp["id"] == 42
      assert resp["error"]["code"] == -32001
      assert resp["error"]["message"] == "Blocked"
    end
  end

  describe "request?/1 and response?/1" do
    test "identifies requests" do
      assert Codec.request?(%{"method" => "tools/call"})
      refute Codec.request?(%{"result" => %{}})
    end

    test "identifies responses" do
      assert Codec.response?(%{"result" => %{}})
      assert Codec.response?(%{"error" => %{}})
      refute Codec.response?(%{"method" => "tools/call"})
    end
  end
end
