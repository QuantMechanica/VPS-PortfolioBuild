# QM5_12730 WTI March Premium Q02 Enqueue - 2026-06-28

Scope: branch `agents/board-advisor`; no `T_Live`, AutoTrading, portfolio-gate,
or deploy-manifest edits.

## Decision

Built `QM5_12730_wti-mar-prem`, a low-frequency structural WTI oil sleeve on
`XTIUSD.DWX`. The edge is a March-only D1 calendar premium from
`ARENDAS-OIL-SEASON-2018`, isolating the remaining unbuilt positive month from
the same academic crude-oil seasonality source family used by the April,
August, and November WTI sleeves.

It is deliberately not the existing gold/silver ratio, XNG RSI2 commodity
pullback, WTI event-window, WTI momentum/reversal, or already-built April/August
calendar-premium logic.

## Build

Artifacts:

- Card: `strategy-seeds/cards/wti-mar-prem_card.md`
- Approved repo copy: `strategy-seeds/cards/approved/QM5_12730_wti-mar-prem_card.md`
- Farm approved-card mirror:
  `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12730_wti-mar-prem_card.md`
- EA: `framework/EAs/QM5_12730_wti-mar-prem/QM5_12730_wti-mar-prem.mq5`
- Compiled EA: `framework/EAs/QM5_12730_wti-mar-prem/QM5_12730_wti-mar-prem.ex5`
- Backtest setfile:
  `framework/EAs/QM5_12730_wti-mar-prem/sets/QM5_12730_wti-mar-prem_XTIUSD.DWX_D1_backtest.set`

Registry:

- `framework/registry/ea_id_registry.csv`: `12730,wti-mar-prem,ARENDAS-OIL-SEASON-2018,active,Development,2026-06-28`
- `framework/registry/magic_numbers.csv`: `12730,wti-mar-prem,0,XTIUSD.DWX,127300000,2026-06-28,Development,active`

Validation:

```powershell
framework/scripts/compile_one.ps1 -EAPath framework/EAs/QM5_12730_wti-mar-prem/QM5_12730_wti-mar-prem.mq5 -Strict
framework/scripts/build_check.ps1 -EALabel QM5_12730_wti-mar-prem -SkipCompile
python tools/strategy_farm/validate_symbol_scope.py --ea-label QM5_12730_wti-mar-prem --json --fail-on-leak
python framework/scripts/skill_card_schema_lint.py --card strategy-seeds/cards/approved/QM5_12730_wti-mar-prem_card.md
```

Results:

- Compile: `PASS`, 0 errors, 0 warnings.
- Build check: `PASS`, 0 failures, 16 existing shared-framework DWX advisory warnings.
- Symbol scope: `SINGLE_SYMBOL_OK`.
- Card schema lint: `ok`, no ML hits.
- Setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`.

## Q02 Enqueue

Farm build task: `4f6b746f-8f0d-4583-b4d4-3ffd2bf652e2`.

`farmctl.py record-build` auto-enqueued one non-duplicate Q02 row:

| Field | Value |
|---|---|
| Work item | `e9c4acc8-af9d-460f-8bf0-5ec30197f075` |
| EA | `QM5_12730` |
| Symbol | `XTIUSD.DWX` |
| Phase | `Q02` |
| Status at handoff | `pending` |
| Setfile | `QM5_12730_wti-mar-prem_XTIUSD.DWX_D1_backtest.set` |

No manual MT5 backtest was launched. Q02 execution is left to the paced terminal
worker fleet.
