defmodule Dingleberry.Signals.LLMClassifiedTest do
  use ExUnit.Case

  alias Dingleberry.Signals.LLMClassified
  alias Dingleberry.Signals.Extensions.LLMClassification

  describe "LLMClassified signal" do
    test "creates signal with valid attrs" do
      assert {:ok, signal} =
               LLMClassified.new(%{
                 command: "find / -exec rm {} \\;",
                 risk: "block",
                 reason: "Recursive deletion across filesystem",
                 confidence: 0.95,
                 model: "ollama:llama3.2",
                 latency_ms: 200,
                 cached: false
               })

      assert signal.type == "dingleberry.llm.classified"
      assert signal.data.command == "find / -exec rm {} \\;"
      assert signal.data.risk == "block"
      assert signal.data.confidence == 0.95
    end

    test "creates signal without optional fields" do
      assert {:ok, signal} =
               LLMClassified.new(%{
                 command: "echo hello",
                 risk: "safe",
                 reason: "Read-only output",
                 confidence: 0.99,
                 model: "ollama:llama3.2"
               })

      assert signal.data.command == "echo hello"
    end
  end

  describe "LLMClassification extension" do
    test "has correct namespace" do
      assert LLMClassification.namespace() == "llm.classification"
    end

    test "has schema with required fields" do
      schema = LLMClassification.schema()
      assert Keyword.has_key?(schema, :model)
      assert Keyword.has_key?(schema, :confidence)
      assert Keyword.has_key?(schema, :reason)
      assert Keyword.has_key?(schema, :latency_ms)
      assert Keyword.has_key?(schema, :cached)
    end

    test "validates data with required fields" do
      assert {:ok, validated} =
               LLMClassification.validate_data(%{
                 model: "ollama:llama3.2",
                 confidence: 0.95,
                 reason: "Test classification"
               })

      assert validated.model == "ollama:llama3.2"
      assert validated.confidence == 0.95
    end

    test "rejects data missing required model" do
      assert {:error, _} =
               LLMClassification.validate_data(%{
                 confidence: 0.5,
                 reason: "test"
               })
    end

    test "rejects data missing required confidence" do
      assert {:error, _} =
               LLMClassification.validate_data(%{
                 model: "test",
                 reason: "test"
               })
    end

    test "accepts data with all fields including optional" do
      assert {:ok, validated} =
               LLMClassification.validate_data(%{
                 model: "ollama:llama3.2",
                 confidence: 0.88,
                 reason: "Risky network command",
                 latency_ms: 150,
                 cached: true
               })

      assert validated.latency_ms == 150
      assert validated.cached == true
    end
  end
end
