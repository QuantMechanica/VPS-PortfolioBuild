# FTMO trial pulse collector-clock and weekend-proof repair

- Router task: `00689fe3-3b6b-4026-9728-de58818e4043`
- Review state: `REVIEW`
- Implementation branch: `agents/codex-ftmo-pulse-clock-20260907`
- Implementation commit: `b3708e91a1`

## Root cause

The collector record is UTC-correct. The reported sample at
`2026-09-06T21:15:23Z` also carries `ts_epoch=1788729323`, which converts to
the same UTC instant. The negative age was created inside the observer:
`main()` captured its `now` before scanning journals and long-lived EA logs,
then read the concurrently appended collector JSONL minutes later using the
old reference. The same pattern remained visible on 2026-09-07: pulse
`checked_at_utc=08:19:55Z`, selected collector row `08:22:27Z`, age `-2.529m`.
This was not broker/server time mislabeled as UTC.

## Repair

- Collector freshness in `main()` now uses a current UTC reference after the
  journal/EA scans.
- `read_collector_snapshot()` uses the existing UTC-aware, zero-clamped age
  helper. A valid sample newer than the supplied observation reference has
  `age_minutes=0.0`, is fresh, and remains the primary equity source. It can no
  longer create `collector_snapshot_stale:-Xm` or force the stale EA snapshot
  fallback.
- `KS_DAY_ANCHOR_SET` and `KS_BOOK_TAG_SET` are explicit setter-call events,
  normally emitted during EA initialization; they are not produced by the
  first trade or automatically by a Prague-day rollover. Their absence during
  a Prague Saturday/Sunday is now informational. Normal missing-proof warnings
  resume on Monday Prague time.

## Verification

`python -m pytest tools/strategy_farm/tests/test_ftmo_trial_pulse.py -q`

Result: `29 passed, 1 unrelated existing DeprecationWarning`.

A read-only probe against the live JSONL with a deliberately earlier reference
returned the latest account-bound sample as `fresh=True`, `age_minutes=0.0`,
equity/balance `100000.0/100000.0`. `git diff --check` passed before commit.

No terminal, account, chart, preset, AutoTrading, position, order, or halt
authority state was changed.
