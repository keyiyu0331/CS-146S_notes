# CLAUDE.md

This repo holds coursework for Stanford's CS146S: working code plus markdown notes explaining the concepts learned each week.

## Structure

- `code/weekN/` — code for week N (exercises, starter code, whatever was worked on that week).
- `notes/weekN.md` — a markdown summary, in the student's own words, of the concepts covered in week N. Not a transcript — a distilled explanation of the ideas.
- `requirements.txt` — one shared, cumulative list of Python dependencies across all weeks. Append to it rather than creating per-week requirement files.

## Adding a new week

1. Create `code/weekN/` for that week's code.
2. Create `notes/weekN.md` summarizing that week's concepts.
3. If new Python packages are used, add them to the root `requirements.txt`.

## Naming

Weeks are named `week1`, `week2`, ... with no zero-padding. If the course runs past week 9, lexicographic directory listing will sort `week10` before `week2` — consider switching to zero-padded names (`week01`) at that point if it becomes annoying.
