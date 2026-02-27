defmodule Dingleberry.Signals.SignalTypesTest do
  use ExUnit.Case

  alias Dingleberry.Signals.{CommandIntercepted, CommandDecided, PolicyMatched}

  describe "CommandIntercepted signal" do
    test "creates a valid CloudEvents signal" do
      {:ok, signal} =
        CommandIntercepted.new(%{
          command: "rm -rf /tmp",
          source: "shell",
          risk: "warn",
          matched_rule: "destructive_rm",
          session_id: "test-123"
        })

      assert signal.type == "dingleberry.command.intercepted"
      assert signal.source == "/dingleberry/interceptor"
      assert signal.data.command == "rm -rf /tmp"
      assert signal.data.risk == "warn"
      assert signal.specversion == "1.0.2"
      assert signal.id != nil
    end

    test "requires command, source, and risk" do
      assert {:error, _} = CommandIntercepted.new(%{command: "ls"})
    end
  end

  describe "CommandDecided signal" do
    test "creates a valid CloudEvents signal" do
      {:ok, signal} =
        CommandDecided.new(%{
          command: "git push --force",
          decision: "approved",
          decided_by: "human",
          risk: "warn",
          matched_rule: "force_push"
        })

      assert signal.type == "dingleberry.command.decided"
      assert signal.source == "/dingleberry/approval"
      assert signal.data.decision == "approved"
      assert signal.data.decided_by == "human"
    end

    test "requires command and decision" do
      assert {:error, _} = CommandDecided.new(%{command: "ls"})
    end
  end

  describe "PolicyMatched signal" do
    test "creates a valid CloudEvents signal" do
      {:ok, signal} =
        PolicyMatched.new(%{
          command: "chmod 777 /etc/passwd",
          rule_name: "dangerous_chmod",
          risk: "warn",
          scope: "shell"
        })

      assert signal.type == "dingleberry.policy.matched"
      assert signal.source == "/dingleberry/policy"
      assert signal.data.rule_name == "dangerous_chmod"
    end

    test "requires command and risk" do
      assert {:error, _} = PolicyMatched.new(%{})
    end
  end
end
