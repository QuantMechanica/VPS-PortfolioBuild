# QM5_34001 (kalman-filter-state-estimation-scalper) Build & Verification Evidence

- Task ID: `f9a8b8f7-3307-44d7-a1c4-2ad8c2a4cac9`
- EA ID: `QM5_34001`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Target symbols: `EURUSD.DWX` (slot 0), `GBPUSD.DWX` (slot 1), `USDJPY.DWX` (slot 2)
- Timeframe: `M15`
- Magic Numbers: `340010000` (slot 0), `340010001` (slot 1), `340010002` (slot 2)
- MQ5 SHA-256: `2095ff4337efa71e0ddb6ca9a5551e8179ba6fdbdeeafdf23b3ad13453da28c0`
- EX5 SHA-256: `7287c0110656f804db1d137665249f98c4bbc9fcceabfe6b1ff1a2a76b6ad608`

## Summary of Implementation & Hardening

- Discrete 1D Kalman Filter state estimation on closed M15 bar prices over 100-bar rolling history per approved card `QM5_34001_kalman-filter-state-estimation-scalper.md`.
- Hardening D7 MAE hook: Added `QM_FrameworkTrackOpenPositionMae()` to `OnTick`.
- Hardening checks D3-D18: PASS with 0 failures.

## Verification Checklist

- **Build Guardrails**: Verified via `validate_build_guardrails.py` -> PASS (max news stale hours: 336).
- **SPEC Document**: Created and validated with `validate_spec_doc.py` -> PASS.
- **Setfile Generation**: Generated EURUSD.DWX, GBPUSD.DWX, and USDJPY.DWX M15 backtest setfiles with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and valid `build_hash`.
- **Smoke Status**: `deferred_p2_smoke` recorded; live MT5 worker backtests active; runtime backtest deferred to Q02 dispatch.

## State Disposition

Artifact ready for Codex review.
