# AI Skills

This repository includes a companion AI Skill for generating and refactoring TypeScript with a functional style bias:

```text
skills/functional-typescript
```

The skill is general-purpose TypeScript guidance. It is especially useful for this repo's design-patterns-with-functional-programming examples, but it can also be copied into other TypeScript projects.

## Install Locally

To make the skill available to Codex from this checkout, copy it into your local skills directory:

```bash
mkdir -p ~/.codex/skills
cp -R "skills/functional-typescript" ~/.codex/skills/
```

Then invoke it explicitly when needed:

```text
Use $functional-typescript to refactor this TypeScript example.
```

Codex-compatible environments may also discover the skill from a repo-local `skills/` directory when that environment supports repo-scoped skills.

## Style Intent

The skill is preference-first, not a strict ban on object-oriented code. It asks agents to prefer pure functions, immutable data, explicit inputs and outputs, algebraic types, and function composition by default.

Classes, interfaces, inheritance, and mutable objects remain acceptable when a framework requires them, existing code is class-heavy, the user explicitly asks for classic OOP, or an example needs an OOP version for comparison.
