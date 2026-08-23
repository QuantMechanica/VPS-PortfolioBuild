# QM5_12940 Gemini Rebuild and Verification

Date: 2026-08-23

- Task ID: `f2e0fa39-1871-43b8-a282-e0f2ea55e1cf`
- EA ID: `QM5_12940`
- Slug: `bressert-cycle-trigger-line-h4-card`
- EA Directory: `framework/EAs/QM5_12940_bressert-cycle-trigger-line-h4-card`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12940_bressert-cycle-trigger-line-h4-card.md`
- Branch: `agents/board-advisor`
- Assigned Agent: `gemini`
- Prior Review: `395e4a56-b7a5-4c07-9187-253b4d2d6dd0` (RECYCLE verdict)

## Summary of Defects Addressed

1. **Double New-Bar Evaluation Fixed**: Replaced redundant double `QM_IsNewBar` calls with single `const bool is_new_bar = QM_IsNewBar(_Symbol, _Period);`.
2. **DSS Array Out-of-Bounds Fixed**: Provided generous buffer headroom in `DSS_ComputeAtShift` so all inner loop accesses (`k1[s]` for `s < m + p3`) remain strictly within array bounds (`k1_count = rawk2_len + p3 + 10`).
3. **Dynamic Trigger Period**: Replaced hard-coded 3-bar average with `DSS_ComputeTriggerAtShift(shift, strategy_trigger_period)` to dynamically calculate trigger line over `strategy_trigger_period`.
4. **T1 Partial Close & Post-T1 ATR Trail**: Implemented 50% partial take profit at T1 (1.5 * ATR(14)) via `QM_TM_PartialClose(ticket, half_vol, QM_EXIT_STRATEGY)` and post-T1 ATR trailing stop at 1.0 * ATR(14).
5. **Entry Request Contract Hygiene**: `QM_EntryRequest` is explicitly zero-initialized via `ZeroMemory(req);`, with `req.symbol_slot = qm_magic_slot_offset;` and `req.expiration_seconds = 0;`.
6. **Execution Order & MAE Tracking**: Ordered `QM_FrameworkTrackOpenPositionMae()`, Friday close, and position management cleanly.

## Verification & Guardrail Results

- `validate_build_guardrails.py`: **PASS** (14 files checked, 0 findings, news stale limit = 336 hours).
- `validate_symbol_scope.py`: **SINGLE_SYMBOL_OK** (0 violations).
- MQ5 SHA-256: `f1ddd1562ce76f5ac9a6352d516f6cdd381f9e8875100cca95076a7449ccca55`.
- Setfile Audit: 13/13 setfiles retain `RISK_FIXED=1000.0`, `RISK_PERCENT=0.0`, `qm_news_stale_max_hours=336`.
- Artifact updated at `C:/QM/repo/artifacts/qm5_12940_build_result.json`.

Task is submitted for mandatory Codex review in state `REVIEW`.
