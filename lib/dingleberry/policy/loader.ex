defmodule Dingleberry.Policy.Loader do
  @moduledoc """
  Loads policy rules from YAML files.
  """

  alias Dingleberry.Policy.Rule

  @doc "Load rules from a YAML file path"
  def load_file(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, %{"rules" => rules} = yaml} when is_list(rules) ->
        {:ok, Enum.map(rules, &Rule.from_map/1), extract_llm_policies(yaml)}

      {:ok, _} ->
        {:error, :invalid_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Load rules from a YAML string"
  def load_string(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, %{"rules" => rules} = yaml} when is_list(rules) ->
        {:ok, Enum.map(rules, &Rule.from_map/1), extract_llm_policies(yaml)}

      {:ok, _} ->
        {:error, :invalid_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp extract_llm_policies(yaml) do
    Map.get(yaml, "llm_policies", [])
  end
end
