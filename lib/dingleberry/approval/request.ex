defmodule Dingleberry.Approval.Request do
  @moduledoc """
  An intercepted command/tool call awaiting human approval.
  """

  @enforce_keys [:id, :command, :source, :risk, :matched_rule, :timestamp]
  defstruct [
    :id,
    :command,
    :source,
    :risk,
    :matched_rule,
    :timestamp,
    :session_id,
    :metadata,
    :timeout_at,
    :llm_analysis
  ]

  @type t :: %__MODULE__{
          id: String.t(),
          command: String.t(),
          source: :shell | :mcp | :unknown,
          risk: :block | :warn,
          matched_rule: String.t() | nil,
          timestamp: DateTime.t(),
          session_id: String.t() | nil,
          metadata: map() | nil,
          timeout_at: DateTime.t() | nil,
          llm_analysis: map() | nil
        }

  def new(attrs) do
    timeout_seconds = Keyword.get(attrs, :timeout_seconds, 120)
    now = DateTime.utc_now()

    %__MODULE__{
      id: Uniq.UUID.uuid4(),
      command: Keyword.fetch!(attrs, :command),
      source: Keyword.get(attrs, :source, :unknown),
      risk: Keyword.fetch!(attrs, :risk),
      matched_rule: Keyword.get(attrs, :matched_rule),
      timestamp: now,
      session_id: Keyword.get(attrs, :session_id),
      metadata: Keyword.get(attrs, :metadata),
      timeout_at: DateTime.add(now, timeout_seconds, :second),
      llm_analysis: Keyword.get(attrs, :llm_analysis)
    }
  end
end
