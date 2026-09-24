---
name: functional-programming
description: Use when business logic is tangled with I/O, time, randomness, environment, or global state; when code is hard to unit test without mocks; when boolean or nullable fields allow impossible state combinations; when expected outcomes like not-found or validation failures are thrown and caught as control flow; when single-method classes, managers, or shared mutable objects obscure simple data transformations; or when asked to make code "more functional".
---

# Functional Programming for Local Reasoning

Use functional techniques when they let a reader understand behavior from what
is in front of them: explicit inputs, a transformation, an output, and effects
in places that are easy to find. The goal is local reasoning, not purity.

**Test every change:** does it reduce the number of concepts a maintainer must
keep in their head? If not, don't make it, even when the user asked for "more
functional" code.

## Four Reflexes

1. **Separate decisions from effects.** Decide what should happen in code that
   takes plain values. Do I/O, time, randomness, logging, and persistence
   around it.
2. **Values over hidden shared state.** Avoid mutation that other code can
   observe. Mutating a local variable the function itself created is fine.
3. **Make alternatives, failures, and invariants explicit** in the data model
   and return types.
4. **Use the host language's simplest idiomatic form.** Translate intent, not
   syntax. Before picking a union, result, or lazy-sequence construct, check
   `references/language-adaptation.md` for that language.

## Procedure

1. Read the code, its callers, and project conventions: framework, error
   model, dependency injection, existing result types or FP libraries.
2. List where state changes and effects happen: database, network, files,
   clock, randomness, env/config/globals, logging, input mutation, framework
   callbacks.
3. For each smell actually present, apply the matching move below. Skip the
   rest.
4. Run the stop checks. Remove whatever fails them.
5. Preserve behavior: same effects in the same order, same public signatures
   unless the task needs a change and you update the callers. Verify with tests.

## Smell → Move

| You see | Move | Keep it small |
|---|---|---|
| A business rule reads the clock, config, env, randomness, or globals, or sits between I/O calls | Extract the rule into a function whose parameters are the plain values it needs (`now`, config fields, loaded records). The caller reads them and performs the effects. Make the function reachable from tests (package-private/internal is enough). | Pass values, not providers. Don't add `Clock`/`Config`/`Repository` interfaces or a deps record for this. |
| A function mutates its arguments or a shared object; results depend on call order | Return new values, or give the state one owner that changes it in one place. | Local accumulators, builders, and loops are fine. |
| Booleans/nullables valid only in certain combinations (`loading`, `error`, `data`) | One closed type with a case per real state: sealed/tagged union or enum with payload. Dynamic languages: one discriminator field and a documented shape. | Only states the domain has. |
| Expected outcomes (not found, invalid input, rule rejected) thrown and caught as control flow, or easy for callers to forget | Return a closed, domain-named outcome (`Approved \| Rejected(reason)`) or the language's native channel (`Result`, `(T, error)`, optional). | Infrastructure failures (DB, network, timeouts, bugs) keep the normal failure channel. |
| Stateless single-method classes, strategies, or factories | Plain functions, plus a map from key to function when dispatch is needed. | Keep classes that hold state or resources, or that a framework needs. |
| Coordinators passing a mutable context through steps | A sequence of named steps that take and return values. | Named intermediate variables, not point-free chains. |
| Large or unbounded input materialized eagerly | Stream it with the language's iterator/sequence type. | Eager collections are fine for bounded data. Never iterate a one-shot iterator twice. |

## Example: Pass Values, Not Providers

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

The shape is the same in any language: a decision function over values, a
domain-named outcome, and a thin shell that owns the effects.

## Stop Checks: Performative FP

If a function already derives its output from explicit inputs and any mutation
is local, it is functional where it matters. Say so and leave it, or make one
small idiomatic change. This still holds when the user asks for "more
functional" code: explain why instead of rewriting.

| Thought | Reality |
|---|---|
| "More functional means no mutation, so replace the loop with `reduce`" | Callers can't observe a local accumulator. A fold that copies its accumulator each step adds allocations and concepts. Keep the loop. |
| "No FP library here, so I'll hand-roll a small `Either`/`Result`" | Name the outcomes for the domain and use the language's `switch`/`match`. A generic `Either` with `fold` adds vocabulary without meaning. |
| "Inject a Clock/Store/Analytics record so effects are visible" | The shell calling effects directly is already visible. Give the decision `now` and the config values; its tests then need no fakes. Add an interface only for a second real implementation or when the codebase already has one. |
| "Infrastructure errors should be results too, so nothing throws" | Only expected domain outcomes go in the return type. Database, network, and programming errors keep the normal channel. |
| "Early returns are imperative; chain `Optional`/ternaries instead" | Early returns in a pure function read clearly. Use combinators only where they are shorter and easier to read. |
| "Make the result read-only, or turn the entity into an immutable record" | Changing a public type or a framework-managed object (ORM entity, DI bean) is an API change. Do it only when shared mutation is the actual bug. |
| "The compiler will flag missing cases" | Only where the language checks it: Rust, Kotlin, Swift, Scala, Java 21 sealed `switch`, TypeScript with a `never` check. C# checks enum members (CS8509 names a missing one unless a `_` arm hides it) but never record or class hierarchies (CS8509 fires even when every case is listed). When a missed C# record case must fail the build, give the outcome type a `Match` method with one delegate parameter per case. Go and Python without a type checker don't check either. |

**Red flags.** Reconsider the change if it adds any of these:

- A hand-rolled `pipe`, `compose`, `Either`, `Option`, `Result`, or `Unit`, or an FP library the project didn't have
- An interface or function record with one implementation, added only for tests
- `reduce`, `fold`, or recursion replacing a readable loop
- One-use helpers the reader must jump between to follow simple logic
- Public signature or type changes the task didn't require
- Comments arguing that the code is "still functional"

## Frameworks and OOP

Keep classes that a framework requires (Spring beans, ASP.NET controllers,
Django views, Android ViewModels, Rails models), classes that wrap resources
(connections, caches, sessions, actors), and class-based designs a rewrite
would make hard to review. Improve them from the inside: extract pure
decision functions, static methods, or value records that the class calls.
Leave lifecycle and proxy behavior (DI, transactions, caching annotations) on
the entry points where it was.

## Review Questions

- Can the business rules be tested without I/O, mocks, or the real clock?
- Can a reader point to every place where state changes or effects happen?
- Can the data model represent a state the domain can't be in?
- Are expected outcomes visible in the API, with infrastructure failures still
  in the normal channel?
- Did I add an abstraction, helper, type, or dependency the codebase doesn't need?
- Did I replace readable imperative code just to look functional?
- Does the result read like idiomatic code in this language and codebase?
- Is the diff local and reviewable, with behavior and effect order unchanged?
