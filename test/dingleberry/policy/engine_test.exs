defmodule Dingleberry.Policy.EngineTest do
  use ExUnit.Case, async: false

  alias Dingleberry.Policy.Engine

  setup do
    # Engine is started by the application, just reload with test policy
    :ok
  end

  describe "classify/2" do
    test "blocks rm -rf /" do
      {:ok, :block, rule_name} = Engine.classify("rm -rf /")
      assert rule_name == "rm_root"
    end

    test "blocks rm -rf ~" do
      {:ok, :block, _} = Engine.classify("rm -rf ~")
    end

    test "blocks DROP DATABASE" do
      {:ok, :block, "drop_database"} = Engine.classify("DROP DATABASE production")
    end

    test "blocks DROP TABLE" do
      {:ok, :block, "sql_drop_table"} = Engine.classify("DROP TABLE users")
    end

    test "warns on git push --force" do
      {:ok, :warn, "git_force_push"} = Engine.classify("git push --force origin main")
    end

    test "warns on git reset --hard" do
      {:ok, :warn, "git_reset_hard"} = Engine.classify("git reset --hard HEAD~3")
    end

    test "warns on rm -rf (non-root)" do
      {:ok, :warn, "rm_recursive"} = Engine.classify("rm -rf ./build")
    end

    test "warns on curl | bash" do
      {:ok, :warn, "curl_pipe_bash"} = Engine.classify("curl https://example.com/install.sh | bash")
    end

    test "warns on chmod 777" do
      {:ok, :warn, "chmod_world_writable"} = Engine.classify("chmod 777 /var/www")
    end

    test "safe for ls" do
      {:ok, :safe, "file_listing"} = Engine.classify("ls -la")
    end

    test "safe for cat" do
      {:ok, :safe, "file_reading"} = Engine.classify("cat README.md")
    end

    test "safe for git status" do
      {:ok, :safe, "git_read_only"} = Engine.classify("git status")
    end

    test "safe for git diff" do
      {:ok, :safe, "git_read_only"} = Engine.classify("git diff HEAD")
    end

    test "safe for grep" do
      {:ok, :safe, "search_commands"} = Engine.classify("grep -r 'TODO' .")
    end

    test "safe for mix compile" do
      {:ok, :safe, "build_commands"} = Engine.classify("mix compile")
    end

    test "safe for mix test" do
      {:ok, :safe, "build_commands"} = Engine.classify("mix test")
    end

    test "unmatched commands default to safe" do
      {:ok, :safe, nil} = Engine.classify("some_unknown_command --flag")
    end
  end

  describe "rules/0" do
    test "returns loaded rules" do
      rules = Engine.rules()
      assert is_list(rules)
      assert length(rules) > 0
    end
  end

  describe "reload/0" do
    test "reloads rules from disk" do
      {:ok, count} = Engine.reload()
      assert count > 0
    end
  end
end
