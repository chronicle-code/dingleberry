defmodule Dingleberry.Actions.RecordAuditTest do
  use Dingleberry.DataCase

  alias Dingleberry.Actions.RecordAudit

  describe "Jido.Action run/2 callback" do
    test "records an audit entry" do
      {:ok, result} =
        RecordAudit.run(
          %{
            command: "rm -rf /tmp/test",
            source: "shell",
            risk: "warn",
            decision: "approved",
            decided_by: "human",
            session_id: "test-session"
          },
          %{}
        )

      assert result.entry_id != nil
    end

    test "records with minimal required fields" do
      {:ok, result} =
        RecordAudit.run(
          %{
            command: "git push --force",
            risk: "warn",
            decision: "rejected"
          },
          %{}
        )

      assert result.entry_id != nil
    end
  end

  describe "action metadata" do
    test "has correct name" do
      assert RecordAudit.name() == "record_audit"
    end

    test "has correct category" do
      assert RecordAudit.category() == "audit"
    end
  end
end
