defmodule Dingleberry.Actions.ClassifyCommandTest do
  use ExUnit.Case

  alias Dingleberry.Actions.ClassifyCommand

  describe "Jido.Action run/2 callback" do
    test "classifies a safe command" do
      {:ok, result} = ClassifyCommand.run(%{command: "ls -la", scope: :shell}, %{})
      assert result.risk == :safe
      assert result.command == "ls -la"
    end

    test "classifies a dangerous command as block" do
      {:ok, result} = ClassifyCommand.run(%{command: "rm -rf /", scope: :shell}, %{})
      assert result.risk == :block
      assert result.rule_name != nil
    end

    test "classifies a risky command as warn" do
      {:ok, result} = ClassifyCommand.run(%{command: "git push --force", scope: :shell}, %{})
      assert result.risk == :warn
      assert result.rule_name != nil
    end

    test "supports shell scope" do
      {:ok, result} = ClassifyCommand.run(%{command: "ls", scope: :shell}, %{})
      assert result.risk == :safe
    end

    test "returns command in result" do
      {:ok, result} = ClassifyCommand.run(%{command: "echo hello", scope: :shell}, %{})
      assert result.command == "echo hello"
    end
  end

  describe "action metadata" do
    test "has correct name" do
      assert ClassifyCommand.name() == "classify_command"
    end

    test "has correct category" do
      assert ClassifyCommand.category() == "policy"
    end

    test "has description" do
      assert is_binary(ClassifyCommand.description())
    end
  end
end
