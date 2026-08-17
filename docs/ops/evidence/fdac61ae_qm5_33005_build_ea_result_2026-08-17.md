# QM5_33005 (andrea-unger-dax-intraday-bias-breakout) Build & Verification Evidence

- Task ID: `fdac61ae-c7a2-407e-bfef-fdda420857f2`
- EA ID: `QM5_33005`
- Date: 2026-08-17
- Branch: `agents/board-advisor`
- Target symbol: `GDAXI.DWX` (slot 0)
- Timeframe: `M15`
- Magic Number: `330050000` (slot 0)

## Summary of Implementation

Implemented 4-time World Cup Trading Champion Andrea Unger's DAX opening range breakout system mechanically per approved strategy card `QM5_33005_andrea-unger-dax-intraday-bias-breakout.md`:
- 30-minute opening range calculated across 09:00-09:30 CET (10:00-10:30 broker time) from closed M15 bars [1] and [2].
- At 10:30 broker open, places BUY_STOP at $High_{30} + 3.0$ pts and SELL_STOP at $Low_{30} - 3.0$ pts with order expiration set to intraday cash session close (18:30 broker / 17:30 CET).
- Risk & Trade Management: initial stop loss at $0.60 \times Range_{30}$, take profit at $1.80 \times Range_{30}$ (1:3.0 R:R).
- OCO enforcement cancels unfilled opposite stop order upon trade fill.
- Intraday Time Exit: strictly closes all open positions at 18:30 broker (17:30 CET Frankfurt cash close).
- No-trade filter: spread filter relative to M15 ATR and 23:55-00:05 rollover blackout.

## Verification Checklist

- **Magic Numbers Registry**: Registered `33005,andrea-unger-dax-intraday-bias-breakout,0,GDAXI.DWX,330050000,2026-08-17T18:40:00Z,Gemini,active` in `framework/registry/magic_numbers.csv`.
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,320 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_33005_andrea-unger-dax-intraday-bias-breakout/SPEC.md` and validated with `validate_spec_doc.py` -> `PASS`.
- **Build Check & Compilation**: Ran `build_check.ps1` -> `PASS` (0 errors, 0 warnings; `.ex5` compiled cleanly).
- **Setfile Generation**: Generated `GDAXI.DWX` M15 backtest setfile in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> `PASS` (`max_news_stale_hours: 336`, `verdict: PASS`).
- **Smoke Status**: `deferred_p2_smoke` recorded due to headless scheduled execution; Q02 will provide runtime backtest evidence.

## State Disposition

Artifact ready for Codex review.
