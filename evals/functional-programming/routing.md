# Routing: does the description load the skill at the right time?

Agents pick skills from `name` + `description` alone. This eval checks that the
description loads the skill for design problems it helps with and stays quiet
for ordinary coding work.

## Method

Give a fresh agent the skill list below (swap in the `description` under test)
and one task at a time. Ask: "Which of these skills, if any, would you load
before starting? Answer with skill names only, or `none`."

Skill list:

- `functional-programming`: *(description under test)*
- `test-driven-development`: Use when implementing any feature or bugfix, before writing implementation code
- `systematic-debugging`: Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
- `api-design`: Use when designing or changing HTTP/REST/gRPC endpoints, request/response schemas, or versioning
- `performance-profiling`: Use when code is slow, uses too much memory, or a profile shows a hotspot
- `writing-docs`: Use when writing READMEs, docstrings, or user-facing documentation

## Tasks

Should load `functional-programming`:

1. This checkout function reads a global config, calls `Date.now()`, and writes to the database. I can't unit test the pricing rules. Help.
2. Our Redux-less React state has `isLoading`, `isError`, `data`, and `error` fields and the UI shows impossible combinations.
3. The Go service passes a `*Context` struct that five packages mutate. Bugs appear depending on call order.
4. Review this PR: the new `InvoiceManager`, `InvoiceCoordinator`, and `InvoiceFactory` classes each have one method.
5. Our service throws `UserNotFoundException` for a normal lookup miss and the callers use try/catch for control flow. Is there a better design?
6. Refactor this Python module to be more functional.

Should NOT load `functional-programming`:

7. Add a `--verbose` flag to the CLI that prints each file as it is processed.
8. Bump the Spring Boot version from 3.2 to 3.3 and fix any compile errors.
9. Write a SQL migration that adds a nullable `archived_at` column to `projects`.
10. The CSS grid breaks on mobile Safari; the sidebar overlaps the content.
11. Rename `getUser` to `fetchUser` across the codebase.
12. Add a new REST endpoint `GET /orders/{id}/items` following the existing controllers.
13. Write a TypeScript function that parses a CSV string and returns the sum of each numeric column.
14. Explain what this Rust iterator chain does: `v.iter().filter(|x| x.active).map(|x| x.id).collect::<Vec<_>>()`.
15. Generate a Kotlin data class and JSON serializer for this API response.
16. Review this PR that adds pagination to the users list endpoint.

Pass: loads on 1-6 (6 is an explicit request) and does not load on 7-16.
Tasks 13-16 are ordinary generation, explanation, and review work that a
broad "any code in any language" description tends to capture.
Loading alongside another skill counts as loading.
