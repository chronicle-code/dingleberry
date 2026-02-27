defmodule Dingleberry.Shell.ParserTest do
  use ExUnit.Case, async: true

  alias Dingleberry.Shell.Parser

  describe "parse/1" do
    test "parses simple command" do
      {:ok, result} = Parser.parse("ls -la")
      assert result.executable == "ls"
      assert result.args == ["-la"]
    end

    test "parses command with quoted arguments" do
      {:ok, result} = Parser.parse(~s(grep "hello world" file.txt))
      assert result.executable == "grep"
      assert result.args == ["hello world", "file.txt"]
    end

    test "returns error for empty command" do
      assert {:error, :empty_command} = Parser.parse("")
      assert {:error, :empty_command} = Parser.parse("   ")
    end
  end

  describe "executable_name/1" do
    test "extracts base executable" do
      assert Parser.executable_name("ls -la") == "ls"
      assert Parser.executable_name("/usr/bin/git status") == "git"
    end

    test "handles sudo" do
      assert Parser.executable_name("sudo rm -rf /tmp/test") == "rm"
    end
  end

  describe "piped?/1" do
    test "detects pipes" do
      assert Parser.piped?("cat file | grep pattern")
      refute Parser.piped?("cat file")
    end
  end

  describe "chained?/1" do
    test "detects command chains" do
      assert Parser.chained?("cd /tmp && rm -rf build")
      assert Parser.chained?("echo hello; echo world")
      refute Parser.chained?("echo hello")
    end
  end

  describe "split_pipes/1" do
    test "splits piped commands" do
      parts = Parser.split_pipes("cat file | grep pattern | wc -l")
      assert parts == ["cat file", "grep pattern", "wc -l"]
    end
  end
end
