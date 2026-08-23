# Claude re-verification: QM5_36004 remediation

- Review task: `af9af332-6c97-4abd-a319-4373c82e0844`
- Prior Codex review: `docs/ops/evidence/80b2cb2a_qm5_36004_gemini_build_codex_review_2026-08-18.md` (CHANGES_REQUIRED, 7 findings)
- Remediation commit: `1c8d911f9` (`build(ea): remediate QM5_36001 and QM5_36004 NNFX implementations per Codex review`), branch `agents/board-advisor`
- Remediation self-report: `docs/ops/evidence/22225e01_qm5_36004_build_ea_result_2026-08-23.md`
- Reviewed source: `framework/EAs/QM5_36004_nnfx-alma-qqe-volume-flow-sniper/QM5_36004_nnfx-alma-qqe-volume-flow-sniper.mq5` at current HEAD
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36004_nnfx-alma-qqe-volume-flow-sniper.md`
- **Verdict: CHANGES_STILL_REQUIRED — remain in REVIEW; no pipeline handoff. Remaining item: finding #5 only (fresh factory build + smoke evidence). Source code findings 1,2,3,4,6,7 independently re-verified as resolved against the approved card, not just against the self-report.**

Per hard rule (Gemini-originated code requires mandatory Codex review before acceptance),
this task stays in REVIEW regardless of verdict; Claude does not self-approve or advance
gemini-originated builds to PIPELINE.

## Per-finding re-verification (independent read of current .mq5, not the self-report)

| # | Severity | Original finding | Status | Evidence |
|---|----------|-------------------|--------|----------|
| 1 | Critical | Full-position TP instead of 50% partial + runner | **RESOLVED** | `req.tp=0.0` at entry; `Strategy_ManageOpenPosition` calls `QM_TM_PartialClose(ticket, volume*0.5, QM_EXIT_PARTIAL)` at +1.0 ATR, then moves runner SL to BE+1pip; `sl_not_breakeven` guard prevents re-fire |
| 2 | Critical | QQE persistent state substituted for crossover | **RESOLVED** | `Strategy_QQECross` compares shift-1 vs shift-2 state, returns non-zero only on fresh transition; entry requires `qqe_cross != 0` |
| 3 | High | Rollover blackout evaluated in broker time, not GMT | **RESOLVED** | `QM_BrokerToUTC(TimeCurrent())` used for the 23:55-00:0x blackout check (off-by-one-minute vs the literal "00:05" inclusive wording, immaterial on D1) |
| 4 | High | Approved loss-limit contract absent | **RESOLVED** (1 framework-standard caveat) | `QM_KillSwitchInit(..., 2.5, 5.0, 1.0)` sets daily=2.5%, portfolio DD=5.0%, cap=1.0%; 2.0% entry halt implemented in `Strategy_NoTradeFilter`. Caveat: portfolio-DD is enforced via the framework's cross-EA signal-file mechanism, which is inert for a single-EA backtest — this is a standing framework property, not an EA-specific defect |
| 5 | High | Producer result blocked, no smoke evidence | **UNRESOLVED** | Ad-hoc compile was correctly refused (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, active live factory `terminal64.exe`), so no fresh smoke exists yet. Tracked `.ex5` predates this remediation (last touch: pump auto-commit `bfd467bc6`, not the source fix). This is an evidence-gate, not a source defect — it must be closed by a governed factory compile+smoke, not waived |
| 6 | High | No committed identity for source/binary | **RESOLVED for source** | `.mq5`/`SPEC.md`/setfiles tracked and clean at HEAD; `.ex5` itself is stale relative to the fixed source (see #5) |
| 7 | Medium | Entry-only filters could suspend protective management/exits | **RESOLVED** | `OnTick` runs `ManageOpenPosition`/`ExitSignal` before the news gate, `NoTradeFilter`, and `IsNewBar` |

## Disposition

Code-level remediation is genuine and matches the approved card for all Critical/High source
findings. The task cannot advance past REVIEW for two independent reasons: (a) the mandatory
Codex acceptance gate for Gemini-originated code has not run on this remediation, and (b) finding
#5 (fresh compile + smoke evidence bound to the remediated source) is still open. Do not enqueue
for pipeline handoff until a governed factory build produces a fresh `.ex5` hash-bound to the
current source and a non-blocked smoke report.
