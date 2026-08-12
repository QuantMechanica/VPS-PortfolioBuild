# QM5_20172 WTI Friday Bear-Regime Bounce — Q01 PASS / Q02 Enqueued

**Date:** 2026-07-26  
**Branch:** `agents/board-advisor`

## Outcome

`QM5_20172_wti-fri-bear` buys the source-directed WTI Friday premium only
when the completed 252-D1 log return is negative. It enters at a genuine
Friday-after-Thursday boundary, attaches a frozen `3.0 * ATR(20)` stop, and
flattens through the V5 Friday-close control.

This mechanic is distinct from unconditional `QM5_12597_wti-fri-prem`,
positive-regime `QM5_20145_wti-fri-trend`, the Wednesday/Thursday
bear-regime variants, and `QM5_12567` RSI pullback logic.

## Evidence

- Reputable source packet:
  `strategy-seeds/sources/GORSKA-MOP-WTI-FRIBEAR-2026/source.md`
- Approved card:
  `artifacts/cards_approved/QM5_20172_wti-fri-bear_card.md`
- Card schema lint: PASS, no ML hits, no missing sections.
- EA registry: `20172,wti-fri-bear`.
- Magic registry: slot 0, `XTIUSD.DWX`, magic `201720000`.
- Strict compile: PASS, 0 errors, 0 warnings.
- Compile summary:
  `D:\QM\reports\compile\20260726_095359\summary.csv`
- Binary SHA256:
  `F7DDE33A57B428BCD4B23B77BBB2B84AAD1C5B2C0A24EE699FBE6C44429365D2`
- Backtest setfile: D1, `RISK_FIXED=1000`, `RISK_PERCENT=0`,
  `PORTFOLIO_WEIGHT=1`.
- Q02 work item:
  `ab8d8b7a-1c17-4cdc-b259-080cab3b75df`, pending, `XTIUSD.DWX`.

No manual tester, live setfile, T_Live access, AutoTrading action, deploy
manifest, portfolio manifest, or portfolio-gate change was performed.

## Reconciliation note — 2026-07-29

This document remains the historical enqueue receipt. The referenced work item
subsequently completed `done/DRAFT_DEFECT`; it is not a Q02 PASS. A second row,
`88ba4560-fd7f-456f-903f-f4982d8f9cf3`, was later materialized from the stale
review-failed build result and has been quarantined as
`failed/BLOCKED_STALE_BUILD_RESULT` under transition-ledger sequence 2. A fresh
Q02 requires a new generation-bound build result and the coordinated restart
contract.
