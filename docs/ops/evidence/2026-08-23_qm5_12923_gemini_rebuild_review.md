# QM5_12923 Gemini Rebuild and Verification

Date: 2026-08-23

- Task ID: `f9e1abeb-a14c-4f02-9869-b9d99fcbf303`
- EA ID: `QM5_12923`
- Slug: `hopwood-dmi-cross-h1-card`
- EA Directory: `framework/EAs/QM5_12923_hopwood-dmi-cross-h1-card`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12923_hopwood-dmi-cross-h1-card.md`
- Branch: `agents/board-advisor`
- Assigned Agent: `gemini`
- Prior Review: `a2effd9b-b0bb-4def-b95e-cee799c24f88` (RECYCLE verdict)

## Summary of Defects Addressed

1. **Setfile / SPEC Universe Discrepancy Resolved**:
   - Generated the 4 missing setfiles: `NDX.DWX` (slot 1), `SP500.DWX` (slot 2), `UK100.DWX` (slot 3), and `WS30.DWX` (slot 4).
   - Updated `SPEC.md` Section 3 to explicitly enumerate all 9 symbols in the designed universe (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `AUDUSD.DWX`, `GDAXI.DWX`, `NDX.DWX`, `WS30.DWX`, `UK100.DWX`, `SP500.DWX`).
   - Every declared symbol now has a valid corresponding setfile with matching slot offsets from `magic_numbers.csv`.
2. **Execution Contract Hygiene**:
   - `QM_EntryRequest` is explicitly zero-initialized via `ZeroMemory(req);`, with `req.symbol_slot = qm_magic_slot_offset;` and `req.expiration_seconds = 0;`.
   - `QM_FrameworkTrackOpenPositionMae()` is called on tick.
   - All 9 setfiles use `RISK_FIXED = 1000.0`, `RISK_PERCENT = 0.0`, and `PORTFOLIO_WEIGHT = 1.0`.

## Verification & Guardrail Results

- `validate_build_guardrails.py`: **PASS** (10 files checked, 0 findings, news stale limit = 336 hours).
- `validate_symbol_scope.py`: **SINGLE_SYMBOL_OK** (0 violations).
- MQ5 SHA-256: `6d0d02a3fcc80f9fdd01bde9fb1acd4638b1d34aaa4949d5c13442fbb60288e2`.
- EX5 SHA-256: `4417b4a9e5140a69066b2e8d536a7997c807c80b52038a3e2e31171580c2912e`.
- Setfile Audit: 9/9 setfiles pass build guardrails and symbol scoping.
- Artifact updated at `C:/QM/repo/artifacts/qm5_12923_build_result.json`.

Task is submitted for mandatory Codex review in state `REVIEW`.
