---
name: functional-programming
description: Use when business logic is tangled with I/O, time, randomness, environment, or global state; when code is hard to unit test without mocks; when boolean or nullable fields allow impossible state combinations; when expected outcomes like not-found or validation failures are thrown and caught as control flow; when single-method classes, managers, or shared mutable objects obscure simple data transformations; or when asked to make code "more functional".
---

# Functional Programming: Make Implicit Contracts Explicit

Functional programming is useful when it moves knowledge out of convention
and control flow and into values, types, function signatures, and
composition. Use the smallest construct that makes the contract explicit;
avoid functional ceremony that adds vocabulary without adding information.

An implicit contract is anything a caller must know but cannot see in the
API: a failure that arrives as an exception or `null`, a field that is only
valid in some states, a function that reads the clock or writes to a
database, a value that other code mutates, a rule that lives in a comment.
For every change ask: **does this construct expose information the caller
needed anyway, or does it only rename what was already visible?**

## Procedure

1. Read the code, its callers, and project conventions: framework, error
   model, dependency injection, existing result or option types, FP libraries.
2. Find what is implicit: expected failures, absence, state combinations,
   effects (database, network, files, clock, randomness, env/config/globals,
   logging, input mutation, framework callbacks), order-dependent mutation.
3. For each item, decide whether making it explicit improves the contract
   for the callers that exist. Choose the smallest construct that expresses
   it, preferring the language's and project's existing constructs
   (`references/language-adaptation.md` lists them per language). Introduce
   a small reusable abstraction when several functions share the pattern.
4. Stop when the next construct would expose no additional meaning. This
   holds when the user asks for "more functional" code: if the code already
   states its contract, say so and leave it, or make one small idiomatic change.
5. Preserve behavior: same effects in the same order, same public signatures
   unless the task needs a change and you update the callers. Verify with tests.

## Implicit → Explicit

| Implicit today | Make it explicit with | Stop here |
|---|---|---|
| An expected failure (validation, not found in normal flow, authorization rejection, insufficient funds, rule rejection) thrown, or signalled by `null`/`false`/a magic value | A closed outcome in the return type: a domain-named union (`Approved \| Rejected(reason)`), or `Result<T, E>` with a domain error type as `E` | Use the native channel where one exists (`Result`, `(T, error)`, sealed types). Infrastructure failures keep the normal failure channel unless the caller handles them as ordinary control flow. |
| Absence signalled by `null`, sentinels, or exceptions | `T?`, `T \| undefined`, `Optional`, `Option` | Native nullable when absence is checked once, locally. An option type when absence flows through several transformations or the project already has one. |
| Several booleans/nullables valid only in certain combinations (`loading`, `error`, `data`) | One closed type with a case per real state: sealed/tagged union or enum with payload. Dynamic languages: one discriminator field and a documented shape. | Only states the domain has. |
| A business rule that reads the clock, config, env, randomness, or globals, or sits between I/O calls | Extract the rule into a function over plain values (`now`, config fields, loaded records). The caller performs the effects. Make the function reachable from tests. | Pass a value when the rule needs one sample. Pass a function or a dependency record when the operation performs the effect itself and its signature should say so. |
| A function mutates its arguments or shared state; results depend on call order | Return new values (`const paid = markPaid(submitted, paidAt)`), or give the state one owner that changes it in one place. | Local accumulators, builders, and loops are fine when the mutation is not the state transition the reader needs to see. |
| Stateless single-method classes, strategies, or factories | Plain functions, plus a map from key to function when dispatch is needed. | Keep classes that hold state or resources, or that a framework needs. |
| Several steps share one success/failure or presence/absence shape, and callers repeat the unwrap-and-bail per step | `map`/`flatMap`/`match` on the shared type, so short-circuiting is stated once | Named intermediate variables over point-free chains. One call site with two or three steps: early returns are enough. |
| Large or unbounded input materialized eagerly | Stream it with the language's iterator/sequence type. | Eager collections are fine for bounded data. Never iterate a one-shot iterator twice. |

## Choosing the Construct

**Domain outcome vs generic `Result`.** Complementary tools, not competing
rules. A domain-named outcome (`Approved | Rejected(reason)`) is right when
the variants carry domain meaning and one caller switches on them. A generic
`Result<T, E>` is right when several operations share the success/failure
algebra and callers sequence them; the domain error type is `E`, so nothing
is lost:

```ts
type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

type TransferError =
  | { readonly kind: "account-not-found"; readonly id: string }
  | { readonly kind: "account-frozen"; readonly id: string }
  | { readonly kind: "insufficient-funds" };

const validateTransfer = (input: TransferInput): Result<ValidatedTransfer, TransferError> => { /* ... */ };
```

A small generic type (`Result`, `Either`, `Option`) is legitimate when
several functions share the shape, callers gain compile-time information,
`map`/`flatMap`/`match` remove repeated control-flow boilerplate, its API
stays small with clear semantics, or the project is teaching the construct.
Writing the type plus `flatMap` yourself is not "adding an FP library"; it
is a few lines that state the sequencing once. It becomes performative when
introduced for a single call site, when the language already has an equally
expressive idiom, when it hides domain distinctions behind a generic error,
when its combinator API outgrows the problem, when it exists only to avoid
`if`/`switch`/early return/local mutation, or when it turns failures that
should stay exceptional into values for no semantic reason.

**Expected vs infrastructure failures.** Expected domain outcomes belong in
the return type: validation failure, not found when absence is normal,
authorization rejection, insufficient funds, rule rejection. Infrastructure
and unexpected failures (database unavailable, network timeout, disk
failure, bugs, violated invariants) need not be forced into every `Result`.
The line is semantic, not mechanical: a boundary may deliberately turn an
infrastructure exception into a value, such as a UI loader returning
`Loading | Loaded(value) | Failed(NetworkError)`, because its caller handles
that failure as normal control flow. Convert the failures the caller is
expected to handle, not every exception.

**`T | undefined` vs `Option<T>`.** Native nullable types are the smallest
form when absence is simple and local. An option type earns its place when
absence flows through several transformations, when `map`/`flatMap`/`filter`
read better than repeated null checks, when the project already uses one, or
when the code is teaching composition. Reject an option abstraction only
when it adds vocabulary without adding a contract.

**Effects and dependencies.** Make effects and external dependencies visible
at the boundary where they matter. `now: Date` is right when a decision needs
one sampled time. `now: () => Date` or a `Clock` is right when the operation
itself must sample time, possibly more than once, or when time is part of its
effect contract. A dependency record such as

```ts
type RegistrationDeps = {
  createId: () => string;
  now: () => Date;
  saveUser: (user: User) => Promise<void>;
  emailExists: (email: string) => Promise<boolean>;
};
```

is valid when its purpose is to make the operation's effect surface explicit
in the signature. Flag it only when it exists to satisfy a purity aesthetic,
or when it adds indirection without clarifying what the operation does. An
interface with one implementation, added only so a test can mock it, is that
kind of indirection.

**Immutability.** Immutable values make state transitions explicit:
`const paid = markPaid(submitted, paidAt)` states a transition that a run of
field assignments hides. Default to immutable transformations for domain
values. Use local mutation when it is simpler, contained, and not
semantically relevant. Mutation is more suspicious when correctness depends
on operation order or aliasing. The criterion is not purity; it is whether
the state transition is visible.

**Composition.** Judge `pipe`, `compose`, `map`, `flatMap`, `fold`, and
`reduce` by whether they expose or obscure the transformation.
`parse(input).flatMap(validate).flatMap(price).map(toResponse)` is good when
each step shares the same `Result` and the chain makes short-circuiting
explicit. `items.reduce(...)` is bad when a loop is clearer and `reduce` is
there only to avoid a local accumulator. Semantic composition states data
flow; stylistic composition only changes syntax.

## Example: Decision Over Values, Shell Owns Effects

```kotlin
sealed interface Renewal {
    data class Charge(val cents: Long) : Renewal
    data class Retry(val at: Instant) : Renewal
    data object Cancel : Renewal
}

// Decision: plain values in, closed outcome out. Tested with literals, no mocks.
fun decideRenewal(sub: Subscription, now: Instant, maxRetries: Int): Renewal {
    if (sub.failedAttempts >= maxRetries) return Renewal.Cancel
    if (sub.failedAttempts > 0) return Renewal.Retry(now.plus(Duration.ofHours(24)))
    return Renewal.Charge(sub.plan.priceCents)
}

// Shell: reads the world and performs effects. Still a framework class if it was one.
class RenewalJob(
    private val subs: SubscriptionRepo,
    private val billing: Billing,
    private val clock: Clock,
    private val config: BillingConfig,
) {
    fun run(id: SubscriptionId) {
        val sub = subs.find(id)
        when (val d = decideRenewal(sub, clock.instant(), config.maxRetries)) {
            is Renewal.Charge -> billing.charge(sub.customerId, d.cents)
            is Renewal.Retry -> subs.scheduleRetry(id, d.at)
            Renewal.Cancel -> subs.cancel(id)
        }
    }
}
```

The decision takes `now` as a value because it samples time once. If the
operation had to perform the effects itself, a function parameter or a
dependency record would make that visible instead.

## Stop Checks

| Thought | Reality |
|---|---|
| "More functional means no mutation, so replace the loop with `reduce`" | A local accumulator is not a state transition anyone reads. A fold that copies its accumulator each step adds allocations and concepts. Keep the loop. |
| "Domain-named outcomes are always better than a generic `Result`" | Only when one caller switches on them. When several steps share the failure channel, `Result<T, DomainError>` with `flatMap` states the short-circuit once; the domain lives in `E`. |
| "A `Result` type means either `if (!r.ok) return r` everywhere or a mini FP library" | A `flatMap` is a few lines. Steps that return a shared `Result` plus one `flatMap` state the sequencing once; exceptions state it nowhere and take the failure out of the signature. |
| "Infrastructure errors should be results too, so nothing throws" | Convert the failures callers handle as normal flow. Database, network, and programming errors keep the normal channel unless a boundary deliberately presents them as a state. |
| "Inject a Clock/Store/Analytics record so effects are visible" | If the decision needs one value, pass the value and let the shell keep the effect. Add a function parameter or dependency record when the operation performs the effect itself and the signature should say so. |
| "Early returns are imperative; chain `Optional`/ternaries instead" | Early returns in a pure function state the contract. Use combinators only where they are shorter and easier to read. |
| "Make the result read-only, or turn the entity into an immutable record" | Changing a public type or a framework-managed object (ORM entity, DI bean) is an API change. Do it only when shared mutation is the actual bug. |
| "The compiler will flag missing cases" | Only where the language checks it: Rust, Kotlin, Swift, Scala, Java 21 sealed `switch`, TypeScript with a `never` check. C# checks enum members (CS8509 names a missing one unless a `_` arm hides it) but never record or class hierarchies (CS8509 fires even when every case is listed). When a missed C# record case must fail the build, give the outcome type a `Match` method with one delegate parameter per case. Go and Python without a type checker don't check either. |

## Red Flags

Reconsider the change if it does any of these:

- Introduces a generic FP abstraction that is used once and conveys no
  reusable contract.
- Replaces clear control flow solely to avoid `if`, `switch`, early return,
  a loop, or local mutation.
- Adds combinators whose only purpose is to imitate an FP library.
- Hides domain distinctions inside an overly generic error type.
- Converts every infrastructure exception into an ordinary result value.
- Adds dependencies or interfaces solely for tests when they do not clarify
  the production contract.
- Changes framework-managed entities or public APIs solely to make them look
  more functional.
- Uses `Result`, `Either`, or `Option` without being able to say what
  semantic information the type exposes.

`Result`, `Option`, `Either`, `pipe`, `compose`, `reduce`, and dependency
records are not red flags in themselves. Their misuse is.

## Frameworks and OOP

Keep classes that a framework requires (Spring beans, ASP.NET controllers,
Django views, Android ViewModels, Rails models), classes that wrap resources
(connections, caches, sessions, actors), and class-based designs a rewrite
would make hard to review. Improve them from the inside: extract pure
decision functions, static methods, or value records that the class calls.
Leave lifecycle and proxy behavior (DI, transactions, caching annotations) on
the entry points where it was.

## Review Questions

- Can the caller see absence, failure, effects, and alternatives from the API?
- Does each construct make the contract easier to understand locally, or does
  it only add vocabulary?
- Can the business rules be tested without I/O, mocks, or the real clock?
- Can the data model represent a state the domain can't be in?
- Are expected outcomes in the return type, with infrastructure failures
  handled where the caller expects them?
- Where a generic abstraction was introduced, do several functions share it?
- Does the result read like idiomatic code in this language and codebase?
- Is the diff local and reviewable, with behavior and effect order unchanged?
