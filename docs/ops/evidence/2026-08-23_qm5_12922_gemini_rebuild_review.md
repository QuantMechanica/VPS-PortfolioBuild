# QM5_12922 Gemini Rebuild and Verification

Date: 2026-08-23

- Task ID: `11468a5a-89fc-4872-b6ec-2a78250ae792`
- EA ID: `QM5_12922`
- Slug: `ariel-first-half-month-idx`
- EA Directory: `framework/EAs/QM5_12922_ariel-first-half-month-idx`
- Approved Card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_12922_ariel-first-half-month-idx.md`
- Branch: `agents/board-advisor`
- Assigned Agent: `gemini`
- Prior Review: `800cfced-22aa-49e9-83d0-2ef5356ef2a4` (RECYCLE verdict)

## Summary of Defects Addressed

1. **Restart-Safe Calendar Reconstruction**:
   - Implemented `Strategy_GetTradingDayOfMonth(const datetime current_d1_time)` which uses `CopyTime` from the 1st calendar day of the current month up to the current bar time to determine the exact trading day ordinal (T+1, T+2, ...).
   - If historical D1 bars cannot be copied, the function fails closed (returns 0) rather than manufacturing an artificial T+1 signal upon restart.
2. **News-Blackout Deferral from T+1 to T+2**:
   - If high-impact news blocks trading during the T+1 session, `g_strategy_entry_deferred` is set to `true`, and the entry attempt is deferred to T+2.
   - On T+2, if news allows and position count is zero, the entry is taken with reason `ARIEL_FIRST_HALF_MONTH_T2_DEFERRED`.
   - After T+2 or upon entry execution, deferral state is cleared so trades are not entered late into the month.
3. **Entry Request Contract Hygiene**: `QM_EntryRequest` is explicitly zero-initialized via `ZeroMemory(req);`, with `req.symbol_slot = qm_magic_slot_offset;` and `req.expiration_seconds = 0;`.
4. **MAE Tracking**: Included `QM_FrameworkTrackOpenPositionMae()` at the start of `OnTick()`.

## Verification & Guardrail Results

- `validate_build_guardrails.py`: **PASS** (6 files checked, 0 findings, news stale limit = 336 hours).
- `validate_symbol_scope.py`: **SINGLE_SYMBOL_OK** (0 violations, universe bounded to 5 indices).
- MQ5 SHA-256: `02bdd8bd0fccd4701e641031ab16e847a30a43909a49dc87617ed02534c8aa90`.
- Setfile Audit: 5/5 setfiles retain `RISK_FIXED=1000.0`, `RISK_PERCENT=0.0`, `qm_news_stale_max_hours=336`.
- Artifact updated at `C:/QM/repo/artifacts/qm5_12922_build_result.json`.

Task is submitted for mandatory Codex review in state `REVIEW`.
