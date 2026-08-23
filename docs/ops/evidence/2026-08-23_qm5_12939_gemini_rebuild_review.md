# QM5_12939 Gemini Rebuild and Verification

Date: 2026-08-23

- Task ID: `2a3580e3-ddbf-4853-b012-0cab4471109e`
- EA ID: `QM5_12939`
- Slug: `carney-alternate-bat-h4`
- EA Directory: `framework/EAs/QM5_12939_carney-alternate-bat-h4`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12939_carney-alternate-bat-h4.md`
- Branch: `agents/board-advisor`
- Assigned Agent: `gemini`
- Prior Review: `98e0cec3-d7a2-46f7-b8ad-f09146151f78` (RECYCLE verdict)

## Summary of Defects Addressed

1. **Double New-Bar Evaluation Fixed**: `QM_IsNewBar(_Symbol, _Period)` was previously called twice per tick in `OnTick()`, causing the second call to evaluate to false on every tick and preventing any entry execution. Replaced with single evaluated boolean `const bool is_new_bar = QM_IsNewBar(_Symbol, _Period);`.
2. **Entry Request Contract Hygiene**: `QM_EntryRequest` is now zero-initialized via `ZeroMemory(req);`, with explicit `req.symbol_slot = qm_magic_slot_offset;` and `req.expiration_seconds = 0;`.
3. **T1 Partial Close & T2 Target Implementation**:
   - Implemented T1 partial take profit (50% position close) at 38.2% AD retracement via `QM_TM_PartialClose(ticket, half_vol, QM_EXIT_STRATEGY)`.
   - Set broker TP to T2 target (remaining 50% position) at 61.8% AD retracement.
   - Implemented post-T1 ATR trailing stop trailing at 1.0 * ATR(14) below bar 1 low (buy) / above bar 1 high (sell).
4. **Opposite-Direction Alternate-Bat Exit**: Implemented `Strategy_ExitSignal()` to detect confirmed opposite-direction harmonic signals and trigger position close via `QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY)`.
5. **Execution Order & MAE Tracking**: Ordered `QM_FrameworkTrackOpenPositionMae()`, Friday close, and position management cleanly ahead of entry filters.

## Verification & Guardrail Results

- `validate_build_guardrails.py`: **PASS** (14 files checked, 0 findings, news stale limit = 336 hours).
- `validate_symbol_scope.py`: **SINGLE_SYMBOL_OK** (0 violations).
- MQ5 SHA-256: `d9a62e7b379ffcb65f7968fcb38320b3aa37379ab93b718d09e3004fa3f40177`.
- Setfile Audit: 13/13 setfiles retain `RISK_FIXED=1000.0`, `RISK_PERCENT=0.0`, `qm_news_stale_max_hours=336`.
- Artifact updated at `C:/QM/repo/artifacts/qm5_12939_build_result.json`.

Task is submitted for mandatory Codex review in state `REVIEW`.
