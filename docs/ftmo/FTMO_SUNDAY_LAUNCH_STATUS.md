# FTMO Sunday launch status — representative Demo generation starting Sunday 2026-09-27 (living, OWNER §Y)

Authority: OWNER-DEC-FTMO-FINAL-MEGA-20260921 (`decisions/2026-09-21_owner_ftmo_final_mega_prompt_sunday_demo.md`). Fable launches
autonomously when the critical preflight checks are green; the sole mandatory OWNER approval remains the paid FTMO Challenge purchase.
Updated by Fable at every material change; last update **2026-09-21 18:4xZ**.

## §Y fields

| Field | Status 2026-09-21 18:4xZ | Evidence |
|---|---|---|
| CODEX_PLAN | **UPGRADED = pro** (was prolite) | `docs/ops/evidence/2026-09-21_ftmo_final_mega_prompt/README.md` §1 |
| CODEX_QUOTA_STATE | weekly window 0 % used, reset 2026-09-28T17:57Z; budget line re-anchored at 0 %; 5-hour window not reported by the endpoint; card-build pacer disabled | same |
| SUNDAY_DEMO_READY | **NO** (critical items open: kill-switch governed initializer, demo-day retro audit, genesis manifest + preflight tooling, sleeve attribution) | this table |
| SUNDAY_FTMO_BOOK | planned = incumbent D2g6 six sleeves (13213 USDJPY H1 @0.15625 %, 10706 GBPUSD H1, 10700 XAUUSD H1, 11422 USDCAD D1, 10403 XAUUSD D1, 41219 XAUUSD D1 @0.3125 % each) with the KS initializer applied; no roster change resolved | `docs/ftmo/FTMO_BOOK_CURRENT.md` v2 |
| SLEEVE_COUNT | 6 | |
| TOTAL_BOOK_RISK | 1.71875 % | |
| P_FIRST_NET_FTMO_PAYOUT_LCB | **0.8668** (financed; unfinanced reference 0.9194) | `2026-09-21_ftmo_book_sim_v1_financed/` |
| P_CHALLENGE_PASS | 0.9516 | |
| MEDIAN_CHALLENGE_DAYS | 289 bd (p10 121 / p90 647) | |
| MEDIAN_FIRST_PAYOUT_DAYS | 489 bd end-to-end (p10 254 / p90 909); 15 bd after funding | |
| DAILY_LOSS_BREACH_PROB | 0.0 | |
| MAX_LOSS_BREACH_PROB | 0.0202 (phase 1) | |
| DEPENDENCE_HIGHEST_CLUSTER | {10403, 10700, 41219} XAUUSD — activity cluster (position overlap 39 %), not a tail cluster (lower-tail co-exceedance 0) | `FTMO_BOOK_DEPENDENCE_MATRIX_financed.md` |
| KILL_SWITCH | **BLOCKED** — deployed D2g6 sleeves run anchor_offset 0 / raw equity / no book tag (diagnosis 4fd8222f); governed initializer = Codex `d6189118` IN_PROGRESS (prio 86, exempt) | `2026-09-21_4fd8222f_ftmo_d2g6_kill_switch_anchor_diagnosis.md` |
| ROLLOVER | **BLOCKED** — Prague-calendar helper + KS_DAY_ROLLOVER event part of `d6189118`; runtime + rollover-event + Daily-Loss-anchor + book-generation-identity proofs after deployment | |
| HARNESS_V2 | **IN_PROGRESS** — Codex `7088da77` (prio 84, exempt) incl. §L golden test vs MT5 Every Real Tick | |
| NEWS_TIME_ARCHIVE | **IN_PROGRESS** — Codex `a36a5983` (prio 82, exempt); impact bound pending | |
| GENESIS_MANIFEST | **BLOCKED** — tooling ticket `94a15624` TODO (prio 72, exempt) | |
| FTMO_BOOK_INCUMBENT | D2g6 = PRE_SUNDAY_LIVE_TRIAL since 2026-09-18 04:50Z (3.5 validation days, not representative, pulse WARN ks_day_anchor_missing 0/6) | `D:/QM/reports/state/ftmo_demo_cycle.json`, `ftmo_trial_pulse.json` |
| FTMO_BOOK_SHADOW | = incumbent (no resolved addition); shadow candidate 11708 EURUSD D1 | `FTMO_BOOK_CURRENT.md` §2 |
| SHADOW_BOOK_BEST_PENDING_SLEEVE | 11708 EURUSD D1 — SHADOW_BOOK, financed marginal LCB ≈ 0 to +0.01 (unresolved) | `2026-09-21_ftmo_11708_sign_change_reconciliation/` |
| 11708_SIGN_FLIP | **EXPLAINED** (EXPECTED_MODEL_IMPROVEMENT; the +0.020 was unfinanced 1k-path noise; old −0.028 was a joint add with 11910 on a shorter window) | same |

## Go / No-Go checklist (OWNER §R) — current state

| Area | Check | State | Owner / ticket |
|---|---|---|---|
| CODE/ARTIFACT | all six EAs compile 0 errors / 0 warnings against the new KS include | RED (awaiting d6189118 build_check) | Codex d6189118 → Fable deploy |
| CODE/ARTIFACT | exact EX5 + setfile binding, magic registry clean, no drift | GREEN today for the running D2g6 (alias receipt 2026-09-18 re-verified by 4fd8222f); must be re-bound after the KS rebuild | genesis manifest 94a15624 |
| ACCOUNT RISK | governor, Daily-Loss anchor, Prague rollover, Max-Loss, combined open risk, KS tested, book-generation identity | RED (d6189118 + runtime proofs) | Codex d6189118 → Fable |
| EXECUTION | spread/commission realistic, no unrealistic fill dependency, OCO verified, calendars/DST/news valid | AMBER — commission/financing modelled (financed run); news archive DST audit open (a36a5983); OCO not relevant to the six (no bracket EA in the roster) | a36a5983 |
| PORTFOLIO | dependence matrix current, weights intentional, no duplicate exposure, XAU cluster understood, first-passage current | GREEN (financed re-run 2026-09-21) | Fable |
| OPERATIONS | sleeve P&L attribution, logs, recovery procedure, demo account clean before attach, post-attach verification | RED (attribution 74c41987; account-clean + post-attach = launch-day steps) | Codex 74c41987 → Fable |
| DEMO DAYS | retro-audit classification of the 2026-09-18..27 days (BEHAVIOR_IDENTICAL / POTENTIALLY_DIFFERENT / MATERIALLY_INVALID) | RED (4505b206 TODO) | Codex 4505b206 |

## Next five actions (ordered)

1. Codex `a36a5983` → `d6189118` → `7088da77` run in the orchestration lane now; Fable reviews each on return (cross-vendor), then deploys the KS
   rebuild to the demo under production discipline (readback, backup, hash binding, rollback, post-change verification, receipt) and collects the
   rollover-event proof at the next Prague midnight.
2. Route `3fae43b2` (simulator confidence), `4505b206` (demo-day retro audit), `74c41987` (attribution), `94a15624` (genesis + preflight) as the lane frees.
3. Harness v2 golden test result decides whether the NY/index cash-session family sweep (the STRONGEST_MISSING_BOOK_BEHAVIOR) runs before Sunday.
4. Saturday 2026-09-26: freeze the Sunday roster, build the genesis manifest, run the preflight; Sunday: clean account, attach, post-attach verification,
   genesis launch timestamp, 14-day clock starts.
5. Weekly review Friday: are we closer to a payout or merely busier (OWNER §89).
