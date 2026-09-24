# Evals: functional-programming skill

These evals check whether the skill changes an agent's engineering decisions,
not whether the agent can recite FP facts. Every scenario is a realistic
request with a rubric that names concrete pass and fail signals. Four of the
seven scenarios (C, D, E, and part of F) exist to catch **over-application**:
performative FP that makes code harder to maintain.

## Layout

```text
scenarios/            one file per scenario: "## Prompt" (shown to the agent)
                      and "## Rubric" (hidden, used for grading)
routing.md            does the description load the skill at the right time?
build-prompts.sh      turns scenarios + a SKILL.md variant into agent prompts
results/              dated run logs with verbatim agent rationalizations
```

| ID | Language | Tests | Risk |
|---|---|---|---|
| A | TypeScript | Extract decisions from a service with global config, clock, analytics, DB | Under- and over-abstraction |
| B | Kotlin | `loading`/`success`/`error`/`data` flag state | Symptom-only fix |
| C | Java/Spring | Framework-required `@Service` with `@Transactional` | Fighting the framework, hand-rolled `Either` |
| D | Python | "Make it more functional" on a clear single-pass loop over a generator | `reduce`, multi-pass over a one-shot iterator |
| E | Go | Hot-path histogram with local mutation | Allocating "immutable" rewrites |
| F | C#/ASP.NET | Expected failures thrown as exceptions | Generic `Result`, wrapping infra errors, wrong exhaustiveness claims |
| G | Python | One-method strategy classes + factory | Missing the first-class-function simplification |

## Running

1. Build prompts for each variant you want to compare:

   ```bash
   bash evals/functional-programming/build-prompts.sh none /tmp/fp-evals/none
   bash evals/functional-programming/build-prompts.sh skills/functional-programming/SKILL.md /tmp/fp-evals/new
   # the skill before the local-reasoning rewrite
   git show e18b39d:skills/functional-programming/SKILL.md > /tmp/old-SKILL.md
   bash evals/functional-programming/build-prompts.sh /tmp/old-SKILL.md /tmp/fp-evals/old
   ```

2. Give each prompt file to a **fresh** agent (a subagent, `codex exec`, or
   `claude -p`) with no other context. One scenario per agent: seeing several
   scenarios together tips the agent off that some are traps.

3. Grade each answer against the scenario's rubric by reading it. Keyword
   counts are not enough: answers often mention `reduce` or `Either` only to
   reject them.

4. Record the verdict and any rationalization, quoted verbatim, in a new
   `results/YYYY-MM-DD.md`.

Run at least two repetitions per cell before drawing conclusions. Single
samples vary; the 2026-09-24 run has a scenario (C) that failed once and
passed once without the skill.

## When to run

- Before editing `SKILL.md`: run the baseline (`none`) and the current skill
  on the scenarios your edit targets. If the current skill already passes,
  the edit has nothing to fix.
- After editing: rerun the same scenarios and the routing check.
- When adding guidance: first add a scenario that fails without it.
