---
name: new-week-materials
description: Set up the materials folder for the next course week by creating materials/weekN/ with two empty lecture files numbered after last week's (e.g. week3 has lec5.md, lec6.md, so the next week gets week4/lec7.md, lec8.md). Use when the user wants to prepare, set up, or start materials for a new week, or invokes /new-week-materials.
---

# New week materials

Run the script; it does all the work:

```bash
bash "$(git rev-parse --show-toplevel)/.claude/skills/new-week-materials/scripts/new_week.sh"
```

What it does:
- Next week = highest existing `materials/weekN` + 1.
- Lecture numbers continue from the highest `lec<K>.md` anywhere in `materials/` (two lectures per week).
- Stops with an error if the target week folder already exists; never overwrites.

Then tell the user the folder and file names it created.

Rules:
- `materials/` is gitignored. Never stage or commit anything in it.
- If the user says a week has a different number of lectures, or wants a specific week number, create the files by hand instead of running the script, following the same naming.
