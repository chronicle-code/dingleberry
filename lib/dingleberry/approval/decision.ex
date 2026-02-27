defmodule Dingleberry.Approval.Decision do
  @moduledoc """
  A human decision on an approval request.
  """

  @enforce_keys [:request_id, :action, :decided_at]
  defstruct [:request_id, :action, :decided_by, :decided_at, :reason]

  @type action :: :approved | :rejected | :timed_out

  @type t :: %__MODULE__{
          request_id: String.t(),
          action: action(),
          decided_by: String.t() | nil,
          decided_at: DateTime.t(),
          reason: String.t() | nil
        }

  def approve(request_id, opts \\ []) do
    %__MODULE__{
      request_id: request_id,
      action: :approved,
      decided_by: Keyword.get(opts, :decided_by, "human"),
      decided_at: DateTime.utc_now(),
      reason: Keyword.get(opts, :reason)
    }
  end

  def reject(request_id, opts \\ []) do
    %__MODULE__{
      request_id: request_id,
      action: :rejected,
      decided_by: Keyword.get(opts, :decided_by, "human"),
      decided_at: DateTime.utc_now(),
      reason: Keyword.get(opts, :reason)
    }
  end

  def timeout(request_id) do
    %__MODULE__{
      request_id: request_id,
      action: :timed_out,
      decided_by: "system",
      decided_at: DateTime.utc_now(),
      reason: "Approval timeout expired"
    }
  end
end
