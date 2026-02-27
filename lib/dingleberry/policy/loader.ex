defmodule Dingleberry.Policy.Loader do
  @moduledoc """
  Loads policy rules from YAML files.
  """

  alias Dingleberry.Policy.Rule

  @doc "Load rules from a YAML file path"
  def load_file(path) do
    case YamlElixir.read_from_file(path) do
      {:ok, %{"rules" => rules}} when is_list(rules) ->
        {:ok, Enum.map(rules, &Rule.from_map/1)}

      {:ok, _} ->
        {:error, :invalid_format}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "Load rules from a YAML string"
  def load_string(yaml_string) do
    case YamlElixir.read_from_string(yaml_string) do
      {:ok, %{"rules" => rules}} when is_list(rules) ->
        {:ok, Enum.map(rules, &Rule.from_map/1)}

      {:ok, _} ->
        {:error, :invalid_format}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
