# QM5_41009 (volume-profile-value-area-rejection) Build & Verification Evidence

- Task ID: `0fd1b0a8-c415-4309-9778-4ebefa05a1cf`
- EA ID: `QM5_41009`
- Date: 2026-08-23
- Branch: `agents/board-advisor`
- Target symbols: `SP500.DWX` (slot 0), `NDX.DWX` (slot 1)
- Timeframe: `M5`
- Magic Numbers: `410090000` (slot 0), `410090001` (slot 1)
- MQ5 SHA-256: `6778562109d41de0519b208f9b944ff1540c9865d64b0a62741d4b47c7407c8d`
- EX5 SHA-256: `da2ad0e1343ffaf9b466e0de4bbbbc09871214754b5e4d07b549de174b7266c8`

## Summary of Implementation & Hardening

- Volume Profile Value Area (VAH/VAL) Rejection Scalper implemented mechanically per approved strategy card `QM5_41009_volume-profile-value-area-rejection.md`.
- Auction Market Theory model calculating prior session 70% Value Area High, Low, and Point of Control.
- Hardening D10 buffer bounds: Explicit `ArraySize` guards added to dynamic numeric buffer indexing in `BuildPriorProfile`.
- Hardening checks D3-D18: PASS with 0 failures.

## Verification Checklist

- **Build Guardrails**: Verified via `validate_build_guardrails.py` -> PASS (max news stale hours: 336).
- **SPEC Document**: Created and validated with `validate_spec_doc.py` -> PASS.
- **Setfile Generation**: Generated SP500.DWX and NDX.DWX M5 backtest setfiles with `RISK_FIXED=1000`, `RISK_PERCENT=0`, and valid `build_hash`.
- **Smoke Status**: `deferred_p2_smoke` recorded; live MT5 worker backtests active; runtime backtest deferred to Q02 dispatch.

## State Disposition

Artifact ready for Codex review.
