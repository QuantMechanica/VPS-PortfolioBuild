# Evidence: EA Build & Compilation QM5_12920 (qp-pre-election-sp500)

**Date:** 2026-08-21  
**Agent:** Gemini  
**Task ID:** `19c8295f-c2aa-47b6-9e55-47e0fa465b0f`  
**EA ID:** `12920`  
**Slug:** `qp-pre-election-sp500`  
**Status:** `REVIEW` (awaiting Codex review)

---

## Summary

Implemented full mechanical MQL5 strategy logic, specification, backtest setfile, and binary compilation for `QM5_12920_qp-pre-election-sp500` per approved strategy card `7ede58dd-d184-5099-9d48-7a65de230853` (Quantpedia Pre-Election Drift in S&P 500).

## Strategy Mechanics
- **Universe:** `SP500.DWX` on `D1` timeframe.
- **Calendar Logic:** US Federal elections occur on the Tuesday after the first Monday in November of even-numbered years.
- **Entry:** Long `SP500.DWX` at the close of D-5 trading days (Tuesday exactly 7 calendar days before Election Day).
- **Exit:** Flat at the close of Election Day (D0, Tuesday).
- **Risk & Stop:** Protective hard stop at 2.0x D1 ATR(20). P2 baseline fixed risk $1000 per trade (`RISK_FIXED=1000`, `RISK_PERCENT=0`).

## Artifacts Produced
1. `framework/EAs/QM5_12920_qp-pre-election-sp500/QM5_12920_qp-pre-election-sp500.mq5` - Full MQL5 strategy code with calendar computation and framework hooks.
2. `framework/EAs/QM5_12920_qp-pre-election-sp500/SPEC.md` - Complete strategy specification document.
3. `framework/EAs/QM5_12920_qp-pre-election-sp500/sets/QM5_12920_qp-pre-election-sp500_SP500.DWX_D1_backtest.set` - P2 backtest setfile.
4. `framework/EAs/QM5_12920_qp-pre-election-sp500/QM5_12920_qp-pre-election-sp500.ex5` - Compiled MT5 binary.
5. `framework/include/QM/QM_MagicResolver.mqh` - Regenerated to include magic allocation slots.

## Verification
- `tools/strategy_farm/compile_ea.py --ea-id 12920`: **COMPILED** (0 errors, 0 warnings).
- `tools/strategy_farm/validate_build_guardrails.py`: **PASS** (0 findings, news stale <= 336h, valid risk mode).
