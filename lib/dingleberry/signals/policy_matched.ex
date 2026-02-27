defmodule Dingleberry.Signals.PolicyMatched do
  @moduledoc "Signal emitted when a policy rule matches a command."

  use Jido.Signal,
    type: "dingleberry.policy.matched",
    default_source: "/dingleberry/policy",
    schema: [
      command: [type: :string, required: true, doc: "The command that was classified"],
      rule_name: [type: :string, doc: "Name of the matched rule"],
      risk: [type: :string, required: true, doc: "Risk level (safe/warn/block)"],
      scope: [type: :string, doc: "Classification scope"]
    ]
end
