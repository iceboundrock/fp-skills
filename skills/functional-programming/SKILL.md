---
name: functional-programming
description: Use when generating, refactoring, reviewing, or explaining code in any language where functional style, immutable data, explicit data flow, algebraic types, composition, or design-patterns-with-functional-programming examples would improve maintainability.
---

# Functional Programming

Prefer functional style by default, regardless of language. Treat this as a strong style bias, not a ban on object-oriented code. Translate the principles below into the idioms of whatever language you are working in (TypeScript, JavaScript, Python, Rust, Go, Kotlin, Scala, Swift, Java, C#, Haskell, OCaml, Clojure, Elixir, etc.).

## Default Bias

When writing or changing code:

- Model behavior as small pure functions with explicit inputs and outputs.
- Prefer immutable data: language-level immutability features (`readonly`, `const`, `final`, `val`, frozen/persistent collections, `dataclass(frozen=True)`, records, structs without setters) and produce new values rather than mutating in place.
- Express alternatives with sum types / tagged unions / discriminated unions / sealed hierarchies / enums-with-payloads before deep class hierarchies when behavior is data-driven.
- Represent nullable or failing computations with `Option`/`Maybe`/`Optional` and `Result`/`Either` style types (or the language's equivalent) when callers need to handle absence or errors explicitly. Avoid silent `null`/`None` and exceptions for expected outcomes.
- Compose transformations with functions, `map`, `filter`, `reduce`/`fold`, comprehensions, and small pipeline helpers instead of hidden control flow.
- Inject dependencies as function parameters or records/structs of functions, so side effects are visible at the call site.
- Keep side effects at the boundary: I/O, logging, mutation, time, randomness, and network calls should be easy to locate.
- Use the type system (or runtime contracts in dynamic languages) to make illegal states hard to represent.

## When OOP Is Acceptable

Use classes, interfaces, inheritance, or mutable objects when they are the clearer fit:

- A framework or library requires a class-based or object-oriented API.
- Existing code is class-heavy and a local functional rewrite would make the change harder to review.
- The user explicitly asks for OOP, SOLID, or classic design-pattern code.
- The task is educational and needs an OOP version to contrast with a functional version.
- Encapsulation of stateful resources (connections, caches, hardware handles) is simpler than threading state through every function.

When using OOP, still prefer immutable inputs, small methods, explicit dependencies, and side effects at the boundary.

## Cross-Language Patterns

Prefer data-first designs. Use sum types / tagged unions to make alternatives explicit.

TypeScript:

```ts
type SaveTarget =
  | { readonly kind: "s3"; readonly bucket: string }
  | { readonly kind: "file"; readonly path: string };

type Save = (target: SaveTarget, data: string) => Promise<void>;
```

Rust:

```rust
enum SaveTarget {
    S3 { bucket: String },
    File { path: PathBuf },
}

fn save(target: &SaveTarget, data: &str) -> Result<(), SaveError> { /* ... */ }
```

Python:

```python
@dataclass(frozen=True)
class S3Target:
    bucket: str

@dataclass(frozen=True)
class FileTarget:
    path: str

SaveTarget = S3Target | FileTarget

def save(target: SaveTarget, data: str) -> None: ...
```

Prefer explicit outcomes over thrown exceptions for expected failures.

TypeScript:

```ts
type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };
```

Rust uses `Result<T, E>` and `Option<T>` natively. Kotlin/Scala have `Result`/`Either`/`Option`. In Python, return a union type or use a small `Result` dataclass; reserve exceptions for truly exceptional conditions.

Prefer dependency records over hidden globals so side effects are visible.

TypeScript:

```ts
type Clock = { readonly now: () => Date };

const formatTimestamp = (clock: Clock): string =>
  clock.now().toISOString();
```

Python:

```python
from typing import Protocol
from datetime import datetime

class Clock(Protocol):
    def now(self) -> datetime: ...

def format_timestamp(clock: Clock) -> str:
    return clock.now().isoformat()
```

Go:

```go
type Clock struct {
    Now func() time.Time
}

func FormatTimestamp(c Clock) string {
    return c.Now().Format(time.RFC3339)
}
```

## Review Checklist

Before finalizing code, check:

- Can a class or method be a plain function without losing clarity?
- Is mutation avoided or isolated behind a clear boundary?
- Are absence and errors explicit in the type or return contract, rather than hidden in `null`/`None` or thrown exceptions?
- Are side effects visible from the function signature or injected dependencies?
- Are types (or contracts, in dynamic languages) precise enough to prevent invalid combinations of fields?
- Is the functional version simpler than the OOP version for this task, in the idioms of this language?

If functional style would obscure the intent in the host language, say why and choose the clearer design.
