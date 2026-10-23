# Evals: functional-programming skill

These evals check whether the skill changes an agent's engineering decisions,
not whether the agent can recite FP facts. Every scenario is a realistic
request with a rubric that names concrete pass and fail signals. Four of the
eight scenarios (C, D, E, and part of F) exist to catch **over-application**:
performative FP that makes code harder to maintain. Scenario H catches the
opposite drift, **over-correction**: refusing a small generic `Result` with
`flatMap` where several steps share one expected-failure channel.

Rubrics fail an answer for misuse of a construct, not for its identity. A
`Result`, `Option`, dependency record, or `pipe` is a fail signal only where
the rubric says why it adds no contract in that scenario.

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
| A | TypeScript | Extract decisions from a service with global config, clock, analytics, DB | Under- and over-abstraction, collapsing the two clock reads |
| B | Kotlin | `loading`/`success`/`error`/`data` flag state | Symptom-only fix |
| C | Java/Spring | Framework-required `@Service` with `@Transactional` | Fighting the framework, a generic `Either` for one decision, fixing a latent bug in passing |
| D | Python | "Make it more functional" on a clear single-pass loop over a generator | `reduce`, multi-pass over a one-shot iterator |
| E | Go | Hot-path histogram with local mutation | Allocating "immutable" rewrites |
| F | C#/ASP.NET | Expected failures thrown as exceptions | A generic `Result` for one operation, wrapping infra errors, wrong exhaustiveness claims, rules left between I/O calls |
| G | Python | One-method strategy classes + factory | Missing the first-class-function simplification |
| H | TypeScript | Five steps, two handlers, three failure conventions | Refusing a shared `Result`/`flatMap`; copying early returns per handler |

## Running

1. Build prompts for each variant you want to compare:

   ```bash
   bash evals/functional-programming/build-prompts.sh none /tmp/fp-evals/none
   bash evals/functional-programming/build-prompts.sh skills/functional-programming/SKILL.md /tmp/fp-evals/new
   # the skill before the local-reasoning rewrite
   git show e18b39d:skills/functional-programming/SKILL.md > /tmp/old-SKILL.md
   bash evals/functional-programming/build-prompts.sh /tmp/old-SKILL.md /tmp/fp-evals/old
   # the local-reasoning skill (PR #19), before the explicit-contracts revision
   mkdir -p /tmp/lr-skill/references
   git show c5a3a6e:skills/functional-programming/SKILL.md > /tmp/lr-skill/SKILL.md
   git show c5a3a6e:skills/functional-programming/references/language-adaptation.md > /tmp/lr-skill/references/language-adaptation.md
   bash evals/functional-programming/build-prompts.sh /tmp/lr-skill/SKILL.md /tmp/fp-evals/lr
   ```

   Put a historical `SKILL.md` in a directory with its `references/` copy;
   the prompt tells the agent where the supporting files are.

2. Give each prompt file to a **fresh** agent with no other context, run
   outside this repository as described under "Isolation" below. One
   scenario per agent: seeing several scenarios together tips the agent off
   that some are traps.

3. Grade each answer against the scenario's rubric by reading it. Keyword
   counts are not enough: answers often mention `reduce` or `Either` only to
   reject them.

4. Record the verdict and any rationalization, quoted verbatim, in a new
   `results/YYYY-MM-DD.md`.

Run at least two repetitions per cell before drawing conclusions. Single
samples vary; the 2026-09-24 run has a scenario (C) that failed once and
passed once without the skill.

## Isolation

Run the agents from an empty directory outside this repository. Claude
Code loads `CLAUDE.md` and `AGENTS.md` from the working directory and its
parents, and subagents spawned from a session here inherit them. This
repository's `AGENTS.md` states the skill's thesis and what scenario H
rewards. The lr skill passed H 2 of 2 as in-repo subagents and failed 2 of
2 run in isolation (`results/2026-10-23.md`). Check any other harness the
same way.

The `claude -p` setup used on 2026-10-23, with Claude Code 2.1.309:

```bash
cd "$(mktemp -d)"   # no CLAUDE.md, AGENTS.md, or .claude here or in any parent
claude -p --model <full model ID> --setting-sources project \
  --disable-slash-commands --strict-mcp-config --tools Read \
  --no-session-persistence --output-format stream-json --verbose \
  [--add-dir <copy of the skill directory>] < prompt.md
```

- `--setting-sources project` in an empty directory skips user settings,
  so user plugins and their hooks stay off. `--disable-slash-commands`
  removes skills, and `--strict-mcp-config` removes connected MCP servers.
  None of these flags stops `CLAUDE.md` from loading; only the working
  directory does. `--bare` isolates further but accepts only
  `ANTHROPIC_API_KEY` auth.
- Build skill-variant prompts from a copy of the skill directory outside
  the repository, as step 1 does for `old` and `lr`, so the supporting-files
  path and `--add-dir` stay outside it too.
- Check a configuration before comparing variants under it. The stream's
  `init` event lists the model, tools, skills, plugins, and MCP servers. For
  instructions, ask for a fact only `AGENTS.md` holds, such as the commit it
  names for the old skill, from the eval directory and, as a positive
  control, from the repository. Every cell of a comparison should run under
  the same checked configuration.
- Built prompts must not contain rubric text:
  `grep -E '## Rubric|Pass \(all\)|Fail signals|Neutral:'` finds nothing.
- Record the harness and its version, the full model ID, the flags, and
  the skill commit in the results log. Keep the raw outputs until the run is
  graded and logged.

## When to run

- Before editing `SKILL.md`: run the baseline (`none`) and the current skill
  on the scenarios your edit targets. If the current skill already passes,
  the edit has nothing to fix.
- After editing: rerun the same scenarios and the routing check.
- When adding guidance: first add a scenario that fails without it.

## Scenario A's clock reads

A grades where time enters the pricing rule, and its rubric has one narrow
tolerance.

- The pricing rule takes time as an explicit input. When it needs one
  sample, pass a timestamp value: the function stays pure and its tests need
  no fake clock. Pass a clock function (`now: () => number`) or a dependency
  record when the operation itself has to read the time. That also makes the
  dependency explicit, but calling it performs whatever effect it wraps, so
  the function is not, in general, pure.
- Either way the caller owns the sampling decision. Passing a value does
  not take it away: the caller can capture the time early or at the call.
- The preferred refactoring keeps both reads where the original has them:
  the subtotal, then the first read for the discount, then the second read
  for `placedAt`, then the track and the insert. This is guidance, not a
  pass criterion.
- The rubric also accepts reading the clock before the subtotal loop, as a
  shell does when it passes `order.items` and `Date.now()` to one pricing
  function. The allowance is specific to A and rests on a model: type-valid
  orders, with a frozen clock or a stub that returns set values per read.
  Under that model both versions return the same order. It is not runtime
  equivalence. A clock that advances with work, real or fake, can give a
  different discount, and a stub shared across a throwing call and a later
  call sees the extra read. The rubric tolerates those differences on
  purpose.
- Collapsing the two reads into one still fails. Each read has its own
  job, and one sample changes `placedAt` at an hour boundary.
