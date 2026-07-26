# QM5_20174 WTI Tuesday Positive-Trend Counterfade — Q01 PASS / Q02 Enqueued

**Date:** 2026-07-26  
**Branch:** `agents/board-advisor`

## Outcome

`QM5_20174_wti-tue-bullfade` shorts source-documented WTI Tuesday weakness
only when the completed 252-D1 log return is strictly positive. It is a
weekly countertrend calendar package distinct from unconditional
`QM5_12610_wti-tue-fade`, negative-trend continuation
`QM5_20155_wti-tue-trend`, the gold/silver baskets, and QM5_12567 RSI
pullback logic.

The EA requires a genuine Monday-to-Tuesday D1 boundary, consumes one
restart-safe attempt per Tuesday-anchored broker week, attaches a frozen
`3.0 * ATR(20)` hard stop, and exits at the next non-Tuesday D1 bar.

## Evidence

- Governed source packet:
  `strategy-seeds/sources/GORSKA-MOP-WTI-TUEBULL-2026/source.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_20174_wti-tue-bullfade_card.md`
- Card schema lint: PASS; no ML hits or missing sections.
- EA registry: `20174,wti-tue-bullfade`.
- Magic registry: slot 0, `XTIUSD.DWX`, magic `201740000`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile summary:
  `D:\QM\reports\compile\20260726_145157\summary.csv`
- Targeted build check:
  `D:\QM\reports\framework\21\build_check_20260726_145312.json`
  (PASS, 0 failures, 0 warnings).
- Binary SHA256:
  `A58ECA67B4446FA0977521D4BA5C88AEEEEFBDA71E004F9F9704776D2BC57F3D`
- Backtest setfile: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Q02 work item:
  `4d229268-e541-4c34-8282-f884ec85db5f`, pending, `XTIUSD.DWX`.

The canonical targeted paced command was:

`python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20174 --queue-ceiling 10000`

No manual tester, live setfile, T_Live access, AutoTrading action, deploy
manifest, portfolio manifest, or portfolio-gate change was performed.
