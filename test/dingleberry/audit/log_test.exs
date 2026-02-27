defmodule Dingleberry.Audit.LogTest do
  use Dingleberry.DataCase, async: false

  alias Dingleberry.Audit.Log

  describe "create_entry/1" do
    test "creates a valid entry" do
      {:ok, entry} =
        Log.create_entry(%{
          command: "rm -rf ./build",
          risk: "warn",
          decision: "approved",
          source: "shell",
          matched_rule: "rm_recursive"
        })

      assert entry.command == "rm -rf ./build"
      assert entry.risk == "warn"
      assert entry.decision == "approved"
    end

    test "rejects invalid risk" do
      {:error, changeset} =
        Log.create_entry(%{
          command: "test",
          risk: "invalid",
          decision: "approved"
        })

      assert changeset.errors[:risk]
    end
  end

  describe "list_entries/1" do
    test "returns entries ordered by most recent" do
      Log.create_entry(%{command: "first", risk: "safe", decision: "auto_approved"})
      Log.create_entry(%{command: "second", risk: "warn", decision: "approved"})

      entries = Log.list_entries()
      assert length(entries) == 2
      assert hd(entries).command == "second"
    end

    test "supports limit" do
      for i <- 1..5 do
        Log.create_entry(%{command: "cmd #{i}", risk: "safe", decision: "auto_approved"})
      end

      assert length(Log.list_entries(limit: 3)) == 3
    end
  end

  describe "count_by_risk/0" do
    test "groups counts by risk" do
      Log.create_entry(%{command: "a", risk: "safe", decision: "auto_approved"})
      Log.create_entry(%{command: "b", risk: "safe", decision: "auto_approved"})
      Log.create_entry(%{command: "c", risk: "warn", decision: "approved"})

      counts = Log.count_by_risk()
      assert counts["safe"] == 2
      assert counts["warn"] == 1
    end
  end

  describe "count/0" do
    test "returns total count" do
      assert Log.count() == 0
      Log.create_entry(%{command: "a", risk: "safe", decision: "auto_approved"})
      assert Log.count() == 1
    end
  end
end
