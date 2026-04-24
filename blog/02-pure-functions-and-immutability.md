# Pure Functions and Immutability

Pure functions and immutable data are two of the most useful functional programming ideas you can bring into everyday TypeScript. They do not require a new runtime, a framework, or an external library. They require one design habit: make data flow visible.

A pure function returns the same output for the same input and does not change anything outside itself. Immutable data means a value stays fixed after creation. This style gives humans and AI less hidden context to guess about.

## The Problem

Bugs come from code that changes data while also making a decision.

Consider common application workflows:

- A cart total recalculates after items, discounts, tax, and shipping are updated.
- A profile update validates input and mutates the existing user object.
- A scheduling rule changes a list of available slots while checking for conflicts.
- A request handler normalizes payload fields and records analytics events.

The risky part is not that state exists. Real applications need state. The risk appears when state changes mix into ordinary-looking business logic. A caller passes an object into a method without knowing the method mutates it. A later change reuses the same object in two places and shares updates by mistake. A test passes alone but fails after another test because state leaked.

This pain grows when AI edits the code. If mutation is implicit, AI must infer which functions are safe to call, which values stay valid, and which objects are shared.

## Where AI Struggles

AI struggles when a change depends on invisible history:

- **A function has hidden outputs.** It returns a value, but it also changes an object, updates a cache, or writes to a field.
- **Order matters but is not documented.** Calling `applyDiscount` before `addItem` may produce a different result than calling it after.
- **Shared references look independent.** Two variables point at the same mutable object, so changing one changes the other.
- **Tests require setup discipline.** The correct result depends on resetting internal state between examples.
- **Types describe shape, not behavior.** A `Cart` type says what fields exist, but not which functions mutate those fields.

Generated code follows the nearest visible pattern. If the visible pattern is "take an object and modify it in place," AI extends that pattern. It may add a rule in the middle of an existing mutation flow, forget one branch, or change a value before validation finishes.

Pure functions and immutable data make behavior visible in the function signature. Inputs come in. Outputs go out. The original value stays available for comparison, logging, retrying, or rollback.

## Traditional OOP Approach

Consider a shopping cart that supports items and percentage discounts:

```ts
type CartItem = {
  sku: string;
  quantity: number;
  unitPriceCents: number;
};

class ShoppingCart {
  private readonly items: CartItem[] = [];
  private discountPercent = 0;

  addItem(item: CartItem): void {
    const existing = this.items.find((current) => current.sku === item.sku);

    if (existing) {
      existing.quantity += item.quantity;
      return;
    }

    this.items.push(item);
  }

  applyDiscount(percent: number): void {
    if (percent < 0 || percent > 100) {
      throw new Error("Discount must be between 0 and 100");
    }

    this.discountPercent = percent;
  }

  totalCents(): number {
    const subtotal = this.items.reduce(
      (sum, item) => sum + item.quantity * item.unitPriceCents,
      0,
    );

    return Math.round(subtotal * (1 - this.discountPercent / 100));
  }
}
```

This design is familiar. It keeps cart behavior near cart state, and for a small example it is easy to follow.

The problems appear as the workflow grows:

- `addItem` mutates either an existing item or the internal array.
- The object stores discount state, so `totalCents` depends on call history.
- The caller cannot tell from the method names which data changes in place.
- Invalid discounts throw, so expected failure is not part of the return type.
- A test must create a fresh cart for every scenario or risk state leaking between checks.

AI asked to "add a buy-one-get-one rule" must now decide several things. Where should that state live? Does the rule mutate items? Should totals change existing quantities? How does this interact with discounts? The design leaves room to guess.

## Functional-Light TypeScript Approach

A functional-light version separates data updates from calculations and returns new values instead of mutating existing ones:

```ts
type CartItem = {
  readonly sku: string;
  readonly quantity: number;
  readonly unitPriceCents: number;
};

type Cart = {
  readonly items: ReadonlyArray<CartItem>;
  readonly discountPercent: number;
};

type DiscountError = {
  readonly kind: "discount-out-of-range";
  readonly percent: number;
};

type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

const emptyCart = (): Cart => ({
  items: [],
  discountPercent: 0,
});

const addItem = (cart: Cart, item: CartItem): Cart => {
  const existing = cart.items.find((current) => current.sku === item.sku);

  if (!existing) {
    return {
      ...cart,
      items: [...cart.items, item],
    };
  }

  return {
    ...cart,
    items: cart.items.map((current) =>
      current.sku === item.sku
        ? { ...current, quantity: current.quantity + item.quantity }
        : current,
    ),
  };
};

const applyDiscount = (
  cart: Cart,
  percent: number,
): Result<Cart, DiscountError> => {
  if (percent < 0 || percent > 100) {
    return {
      ok: false,
      error: { kind: "discount-out-of-range", percent },
    };
  }

  return {
    ok: true,
    value: { ...cart, discountPercent: percent },
  };
};

const totalCents = (cart: Cart): number => {
  const subtotal = cart.items.reduce(
    (sum, item) => sum + item.quantity * item.unitPriceCents,
    0,
  );

  return Math.round(subtotal * (1 - cart.discountPercent / 100));
};
```

This is ordinary TypeScript. There is no library-specific `List`, no advanced abstraction, and no runtime enforcement beyond what TypeScript conventions can express.

Each function now has a clearer contract:

- `addItem` returns a new `Cart`.
- `applyDiscount` returns either a new `Cart` or a typed validation error.
- `totalCents` is pure calculation from a `Cart` to a number.
- `readonly` fields and `ReadonlyArray` signal that callers should not mutate the value.
- Existing cart values stay available for comparison and testing.

The calling code becomes explicit about each step:

```ts
const cart = addItem(emptyCart(), {
  sku: "keyboard",
  quantity: 1,
  unitPriceCents: 12_500,
});

const discounted = applyDiscount(cart, 15);

if (!discounted.ok) {
  console.error("Invalid discount", discounted.error.percent);
} else {
  console.log(totalCents(discounted.value));
}
```

No hidden object changed during this flow. The original `cart` still represents the cart before the discount. The discounted cart is a separate value.

## Why This Helps AI

Pure functions and immutable data help AI because they turn implicit behavior into local, checkable structure.

When AI changes `totalCents`, it sees that the function takes a `Cart` and returns a `number`. It should not log, mutate, fetch, cache, or validate unrelated input there. The signature narrows the expected behavior.

When AI changes `addItem`, the return type tells it to produce a `Cart`. The existing implementation shows object spreading and `map`, so the local pattern points toward creating a new value instead of editing the old one.

When AI changes `applyDiscount`, the `Result<Cart, DiscountError>` type makes failure handling visible. Adding a new discount rule means extending the error type or adding another branch. Callers have a structure for handling failure.

This gives the compiler more chances to help. It also gives reviewers a smaller question to answer: "Does this function transform the input into the expected output?" That is easier to review than "Did this method change the right internal fields in the right order without affecting anything else?"

Immutability is a guardrail, not a guarantee. TypeScript's `readonly` is a compile-time signal, and JavaScript objects can be mutated if someone bypasses the types. The signal matters. AI tools follow visible local patterns, so immutable patterns make safer changes easier to imitate.

## Trade-offs

Pure functions and immutable data are not free:

- Returning new objects allocates more than mutating in place.
- Deeply nested updates become noisy without careful data modeling.
- Teams used to stateful objects may find the style unfamiliar at first.
- `readonly` in TypeScript does not provide deep runtime immutability.
- Some domains are stateful by nature: UI widgets, streams, database transactions, and long-lived connections.

The answer is not to remove all mutation. It is to isolate mutation behind clear boundaries.

Use pure functions for validation, pricing, formatting, filtering, rule evaluation, and other business transformations. Use immutable data for values that move between functions. Keep mutation for the edges: database writes, UI state updates, in-memory caches, and adapters around external systems.

In performance-sensitive paths, measure before assuming immutable updates cost too much. Most application workflows are dominated by I/O, network calls, rendering, or database work rather than small object allocations.

## Takeaways

Pure functions are easy to call, test, review, and move. Immutable data prevents one part of the code from surprising another part by changing a shared value.

For AI, these benefits compound:

- AI can infer intent from function signatures instead of hidden state.
- The compiler can catch more missing branches and invalid assignments.
- Tests can focus on input and output instead of setup and teardown.
- Reviews can reason about small transformations rather than object history.
- New rules stay local because the data flow is explicit.

You do not need to rewrite an application around functional programming to get these benefits. Start by finding one workflow where a function both decides something and mutates something. Split the decision into a pure function. Return a new value. Make expected failure explicit. That small move gives humans and AI clearer rails to follow.

## Exercise

Find a method in your codebase that updates an object and also calculates or validates something.

Refactor it in four steps:

1. Write down the input value the calculation needs.
2. Extract a pure function that takes that input and returns the calculated result or a typed error.
3. Change the update step so it creates a new value instead of mutating the original object.
4. Add a test that calls the pure function twice with the same input and checks that both calls return the same output.

After the refactor, ask AI to add one new rule to the calculation. Check whether it changes only the pure function, whether the original input stays unchanged, and whether TypeScript flags any caller that forgot to handle a new failure case.
