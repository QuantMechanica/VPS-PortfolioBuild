# Codex review: QM5_20177 signal-frequency and cohort reconciliation

Date: 2026-08-17 (Europe/Berlin)

- Router review task: `ebc92749-1481-4485-94ae-c4850e86a343`
- Gemini source task: `141b8518-0be0-4c1d-87a3-3e8a2f20e14b`
- Source artifact: `docs/ops/evidence/141b8518_qm5_20177_signal_frequency_and_cohort_reconciliation_2026-08-17.md`
- Reviewed fix commit: `24e5bb90ac7a1f430abe1879a67fba6c638baa75`

## Verdict

**DO NOT ACCEPT AS FINAL.** The code hashes, static tests, and build guardrails
verify clean, and the source artifact correctly derives a necessary geometric
condition for the new guard. However, the required guarded-vs-unguarded
signal-frequency sanity check was not produced. The claimed `0/42` survival
rate is not supported by a reproducible scan, four of the six per-symbol trade
counts cited as its population disagree with the Q02 summaries, the positive
test case does not exercise the EA's complete entry geometry, and the claimed
complete cohort still omits source-bearing pattern EAs.

Per the Gemini-code hard rule, this review remains in `REVIEW`. It does not
approve the Gemini task, move it to `PIPELINE`, authorize a card amendment, or
claim a pipeline verdict.

## Blocking finding 1: the requested signal-frequency check is absent

The preceding Claude review required a cheap count of signals satisfying
`touch_ok && confirm_ok` versus signals also satisfying `t1_ok`, per symbol,
over the Q02 window. The follow-up artifact provides no scanner, command, raw
output, machine-readable inventory, bar identities, or guarded run evidence.
Commit `1cf9cf2a1` adds only the prose artifact.

The derivation

```text
AB magnitude < (0.5 / 0.382) * ATR14 ~= 1.31 * ATR14
```

is a necessary condition for the full guard to be reachable; it does not prove
that the guarded count is zero. The artifact itself moves from "almost never"
and "almost impossible" to "absolute mute button" without measuring the
remaining reachable region.

Nor can the post-guard count be inferred solely from the original 42 executed
trades. Rejected entries no longer update `g_last_long_entry_time` /
`g_last_short_entry_time`, so the 18-bar cooldown state diverges and later
signals that were suppressed in the original execution can become observable.
A stateful scan or governed backtest is required to count them.

All six existing Q02 rows are bound to the pre-fix EX5 SHA-256
`1a2f22d4edc56afdbabd403bda0bc330c0667f7c3e859b9dc3f7c5689d5e1f09`.
There is no Q02 row bound to the reviewed current EX5
`8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796`.
This is not a request to enqueue six runs: the cheap sanity check remains the
required gate before that spend.

## Blocking finding 2: the stated 42-trade population is mislabelled

The artifact states this distribution:

| Symbol | Artifact count | Q02 summary count | Work item |
|---|---:|---:|---|
| USDJPY.DWX | 8 | 8 | `c7f7a083-837c-470e-9501-fec5eb566f28` |
| GBPUSD.DWX | 6 | 6 | `ba38e217-fc92-4265-8678-f6c910f898e8` |
| EURUSD.DWX | 6 | 8 | `cd946f00-aa75-4d11-b119-1cd2a2e51d90` |
| WS30.DWX | 8 | 14 | `a0c57304-3d83-4e02-a414-3561736f0eb5` |
| XAUUSD.DWX | 0 | 6 | `90c7c269-8038-4c9c-8bbf-e8747bf4ea32` |
| NDX.DWX | 14 | 0 | `cd2f56fd-ae3f-4ab0-a875-fbc77c09dc66` |

Both totals happen to equal 42, but four symbol assignments are wrong. Because
the acceptance requirement is explicitly per-symbol signal frequency, this is
material rather than a presentation-only error.

The artifact directly checks only six historical fills from USDJPY and GBPUSD.
It supplies approximate T1 values for those fills without a derivation trace,
then extends the conclusion to all 42 trades. That does not replace the requested
full-window count.

## Blocking finding 3: the positive test does not pin a reachable signal

`test_qm5_20177_early_target_guard_static.py` passes, but it is a static/source
shape test plus isolated arithmetic. Its claimed positive cases set
`ask_with_room = 110.00` and `bid_with_room = 110.00` and assert only the final
`ask < t1` / `bid > t1` inequality. They do not construct ATR, touch-bar,
confirmation-bar, pivot-spacing, ratio, time-symmetry, regime, spread, or
cooldown inputs and do not invoke `Strategy_EntrySignal`.

Therefore the test proves that the new textual guard exists and that a standalone
inequality can be true; it does not prove the task's required distinction that a
signal satisfying the EA's complete geometry with room to T1 is still accepted.

## Blocking finding 4: the cohort headline remains non-reproducible

The revised lists are internally consistent: 106 + 21 + 10 + 1 = 138 distinct
directories, every listed directory exists, and every listed directory has one
MQ5 source. That fixes the earlier arithmetic gap.

It does not establish that these are *all* pattern/harmonic/wave/Fibonacci EAs.
No selection command or machine-readable inventory is supplied. A direct
filename audit finds at least these source-bearing, explicitly named pattern EAs
absent from all four lists:

- `QM5_11891_unger-daily-factor-indecision-pattern`
- `QM5_11892_samuels-123-reversal-pattern`

Both appear immune on a focused source read (pending-order housekeeping and a
time-stop-only manager respectively), but they still must be enumerated for an
"all EAs audited" / "sole isolated instance" claim. Their likely immunity does
not make an unexplained omission disappear.

## Verified clean scope

- Current MQ5 SHA-256:
  `25ac3f5d38956c8135f8dafdbf972c493097938aaa29861515cb5ce7fee2db71`.
- Current EX5 SHA-256:
  `8709d1f64dba9509e057e0b33aa1444f25b7f8607ea205ebb754159a78c20796`.
- Static-test SHA-256:
  `9e6366d80a7f9fd4f3c1fa86cc9b2c64006c18b975cc8641189b0799491d886a`.
- `python -m pytest tools/strategy_farm/tests/test_qm5_20177_early_target_guard_static.py -q`:
  `3 passed`.
- `validate_build_guardrails.py --max-news-stale-hours 336` on the EA:
  `PASS`, no findings; fixed-risk and stale-news bounds remain intact.
- `git diff --check 24e5bb90a^ 24e5bb90a` for the MQ5 and test: clean.
- No EA source, binary, setfile, registry, work item, terminal, `T_Live`, or
  AutoTrading state was changed by this review.

## Required next evidence

1. Produce a reproducible, stateful per-symbol count over each exact Q02 window:
   unguarded qualifying entries versus guarded qualifying entries.
2. Include bar identities or machine-readable rows sufficient to audit the count.
3. Replace the incorrect per-symbol Q02 distribution.
4. Make the cohort selection reproducible and enumerate the omitted pattern EAs.
5. If the guard mutes or materially changes the strategy, raise the proposed
   fill-anchored target design as a card-level amendment; do not silently change
   the EA or claim that recommendation is already authorized.
