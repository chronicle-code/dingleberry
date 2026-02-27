defmodule DingleberryWeb.DashboardLive do
  use DingleberryWeb, :live_view

  alias Dingleberry.Approval.Queue
  alias Dingleberry.Audit.Log

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Queue.subscribe()
    end

    pending = Queue.pending()
    stats = load_stats()

    {:ok,
     assign(socket,
       page_title: "Dashboard",
       pending: pending,
       stats: stats
     )}
  end

  @impl true
  def handle_event("approve", %{"id" => id}, socket) do
    case Queue.approve(id) do
      {:ok, _decision} ->
        {:noreply, put_flash(socket, :info, "Command approved")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Request not found (may have timed out)")}
    end
  end

  def handle_event("reject", %{"id" => id}, socket) do
    case Queue.reject(id) do
      {:ok, _decision} ->
        {:noreply, put_flash(socket, :info, "Command rejected")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Request not found (may have timed out)")}
    end
  end

  @impl true
  def handle_info({:new_request, _request}, socket) do
    {:noreply, assign(socket, pending: Queue.pending())}
  end

  def handle_info({:decision, _id, _decision}, socket) do
    pending = Queue.pending()
    stats = load_stats()
    {:noreply, assign(socket, pending: pending, stats: stats)}
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
    <div class="space-y-8">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Dingleberry Dashboard</h1>
        <span class="badge badge-lg badge-outline">
          {@stats.total} total intercepted
        </span>
      </div>

      <!-- Stats Cards -->
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Blocked</div>
          <div class="text-2xl font-bold text-error">{Map.get(@stats.by_risk, "block", 0)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Warned</div>
          <div class="text-2xl font-bold text-warning">{Map.get(@stats.by_risk, "warn", 0)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Approved</div>
          <div class="text-2xl font-bold text-success">{Map.get(@stats.by_decision, "approved", 0) + Map.get(@stats.by_decision, "auto_approved", 0)}</div>
        </div>
        <div class="card bg-base-200 p-4">
          <div class="text-sm opacity-70">Rejected</div>
          <div class="text-2xl font-bold text-error">{Map.get(@stats.by_decision, "rejected", 0) + Map.get(@stats.by_decision, "auto_blocked", 0)}</div>
        </div>
      </div>

      <!-- Pending Approvals -->
      <div>
        <h2 class="text-xl font-semibold mb-4">
          Pending Approvals
          <span :if={length(@pending) > 0} class="badge badge-warning ml-2">
            {length(@pending)}
          </span>
        </h2>

        <div :if={@pending == []} class="card bg-base-200 p-8 text-center opacity-70">
          No pending approvals. All quiet.
        </div>

        <div class="space-y-3">
          <div :for={request <- @pending} class="card bg-base-200 border-l-4 border-warning p-4">
            <div class="flex items-start justify-between gap-4">
              <div class="flex-1 min-w-0">
                <div class="flex items-center gap-2 mb-1">
                  <span class={[
                    "badge badge-sm",
                    request.risk == :block && "badge-error",
                    request.risk == :warn && "badge-warning"
                  ]}>
                    {request.risk}
                  </span>
                  <span class="badge badge-sm badge-outline">{request.source}</span>
                  <span :if={request.matched_rule} class="text-xs opacity-60">
                    Rule: {request.matched_rule}
                  </span>
                </div>
                <pre class="text-sm font-mono bg-base-300 rounded p-2 overflow-x-auto whitespace-pre-wrap break-all">{request.command}</pre>
                <div class="text-xs opacity-50 mt-1">
                  {Calendar.strftime(request.timestamp, "%H:%M:%S")}
                  · Expires {Calendar.strftime(request.timeout_at, "%H:%M:%S")}
                </div>
              </div>
              <div class="flex gap-2 flex-shrink-0">
                <button
                  phx-click="approve"
                  phx-value-id={request.id}
                  class="btn btn-success btn-sm"
                >
                  Approve
                </button>
                <button
                  phx-click="reject"
                  phx-value-id={request.id}
                  class="btn btn-error btn-sm"
                >
                  Reject
                </button>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end
end
