# Week 1 — Building a Coding Agent from Scratch

Draft notes based on `code/week1/coding_agent_from_scratch.py`. Expand with anything covered in lecture that isn't captured here.

## Core idea

A "coding agent" is just an LLM in a loop: give it a system prompt describing available tools, let it request a tool call in a fixed text format, execute that tool locally, feed the result back in, and repeat until it responds without requesting a tool.

## Key pieces

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

## Things to note / open questions

- No error handling around unknown tool names or missing required args (e.g. `TOOL_REGISTRY[name]` would raise `KeyError` if the model hallucinates a tool name).
- Conversation history grows unbounded — no summarization/truncation strategy yet.
- Uses OpenAI's `responses.create` API with `max_output_tokens=5000`; model name in the script (`gpt-5.6-terra`) is illustrative/placeholder.
