# CLAUDE.md

This repo holds coursework for Stanford's CS146S: working code plus markdown notes explaining the concepts learned each week.

## Structure

- `code/weekN/` — code for week N (exercises, starter code, whatever was worked on that week).
- `materials/weekN/` — raw source material (class notes, etc.). **Gitignored — never commit it.**
- `notes/weekN.md` — a markdown summary, in the student's own words, of the concepts covered in week N. Not a transcript — a distilled explanation of the ideas.
- `requirements.txt` — one shared, cumulative list of Python dependencies across all weeks. Append to it rather than creating per-week requirement files.

## Working style

When walking through code in this repo, act as a tutor: explain the underlying concepts (why the code is structured this way, what idea it's teaching), not just what each line does. Assume the student wants to build understanding, not just get a working answer.

## Writing a week's notes

When asked to write notes for week N, the student will already have put class notes in `materials/weekN/` and code in `code/weekN/`. Use `notes/week1.md` as the reference example.

1. **Read everything** in `materials/weekN/` and `code/weekN/`. If either folder is missing or empty, say so and work from what exists.
2. **Write `notes/weekN.md`** with this shape:
   - Title + a short intro naming the week's parts and the one theme that ties them together.
   - One part per source: concepts from the code (reference real function/variable names) and concepts from lecture (grouped by topic, not in lecture order).
   - A "Connecting the two" section — usually a table mapping code ↔ lecture concepts, including where the code falls short of what lecture describes.
   - "Things to note / open questions" at the end.
3. **Rules:**
   - Distill, don't transcribe. Explain *why*, and use tables where comparing things.
   - Don't invent content. If the materials only name a topic without details, leave it out and tell the student. If something is unclear, list it under open questions.
   - If `notes/weekN.md` already exists, keep the student's wording and add to it rather than rewriting.
   - Leave out transcript/meeting links and other personal links.
4. If the code uses new Python packages, add them to the root `requirements.txt`.
5. **Report back**: summarize the structure, list any gaps or topics you skipped, and ask the student to review. Don't commit until asked, and never stage `materials/`.

## Naming

Weeks are named `week1`, `week2`, ... with no zero-padding. If the course runs past week 9, lexicographic directory listing will sort `week10` before `week2` — consider switching to zero-padded names (`week01`) at that point if it becomes annoying.
