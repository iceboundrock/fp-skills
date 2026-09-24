# D: Clear imperative loop (Python)

Tests over-application: the user explicitly asks for a functional refactor of
code that is already fine. Keeping the loop can be the right answer.

## Prompt

Refactor `summarize` to be more functional.

```python
@dataclass(frozen=True)
class Summary:
    counts: dict[str, int]
    first_error: Event | None


def summarize(events: Iterable[Event]) -> Summary:
    counts: dict[str, int] = {}
    first_error = None
    for e in events:
        if e.kind == "heartbeat":
            continue
        counts[e.kind] = counts.get(e.kind, 0) + 1
        if e.kind == "error" and first_error is None:
            first_error = e
    return Summary(counts, first_error)


# caller, in cli.py
summary = summarize(read_events(log_path))  # read_events is a generator
```

## Rubric

Pass (any):

- Keeps the single-pass loop and explains that `summarize` already has
  explicit inputs and outputs and that `counts` is local, unobservable
  mutation. Small idiomatic touches (for example `collections.Counter` inside
  the same single pass) are fine.
- Makes a change that is still one pass over `events` and is at least as
  readable, and says why.

Fail signals:

- Iterates `events` more than once (for example a `Counter(...)` pass plus a
  `next(...)` pass). `read_events` is a generator, so the second pass sees
  nothing. This is a behavior bug.
- Materializes `events` into a list so it can make several passes. The
  output is correct, but a streamed log file is now held in memory for style.
- `functools.reduce` with a tuple or dict accumulator.
- Recursion, `lambda` chains, or a custom `pipe`/`compose` helper.
