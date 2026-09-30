# Week 1 — Coding Agents: The Loop and the Harness

Two layers this week:

1. **The loop** (Lec 1 + `code/week1/coding_agent_from_scratch.py`): the minimal engine of a coding agent.
2. **The harness** (Lec 2, "The Anatomy of a Modern Coding Agent"): everything built *around* that loop in a production agent like Claude Code.

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

## Connecting the two: our code vs. a production harness

| Concept | In `coding_agent_from_scratch.py` | In Claude Code |
|---|---|---|
| Tool list in prompt | Auto-generated from docstrings/signatures | Same idea, ~40 native tools + MCP |
| Tool-call format | Text line `tool: NAME({...})`, parsed by hand | Structured tool-calling |
| Project config | None | `CLAUDE.md` / `AGENTS.md` |
| Long conversations | Unbounded `messages` list | Compaction |
| Big tasks | Single loop | Plan mode, subagents |
| Reusable procedures | None | Skills |

## Things to note / open questions

- No error handling around unknown tool names or missing required args (e.g. `TOOL_REGISTRY[name]` would raise `KeyError` if the model hallucinates a tool name).
- Conversation history grows unbounded — no summarization/truncation strategy yet. (→ compaction)
- Uses OpenAI's `responses.create` API with `max_output_tokens=5000`; model name in the script (`gpt-5.6-terra`) is illustrative/placeholder.
- Lecture mentioned checksums, hashes, and UIDs on objects "for security/validation" — unclear exactly which objects/where in the harness. Worth clarifying.
- If "more behavior in the weights" keeps shrinking system prompts, how much of the harness will eventually disappear?
