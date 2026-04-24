---
name: functional-typescript
description: Use when generating, refactoring, reviewing, or explaining TypeScript code where functional style, immutable data, explicit data flow, algebraic types, composition, or design-patterns-with-functional-programming examples would improve maintainability.
---

# Functional TypeScript

Prefer functional TypeScript by default. Treat this as a strong style bias, not a ban on object-oriented code.

## Default Bias

When writing or changing TypeScript:

- Model behavior as small pure functions with explicit inputs and outputs.
- Prefer immutable data: `readonly` properties, `ReadonlyArray<T>`, object spreading, and new values over in-place mutation.
- Express alternatives with discriminated unions before class hierarchies when behavior is data-driven.
- Represent nullable or failing computations with `Option`- or `Result`-style types when callers need to handle absence or errors explicitly.
- Compose transformations with functions, `map`, `filter`, `reduce`, and small pipeline helpers instead of hidden control flow.
- Inject dependencies as function parameters or records of functions when that keeps side effects visible.
- Keep side effects at the boundary: I/O, logging, mutation, time, randomness, and network calls should be easy to locate.
- Use precise TypeScript types to make illegal states hard to represent.

## When OOP Is Acceptable

Use classes, interfaces, inheritance, or mutable objects when they are the clearer fit:

- A framework or library requires a class-based API.
- Existing code is class-heavy and a local functional rewrite would make the change harder to review.
- The user explicitly asks for OOP, SOLID, or classic design-pattern code.
- The task is educational and needs an OOP version to contrast with a functional version.
- Encapsulation of stateful resources is simpler than passing state through every function.

When using OOP, still prefer immutable inputs, small methods, explicit dependencies, and side effects at the boundary.

## TypeScript Patterns

Prefer data-first designs:

```ts
type SaveTarget =
  | { readonly kind: "s3"; readonly bucket: string }
  | { readonly kind: "file"; readonly path: string };

type Save = (target: SaveTarget, data: string) => Promise<void>;
```

Prefer explicit outcomes:

```ts
type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };
```

Prefer dependency records over hidden globals:

```ts
type Clock = { readonly now: () => Date };

const formatTimestamp = (clock: Clock): string =>
  clock.now().toISOString();
```

## Review Checklist

Before finalizing TypeScript code, check:

- Can a class or method be a plain function without losing clarity?
- Is mutation avoided or isolated behind a clear boundary?
- Are null, undefined, and errors explicit in the type contract?
- Are side effects visible from the function signature or dependency arguments?
- Are types precise enough to prevent invalid combinations of fields?
- Is the functional version simpler than the OOP version for this task?

If functional style would obscure the intent, say why and choose the clearer design.
