# QM5_13095 XTI Outside-Week Fade Q02 Enqueue

Date: 2026-07-09
Branch: `agents/board-advisor`
Operator: Codex

## Action

Built `QM5_13095_xti-outweek-fade` as a new structural crude-oil sleeve and
auto-enqueued one Q02 work item.

- Edge: `XTIUSD.DWX` D1 outside-week exhaustion fade
- Symbol: `XTIUSD.DWX`
- Build task: `24c4e2fd-43b2-4729-93bf-acd53ddc7e5f`
- Q02 work item: `feda82d7-70c2-480f-9393-4d15ef8dfbb7`
- Status after enqueue: `pending`
- Setfile risk mode: `RISK_FIXED=1000`, `RISK_PERCENT=0`
- Source: Crabel, *Day Trading with Short-Term Price Patterns and Opening Range Breakout*; EIA WTI spot-price market context

## Rationale

The current certified book already has XAU, SP500, NDX, and XNG exposure. This
build adds solo crude-oil outside-week exhaustion exposure: the prior broker
week must expand beyond both sides of the parent week, close in an extreme
tail, and the current week must show D1 reversal evidence before the EA fades
the outside-week move.

This is non-duplicate versus existing WTI sleeves because it is not weekly ORB,
inside-week compression breakout, monthly ORB, post-WPSR inside-bar event
breakout, weekend gap, fixed calendar month/weekday seasonality, inventory/OPEC
refinery/news proxy, futures-curve ratio, broad commodity reversal, VRP proxy,
or commodity RSI logic.

## Verification

- `build_check.ps1 -EALabel QM5_13095_xti-outweek-fade -Strict`: PASS, 0
  errors, 0 warnings, report `D:/QM/reports/framework/21/build_check_20260709_162318.json`
- `build_check.ps1 -EALabel QM5_13095_xti-outweek-fade -Strict -SkipCompile`:
  PASS, report `D:/QM/reports/framework/21/build_check_20260709_162431.json`
- `validate_spec_doc.py framework/EAs/QM5_13095_xti-outweek-fade`: PASS
- `validate_symbol_scope.py --ea-label QM5_13095_xti-outweek-fade --json`:
  `SINGLE_SYMBOL_OK`
- `skill_card_schema_lint.py --card D:/QM/strategy_farm/artifacts/cards_approved/QM5_13095_xti-outweek-fade.md`:
  PASS
- Magic resolver regenerated and includes `13095`; strict resolver mode still
  reports unrelated pre-existing missing EA dirs `1001`, `1015`, and `1016`.

## CPU Ceiling

No manual MT5 backtest was launched. The paced worker fleet owns Q02 dispatch.

Detailed machine-readable artifacts:

- `artifacts/qm5_13095_build_result.json`
- `artifacts/qm5_13095_q02_enqueue_20260709.json`
