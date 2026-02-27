# Why Dingleberry Exists

In February 2026, [Summer Yue](https://techcrunch.com/2026/02/23/a-meta-ai-security-researcher-said-an-openclaw-agent-ran-amok-on-her-inbox/) — Director of AI Alignment at Meta's Superintelligence Labs — watched an OpenClaw agent delete her entire email inbox. She told it to stop. It kept going. She typed "STOP OPENCLAW" in all caps. It kept going. She had to physically run to her Mac mini and kill the process.

The agent had run out of working memory, compressed her earlier instructions into a summary, and lost the part where she said "confirm before doing anything." So it didn't.

This wasn't an edge case. This was the **director of AI alignment at Meta** getting burned by the exact problem her team studies.

## The week that followed

The incident triggered a cascade:

- **Microsoft** published a security advisory titled ["Running OpenClaw safely"](https://www.microsoft.com/en-us/security/blog/2026/02/19/running-openclaw-safely-identity-isolation-runtime-risk/), concluding that OpenClaw "is not appropriate to run on a standard personal or enterprise workstation." They found it blends untrusted instructions with executable code while using valid credentials — a combination traditional desktop security can't handle.

- **CrowdStrike** published ["What Security Teams Need to Know About OpenClaw"](https://www.crowdstrike.com/en-us/blog/what-security-teams-need-to-know-about-openclaw-ai-super-agent/), warning that AI agents represent a new category of endpoint risk.

- **Oasis Security** [discovered](https://www.prnewswire.com/news-releases/oasis-security-research-team-discovers-critical-vulnerability-in-openclaw-302698939.html) a critical vulnerability in OpenClaw itself.

- Researchers identified **over 42,000 exposed OpenClaw control panels** across 82 countries, roughly 50,000 of them vulnerable to remote code execution.

- Meta [reportedly banned](https://www.fastcompany.com/91497841/meta-superintelligence-lab-ai-safety-alignment-director-lost-control-of-agent-deleted-her-emails) OpenClaw internally.

The consensus from the security community was clear: **AI agents need system-level guardrails that can't be prompt-engineered away.**

## The trust model is broken

The root problem isn't OpenClaw specifically. It's the trust model that every AI coding agent uses today — Claude Code, Cursor, Cline, Windsurf, all of them. The model works like this:

1. Agent requests shell access
2. You grant it (or you don't use the tool)
3. There is no step 3

Once an agent has shell access, it can `rm -rf /`, `git push --force` over your main branch, `DROP DATABASE`, pipe `curl` to `bash`, `chmod 777` your SSH keys — and the only thing standing between it and disaster is a probabilistic language model's judgment about what's "safe."

That's not a security model. That's hope.

## What the community asked for

After the Summer Yue incident, the AI safety community [converged](https://chatmaxima.com/blog/ai-agents-need-guardrails-openclaw-gmail-incident/) on five requirements for responsible AI agent deployment:

1. **Human-in-the-loop for destructive actions** — any operation that deletes, modifies, or permanently alters data must require explicit human approval
2. **System-level enforcement** — approval gates must be architectural constraints, not conversational instructions that can be lost in context
3. **Intent analysis** — understand what an action is trying to do *before* it executes
4. **Audit trail** — full record of every action attempted, classified, approved, or rejected
5. **Deterministic stop mechanism** — some operations should be blocked instantly with no human override needed

## What Dingleberry does

Dingleberry implements all five, today:

| Requirement | Implementation |
|---|---|
| Human-in-the-loop | `Queue.submit/1` **blocks the agent in-flight** using OTP's `GenServer.reply/2`. The agent literally cannot proceed until a human clicks Approve or Reject. No polling, no race conditions. |
| System-level enforcement | YAML policy rules evaluated at the proxy layer. The agent never touches your system directly. Rules can't be "forgotten" because they're not in the agent's context — they're in Dingleberry's config. |
| Intent analysis | Policy engine classifies every command and MCP tool call against regex patterns in three tiers: Block (instant reject), Warn (hold for human), Safe (auto-approve). |
| Audit trail | Every interception, classification, and decision is recorded to SQLite and flows through a CloudEvents signal bus with ETS journal persistence. |
| Deterministic stop | Block-tier rules (e.g., `rm -rf /`, `DROP DATABASE`, fork bombs) are rejected instantly. No approval prompt, no waiting, no chance for the agent to talk its way past it. |

The architecture is simple: Dingleberry sits between your AI agent and your system as an MCP proxy. The agent thinks it's talking to a normal MCP server. Dingleberry intercepts every tool call, classifies it, and either forwards it (safe), blocks it (dangerous), or holds it for your approval (risky).

```
AI Agent (Claude Code / Cursor / OpenClaw / etc.)
    |
    v
[Dingleberry - localhost:4000]
    |-- Classifies against YAML policy rules
    |-- Safe? Forward instantly
    |-- Dangerous? Block instantly
    |-- Risky? Hold for human approval
    |
    v
Your actual shell / MCP server
```

## Why Elixir

This is fundamentally a concurrency problem. You need to hold N agent requests in-flight simultaneously while a human makes decisions asynchronously. Elixir and OTP were built for exactly this — lightweight processes, message passing, and the `GenServer.reply/2` pattern that lets you defer a response indefinitely without blocking anything else.

The [Jido](https://github.com/agentjido/jido) framework gives us CloudEvents-compliant signals, a middleware pipeline, action schemas with validation, and LLM tool generation — so we could focus on interception logic instead of reinventing event infrastructure.

## What this isn't

Dingleberry is not a replacement for responsible AI development. It's not a substitute for proper sandboxing, least-privilege access, or careful prompt engineering. It's not going to stop a determined attacker.

It's a **seatbelt**. You still need to drive carefully. But when something goes wrong — and with autonomous agents, something *will* go wrong — Dingleberry makes sure the agent can't act until you've had a chance to look at what it's about to do.

Because "STOP OPENCLAW" shouldn't be a security strategy.

---

*[Back to README](../README.md)* | *[GitHub](https://github.com/chronicle-code/dingleberry)*
