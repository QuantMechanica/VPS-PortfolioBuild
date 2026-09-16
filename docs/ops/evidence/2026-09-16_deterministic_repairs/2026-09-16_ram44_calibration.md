# RAM-44GB class calibration (ticket 6cdc6811) — result

Date: 2026-09-16
Agent: Kimi interim OWNER delegation, task `det-repairs`
Backlog row: `ram_44gb_reservation_class` (AUTHORIZED_PENDING_EXECUTION,
ticket 6cdc6811; backlog said 443 rows / ~46.43 h — the live hold census was
531 rows)
Verdict: **EXECUTED. 44 GB is MEASURED NECESSITY for full-window dense-tick
index D1 runs; the lever-1 per-base lowering was under-calibrated and is
corrected. 52 winnable rows released; 479 stay parked with documented reason.**

## Evidence (tester memory ledger, trailing 14 d, 19,210 records)

| class | n | p50 | p95 | max |
|---|---|---|---|---|
| single_index_tick | 489 | 2.07 | 10.6 | **39.5 GB** |
| multi_leg_fx_basket | 26 | 21.2 | 33.4 | 33.5 GB |
| heavy_or_unknown_multisymbol | 0 | — | — | — |

Full-window D1 index monsters (2026-09-15, admitted under the lever-1 table):

- NDX.DWX QM5_10280 Q05 D1 **finished 39.5 GB WS / 49.3 GB private** (reservation was 12)
- NDX.DWX QM5_1077 Q05 D1 **finished 39.2 GB**; sibling run **ram_emergency_reap at 25.7 GB**
- GDAXI.DWX QM5_1642 Q02 D1 smoke **finished 35.4 GB** (reservation was 24)
- SP500 (pre-window, 2026-08-15): 45.7 GB private / 46.8 GB WS — the original 44 GB basis

The lever-1 NDX 12 / WS30 12 values generalized Q04-only measurements
(NDX n=3 max 2.10 GB, WS30 n=5 max 1.15 GB); the 2026-09-15 ledger falsified
that generalization for full-window phases.

## Reclassification (governed table `INDEX_TICK_RESERVATION_GB_BY_BASE`)

| base | before | after | basis |
|---|---|---|---|
| SP500 | 44 | 44 | measured 45.7/46.8 GB (2026-08-15) |
| NDX | 12 | **44** | measured 39.5/39.2 GB Q05 D1 (2026-09-15) — never below measured peak |
| GDAXI | 24 | **44** | measured 35.4 GB Q02 D1 (2026-09-15) |
| WS30 | 12 | **24** | reverted to provisional (its 12 rested on the Q04-only evidence NDX falsified) |
| UK100 | 24 | 24 | provisional, n=1, no counterevidence |
| heavy_or_unknown_multisymbol (flat) | 44 | 44 | n=0 measurements; documented fail-safe; lowering forbidden |

Guards untouched: `max(flat, measured, floor)`, `RAM_MIN_FREE_GB=14.0`
post-reservation floor, drain-window floor, cold-restart reserve, RAM
emergency reaper. Reservation values are admission-lane labels, not kill
limits. Rollback: `QM_INDEX_TICK_RESERVATION_TABLE=0`.

- Code + tests: commit `c29b4196d1` (9/9 table tests pass; the 8 failures in
  the wider RAM test selection are pre-existing/environmental, verified
  against pristine code).
- Fleet rollout: `session_tools/reload_chunk87.py` (staggered, idle-aware;
  started 2026-09-16T14:5xZ, progressing through all ten terminals).

## Parked-cohort disposition (531 active holds)

- **Released: 52** `two_leg_metal_pair @24 GB` rows (24+14=38 GB needed ≤
  54.1 GB max free — winnable in normal quiet windows). Governed release via
  `farmctl.release_work_item_hold` (fresh backup + exact hold-code CAS +
  transition-ledger record), journal `ram44_release_journal.jsonl` (52/52 ok).
  Selector: `session_tools/release_44gb_holds_0916.py` — classifies with the
  real multisymbol EA census (the 0914 tool's `--max-reservation-gb` mode
  passes an empty EA set and would have misreleased heavy rows as ordinary@8;
  caught in dry-run, not applied).
- **Stay parked: 479** = 52 `single_index_tick@44` (measured necessity) +
  427 `heavy_or_unknown_multisymbol@44` (fail-safe, no measurements). 44+14 =
  58 GB needed vs 54.1 GB max free — structurally unwinnable on this host
  until the RAM decision (OWNER 2026-09-15: no VPS upgrade — park/schedule
  differently).

## Runnable hours

Backlog estimate for the whole class was ~46.43 h across 443 rows.  This wave
unlocked the 52 winnable rows (~5.4 h at the backlog's per-row rate); the
remaining ~41 h sit in the two 44 GB classes that are measured/fail-safe
necessity on a 63 GB host and need the OWNER RAM decision (or software
efficiency work per the no-upgrade directive).

## Receipt

Machine-readable: `2026-09-16_ram44_calibration_receipt.json` (this
directory) — evidence rows, table before/after, cohort disposition, guardrails.
