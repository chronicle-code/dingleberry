defmodule Dingleberry.Approval.Queue do
  @moduledoc """
  GenServer that manages the blocking approval queue.

  `submit/1` blocks the calling process until a human approves or rejects
  the request via the LiveView dashboard. Uses deferred `GenServer.reply/2`
  to unblock the caller when a decision is made.
  """

  use GenServer

  alias Dingleberry.Approval.{Request, Decision}

  @timeout_check_interval :timer.seconds(5)
  @pubsub Dingleberry.PubSub
  @topic "approval_queue"

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Submit a request for approval. Blocks the caller until a decision is made.
  Returns {:approved, decision} or {:rejected, decision} or {:timed_out, decision}.
  """
  def submit(%Request{} = request) do
    GenServer.call(__MODULE__, {:submit, request}, :infinity)
  end

  @doc "Approve a pending request by ID"
  def approve(request_id, opts \\ []) do
    GenServer.call(__MODULE__, {:approve, request_id, opts})
  end

  @doc "Reject a pending request by ID"
  def reject(request_id, opts \\ []) do
    GenServer.call(__MODULE__, {:reject, request_id, opts})
  end

  @doc "List all pending requests"
  def pending do
    GenServer.call(__MODULE__, :pending)
  end

  @doc "Subscribe to queue events via PubSub"
  def subscribe do
    Phoenix.PubSub.subscribe(@pubsub, @topic)
  end

  def topic, do: @topic

  # Server callbacks

  @impl true
  def init(_opts) do
    schedule_timeout_check()
    {:ok, %{pending: %{}, callers: %{}}}
  end

  @impl true
  def handle_call({:submit, %Request{} = request}, from, state) do
    # Don't reply now — we'll reply later when a decision is made
    state = %{
      state
      | pending: Map.put(state.pending, request.id, request),
        callers: Map.put(state.callers, request.id, from)
    }

    broadcast({:new_request, request})
    {:noreply, state}
  end

  def handle_call({:approve, request_id, opts}, _from, state) do
    case Map.fetch(state.pending, request_id) do
      {:ok, _request} ->
        decision = Decision.approve(request_id, opts)
        state = resolve(state, request_id, decision)
        {:reply, {:ok, decision}, state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call({:reject, request_id, opts}, _from, state) do
    case Map.fetch(state.pending, request_id) do
      {:ok, _request} ->
        decision = Decision.reject(request_id, opts)
        state = resolve(state, request_id, decision)
        {:reply, {:ok, decision}, state}

      :error ->
        {:reply, {:error, :not_found}, state}
    end
  end

  def handle_call(:pending, _from, state) do
    requests =
      state.pending
      |> Map.values()
      |> Enum.sort_by(& &1.timestamp, {:asc, DateTime})

    {:reply, requests, state}
  end

  @impl true
  def handle_info(:check_timeouts, state) do
    now = DateTime.utc_now()

    expired =
      state.pending
      |> Enum.filter(fn {_id, req} ->
        req.timeout_at && DateTime.compare(now, req.timeout_at) == :gt
      end)

    state =
      Enum.reduce(expired, state, fn {id, _req}, acc ->
        decision = Decision.timeout(id)
        resolve(acc, id, decision)
      end)

    schedule_timeout_check()
    {:noreply, state}
  end

  # Private

  defp resolve(state, request_id, decision) do
    # Reply to the blocked caller
    case Map.fetch(state.callers, request_id) do
      {:ok, from} -> GenServer.reply(from, {decision.action, decision})
      :error -> :ok
    end

    broadcast({:decision, request_id, decision})

    %{
      state
      | pending: Map.delete(state.pending, request_id),
        callers: Map.delete(state.callers, request_id)
    }
  end

  defp broadcast(message) do
    Phoenix.PubSub.broadcast(@pubsub, @topic, message)
  end

  defp schedule_timeout_check do
    Process.send_after(self(), :check_timeouts, @timeout_check_interval)
  end
end
