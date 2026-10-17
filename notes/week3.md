# Week 3 — Agent Skills and Always-On Agents

Three parts this week:

1. **Skills** (Lec 5, "Agent Skills" + Cmux demo): what a skill is, the main kinds of skills worth building, and how to write and maintain them.
2. **Always-on agents** (Lec 6, guest lecture by Lee Robinson, "How Always-On Agents Work"): what changes when the harness from week 1 runs on a server for weeks instead of on a laptop for an hour.
3. **The readings**: three public skill libraries from lecture: browse.sh (per-website skills), Matt Pocock's `skills` (planning by "grilling"), and Cursor's `pstack` (rigor and verification).

There is no `code/week3/` this week, so there's no code part.

The theme connects to weeks 1–2: **load only what's needed, when it's needed, and make the agent prove its work.** Skills do this with progressive disclosure (only name + description stays in context). Always-on agents do it with tool search, subagents, files, and memory layers. Both lectures named verification as what lets you trust an agent enough to leave it alone.

---

## Part 1 — Agent skills (Lec 5)

### What a skill is

| | MCP tool (week 2) | Skill |
|---|---|---|
| Unit | One function with a schema | A procedure: instructions, guidelines, and scripts |
| Size | Small, single entry point | Can be long; may bundle files and scripts |
| What's always in context | Full tool definition (unless using tool search / Code Mode) | Only **name + 1–2 sentence description** |
| When the rest loads | — | When the description matches the task |

- **Progressive disclosure is the core mechanism.** The metadata snippet is always loaded. The full body is pulled in only when the agent decides the skill fits. That's why you can have dozens of skills without filling the context window. Week 2's `plan` skill did the same thing one level down, by keeping `design_doc_template.md` in a separate file.
- Because the description is the only part the agent sees when deciding, **the description decides whether the skill ever gets used.**

### Four kinds of skills

| Category | What it does | Lecture example |
|---|---|---|
| **Code understanding & planning** | Make the agent ask questions *before* building, so you correct less afterward | Matt Pocock's "Grill Me" (clarifying questions) and "Grill with Docs" (adds domain modeling: a glossary + ADRs) |
| **Verification** (*the most important*) | Let the agent test its own work in a loop: unit, integration, QA | Cursor's pstack: a meta-skill that writes a project-specific verification skill for your stack |
| **Code style** | *Declarative*: describe what the code should look like, not steps to follow | Rules for defining feature flags with PostHog (which object type, when). A few dozen of these load into AI code review and leave PR comments |
| **Specialized** | Per-domain know-how the agent would otherwise figure out the slow way | browse.sh: per-site browsing skills (Amazon search, Ticketmaster, Airbnb) |

- **Why verification matters most.** An agent that can check its own work doesn't need a human to look at every step. That makes the codebase "agent-ready" and makes running agents in parallel possible. Without verification, parallel agents just produce more unchecked work for you to review.
- **Declarative vs. procedural.** RAPID skills (week 2) are procedures: do X, then Y. Style skills describe what good code looks like and let the agent (or reviewer) apply it. The same rules can then guide both writing and reviewing.
- **Specialized skills save tokens.** Without a site skill, the agent has to explore a page's DOM to find what it needs. A skill gives it the answer up front, so it uses fewer tokens and costs less.

### Best practices for building skills

- **Keep each skill focused.** A bloated skill gets triggered at the wrong time and does worse when it is triggered.
- **Write the description carefully.** Include **trigger phrases** so the agent knows when to use the skill without being told.
- **Use scripts/CLI tools for deterministic steps.** If a step always works the same way, a script is more reliable than describing it in English.
- **Find candidates in your own chat history.** If you keep typing the same prompt, make it a skill.
- **Keep a personal library and sharpen it** ("sharpen your own knives"). Start general, personalize where needed, delete what you don't use. Lecture compared this to refactoring.
- **Revisit about monthly.** Codebases drift and skills go stale. Advanced teams automate this: a separate agent compares codebase changes against the existing skills and opens PRs to update them.
- **Measure with A/B tests**: run tasks with vs. without the skill. Lecture noted few teams actually do this.

### Cmux demo (guest: Austin, Cmux co-founder)

Cmux is an open-source terminal app for running many coding-agent sessions at once.

- **Built for many agents**: a vertical sidebar of sessions where finished agents move to the top (like iMessage).
- **Built-in browser** so agents can check their work against a live page.
- **Fully programmable**: anything a human can do in the terminal, an agent can do through the CLI.
- **Verification in practice**: a skill records a video of UI changes as an artifact. If the video looks right, the PR merges *without reading the diff*. This is the "verification lets you trust the agent" idea taken all the way.
- **Skills to fix outdated knowledge**: models default to older Swift/Apple APIs from their training data, so Cmux ships skills on current vs. deprecated APIs (e.g. concurrency). Same idea as week 2's Context7: don't trust the model's memory of a fast-moving library.
- Students will contribute to the Cmux repo as part of coursework.

---

## Part 2 — Always-on agents (Lec 6, Lee Robinson)

### From a harness to an always-on agent

Week 1's harness is a model calling tools in a loop, and it stops when you close the laptop. An always-on agent is the same loop, made persistent:

| | Simple harness | Always-on agent |
|---|---|---|
| Where it runs | Your machine | Cloud; survives crashes, restarts itself |
| Environment | Your shell | Its own Linux machine (desktop, browser, files, shell) |
| Triggered by | Your prompt | Slack, email, meetings, scheduled routines |
| Behavior | Answers every message | Decides when to stay quiet and when to report, like a colleague |
| Lifetime | Hours | Goal: weeks or months |

### Architecture: thin client, thick server

- **All heavy work lives on the server.** Updates ship without App Store releases, scaling follows established patterns, and the agent loop stays on the server so the VM can be rebuilt separately.
- **GrokBot's client has exactly one tool: `SendMessage`.** Shell, files, cloud agents, and screen recording all live on the server. A new surface (mobile, Slack, email) only has to implement that one tool. This is the M+N idea from MCP (week 2) applied to clients.
- **Infrastructure:**
  - **Durable workflows (Temporal) instead of plain job queues.** If step 7 fails, it resumes at step 7 instead of rerunning from step 1. This matters a lot when steps are expensive model calls.
  - **Firecracker VMs** are easy to snapshot, shut down, and restart.
  - **Message priority**: a user interrupt jumps the queue, and messages sent in quick succession are batched into one turn.

### Context engineering in the harness

- **Tool search**: only tool *names* go in every prompt; the model fetches the full schema from a file when it needs it. Same idea as skills' progressive disclosure and week 2's Code Mode.
- **Information retrieval ladder.** The agent tries each step before bothering the user:
  1. Conversation history
  2. Plugin / MCP server (e.g. Plaid for banking data)
  3. Web search
  4. Computer use (browser, scripts on the VM)
  5. Ask the user
- **Keep the main conversation sparse.** Send expensive tool calls and screenshots to subagents, which return only the result. None of their intermediate work enters the main context.
- **Harness tips** and the reason for each:

| Tip | Why |
|---|---|
| Don't add or remove tools between turns | Changing tool definitions breaks the prompt cache |
| Keep tool descriptions/schemas short | They're paid for on every call |
| Send long outputs to a file, not the context | Agents read files well; the context stays small |
| Keep system prompt + tool definitions static | Maximizes cache hits; only the newest message pays full price |
| Warm the cache when the user starts typing | The cache is ready by the time they send |
| Compact while the cache is still warm | Summarizing from a cached context is cheaper than after it expires |

### Memory and compaction

Memory is layered by how long each piece stays relevant:

| Layer | Contents | In every prompt? |
|---|---|---|
| **Profile** | Core facts about the user (e.g. "prefers lowercase messages") | Yes |
| **Log** | Dated history of past conversations | No; searched |
| **Notes** | Short-term scratchpad, relevant for the next 30–60 min | While relevant |
| **Everything else** | Files on the machine | Retrieved on demand via file search / shell |

- **Compaction is lossy**, and getting the algorithm right is hard (week 2's LangWatch reading measured how much worse an agent does after compaction). Compacting while the cache is warm keeps it cheap; the user then continues from the summary.
- **Subagents give effectively unlimited context.** Each one starts with a fresh window, reports only its result, and runs as its own durable workflow, so a crash doesn't lose its work.

### Security

- **Auto-review**: a separate model checks every shell command. Lecture argued this is often more reliable than a tired human clicking "approve."
- **Untrusted inputs aren't instructions.** Emails and webhooks are data. Treating them as commands is a prompt-injection hole, and an agent triggered by email is exposed to this constantly.
- **Irreversible actions need explicit approval** (sending email or Slack messages).
- **Secrets stay out of the conversation entirely.**

### Training flywheel and what's next

- **Inner loop** (fast): find a bug → fix the harness/prompt → check it in evals → ship.
- **Outer loop** (every few months): a new model trained on the collected failures does better on evals, and each jump in model capability makes new product behavior possible.
- **Predictions for the next 6–12 months**: agents running for weeks or months; better long-term memory recall (graphs, files, or something new); speech-to-speech becoming common; models learning skills on the job and saving them as reusable files. Evaluating month-long runs against monthly model releases is still unsolved.
- **"Delete the product"** (Cursor / SpaceX): assume today's models are the worst they'll ever be. Build as little as possible and keep the interface simple, so it can be rebuilt in 6 months.

---

## Part 3 — Readings

### browse.sh

**Main takeaway: a public catalog of per-website skills plus a browser CLI, so agents don't have to work out each site from scratch.**

- Install with `npm install -g browse`. It drives a browser (click, scroll, type, hover, press), streams network/console output for debugging, and runs locally or on Browserbase cloud sessions (`browse cloud`).
- **Each skill is a `SKILL.md` for one task on one site** (`browse.sh/skills/<domain>/<slug>.md`). It defines inputs (URL, ID, query) and structured outputs, usually JSON.
- **API first, browser second.** Many skills use a public API or data endpoint when one exists and only fall back to driving the page. This is the "prefer scripts for deterministic steps" rule from lecture.
- **Safety written into the skill**: many are explicitly read-only ("never books," "never checks out").
- **Failure is documented too.** Skills record anti-bot walls (Akamai, PerimeterX, Imperva), dead sites, and labeled outcomes (zero results, bot block, not found), so the agent can tell "no results" apart from "blocked."
- **Built for agent discovery**: `llms.txt` (short index) and `llms-full.txt` (full skill text). This is progressive disclosure at the catalog level.
- Covers travel, shopping, jobs, government data, health, and reference sites.

### Matt Pocock, `skills` ("Skills for Real Engineers")

**Main takeaway: small, composable skills that keep you in control. The headline technique is "grilling": the agent interviews you until the plan has no open questions.**

- **Against big frameworks.** He argues frameworks like Spec-Kit take over the whole process, which takes control away from you and makes problems hard to fix. His skills are meant to be small and easy to adapt.
- **Four failure modes and the fix for each:**

| Failure | Fix |
|---|---|
| Misalignment: builds the wrong thing | Grilling before work starts |
| Verbosity: too many words | A shared domain language (glossary) |
| Broken code: working blind | Feedback loops: static types, browser access, red-green-refactor tests |
| Ball of mud: agents speed up entropy | Care about design; deep modules |

- **Grilling** is a reusable primitive (`grilling`) used by several skills:
  - `/grill-me`: interviews you about a plan until every branch of the design is settled. For non-code topics.
  - `/grill-with-docs`: the same interview, plus sharpening terms and writing decisions to `GLOSSARY.md` and **ADRs** (Architecture Decision Records) as they come up.
- **Why a glossary helps.** "There's a problem with the materialization cascade" is shorter and clearer than describing the whole idea every time, *if* the agent knows the term. Consistent names also make the code easier for agents to search.
- **User-invoked vs. model-invoked.** User-invoked skills orchestrate work (`/to-spec`, `/to-tickets`, `/implement`, `/triage`, `/retro`). Model-invoked skills are building blocks the agent can pick up on its own (`tdd`, `diagnosing-bugs`, `code-review`, `domain-modeling`). A user-invoked skill can call model-invoked ones, but not other user-invoked ones. This is the same distinction as week 2's `disable-model-invocation: true`.
- Other skills that match lecture: `/handoff` (compact a conversation into a doc for another agent), `/retro` (suggest improvements to the agent's environment after a session, i.e. sharpening your knives), `writing-for-agents` (how to write skills and CLAUDE.md files).

### Cursor, `pstack` (by Poteto)

**Main takeaway: skills aimed at rigor, not speed. Agents are expected to prove their work against the real app, and that's what makes running many agents in parallel safe.**

- Motto: "if you want to go fast, go deep first." The goal is less code that's better, not more output.
- **Entry point `/poteto-mode`** reads the task and picks one of 23 playbooks (bug fix, perf, refactor, hillclimb, babysit a PR, autonomous run...), calling other skills as needed.
- **No planning skills on purpose**: "the best spec is code." This contrasts with RAPID (week 2) and grilling, which both put planning first.
- **The verification meta-skill**, `/create-verification-skill`:
  1. **Investigates the repo**: what the user-facing surface is, how to start the app, how an agent can drive it, what evidence can be captured. It asks you only what it can't find out itself.
  2. **Writes `verify-<app>/SKILL.md`** with sections for Launch, Doctor (is the running app usable?), Drive, Evidence, Cleanup, and Helpers.
  3. **Seeds a feature map**: 3–5 files, one per key feature, each covering how to reach it, how to drive it, what the end state looks like, and gotchas.
  4. **Proves it** by running the generated skill once. A skill that has never been run counts as a draft.
  - Rules: drive the real user path (not test-only endpoints), check side effects (files, rows, messages), never weaken a test to make it pass.
  - `/maintain-verification-skill` fixes the feature map when it drifts from the app. This is lecture's "revisit skills monthly," as a skill.
- **Using multiple models**: `/setup-pstack` assigns models to roles (by default, routine code work goes to Grok and the hardest changes and judgment calls go to Opus). `/interrogate` has different models try to break a diff, and `/arena` runs several attempts and merges the best parts.
- **Fixing mistakes where they start**: `/correct` finds recurring agent mistakes and fixes each at the strongest level that works: architecture first, then types/lint/CI, then tests, with docs last. A rule written only in docs is the easiest for an agent to ignore.
- **Principles as small skills** (24 of them, e.g. `prove-it-works`, `guard-the-context-window`, `subtract-before-you-add`), indexed by `/poteto-mode` and read at the start of each task.

---

## Connecting the two

No code this week, so this table maps the lecture ideas to the readings and to last week's skills in `code/week2/`.

| Concept | Lecture | Readings | Week 2 code | Gap / tension |
|---|---|---|---|---|
| Progressive disclosure | Lec 5: name + description always loaded; Lec 6: tool search | browse.sh `llms.txt` → `llms-full.txt`; pstack's principle index | `plan` → `design_doc_template.md` | — |
| Planning before building | Lec 5: Grill Me / Grill with Docs | Pocock's grilling | RAPID research → proposals → plan | pstack says "the best spec is code" and has no planning skills |
| Verification | Lec 5: most important category; Cmux video artifacts | pstack `create-verification-skill` + feature map | `review` reads the diff | Week 2 has no skill that *runs* the app; review is static |
| Declarative style rules | Lec 5: PostHog feature-flag skills feeding AI review | Pocock's `codebase-design`; pstack's principles | `review` severity markers | Week 2 has no style skills |
| Deterministic steps as scripts | Lec 5 | browse.sh: API first, browser fallback | Skills are all prose | — |
| Skill upkeep | Lec 5: monthly refactor; agent-proposed PRs | pstack `/maintain-verification-skill`, `/reflect`, `/correct`; Pocock `/retro` | — | Nothing in the repo yet for noticing stale skills |
| Who triggers a skill | — | Pocock: user- vs. model-invoked | `disable-model-invocation: true` everywhere | — |
| Keep main context small | Lec 6: subagents, long outputs to files | Pocock `/handoff`; pstack `guard-the-context-window` | RAPID's file handoffs | — |
| Outdated model knowledge | Lec 5: Cmux Swift API skills | — | Context7 in `research-codebase` | — |
| Safety on actions | Lec 6: approve irreversible actions; untrusted input ≠ instructions | browse.sh: read-only, "never books" | — | — |

---

## Things to note / open questions

- **Names in the class notes don't match the sources.** The notes say "Matt Bookholt"; the repo is Matt Pocock's. They say "Potato Stack (Lauren, Cursor)"; the repo is `pstack` by Poteto. The logistics section says "Leslie Robinson"; the Lec 6 title says Lee Robinson. These look like transcription errors. I used the names from the sources.
- **Does the verification meta-skill interview you?** Lecture said it interviews you about your stack. The actual `create-verification-skill` mostly investigates the *repo* and asks you only what it can't find itself.
- **browse.sh token savings.** Lecture said per-site skills cut tokens and cost. The part of the browse.sh page I read (the first ~100k of ~187k characters) makes no such claim. Lecture also said browse.sh is by Browserbase; the page shows Browserbase as the cloud provider but doesn't name an author.
- **Glossary filename.** Lecture said `glossary.md`; the repo uses `GLOSSARY.md` (formerly `CONTEXT.md`).
- **Plan first, or code first?** RAPID and grilling put planning before code; pstack has no planning skills and recommends the editor's plan mode instead. Is either one the course's recommendation, or does it depend on the task size (the week 2 table)?
- **"Merge without reading the diff"** (Cmux) depends completely on how good the verification is. What does the course say about where that's safe vs. not?
- **GrokBot**: lecture's next step is to try the open-source GrokBot fork on GitHub, but the notes give no link. pstack has a `/make-bot-ui` skill for a "Grok Bot," which may be related.
- **Compaction advice adds up.** Lec 6 says compact while the cache is warm; week 2's LangWatch said compacting too early is the bigger mistake. Together: compact late, but before the cache expires.
- Lec 6 suggested going deeper on LLM training basics; the notes don't say which material.
- Cmux contributions are part of coursework; details weren't in the notes.
