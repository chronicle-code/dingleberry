defmodule Dingleberry.Shell.Interceptor do
  @moduledoc """
  Shell command interceptor. Classifies commands via the policy engine,
  queues dangerous ones for approval, then executes or rejects.
  """

  use GenServer

  require Logger

  alias Dingleberry.Policy.Engine, as: PolicyEngine
  alias Dingleberry.Approval.{Queue, Request}
  alias Dingleberry.Approval.Decision
  alias Dingleberry.Audit.Log
  alias Dingleberry.Notify.Desktop
  alias Dingleberry.Signals

  defstruct [:session_id, :config]

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Intercept and potentially execute a shell command.
  Returns {:ok, output} | {:rejected, reason} | {:blocked, reason} | {:error, reason}
  """
  def execute(command) do
    GenServer.call(__MODULE__, {:execute, command}, :infinity)
  end

  @doc "Classify a command without executing"
  def classify(command) do
    GenServer.call(__MODULE__, {:classify, command})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    session_id = Keyword.get(opts, :session_id, Uniq.UUID.uuid4())

    {:ok,
     %__MODULE__{
       session_id: session_id,
       config: Dingleberry.Config.load()
     }}
  end

  @impl true
  def handle_call({:execute, command}, _from, state) do
    result = do_execute(command, state)
    {:reply, result, state}
  end

  def handle_call({:classify, command}, _from, state) do
    {:ok, risk, rule_name} = PolicyEngine.classify(command, scope: :shell)
    {:reply, {:ok, risk, rule_name}, state}
  end

  # Private

  defp do_execute(command, state) do
    {:ok, risk, rule_name} = PolicyEngine.classify(command, scope: :shell)

    # Emit intercepted signal through the Jido signal bus
    Signals.emit_intercepted(%{
      command: command,
      source: "shell",
      risk: to_string(risk),
      matched_rule: rule_name,
      session_id: state.session_id
    })

    case risk do
      :safe ->
        auto_approve_audit(command, rule_name, state)
        run_command(command)

      :block ->
        auto_block_audit(command, rule_name, state)

        Signals.emit_decided(%{
          command: command,
          decision: "auto_blocked",
          decided_by: "policy_engine",
          risk: "block",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        {:blocked, "Command blocked by policy: #{rule_name}"}

      :warn ->
        request_and_maybe_execute(command, rule_name, state)
    end
  end

  defp request_and_maybe_execute(command, rule_name, state) do
    request =
      Request.new(
        command: command,
        source: :shell,
        risk: :warn,
        matched_rule: rule_name,
        session_id: state.session_id,
        timeout_seconds: state.config.approval_timeout_seconds
      )

    if state.config.desktop_notifications do
      Desktop.notify(request)
    end

    case Queue.submit(request) do
      {:approved, decision} ->
        Log.record(request, decision)

        Signals.emit_decided(%{
          command: command,
          decision: "approved",
          decided_by: decision.decided_by || "human",
          risk: "warn",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        run_command(command)

      {:rejected, decision} ->
        Log.record(request, decision)

        Signals.emit_decided(%{
          command: command,
          decision: "rejected",
          decided_by: decision.decided_by || "human",
          risk: "warn",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        {:rejected, decision.reason || "Rejected by human"}

      {:timed_out, decision} ->
        Log.record(request, decision)

        Signals.emit_decided(%{
          command: command,
          decision: "timed_out",
          decided_by: "system",
          risk: "warn",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        {:rejected, "Approval timed out"}
    end
  end

  defp run_command(command) do
    try do
      {output, exit_code} = System.cmd("sh", ["-c", command], stderr_to_stdout: true)
      {:ok, %{output: output, exit_code: exit_code}}
    rescue
      e -> {:error, Exception.message(e)}
    end
  end

  defp auto_approve_audit(command, rule_name, state) do
    request = %{
      command: command,
      source: :shell,
      risk: :safe,
      matched_rule: rule_name,
      session_id: state.session_id,
      metadata: nil
    }

    decision = %Decision{
      request_id: "auto",
      action: :auto_approved,
      decided_by: "policy_engine",
      decided_at: DateTime.utc_now()
    }

    Log.record(request, decision)
  end

  defp auto_block_audit(command, rule_name, state) do
    request = %{
      command: command,
      source: :shell,
      risk: :block,
      matched_rule: rule_name,
      session_id: state.session_id,
      metadata: nil
    }

    decision = %Decision{
      request_id: "auto",
      action: :auto_blocked,
      decided_by: "policy_engine",
      decided_at: DateTime.utc_now()
    }

    Log.record(request, decision)
  end
end
