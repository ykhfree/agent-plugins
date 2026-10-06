# Recurrence verification (skillify D3)

Date: 2026-10-03.

## Original failing input
A weak suite (`tests/fixtures/sample-project`, `DiscountTest`) does not test `amount == 10_000`.
A "fix" adds a test with no assertion:

```kotlin
@Test
fun `boundary order runs`() {
    Discount().apply(10_000)
}
```

Coverage rises, but the boundary is still unchecked.

## Replay against the scripts
`mh.py gaps --repo . --module .` on the weak suite: exit 1.

```
[('m-babc47489e', 10, 'ConditionalsBoundaryMutator', []), ('m-0bfac8bf33', 14, 'NegateConditionalsMutator', ['log-guard'])]
{'kotlin-intrinsics': 2, 'outside-scope': 0}
```

`mh.py verify ... --test-method "boundary order runs" --mutant m-babc47489e`: exit 1.

```json
{
  "gates": {
    "main-code-unchanged": true,
    "new-test-kills-every-mutant": false,
    "pit-run": true,
    "test-passes-run-1": true,
    "test-passes-run-2": true
  },
  "mutants": {
    "m-babc47489e": {"killed_by_new_test": false, "status": "SURVIVED"}
  }
}
```

The test passes, but the gate rejects it. `tests/e2e/pit_roundtrip_test.sh` replays this on every run
and also checks that a test asserting `apply(10_000) == 9_000` passes the gate (exit 0).
