# Vibe Coding Isn't the Problem — Your Types Are

Vibe coding broke production again last week. An AI coding assistant added a new email validation rule to a user registration service. The review approved it. The tests passed. The code shipped. Seven days later, a customer registered with a malformed address through a second code path the assistant missed.

I have written TypeScript for ten years. I have watched this same failure repeat across three companies. Vibe coding — the practice of steering an AI assistant through natural language and hoping the output fits — produces this same failure across teams and stacks. The assistant is not the problem. The code gave it room to guess.

Better prompts will not fix this. A design that makes guessing expensive will.

## Where vibe coding breaks

AI coding assistants generate code by matching the patterns they can see. If a class holds mutable state and mixes validation, persistence, and logging in one method, the assistant writes the next change in the same shape. The output compiles. The output passes local tests. The design intent — the rule that says "validate before you mutate" or "never log a password" — lives in a code review comment from six months ago that the assistant cannot read.

Three gaps do most of the damage:

**Hidden state.** A method updates an object, writes to a database, and returns a value from one call. The return type says `User`. The signature hides the write.

**Informal failure.** Code throws an exception, returns `null`, returns `undefined`, or skips work without a signal. The caller has no type-level reason to handle any of these cases.

**Loose data shapes.** An interface accepts four optional fields that only make sense in two of the sixteen combinations. The compiler accepts the other fourteen.

A senior engineer works around these gaps through habit and memory. An AI assistant has neither. It reads the types, the names, and the nearest examples, and it fills in the rest.

## The OOP version looks fine

Here is a user registration service. The shape is standard — a constructor-injected repository and one method that does the work.

```typescript
type User = {
  id: string;
  email: string;
  displayName: string;
  createdAt: Date;
};

interface UserRepository {
  save(user: User): Promise<void>;
}

class RegistrationService {
  constructor(private readonly repo: UserRepository) {}

  async register(email: string, displayName: string): Promise<User> {
    if (!email.includes("@")) {
      throw new Error("Invalid email");
    }
    if (displayName.trim().length === 0) {
      throw new Error("Display name is required");
    }

    const user: User = {
      id: crypto.randomUUID(),
      email: email.toLowerCase(),
      displayName: displayName.trim(),
      createdAt: new Date(),
    };

    await this.repo.save(user);
    console.log("registered user", user.id);
    return user;
  }
}
```

![Diagram showing a single service class as an opaque box absorbing five separate arrows for validation, ID generation, time, persistence, and logging, with all outputs merged into one ambiguous return path](image-placeholder)

Reviewers accept this code. Tests pass. The design still has three gaps an AI assistant can exploit:

- The return type promises a `User`. It does not warn callers about `throw`.
- Validation, ID generation, time, persistence, and logging sit in one method. An edit to any of them risks the others.
- The error cases live in string messages. A caller that wants to treat "invalid email" as a distinct failure from "missing display name" has to parse the message or catch and re-throw.

Ask an assistant to add a uniqueness check on email. It will add a database query somewhere inside `register`. It will throw a new `Error`. The new failure mode joins the existing undocumented ones.

## The same workflow as a typed pipeline

Here is the same behavior, rewritten to put the contract in the types.

```typescript
type RegistrationInput = {
  readonly email: string;
  readonly displayName: string;
};

type RegistrationError =
  | { readonly kind: "invalid-email" }
  | { readonly kind: "missing-display-name" }
  | { readonly kind: "email-taken"; readonly email: string };

type Result<T, E> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

type User = {
  readonly id: string;
  readonly email: string;
  readonly displayName: string;
  readonly createdAt: Date;
};

type RegistrationDeps = {
  readonly createId: () => string;
  readonly now: () => Date;
  readonly saveUser: (user: User) => Promise<void>;
  readonly emailExists: (email: string) => Promise<boolean>;
  readonly log: (event: string, fields: Record<string, string>) => void;
};

const validate = (
  input: RegistrationInput,
): Result<RegistrationInput, RegistrationError> => {
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

const registerUser = async (
  input: RegistrationInput,
  deps: RegistrationDeps,
): Promise<Result<User, RegistrationError>> => {
  const validated = validate(input);
  if (!validated.ok) return validated;

  if (await deps.emailExists(validated.value.email)) {
    return {
      ok: false,
      error: { kind: "email-taken", email: validated.value.email },
    };
  }

  const user: User = {
    id: deps.createId(),
    email: validated.value.email,
    displayName: validated.value.displayName,
    createdAt: deps.now(),
  };

  await deps.saveUser(user);
  deps.log("registered_user", { userId: user.id });
  return { ok: true, value: user };
};
```

![Diagram showing the same five operations as separate labeled pipes arranged in sequence, with a branching Result output that splits into success and error paths](image-placeholder)

This is still plain TypeScript. No library, no monads, no functional programming jargon on the surface. Three changes carry the weight:

1. `Result<User, RegistrationError>` lists every failure the caller must handle.
2. `RegistrationDeps` names every side effect the function performs.
3. `readonly` marks every input and output as data the function will not mutate.

## What the compiler now catches

The value of the rewrite shows up on the next change.

**Add a new validation rule.** The assistant extends `RegistrationError` with a new `kind`. Every `switch` on the error becomes a compile error until a developer handles the new case. The rule cannot sneak through one code path.

**Add a new caller.** The caller receives a `Result`. Using `.value` without checking `ok` is a type error. The assistant cannot forget the failure branch.

**Add a new side effect.** A feature needs to send a welcome email. The assistant adds `sendEmail` to `RegistrationDeps`. The production wiring, the test fakes, and the reviewer see a new dependency in the signature. The effect cannot hide inside a helper that looks like a calculation.

Each of these is a mistake the OOP version welcomed. The typed pipeline rejects each at compile time.

## When this is overkill

Types cost time to write. Three cases where that cost is not worth paying:

- Scripts under a hundred lines that run once.
- Spike branches that explore a question and get thrown away.
- Glue code that wraps a single external call and has no logic of its own.

Everything else earns the structure back within weeks. The cost shows up once, at authoring time. The benefit shows up on every future change.

## Five rules for AI-safe TypeScript

1. Return `Result<T, E>` for expected failures. Reserve `throw` for programmer bugs.
2. Pass side effects (time, IDs, I/O, logging) as a dependency record.
3. Mark every field `readonly`. Spread, do not mutate.
4. Model alternatives as discriminated unions. Let the compiler force exhaustive handling.
5. Keep pure transformation and side effects in separate functions.

These rules do not turn TypeScript into Haskell. They narrow the surface where an AI assistant can guess wrong.

## Try it on one function

Pick a method in your codebase that validates input and then performs a side effect. Rewrite it in three steps:

1. Extract a pure validation function that returns `Result<Validated, Error>`.
2. Move time, IDs, persistence, and network calls into a dependency record passed to the caller.
3. Change the top-level function to return `Result`. Fix the call sites the compiler flags.

Then ask your AI assistant to add one new validation rule or one new failure mode. Count the places the compiler forces a decision. That number is the margin between shipping a gap and catching one.
