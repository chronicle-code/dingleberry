defmodule Dingleberry.Policy.Rule do
  @moduledoc """
  A single policy rule that matches commands/tool calls against patterns.
  """

  @enforce_keys [:name, :action, :patterns]
  defstruct [:name, :description, :action, :patterns, :scope, compiled_patterns: []]

  @type action :: :block | :warn | :safe
  @type scope :: :shell | :mcp | :all

  @type t :: %__MODULE__{
          name: String.t(),
          description: String.t() | nil,
          action: action(),
          patterns: [String.t()],
          scope: scope(),
          compiled_patterns: [Regex.t()]
        }

  @doc "Build a Rule from a map (parsed from YAML)"
  def from_map(%{"name" => name, "action" => action, "patterns" => patterns} = map) do
    compiled =
      Enum.map(patterns, fn pattern ->
        case Regex.compile(pattern, "i") do
          {:ok, regex} -> regex
          {:error, _} -> Regex.compile!(Regex.escape(pattern), "i")
        end
      end)

    %__MODULE__{
      name: name,
      description: Map.get(map, "description"),
      action: String.to_atom(action),
      patterns: patterns,
      scope: (Map.get(map, "scope", "all") |> String.to_atom()),
      compiled_patterns: compiled
    }
  end

  @doc "Check if a command string matches this rule"
  def matches?(%__MODULE__{compiled_patterns: compiled, scope: scope}, command, opts \\ []) do
    command_scope = Keyword.get(opts, :scope, :all)

    scope_matches?(scope, command_scope) and
      Enum.any?(compiled, fn regex -> Regex.match?(regex, command) end)
  end

  defp scope_matches?(:all, _), do: true
  defp scope_matches?(scope, scope), do: true
  defp scope_matches?(_, :all), do: true
  defp scope_matches?(_, _), do: false
end
