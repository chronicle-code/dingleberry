defmodule Dingleberry.Audit.Log do
  @moduledoc "Context module for audit log CRUD and statistics."

  import Ecto.Query
  alias Dingleberry.Repo
  alias Dingleberry.Audit.Entry

  @doc "Create an audit entry from a request and decision"
  def create_entry(attrs) when is_map(attrs) do
    %Entry{}
    |> Entry.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Record an intercepted command and its outcome"
  def record(request, decision) do
    create_entry(%{
      command: request.command,
      source: to_string(request.source),
      risk: to_string(request.risk),
      decision: to_string(decision.action),
      matched_rule: request.matched_rule,
      session_id: request.session_id,
      decided_by: decision.decided_by,
      reason: decision.reason,
      metadata: request.metadata
    })
  end

  @doc "List audit entries, most recent first"
  def list_entries(opts \\ []) do
    limit = Keyword.get(opts, :limit, 100)
    offset = Keyword.get(opts, :offset, 0)

    Entry
    |> order_by(desc: :inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> maybe_filter_risk(opts)
    |> maybe_filter_decision(opts)
    |> Repo.all()
  end

  @doc "Count entries grouped by risk level"
  def count_by_risk do
    Entry
    |> group_by(:risk)
    |> select([e], {e.risk, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Count entries grouped by decision"
  def count_by_decision do
    Entry
    |> group_by(:decision)
    |> select([e], {e.decision, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end

  @doc "Total entry count"
  def count do
    Repo.aggregate(Entry, :count)
  end

  defp maybe_filter_risk(query, opts) do
    case Keyword.get(opts, :risk) do
      nil -> query
      risk -> where(query, [e], e.risk == ^to_string(risk))
    end
  end

  defp maybe_filter_decision(query, opts) do
    case Keyword.get(opts, :decision) do
      nil -> query
      decision -> where(query, [e], e.decision == ^to_string(decision))
    end
  end
end
