# AI Skills

This repository includes an AI coding-agent skill that applies functional
programming techniques where they make implicit contracts explicit (failures,
absence, states, and effects that a caller must know about but cannot see in
the API):

```text
skills/functional-programming/
  SKILL.md                          # decision guide the agent loads
  agents/openai.yaml                # Codex UI metadata and invocation policy
  references/language-adaptation.md # per-language idioms, loaded on demand
```

The skill is language-neutral. It targets hidden effects, hidden mutable state,
impossible state combinations, exception-driven expected outcomes, and
single-method class hierarchies. It also tells the agent when to leave code
alone, such as a clear loop with local mutation or a framework-required class.

## Install Locally

Codex reads user skills from `~/.agents/skills` and repository skills from
`.agents/skills`:

```bash
mkdir -p ~/.agents/skills
cp -R skills/functional-programming ~/.agents/skills/
```

Claude Code reads personal skills from `~/.claude/skills`:

```bash
mkdir -p ~/.claude/skills
cp -R skills/functional-programming ~/.claude/skills/
```

The skill loads implicitly when a task matches its description. To invoke it
explicitly in Codex:

```text
Use $functional-programming to untangle the pricing rules from the database calls in checkout.ts.
```

## Style Intent

The skill optimizes for explicit contracts, not functional purity and not the
fewest concepts. It picks the smallest construct that states the contract,
which can be a plain loop, a domain-named outcome, or a shared `Result` with
`flatMap` when several steps share one failure channel. Classes, interfaces,
and mutable objects remain appropriate when a framework requires them, when
they wrap stateful resources, or when the codebase is class-based and a
rewrite would be hard to review.

## Evaluations

Scenarios, rubrics, and baseline results live in
[`evals/functional-programming`](../evals/functional-programming/README.md).
Run them before and after changing the skill.
