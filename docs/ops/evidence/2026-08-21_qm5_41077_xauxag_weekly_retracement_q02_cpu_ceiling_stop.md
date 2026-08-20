# QM5_41077 Q02 CPU-ceiling stop

Date: 2026-08-21

Branch: `agents/board-advisor`

EA: `QM5_41077_xauxag-wretr-rv`

Outcome: `Q01 PASS`; `Q02 ENQUEUED/PENDING`; this lane stopped at the tester
and host-CPU ceilings

## New commodity sleeve delivered

`QM5_41077` is a new low-frequency XAU/XAG relative-value basket. On the
first tradable D1 bar of a new broker week, it reconstructs three synchronized
completed week-end close pairs and computes two adjacent changes in
`ln(XAU)-ln(XAG)`. When the newest change has the strict opposite sign from
the older impulse and a strictly smaller absolute magnitude, it follows that
partial retracement for one broker week. The two legs target equal absolute
notional, share one fixed-risk budget, and carry frozen ATR hard stops.

The state is mutually exclusive with `QM5_41066_xauxag-wdecay-rv` (same-sign
deceleration), `QM5_41075_xauxag-wovershoot-rv` (opposite-sign dominant newest
move faded), and `QM5_41076_xauxag-waccel-rv` (same-sign acceleration faded).
It also differs from the single-leg WTI pullback sibling `QM5_41069` because
this package follows the newest retracement in a paired metals carrier. The
canonical pre-allocation checker returned `CLEAN` across 4,564 registry rows
and 625 root cards. The approved source boundary treats the weekly
continuation rule as an untested QM hypothesis; it transfers no performance,
neutrality, or decorrelation claim from the peer-reviewed and CME sources.

## Committed governed build

| Commit | Scope |
|---|---|
| `c1f1182c1` | durable source approval and bounded child source packet |
| `8799a0bbe` | deterministic EA ID 41077 reservation and build identity |
| `368cca0fc` | schema-valid approved card and G0 decision |
| `d25a853e2` | active basket magics 410770000/410770001 and regenerated resolver |
| `2d4b072ad` | paired MQ5/EX5, basket manifest, fixed-risk setfile, reference suite, and Q01 evidence links |

The only preset is one logical D1 backtest setfile locking
`RISK_FIXED=1000`, `RISK_PERCENT=0`, and `PORTFOLIO_WEIGHT=1`. No live, demo,
shadow, stress, or optimization setfile was created.

## Q01 evidence

- Nine deterministic reference tests passed, covering both entry directions,
  strict flat-state boundaries, synchronized-week and first-bar failures,
  restart/attempt behavior, year rollover, lifecycle, and package sizing.
- Card schema and prohibited-signal lint passed with no missing sections and
  no ML/banned-indicator hits.
- Strict compile passed with zero errors and zero warnings.
- Targeted strict build check passed with zero failures and zero warnings:
  `D:/QM/reports/framework/21/build_check_20260820_224413.json`.
- Static P1 validation passed:
  `D:/QM/reports/pipeline/QM5_41077/P1/P1_QM5_41077_result.json`.
- MQ5 SHA-256:
  `2D1A321EC1850AE7A267921C6160188EBCF5B5A2DCAC5F15E302027D3C93DD1B`.
- EX5 SHA-256:
  `FF553FEC0C7CDCD68B64B3C76EE590B8C6569266B01B409D259A775250FD3083`.
- Setfile byte SHA-256:
  `4672EFF39ADF9A204386F3F410D213453DE450FFE91CD612A442EA128EFC81B3`.
- Basket-manifest SHA-256:
  `BF49B0F1AAAE37D80CD4A3649A81D8E1CE0BF8A89E00A0703A27FE3A4E4822C0`.

## Target-only queue reconciliation

The canonical farm database was queried through the supported target view:

```text
python tools/strategy_farm/farmctl.py work-items --ea QM5_41077
count=0
```

A non-mutating target-only sweep then selected exactly one never-tested Q02
candidate:

```text
python tools/strategy_farm/sweep_enqueue_built_eas.py --ea QM5_41077 --max-part2-per-run 0
APPLY=False
part1 never_tested: enqueued=1 skipped=0
part2 stranded: enqueued=0 skipped=0
priority_track items: 1
```

The dry-run wording reports what would be enqueued. `APPLY=False` means no
farm row was written by this command, and no `--apply` invocation followed in
this lane.

A later read-only reconciliation at `2026-08-20T22:54:31Z` found one
concurrently-created Q02 row:

| Field | Value |
|---|---|
| work item | `8a5bd279-0a00-4bbc-a24b-77ab1f5b48fa` |
| phase / kind | `Q02` / `backtest` |
| symbol | `QM5_41077_XAU_XAG_WRETR_RV_D1` |
| status | `pending` |
| attempts / claim | `0` / unclaimed |
| created | `2026-08-20T22:52:59+00:00` |

The row appeared after the empty preflight query without an apply command from
this lane. The enqueue actor is not attributed here. The row was left
singular, pending, and untouched; no duplicate was created. The reconciled
external state is therefore `Q02 ENQUEUED_PENDING_CPU_CEILING`.

## Binding paced-fleet capacity stop

The canonical `farmctl mt5-slots` inventory at
`2026-08-20T22:50:12+00:00` reported seven running governed research
terminals, equal to the paced terminal ceiling: `T1`, `T3`, `T4`, `T5`,
`T7`, `T8`, and `T9`. It reported no duplicate terminal workers and no
orphaned terminal processes. Eight research slots were reserved, including
`T6`, so there was no admission headroom.

A simultaneous read-only `Win32_Processor` snapshot reported 100 percent
whole-host CPU across 16 logical processors, above the explicit 97 percent
hard CPU ceiling. The terminal-count ceiling was independently sufficient to
stop. `T_Live` and the unrelated FTMO terminal were observed only so they
could be excluded from the governed research count; neither was controlled or
modified.

## Safe handoff

The existing Q02 row was not claimed, dispatched, requeued, reprioritized,
reserved, or run by this lane. No smoke or manual backtest was launched and no
terminal was controlled. The portfolio gate, T_Live manifest, T_Live files,
and AutoTrading were not touched.

Let the normal farm claim the existing singular row only after governed
research occupancy and host CPU are below their ceilings. Do not enqueue a
sibling. Q02 remains responsible for density and economic falsification; Q09
alone may establish realized portfolio correlation. This record is not a Q02
PASS and does not authorize live use.

Machine-readable evidence is in
`artifacts/qm5_41077_q02_cpu_ceiling_stop_20260820T225432Z_board_advisor.json`.
