#!/usr/bin/env bash
# Create materials/week<N+1>/ with two empty lecture files, numbered after
# the highest lec<K>.md found anywhere under materials/.
set -euo pipefail

root="$(git rev-parse --show-toplevel)"
materials="$root/materials"
mkdir -p "$materials"

# Highest existing week number (0 if none).
last_week=$(find "$materials" -maxdepth 1 -type d -name 'week*' \
  | sed -E 's/.*week([0-9]+)$/\1/' | grep -E '^[0-9]+$' | sort -n | tail -1)
last_week=${last_week:-0}

# Highest existing lecture number across all weeks (0 if none).
last_lec=$(find "$materials" -type f -name 'lec*.md' \
  | sed -E 's/.*lec([0-9]+)\.md$/\1/' | grep -E '^[0-9]+$' | sort -n | tail -1)
last_lec=${last_lec:-0}

week=$((last_week + 1))
dir="$materials/week$week"

if [ -e "$dir" ]; then
  echo "error: $dir already exists" >&2
  exit 1
fi

mkdir "$dir"
echo "Created $dir"
for lec in $((last_lec + 1)) $((last_lec + 2)); do
  touch "$dir/lec$lec.md"
  echo "  lec$lec.md"
done
