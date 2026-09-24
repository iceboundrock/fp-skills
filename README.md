# Functional Programming Skills

This repository collects practical TypeScript examples and articles for applying functional programming ideas to familiar design-pattern problems.

The goal is not to replace object-oriented programming. The goal is to add a small set of functional techniques that make code easier to test, review, and safely change, especially when working with AI-assisted coding tools.

## Blog Series

1. [Vibe Coding Isn't the Problem — Your Types Are](blog/01-vibe-coding-isnt-the-problem.md)
2. [Pure Functions and Immutability](blog/02-pure-functions-and-immutability.md)
3. [Types as AI Guardrails: Narrow the Surface an AI Can Get Wrong](blog/03-types-as-ai-guardrails.md)
4. [Why `{ data, loading, error }` Lies — And Algebraic Data Types Fix Your Vibe Coding](blog/04-algebraic-data-types.md)

## AI Coding-Agent Skill

[`skills/functional-programming`](skills/functional-programming/SKILL.md) is a language-neutral skill for Codex, Claude Code, and other agents that support `SKILL.md`. It steers an agent toward separating decisions from effects and making states and outcomes explicit, and away from performative functional programming. See [AI Skills](docs/AI_Skills.md) for installation and [the evals](evals/functional-programming/README.md) for how it is tested.

## Supporting Docs

- [Series notes](docs/Design%20Patterns%20with%20%28a%20little%29%20Functional%20Programming.md)
- [AI Skills](docs/AI_Skills.md)

## Local TypeScript Examples

Source examples live under `src/` and use TypeScript only, without external functional programming libraries.
