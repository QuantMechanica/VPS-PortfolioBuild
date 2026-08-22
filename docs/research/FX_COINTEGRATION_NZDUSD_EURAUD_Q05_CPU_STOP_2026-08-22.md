# QM5_20208 NZDUSD/EURAUD Q05 CPU-stop handoff

Date: 2026-08-22

Branch: `agents/board-advisor`
Preflight base HEAD: `0e894f302e83a030fa08c6249990a3c8ae6f46ff`

## Outcome

No new FX card was created and no backtest was enqueued. The durable 66-pair
frontier reconciliation already accounts for all 66 unordered FX relationships,
so another card would duplicate an existing basket identity. The two reference
anchors are no longer blocked at Q02: QM5_12532 has passed Q02 and Q04, while
QM5_12533 has passed Q02 and terminated at Q04.

The strongest actionable fallback found was the existing scan-derived,
market-neutral FX basket QM5_20208 (NZDUSD/EURAUD). It has one Q02 `PASS` and one
Q04 `PASS_LOWFREQ`, with no Q05 work item. A final five-sample CPU preflight
reached 100%, above the binding 97% ceiling. The mission's hard-stop rule
therefore prohibited the Q05 enqueue and any tester execution.

Machine-readable evidence is in
`artifacts/fx_cointegration_nzdusd_euraud_q05_cpu_stop_20260822T061206Z_board_advisor.json`.

## Non-duplicate selection

- Frontier evidence:
  `artifacts/fx_cointegration_frontier_cpu_stop_20260812T112137Z_board_advisor.json`.
- Latest fleet stop context:
  `docs/research/FX_COINTEGRATION_FRONTIER_HARD_CPU_STOP_2026-08-22_034614Z.md`.
- Selected existing identity: `QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1`.
- Scan position: rank 27 of 66 sign-aware relationships by OOS net Sharpe.
- Research observations: DEV net Sharpe `-0.091704`, OOS net Sharpe
  `0.474703`, OOS return `4.877699%`, 19 OOS state changes, fixed beta
  `-0.286008035`, estimated half-life `138.333` D1 bars.
- This is deliberately a one-shot structural test. No beta refit, rescue
  filter, pair substitution, ML component, grid, or parameter rescue is
  authorized.

## Card, source, and build bindings

The OWNER-approved card is
`strategy-seeds/cards/approved/QM5_20208_nzdusd-euraud_card.md`
(`sha256:bf233695c7321fcf38372b27a9c8ec5224887f2c7bd23c4becf237aae373b32c`).
Its primary method source is Ernest P. Chan, *Quantitative Trading* (Wiley,
2009), captured in the OWNER-ratified Tier-A extraction
`strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md`
(`sha256:183a1624ae3eb4432dde9ba8883e3f5b16e0107a191e468864ca9600d8d45d64`).

Validated build inputs:

- EX5:
  `framework/EAs/QM5_20208_nzdusd-euraud/QM5_20208_nzdusd-euraud.ex5`
  (`sha256:31d4460df6cd3e9ef579d8ed4e3849e62b3423ef0e942f6703122e2245988bc4`).
- Logical-basket setfile:
  `framework/EAs/QM5_20208_nzdusd-euraud/sets/QM5_20208_nzdusd-euraud_QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1_D1_backtest.set`
  (`sha256:f6ae2633e6ec4e54a7e14835c16c50c231c4135495abf7f3cdb00eaf5346ae04`).
- Basket manifest:
  `framework/EAs/QM5_20208_nzdusd-euraud/basket_manifest.json`
  (`sha256:ed2fac5d413a6a4665388f73d22606408e51a7e317136e4ac8ed0a8369aa8796`).
- Backtest risk is locked to `RISK_FIXED=1000`, `RISK_PERCENT=0`, and
  `PORTFOLIO_WEIGHT=1`.
- Active registered trade slots are NZDUSD slot 0 / magic 202080000 and
  EURAUD slot 1 / magic 202080001. AUDUSD and EURUSD are conversion-history
  dependencies only.

## Existing phase evidence

| Phase | Work item | Verdict | Evidence |
|---|---|---|---|
| Q02 | `1935fc01-6eaa-4db1-8397-660d22ebdfbb` | `PASS` | `D:/QM/reports/work_items/1935fc01-6eaa-4db1-8397-660d22ebdfbb/QM5_20208/20260803_153551/summary.json` |
| Q04 | `3703d3fd-6e3a-4fc2-bc4a-20b2984479b2` | `PASS_LOWFREQ` | `D:/QM/reports/pipeline/QM5_20208/Q04/QM5_20208_NZDUSD_EURAUD_COINTEGRATION_D1__3703d3fd-6e3a-4fc2-bc4a-20b2984479b2/aggregate.json` |

The Q04 aggregate
(`sha256:83a568cd4f9da060ceeeab5aa7d95398a97b7792f9c151dd8175d4a60a7eec4a`)
contains three valid OOS folds: 2023 net PF `4.0889` / 12 trades, 2024 net PF
`1.3320` / 18 trades, and 2025 net PF `0.2736` / 10 trades. The pooled result
is net PF `1.709` across 40 trades and 3/3 active years. The canonical cascade
explicitly accepts Q04 `PASS_LOWFREQ` as a Q05 predecessor.

## Binding CPU stop

At `2026-08-22T06:12:06Z`, five one-second total-processor samples were:

`[100.00, 95.42, 93.95, 100.00, 100.00] %`

Maximum: `100.00%`

Ceiling: `97.00%`

Decision: `HARD_STOP_CPU`

The contemporaneous fleet view showed six factory tester terminals active
(`T1`, `T2`, `T3`, `T5`, `T6`, and `T10`) and approximately 129.45 GiB free on
`D:`. T_Live and the external FTMO terminal were observed only as excluded,
non-pipeline processes.

## Deferred exact action

The queue remains unchanged: exactly the Q02 and Q04 rows above, and no Q05
row. When a fresh five-sample preflight stays at or below 97%, the single
idempotent promotion command is:

```powershell
python tools/strategy_farm/farmctl.py enqueue-backtest --ea QM5_20208 --phase Q05 --from-work-item-id 3703d3fd-6e3a-4fc2-bc4a-20b2984479b2
```

Do not manually launch a tester. The paced fleet may claim the pending row
after the enqueue. No T_Live or AutoTrading action is authorized.

## Protected surfaces

This handoff does not modify or invoke `portfolio_admission`, `_kpi`,
`_q08_contribution`, the T_Live manifest, T_Live, or AutoTrading. It does not
alter the approved card, EA, EX5, setfile, basket manifest, registry, queue, or
phase evidence.
