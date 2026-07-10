# QM5_11916 Forex Magic Repair and Q02 Requeue - 2026-06-28

## Scope

EA: `QM5_11916_neely-weller-alexander-filter-2pct-d1`

Card: `D:\QM\strategy_farm\artifacts\cards_approved\QM5_11916_neely-weller-alexander-filter-2pct-d1.md`

Priority lane: diverse FX D1 infra rescue.

## Root Cause

Recent Q02 work items failed with `ONINIT_FAILED` / `EA_MAGIC_NOT_REGISTERED`.
Tester evidence showed `ea_id=11916 slot=0 magic=119160000`, while
`framework/registry/magic_numbers.csv` had no rows for EA ID `11916`.

The existing backtest setfiles also all used `qm_magic_slot_offset=0`, so
non-EURUSD symbols could not resolve their symbol-specific magic even after
registration.

## Repair

- Added ten `11916` magic registry rows for the approved FX universe.
- Regenerated `framework/include/QM/QM_MagicResolver.mqh`.
- Regenerated all ten D1 RISK_FIXED backtest setfiles with symbol slots:
  EURUSD=0, GBPUSD=1, USDJPY=2, USDCAD=3, USDCHF=4, AUDUSD=5,
  NZDUSD=6, EURJPY=7, GBPJPY=8, AUDJPY=9.
- Recompiled the `.ex5`.
- Added missing `SPEC.md`.
- Replaced raw `iClose` strategy reads with the framework `QM_SMA(..., period=1)`
  closed-bar reader and initialized `QM_EntryRequest.expiration_seconds`.

## Validation

- `python framework\scripts\validate_spec_doc.py framework\EAs\QM5_11916_neely-weller-alexander-filter-2pct-d1`
  - PASS: 1, FAIL: 0
- `.\framework\scripts\compile_one.ps1 -EALabel QM5_11916_neely-weller-alexander-filter-2pct-d1 -Strict`
  - PASS, 0 errors, 0 warnings
- `.\framework\scripts\build_check.ps1 -EALabel QM5_11916_neely-weller-alexander-filter-2pct-d1`
  - PASS, 0 failures
  - 16 advisory warnings from shared framework include scans

Build-check report:
`D:\QM\reports\framework\21\build_check_20260628_175437.json`

## Q02 Requeue

Queued a staged Q02 wave through the farm DB without starting local backtests:

| Work item | Symbol | Status |
|---|---|---|
| `ad1aaca6` | `EURUSD.DWX` | pending |
| `ddfca25d` | `USDJPY.DWX` | pending |
| `50063539` | `AUDJPY.DWX` | pending |

Deferred sidecar source: `codex_infra_repair.q02_requeue`

Deferred symbols: `GBPUSD.DWX`, `USDCAD.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`,
`NZDUSD.DWX`, `EURJPY.DWX`, `GBPJPY.DWX`.

## Recovery Completion - 2026-07-10

The historical Q02 failure class was rechecked against the real work-item
evidence before advancing the recycle task. The latest complete pre-repair
reports still show `ONINIT_FAILED`, `EA_MAGIC_NOT_REGISTERED`, `BARS_ZERO`, and
`HISTORY_CONTEXT_INVALID`; no post-repair strategy verdict existed. The June 28
registry/slot fix therefore remains the applicable infrastructure correction.

This completion pass also repaired two build-safety issues in the current EA:

- position management and strategy exits now run before either news-entry gate,
  so an open position remains managed through a blackout window;
- `QM_EntryRequest` is zero-initialized before the strategy fills it.

The approved Federal Reserve-sourced card is now copied into
`docs/strategy_card.md`. Validation evidence:

- `validate_spec_doc.py`: PASS (1 PASS, 0 FAIL)
- build check: PASS, 0 failures, 0 warnings
  (`D:\QM\reports\framework\21\build_check_20260710_132505.json`)
- strict compile: PASS, 0 errors, 0 warnings
  (`C:\QM\repo\framework\build\compile\20260710_132518\QM5_11916_neely-weller-alexander-filter-2pct-d1.compile.log`)
- build result:
  `D:\QM\strategy_farm\artifacts\builds\4baddbe8-c2da-479b-b9fe-9be4ec4eb046.json`

The standard `record-build` path staged the next Q02 recovery wave without
launching an interactive backtest:

| Work item | Symbol | Status |
|---|---|---|
| `2d118c6a` | `GBPUSD.DWX` | pending |
| `52efb82d` | `USDCAD.DWX` | pending |
| `7a8d456a` | `USDCHF.DWX` | pending |

The earlier EURUSD/USDJPY/AUDJPY wave remains pending. AUDUSD, NZDUSD, EURJPY,
and GBPJPY remain in the canonical Q02 deferred-symbol sidecar and will promote
under the normal staged-wave rule. T1, T2, T3, and T8 were already running
factory work at the check, so no manual MT5 smoke was started and no T_Live
process or setting was touched.
