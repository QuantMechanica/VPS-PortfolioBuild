# QM5_41076 Q02 CPU-ceiling stop

Date: 2026-08-20

Branch: `agents/board-advisor`

EA: `QM5_41076_xauxag-waccel-rv`

Outcome: `Q01 PASS`; `Q02 NOT_ENQUEUED_CPU_CEILING`

## New commodity sleeve delivered

`QM5_41076` is a new low-frequency XAU/XAG relative-value basket. On the
first tradable D1 bar of a new broker week, it reconstructs three synchronized
completed week ends. If the two adjacent changes in `ln(XAU)-ln(XAG)` have the
same strict sign and the newest absolute change is strictly larger, it fades
that acceleration for one broker week with opposite XAU/XAG legs, equal-
notional targeting, frozen ATR hard stops, and one aggregate fixed-risk
budget.

The state is mutually exclusive with `QM5_41066_xauxag-wdecay-rv`, which
requires a strictly smaller newest same-sign move, and
`QM5_41075_xauxag-wovershoot-rv`, which requires opposite signs. The canonical
pre-allocation check returned `CLEAN` across 4,563 registry rows and 625 root
cards. The approved card discloses the weekly acceleration fade as an untested
QM translation of peer-reviewed gold/silver relationship evidence and the CME
intermarket carrier; no source performance statistic transfers.

## Committed governed build

| Commit | Scope |
|---|---|
| `9d8585d00` | durable source approval and bounded child source packet |
| `bfabac2e1` | deterministic EA ID 41076 reservation and build identity |
| `567040b36` | schema-valid approved card and G0 decision |
| `1ca20ca8c` | active basket magics 410760000/410760001 and regenerated resolver |
| `366a8cafd` | paired MQ5/EX5, basket manifest, fixed-risk setfile, reference suite, and Q01 evidence links |

The one logical D1 backtest setfile locks `RISK_FIXED=1000`,
`RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live, demo, shadow, stress, or
optimization setfile was created.

## Q01 evidence

- Nine deterministic reference tests passed, covering both signal directions,
  all flat-state boundaries, synchronized-week and clock failures, restart and
  consumed-attempt behavior, year boundaries, lifecycle, and package sizing.
- Card schema lint passed with no missing sections and no ML/banned-indicator
  hits.
- Strict compile passed with zero errors and zero warnings.
- Targeted strict build check passed with zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260820_214352.json`.
- Static P1 validation passed:
  `D:/QM/reports/pipeline/QM5_41076/P1/P1_QM5_41076_result.json`.
- MQ5 SHA-256:
  `75799C462F16684DE24A8C6C9FDDAFFDDB31BCF34F248F06B340055524B8BB75`.
- EX5 SHA-256:
  `4B071D824CC68942EACB927D08077C7393CF8FDFF5F8C1CA5E8261EEA388AB5D`.
- Setfile byte SHA-256:
  `0B8B137E0427960DD269FB67398A5A47743D5A3706C65C41275B61EA5418A410`.
- Basket-manifest SHA-256:
  `069B23656F0604BC24636C37D683E3D7021E6D402F9E9759F82BC3BE757CEC0B`.

## Target-only queue reconciliation

The canonical farm database was queried through the supported target view:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41076
count=0
```

A non-mutating target-only sweep then selected exactly one never-tested Q02
candidate:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41076 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
priority_track items: 1
```

The dry-run wording reports what would be enqueued; `APPLY=False` means no row
was written. No `--apply` invocation followed.

## Binding paced-fleet capacity stop

The canonical `farmctl mt5-slots` inventory at
`2026-08-20T21:45:34+00:00` reported eight running governed research
terminals: `T1`, `T2`, `T3`, `T5`, `T6`, `T7`, `T8`, and `T10`. This exceeds
the paced terminal ceiling of seven. It reported no duplicate terminal
workers and no orphaned terminal processes.

The terminal ceiling was already binding, so no additional whole-host CPU
probe was needed and no load was added. `T_Live` and the unrelated FTMO
terminal were observed only so they could be excluded from the governed
research count. Neither was controlled or modified.

## Safe handoff

Q02 was not enqueued, dispatched, reserved, or run. No smoke or manual
backtest was launched and no terminal was controlled. The portfolio gate,
T_Live manifest, T_Live files, and AutoTrading were not touched.

After governed research occupancy falls below seven, re-run the exact
`QM5_41076` work-item query, target-only dry-run, slot inventory, and current
whole-host CPU check. If the target still has no row and all ceilings permit,
apply exactly one target-only Q02 enqueue. Q02 remains responsible for trade
density and economic falsification; Q09 alone may establish realized
portfolio correlation. This record is not a Q02 PASS and does not authorize
live use.

Machine-readable evidence is in
`artifacts/qm5_41076_q02_cpu_ceiling_stop_20260820T214534Z_board_advisor.json`.
