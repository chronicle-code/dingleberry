defmodule Dingleberry.Signals.ExtensionsTest do
  use ExUnit.Case

  alias Dingleberry.Signals.Extensions.{RiskMetadata, AuditContext, DecisionContext}

  describe "RiskMetadata extension" do
    test "has correct namespace" do
      assert RiskMetadata.namespace() == "risk.metadata"
    end

    test "has schema with risk_level, risk_score, classified_at" do
      schema = RiskMetadata.schema()
      assert Keyword.has_key?(schema, :risk_level)
      assert Keyword.has_key?(schema, :risk_score)
      assert Keyword.has_key?(schema, :classified_at)
    end

    test "validates data with required risk_level" do
      assert {:ok, validated} =
               RiskMetadata.validate_data(%{
                 risk_level: :warn,
                 risk_score: 0.5,
                 classified_at: "2026-02-27T00:00:00Z"
               })

      assert validated.risk_level == :warn
      assert validated.risk_score == 0.5
    end

    test "rejects data missing required risk_level" do
      assert {:error, _reason} =
               RiskMetadata.validate_data(%{risk_score: 0.5})
    end

    test "accepts data with only required fields" do
      assert {:ok, validated} = RiskMetadata.validate_data(%{risk_level: :safe})
      assert validated.risk_level == :safe
    end
  end

  describe "AuditContext extension" do
    test "has correct namespace" do
      assert AuditContext.namespace() == "audit.context"
    end

    test "has schema with session_id, hostname, request_id" do
      schema = AuditContext.schema()
      assert Keyword.has_key?(schema, :session_id)
      assert Keyword.has_key?(schema, :hostname)
      assert Keyword.has_key?(schema, :request_id)
    end

    test "validates data with all fields" do
      assert {:ok, validated} =
               AuditContext.validate_data(%{
                 session_id: "sess-123",
                 hostname: "localhost",
                 request_id: "req-456"
               })

      assert validated.session_id == "sess-123"
      assert validated.hostname == "localhost"
    end

    test "validates data with no fields (all optional)" do
      assert {:ok, _validated} = AuditContext.validate_data(%{})
    end
  end

  describe "DecisionContext extension" do
    test "has correct namespace" do
      assert DecisionContext.namespace() == "decision.context"
    end

    test "has schema with decision_time_ms, approver_id" do
      schema = DecisionContext.schema()
      assert Keyword.has_key?(schema, :decision_time_ms)
      assert Keyword.has_key?(schema, :approver_id)
    end

    test "validates data with all fields" do
      assert {:ok, validated} =
               DecisionContext.validate_data(%{
                 decision_time_ms: 1500,
                 approver_id: "user-789"
               })

      assert validated.decision_time_ms == 1500
      assert validated.approver_id == "user-789"
    end

    test "validates data with no fields (all optional)" do
      assert {:ok, _validated} = DecisionContext.validate_data(%{})
    end

    test "rejects negative decision_time_ms" do
      assert {:error, _reason} =
               DecisionContext.validate_data(%{decision_time_ms: -1})
    end
  end

  describe "extension callbacks" do
    test "to_attrs/1 returns data unchanged by default" do
      data = %{risk_level: :warn, risk_score: 0.5}
      assert RiskMetadata.to_attrs(data) == data
    end

    test "from_attrs/1 returns data unchanged by default" do
      attrs = %{session_id: "test", hostname: "local"}
      assert AuditContext.from_attrs(attrs) == attrs
    end
  end
end
