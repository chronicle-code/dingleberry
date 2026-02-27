defmodule Dingleberry.Signals.CommandIntercepted do
  @moduledoc "Signal emitted when a command is intercepted by Dingleberry."

  use Jido.Signal,
    type: "dingleberry.command.intercepted",
    default_source: "/dingleberry/interceptor",
    schema: [
      command: [type: :string, required: true, doc: "The intercepted command"],
      source: [type: :string, required: true, doc: "Command source (shell/mcp)"],
      risk: [type: :string, required: true, doc: "Risk classification (safe/warn/block)"],
      matched_rule: [type: :string, doc: "Name of the matched policy rule"],
      session_id: [type: :string, doc: "Proxy session ID"]
    ]
end
