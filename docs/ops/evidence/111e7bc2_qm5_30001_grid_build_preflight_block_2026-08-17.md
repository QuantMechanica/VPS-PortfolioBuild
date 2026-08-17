# QM5_30001 (bollinger-bands-grid-waka-waka) Build Preflight — Deterministic Block

- Task ID: `111e7bc2-035a-44c0-9802-6ac23542e6cc`
- EA ID: `QM5_30001`
- Date: 2026-08-17
- Branch: `agents/board-advisor`
- Decision record checked: `decisions/DL-082_grid_cap_extended_commercial_ea_deconstructions.md`
- Evidence reference: `docs/ops/evidence/12148e59_grid_build_preflight_block_2026-08-16.md`
- Result: **no build started — blocked by active charter hard rule**

## Failed Gates & Preflight Findings

1. **Charter Hard Rule Conflict (No Grid / No Martingale)**:
   The scheduled-cycle instruction defines a hard boundary: Edge Lab work must strictly fit the active charter (FTMO + DXZ target, <=5% daily DD, <=10% total DD, mandatory news blackout, swing/scalping horizon only, no HFT, **no martingale/grid**, mechanical only, no ML in EA).
   Strategy card `QM5_30001_bollinger-bands-grid-waka-waka.md` explicitly specifies a 10-level dynamic ATR grid with a 1.45x martingale lot-progression multiplier and an unhedged 20% catastrophe drawdown basket stop, which directly violates the Edge Lab charter hard boundary.

2. **Registry & Execution Boundary**:
   Per the deterministic build protocol and DL-082, commercial grid EA deconstructions require explicit OWNER policy alignment and bounded group-stop verification. Under the current cycle's hard constraints, no martingale/grid EA may be drafted or advanced into backtest pipelines.

## Verification Performed

- Confirmed canonical checkout branch: `agents/board-advisor`.
- Verified clean state of scoped registry files: `framework/registry/magic_numbers.csv` and `framework/include/QM/QM_MagicResolver.mqh`.
- Did not allocate magic numbers or mutate registry for QM5_30001.
- Did not enqueue backtests or start MT5 terminals.

## Review Disposition

Deferred to `REVIEW` for OWNER / Codex review and charter reconciliation.
