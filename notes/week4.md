# Week 4 — Customizing the Agent, and Building for the Next Model

Two parts this week:

1. **Customizing your agent setup** (Lec 7): the ways to extend a coding agent (APIs, MCP, skills, `agents.md`, hooks, subagents) and which MCP servers are worth adding.
2. **Fireside chat with Boris Cherny, creator of Claude Code** (Lec 8): how Claude Code was built, how Anthropic now verifies agent-written code, and where he thinks software is heading.

There is no `code/week4/` this week, so there's no code part.

The theme: **the human's job moves from writing code to setting up the environment the agent works in, and checking what it produces.** Lec 7 covers the setup side: what the agent sees (`agents.md`), what it can reach (MCP), and what runs automatically around it (hooks). Lec 8 covers what follows once that works: code output goes up ~10x, so reviewing becomes the bottleneck and gets automated too.

---

## Part 1 — Customizing your agent setup (Lec 7)

### APIs vs. MCP vs. skills

| | API | MCP | Skill |
|---|---|---|---|
| What it is | An HTTP/REST/GraphQL service interface | A standard protocol for agents to call external services as tools | A procedure: prompts plus tool/API calls for longer, multi-step work |
| Built for | Developers writing code | Agent runtimes, not really human developers | Agents doing complex tasks ("a recipe") |
| Who deals with auth, retries, pagination | The caller | The protocol and the server | Whatever the skill calls underneath |

- These are layers, not competitors. A skill can call an MCP tool, and the MCP server calls an API.
- **Browser use** doesn't sit in one column. It can be done through a CLI/API or through an MCP server.

### Why MCP matters

Week 2 covered what MCP is. This lecture listed what you get by using it instead of calling an API yourself:

- **Auth**: OAuth is part of the protocol, so there are no plain-text API keys in `.env` files.
- **Versioning**: the third-party server handles packaging, so upgrading or downgrading is easy.
- **Portability**: any MCP client works with any MCP server.
- **Sandboxing (remote MCP)**: the tool runs on the server, not on your machine, so a prompt-injected call can't touch your local files.
- **Backwards compatibility** is mostly fine on the server side. One caveat: models were trained on older protocol versions, which can cause small oddities.

### `agents.md`: a README for agents

- Every major coding harness loads `agents.md` into context at startup, so it has become the de facto standard (agents.md). `CLAUDE.md` is now largely the same thing, and lecture said Anthropic eventually adopted `agents.md` too. (Week 1 said you can symlink one to the other.)
- **Typical sections**:
  - Project overview / codebase map: points the agent to the right directories.
  - Build and test commands: the project-specific ones (pnpm, Maven vs. Gradle).
  - Code style guidelines.
  - Testing instructions: how to start the app and run e2e or smoke tests.
  - Security boundaries: e.g. never commit API keys to certain file types.
- **Keep it short**, under ~300 lines as a soft limit. The root file goes into *every* agent's context, subagents included.
  - The test for each line: *"Does this apply to an agent three levels deep in a random subdirectory?"* If not, move it or cut it.
  - Don't put code snippets in it. They go stale and make the file longer.
- **Large repos: nest them.** The root `agents.md` works as a router that points to per-directory files. Those hold the commands and rules for their own directory. Agents walk the tree and attach each file's content to its path. This is progressive disclosure again (weeks 1–3): a directory's rules load only when the agent works there.
- **It's a prompt, not the source of truth.** If `agents.md` is out of date, the agent finds information that conflicts with the code. It then either goes in circles or trusts the code. Best practice: **check `agents.md` against the codebase in CI**, daily or weekly. (Week 3 said the same about skills going stale.)
- Having an agent write the first draft is fine, but always edit it yourself.

### Hooks, skills, and subagents

| | Hooks | Skills | Subagents |
|---|---|---|---|
| What it is | A script that runs at fixed points in the agent lifecycle | A procedure the agent loads when relevant | A separate agent with its own fresh context window |
| Deterministic? | **Yes**: the harness runs it, not the model | No: the model decides to use it and follows it | No |
| When it runs | Pre-tool-use, post-tool-use, stop (end of run) | When the description matches the task | When the main agent delegates |
| What comes back | Pass/fail, or output the agent sees | — | Only the final result |

- **Hooks** are for things that must happen every time, which you shouldn't leave to the model's memory. Examples: cleaning up prompts, blocking sensitive actions, linting and formatting.
  - *Stop hook*: run the full pre-commit suite when the agent finishes. If it fails, the agent keeps going until every check passes. This makes verification automatic.
  - *Boris's setup*: a post-tool-use hook runs the Bun formatter after every tool call. Formatting problems get fixed one at a time as they appear, instead of all at once in a slow pre-commit run.
- **Skills**: only a recap this lecture (covered in weeks 2–3).
- **Subagents**: the main use is exploring and summarizing a large codebase without filling the main context. Because only results come back, you can keep delegating and keep running, which gives an "infinite context" illusion. Boris's examples: a CodeSimplifier subagent and an app-verification subagent.
- **The overlap is fine.** You could build a verifier as a hook, a skill, or a subagent. Lecture said having more than one way to do something is acceptable.

### Recommended MCP servers

| Area | Servers | What the agent gets |
|---|---|---|
| Project management | Linear, Jira | Read and write issues, update tickets |
| Documentation | Notion, Confluence | Specs and user journeys |
| **Observability** | Datadog, Sentry | Lecture called this "probably one of the biggest productivity boosts" for any team. Example: diagnosing a 3am incident without digging through logs yourself |
| Database | Postgres, Redshift | Reading data. **Don't give it write access to production databases** |
| Technical docs | Context7, Exa | Current API docs and library versions (the same reason as week 2's Context7) |
| ML experiment tracking | Arize | Tracking LLM/ML experiments |

---

## Part 2 — Boris Cherny on building Claude Code (Lec 8)

### How Claude Code started

- His first internal demo, posted to Slack, got two reactions.
- **The moment it clicked**: he gave Claude a bash tool and asked "what music am I listening to?" Claude wrote AppleScript to ask the music player and answered. This is the week 1 loop (model + one tool) doing something nobody programmed it to do.
- He then spent six months working on it every night and weekend.
- **Terminal-only on purpose**, so he didn't have to build a UI.
- **It still uses the public Anthropic API**: no secret models or endpoints. Using the same API as customers gives the team a tight feedback loop and lets them improve it every week. His lesson: *the only way to make infrastructure good is to build a product on top of it.*

### Small teams and constraints

- Claude Code started as one person, who spent months asking for even one more engineer.
- **Why small teams work**:
  1. You have to cut the right corners and stay focused on the one hypothesis you're testing.
  2. You have to use Claude to automate everything: coding, code review, design review, collecting user feedback.
- The contrast was Facebook. When Zuckerberg cared about a project, the question was why not put 150 engineers on it instead of 80.
- Every new hire asked for a desktop or web app, and the team stayed terminal-only for six months anyway. *"Prioritization is saying no to good ideas."* He compared it to Twitter's 140-character limit: constraints drive creativity.

### Verification: making agent code trustworthy

- Code output per engineer went up **~10x** after Claude Code came in internally.
- **The bottleneck moved from writing code to reviewing it.** Engineers started approving PRs without reading them.
- **Automated code review**: Claude was backtested against past incidents and catches nearly every bug before production. A faster, cheaper version that catches more was announced the day of the lecture.
- **The pipeline being built**: one Claude writes the code, a second reviews it, and a third merges it. The merge rate is estimated above 90%.
- **Two layers of verification**:

| Layer | What it is | Example |
|---|---|---|
| Traditional | Tests, linting, end-to-end runs against real systems | iOS simulator, calling live services, **no mocks** |
| Formal | Model tricky code mathematically and search for counterexamples | Lean and TLA+ for stateful or concurrent code; each counterexample is then reproduced as a bug in the real code |

This is the same point weeks 3–4 kept making: verification is what lets you trust an agent's work without a human checking every line.

### Latent demand and product thinking

- **Latent demand**, which he called the most important idea in product: like *desire paths* on a lawn. Let people walk first, then pave where the dirt path forms. Watch what users already try to do, and build that.
  - Example: they merged the chat and cowork tabs after a Venn diagram showed most users used both.
- **Everything should be both a product and a platform.** Example: the new "mods" feature. Users ask Claude to make custom UI elements (e.g. a thumbs-up button), and those persist across desktop, CLI, Slack, VS Code, and soon mobile.
- **Build for the model six months ahead**:
  - Claude Code launched in February and revenue stayed flat (~$40M) for months. It took off when Opus 4 and Sonnet 4 shipped in May.
  - Claude Tag (an agent coworker in Slack) was built for Fable before Fable existed, and didn't work until that model came out.
  - **How to guess what will improve**: read agent transcripts, find where the model fails, and assume those cases will get better. This was the lecture's one action item: **read agent transcripts regularly.**

### The bigger picture

- **The printing press analogy**:
  - Before it: 5–10% of Europe could read. Scribes copied religious texts, and ink and paper were too expensive for creative work.
  - After it: more literature in 50 years than in the previous 1,000, and books got ~100x cheaper.
  - The real gain wasn't literacy itself. It was what literacy made possible: the Renaissance and the Industrial Revolutions.
- **Coding is on the same path.** As the tool spreads, the value goes to domain experts, not to coders. *"The best accounting software in 2027 will be built by an accountant, not an engineer."* *"The best CRM will be built by a salesperson."*
- **What still needs humans**: system design, UI taste, and deciding what to build next. His estimate is that Claude passes humans on these within 6–12 months.
- **Hiring has changed**: curiosity, generalist thinking, product and business sense, accountability, and proactivity matter most. Coding ability is now secondary.

---

## Connecting the two

No code this week, so this table maps the lecture ideas to earlier weeks and to this repo's own setup (`CLAUDE.md`, `.claude/skills/new-week-materials/`).

| Concept | Lec 7 | Lec 8 | Earlier weeks | This repo | Gap / tension |
|---|---|---|---|---|---|
| Project instructions for the agent | `agents.md`: short, a router, checked in CI | — | Week 1: keep `CLAUDE.md` minimal, exact commands | Root `CLAUDE.md`: structure, workflow, naming | Single file with no nesting (fine at this size); nothing checks it against the repo |
| Progressive disclosure | Nested `agents.md` per directory | — | Weeks 1–3: skills, tool search | The skill's body loads only when invoked | — |
| Deterministic automation | Hooks (pre/post-tool, stop) | Bun formatter after every tool call | Week 3: use scripts for deterministic steps | `new_week.sh` does the work instead of prose steps | No hooks set up in this repo |
| Verification | Stop hook runs pre-commit until it passes | Write/review/merge pipeline; tests with no mocks; Lean/TLA+ | Week 3: verification is the most important kind of skill | — | No tests or checks in this repo yet |
| Context isolation | Subagents for exploring; "infinite context" | CodeSimplifier and verification subagents | Weeks 1, 3: subagents, compaction | — | — |
| External tools | Recommended MCP servers; no prod DB writes | — | Week 2: MCP design, Context7 | — | — |
| Instructions going stale | Validate `agents.md` in CI | — | Week 3: revisit skills monthly | — | Who maintains it in practice: a human, an agent, or CI? |
| Reading transcripts | — | Read transcripts to find model failures | Week 1: reading real Claude Code prompts | — | — |

---

## Things to note / open questions

- **Names that look like transcription errors.** Lec 7 calls Boris Cherny the "creator of Bolt/PlotCode", but Lec 8's title says creator of Claude Code. I used Claude Code. Lec 7 also credits the "infinite context" idea to "the Grok team", which may be a mis-transcription.
- **`agents.md` vs. `CLAUDE.md`.** Lecture said Anthropic "eventually adopted agents.md", but this repo (and week 1's example prompts) still use `CLAUDE.md`. Does Claude Code read `agents.md` directly now, or do you still need a symlink?
- **Validating `agents.md` in CI**: what does the check actually look like? An agent comparing the file to the code, or scripted checks that the listed commands still run?
- **Hooks that loop.** A stop hook that runs pre-commit "until all checks pass": what stops it from looping forever if the agent can't fix a failure?
- **The Claude write/review/merge pipeline.** If merges are automated, where does a human still sign off? This is a stronger version of week 3's "merge without reading the diff" question.
- **Formal verification.** The notes only name Lean and TLA+. How much effort does modeling a piece of code take, and when is it worth it?
- **Skipped**: Lec 7 only says skills were a recap, so there's nothing new on skills here. Arize got one line and I didn't add more. I also left out logistics (project deadlines, room change) and the transcript links.
- Several of Boris's numbers (10x output, >90% merge rate, ~$40M flat revenue, 6–12 months until Claude passes humans on design and taste) are his claims or estimates as reported in the notes, not checked figures.
