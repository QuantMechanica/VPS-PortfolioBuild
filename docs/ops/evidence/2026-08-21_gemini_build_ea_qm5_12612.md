# Evidence: EA Build & Compilation QM5_12612 (tsmom-12m-vol-scaled-ndx)

**Date:** 2026-08-21  
**Agent:** Gemini  
**Task ID:** `27fb255a-232e-4a06-9e12-f80e263f98e3`  
**EA ID:** `12612`  
**Slug:** `tsmom-12m-vol-scaled-ndx`  
**Status:** `REVIEW` (awaiting Codex review)

---

## Summary

Implemented full mechanical MQL5 strategy logic, specification, backtest setfile, and binary compilation for `QM5_12612_tsmom-12m-vol-scaled-ndx` per approved strategy card `e5a3f925-5a9e-513d-9e70-5c7c70fa0e59` (Moskowitz, Ooi & Pedersen 2012 TSMOM on NDX with trailing realized volatility scaling).

## Strategy Mechanics
- **Universe:** `NDX.DWX` on `D1` timeframe.
- **Monthly Gate:** Evaluated on the first D1 bar of each calendar month.
- **Directional Signal:** Sign of 12-month return (`close[1] / close[1 + 252] - 1.0`).
- **Volatility Scaling:** Trailing 63-day realized annualized volatility from log returns. Sizing multiplier `vol_scalar = target_vol / Max(realized_vol, 0.01)`, clamped between 0.10 and 2.00 (target vol = 10%).
- **Rebalance / Sizing:** Direction flip closes and reverses; vol change > 20% resizes position; hold otherwise.
- **Risk & Stop:** Protective ATR(14, D1) x 3.0 hard stop. P2 baseline $1000 fixed risk scaled by vol multiplier (`scaled_risk = RISK_FIXED * vol_scalar`).

## Artifacts Produced
1. `framework/EAs/QM5_12612_tsmom-12m-vol-scaled-ndx/QM5_12612_tsmom-12m-vol-scaled-ndx.mq5` - Full MQL5 strategy code with realized vol computation and monthly rebalance.
2. `framework/EAs/QM5_12612_tsmom-12m-vol-scaled-ndx/SPEC.md` - Complete strategy specification document.
3. `framework/EAs/QM5_12612_tsmom-12m-vol-scaled-ndx/sets/QM5_12612_tsmom-12m-vol-scaled-ndx_NDX.DWX_D1_backtest.set` - P2 backtest setfile.
4. `framework/EAs/QM5_12612_tsmom-12m-vol-scaled-ndx/QM5_12612_tsmom-12m-vol-scaled-ndx.ex5` - Compiled MT5 binary.
5. `framework/include/QM/QM_MagicResolver.mqh` - Regenerated to include magic allocation slots.

## Verification
- `tools/strategy_farm/compile_ea.py --ea-id 12612`: **COMPILED** (0 errors, 0 warnings).
- `tools/strategy_farm/validate_build_guardrails.py`: **PASS** (0 findings, news stale <= 336h, valid risk mode).
