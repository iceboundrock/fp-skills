# TypeScript Types as AI Guardrails: Narrow the Surface an AI Can Get Wrong

An AI agent rewrote a shipping handler last month. The diff compiled. The unit tests passed. The production order it created had `isShipped: true`, `isPaid: false`, and `paidAt: null`. The type said `Order`. The type lied.

`readonly` fields and `Result` returns are table stakes. The next leverage point for AI-assisted TypeScript is the shape of the data itself. Types that make invalid states unrepresentable shrink the space where an AI can guess.

## The Problem

Application types start as grab bags.

A typical `Order` has a status string, three boolean flags, five optional timestamps, and two stringly-typed IDs. The type accepts the valid states. It also accepts every invalid combination between them.

A senior engineer remembers that a shipped order must have a paid timestamp. That rule lives in their head, in a pull request from eight months ago, and in nowhere the compiler can see.

AI cannot read the pull request. It reads the type. If the type allows the combination, AI treats the combination as legal.

## Where AI-Assisted Coding Struggles

Four patterns cause the damage.

**Boolean flags that should be mutually exclusive.** An `Order` with both `isDraft: true` and `isSubmitted: true` is nonsense, but the type accepts it. AI generates a refund flow that flips one flag and forgets the other.

**Optional fields whose presence depends on another field.** `paidAt` is only valid when `isPaid: true`. The type says `paidAt?: Date`, so every function must re-check the pairing. AI forgets one branch.

**Primitive IDs that swap silently.** `saveOrder(userId, orderId)` compiles the same as `saveOrder(orderId, userId)`. Both are `string`. The bug surfaces in production.

**Unknown payloads parsed by shape-guessing.** A webhook handler takes `unknown`, runs five `if (x.foo != null)` checks, and passes the object to the next function as `any`. Every downstream change carries the assumption.

AI completes each of these patterns by imitation. If the visible pattern allows invalid states, AI extends the allowance.

## Traditional OOP Approach

Consider an order lifecycle: draft, submitted, paid, shipped, cancelled.

```typescript
type OrderItem = {
  sku: string;
  quantity: number;
  unitPriceCents: number;
};

type Order = {
  id: string;
  userId: string;
  items: OrderItem[];
  status: string;
  isDraft: boolean;
  isSubmitted: boolean;
  isPaid: boolean;
  isShipped: boolean;
  submittedAt: Date | null;
  paidAt: Date | null;
  shippedAt: Date | null;
  trackingNumber: string | null;
  cancellationReason: string | null;
};

class OrderService {
  markShipped(order: Order, trackingNumber: string): Order {
    order.isShipped = true;
    order.shippedAt = new Date();
    order.trackingNumber = trackingNumber;
    order.status = "shipped";
    return order;
  }
}
```

The type is permissive. It accepts:

- `isShipped: true` with `isPaid: false`.
- `status: "paid"` with `paidAt: null`.
- `trackingNumber: "X123"` with `isShipped: false`.
- `saveOrder(order.userId, order.id)` and `saveOrder(order.id, order.userId)` — both compile.

Ask AI to add a refund state. It adds `isRefunded: boolean` and `refundedAt: Date | null`. The type now has eight new boolean combinations that never occur in practice and one more pair of co-dependent nullable fields. The compiler accepts all of them.

## Functional-Light TypeScript Approach

Three plain-TypeScript moves remove the invalid states.

**Move 1: One discriminated union per state.** Each variant carries only the fields valid in that state.

```typescript
type OrderItem = {
  readonly sku: string;
  readonly quantity: number;
  readonly unitPriceCents: number;
};

type Draft = {
  readonly status: "draft";
  readonly id: OrderId;
  readonly userId: UserId;
  readonly items: ReadonlyArray<OrderItem>;
};

type Submitted = {
  readonly status: "submitted";
  readonly id: OrderId;
  readonly userId: UserId;
  readonly items: ReadonlyArray<OrderItem>;
  readonly submittedAt: Date;
};

type Paid = {
  readonly status: "paid";
  readonly id: OrderId;
  readonly userId: UserId;
  readonly items: ReadonlyArray<OrderItem>;
  readonly submittedAt: Date;
  readonly paidAt: Date;
};

type Shipped = {
  readonly status: "shipped";
  readonly id: OrderId;
  readonly userId: UserId;
  readonly items: ReadonlyArray<OrderItem>;
  readonly submittedAt: Date;
  readonly paidAt: Date;
  readonly shippedAt: Date;
  readonly trackingNumber: string;
};

type Cancelled = {
  readonly status: "cancelled";
  readonly id: OrderId;
  readonly userId: UserId;
  readonly items: ReadonlyArray<OrderItem>;
  readonly cancelledAt: Date;
  readonly reason: string;
};

type Order = Draft | Submitted | Paid | Shipped | Cancelled;
```

There is no `paidAt: Date | null`. A `Paid` order has `paidAt`. A `Draft` order does not. The combination "shipped but not paid" cannot be written.

**Move 2: Branded IDs.** Give each ID a distinct compile-time identity.

```typescript
type OrderId = string & { readonly __brand: "OrderId" };
type UserId = string & { readonly __brand: "UserId" };

const orderId = (value: string): OrderId => value as OrderId;
const userId = (value: string): UserId => value as UserId;
```

`saveOrder(orderId, userId)` no longer compiles with the arguments flipped. Two `string` values that mean different things fail type-checking when swapped.

**Move 3: Parse at the boundary.** Turn `unknown` input into a typed value once, at the edge.

```typescript
type ParseError =
  | { readonly kind: "missing-field"; readonly field: string }
  | { readonly kind: "invalid-type"; readonly field: string; readonly expected: string };

type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

type OrderRequest = {
  readonly userId: UserId;
  readonly items: ReadonlyArray<OrderItem>;
};

const parseOrderRequest = (input: unknown): Result<OrderRequest, ParseError> => {
  if (typeof input !== "object" || input === null) {
    return {
      ok: false,
      error: { kind: "invalid-type", field: "root", expected: "object" },
    };
  }

  const record = input as Record<string, unknown>;

  if (typeof record.userId !== "string") {
    return { ok: false, error: { kind: "missing-field", field: "userId" } };
  }
  if (!Array.isArray(record.items)) {
    return { ok: false, error: { kind: "missing-field", field: "items" } };
  }

  return {
    ok: true,
    value: {
      userId: userId(record.userId),
      items: record.items as ReadonlyArray<OrderItem>,
    },
  };
};
```

Downstream functions never see `unknown`. They see a typed `OrderRequest`. The guessing ends at the boundary.

State transitions now read as total functions between variants:

```typescript
const markPaid = (order: Submitted, paidAt: Date): Paid => ({
  ...order,
  status: "paid",
  paidAt,
});

const markShipped = (
  order: Paid,
  shippedAt: Date,
  trackingNumber: string,
): Shipped => ({
  ...order,
  status: "shipped",
  shippedAt,
  trackingNumber,
});
```

`markShipped` cannot accept a `Draft`. The type system rejects the call.

## Why This Helps AI

Three compounding effects.

**Exhaustive matching forces AI to see every state.** A `switch` on `order.status` with no default must handle all five variants. Add a `Refunded` variant and every switch becomes a compile error until AI extends it. The new state cannot slip through one code path.

**Branded IDs close an entire class of silent bugs.** AI fills function arguments by matching types. When `UserId` and `OrderId` are distinct types, AI cannot pass them in the wrong order. A human reviewer no longer needs to mentally check argument positions.

**Parse-at-boundary narrows the surface of internal code.** Every function below `parseOrderRequest` operates on a typed value. AI-generated handlers do not re-check `typeof x === "string"` or guess field shapes. The permissive input pattern is not visible for AI to imitate.

The compiler is the cheapest reviewer on the team. Types that forbid invalid states convert "reviewer catches the mistake" into "AI cannot write the mistake."

## Trade-offs

These techniques cost something.

- Discriminated unions duplicate shared fields. Orders with ten shared fields and three state-specific fields feel verbose. Factor shared fields into a common object when duplication exceeds three fields.
- Branded IDs need small constructors at every boundary where raw strings enter the system. The constructor is one line per type.
- Parse-at-boundary adds one function per external input. Schema libraries reduce the cost, but the pattern works with plain TypeScript.
- `readonly` and branded types are compile-time only. A runtime cast bypasses them. Treat the types as guardrails against honest mistakes, not attackers.
- Converting a legacy codebase is not a weekend job. Start with one aggregate, one boundary, or one pair of IDs that reviewers keep catching swapped.

Use the techniques where invalid states cause production incidents. Skip them in throwaway scripts and single-call glue code.

## Takeaways

Types are documentation the compiler reads.

- Replace co-dependent boolean flags with a discriminated union on `status`.
- Replace nullable fields that depend on other fields with variants that include or omit them.
- Replace primitive IDs with branded types at the boundaries where ambiguity costs time.
- Replace scattered shape checks with one parse function at the edge.

Each move narrows the surface an AI can get wrong. A compiler error at edit time costs seconds. A bad order in production costs hours.

## Exercise

Find one type in your codebase that has two or more boolean flags, or two or more optional fields whose presence depends on each other.

Refactor it in three steps:

1. List the real states the value can be in. Write each one as a variant with only the fields valid in that state.
2. Pick one pair of IDs that reviewers have caught swapped before. Convert both to branded types. Fix the call sites the compiler flags.
3. Find one function that takes `unknown` or `any` from an external source. Write a `parse*` function that returns `Result<Typed, ParseError>`. Move the `unknown` to one function and the typed value to the rest.

Then ask AI to add one new state or one new field. Count the compile errors that steer the change. That count is the margin between a reviewer catching the mistake and the compiler catching it.

**Meta Description:** Typed data shapes stop AI-assisted TypeScript from writing invalid states. Use discriminated unions, branded IDs, and parse-at-boundary as compile-time guardrails.
