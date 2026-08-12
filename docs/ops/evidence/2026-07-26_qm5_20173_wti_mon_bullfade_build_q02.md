# QM5_20173 WTI Monday Positive-Trend Counterfade — Q01 PASS / Q02 Blocked

**Date:** 2026-07-26
**Branch:** `agents/board-advisor`

## Outcome

`QM5_20173_wti-mon-bullfade` shorts source-documented WTI Monday weakness
only when the completed 252-D1 log return is strictly positive. This is a
weekly countertrend state distinct from negative-trend `QM5_20149`, the
unconditional Monday short, gold/silver ratio builds, and QM5_12567 RSI
pullback logic.

## Evidence

- Governed source packet:
  `strategy-seeds/sources/QUAY-MOP-WTI-MONBULL-2026/source.md`
- Approved card:
  `strategy-seeds/cards/approved/QM5_20173_wti-mon-bullfade_card.md`
- Card schema lint: PASS; no ML hits or missing sections.
- EA registry: `20173,wti-mon-bullfade`.
- Magic registry: slot 0, `XTIUSD.DWX`, magic `201730000`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile summary:
  `D:\QM\reports\compile\20260726_103522\summary.csv`
- Targeted build check:
  `D:\QM\reports\framework\21\build_check_20260726_103629.json`
  (PASS, 0 failures, 0 warnings).
- Binary SHA256:
  `92B86CDA059D2174E024D3EAEF114862C91C49E2F4F99C2F8D2EB9017269C975`
- Backtest setfile: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.

## Q02 Enqueue

The canonical targeted command was attempted:

`python tools/strategy_farm/sweep_enqueue_built_eas.py --apply --ea QM5_20173 --queue-ceiling 10000`

It returned `{"skipped":"FACTORY_OFF.flag set"}`. The safety flag was not
removed or bypassed, and no direct SQLite insertion was made. Retry the same
targeted command only in an authorized factory-on window.

No manual tester, live setfile, T_Live access, AutoTrading action, deploy
manifest, portfolio manifest, or portfolio-gate change was performed.
