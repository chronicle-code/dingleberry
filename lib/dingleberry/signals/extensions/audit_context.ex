defmodule Dingleberry.Signals.Extensions.AuditContext do
  @moduledoc "Signal extension for audit trail context."

  use Jido.Signal.Ext,
    namespace: "audit.context",
    schema: [
      session_id: [type: :string, doc: "MCP proxy session ID"],
      hostname: [type: :string, doc: "Hostname where the command originated"],
      request_id: [type: :string, doc: "Unique request correlation ID"]
    ]
end
