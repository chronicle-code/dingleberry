defmodule Dingleberry.Policy.EngineLLMTest do
  use Dingleberry.DataCase

  alias Dingleberry.Policy.Engine

  describe "classify/2 — regex rules take priority" do
    test "known safe command returns safe without LLM" do
      {:ok, risk, rule_name} = Engine.classify("ls -la", scope: :shell)
      assert risk == :safe
      # Either matches a safe rule or returns nil (default safe)
      assert is_binary(rule_name) or is_nil(rule_name)
    end

    test "known block command returns block without LLM" do
      {:ok, :block, rule_name} = Engine.classify("rm -rf /", scope: :shell)
      assert is_binary(rule_name)
    end

    test "known warn command returns warn without LLM" do
      {:ok, :warn, rule_name} = Engine.classify("git push --force", scope: :shell)
      assert is_binary(rule_name)
    end
  end

  describe "classify/2 — LLM disabled (default)" do
    test "unmatched command returns safe when LLM disabled" do
      # A command that doesn't match any regex rule
      {:ok, :safe, nil} = Engine.classify("some_obscure_custom_command", scope: :shell)
    end
  end

  describe "reload/0" do
    test "reloads rules successfully" do
      {:ok, count} = Engine.reload()
      assert is_integer(count)
      assert count > 0
    end
  end
end
