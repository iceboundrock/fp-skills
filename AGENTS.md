# Repository rules

## What this repo is

Mostly prose, with a small amount of code. It has four parts:

- `skills/functional-programming/`: the main deliverable. It is a language-neutral agent skill for Codex, Claude Code, and other `SKILL.md` agents.
- `evals/functional-programming/`: scenario-based evals that test whether the skill changes an agent's decisions.
- `blog/` and `docs/`: an article series and supporting notes. `README.md` lists the blog posts in order.
- `src/`: small TypeScript design-pattern examples that use no external FP libraries.

## Commands

```bash
npx tsc --noEmit   # type-check src/ (the only code check; there is no linter or test suite)
npm start          # compile to dist/ and run dist/index.js
```

`npm test` is the npm placeholder and always fails.

To build eval prompts for a skill variant (`none` means no skill):

```bash
bash evals/functional-programming/build-prompts.sh skills/functional-programming/SKILL.md <out-dir>
bash evals/functional-programming/build-prompts.sh none <out-dir>
```

## Skill layout

- The `description` in `SKILL.md`'s frontmatter decides when agents load the skill. `evals/functional-programming/routing.md` tests it, so rerun the routing check whenever you change the description.
- `SKILL.md` stays language-neutral. Per-language idioms go in `references/language-adaptation.md`, which the agent loads on demand. Claims that appear in both files, such as which compilers check exhaustiveness, must agree.
- `agents/openai.yaml` holds Codex UI metadata and the invocation policy.
- The skill's thesis is local reasoning, not purity. Many of its rules exist to stop over-application, such as `reduce` replacing loops, hand-rolled `Either`, or interfaces added only for tests. Edits should not weaken these guards.

## Changing the skill: eval workflow

`evals/functional-programming/README.md` is the full procedure. In short:

- Before editing `SKILL.md`, run the baseline (`none`) and the current skill on the scenarios the edit targets. If the current skill already passes, the edit has nothing to fix.
- To add guidance, first add a scenario that fails without it.
- Give one scenario to each fresh agent with no other context, and run at least two repetitions per cell.
- Grade by reading each answer against the rubric, not by counting keywords. Record verdicts and verbatim rationalizations in a new `results/YYYY-MM-DD.md`.
- Commit `e18b39d` holds the pre-rewrite skill, which serves as the "old" variant.

`build-prompts.sh` parses files with `awk` on exact markers. Keep them when editing:

- Scenario files need `## Prompt` (shown to the agent) followed by `## Rubric` (hidden).
- `routing.md` needs `Skill list:`, `## Tasks`, `Pass:`, the `*(description under test)*` placeholder, and numbered task lines.

## General

- Inspect existing patterns before editing. Copy the neighbouring style.
- Prefer minimal diffs. Do not refactor unrelated code.
- Do not add dependencies unless the task requires them.
- Keep the boundaries between the parts listed under "What this repo is" explicit. For example, per-language idioms stay in `references/`, and rubrics stay in the eval scenarios, not in `SKILL.md`. Do not move content across them to save a file.
- After modifying code, run the matching check from "Commands": `npx tsc --noEmit` for `src/`, and a prompt build for `build-prompts.sh`. There is no CI. Skill edits follow the eval workflow above.



## Non-code artifacts

Issues, PR descriptions, specs, plans, reviews, and every other non-code artifact(except blog posts) give readers the
context and judgment the diff cannot, not a narrated diff or filler, and are published in full on
GitHub. The full rules:

@docs/non-code-rules.md

### Blog

If you are writing/reviewing a tech blog, put it into `blog/` folder, read the [Non-code rules](./docs/non-code-rules.md) and [CLAUDE.md](./blog/CLAUDE.md) first.

## PR rules

- Merge a PR only when I explicitly ask; squash-merge unless I say otherwise.
- When reviewing a PR, post everything (findings, spec and standards checks, assessment, observations, verification, summary) as one comment on the PR.
- After a PR is merged, clean up local branches and worktrees, fast-forward main, then update and close related issues.

## Git conventions

Never include AI attribution in commit messages, PR titles, or PR descriptions, in any form: no
`Co-Authored-By: Claude`, `Generated with ...` footers, sign-offs naming an AI agent or vendor
(Claude, Anthropic, GPT, OpenAI, …), or `Claude-Session:` trailers and session URLs — even when a
tool inserts them automatically. When squash-merging, write a clean commit message that describes
only the change itself.