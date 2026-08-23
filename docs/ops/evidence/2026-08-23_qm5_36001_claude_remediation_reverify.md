# Claude re-verification: QM5_36001 remediation

- Review task: `2a6ee952-e292-4ace-a5d8-01c6340da256`
- Prior Codex review: `docs/ops/evidence/d47d0803_qm5_36001_gemini_build_codex_review_2026-08-18.md` (CHANGES_REQUIRED, 6 findings)
- Remediation commit: `1c8d911f9` (`build(ea): remediate QM5_36001 and QM5_36004 NNFX implementations per Codex review`), branch `agents/board-advisor`
- Remediation self-report: `docs/ops/evidence/3c1da904_qm5_36001_build_ea_result_2026-08-23.md`
- Reviewed source: `framework/EAs/QM5_36001_nnfx-classic-mcginley-ssl-wae/QM5_36001_nnfx-classic-mcginley-ssl-wae.mq5` at current HEAD
- Approved card: `D:/QM/strategy_farm/artifacts/cards_approved/QM5_36001_nnfx-classic-mcginley-ssl-wae.md`
- **Verdict: CHANGES_STILL_REQUIRED — remain in REVIEW; no pipeline handoff. All 6 source findings independently verified resolved against the approved card; the open item is build/smoke evidence: the tracked `.ex5` is still bound to the pre-remediation commit `2ad86abe7`, not to the fixed source.**

Per hard rule (Gemini-originated code requires mandatory Codex review before acceptance),
this task stays in REVIEW regardless of verdict; Claude does not self-approve or advance
gemini-originated builds to PIPELINE.

## Per-finding re-verification (independent read of current .mq5, not the self-report)

| # | Severity | Original finding | Status | Evidence |
|---|----------|-------------------|--------|----------|
| 1 | Critical | Full-position TP, no runner survives | **RESOLVED** | `req.tp=0.0`; `Strategy_ManageOpenPosition` calls `QM_TM_PartialClose(ticket, volume*0.5, QM_EXIT_PARTIAL)` at +1.0 ATR (`be_trigger = tp_atr_mult*atr_1`), then `QM_TM_MoveSL` to BE+1pip; `sl_not_breakeven` guard prevents re-fire; fallback moves SL to BE even if partial-close/halving fails (safe degenerate case) |
| 2 | High | SSL persistent state substituted for crossover | **RESOLVED** | `Strategy_SSLCross(1)` compares shift1 vs shift2 `SSLState`, returns non-zero only on a genuine transition; entry gates on `ssl_cross`, not raw state |
| 3 | High | DeMarker level threshold substituted for crossover | **RESOLVED** | `Strategy_ExitSignal` compares consecutive bars: long `demarker_1>=0.70 && demarker_2<0.70`; short `demarker_1<=0.30 && demarker_2>0.30` (plus SSL flip) — true crossover |
| 4 | High | WAE short gate uses undocumented directional substitution vs card | **RESOLVED**, one caveat | `Strategy_WAEPass` now symmetric: long `(macd_now-macd_prev)*sens > Max(explosion,deadzone)`, short `(macd_prev-macd_now)*sens > threshold` — the old asymmetric "must be negative" substitution is gone. Caveat: the card only writes `WAE_Bull` explicitly and never spells out `WAE_Bear`; the fix relies on the canonical symmetric WAE interpretation, which is defensible but not literally spelled out in the card text. Not a functional defect — flagging for completeness, not blocking |
| 5 | High | GMT rollover in broker time + loss-limit contract absent | **RESOLVED**, two minor caveats | `QM_BrokerToUTC(TimeCurrent())` used for rollover blackout (off-by-one-minute at the 00:05 boundary vs literal card wording, immaterial on D1); 2.0% daily entry halt implemented; `QM_KillSwitchInit(id, magic, 2.5, 5.0, 1.0)` — signature-verified against `QM_KillSwitch.mqh` as `(ea_id, magic, daily_loss_halt_pct, portfolio_dd_halt_pct, per_trade_risk_cap_pct)`, so 2.5%/5.0% match card §4.2. Daily halt is equity-based (includes unrealized) vs card's "realized" wording — functions as intended circuit breaker regardless |
| 6 | Medium | Entry-only filters could suspend protective management/exits | **RESOLVED** | `OnTick` runs `Strategy_ManageOpenPosition` and `Strategy_ExitSignal`/close before the news gate and `Strategy_NoTradeFilter` |

## Disposition

All 6 source findings are genuinely resolved against the approved card, independently verified
(framework primitive signatures checked, not just the self-report). This EA's remediation is code-
complete. Same structural gap as QM5_36004, however: the tracked `.ex5` at HEAD is still bound to
commit `2ad86abe7` (the pre-remediation build referenced in the original Codex review), not to the
fixed source in `1c8d911f9`. No fresh compile/smoke evidence exists for the remediated code, and
ad-hoc compilation is correctly governance-refused while the live factory is running. Do not enqueue
for pipeline handoff until a governed factory build produces a fresh `.ex5` hash-bound to the current
source and a non-blocked smoke report — consistent with the same standard applied to QM5_36004.
