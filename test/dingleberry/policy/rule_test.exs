defmodule Dingleberry.Policy.RuleTest do
  use ExUnit.Case, async: true

  alias Dingleberry.Policy.Rule

  describe "from_map/1" do
    test "builds rule from YAML map" do
      map = %{
        "name" => "test_rule",
        "description" => "Test description",
        "action" => "warn",
        "patterns" => ["rm\\s+-rf"],
        "scope" => "shell"
      }

      rule = Rule.from_map(map)
      assert rule.name == "test_rule"
      assert rule.action == :warn
      assert rule.scope == :shell
      assert length(rule.compiled_patterns) == 1
    end

    test "defaults scope to :all" do
      map = %{
        "name" => "test",
        "action" => "block",
        "patterns" => ["bad"]
      }

      rule = Rule.from_map(map)
      assert rule.scope == :all
    end
  end

  describe "matches?/3" do
    test "matches command against pattern" do
      rule =
        Rule.from_map(%{
          "name" => "test",
          "action" => "warn",
          "patterns" => ["rm\\s+-rf"]
        })

      assert Rule.matches?(rule, "rm -rf ./build")
      refute Rule.matches?(rule, "ls -la")
    end

    test "case insensitive matching" do
      rule =
        Rule.from_map(%{
          "name" => "test",
          "action" => "block",
          "patterns" => ["DROP\\s+TABLE"]
        })

      assert Rule.matches?(rule, "drop table users")
      assert Rule.matches?(rule, "DROP TABLE users")
    end

    test "respects scope" do
      rule =
        Rule.from_map(%{
          "name" => "test",
          "action" => "warn",
          "patterns" => ["write_file"],
          "scope" => "mcp"
        })

      assert Rule.matches?(rule, "write_file", scope: :mcp)
      refute Rule.matches?(rule, "write_file", scope: :shell)
      assert Rule.matches?(rule, "write_file", scope: :all)
    end
  end
end
