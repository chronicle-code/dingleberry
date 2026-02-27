defmodule DingleberryWeb.SessionsLive do
  use DingleberryWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    sessions = list_proxy_sessions()

    {:ok,
     assign(socket,
       page_title: "Sessions",
       sessions: sessions
     )}
  end

  @impl true
  def handle_event("refresh", _params, socket) do
    {:noreply, assign(socket, sessions: list_proxy_sessions())}
  end

  defp list_proxy_sessions do
    case Registry.select(Dingleberry.ProxyRegistry, [{{:"$1", :"$2", :"$3"}, [], [{{:"$1", :"$2"}}]}]) do
      sessions when is_list(sessions) ->
        Enum.map(sessions, fn {session_id, pid} ->
          %{id: session_id, pid: inspect(pid), alive: Process.alive?(pid)}
        end)

      _ ->
        []
    end
  rescue
    _ -> []
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Active Sessions</h1>
        <button phx-click="refresh" class="btn btn-sm btn-outline">
          Refresh
        </button>
      </div>

      <div :if={@sessions == []} class="card bg-base-200 p-8 text-center opacity-70">
        No active proxy sessions. Start one with:
        <pre class="mt-2 text-sm font-mono bg-base-300 rounded p-2 inline-block">mix dingleberry.proxy --command your-mcp-server</pre>
      </div>

      <div class="overflow-x-auto">
        <table :if={@sessions != []} class="table table-sm">
          <thead>
            <tr>
              <th>Session ID</th>
              <th>PID</th>
              <th>Status</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={session <- @sessions} class="hover">
              <td class="font-mono text-sm">{session.id}</td>
              <td class="font-mono text-xs opacity-60">{session.pid}</td>
              <td>
                <span class={["badge badge-sm", session.alive && "badge-success" || "badge-error"]}>
                  {if session.alive, do: "active", else: "dead"}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
    """
  end
end
