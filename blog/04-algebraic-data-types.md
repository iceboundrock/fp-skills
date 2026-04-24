# Why `{ data, loading, error }` Lies — And Algebraic Data Types Fix Your Vibe Coding

An AI agent wrote a React hook last week. It returned `{ data, loading, error }`. The render branch said

```jsx
if (loading) return <Spinner />; 
if (error) return <Err />; 
return <List data={data} />; 
```

In production, `data` arrived, `loading` stayed `true` for a tick, and the list crashed on `data.items.map`. The type said `Order[] | null`. The state said "loaded". Both agreed. Neither was right.

[Post 3](03-types-as-ai-guardrails.md) showed how to shape one aggregate so its states are legal. This post uses the same tool — Algebraic Data Types (ADTs) — as a cross-cutting vocabulary. It covers the surfaces where vibe coding drops cases: async calls, error handling, and remote data.

## The Problem

The `{ data, loading, error }` shape is a habit, not a type.

It describes one concept — "what does this request know right now?" — with three fields that can all be true, all be false, or any combination in between. Eight combinations. Four legal. The compiler cannot tell one from the other.

Every caller reads the shape and invents a convention. "If `loading` is true, ignore `data`." "If `error` exists, trust it over `data`." The convention lives in heads and pull requests. It does not live in the type.

## Where Vibe Coding Struggles

AI copies the surface pattern.

**It chains nulls instead of naming cases.** A prompt that says "show the user's name" becomes `user?.profile?.name ?? "Unknown"`. The chain compiles. The chain hides whether `user` is loading, missing, or forbidden.

**It adds another `if` when a new case appears.** Ask AI to handle "stale data after refetch." It adds `isStale: boolean` to the record. The shape now has sixteen combinations. The new flag never collides with the old ones at the type level.

**It skips impossible-but-legal branches.** A component renders `data` while `loading` is still `true`. The type permits the combination. AI never writes the guard.

Each pattern extends what it sees. The shape invites the mistakes.

## Traditional OOP Approach

A common class wraps the shape:

```typescript
class RemoteOrder {
  loading: boolean = false;
  error: Error | null = null;
  data: Order | null = null;

  isReady(): boolean {
    return !this.loading && this.error === null && this.data !== null;
  }

  getData(): Order {
    if (!this.isReady()) throw new Error("Not ready");
    return this.data!;
  }
}
```

The class adds guard methods, but the fields still permit every combination. A caller that forgets `isReady()` reads `data` as `Order | null` and handles `null` with `?.`. A caller that remembers `isReady()` calls `getData()` and converts a compile-time concern into a runtime throw.

Ask AI to add a refetch-in-progress state. It adds a fourth field, `refetching: boolean`. The combinations double. Every existing call site is now one flag short of correct.

## Functional-Light TypeScript Approach

An Algebraic Data Type has two parts: a **sum** (tagged variants) and a **product** (the fields each variant carries). One tag per case. Each variant carries only the fields valid in that case.

**Move 1: Replace the shape with a sum of cases.**

```typescript
type RemoteData<T, E> =
  | { readonly kind: "idle" }
  | { readonly kind: "loading" }
  | { readonly kind: "success"; readonly value: T }
  | { readonly kind: "failure"; readonly error: E };
```

A `RemoteData<Order, OrderError>` is one of four things. There is no `data: null` with `loading: true`. There is no `error` on a `success`. The combinations that never occurred in practice no longer exist in the type.

**Move 2: Make the error type its own ADT.**

```typescript
type OrderError =
  | { readonly kind: "network"; readonly status: number }
  | { readonly kind: "not-found"; readonly orderId: string }
  | { readonly kind: "forbidden"; readonly userId: string }
  | { readonly kind: "parse"; readonly field: string };
```

Failure is no longer `Error`. It is one of four named cases, each with the fields a handler needs. A retry button knows which errors are retryable. A toast knows which errors need a login prompt. AI reads the names and writes the branch.

**Move 3: Exhaustive matching with `never`.**

```typescript
const assertNever = (x: never): never => {
  throw new Error(`Unexpected variant: ${JSON.stringify(x)}`);
};

const render = (state: RemoteData<Order, OrderError>): string => {
  switch (state.kind) {
    case "idle":
      return "Click to load.";
    case "loading":
      return "Loading…";
    case "success":
      return `Order ${state.value.id}`;
    case "failure":
      return renderError(state.error);
    default:
      return assertNever(state);
  }
};
```

Add a `stale` variant to `RemoteData`. Every `switch` without a `stale` case becomes a compile error, because `state` is no longer `never` in the `default` branch. The compiler lists every place the new case must land.

**Move 4: A small `match` helper, plain TypeScript.**

```typescript
type Cases<S extends { kind: string }, R> = {
  [K in S["kind"]]: (state: Extract<S, { kind: K }>) => R;
};

const match = <S extends { kind: string }, R>(
  state: S,
  cases: Cases<S, R>,
): R => cases[state.kind as S["kind"]](state as Extract<S, { kind: S["kind"] }>);

const label = (state: RemoteData<Order, OrderError>): string =>
  match(state, {
    idle: () => "Click to load.",
    loading: () => "Loading…",
    success: ({ value }) => `Order ${value.id}`,
    failure: ({ error }) => renderError(error),
  });
```

Omit a case and the object literal fails to type-check. No `default` branch, no `assertNever` call. One place to add the handler when a new variant appears.

## Why This Helps AI

Three compounding effects.

**New variants cascade.** Add `stale` to `RemoteData`. Every `match` call and every exhaustive `switch` fails to compile until AI handles the new case. The diff is not "add a flag"; the diff is "extend the grammar."

**Named cases replace guessed flags.** AI autocompletes `case "failure":` because the variant name is in the type. It does not invent `if (!loading && error == null && data != null)`. The type hands AI a vocabulary.

**Nested ADTs keep data in scope.** `OrderError` inside `failure` hands AI the error fields at the moment a handler runs. No `if (error instanceof NotFoundError)` with a cast. No `error.code === "FORBIDDEN"` string compare.

The compiler reads the grammar. AI fills in the words. The reviewer checks that the grammar is the right one, not that every branch was handled.

## Trade-offs

These patterns cost something.

- Tagged variants add a `kind` field per case. Runtime cost is a short string per value.
- TypeScript has no pattern-matching syntax. A `switch` with `assertNever`, or a `match` helper, is the tool. Neither is as terse as Rust or Haskell.
- External APIs return flat shapes. Convert at the boundary, as post 03 covers, then keep the ADT internal.
- Not every `boolean` is an ADT. A single on/off toggle is a boolean. Two flags that describe one concept are an ADT.
- Deep ADT nesting past three levels reads worse than a flat record with a parse step. Stop when the tree stops helping.

Use ADTs where branching logic causes incidents. Skip them in a feature flag or a config struct.

## Takeaways

Every time branching logic derives from combinations of booleans and nulls, there is an ADT hiding in the code.

- Replace `{ data, loading, error }` with `RemoteData<T, E>`.
- Replace a bare `Error` with a sum of domain errors.
- Replace `if/else` chains on flags with `switch` on a `kind` tag.
- Replace `default: throw` with `assertNever` for exhaustiveness.

Each move converts a runtime guess into a compile-time check. AI cannot skip a case the compiler counts.

## Exercise

Find one `{ data, loading, error }` shape in your code — a hook return, an API slice, a page state.

Refactor it in four steps:

1. Write `RemoteData<T, E>` as a four-case sum type. Replace the old shape.
2. Split the component's render into a `switch` on `state.kind`. Delete every `data == null` check in the render path.
3. Add an `assertNever` default. Add a `stale` variant to `RemoteData`. Watch the compiler list every call site.
4. Split the `E` type into a sum of the errors your UI distinguishes. Delete the `instanceof` checks.

Then ask AI to add one more variant — `cancelled`, `optimistic`, anything. Count the compile errors that guide the change. That count is the margin between a reviewer catching the bug and the compiler catching it.

**Meta Description:** Algebraic Data Types replace { data, loading, error } in TypeScript. Tagged sums with exhaustive matching force AI-assisted code to handle every case.
