defmodule DingleberryWeb.PolicyLive do
  use DingleberryWeb, :live_view

  alias Dingleberry.Policy.Engine, as: PolicyEngine

  @impl true
  def mount(_params, _session, socket) do
    rules = PolicyEngine.rules()

    grouped =
      rules
      |> Enum.group_by(& &1.action)
      |> Map.put_new(:block, [])
      |> Map.put_new(:warn, [])
      |> Map.put_new(:safe, [])

    {:ok,
     assign(socket,
       page_title: "Policy",
       rules: rules,
       grouped: grouped,
       total: length(rules)
     )}
  end

  @impl true
  def handle_event("reload", _params, socket) do
    case PolicyEngine.reload() do
      {:ok, count} ->
        rules = PolicyEngine.rules()

        grouped =
          rules
          |> Enum.group_by(& &1.action)
          |> Map.put_new(:block, [])
          |> Map.put_new(:warn, [])
          |> Map.put_new(:safe, [])

        {:noreply,
         socket
         |> assign(rules: rules, grouped: grouped, total: count)
         |> put_flash(:info, "Reloaded #{count} rules")}

      _ ->
        {:noreply, put_flash(socket, :error, "Failed to reload policy")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="space-y-6">
      <div class="flex items-center justify-between">
        <h1 class="text-2xl font-bold">Policy Rules</h1>
        <div class="flex items-center gap-4">
          <span class="text-sm opacity-60">{@total} rules loaded</span>
          <button phx-click="reload" class="btn btn-sm btn-outline">
            Reload Policy
          </button>
        </div>
      </div>

      <!-- Block Rules -->
      <div>
        <h2 class="text-lg font-semibold text-error mb-3">
          Block ({length(@grouped[:block])})
        </h2>
        <.rule_table rules={@grouped[:block]} />
      </div>

      <!-- Warn Rules -->
      <div>
        <h2 class="text-lg font-semibold text-warning mb-3">
          Warn ({length(@grouped[:warn])})
        </h2>
        <.rule_table rules={@grouped[:warn]} />
      </div>

      <!-- Safe Rules -->
      <div>
        <h2 class="text-lg font-semibold text-success mb-3">
          Safe ({length(@grouped[:safe])})
        </h2>
        <.rule_table rules={@grouped[:safe]} />
      </div>

      <div class="card bg-base-200 p-4 text-sm opacity-60">
        Policy file: {Dingleberry.Config.default_policy_file()}
        <br/>
        Edit the YAML file and click "Reload Policy" to apply changes.
      </div>
    </div>
    """
  end

  defp rule_table(assigns) do
    ~H"""
    <div :if={@rules == []} class="text-sm opacity-50 pl-4">No rules in this category</div>
    <div class="overflow-x-auto">
      <table :if={@rules != []} class="table table-sm">
        <thead>
          <tr>
            <th>Name</th>
            <th>Description</th>
            <th>Scope</th>
            <th>Patterns</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={rule <- @rules} class="hover">
            <td class="font-mono text-sm">{rule.name}</td>
            <td class="text-sm">{rule.description || "-"}</td>
            <td><span class="badge badge-xs badge-outline">{rule.scope}</span></td>
            <td class="max-w-sm">
              <div class="flex flex-wrap gap-1">
                <code :for={pattern <- rule.patterns} class="text-xs bg-base-300 rounded px-1">
                  {pattern}
                </code>
              </div>
            </td>
          </tr>
        </tbody>
      </table>
    </div>
    """
  end
end
