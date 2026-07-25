# Q07 rerun cohort — SEALED before the requeue (R-1 gate requirement)

Sealed 2026-07-25, before any rerun was launched, per the gate-repair plan REVISION 2: *"the
cohort must be fixed in writing before the requeue, not chosen afterwards from whichever number
looks best."* Derived by one agent, independently re-derived by an adversarial verifier
(**SURVIVES, bit-for-bit identical** — every attack vector closed: multi-symbol contamination,
symbol-key joins, superseded passes, timestamp-ordering hazards). Machine-readable copy consumed by
the rerun driver: `scratchpad/q07_cohort.json` (12 entries).

## Track A — vacuous-variance cohort (11 sleeves, risk 4.9255 @9.75 / 5.9768 @12.0)

Rule: a book sleeve is IN iff its **latest** Q07 PASS row (matched by `ea_id`, then symbol) carries
`variance_pct=0.00`. Matches the Codex challenge's latest-PASS join exactly.

| ea_id | symbol | risk @9.75 | risk @12.0 | latest Q07 PASS | updated |
|---:|---|---:|---:|---|---|
| 10440 | NDX.DWX | 0.0577 | 0.0759 | 16d8210c | 06-07 |
| 10911 | GDAXI.DWX | 0.1276 | 0.1675 | ba34fb1f | 06-15 |
| 10919 | XTIUSD.DWX | 0.9181 | 1.0000 | b0a43323 | 07-03 |
| 10939 | GBPUSD.DWX | 0.1887 | 0.2479 | 2a77e549 | 06-26 |
| 11165 | AUDCAD.DWX | 0.5230 | 0.6869 | b378f9b7 | 06-14 |
| 11421 | AUDUSD.DWX | 0.3614 | 0.4747 | b77d915a | 06-26 |
| 12567 | XAUUSD.DWX | 0.7465 | 0.9805 | 3cc839c7 | 06-27 |
| 12567 | XNGUSD.DWX | 0.9797 | 1.0000 | f9452af6 | 06-25 |
| 12989 | XAUUSD.DWX | 0.2420 | 0.3178 | 377350fb | 07-03 |
| 1556 | XAUUSD.DWX | 0.6017 | 0.7903 | 5b9d5cf2 | 07-05 |
| 1567 | EURUSD.DWX | 0.1791 | 0.2352 | fba298c8 | 07-18 |

The multi-symbol EAs split correctly and deliberately: 11165 AUDCAD (0.00, in) vs EURUSD (9.52,
out); 11421 AUDUSD (0.00, in) vs EURUSD (15.82, out); 12567 both legs 0.00, both in.

**Laundering surface at Q07 is clean:** zero cohort EAs have a Q07-phase `.requeued_*` archive
(323 requeued work-item UUIDs joined back through the DB — none is a Q07 row of a cohort EA). The
WP-10 authentication is therefore a guard, not an active repair, for this rerun. Archives DO exist
for these EAs in adjacent phases (Q04/Q05/Q08) — out of scope here.

## Track A addendum — QM5_13128/NDX, added on its own justification (risk 1.0 / 1.0)

**The book's largest sleeve has no real Q07 evidence at all. Its single Q07 "PASS" row
(`37308752`) is an administrative backfill stamp** — payload contains only
`{backfill: "requal_wave_20260717", basis: "...work_items lane was never backfilled for Q04-Q09
era", evidence_dir}`; no setfile execution, no five-seed run, no variance; the `ea_metrics` row is
`source='parse_error'` with every metric null. The cited decision file
(`decisions/2026-07-12_t_live_dxz_23sleeve.md`) records its actual path as **Q02 → Q08 FAIL_SOFT →
Q09 portfolio rescue** — Q07 appears nowhere. The sleeve is salvage-lane Probation origin; Q04–Q06
have no rows and no artifacts either.

Real evidence backing 1.0 risk today: a Q08 **FAIL_SOFT** (57 trades, cost-cushion PASS) and last
night's Q10 PASS (pf 2.29, dd 1.25 %). That is all.

13128 does not meet the Track-A rule (its row has a NULL reason, not `variance_pct=0.00`) —
including it silently would have broken the seal. It is added **explicitly, on a different
justification**: not "vacuous variance" but "no run ever happened". Symbol `NDX.DWX` (not a
basket; framework entry path applies, so Q07's HARSH stress-rejection gives the seeds something to
bite on despite the strategy's deterministic calendar logic). Setfile: the manifest `backtest_set`.

Its Q07 row is also the only one in the book with a naive (non-ISO) `updated_at` — written by a
different path, never backfilled by WP-3 (which keys on siblings that this stamp doesn't have).
Integrity anomaly noted for WP-1b/Q03-phantom follow-up.

## Track B — basket sleeves (2), NOT in this rerun

12778/AUDUSD (wi `QM5_12778_AUDUSD_EURJPY_COINTEGRATION_D1`) and 13117/EURGBP (wi
`QM5_13117_EURGBP_AUDJPY_COINTEGRATION_D1`) both carry `variance_pct=0.00` and would land in a
naive filter — but their Q07 is structurally vacuous until the WP-9 recompile lands
(`QM_BasketOrder.mqh` bypassed the stress hook; the evidence shows it plainly: 13117's Q06 detail
records `rejection_probability: 0.1` with PF byte-identical to Q05). Requeuing them before the
recompile would re-certify nothing. They run as their own track: **recompile `--force` (the WP-9
fix is header-only and both `.ex5` are newer than their `.mq5` — the mtime cache would silently
skip it) → Q06 → Q07 → Q10 (13117's INVALID retry last, against the then-warm cache).**

## Exclusions — latest Q07 PASS has real nonzero variance (10)

10403/XAU 19.51 · 10513/XAU 6.68 · 11132/SP500 6.16 · 11165/EURUSD 9.52 · 11421/EURUSD 15.82 ·
11708/EURUSD 6.93 · 12969/USDJPY 18.10 · 10706/GBPUSD 10.71 · 13301/GDAXI 6.44 · 13213/USDJPY 5.13

All 24 sleeves accounted for: 11 + 1 + 2 + 10 = 24. No sleeve has zero Q07 rows.

## Execution preconditions (all must hold before the driver runs)

1. WP-10 (effective-seed authentication) committed — the runner in tree is already the fixed one.
2. Codex WP-5/7 build landed and reviewed — the runner files must be stable, not mid-edit.
3. Factory quiescent by process scan (workers, pump, phase runners, run_smoke) — not by script exit.
4. Driver: `scratchpad/q07_rerun.py` (syntax-checked, resumable, detached-safe; parses
   `variance_pct` per sleeve — the acceptance signal is variance turning nonzero on the fixed
   injector, with every seed above the per-seed PF floor).
