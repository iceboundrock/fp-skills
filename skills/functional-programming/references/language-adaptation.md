# Language Adaptation

Translate the intent, not the syntax. For each language this lists the native
way to express closed alternatives, expected failures, absence, and lazy
sequences, plus the traps agents fall into. When the project already has a
convention (a result type, an FP library, a lint rule), follow the project.

"Exhaustive" means the compiler or standard type checker reports a missing
case. Where it is not exhaustive, add an explicit fallback arm that fails
loudly, and do not claim the compiler will catch new cases.

## TypeScript / JavaScript

- Alternatives: discriminated union on a literal field (`kind`, `type`, `status`).
  Exhaustive in TS through a `never` check in the `default` branch. Plain JS
  has no check; document the shape (JSDoc) and throw in `default`.
- Expected outcomes, three legitimate forms; pick by what the caller does
  with the result:
  - `T | undefined` (or `T | null`): absence with no reason, checked once by
    the caller. The smallest form for a lookup miss.
  - A domain-named union such as
    `{ kind: "approved"; value: ApprovalData } | { kind: "rejected"; reason: RejectionReason }`:
    the variants carry domain meaning and one caller switches on them.
  - A generic `Result<T, E> = { ok: true; value: T } | { ok: false; error: E }`,
    with `E` a discriminated union of domain errors: several functions share
    the success/failure shape and callers sequence them, so `flatMap`/
    `andThen` states the short-circuit once. It is ordinary TypeScript, not
    an FP-library import; keep the module to the type, `ok`/`err`
    constructors, and the combinators the callers use.
  Exceptions stay for bugs and I/O failures unless a boundary deliberately
  turns them into a state (`RemoteData`: `loading | loaded | failed`).
- Absence through several transformations: an `Option`-style type or
  optional chaining (`?.`, `??`) both work. Use the one that reads better at
  the call sites; do not add an `Option` for a single `if`.
- Lazy: generators, async iterators, streams. Arrays are fine for bounded data.
- Immutability: `readonly` and `as const` are compile-time only. `Object.freeze` is shallow.
- Trap: `reduce` building objects with spread copies every step (quadratic).
- Trap: a `Result` module that grows applicative helpers, `sequence`,
  `traverse`, or `Unit` that no caller in the project uses.

## Python

- Alternatives: `@dataclass(frozen=True)` variants joined with `|`, or an `Enum`,
  matched with `match` (3.10+) or `isinstance`. Exhaustiveness exists only
  under a type checker, with `assert_never` (3.11+, or `typing_extensions`).
- Expected outcomes: exceptions are idiomatic, including `KeyError`/`ValueError`
  style lookups. Return `None` or a small union of dataclasses when callers
  must branch on the outcome as part of normal flow.
- Lazy: generators and `itertools`. A generator is single-pass: code that
  iterates its input twice breaks when the input is a generator.
- Trap: `functools.reduce` with tuple or dict accumulators. A `for` loop,
  `sum`, `Counter`, or a comprehension is usually clearer.

## Rust

- Alternatives: `enum` with payloads, `match` is exhaustive.
- Expected outcomes: `Result<T, E>` and `Option<T>` with `?`. `panic!` is for bugs.
- Lazy: iterators are lazy and zero-cost. `let mut` locals are normal Rust.
- Trap: cloning data to avoid `&mut` when a local mutable binding is clearer.

## Go

- Alternatives: no sum types. Use a `Kind` constant plus `switch`, or an
  interface with an unexported marker method. Not exhaustive (the
  `exhaustive` linter covers enum-like constants if the project uses it).
- Expected outcomes: `(T, error)` with sentinel or typed errors and
  `errors.Is`/`errors.As` is the shared failure channel. A generic
  `Result[T]`/`Option[T]` fights that idiom: every caller already handles
  `error`, and generics give no `?`-style sequencing.
- Lazy: slices by default. `iter.Seq` (Go 1.23+) for streaming. Channels carry
  goroutine cost; they are not a lazy-list substitute.
- Dependencies: small interfaces or function fields are idiomatic. Globals and
  `init()` state are the hidden-dependency smell.
- Trap: generic `Map`/`Filter`/`Reduce` helpers in place of plain loops.

## Kotlin

- Alternatives: `sealed interface`/`sealed class` with `data class`/`data object`,
  `when` is exhaustive over sealed types and enums.
- Expected outcomes: a domain-named sealed result, or nullable `T?` for absence.
  A project-level `sealed interface Outcome<out T, out E>` is fine when
  several services share the shape and compose it. The stdlib
  `Result`/`runCatching` catches every exception, including coroutine
  `CancellationException`; do not use it for domain outcomes.
- Lazy: `Sequence`; `Flow` for async streams.
- Trap: adding Arrow to a project that does not already use it.

## Scala

- Alternatives: `sealed trait` or Scala 3 `enum`; the compiler warns on
  non-exhaustive matches.
- Expected outcomes: `Option`, `Either`, `Try` from the standard library.
- Lazy: `Iterator`, `LazyList`, `.view`.
- Trap: introducing cats/ZIO/tagless-final into a codebase that does not use them.

## Swift

- Alternatives: `enum` with associated values, `switch` is exhaustive.
- Expected outcomes: `Optional`, `throws` (typed throws in Swift 6), or `Result`
  for callback-style APIs.
- Lazy: `.lazy` sequences, `AsyncSequence`.
- Structs already have value semantics; `let` vs `var` is the main immutability tool.

## Java

- Alternatives: `sealed interface` + `record` (17+). `switch` pattern matching
  over sealed types is exhaustive in Java 21+. On older versions use an enum or
  a visitor-free `instanceof` chain with a throwing fallback.
- Expected outcomes: a sealed result type named for the domain
  (`RefundDecision.Approved | Rejected`) when one caller switches on it; a
  shared `sealed interface Result<T, E>` with `Ok`/`Err` records when
  several services return the same shape and callers chain them. `Optional`
  is for return values, not fields or parameters. Checked/unchecked
  exceptions stay for infrastructure.
- Lazy: `Stream` is lazy and single-use.
- Frameworks: in Spring's default proxy mode, `@Transactional`, `@Cacheable`,
  etc. apply only to calls that come in through the proxy, so a method the
  bean calls on itself gets no transaction or caching. Visibility rules differ
  by annotation and proxy type: since Spring 6.0, class-based proxies make
  protected and package-private `@Transactional` methods transactional;
  interface-based proxies need a public method declared on the interface; the
  cache annotations need public methods. Keep those annotations on the entry
  point where they were; extract pure logic into static methods or plain
  classes.
- Trap: an `Either<L, R>` with `fold`, or Vavr, introduced for one call
  site where a two-case sealed interface says the same thing in domain terms.

## C#

- Alternatives: `record` types and `switch` expressions. What the compiler
  checks depends on what you switch over:
  - Record or class hierarchy: never treated as closed, so a type-pattern
    switch gets CS8509 even when every case is listed. Add
    `_ => throw new UnreachableException()` (.NET 7+). Promoting CS8509 cannot
    catch a missing record case. When a missed case must fail at compile time,
    give the outcome type one `Match` method with a required delegate
    parameter per case.
  - Enum: declared members are checked. List every member and leave out the
    `_` arm, which would also hide a member added later. A missing member gets
    CS8509 naming it; full coverage leaves only CS8524 for unnamed values such
    as `(Outcome)42`. Suppress CS8524 (`<NoWarn>$(NoWarn);CS8524</NoWarn>`, or
    `#pragma warning disable CS8524` around the switch) and such a value
    throws `SwitchExpressionException` at run time. To make a missing member
    fail the build, promote CS8509
    (`<WarningsAsErrors>$(WarningsAsErrors);CS8509</WarningsAsErrors>`); this
    also turns every record switch still lacking its `_` arm into an error.
- Expected outcomes: exceptions are idiomatic. For business rejections that
  callers must map (for example to HTTP codes), return a small record or
  enum-based result; a shared `Result<T, TError>` record is fine when several
  services return the same shape. `T?` for absence.
- Lazy: `IEnumerable<T>` with `yield` and LINQ are deferred; enumerating twice
  re-runs the query. `IAsyncEnumerable<T>` for async streams.
- Trap: adding LanguageExt/OneOf for one service, a `Result` with
  `Map`/`Bind`/`Match` that only one controller switches on, or wrapping
  `DbUpdateException` in the result.

## Haskell / OCaml

- Purity and ADTs are native; the skill's value here is effect boundaries:
  keep `IO` (or OCaml side effects) in a thin shell around pure functions.
- Expected outcomes: `Maybe`/`Either` (Haskell), `option`/`result` (OCaml).
  OCaml exceptions remain idiomatic for some library APIs.
- Haskell laziness is the default: prefer strict folds (`foldl'`) for
  accumulators to avoid space leaks.
- Trap: introducing mtl stacks, free monads, or effect libraries the project
  does not already use.

## Clojure

- Alternatives: maps with a `:type` key and `case` or multimethods. Contracts
  via spec or malli when the project uses them.
- Expected outcomes: `nil` for absence (nil punning), data maps for outcomes,
  `ex-info` for exceptional failures.
- Lazy: sequences are lazy and chunked; never put side effects inside `map`.
  Use `doseq`/`run!` for effects, transducers for pipelines.
- State: atoms/refs are the explicit, visible form of shared state.

## Elixir

- Alternatives: tagged tuples and structs, pattern matching in function heads.
- Expected outcomes: `{:ok, value}` / `{:error, reason}` with `with`. Raise for
  bugs ("let it crash" under a supervisor).
- Lazy: `Stream`; `Enum` is eager.
- State: processes (`GenServer`, `Agent`) are the stateful objects. Keep them;
  move decision logic from callbacks into pure functions they call.
