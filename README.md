<p align="center">
  <img src="priv/static/images/logo-500.png" alt="Dingleberry mascot" width="200" />
</p>

<h1 align="center">Dingleberry</h1>

<p align="center"><strong>The emergency brake for AI agents.</strong></p>

A local daemon that sits between your AI coding agents and your system, intercepting every shell command and MCP tool call. Dangerous operations get held for human approval in a real-time dashboard before they can touch your files, your git history, or your database.

Because AI agents that can `rm -rf /` without asking should not exist in the wild.

---

## The Problem

AI coding agents are getting more powerful and more autonomous. That's great — until one of them:

- Force-pushes over your main branch
- Drops a production database table
- Runs `curl | bash` from an untrusted source
- Deletes your `.env` file
- Does a `chmod 777` on your SSH keys

These aren't hypotheticals. They're [happening](https://simonwillison.net/2025/Jun/8/you-should-be-scared/) right now, across Claude Code, Cursor, Aider, Replit, and every other agent tool. The trust model is broken: agents request unlimited shell access, and you either grant it or don't use the tool.

**Dingleberry** fills the gap. It's a universal, agent-agnostic interceptor that works with *any* AI coding tool, classifies every action against YAML policy rules, and blocks dangerous operations until a human says "yes."

## How It Works

```
AI Agent (Claude Code / Cursor / Aider / etc.)
    |
    v
[Dingleberry - localhost:4000]
    |-- Classifies command against YAML policy
    |-- Safe? Auto-approve, forward instantly
    |-- Dangerous? Hold in queue, notify human
    |-- Human approves/rejects via LiveView dashboard
    |
    v
Your actual shell / MCP server
```

The magic: `Queue.submit/1` **blocks the agent's request in-flight** using Elixir's `GenServer.reply/2` pattern. The AI agent literally cannot proceed until you click Approve or Reject. No polling. No race conditions. Just OTP doing what it was born to do.

## Quick Start

```bash
# Clone it
git clone https://github.com/dingleberry-ai/dingleberry.git
cd dingleberry

# Set up
mix setup

# Initialize your config
mix dingleberry.init

# Run it
mix phx.server
```

Open [localhost:4000](http://localhost:4000) and you'll see the dashboard. Now route your AI agent through Dingleberry.

### As an MCP Proxy

```bash
# Wrap any MCP server
mix dingleberry.proxy --command npx --args "@modelcontextprotocol/server-filesystem /tmp"

# Point your AI agent at Dingleberry instead of the real server
```

### As a Shell Interceptor

```bash
# Interactive mode
mix dingleberry.shell

dingleberry> ls -la          # Auto-approved (safe)
dingleberry> rm -rf ./build  # Held for approval in dashboard
dingleberry> rm -rf /        # Instantly blocked by policy
```

## Policy Engine

Dingleberry ships with ~25 sane default rules in three tiers:

| Tier | Behavior | Examples |
|------|----------|---------|
| **Block** | Instantly rejected, never forwarded | `rm -rf /`, `DROP DATABASE`, fork bombs, `dd if=` |
| **Warn** | Held for human approval | `git push --force`, `rm -rf`, `curl \| bash`, `chmod 777`, `kill -9` |
| **Safe** | Auto-approved, forwarded instantly | `ls`, `cat`, `grep`, `git status`, `mix test` |

Rules are YAML with regex patterns:

```yaml
rules:
  - name: git_force_push
    description: "Force push to remote"
    action: warn
    patterns:
      - "git\\s+push\\s+.*--force"
    scope: shell
```

Edit `~/.dingleberry/policy.yml` and click "Reload Policy" in the dashboard. No restart needed.

## Dashboard

The LiveView dashboard at `localhost:4000` gives you:

- **Dashboard** — Pending approval cards with one-click Approve/Reject
- **History** — Full audit log of every intercepted command
- **Policy** — View and reload your YAML rules
- **Sessions** — Active MCP proxy sessions

All real-time via Phoenix PubSub. When an agent triggers a warn/block rule, the card appears instantly.

## Desktop Notifications

When a command needs approval, Dingleberry sends a native OS notification:
- **macOS**: via `osascript`
- **Linux**: via `notify-send`

So you'll know immediately even if the dashboard isn't in focus.

## Architecture

Built on Elixir/OTP because this is fundamentally a concurrency problem — you need to hold N agent requests in-flight simultaneously while a human makes decisions asynchronously.

- **Policy Engine** — GenServer with compiled regex patterns from YAML
- **Approval Queue** — GenServer using deferred `reply/2` to block callers
- **MCP Proxy** — JSON-RPC 2.0 codec + bidirectional Port to real MCP server
- **Shell Interceptor** — Command parser + policy check + conditional execution
- **Audit Log** — SQLite via Ecto for zero-config persistence
- **LiveView Dashboard** — Real-time UI via Phoenix PubSub

## Configuration

`~/.dingleberry/config.yml`:

```yaml
port: 4000
approval_timeout_seconds: 120
desktop_notifications: true
log_level: info
```

## Requirements

- Elixir 1.15+
- Erlang/OTP 26+

That's it. No Docker. No cloud. No API keys. Everything runs on your machine.

## License

Apache-2.0. See [LICENSE](LICENSE).

---

*Named after the thing that hangs on and won't let go — just like this daemon hangs onto every dangerous command until you say it's okay.*
