#!/usr/bin/env bash
# Build eval prompts for one skill variant.
#
#   bash evals/functional-programming/build-prompts.sh <SKILL.md|none> <out-dir>
#
# Writes <out-dir>/<scenario-id>.md for each scenario (rubrics stripped) and
# <out-dir>/routing.md (skipped for `none`). Give each file to a fresh agent.
set -euo pipefail

skill=$1
out=$2
here=$(cd "$(dirname "$0")" && pwd)
mkdir -p "$out"

for scen in "$here"/scenarios/*.md; do
  id=$(basename "$scen" .md)
  {
    echo "You are a coding agent working in a user's repository."
    if [ "$skill" != none ]; then
      echo "Your harness decided the following skill applies to this task and loaded it. Follow it."
      echo "Supporting files it links to are in: $(cd "$(dirname "$skill")" && pwd) (read them only if the skill tells you to)."
      echo
      echo "<skill>"
      cat "$skill"
      echo "</skill>"
    fi
    echo
    echo "Respond as you would in a real session: make the change (show full new code for every changed file) and briefly explain it. Do not ask clarifying questions; state any assumptions. You cannot run code. Do not read any files other than those named above."
    echo
    echo "## User request"
    echo
    awk '/^## Prompt/{f=1;next} /^## Rubric/{f=0} f' "$scen"
  } > "$out/$id.md"
done

[ "$skill" = none ] && exit 0

desc=$(sed -n 's/^description: //p' "$skill")
{
  echo "You are a coding agent. Before starting a task you may load skills. You only see each skill's name and description:"
  echo
  awk '/^Skill list:/{f=1;next} /^## Tasks/{f=0} f' "$here/routing.md" |
    awk -v d="$desc" '{ sub(/\*\(description under test\)\*/, d); print }'
  echo "For EACH task below, treated independently as if it were the only user message, answer which skills (if any) you would load before starting. Output one line per task: '<number>: <skill names comma-separated or none>'. No other text."
  echo
  awk '/^## Tasks/{f=1;next} /^Pass:/{f=0} f' "$here/routing.md" | grep -E '^[0-9]+\.'
} > "$out/routing.md"
