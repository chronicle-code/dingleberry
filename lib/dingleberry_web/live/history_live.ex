defmodule DingleberryWeb.HistoryLive do
  use DingleberryWeb, :live_view

  alias Dingleberry.Audit.Log

  @impl true
  def mount(_params, _session, socket) do
    entries = Log.list_entries(limit: 100)
    stats = load_stats()

    {:ok,
     assign(socket,
       page_title: "History",
       entries: entries,
       stats: stats,
       filter_risk: nil,
       filter_decision: nil
     )}
  end

  @impl true
  def handle_event("filter", %{"risk" => risk, "decision" => decision}, socket) do
    opts = [limit: 100]
    opts = if risk != "", do: Keyword.put(opts, :risk, risk), else: opts
    opts = if decision != "", do: Keyword.put(opts, :decision, decision), else: opts

    entries = Log.list_entries(opts)

    {:noreply,
     assign(socket,
       entries: entries,
       filter_risk: if(risk != "", do: risk),
       filter_decision: if(decision != "", do: decision)
     )}
  end

  defp load_stats do
    %{
      total: Log.count(),
      by_risk: Log.count_by_risk(),
      by_decision: Log.count_by_decision()
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <h1 class="text-2xl font-bold">Audit History</h1>

      <!-- Stats -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Total</div>
          <div class="text-2xl font-bold">{@stats.total}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Blocked</div>
          <div class="text-2xl font-bold text-error">{Map.get(@stats.by_risk, "block", 0)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Warned</div>
          <div class="text-2xl font-bold text-warning">{Map.get(@stats.by_risk, "warn", 0)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Safe</div>
          <div class="text-2xl font-bold text-success">{Map.get(@stats.by_risk, "safe", 0)}</div>
        </div>
      </div>

      <!-- Filters -->
      <form phx-change="filter" class="flex gap-4">
        <select name="risk" class="select select-sm select-bordered">
          <option value="">All risks</option>
          <option value="block" selected={@filter_risk == "block"}>Block</option>
          <option value="warn" selected={@filter_risk == "warn"}>Warn</option>
          <option value="safe" selected={@filter_risk == "safe"}>Safe</option>
        </select>
        <select name="decision" class="select select-sm select-bordered">
          <option value="">All decisions</option>
          <option value="approved" selected={@filter_decision == "approved"}>Approved</option>
          <option value="rejected" selected={@filter_decision == "rejected"}>Rejected</option>
          <option value="auto_approved" selected={@filter_decision == "auto_approved"}>Auto-approved</option>
          <option value="auto_blocked" selected={@filter_decision == "auto_blocked"}>Auto-blocked</option>
          <option value="timed_out" selected={@filter_decision == "timed_out"}>Timed out</option>
        </select>
      </form>

      <!-- Entries Table -->
      <div class="overflow-x-auto">
        <table class="table table-sm">
          <thead>
            <tr>
              <th>Time</th>
              <th>Command</th>
              <th>Source</th>
              <th>Risk</th>
              <th>Decision</th>
              <th>Rule</th>
            </tr>
          </thead>
          <tbody>
            <tr :if={@entries == []} >
              <td colspan="6" class="text-center opacity-50 py-8">No audit entries yet</td>
            </tr>
            <tr :for={entry <- @entries} class="hover">
              <td class="text-xs whitespace-nowrap">{Calendar.strftime(entry.inserted_at, "%m/%d %H:%M:%S")}</td>
              <td class="max-w-md">
                <pre class="text-xs font-mono truncate">{entry.command}</pre>
              </td>
              <td><span class="badge badge-xs badge-outline">{entry.source}</span></td>
              <td>
                <span class={[
                  "badge badge-xs",
                  entry.risk == "block" && "badge-error",
                  entry.risk == "warn" && "badge-warning",
                  entry.risk == "safe" && "badge-success"
                ]}>
                  {entry.risk}
                </span>
              </td>
              <td>
                <span class={[
                  "badge badge-xs",
                  entry.decision in ~w(approved auto_approved) && "badge-success",
                  entry.decision in ~w(rejected auto_blocked) && "badge-error",
                  entry.decision == "timed_out" && "badge-warning"
                ]}>
                  {entry.decision}
                </span>
              </td>
              <td class="text-xs opacity-60">{entry.matched_rule || "-"}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
