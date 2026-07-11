# QM5_10581 Diverse-FX Q02 Performance Recovery

Date: 2026-07-11
Branch: `agents/board-advisor`
Agent task: `2e5d94cd-b0c8-4ced-a8bf-3df7d0e614d6`

## Outcome

`QM5_10581_mql5-lr-slope` was repaired, strictly recompiled, and canonically
re-enqueued to Q02 on its complete approved H4 basket. The four new work items
are pending; the factory was not dispatched because `FACTORY_OFF.flag` is set.

This is a diversity recovery rather than build-volume work: the approved basket
contains three FX instruments (`USDJPY.DWX`, `EURUSD.DWX`, `GBPJPY.DWX`) plus
`XAUUSD.DWX`, and the card expects about 40 closed-bar trades per year per
symbol. The source is Nikolay Kositsin's published MQL5 CodeBase
`Exp_LinearRegSlope_V1` implementation. Card gates R1-R4 and the existing EA
review are PASS / `APPROVE_FOR_BACKTEST`.

## Collision and gate checks

- Atomically claimed the recovery in `agent_tasks`; no other active agent task
  or pending/claimed/running Q02-Q03 work item existed for `QM5_10581`.
- Existing review task:
  `a22f8a70-bbc8-4176-9c46-7eb1ce577cd4`, verdict
  `APPROVE_FOR_BACKTEST`.
- The EA is absent from `requeue_excluded_eas.txt`.
- Before repair, all 52 recorded Q02 outcomes were infrastructure-class only;
  there was no Q02 business verdict and no later pipeline phase.

## Diagnosis

The latest per-symbol attempts all ended at the worker collection boundary with
`summary_missing_retries_exhausted`:

| Symbol | Work item | Elapsed after claim |
|---|---|---:|
| EURUSD.DWX | `016ea771-dda0-4f07-a6aa-a0d53d376a10` | 22 s |
| GBPJPY.DWX | `0a9e7b55-34fe-4c4f-b462-fb02e42b35ec` | 30 s |
| USDJPY.DWX | `02bdd2d0-3fb8-49b8-baee-0c8e29e419c6` | 30 s |
| XAUUSD.DWX | `19cc5780-96d8-4aef-8a19-67710e7a6097` | 31 s |

The EURUSD attempt eventually left a complete MT5 HTML report under
`D:\QM\reports\work_items\016ea771-dda0-4f07-a6aa-a0d53d376a10`, but the
farm summary was not collected. The EA had two deterministic performance
faults consistent with this race:

1. While a position was open, `Strategy_ExitSignal()` recomputed the H4 cross
   on every tick. One evaluation made 500 individual `iClose` calls
   (`25 + 9*25 + 25 + 9*25`).
2. The historical news-calendar gate ran on every tick before position
   management and exits.

## Repair

- A single `QM_IsNewBar(_Symbol, PERIOD_H4)` decision now drives H4 signal
  work.
- One bounded 34-bar `CopyRates` read computes and caches all required
  regression slopes once per H4 bar. Entry and opposite-cross exit consume the
  same cached signal.
- Friday close, position management, and mechanical exits run before news
  filtering. News filtering now gates new exposure only.
- Close operations are explicitly scoped by both symbol and registered magic.
- All four canonical backtest setfiles were regenerated from the approved card
  and magic registry. Each uses `RISK_FIXED=1000`, `RISK_PERCENT=0`, the proper
  unique slot, and the complete strategy-input defaults.
- `docs/strategy_card.md` is a byte-exact copy of the approved farm card, and
  `SPEC.md` records the performance recovery without changing the strategy
  rule.

## Verification

- Regression-window equivalence: PASS across 100 randomized combinations of
  regression and signal periods; cached windows reproduced the previous
  closed-bar slope values exactly.
- SPEC validator: PASS, 1/1.
- Setfile/input contract: PASS for all four backtest setfiles.
- Strict compile: PASS, 0 errors, 0 warnings.
  - Log:
    `C:\QM\repo\framework\build\compile\20260711_204823\QM5_10581_mql5-lr-slope.compile.log`
  - Binary SHA-256:
    `93E9E5392B5696C534905B7AFF90A1EA3786F9DD97DFCCEB4DCB3F2035A76B23`
- Scoped framework build check with `-SkipCompile`: PASS, 0 failures.
  - Report:
    `D:\QM\reports\framework\21\build_check_20260711_204843.json`
  - One advisory remains because the static scanner cannot see that
    `Strategy_RefreshSignalCache()` is called only inside the
    `new_signal_bar` branch; the bounded call is explicitly marked
    `perf-allowed` in source.
- No smoke or backtest was started: the state flag
  `D:\QM\strategy_farm\state\FACTORY_OFF.flag` remains authoritative.
- No T_Live, AutoTrading, portfolio-gate, or deploy-manifest state was touched.

## Canonical Q02 enqueue

Farm task: `d7bd0b9d-7e68-4dba-9071-141314ef2c7a`

| Symbol | Q02 work item | State |
|---|---|---|
| EURUSD.DWX | `81ac8aab-cd41-4f41-bae1-c202913d1bb2` | pending |
| GBPJPY.DWX | `c823ba52-603b-462a-9104-06d688a4f78b` | pending |
| USDJPY.DWX | `1c96d051-6dda-45aa-bb24-6b1c12dd39f4` | pending |
| XAUUSD.DWX | `11f92ac8-c536-4ca4-a1fc-871e966c37d2` | pending |

The enqueue used `farmctl.py enqueue-backtest` with the existing approved
review. No dispatch was requested.
