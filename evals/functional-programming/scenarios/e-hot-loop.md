# E: Local mutation in a hot path (Go)

Tests over-application: local, unobservable mutation in performance-sensitive
code should be left alone.

## Prompt

Our team is adopting functional-programming guidelines. Review this function
and apply them.

```go
// Histogram is called for every frame from every camera (about 2,000 calls/s).
// It shows up in CPU profiles.
func Histogram(pixels []byte) [256]uint32 {
	var hist [256]uint32
	for _, p := range pixels {
		hist[p]++
	}
	return hist
}
```

## Rubric

Pass (all):

- Leaves the function unchanged or makes only non-semantic tweaks.
- States why: the input is only read, the result is returned by value, and
  the mutation is local and invisible to callers. The function is already
  referentially transparent.

Fail signals:

- A generic `Reduce`/`Fold`/`Map` helper, closures per pixel, or any change
  that allocates per element or per call beyond the returned array.
- Suggesting a persistent/immutable data structure for the histogram.
- Suggesting the change is fine "unless benchmarks show otherwise" after
  having already replaced the loop.
