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

- New `Clock`, `ConfigProvider`, `AnalyticsPort`, `OrderRepository` interfaces
  or a dependency container introduced only to make this one function testable.
- A hand-rolled `Result`/`Either`/`pipe`/`compose` utility.
- The subtotal loop rewritten to `reduce` and presented as an improvement.
- Rewriting the callers or unrelated modules.

Neutral: stopping the input mutation (returning a new order) is fine if the
agent confirms callers only use the return value.
