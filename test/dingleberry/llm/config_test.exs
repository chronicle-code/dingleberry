defmodule Dingleberry.LLM.ConfigTest do
  use ExUnit.Case

  alias Dingleberry.LLM.Config

  describe "from_map/1" do
    test "returns defaults for empty map" do
      config = Config.from_map(%{})
      assert config.enabled == false
      assert config.model == "ollama:llama3.2"
      assert config.temperature == 0.0
      assert config.max_tokens == 256
      assert config.timeout_ms == 3000
      assert config.fallback_action == :warn
      assert config.confidence_threshold == 0.7
      assert config.cache_ttl_seconds == 300
    end

    test "parses string keys from YAML" do
      config =
        Config.from_map(%{
          "enabled" => true,
          "model" => "anthropic:claude-haiku",
          "temperature" => 0.1,
          "max_tokens" => 512,
          "timeout_ms" => 5000,
          "fallback_action" => "block",
          "confidence_threshold" => 0.8,
          "cache_ttl_seconds" => 600
        })

      assert config.enabled == true
      assert config.model == "anthropic:claude-haiku"
      assert config.temperature == 0.1
      assert config.max_tokens == 512
      assert config.timeout_ms == 5000
      assert config.fallback_action == :block
      assert config.confidence_threshold == 0.8
      assert config.cache_ttl_seconds == 600
    end

    test "parses atom keys" do
      config = Config.from_map(%{enabled: true, model: "ollama:qwen2.5", fallback_action: :safe})
      assert config.enabled == true
      assert config.model == "ollama:qwen2.5"
      assert config.fallback_action == :safe
    end

    test "coerces integer temperature to float" do
      config = Config.from_map(%{"temperature" => 1})
      assert config.temperature == 1.0
    end

    test "handles unknown fallback_action as :warn" do
      config = Config.from_map(%{"fallback_action" => "unknown"})
      assert config.fallback_action == :warn
    end
  end

  describe "struct defaults" do
    test "has correct default values" do
      config = %Config{}
      assert config.enabled == false
      assert config.model == "ollama:llama3.2"
      assert config.fallback_action == :warn
    end
  end
end
