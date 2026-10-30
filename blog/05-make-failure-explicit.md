# `undefined`, a Union, or `Result`? How to Make Failure Explicit in TypeScript

You already know how to make failure explicit in TypeScript. Posts 01 to 04 covered how. The harder question is which form the failure takes, and in this series' evals, AI agents got that wrong in both directions.

A Claude Sonnet run turned a database exception into a result case: "Infra failures are now a domain outcome too, not a leaked exception."

A `claude-opus-5-5` run pasted the same bail-out line after every step rather than write a helper. Its reason: "To remove it I'd need an `andThen`/`pipe` helper (a homemade FP library) or steps that throw, and both seemed worse than one line each."

I have written TypeScript for ten years. Both mistakes have one fix: let the form of a failure follow the shape of the code, not a preference for or against functional programming (FP). This post walks one feature through four forms and shows where each stops paying: `T | undefined`, a domain-named union, a shared `Result<T, E>`, and an exception.

## The Problem: Four Ways to Say "Not Booked"

The booking service below says "not booked" four ways. It throws `NotFoundError`, returns `null`, throws `ClassFullError`, or lets the database driver throw. Its return type mentions only the `null`. Every caller guesses the rest.

Sorting failures into three kinds ends the guessing:

- **Absence.** The record isn't there. A lookup miss carries no reason.
- **Expected rejection.** The record is there, and a business rule says no. The caller needs the reason.
- **Infrastructure failure.** The database timed out. No business rule ran, and a retry may succeed.

Sort each signal into one kind before you pick a construct.

## Where AI-Assisted Coding Struggles

AI copies the nearest convention. When the code has four, nothing tells it which one applies. Guidance doesn't settle it either: it can push an agent wrong in either direction. Both quotes above come from this repository's eval logs:

- **2026-09-24, Claude Sonnet, a C# transfer service (scenario F), one run each with no skill and with the old skill** ([log](https://github.com/iceboundrock/fp-skills/blob/main/evals/functional-programming/results/2026-09-24.md)). The first quote is from the run with no skill. The run with an older version of this repository's skill ("Prefer functional style by default") added a generic `Result<TValue, TError>` for one operation, calling it "the stronger guardrail".
- **2026-10-23, `claude-opus-5-5`, TypeScript intake handlers (scenario H), two isolated runs per variant** ([log](https://github.com/iceboundrock/fp-skills/blob/main/evals/functional-programming/results/2026-10-23.md)). Five steps shared one failure channel. The skill from pull request #19 listed hand-rolled `Result` and `pipe` helpers as red flags. With that skill, both runs repeated `if (!x.ok) return x;` after each step and cited the rule. The second quote is from run 2. With no skill, both runs wrote an `andThen` helper.

One or two runs per cell show that each failure happens, not how often. Neither skill separated one operation's outcomes from a failure channel that several steps share. This post draws that line.

## The Implicit Version

A fitness studio lets members book classes in its app, and front-desk staff book for them from a console. A full class puts the member on a waitlist.

```typescript
// The HTTP handler maps: Booking → 201, NotFoundError → 404, null → 403,
// ClassFullError → insert a waitlist entry, then 202. Anything else → 500.
async function bookClass(memberId: string, classId: string): Promise<Booking | null> {
  const member = await db.members.find(memberId);
  const session = await db.sessions.find(classId);
  if (!member || !session) throw new NotFoundError();
  if (member.membershipEndsAt < new Date()) return null;
  if (session.bookedCount >= session.capacity) throw new ClassFullError();
  return db.bookings.insert(member.id, session.id);
}
```

The signature promises a `Booking` or `null`. `null` means "membership expired", but only a comment says so. A missing record and a full class both throw, and the handler's `catch` performs the waitlist insert. `ClassFullError`, a normal outcome, travels on the same channel as a database timeout. The front-desk console needs its own copy of that `catch`.

Ask an AI to add "off-peak plans can't book peak classes". It has four conventions to copy and no type that says which one applies.

## Making Failure Explicit in TypeScript, One Step at a Time

### Name One Operation's Outcomes

One operation with meaningful outcomes gets a domain-named union. This operation writes, so it needs two: what to do, and what happened.

```typescript
// What to do. Decided from loaded records, before any write.
type BookingDecision =
  | { readonly kind: "book" }
  | { readonly kind: "waitlist" }
  | { readonly kind: "reject"; readonly reason: "membership-expired" };

// What happened. Returned after the write, if any, succeeds.
type BookingOutcome =
  | { readonly kind: "booked"; readonly booking: Booking }
  | { readonly kind: "waitlisted" }
  | { readonly kind: "rejected"; readonly reason: "membership-expired" }
  | { readonly kind: "not-found" };

const decideBooking = (member: Member, session: ClassSession, now: Date): BookingDecision => {
  if (member.membershipEndsAt < now) return { kind: "reject", reason: "membership-expired" };
  if (session.bookedCount >= session.capacity) return { kind: "waitlist" };
  return { kind: "book" };
};

async function bookClass(memberId: string, classId: string): Promise<BookingOutcome> {
  const member = await db.members.find(memberId);
  const session = await db.sessions.find(classId);
  if (!member || !session) return { kind: "not-found" };

  const decision = decideBooking(member, session, new Date());
  switch (decision.kind) {
    case "book":
      return { kind: "booked", booking: await db.bookings.insert(member.id, session.id) };
    case "waitlist":
      await db.waitlist.insert(member.id, session.id);
      return { kind: "waitlisted" };
    case "reject":
      return { kind: "rejected", reason: decision.reason };
  }
}
```

`book` is an instruction, and `booked` is a fact. The insert can still fail after the decision says `book`, so code that sends a confirmation on `book` could confirm a seat nobody saved.

The HTTP handler maps the four outcomes to 201, 202, 403, and 404, and the console maps them to its own messages. A second caller is no reason to make the type generic: `BookingOutcome` already tells both callers every case. Give each mapping a declared return type or post 04's `assertNever` default, and the compiler flags one that misses a case.

The effects keep their order: read the member, read the class, check for absence, read the clock once, decide, then write at most once. The checks keep their order too, so an expired member asking for a full class still gets 403, not a waitlist place.

The pure function makes nothing atomic. `decideBooking` sees records loaded before it ran, so two requests for the last seat can both decide `book`. The original code has the same race, and this refactor neither adds nor fixes it. Closing it takes the database: a capacity constraint, a conditional insert, or a transaction that locks the class row when it reads it.

### Absence: `undefined` Is Enough Here

`db.members.find` returns `Member | undefined`, and `bookClass` checks it once, right after the loads. That is already the smallest form.

Absence is not rejection. A missing member gets a 404 with no reason, and an expired membership gets a rejection with one. Only the rejection belongs in `BookingDecision`, which runs on records that exist.

An `Option<T>` type earns its place when absence flows through several transformations and its `map` calls read more plainly than optional chaining (`?.`, `??`) at the call sites, or when the codebase already has one. Don't add an `Option` for one `if`.

### Stop Here: The "More Functional" Version Is Worse

For this flow, the next construct removes no decisions. Here it is anyway:

```typescript
type BookingError =
  | { readonly kind: "not-found" }
  | { readonly kind: "membership-expired" }
  | { readonly kind: "class-full" } // the waitlist, filed as an error
  | { readonly kind: "database"; readonly cause: unknown }; // an outage, filed as a rejection

type BookClass = (memberId: string, classId: string) => Promise<Result<Booking, BookingError>>;
```

Add an `Option` to each lookup, and the code gains vocabulary without gaining a decision. It also breaks two contracts:

- **The waitlist becomes an error.** Either `bookClass` writes the waitlist entry and then reports failure, or every caller performs the insert in its error branch. The second is the original `catch` again.
- **An outage becomes "you can't book".** Every caller must remember that one error kind means "try again". A caller that forgets answers a timeout as a business rule.

For one flow, the domain union is where to stop. In this example, the reason to go further arrives with the next feature.

### When Several Checks Share a Failure Channel

The studio adds class packs, where each class costs one credit, and off-peak plans, which exclude peak classes. It also adds a job: when a seat frees up, the job re-checks the first waitlisted member, then promotes them or moves to the next.

The studio charges a credit when a member takes a seat, at booking or at promotion, under the plan they hold then. Joining a waitlist costs nothing but still requires a credit. The job re-checks the membership and the credits, because both can change while a member waits. It skips the plan check: a member who switches to an off-peak plan keeps their place on a peak class's waitlist.

Three checks now share one failure channel, and two flows sequence different combinations of them. That is the case this series reserves a shared `Result` for. It is post 01's `Result` shape plus two constructors:

```typescript
type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

const ok = <T>(value: T): Result<T, never> => ({ ok: true, value });
const err = <E>(error: E): Result<never, E> => ({ ok: false, error });

type Plan =
  | { readonly kind: "unlimited" }
  | { readonly kind: "off-peak" }
  | { readonly kind: "class-pack"; readonly credits: number };

type Rejection = "membership-expired" | "peak-not-in-plan" | "no-credits";
type Charge = { readonly credits: 0 | 1 };

const checkMembership = (member: Member, now: Date): Result<Plan, Rejection> =>
  member.membershipEndsAt < now ? err("membership-expired") : ok(member.plan);

const checkPlan = (plan: Plan, session: ClassSession): Result<Plan, Rejection> =>
  plan.kind === "off-peak" && session.peak ? err("peak-not-in-plan") : ok(plan);

const checkCredits = (plan: Plan): Result<Charge, Rejection> => {
  if (plan.kind !== "class-pack") return ok({ credits: 0 });
  return plan.credits > 0 ? ok({ credits: 1 }) : err("no-credits");
};
```

Each check feeds the next: the membership yields the plan, and the plan sets the charge. Booking runs all three checks, and promotion runs membership, then credits. Both flows with early returns:

```typescript
const checkBooking = (member: Member, session: ClassSession, now: Date): Result<Charge, Rejection> => {
  const plan = checkMembership(member, now);
  if (!plan.ok) return plan;
  const covered = checkPlan(plan.value, session);
  if (!covered.ok) return covered;
  return checkCredits(covered.value);
};

const checkPromotion = (member: Member, now: Date): Result<Charge, Rejection> => {
  const plan = checkMembership(member, now);
  if (!plan.ok) return plan;
  return checkCredits(plan.value);
};
```

The same with `andThen`, also called `flatMap` or `bind`, which runs the next step only on `ok`:

```typescript
const andThen = <T, U, E>(result: Result<T, E>, next: (value: T) => Result<U, E>): Result<U, E> =>
  result.ok ? next(result.value) : result;

const checkBooking = (member: Member, session: ClassSession, now: Date): Result<Charge, Rejection> => {
  const plan = checkMembership(member, now);
  const covered = andThen(plan, (p) => checkPlan(p, session));
  return andThen(covered, checkCredits);
};

const checkPromotion = (member: Member, now: Date): Result<Charge, Rejection> =>
  andThen(checkMembership(member, now), checkCredits);
```

Both versions return the same result for the same input and stop at the first rejection. `andThen` states that rule once, not after every step. `map` would not do: it expects a step that cannot fail, so each check's `Result` would nest inside another.

This example sits on the boundary: two call sites, with three steps and two. Early returns are still defensible here, and `andThen` pays as steps and call sites grow. It also needs synchronous steps, which these checks over loaded records are. Put an `await` between steps and each returns a `Promise<Result>`, which this `andThen` cannot take. Early returns still work there.

Booking wants the first rejection only: the member sees one reason. Collecting every error, as a sign-up form does, needs a different tool.

`decideBooking` turns the shared channel back into the booking's own union. `book` now carries a `Charge`, and `reject` carries any `Rejection`. `BookingOutcome`'s `rejected` case widens to `Rejection` the same way.

```typescript
type BookingDecision =
  | { readonly kind: "book"; readonly charge: Charge }
  | { readonly kind: "waitlist" }
  | { readonly kind: "reject"; readonly reason: Rejection };

const decideBooking = (member: Member, session: ClassSession, now: Date): BookingDecision => {
  const eligible = checkBooking(member, session, now);
  if (!eligible.ok) return { kind: "reject", reason: eligible.error };
  if (session.bookedCount >= session.capacity) return { kind: "waitlist" };
  return { kind: "book", charge: eligible.value };
};
```

`Result` is the channel the checks share, not what `bookClass`'s callers see. The order is now membership, plan, credits, then capacity, and the first rejection wins. A member on the unlimited plan passes the plan check and pays nothing, so their bookings behave as before.

The `book` branch of `bookClass` now inserts the booking and debits `charge.credits` in one transaction, and the job's promotion write does the same. The pure function can't make that atomic. A debit conditional on a positive balance stops two bookings from spending the same last credit, but it misses a plan change. A member who switches from unlimited to a class pack after the load still gets `credits: 0`, and a zero debit checks nothing.

Both writes must protect every input their decision read: membership, plan, credits, and capacity. Lock the member and class rows when the transaction reads them, or make the write conditional on both rows' versions. What the shell does when a version check fails, such as rerunning the decision or answering 409, is a separate design question.

### Infrastructure Failures Stay Exceptions

None of the code above catches a driver error. It propagates out of `bookClass`, the HTTP handler answers 500, and the job retries on its next run.

Convert the failures the caller handles as normal flow, not every exception. An outage is not a business rule. A UI may still show a network failure as state, as post 04's `RemoteData` does. That is a choice made at one boundary, not a reason to add `database` to `Rejection`.

## Why This Helps AI

Each form tells an AI something specific:

- A domain-named union says "handle every case, and here are their names."
- A shared `Result` says "these steps stop at the first rejection."
- An exception says "not your branch."

One convention per kind of failure leaves the AI one pattern to copy, not four. Ask it to add "suspended members can't book". The nearest example is `checkMembership`, which returns `Result<Plan, Rejection>`. The AI adds `"suspended"` to `Rejection`, and the compiler flags every exhaustive mapping that lacks it.

## Trade-offs

- One more type per operation, or two when it writes.
- A `Result` module to own. Keep it to the type, `ok`, `err`, and `andThen`. Helpers such as `sequence` and `traverse` with no caller turn it into the problem.
- `andThen` over independent guards becomes a row of closures. Use it when each step's output feeds the next.
- An existing project convention wins. If your codebase uses a `Result` library, or throws everywhere and maps at one boundary, follow it.

These rules are this series' guidance and match this repository's AI skill. TypeScript prescribes none of them.

They also refine post 01's rule 1, "Return `Result<T, E>` for expected failures." The failure still belongs in the return type, but its form depends on who owns it. One operation's outcomes get a domain-named union. A channel that several operations share, and callers sequence, gets `Result<T, E>`. Post 01's `validate` → `registerUser` is that shared case: two steps, one early return.

## Takeaways: Five Decision Rules

![Decision tree routing a failure signal to T | undefined, a domain-named union, a shared Result, or an exception](image-placeholder)

1. Absence checked once, locally: `T | undefined`.
2. One operation with meaningful outcomes: a domain-named union, however many callers.
3. Several operations that share an expected-failure channel, sequenced by callers: `Result<T, DomainError>`.
4. Two or three steps at one call site: early returns. The same bail-out repeated across more steps or several call sites: `andThen`.
5. Database, network, and bugs: exceptions, unless a boundary chooses to show them as state.

When an operation writes, separate what to do from what happened, and keep its effects in their original order.

## Exercise

1. Find a function that returns `null` or throws for an expected case.
2. Label each failure signal as absence, rejection, or infrastructure.
3. Name the operation's outcomes as a union. If it writes, split what to do from what happened.
4. Count the operations that share the failure channel before you reach for `Result`.
5. Ask an AI to add one rule. Check which form it copies.

**Meta Description:** How to make failure explicit in TypeScript: when to use undefined, a domain union, a shared Result, or an exception, and when more abstraction makes code worse.
