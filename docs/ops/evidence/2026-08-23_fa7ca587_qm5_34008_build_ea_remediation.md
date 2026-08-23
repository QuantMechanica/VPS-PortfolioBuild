# QM5_34008 (multicurrency-basket-dispersion-hedger) Build Remediation Evidence

- Task ID: `fa7ca587-77f8-4cea-b71b-7bb1b746b33d`
- EA ID: `QM5_34008`
- Slug: `multicurrency-basket-dispersion-hedger`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Target symbols: EURUSD.DWX (slot 0), GBPUSD.DWX (slot 1), AUDUSD.DWX (slot 2), NZDUSD.DWX (slot 3), USDCAD.DWX (slot 4), USDCHF.DWX (slot 5), USDJPY.DWX (slot 6)
- Timeframe: H1
- Magic Numbers: 340080000 - 340080006

## Summary of Changes and Remediation

Addressed findings from Codex review `72b63c06-7749-4ac4-8276-fcf7bdc02dc4`:
1. **Market-Neutral Two-Leg Package**: Implemented atomic simultaneous entry of `argmin(delta_k)` (USD lagging extremum -> Buy USD) and `argmax(delta_k)` (USD leading extremum -> Sell USD) using `QM_BasketOpenPosition` across the 7-pair basket with fail-closed rollback if both legs cannot be established.
2. **Portfolio-Level Basket Exits**: Implemented combined package exit in `Strategy_ExitSignal` / `Strategy_ManageOpenPosition` that monitors aggregate PnL across all package positions and closes the package upon hitting $+1.5\%$ portfolio profit or $-1.5\%$ portfolio drawdown per card section 3.4. Also flattens orphan positions if unhedged.
3. **Registry & Include Mirroring**: Confirmed all 7 symbols in `framework/registry/magic_numbers.csv` and verified `QM_MagicResolver.mqh` integration.

## Verification Checklist

- **SPEC Validation**: `python framework/scripts/validate_spec_doc.py framework/EAs/QM5_34008_multicurrency-basket-dispersion-hedger` -> PASS (0 failures).
- **Build Guardrails**: `python tools/strategy_farm/validate_build_guardrails.py --max-news-stale-hours 336 framework/EAs/QM5_34008_multicurrency-basket-dispersion-hedger` -> PASS (`verdict: PASS`, 0 findings).
- **Setfile Discipline**: All 7 backtest setfiles configured with `RISK_FIXED=1000` and `RISK_PERCENT=0`.

## State Disposition

Draft code updated and verified. Forwarded to Codex review in state `REVIEW`.
