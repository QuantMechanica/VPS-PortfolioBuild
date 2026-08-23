# Balke on XAUUSD — adjudication (2026-08-23)

**Trigger:** OWNER 2026-08-23 at the Strategy Archive matrix: *"die Balke Range Breakout auf
XAUUSD: da gibt es auch Settings, die funktionieren, wir haben sie aber nicht getestet, oder wohl
die falschen Parameter verwendet, da bei Q02 schon Fail?"*
**Router:** `051eb0bf` · **ToDo:** `QM-TODO-20260823-504`

## Verdict: XAUUSD is not an untested gap. It is a measured, OWNER-approved negative.

The single XAUUSD cell of `QM5_13213` is **not a failed backtest**. Its payload says so
explicitly:

```
verdict            RETIRE            (Q02, 2026-07-29T12:18:03Z)
invalidated_reason XAU excluded by OWNER-approved USDJPY-only admission:
                   walkforward OOS PF 1.03 gross = documented negative
                   (docs/research/BALKE_RANGE_BREAKOUT_WALKFORWARD_2026-07-14.md)
mnt009_legacy_disposition.evidence_kind
                   legacy_db_state_disposition_not_test_result
```

The underlying measurement is a full walkforward over **1.894 trades**, not a screening run:

| Window | Trades | Net | PF | MaxDD |
|---|---:|---:|---:|---:|
| USDJPY DEV 2017-01→2021-09 | 791 | +$74.503 | **1,24** | −$17.149 |
| USDJPY OOS 2021-10→2025-12 | 795 | +$68.235 | **1,20** | −$19.853 |
| XAU DEV 2017-01→2021-09 | 924 | +$52.177 | 1,12 | −$25.307 |
| **XAU OOS 2021-10→2025-12** | **970** | **+$13.342** | **1,03** | **−$40.645** |

XAU OOS is breakeven **before** costs with a drawdown three times the net — and it reproduces
both Balke's own caveat about gold and the independent house finding that XAU range-breakout
styles whipsaw. The round-1 XAU nulls that once looked like a harness problem were fixed
(100-min timeout) and re-run before this conclusion; the negative is post-fix.

**Re-running 13213 on XAUUSD would re-derive a documented negative at the cost of terminal
hours.** Not done.

## What was actually wrong: the surface, not the strategy

The matrix showed a bare `RETIRE` with no explanation, which is exactly what makes a documented
negative look like an untested hole. **Fixed:** `runs_for_ea()` now extracts the first durable
reason from the payload (`verdict_reason`, `invalidated_reason`, `reason`, `failure_class`,
`prior_failure`, `promotion_reason`, and the `mnt009_legacy_disposition` category), and the EA
detail page carries a **reason column**. Measured on `QM5_13213`: 17 of 23 runs now show a reason,
and the XAUUSD cell explains itself in one line.

That is the durable fix. An unexplained terminal verdict is what makes people re-run settled work.

## The one part of the observation that does hold

`QM5_13036` (*balke-go-long-regime*) — the deepest Balke survivor in the house, GDAXI.DWX
Q02→Q10 all PASS — **has never run on XAUUSD**. But that is not a pipeline gap:

- its card declares `target_symbols: [NDX.DWX, GDAXI.DWX]`, `single_symbol_only: true`;
- it is a **long-only index day-exposure with a D1 SMA200 regime gate**, not a range breakout;
- extending it to a metal is a **candidate-pool decision**, which the standing authorization puts
  in the ROT zone — never autonomous.

Submitted to OWNER as a decision rather than executed. The mechanism argument cuts both ways: an
index long-bias harvest has an economic rationale (equity risk premium, session drift) that gold
does not obviously share, so this is a research question, not a coverage chore.

## Correction to the earlier ToDo

`QM-TODO-20260823-504` proposed: *"if artifact: append-only rerun via
`farmctl enqueue-backtest --append-only-rerun-of`"*. Measurement says the premise was wrong — the
row is neither an artifact nor a test result. The rerun is **not** executed and the step is struck.

## Correction to the earlier summary

Reported on 2026-08-23 as *"one row, Q02 = RETIRE, no `verdict_reason` in the payload"*. The
payload has no `verdict_reason` key, but it does carry `invalidated_reason` plus the disposition
block — the reason existed, the reader did not look under the right key. The conclusion drawn from
it ("not an economic failure") happened to be right; the basis was incomplete.
