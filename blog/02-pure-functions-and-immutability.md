# Pure Functions and Immutability

Pure functions and immutable data are two of the most useful functional programming ideas you can bring into everyday TypeScript. They do not require a new runtime, a framework, or an external library. They mostly require one design habit: make data flow visible.

A pure function returns the same output for the same input and does not change anything outside itself. Immutable data means a value is treated as fixed once it has been created. When behavior is expressed this way, both humans and AI assistants have less hidden context to guess about.

## The Problem

Many bugs come from code that changes data while it is also trying to make a decision.

Consider common application workflows:

- A cart total is recalculated after items, discounts, tax, and shipping are updated.
- A profile update validates input and mutates the existing user object.
- A scheduling rule changes a list of available slots while checking for conflicts.
- A request handler normalizes payload fields and also records analytics events.

The risky part is not that state exists. Real applications need state. The risky part is when state changes are mixed into ordinary-looking business logic. A caller may pass an object into a method and not realize the method mutates it. A later change may reuse the same object in two places and accidentally share updates. A test may pass when run alone but fail when run after another test because some state leaked.

This is especially painful when AI-assisted coding tools are editing the code. If mutation is implicit, the assistant has to infer which functions are safe to call, which values are still valid, and which objects are shared.

## Where AI-Assisted Coding Struggles

AI-assisted coding struggles when a change depends on invisible history:

- **A function has hidden outputs.** It returns a value, but it also changes an object, updates a cache, or writes to a field.
- **Order matters but is not documented.** Calling `applyDiscount` before `addItem` may produce a different result than calling it after.
- **Shared references look independent.** Two variables point at the same mutable object, so changing one changes the other.
- **Tests require setup discipline.** The correct result depends on resetting internal state between examples.
- **Types describe shape, not behavior.** A `Cart` type can say what fields exist, but it does not say which functions mutate those fields.

Generated code tends to follow the nearest visible pattern. If the visible pattern is "take an object and modify it in place," the assistant will usually extend that pattern. It may add a new rule in the middle of an existing mutation flow, forget one branch, or accidentally change a value before validation has completed.

Pure functions and immutable data make more of the behavior visible in the function signature. Inputs come in. Outputs go out. The original value remains available for comparison, logging, retrying, or rollback.

## Traditional OOP Approach

Imagine a simple shopping cart that supports items and percentage discounts:

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

This is a familiar design. It keeps cart behavior near cart state, and for a small example it is easy to follow.

The problems appear as the workflow grows:

- `addItem` mutates either an existing item or the internal array.
- The object stores discount state, so `totalCents` depends on call history.
- The caller cannot tell from the method names which data is changed in place.
- Invalid discounts throw, so expected failure is not part of the return type.
- A test has to create a fresh cart for every scenario or risk state leaking between checks.

An AI assistant asked to "add a buy-one-get-one rule" now has to decide where that state should live, whether the rule mutates items, whether totals should change existing quantities, and how this interacts with discounts. The design gives the assistant room to guess.

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

This is still ordinary TypeScript. There is no library-specific `List`, no advanced abstraction, and no runtime enforcement beyond the conventions TypeScript can help express.

The important change is that each function has a clearer contract:

- `addItem` returns a new `Cart`.
- `applyDiscount` returns either a new `Cart` or a typed validation error.
- `totalCents` is pure calculation from a `Cart` to a number.
- `readonly` fields and `ReadonlyArray` communicate that callers should not mutate the value.
- Existing cart values remain available for comparison and testing.

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

Pure functions and immutable data help AI-assisted coding because they turn implicit behavior into local, checkable structure.

When an AI assistant changes `totalCents`, it can see that the function only receives a `Cart` and returns a `number`. It should not log, mutate, fetch, cache, or validate unrelated input there. The signature narrows the expected behavior.

When the assistant changes `addItem`, the return type tells it to produce a `Cart`. The existing implementation shows object spreading and `map`, so the local pattern points toward creating a new value instead of editing the old one.

When the assistant changes `applyDiscount`, the `Result<Cart, DiscountError>` type makes failure handling visible. Adding a new discount rule means extending the error type or adding another branch. Callers already have a structure for handling failure.

This gives the compiler more opportunities to help. It also gives reviewers a smaller question to answer: "Does this function transform the input into the expected output?" That is easier to review than "Did this method change the right internal fields in the right order without affecting anything else?"

Immutability is a guardrail, not a guarantee. TypeScript's `readonly` is mostly a compile-time signal, and JavaScript objects can still be mutated if someone chooses to bypass the types. But the signal matters. AI tools are strongly influenced by visible local patterns, and immutable patterns make safer changes easier to imitate.

## Trade-offs

Pure functions and immutable data are not free:

- Returning new objects can allocate more than mutating in place.
- Deeply nested updates can become noisy without careful data modeling.
- Teams used to stateful objects may find the style unfamiliar at first.
- `readonly` in TypeScript does not provide deep runtime immutability.
- Some domains are naturally stateful, such as UI widgets, streams, database transactions, and long-lived connections.

The practical answer is not to remove all mutation. It is to isolate mutation behind clear boundaries.

Use pure functions for validation, pricing, formatting, filtering, rule evaluation, and other business transformations. Use immutable data for values that move between functions. Keep mutation for the edges: database writes, UI state updates, in-memory caches, and adapters around external systems.

In performance-sensitive paths, measure before assuming immutable updates are too expensive. Many application workflows are dominated by I/O, network calls, rendering, or database work rather than small object allocations.

## Takeaways

Pure functions are useful because they are easy to call, test, review, and move. Immutable data is useful because it prevents one part of the code from surprising another part by changing a shared value.

For AI-assisted coding, these benefits become stronger:

- The assistant can infer intent from function signatures instead of hidden state.
- The compiler can catch more missing branches and invalid assignments.
- Tests can focus on input and output instead of setup and teardown.
- Reviews can reason about small transformations rather than object history.
- New rules tend to stay local because the data flow is explicit.

You do not need to rewrite an application around functional programming to get these benefits. Start by identifying one workflow where a function both decides something and mutates something. Split the decision into a pure function. Return a new value. Make expected failure explicit. That small move often gives both humans and AI tools better rails to follow.

## Exercise

Find a method in your codebase that updates an object and also calculates or validates something.

Refactor it in four steps:

1. Write down the input value the calculation actually needs.
2. Extract a pure function that takes that input and returns the calculated result or a typed error.
3. Change the update step so it creates a new value instead of mutating the original object.
4. Add a test that calls the pure function twice with the same input and checks that both calls return the same output.

After the refactor, ask an AI assistant to add one new rule to the calculation. Review whether it changes only the pure function, whether the original input remains unchanged, and whether TypeScript points out any caller that forgot to handle a new failure case.
