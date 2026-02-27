# Contributing to Dingleberry

Thanks for wanting to help make AI agents less terrifying. Here's how.

## What We're Looking For

### High-Priority Contributions

**More policy rules.** The default policy covers the basics, but there are hundreds of dangerous commands we haven't thought of. If you've seen an AI agent do something cursed, turn it into a rule:
- Cloud CLI destructive commands (`aws s3 rm`, `gcloud compute delete`, `terraform destroy`)
- Container orchestration (`kubectl delete`, `docker compose down -v`)
- Package manager footguns (`npm publish`, `pip install --break-system-packages`)
- Database-specific patterns (MongoDB `dropDatabase`, Redis `FLUSHALL`)
- Platform-specific hazards (Windows `format`, `diskpart`)

**Agent integration guides.** Step-by-step docs for routing specific AI agents through Dingleberry:
- Claude Code (MCP proxy setup)
- Cursor (shell wrapper config)
- Aider (shell integration)
- Continue.dev
- OpenClaw / PicoClaw / NanoBot
- Any other agent tool you use

**MCP transport improvements.** The HTTP/SSE transport works but needs battle-testing with real MCP servers. Help us test against:
- `@modelcontextprotocol/server-filesystem`
- `mcp-server-sqlite`
- Custom MCP servers

**LiveView dashboard enhancements:**
- Bulk approve/reject
- Keyboard shortcuts (y/n for approve/reject)
- Sound alerts
- Session filtering
- Command syntax highlighting
- Policy rule editor (currently view-only)

### Medium-Priority

- **Windows support** — `System.cmd` and port handling for Windows shells
- **Config hot-reload** — Watch `~/.dingleberry/` for file changes
- **Rate limiting** — Auto-block agents that spam dangerous commands
- **Allowlists** — Per-agent trust levels (e.g., "Claude Code can git commit without approval")
- **Metrics/telemetry** — Prometheus/StatsD export of interception stats
- **Plugin system** — Custom classification hooks beyond regex

### Future / Ambitious

- **Browser extension** — Approve/reject from a Chrome/Firefox popup
- **Mobile notifications** — Push to phone when away from desk
- **Multi-user** — Team approval workflows (require 2 approvals for production commands)
- **AI-assisted classification** — Use a small local model to classify ambiguous commands
- **Replay/undo** — Record what the agent *would* have done, allow replaying approved commands

## Development Setup

```bash
git clone https://github.com/dingleberry-ai/dingleberry.git
cd dingleberry
mix setup
mix test           # 59 tests, 0 failures
mix phx.server     # http://localhost:4000
```

## Running Tests

```bash
mix test                           # All tests
mix test test/dingleberry/policy/  # Just policy engine
mix test test/dingleberry/approval # Just approval queue
mix test --cover                   # With coverage
```

## Code Style

- `mix format` before committing
- Keep modules focused — one GenServer per file
- Tests go in matching `test/` directory structure
- Policy rules in YAML, not hardcoded Elixir

## Submitting Changes

1. Fork the repo
2. Create a feature branch (`git checkout -b add-kubectl-rules`)
3. Write tests for new functionality
4. `mix test && mix format`
5. Open a PR with a clear description of what and why

## Reporting Issues

If an AI agent did something destructive that Dingleberry *should* have caught but didn't:
1. Open an issue with the exact command
2. Suggest the rule pattern
3. Bonus points: include a PR with the new rule + test

## Code of Conduct

Be cool. We're all here because AI agents keep doing unhinged things and we want to fix that. Disagreements about implementation are fine; personal attacks are not.

---

*Every contribution makes one more AI agent slightly less capable of destroying your work. That's a good thing.*
