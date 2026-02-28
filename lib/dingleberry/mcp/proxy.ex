defmodule Dingleberry.MCP.Proxy do
  @moduledoc """
  MCP proxy that intercepts tool calls, classifies them via the policy engine,
  and queues dangerous ones for human approval before forwarding to the real
  MCP server.
  """

  use GenServer

  require Logger

  alias Dingleberry.MCP.Codec
  alias Dingleberry.Policy.Engine, as: PolicyEngine
  alias Dingleberry.Approval.{Queue, Request}
  alias Dingleberry.Audit.Log
  alias Dingleberry.Approval.Decision
  alias Dingleberry.Notify.Desktop
  alias Dingleberry.Signals

  defstruct [:transport, :session_id, :config]

  # Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @doc "Process an incoming MCP message. Returns {:ok, response} or {:forward, message}."
  def process_message(pid, raw_message) do
    GenServer.call(pid, {:process, raw_message}, :infinity)
  end

  # Server callbacks

  @impl true
  def init(opts) do
    session_id = Keyword.get(opts, :session_id, Uniq.UUID.uuid4())

    {:ok,
     %__MODULE__{
       transport: Keyword.get(opts, :transport),
       session_id: session_id,
       config: Dingleberry.Config.load()
     }}
  end

  @impl true
  def handle_call({:process, raw_message}, _from, state) do
    case Codec.decode(raw_message) do
      {:ok, message} ->
        {action, response} = intercept(message, state)
        {:reply, {action, response}, state}

      {:error, reason} ->
        Logger.warning("Failed to decode MCP message: #{inspect(reason)}")
        {:reply, {:forward, raw_message}, state}
    end
  end

  # Private

  defp intercept(message, state) do
    if Codec.tool_call?(message) do
      intercept_tool_call(message, state)
    else
      {:forward, message}
    end
  end

  defp intercept_tool_call(message, state) do
    {:ok, tool_info} = Codec.extract_tool_info(message)
    description = Codec.tool_call_description(tool_info)

    {risk, rule_name, llm_analysis} =
      case PolicyEngine.classify(description, scope: :mcp) do
        {:ok, risk, rule_name, llm_analysis} -> {risk, rule_name, llm_analysis}
        {:ok, risk, rule_name} -> {risk, rule_name, nil}
      end

    # Emit intercepted signal through the Jido signal bus
    Signals.emit_intercepted(%{
      command: description,
      source: "mcp",
      risk: to_string(risk),
      matched_rule: rule_name,
      session_id: state.session_id
    })

    case risk do
      :safe ->
        auto_approve_audit(description, rule_name, state)
        {:forward, message}

      :block ->
        request_id = Codec.request_id(message)
        auto_block_audit(description, rule_name, state)

        Signals.emit_decided(%{
          command: description,
          decision: "auto_blocked",
          decided_by: "policy_engine",
          risk: "block",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        error =
          Codec.error_response(
            request_id,
            -32_001,
            "Blocked by Dingleberry policy: #{rule_name}"
          )

        {:respond, error}

      :warn ->
        request_approval(message, description, rule_name, llm_analysis, state)
    end
  end

  defp request_approval(message, description, rule_name, llm_analysis, state) do
    request =
      Request.new(
        command: description,
        source: :mcp,
        risk: :warn,
        matched_rule: rule_name,
        session_id: state.session_id,
        timeout_seconds: state.config.approval_timeout_seconds,
        llm_analysis: llm_analysis
      )

    if state.config.desktop_notifications do
      Desktop.notify(request)
    end

    case Queue.submit(request) do
      {:approved, decision} ->
        Log.record(request, decision)

        Signals.emit_decided(%{
          command: description,
          decision: "approved",
          decided_by: decision.decided_by || "human",
          risk: "warn",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        {:forward, message}

      {:rejected, decision} ->
        Log.record(request, decision)

        Signals.emit_decided(%{
          command: description,
          decision: "rejected",
          decided_by: decision.decided_by || "human",
          risk: "warn",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        request_id = Codec.request_id(message)
        error = Codec.error_response(request_id, -32_002, "Rejected by human: #{decision.reason || "no reason"}")
        {:respond, error}

      {:timed_out, decision} ->
        Log.record(request, decision)

        Signals.emit_decided(%{
          command: description,
          decision: "timed_out",
          decided_by: "system",
          risk: "warn",
          matched_rule: rule_name,
          session_id: state.session_id
        })

        request_id = Codec.request_id(message)
        error = Codec.error_response(request_id, -32_003, "Approval timed out")
        {:respond, error}
    end
  end

  defp auto_approve_audit(description, rule_name, state) do
    request = %{
      command: description,
      source: :mcp,
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

  defp auto_block_audit(description, rule_name, state) do
    request = %{
      command: description,
      source: :mcp,
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
