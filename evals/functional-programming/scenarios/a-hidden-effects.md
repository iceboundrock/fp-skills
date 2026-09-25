# A: Hidden effects in a service (TypeScript)

Tests under-application: can the agent pull decisions out of an effectful
function without inventing an abstraction for every dependency?

## Prompt

We need unit tests for the discount rules in `placeOrder`, but right now it is
basically untestable. Refactor as needed and write the tests (Vitest).

```ts
// src/orders/placeOrder.ts
import { CONFIG } from "../config";
import { db } from "../db";
import { analytics } from "../analytics";

export async function placeOrder(order: Order): Promise<Order> {
  let subtotal = 0;
  for (const item of order.items) {
    subtotal += item.unitPrice * item.quantity;
  }

  const hour = new Date(Date.now()).getUTCHours();
  if (hour >= CONFIG.happyHourStart && hour < CONFIG.happyHourEnd) {
    order.discount = subtotal * CONFIG.happyHourRate;
  } else if (subtotal > CONFIG.bulkThreshold) {
    order.discount = subtotal * CONFIG.bulkRate;
  } else {
    order.discount = 0;
  }
  order.total = subtotal - order.discount;
  order.placedAt = Date.now();

  analytics.track("order_placed", { total: order.total });
  await db.orders.insert(order);
  return order;
}
```

`Order` is `{ id: string; items: LineItem[]; discount?: number; total?: number; placedAt?: number }`.
`placeOrder` has two callers; both use the returned value.

## Rubric

Pass (all):

- Discount/total calculation becomes a function of explicit inputs
  (items or subtotal, the relevant config values, and the current time or hour).
- Tests exercise that function with no mocks of `db`, `analytics`, or the clock.
- `placeOrder` still reads config/time, tracks, and inserts. The effects stay
  in the shell, in the same order.
- Returned order has the same fields as before.

Fail signals (over-application):

- `Clock`, `ConfigProvider`, `AnalyticsPort`, `OrderRepository` interfaces
  or a dependency container that exist only so the tests can mock them,
  while the discount rule itself could have taken plain values.
- A `Result`/`Either` for the discount calculation, which has no expected
  failure, or a `pipe`/`compose` helper used once.
- The subtotal loop rewritten to `reduce` and presented as an improvement.
- Rewriting the callers or unrelated modules.

Neutral:

- Stopping the input mutation (returning a new order) is fine if the agent
  confirms callers only use the return value.
- Sampling `Date.now()` once and using it for both the happy-hour check and
  `placedAt` is fine if the agent names it as a behavior change: the original
  reads the clock twice, so `placedAt` can land in the hour after the one
  that chose the discount. Collapsing the two reads silently is a fail; the
  task did not ask for a behavior change.
- A dependency record on `placeOrder` (`{ now, track, insert }`) that names
  the shell's effects is acceptable if the pricing tests still need no fakes.
  It is a fail only when it is the mechanism that makes the pricing rule
  testable.
