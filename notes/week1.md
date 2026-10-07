# Week 1 — Coding Agents: The Loop and the Harness

Two layers this week:

1. **The loop** (Lec 1 + `code/week1/coding_agent_from_scratch.py`): the minimal engine of a coding agent.
2. **The harness** (Lec 2, "The Anatomy of a Modern Coding Agent"): everything built *around* that loop in a production agent like Claude Code.

Part 3 looks at real Claude Code prompts (`code/week1/prompts/`) to see what those harness pieces actually say to the model.

The recurring theme: almost every harness design choice is really a decision about **what goes into the context window**.

---

## Part 1 — The core loop

### Core idea

A "coding agent" is just an LLM in a loop: give it a system prompt describing available tools, let it request a tool call in a fixed text format, execute that tool locally, feed the result back in, and repeat until it responds without requesting a tool.

```
user → harness → LLM → tool call? → run tool → result back to LLM → ... → final answer → user
```

### Key pieces (from the code)

- **Tool registry** (`TOOL_REGISTRY`): a plain dict mapping tool name → Python function. Each tool is a normal function with a docstring and type-hinted signature — no special framework needed.
- **Auto-generated tool descriptions** (`get_tool_str_representation`, `create_full_system_prompt`): uses `inspect.signature` + the function's docstring to build the tool list text that gets injected into the system prompt. This keeps the prompt in sync with the code automatically.
- **Tool-call convention**: instead of a structured "function calling" API, the model is instructed to emit a single line of the form:
  ```
  tool: TOOL_NAME({"arg": "value"})
  ```
  using compact single-line JSON. This is a simple, model-agnostic alternative to provider-specific tool-calling APIs.
- **Parsing tool calls** (`extract_tool_invocations`): scans the assistant's text output line by line for `tool:` prefixes, splits out the tool name and JSON args, and silently skips malformed lines.
- **Feeding results back**: after running a tool, its result is appended to the conversation as a `user` message wrapped in `tool_result(...)`, so the next LLM call sees what happened.
- **The three example tools**: `read_file`, `list_files`, `edit_file` — the minimal set needed for an agent to inspect and modify a codebase. `edit_file` does a first-occurrence string replace (or full overwrite if `old_str` is empty), which is a simpler substitute for a diff/patch mechanism.
- **The agent loop** (`run_coding_agent_loop`): outer loop reads user input; inner loop repeatedly calls the LLM and executes any requested tools until the LLM produces a plain-text response with no tool calls.

---

## Part 2 — The harness

The **harness** is the software wrapped around the model: it assembles the prompt, exposes tools, runs them, and manages the context over time. Claude Code's harness includes: system prompt, config files (`CLAUDE.md` / `AGENTS.md`), tool list, plan mode, subagents, skills, hooks, and compaction.

### Tool lists

- Claude Code ships ~40 built-in tools. Categories: file access, shell, search (web + LSP), agent tasks, planning/isolation, scheduling (cron), artifacts, MCP resource listing, user interaction, skills.
- **MCP** (Model Context Protocol) servers plug in third-party tools (GitHub, Notion, Slack, ...). They're namespaced with an `mcp__` prefix so they're distinguishable from native tools.
- **Everything in a tool definition goes into the context** — name, description, docstring, argument types. This is exactly what `create_full_system_prompt` does in the week 1 code: the docstring *is* the documentation the model reads. So vague docstrings / loose types → worse tool use.
- **The scaling problem**: if every tool description is in the prompt, more tools = more tokens on every request. Early (2024) harnesses were bloated — e.g., a GitHub MCP server with ~110 tools. Claude's ~40-tool minimalism was a big step forward.
- **Trend**: fewer, heavier "Swiss Army knife" tools instead of many narrow ones. (Compare: our code's `edit_file` covers both "replace" and "create/overwrite" in one tool.)

### System prompt vs. `CLAUDE.md`

| | System prompt | `CLAUDE.md` / `AGENTS.md` |
|---|---|---|
| Who controls it | The harness (not the user) | The user / project |
| What it holds | Behavior, guardrails, environment info, memory format, available models, context-management rules | Project context: how to run tests, start the server, conventions |
| When injected | Every request | Alongside the system prompt |

- Claude Opus 5.5's system prompt is ~50 lines, down ~80% from earlier versions (~200–250 lines). The reason: more behavior is being **baked into the model weights** instead of spelled out in the prompt.
- Even so, tens of thousands of tokens are already used up before the user's first message arrives (system prompt + tools + config).
- `CLAUDE.md` vs. `AGENTS.md` is just naming — Anthropic used one, others used the other; you can symlink them.
- **Best practice for `CLAUDE.md`**: keep it minimal, give *exact* commands (test, run), don't over-constrain. Too many directives = "overfitting" the instructions, and performance gets worse.

### Plan mode

- A dedicated mode for scoping larger tasks before touching code. It's injected as a prompt block, and the model enters/exits it via explicit tools (`enter_plan_mode` / `exit_plan_mode`).
- Workflow: understand requirements → explore codebase (may spawn subagents) → design → review → write a plan file.
- Takeaway: even a "mode" is implemented as *prompt + tools* — the same primitives as the basic loop.

### Skills

- Written procedures (in `.md` files) for multi-step operations: several tool calls, scripts, prompts bundled together. Invoked proactively by the harness or explicitly by the user.
- **Progressive disclosure**: only the skill's short metadata sits in context upfront; the full content is loaded only when the skill is actually relevant.
- Contrast with MCP: MCP dumps every tool definition into every request; skills are much more context-efficient, and a skill is a more powerful abstraction than a single MCP tool call.

### Subagents

- Worker agents spawned by the main (orchestrator) agent. Each starts with a **fresh, independent context window** and returns only its result to the main loop.
- Benefits: **context isolation** (the parent doesn't absorb all the subagent's exploration noise) and **parallelism**.

### Compaction

- Summarizes a long conversation to shrink it; the summary replaces the original context. E.g., ~500k tokens → ~150k.
- Triggered automatically near the context limit, or manually.
- This directly addresses a gap in our week 1 code, where `messages` grows forever.

### Harness design principles

- Harness design is one of the hardest and most important problems in agent systems — not just for coding. Sales, legal, and support agents follow the same logic.
- **Core tension**: invest in the harness vs. invest in the model. The industry currently favors keeping the harness simple and letting the model do more.
- **The "dumb zone"**: LLM performance degrades as context grows. Bloated context → worse results.
- So **context engineering** is the job: trim MCP servers, shorten the system prompt, reduce tool count, use progressive disclosure (skills), isolate work (subagents), and compress history (compaction).

---

## Part 3 — Reading the real prompts

The professor shared five raw prompt blocks from a Claude Code session working on a small todo-app repo. Each one maps to a harness component from Part 2:

| File | Harness component | When it enters the context |
|---|---|---|
| `system_prompt.md` | System prompt | Every request |
| `tool_list.md` | Tool list | Every request |
| `config_files.md` | `CLAUDE.md` injection | Every request, next to the system prompt |
| `plan_mode.md` | Plan mode | Injected mid-conversation when plan mode turns on |
| `subagent_prompt.md` | Subagent task | The *first message* of a fresh subagent context |

### System prompt (`system_prompt.md`)

It's ~53 lines, which matches the lecture's "~50 lines" claim. Most of it isn't "how to code". It covers:

- **Identity + security policy**: a short paragraph on which security work is allowed and which is refused.
- **How the harness works**: output is rendered as markdown in a terminal; tools run under a user-chosen permission mode, so a denied call means "the user said no" and the model shouldn't retry the same call; hooks may intercept calls.
- **Trust boundaries**: the prompt tells the model which inputs carry authority.
  - *System messages* (system-reminders) are harness-controlled and can update rules.
  - *Tool results* are just data. They don't carry instructions.
  - Text pasted inside `<pasted_content>` tags may contain instructions the user didn't write, so the model should follow them only when the user's own message asks it to.
  This is a **prompt-injection defense** written directly into the prompt.
- **Tool-use etiquette**: prefer dedicated file/search tools over shell, run independent calls in parallel, cite code as `file_path:line_number`.
- **Behavioral norms**: match the surrounding code's style; default to they/them pronouns; **confirm before hard-to-reverse or outward-facing actions**; report outcomes faithfully (say when tests fail or a step was skipped).
- **Memory**: a file-based persistent memory. Each memory is one `.md` file holding one fact, with frontmatter (`name`, `description`, `type`: user / feedback / project / reference). An index file, `MEMORY.md`, is loaded every session, with one line per memory. This is **progressive disclosure again**: only the index sits in context, and full memories are read when relevant. The rules also say what *not* to save: anything the repo already records (code, git history, `CLAUDE.md`). Recalled memories count as background, not instructions, and the model should verify a memory before relying on it.
- **Environment**: current model IDs and the surfaces Claude Code runs on.
- **Context management**: the prompt *tells the model about compaction*, so it doesn't rush to wrap up as the context fills. It also says "when you have enough information to act, act", which pushes the model to be decisive instead of re-deriving things.

Takeaway: a modern system prompt is mostly about **operating safely inside a harness** (permissions, trust, memory, context). Coding ability is assumed to come from the weights.

### Tool list (`tool_list.md`)

- 36 built-in tools in 10 categories: Files, Shell, Search & code intelligence, Agents, Planning & isolation, Scheduling, Artifacts, MCP resources, Interaction, Design & review. This matches the lecture's "~40 tools".
- Our week 1 code's three tools (`read_file`, `list_files`, `edit_file`) correspond to the **Files** category. Claude Code splits editing into `Edit` (exact string replace, which is our `edit_file` with a non-empty `old_str`) and `Write` (create/overwrite, which is our `edit_file` with an empty `old_str`).
- Several harness features from Part 2 show up **as tools**: `EnterPlanMode` / `ExitPlanMode` (plan mode), `Agent` / `SendMessage` (subagents), `Skill` (skills), `EnterWorktree` (isolation). The model *calls* these to change its own mode, which is the "prompt + tools" point from Part 2.

### Config file injection (`config_files.md`)

- `CLAUDE.md` isn't just pasted in. It's wrapped in a preamble saying these instructions **override default behavior and must be followed exactly**, and it's labeled with its file path and "project instructions, checked into the codebase". The harness tells the model where the text came from and how much weight to give it.
- The example `CLAUDE.md` follows the lecture's best practice: a one-paragraph project overview, a file-structure map, **exact run commands**, and three short code-style rules. That's all.

### Plan mode (`plan_mode.md`)

- **Hard constraint first**: no edits, no non-read-only tools, no config changes or commits. The one exception is the plan file, at a path the harness assigns. The prompt says this "supersedes any other instructions".
- **Five phases**, which line up with the lecture's workflow:
  1. *Initial understanding*: launch up to 3 **Explore** subagents in parallel, but use the *minimum* needed (usually 1). Look for existing code to reuse.
  2. *Design*: launch **Plan** subagents, possibly with different perspectives (e.g. simplicity vs. performance vs. maintainability).
  3. *Review*: read the critical files yourself; clarify with `AskUserQuestion`.
  4. *Final plan*: write it to the plan file. It starts with a **Context** section (why this change), gives only the recommended approach, names the critical files and the existing functions to reuse, and ends with a **verification** section.
  5. *Call `ExitPlanMode`*.
- **Turn-ending rule**: the turn may only end with `AskUserQuestion` (to clarify requirements) or `ExitPlanMode` (to request approval). Asking "does this plan look OK?" in plain text is explicitly forbidden. This forces the approval step through a **structured tool** the harness can render and act on, instead of free text.
- Plan mode is built on subagents: exploration and design are delegated, so their noise stays out of the main context.

### Subagent prompt (`subagent_prompt.md`)

This is what the *orchestrator* wrote when it spawned a subagent to analyze the todo app's performance. Because the subagent starts with a **fresh, empty context**, the prompt has to stand on its own:

- **Hands over context explicitly**: the repo path plus a short summary of what each relevant file does (e.g. "every operation does `load_tasks()` then `save_tasks()`, no caching, no locking"). The parent compresses its own exploration into a few lines so the child doesn't have to redo it.
- **States constraints up front**: don't modify repo files, don't touch the user's real data file, put scratch files in a given scratchpad directory.
- **Defines the scope as a numbered list** (complexity, benchmarks, concurrency, growth, recommendations), and **bounds the cost** ("a few minutes max", "skip TS benchmarks unless cheap").
- **Specifies the return format**: summary table, measurements table, findings with `file:line`, prioritized recommendations, and *measured facts kept separate from inferences*.

The cost of context isolation: the subagent knows only what the parent writes down. A good subagent prompt reads like a well-written ticket handed to a colleague who has never seen the codebase. The required report format keeps what comes *back* into the parent's context compact and easy to use.

---

## Connecting the two: our code vs. a production harness

| Concept | In `coding_agent_from_scratch.py` | In Claude Code |
|---|---|---|
| Tool list in prompt | Auto-generated from docstrings/signatures | Same idea, ~40 native tools + MCP |
| Tool-call format | Text line `tool: NAME({...})`, parsed by hand | Structured tool-calling |
| Project config | None | `CLAUDE.md` / `AGENTS.md` |
| Long conversations | Unbounded `messages` list | Compaction |
| Big tasks | Single loop | Plan mode, subagents |
| Reusable procedures | None | Skills |
| Safety / permissions | `edit_file` writes anything, no confirmation | Permission modes; prompt says to confirm hard-to-reverse actions |
| Trust boundaries | Tool results are appended as plain `user` messages, so the model can't tell them apart from the real user | System messages vs. tool results vs. `<pasted_content>` have explicitly different authority |
| Persistent memory | None, everything is lost when the script exits | File-based memory with a `MEMORY.md` index loaded each session |

## Things to note / open questions

- No error handling around unknown tool names or missing required args (e.g. `TOOL_REGISTRY[name]` would raise `KeyError` if the model hallucinates a tool name).
- Conversation history grows unbounded — no summarization/truncation strategy yet. (→ compaction)
- Uses OpenAI's `responses.create` API with `max_output_tokens=5000`; model name in the script (`gpt-5.6-terra`) is illustrative/placeholder.
- Lecture mentioned checksums, hashes, and UIDs on objects "for security/validation" — unclear exactly which objects/where in the harness. Worth clarifying.
- If "more behavior in the weights" keeps shrinking system prompts, how much of the harness will eventually disappear?
- Plan mode's read-only rule appears only as prompt text in `plan_mode.md`. Does the harness also *enforce* it (e.g. by blocking write tools), or does it rely on the model obeying?
- `tool_list.md` is a condensed list with one line per tool. The real tool definitions sent to the model include full descriptions and parameter schemas, so how many tokens does the full tool list actually cost?
- The system prompt says system-reminders can arrive "mid-conversation". How and when does the harness inject them (e.g. plan mode, `CLAUDE.md`)?
