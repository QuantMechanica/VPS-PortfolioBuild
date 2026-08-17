# QM5_33006 (andrea-unger-turtle-soup-false-breakout) Build & Verification Evidence

- Task ID: `1da33eb5-f18a-4d65-9346-e7e9ef07fbf9`
- EA ID: `QM5_33006`
- Date: 2026-08-17
- Branch: `agents/board-advisor`
- Target symbols: `SP500.DWX` (slot 0), `XTIUSD.DWX` (slot 1), `EURUSD.DWX` (slot 2)
- Timeframe: `D1`
- Magic Numbers: `330060000` (slot 0), `330060001` (slot 1), `330060002` (slot 2)

## Summary of Implementation

Implemented Andrea Unger's Turtle Soup False Breakout Fade system mechanically per approved strategy card `QM5_33006_andrea-unger-turtle-soup-false-breakout.md`:
- 20-day Donchian extremes ($High_{20}$, $Low_{20}$) calculated across completed daily bars [2..21] at Shift=1.
- Long Entry: triggers when bar [1] penetrates prior 20-day low ($\text{Low}[1] < \text{Low}_{20}$) but closes back inside ($\text{Close}[1] > \text{Low}_{20}$), placing BUY_STOP at $\text{Low}_{20} + 1\text{ tick}$.
- Short Entry: triggers when bar [1] penetrates prior 20-day high ($\text{High}[1] > \text{High}_{20}$) but closes back inside ($\text{Close}[1] < \text{High}_{20}$), placing SELL_STOP at $\text{High}_{20} - 1\text{ tick}$.
- Risk & Money Management: Stop Loss placed at trigger bar extreme $\mp 2\text{ ticks}$; Take Profit placed at the 10-day opposite extreme (10-day high for longs, 10-day low for shorts).
- OCO enforcement: cancels unfilled opposite pending stop upon trade execution.
- No-Trade Filter: spread filter ($> 1.8 \times \text{ATR}(14, \text{D1})[1]$) and 23:55-00:05 rollover blackout.

## Verification Checklist

- **Magic Numbers Registry**: Registered all 3 portable DWX basket symbols in `framework/registry/magic_numbers.csv` (`330060000`, `330060001`, `330060002`).
- **Magic Resolver**: Regenerated `framework/include/QM/QM_MagicResolver.mqh` via `python framework/scripts/update_magic_resolver.py` (17,340 rows kept, 0 dropped).
- **SPEC Document**: Created `framework/EAs/QM5_33006_andrea-unger-turtle-soup-false-breakout/SPEC.md` and validated with `validate_spec_doc.py` -> `PASS`.
- **Build Check & Compilation**: Ran `build_check.ps1` -> `PASS` (0 errors, 0 warnings; `.ex5` compiled cleanly).
- **Setfile Generation**: Generated `SP500.DWX`, `XTIUSD.DWX`, and `EURUSD.DWX` D1 backtest setfiles in `sets/` with `RISK_FIXED=1000` and `RISK_PERCENT=0`.
- **Build Guardrails**: Verified via `tools/strategy_farm/validate_build_guardrails.py` -> `PASS` (`max_news_stale_hours: 336`, `verdict: PASS`).
- **Smoke Status**: `deferred_p2_smoke` recorded due to headless scheduled execution; Q02 will provide runtime backtest evidence.

## State Disposition

Artifact ready for Codex review.
