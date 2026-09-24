# AI Skills

This repository includes an AI coding-agent skill that applies functional
programming techniques where they make code easier to reason about locally:

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

The skill optimizes for local reasoning, not functional purity. Classes,
interfaces, and mutable objects remain appropriate when a framework requires
them, when they wrap stateful resources, or when the codebase is class-based
and a rewrite would be hard to review.

## Evaluations

Scenarios, rubrics, and baseline results live in
[`evals/functional-programming`](../evals/functional-programming/README.md).
Run them before and after changing the skill.
