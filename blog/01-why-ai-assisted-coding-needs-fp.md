# Why AI-Assisted Coding Needs FP

AI-assisted coding is good at producing code quickly. It is less reliable at preserving design intent across a growing codebase. The more implicit state, hidden mutation, and loosely defined contracts a design has, the harder it is for both humans and AI tools to keep changes local and correct.

Functional programming helps here, even in small doses. In TypeScript, we can use plain functions, immutable data, discriminated unions, and explicit return values without adopting a new framework or external library. These techniques turn design expectations into code-level guardrails.

## The Problem

AI tools often generate code by matching local patterns. If the visible pattern is a class with mutable fields and methods that perform validation, formatting, persistence, and logging in one place, the next generated change will usually follow that shape.

That can work for simple features. It becomes fragile when behavior changes:

- A validation rule is added in one path but not another.
- A method mutates shared state before it knows the input is valid.
- A caller forgets to handle an error case because the type signature does not mention it.
- A side effect is hidden inside a helper that looks like a calculation.

The problem is not that AI writes bad code on purpose. The problem is that weak boundaries give it too much room to guess.

## Where AI-Assisted Coding Struggles

AI-assisted coding struggles most when important rules are implicit:

- **State changes are hidden.** A method can update an object, write to a database, and return a value from the same call.
- **Failures are informal.** Code may throw, return `null`, return `undefined`, or quietly skip work.
- **Data shapes are loose.** Optional fields and broad interfaces allow invalid combinations.
- **Responsibilities are mixed.** A single unit handles validation, transformation, authorization, persistence, and logging.

These issues are manageable for experienced developers, but they are poor guardrails for generated code. If the code does not make the rules visible, an AI assistant has to infer them from examples, comments, or naming conventions.

## Traditional OOP Approach

Consider a simple user registration workflow. A traditional object-oriented version might collect behavior inside a service class:

```ts
type UserRecord = {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
};

class RegistrationService {
  private readonly users: UserRecord[] = [];
  private nextId = 1;

  register(email: string, displayName: string): UserRecord {
    if (!email.includes("@")) {
      throw new Error("Invalid email");
    }

    if (displayName.trim().length === 0) {
      throw new Error("Display name is required");
    }

    const user = {
      id: `user-${this.nextId++}`,
      email: email.toLowerCase(),
      displayName: displayName.trim(),
      createdAt: new Date(),
    };

    this.users.push(user);
    console.log("registered user", user.id);

    return user;
  }
}
```

This is not terrible code. It is compact and understandable. But it gives an AI assistant several ways to make unsafe changes later:

- Validation, normalization, ID generation, time, persistence, and logging are coupled.
- Errors are thrown, so callers cannot see possible failure modes from the return type.
- The service mutates internal state, which makes behavior depend on call history.
- Testing requires working around time, randomness, mutation, and logging.

The design relies on discipline more than structure.

## Functional-Light TypeScript Approach

A functional-light version keeps the same business behavior but makes the flow more explicit:

```ts
type RegistrationInput = {
  readonly email: string;
  readonly displayName: string;
};

type RegistrationError =
  | { readonly kind: "invalid-email" }
  | { readonly kind: "missing-display-name" };

type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

type NewUser = {
  readonly email: string;
  readonly displayName: string;
};

type UserRecord = NewUser & {
  readonly id: string;
  readonly createdAt: Date;
};

type RegistrationDeps = {
  readonly createId: () => string;
  readonly now: () => Date;
  readonly saveUser: (user: UserRecord) => void;
  readonly log: (message: string, fields: Record<string, string>) => void;
};

const validateRegistration = (
  input: RegistrationInput,
): Result<NewUser, RegistrationError> => {
  const email = input.email.trim().toLowerCase();
  const displayName = input.displayName.trim();

  if (!email.includes("@")) {
    return { ok: false, error: { kind: "invalid-email" } };
  }

  if (displayName.length === 0) {
    return { ok: false, error: { kind: "missing-display-name" } };
  }

  return { ok: true, value: { email, displayName } };
};

const createUserRecord = (
  user: NewUser,
  deps: Pick<RegistrationDeps, "createId" | "now">,
): UserRecord => ({
  ...user,
  id: deps.createId(),
  createdAt: deps.now(),
});

const registerUser = (
  input: RegistrationInput,
  deps: RegistrationDeps,
): Result<UserRecord, RegistrationError> => {
  const validated = validateRegistration(input);

  if (!validated.ok) {
    return validated;
  }

  const user = createUserRecord(validated.value, deps);

  deps.saveUser(user);
  deps.log("registered user", { userId: user.id });

  return { ok: true, value: user };
};
```

This is still ordinary TypeScript. There are no monads, no external libraries, and no advanced FP vocabulary required. The main difference is that each decision is visible:

- `validateRegistration` is pure and easy to test.
- `Result` forces callers to handle success and failure.
- `RegistrationError` documents the known failure cases.
- Dependencies such as time, ID generation, persistence, and logging are passed in.
- Side effects are kept near the workflow boundary.

The functional version is a little more verbose, but the extra code is mostly useful structure.

## Why This Helps AI

Functional-light TypeScript helps AI-assisted coding because it reduces the number of hidden assumptions the assistant has to infer.

When an AI tool changes `validateRegistration`, it can see that the function returns a `Result<NewUser, RegistrationError>`. If a new validation rule is required, the assistant has a clear place to add the rule and a clear type to extend.

When an AI tool changes `registerUser`, the dependencies show which operations are effectful. Saving and logging are not hidden inside a helper that looks pure. That makes tests easier to generate and reviews easier to perform.

When a new caller is added, TypeScript requires the caller to inspect `ok` before using `value`. The compiler becomes a guardrail. The assistant can still make mistakes, but the design narrows the mistake surface.

This is the practical connection between FP and AI-assisted coding: functional patterns make intent local, explicit, and checkable.

## Trade-offs

Functional-light code is not automatically better. It has trade-offs:

- It may introduce more small types and functions.
- It can feel unfamiliar to teams that expect class-centered designs.
- It may be unnecessary for tiny scripts or throwaway code.
- It still requires judgment about where side effects belong.

The goal is not to turn every TypeScript file into an abstract FP exercise. The goal is to use the smallest useful set of techniques:

- Prefer immutable input and output shapes.
- Keep transformations pure when practical.
- Return explicit success and failure values for expected failures.
- Push side effects to boundaries.
- Use types to prevent invalid states.

That is enough to improve many everyday designs.

## Takeaways

AI-assisted coding works better when code gives it firm rails to follow.

Traditional OOP can provide those rails, but it often depends on conventions, naming, and developer discipline. Functional-light TypeScript moves more of the design into function signatures, data types, and compiler-checked control flow.

For this series, "a little functional programming" means practical techniques that fit inside normal TypeScript:

- functions over large stateful objects when behavior is just transformation
- immutable data over hidden mutation
- discriminated unions over informal flags and optional fields
- explicit results over surprising exceptions for expected failures
- dependency arguments over hidden global effects

These patterns help humans review code, and they help AI assistants generate changes that stay inside the intended design.

## Exercise

Take a service method in your codebase that validates input and performs at least one side effect.

Refactor it in three steps:

1. Extract a pure validation function that returns a typed success or failure result.
2. Move time, randomness, logging, persistence, or network calls into explicit dependencies.
3. Make the top-level workflow return a `Result` so callers must handle expected failure cases.

After the refactor, ask an AI assistant to add one new validation rule. Review whether the change stays local, whether the compiler catches missing cases, and whether the tests are easier to write.
