# Claude review_ea — QM5_36001 / QM5_36004 (Gemini-built, remediation verification)

**Router tasks:** `af9af332-6c97-4abd-a319-4373c82e0844` (QM5_36004),
`2a6ee952-e292-4ace-a5d8-01c6340da256` (QM5_36001)
**Reviewer:** Claude (headless orchestration cycle), 2026-08-23
**Reason:** `codex_review_required_for_gemini_code`, `source_verdict: REMEDIATED_AWAITING_CODEX_REVIEW`

## Scope

On 2026-08-18 Codex reviewed the original Gemini builds of both EAs
(`docs/ops/evidence/80b2cb2a_qm5_36004_gemini_build_codex_review_2026-08-18.md`,
`docs/ops/evidence/d47d0803_qm5_36001_gemini_build_codex_review_2026-08-18.md`)
and returned `CHANGES_REQUIRED` with 6-7 findings each. Gemini remediated
(commit `1c8d911f9`, "remediate QM5_36001 and QM5_36004 NNFX implementations
per Codex review") and a follow-up fixed a setfile/QQE-warmup bug (commit
`73acf69db`). The router routed both back to claude to verify the
remediation before Codex re-reviews. Per CLAUDE.md hard rules this is the
Claude-side pass; it does **not** substitute for the mandatory Codex review —
both tasks stay in `REVIEW`.

I delegated the two per-finding verifications to independent subagents, each
given the exact original Codex finding text and told to check every one
against the current file with line citations. Summarized below; full
per-finding reasoning is in the subagent transcripts (referenced by task
name in this doc's git history / journal, not reproduced verbatim here).

## QM5_36001 — NNFX Classic (McGinley/SSL/Vortex/WAE/DeMarker)

| # | Codex finding (2026-08-18) | Verdict |
|---|---|---|
| 1 | CRITICAL: full-position TP instead of 50% partial + BE runner | **FIXED** — `Strategy_ManageOpenPosition` now calls `QM_TM_PartialClose(ticket, volume*0.5, QM_EXIT_PARTIAL)` at +1 ATR, then moves SL to BE; broker TP removed (`req.tp=0.0`) |
| 2 | HIGH: SSL persistent state treated as crossover | **FIXED** — new `Strategy_SSLCross` compares state at shift vs shift+1, only fires on the transition bar |
| 3 | HIGH: DeMarker static threshold instead of crossover exit | **FIXED** — exit now compares `demarker_1` vs `demarker_2`, requires the extreme to be newly crossed |
| 4 | HIGH: WAE short gate substitutes a signed/directional test for the card's unsigned `WAE > ExplosionLine` | **NOT FIXED as literally stated, but likely correct** — the refactored short condition (`(macd_prev-macd_now)*sens > threshold`) is mathematically identical to the flagged version; it is still directional. Directional WAE (bull/bear split) is standard Waddah Attar Explosion semantics and matches the card's own §2 "WAE_Bull" framing, so this may be a correct implementation and an imprecise original finding rather than an open defect. **Flagging for Codex to confirm intended WAE semantics before treating as closed** — not resolving it myself since it's the one point where the original review and the implementation still disagree on paper. |
| 5 | HIGH: GMT rollover in broker time; no local loss-limit contract | **FIXED** — rollover blackout now uses `QM_BrokerToUTC(TimeCurrent())`; `OnInit` calls `QM_KillSwitchInit(qm_ea_id, magic, 2.5, 5.0, 1.0)` (2.5% daily / 5.0% portfolio DD, matches card §4.2); 2.0% daily entry halt added to `Strategy_NoTradeFilter`. Minor: entry-halt/daily-stop use `ACCOUNT_EQUITY` (includes floating P&L) vs the card's "realized loss" wording — conservative, not a defect. |
| 6 | MEDIUM: no-entry filters suspended position management | **FIXED** — `OnTick` reordered so `Strategy_ManageOpenPosition()` and the rule-exit run before the news gate / `Strategy_NoTradeFilter()` |

New issues from the full-file read: none blocking. All 16 `strategy_*` inputs
have real use sites (no unwired-input defect). Setfiles: `RISK_FIXED=1000`,
`RISK_PERCENT=0`, `build_hash` now stamped (was "pending"). Minor
non-blocking notes: a second partial could theoretically ladder if
`QM_TM_MoveSL` fails right after a successful partial (requires a
double-failure, edge case); min-lot positions skip the partial and go
straight to BE (inherent lot-step limitation).

**QM5_36001 verdict: PASS-leaning**, contingent on Codex confirming finding 4
(WAE directional semantics) is intended, not a residual defect.

## QM5_36004 — NNFX ALMA/QQE/DPO/VFI

| # | Codex finding (2026-08-18) | Verdict |
|---|---|---|
| 1 | CRITICAL: full-position TP instead of 50% partial + BE runner | **FIXED** — same partial-close + BE mechanism as QM5_36001, `req.tp=0.0` |
| 2 | CRITICAL: QQE persistent state treated as crossover | **FIXED** — new `Strategy_QQECross` requires a transition (`state_now==1 && state_prev!=1`, mirrored for short) at shift 1 vs shift 2; commit `73acf69db` additionally fixed a warmup-loop indexing bug (D10) so the underlying series is correctly oriented before the crossover check runs |
| 3 | HIGH: GMT rollover in broker time | **FIXED** — `QM_BrokerToUTC(TimeCurrent())` |
| 4 | HIGH: no local loss-limit contract | **FIXED, with one caveat** — 2.0% daily entry halt and `QM_KillSwitchInit(..., 2.5, 5.0, 1.0)` added (matches card). Caveat: the 5.0% portfolio-DD stop is enforced only via the external operator signal-file channel and does not fire inside the strategy tester (`if(!is_tester)` in `QM_KillSwitch.mqh`) — this is the standard QM portfolio-DD pattern used fleet-wide, not specific to this EA, so not treated as a new defect, but the card's "5.0% total-drawdown stop" is plumbed rather than self-enforced in backtest. |
| 5 | HIGH: build result `blocked_reason` non-empty, no smoke evidence | **NOT FIXED** — the remediation's own evidence doc states compilation was refused (`LIVE_FACTORY_AD_HOC_COMPILE_REFUSED`, live-factory terminal64.exe was active at the time). No recompile, no smoke report exists after the remediation either. |
| 6 | HIGH: no committed identity binding source/binary | **FIXED for source, NOT fixed for binary** — `.mq5` and `.set` files are committed with real `build_hash` values at `1c8d911f9`/`73acf69db`. The `.ex5` on disk is dated 2026-08-17 23:23 and last touched by a pre-remediation pump auto-commit (`bfd467bc6`) — **it does not contain either the TP1/partial-close fix or the QQE-crossover fix.** Because finding 5's compile was refused, there was never a build that could have updated it. |
| 7 | MEDIUM: no-entry filters suspended position management | **FIXED** — `OnTick` reordered, same pattern as QM5_36001 |

New issues from the full-file read: all 13 `strategy_*` inputs wired, no
look-ahead, magic/risk/news wiring correct. The blocking new issue is the
stale binary above — this is the same "stale `.ex5` voids healthy backtests"
class from `project_qm_stale_ex5_voids_healthy_backtests_2026-08-17`
(predicate is build date, not size): **any backtest run against this EA
right now tests the pre-remediation, defective binary**, regardless of how
correct the current `.mq5` source is.

**QM5_36004 verdict: RECYCLE-leaning.** Source-level remediation for
findings 1, 2, 3, 6 (source only), 7 is genuinely correct, and finding 4 is
substantively addressed. But the deliverable is not shippable: finding 5
(no smoke evidence / build blocked) is still open, and as a direct
consequence the committed `.ex5` is the stale pre-fix binary. This needs a
recompile in an OFF-window / `COMPILE_EA` queue slot, a smoke run, and a
fresh `build_hash`/`ex5_sha256` before it can be re-reviewed as shippable —
the source review itself would likely be PASS once that happens.

## Disposition

Both tasks move to `REVIEW`, not `APPROVED`/`PIPELINE`. Codex review remains
mandatory before either advances; per hard rule I did not self-approve or
move either to PIPELINE. QM5_36004 additionally needs a rebuild (compile +
smoke) before any further review is useful — flagging that explicitly so the
next actor doesn't re-review stale source-vs-binary state.
