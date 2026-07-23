# FX Cointegration Q02 CPU-Ceiling Stop

**Date:** 2026-07-23

**Branch:** `agents/board-advisor`

## Outcome

Stopped before any queue mutation or MT5 launch because the paced-fleet
backtest CPU ceiling was exceeded.

The two anchor baskets do not need Q02 repair:

- `QM5_12532` AUDUSD/NZDUSD has logical-basket Q02 PASS evidence and later
  reached Q05 FAIL.
- `QM5_12533` EURJPY/GBPJPY has logical-basket Q02 PASS evidence and later
  reached Q04 FAIL.

Repository evidence also establishes that the documented positive-hedge
66-pair scan and its strict sign-aware extension have no unbuilt survivor.
The mission fallback therefore applies: advance an existing built forex
cointegration card only when paced-fleet capacity becomes available.

## CPU ceiling

The original inspection found eight running factory terminals. A read-only
refresh at `2026-07-23T17:00:48+02:00` found seven:

```text
T2, T3, T4, T6, T7, T9, T10
```

`T_Live` and the separate FTMO terminal were observed only so they could be
excluded from the factory count. Neither was controlled or modified.

Seven factory terminals equal the seven-process ceiling documented by the
current paced-fleet handoff, so capacity is still unavailable. No queue row
was inserted, updated, dispatched, or deleted in either inspection.

## Duplicate guard and continuation target

The canonical headless queue
`D:/QM/reports/pipeline/mt5_queue.db` already contains four queued rows. Two
are forex cointegration baskets:

| Queue id | EA | Pair host | Phase | Priority | Status |
|---|---|---|---|---:|---|
| 2 | `QM5_12760` | `GBPUSD.DWX` | Q02 | 80 | queued |
| 4 | `QM5_13119` | `USDJPY.DWX` | Q02 | 80 | queued |

They remain present exactly once and must not be duplicated. The refreshed
canonical queue still contains four queued rows total and neither FX row has
been dispatched. When the factory count drops below the ceiling, the existing
dispatcher should service these rows before another scan-derived basket is
added. If a later mission still requires one new fallback enqueue, repeat both
the exact tuple duplicate guard and CPU check first, then select an approved,
built basket that has no terminal Q02 verdict and no existing headless row.

## Safety

No portfolio admission, portfolio KPI, Q08 contribution, T_Live manifest,
AutoTrading setting, terminal process, EA source, binary, setfile, basket
manifest, registry, or pipeline database was changed.

## Headless paced-fleet continuation audit

A later read-only audit on 2026-07-23 found the ceiling had tightened rather
than cleared. Nine factory terminals were running:

```text
T1, T2, T3, T4, T6, T7, T8, T9, T10
```

This is two processes above the seven-process ceiling. The canonical scheduler
dry-run, invoked as a module from the repository root, returned:

```json
{"available_slots_after":0,"available_slots_before":0,"dry_run":true,"duplicate":0,"invalid":0,"no_capacity":0,"queued_scanned":0,"scheduled":0,"status":"ok"}
```

The exact queue rows remain present once each, with `status=queued`, no
assigned terminal, no dispatch decision, and no error:

- queue `2`: `QM5_12760`, `Q02`, `GBPUSD.DWX`,
  `q02_fx_coint_12760_s20260629_001`
- queue `4`: `QM5_13119`, `Q02`, `USDJPY.DWX`,
  `q02_fx_coint_13119_s20260710_001`

No queue mutation or MT5 launch was made. The existing dispatcher remains the
only continuation path after paced capacity becomes available.
