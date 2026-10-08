# Week 2 — Structured Workflows and Tools: RAPID, Skills, and MCP

Three parts this week:

1. **The workflow** (Lec 3, "Advanced Prompting and Context Engineering for Complex Codebases" + `code/week2/`): the RAPID framework, a staged process where each stage is a reusable skill.
2. **The tools** (Lec 4, "MCP, Tool-calling, and Beyond"): how MCP connects agents to outside services, and how to design tools that don't bloat the context.
3. **The readings**: LangWatch on when to compact, OpenSpec and Superpowers (two public versions of the "spec first, then code" workflow), and Cloudflare on running MCP inside a company.

The theme carries over from week 1: **context is the scarce resource.** RAPID splits big work into stages so that each stage starts from a clean, compressed context. Good MCP design (and Code Mode) keeps tool definitions from filling the window. The readings put numbers on what it costs when context grows.

---

## Part 1 — RePPIT as skills (code)

`code/week2/` has no Python this week. It holds six **skills**, each a `SKILL.md` with YAML frontmatter followed by a prompt. Together they implement the RePPIT pipeline from lecture.

### The pipeline

```
/explore ─┐
          ├─> /research-codebase ──> research/*.md
          │                              │
          │                     /make-proposals  (human picks one)
          │                              │
          │                         /plan ──> plans/*.md
          │                              │
          │                        /implement
          │                              │
          └──────────────────────── /review
```

| Skill | RAPID step | Input | Output | Key constraint |
|---|---|---|---|---|
| `explore` | (orientation) | an area of the code | briefing in chat | "do not execute unless asked" |
| `research-codebase` | **R**esearch | a research query | doc in `research/` | describe what exists today, with no suggestions |
| `make-proposals` | **P**roposals | research doc + feature request | 2 proposals in chat | must be grounded in the research doc |
| `plan` | **P**lan | chosen proposal | design doc in `plans/` | "do not actually implement any change" |
| `implement` | **I**mplement | plan file | code changes | (one-line prompt) |
| `review` | **T**est / review | uncommitted diff | prioritized action list | 🔴 / 🟡 / 🟢 severity |

### Ideas worth noticing in the skill files

- **Each stage has one job, and the prompt says what *not* to do.** `research-codebase` has a "behavior contract": "Only document what exists today; do not suggest improvements, RCA, or future work." `plan` says "Do not actually implement any change." Without these limits the agent tends to jump ahead (proposing fixes while researching, coding while planning), which mixes stages and wastes the human review between them.
- **Stages hand off through files, not through the conversation.** Research goes to `research/`, plans go to `plans/`. The next stage reads the file instead of inheriting the chat history. This is lecture's "write to file and reingest the compressed representation". It's also what lets you clear context between steps without losing work.
- **Outputs have fixed formats.** `make-proposals` has an output template (Overview / Key Changes / Trade-offs / Validation / Open Questions). `review` forces a single prioritized list with severity markers. `research-codebase` asks for references like `path/to/file.py:123-145`. A fixed shape makes the output easy for a human to review and easy for the next stage to parse.
- **The plan template forces precision.** `plan/design_doc_template.md` requires a "Files Changed" section with line numbers ("YOU MUST INCLUDE THE LINE NUMBERS"), stating that "These should be the ONLY files impacted in the change." This sets the scope of the change, so the implement stage has a clear boundary.
- **The template warns against over-testing.** "Be thoughtful of when tests are actually helpful and ensure the tests generated aren't excessive in mocking." Agents tend to produce many low-value, heavily mocked tests unless told otherwise.
- **Progressive disclosure inside a skill.** `plan/SKILL.md` stays short and points to `design_doc_template.md` as a separate file to open when needed. The long template is read only when the skill runs, not whenever the skill is merely listed.
- **`disable-model-invocation: true` on every skill.** These skills run only when the user types the slash command; the model can't decide to start them on its own. That fits RAPID, where the *human* decides when to move to the next stage. (Compare with Superpowers below, where skills trigger automatically.)
- **`description` is what the model sees up front.** Each frontmatter description says what the skill does *and when to use it* ("Use when the user asks to … or invokes /plan"). This is the metadata that sits in context before the full skill loads (week 1's progressive disclosure).
- **`research-codebase` points to outside tools**: inspect `git` history, and use **Context7** for up-to-date third-party API docs instead of relying on the model's possibly outdated memory of a library.

---

## Part 2 — Lecture concepts

### Why vanilla prompting breaks at scale (Lec 3)

- Prompting directly works on small codebases. It breaks down on Google-scale codebases (hundreds of thousands of files, millions of lines).
- The core limit is the context window. Even 1M-token models have far fewer *useful* tokens: roughly half to three-quarters of the advertised window.
- Lecture cited published studies recommending compaction around **250K–450K tokens** (see the LangWatch reading for one such study).
- Goal: **spec-driven engineering** instead of vibe-coding.

### RePPIT: Research, Proposals, Plan, Implement, Test (Lec 3)

Each step is a skill, a curated prompt committed to version control and shared across the team. RePPIT is a starting point and can be extended; one student added a compliance/security step for healthcare.

| Step | What happens | Where the human comes in |
|---|---|---|
| Research | Agent writes a structured doc of the codebase's current state (only what it does now, no suggestions) | Low priority to check; agents are good at compressing code |
| Proposals | Agent offers **2** distinct solutions grounded in the research | **High leverage**: human weighs trade-offs and picks one |
| Plan | Agent fills in the design doc template: requirements, file-level changes with line numbers, out-of-scope items, testing, observability | High leverage: review the spec |
| Implement | Minimal prompt; agent follows the plan | Modern agents test themselves while implementing |
| Test / Review | Behavior checked in a browser; code quality checked by agentic review | Read the review output |

- **Why exactly two proposals?** They're chosen to be *orthogonal* (lecture compared them to PCA principal components). Two very different options show the trade-off space, and returns diminish after that.
- **Name what's out of scope.** Saying explicitly what the change does *not* include keeps the agent from going off track.
- Built-in plan modes (Claude Code, Codex) are now quite good. A custom plan skill is still useful because it gives every plan the same format.
- Implement and test are merging, since agents like Cursor now test as they go. Agents without browser testing can get it through **Playwright MCP**.
- **AI code review** as lecture described it: several subagents, each focused on one area (security, performance, style, consistency, missing edge cases), with a master agent combining their findings.

### Choosing how much process to use (Lec 3)

| Task size | Approach |
|---|---|
| Copy changes, small fixes | Prompt the agent directly |
| Small feature across a few files | Add a plan step |
| Medium features, large refactors/migrations | Full RAPID with research and proposals |
| Very large projects | Split into multiple issues, one agent per issue, and stack the issues so each agent builds on earlier work |

### Best practices (Lec 3)

- **Clear context between major steps.** Don't keep two competing proposals in the same session, because the rejected one keeps influencing the agent.
- **Compact aggressively**: write to a file, then re-read the compressed version.
- **Choose models by stage**: stronger models for Research, Proposals, and Plan, where mistakes multiply downstream; lighter models are fine for Test.
- **Spend your review time on the early stages.** A wrong research doc or plan produces wrong code no matter how good the implementation agent is.

### What MCP is and why it exists (Lec 4)

- **Model Context Protocol**, developed by Anthropic about two years ago. LLMs are pre-trained and static; MCP gives them live, real-world capabilities.
- **It turns M×N into M+N.** Without a standard, every agent needs its own connector to every service (M agents × N services). With MCP, each agent implements the client side once and each service implements a server once. Shared boilerplate (auth, error handling, rate limiting) is handled in one place instead of in every connector.
- Everything is JSON under the hood.

| Term | Meaning |
|---|---|
| **Host** | The application (Cursor, Claude Desktop) that runs the client SDK |
| **Client** | The SDK library inside the host; keeps a stateful session with each server |
| **Server** | A wrapper around a tool or service; runs locally (**stdio**) or remotely (**HTTP**) |
| **Tool** | A callable function the server exposes: name, description, JSON schema |

**The flow:**

1. Client calls `tools/list` on each connected server (discovery).
2. Servers return JSON for each tool: name, summary, schema.
3. Host injects those definitions into the model's context.
4. The user's query leads the model to emit a structured tool call.
5. The server runs the call and returns a result, and the conversation continues.

**Known limitation:** by default, *every* tool from *every* connected server goes into context. This is the same problem week 1 described: big tool sets fill the window and make it harder for the model to pick the right tool.

### Designing MCP servers well (Lec 4)

- **Avoid one tool per API endpoint.** That was the 2024–early 2025 approach, and it caused tool bloat. Cursor once capped connections at 88 tools, while GitHub's server alone shipped 120–150.
- **Design for outcomes, not operations.**
  - Good: `send_payment(email)` is one call for one outcome.
  - Bad: `list_accounts(email)` → `get_account_id()` → `send_payment(account_id)` is three sequential calls, and each one is another chance to fail.
- **Everything in the signature is context.** Type annotations, docstrings, and function names all reach the model (this is how `create_full_system_prompt` worked in week 1). So avoid `**kwargs`, use typed signatures and Pydantic models, and raise specific errors (`ValueError`, custom exceptions) instead of a generic `Exception`, so the model can tell what went wrong.
- **Name tools so they're easy to find**, because names shape how the model chooses between tools.
- **Iterate**: start with broad coverage, then read agent traces and consolidate. For example, merge `search_meetings`, `search_transcripts`, and `search_slack` into one `search` tool.

### Code Mode (Lec 4)

- Problem: exposing every tool all the time bloats context and costs tokens.
- Solution: a meta-layer MCP server that exposes only **two tools**:
  - **Search**: finds the relevant tools for the current query in an index. Matching can be **lexical** (keywords on tool names) or **semantic** (embedding search).
  - **Execute**: the model writes code that calls the tools it found and chains them together.
- The model never sees the full tool list, only the relevant subset. Studies claim **90%+** token savings, and you can add any number of servers without growing the context.
- This connects to the outcome-not-operations rule: in Code Mode the model writes the multi-step chain itself, in code, inside one call.

---

## Part 3 — Readings

### LangWatch, "The Context Tax: When to Compact"

**Main takeaway: long context costs far more than it looks, compact around 150k–250k for most work, and when unsure compact later rather than earlier.**

- **Why it's expensive.** Every agent step re-reads the whole window, so cumulative cost grows roughly as a power law (exponent ≈ 2.55). Doubling the context costs about **6×** as much. Caching makes each token about 10× cheaper but doesn't change the curve, because you still pay for every cached token on every step.
- **Most of the window isn't used.** The context actually needed per step stayed around **8k tokens** while the window grew about 16×. The used share fell from ~47% (under 50k) to ~2.5% (over 600k). This puts numbers behind lecture's claim that useful context is much smaller than advertised.
- **Compaction has a cost.** A median ~575k window was summarized to ~4.4k tokens (under 1% kept). Afterward, the user-correction rate rose from 17.7% to **41.9%** and stayed high for 30+ steps. Tool errors didn't increase, so the agent's *decisions* got worse while its calls kept working.
- **When to compact.** The cost-optimal point is about **220k** (anything from 170k to 316k is within 10%). Compacting too early is worse than too late (90k costs 1.79× the optimum). Letting a 1M window fill up is about 2.3× worse.
- **It depends on the work.** PR-driving: 200k–250k. Research: 250k–300k. Building and code understanding: 300k–450k, because they depend on exact earlier strings, and an edit has to match the old text character for character.
- **Practical levers:**
  - **Start subagents fresh instead of forking them.** A fork inherits the parent's full context (one example: 523k tokens vs. ~30k fresh). Two forks used about half of one day's tokens.
  - **Keep a verbatim tail**: preserve the last 30k–60k of raw context instead of only a short summary.
- **Caveat**: the data comes from one developer's usage, mostly on one codebase. The *shapes* (power-law cost, flat useful context, post-compaction spike) are more likely to transfer than the exact numbers.

### OpenSpec (openspec.dev)

**Main takeaway: make the spec a lasting, versioned artifact that you check the code against, not a one-time prompt.**

- A lightweight, open-source (MIT) spec framework that works inside Claude Code, Cursor, Codex, and other agents.
- Slash-command workflow: `/opsx:explore` → `/opsx:propose` → `/opsx:apply` → `/opsx:verify` → `/opsx:archive`.
- A proposal produces `proposal.md`, `specs/`, `design.md`, and `tasks.md`.
- It separates **validation** (does the spec describe the right thing?) from **verification** (does the code match the spec?).
- It's very close to RAPID: explore ≈ research, propose ≈ proposals + plan, apply ≈ implement, verify ≈ test/review. The extra pieces are `verify`, which checks the code against the spec explicitly, and `archive`, which keeps finished specs as a record.

### Superpowers (github.com/obra/superpowers)

**Main takeaway: a workflow made only of skills, where the skills trigger automatically and act as required steps, not suggestions.**

- A bootstrap skill (`using-superpowers`) loads at session start and tells the agent to check for a relevant skill before every task.
- Pipeline: **brainstorming** (questions, alternatives, design approved in sections, saved as a doc) → **using-git-worktrees** (an isolated branch with a clean test baseline) → **writing-plans** (2–5 minute tasks with exact paths, code, and checks) → **subagent-driven-development** (a fresh subagent per task, reviewed first for spec compliance, then for code quality) → **test-driven-development** (red-green-refactor; code written before its test is deleted) → **requesting-code-review** (critical issues block progress) → **finishing-a-development-branch**.
- Principles: TDD always, systematic over ad hoc, simplicity, **evidence over claims** (verify before saying it's done), YAGNI, DRY.
- Lecture named this as a well-known framework built on the same ideas as RAPID. The key difference is **who triggers the steps**:

| | Our RAPID skills | Superpowers |
|---|---|---|
| Triggering | Manual (`disable-model-invocation: true`) | Automatic, required |
| Testing | Separate review step at the end | TDD built into every task |
| Isolation | Clear context between stages | Git worktrees + fresh subagent per task |
| Review | One `review` pass over the diff | Two-stage review after each task |

### Cloudflare, "Enterprise MCP"

**Main takeaway: in a company, MCP needs a central control point (a portal or gateway) for auth, discovery, policy, logging, and cost, and Code Mode makes tool count stop affecting context size.**

- **Problems with MCP at company scale:** too many separate authorizations, prompt injection, supply-chain risk from unvetted *local* servers IT can't manage, employees unable to find approved servers, token bloat, and **shadow MCP** (unapproved remote servers IT never sees).
- **Cloudflare's architecture:**
  1. **Central remote servers** built from a template that comes with deny-writes-by-default, audit logs, CI/CD, and secrets management. The safe defaults come with the scaffold.
  2. **Access as the OAuth provider**: SSO, MFA, and device/location checks on every private server.
  3. **MCP server portals**: one place to connect that shows only the servers you're allowed to use, with central logging and data-loss-prevention (DLP) rules. Policies can limit tools per group (e.g. finance gets read-only tools).
  4. **AI Gateway** between client and LLM to switch providers and cap each user's tokens.
  5. **Shadow MCP detection** through hostnames, URL paths, and inspection of request bodies for JSON-RPC methods like `tools/call`.
  6. **Publish first-party public servers** behind a web application firewall (WAF) that checks for prompt injection.
- **Code Mode in practice**: the portal exposes just `portal_codemode_search` and `portal_codemode_execute`. In their test, 52 tools at about 9,400 tokens became 2 tools at about 600 tokens (**94% less**), and the cost stays flat as servers are added. This is the concrete version of Lec 4's Code Mode pattern.

---

## Connecting the two

| Concept | In `code/week2/` | In lecture / readings | Gap |
|---|---|---|---|
| Staged workflow | 6 skills ≈ RAPID | Lec 3 RAPID; OpenSpec; Superpowers | No dedicated **test** skill; `review` covers that stage |
| Stage boundaries | "no suggestions" / "do not implement" contracts | Clear context between steps | Skills don't tell you to clear context; that's up to the user |
| File-based handoff | `research/`, `plans/` | "Write to file and reingest"; OpenSpec's `proposal.md`/`tasks.md` | `implement` has a placeholder path (`/path/to/plan_md`) instead of taking the plan file as an argument |
| Two orthogonal proposals | `make-proposals` | Lec 3's PCA analogy | Skill says "up to two" in one place and "two or three" in another |
| Scope control | "Files Changed" with line numbers; "ONLY files impacted" | Name what's out of scope | Template has no explicit **Out of Scope** section, which lecture listed in the plan |
| Code review | One-agent `review` over the diff with severity markers | Lec 3: several subagents (security, perf, style...) + a combining agent; Superpowers: two-stage per task | Single pass, no subagents |
| Triggering | `disable-model-invocation: true` (human-driven) | Superpowers: automatic, required | A deliberate choice; human approval between stages is the point of RAPID |
| Testing | Template warns against excessive mocking | Superpowers: strict TDD | No TDD; tests are planned, not written first |
| Spec check | — | OpenSpec `/opsx:verify` | Nothing checks the finished code against the plan |
| Up-to-date docs | `research-codebase` → Context7 | Lec 4: MCP for live capabilities | — |
| Context budget | Progressive disclosure (`design_doc_template.md` loaded only when needed) | Code Mode; LangWatch compaction thresholds | — |

---

## Things to note / open questions

- **Compaction thresholds don't fully match.** Lec 3 said compact around **250K–450K**; LangWatch's cost-optimal point is about **220k**, with 150k–220k for general work and 300k–450k only for building/code understanding. Lecture also said "compact aggressively," while LangWatch says compacting *too early* is the more expensive mistake. Which threshold is the course's recommendation?
- **Is "useful context ≈ ½–¾ of the window" the same thing LangWatch measured?** LangWatch found only a small *share* of a large window was actually used per step. Those may be different measurements: how much the model can use well vs. how much a step needs.
- `implement/SKILL.md` is just "Implement the plan described in /path/to/plan_md," a literal placeholder. Is the user supposed to edit it, or pass the path as an argument when calling it?
- `make-proposals` contradicts itself ("up to two" vs. "two or three distinct proposals").
- Lecture's plan step includes **out-of-scope items**, but `design_doc_template.md` has no such section. It only says the Files Changed list is the "ONLY" files touched.
- No `test` skill exists in `code/week2/`. Is the "T" in RAPID covered by `review` plus the agent's own testing during implement?
- `explore` doesn't appear in RAPID's five letters. Is it a lighter alternative to `research-codebase` (briefing in chat, no file written)?
- Lec 4 previewed **MCP gateways** as a later topic; the Cloudflare portal/AI Gateway reading is an early look at it.
- Homework: build your own MCP server. Lec 4's design rules (outcome-shaped tools, typed args, specific errors, good names) are the checklist for it.
- Next week: a full lecture on agent skills.
