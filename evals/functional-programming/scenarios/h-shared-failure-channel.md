# H: Several steps share one expected-failure channel (TypeScript)

Tests under-application after the over-correction guards: when several
sequential steps share the same success/failure shape and two callers
sequence them, a small generic `Result<T, E>` with `map`/`flatMap` is the
smallest construct that states the short-circuit once. Domain-named outcomes
per step, or a shared shape with hand-written early returns copied per
handler, are not enough here.

## Prompt

Order intake is five steps, each with its own way of failing. Two handlers
sequence them and both copy the unwrap-and-bail logic, and the 400 should
say which field was bad but `parseOrder` throws that away. Make failure
handling consistent so a handler maps every expected failure to a status code
in one place, and so the step sequence is written once per handler without
the per-step bail-out being copied. Plain TypeScript, no FP library in the
project, and we don't want a new dependency.

```ts
// src/intake/steps.ts
export function parseOrder(body: unknown): OrderDraft | null {
  // returns null on any malformed input (missing customerId, empty lines,
  // non-string currency, ...); the caller cannot tell which field
  ...
}

export function normalizeLines(draft: OrderDraft): OrderDraft {
  // merges duplicate skus; throws Error(`negative quantity: ${sku}`) if any line is negative
  ...
}

export class OutOfStockError extends Error {
  constructor(public readonly sku: string) { super(`out of stock: ${sku}`); }
}

export function checkStock(draft: OrderDraft, stock: StockSnapshot): OrderDraft {
  for (const line of draft.lines) {
    if ((stock[line.sku] ?? 0) < line.quantity) throw new OutOfStockError(line.sku);
  }
  return draft;
}

export function applyPromotion(draft: OrderDraft, promos: PromoTable): { ok: boolean; draft?: OrderDraft; message?: string } {
  if (draft.promoCode === undefined) return { ok: true, draft };
  const promo = promos[draft.promoCode];
  if (promo === undefined || promo.expiresAt < draft.submittedAt) {
    return { ok: false, message: `invalid promo ${draft.promoCode}` };
  }
  ...
  return { ok: true, draft: discounted };
}

export function priceOrder(draft: OrderDraft, rates: RateTable): { ok: boolean; order?: PricedOrder; message?: string } {
  const rate = rates[draft.currency];
  if (rate === undefined) return { ok: false, message: `unsupported currency ${draft.currency}` };
  ...
  return { ok: true, order };
}
```

```ts
// src/intake/handlers.ts
export async function createOrder(req: Request, res: Response) {
  const [stock, promos, rates] = await Promise.all([stockService.snapshot(), promoService.table(), rateService.current()]);

  const draft = parseOrder(req.body);
  if (draft === null) return res.status(400).send("bad request");
  let normalized: OrderDraft;
  try {
    normalized = normalizeLines(draft);
  } catch (e) {
    return res.status(400).send((e as Error).message);
  }
  let checked: OrderDraft;
  try {
    checked = checkStock(normalized, stock);
  } catch (e) {
    if (e instanceof OutOfStockError) return res.status(409).send(e.message);
    throw e;
  }
  const promoted = applyPromotion(checked, promos);
  if (!promoted.ok) return res.status(422).send(promoted.message);
  const priced = priceOrder(promoted.draft!, rates);
  if (!priced.ok) return res.status(422).send(priced.message);

  await db.orders.insert(priced.order!); // may reject on connection loss
  return res.status(201).json(priced.order);
}

export async function quoteOrder(req: Request, res: Response) {
  const [promos, rates] = await Promise.all([promoService.table(), rateService.current()]);

  const draft = parseOrder(req.body);
  if (draft === null) return res.status(400).send("bad request");
  let normalized: OrderDraft;
  try {
    normalized = normalizeLines(draft);
  } catch (e) {
    return res.status(400).send((e as Error).message);
  }
  const promoted = applyPromotion(normalized, promos);
  if (!promoted.ok) return res.status(422).send(promoted.message);
  const priced = priceOrder(promoted.draft!, rates);
  if (!priced.ok) return res.status(422).send(priced.message);
  return res.status(200).json(priced.order);
}
```

## Rubric

Pass (all):

- Every expected failure (malformed input, negative quantity, out of stock,
  invalid promo, unsupported currency) is a value in the step's return type,
  and each error carries its domain detail (field, sku, promo code,
  currency), not a bare string.
- The five steps share one success/failure shape (a small `Result<T, E>`,
  `Either`, or an equivalent discriminated union) with `E` a union of the
  step errors. A generic `Result` is the intended answer here, not a smell.
- Sequencing is stated once per handler as a composition: `flatMap`/
  `andThen`/`map` on the result type, or a small helper that threads results
  through the steps, so neither handler repeats an unwrap-and-return per
  step.
- The handlers map failures to status codes in one `switch` over the error
  union, exhaustive with a `never` check or equivalent.
- The database write stays outside the result: connection loss still rejects
  the promise (or reaches the framework's error path) and is not converted
  into an intake error case.

Fail signals:

- Keeping `throw`/`catch` or `null` for any of the expected failures.
- Five differently-shaped outcomes (one per step) so each handler branches
  five different ways; or a shared shape with `if (!r.ok) return ...`
  repeated per step in both handlers, which is the copying the prompt asked
  to remove.
- One shared function with a `skipStock`-style flag and early returns, so
  which steps run is hidden in a boolean instead of stated in the
  composition.
- A bare `string` error that loses the field/sku/promo/currency.
- Wrapping the `db.orders.insert` rejection in the result as an ordinary
  failure case.
- Adding fp-ts, Effect, neverthrow, or another library after the prompt
  ruled out new dependencies.
- A `Result` module with combinators none of the callers use (for example
  `sequence`, `traverse`, applicative helpers, `Unit`).
