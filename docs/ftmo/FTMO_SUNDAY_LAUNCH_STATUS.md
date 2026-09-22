# FTMO Sunday launch status — representative Demo generation starting Sunday 2026-09-27 (living, OWNER §Y)

Authority: OWNER-DEC-FTMO-FINAL-MEGA-20260921 (`decisions/2026-09-21_owner_ftmo_final_mega_prompt_sunday_demo.md`). Fable launches
autonomously when the critical preflight checks are green; the sole mandatory OWNER approval remains the paid FTMO Challenge purchase.
Updated by Fable at every material change; last update **2026-09-21 20:5xZ** (full-throttle override; attribution accepted; families B1/B2/B3/C1 all without survivors).

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
| KILL_SWITCH | **BLOCKED** — deployed D2g6 sleeves run anchor_offset 0 / raw equity / no book tag (diagnosis 4fd8222f) **and** the day key froze over the weekend (TimeCurrent-based; Sunday restarts restored stale Friday anchors, retro audit 4505b206); governed initializer = Codex `d6189118` IN_PROGRESS (prio 86, exempt; weekend requirement 8 added) | `2026-09-21_4fd8222f_ftmo_d2g6_kill_switch_anchor_diagnosis.md` |
| ROLLOVER | **BLOCKED** — Prague-calendar helper + KS_DAY_ROLLOVER event part of `d6189118`; runtime + rollover-event + Daily-Loss-anchor + book-generation-identity proofs after deployment | |
| HARNESS_V2 | **IN_PROGRESS** — Codex `7088da77` (prio 84, exempt) incl. §L golden test vs MT5 Every Real Tick | |
| NEWS_TIME_ARCHIVE | **IN_PROGRESS** — Codex `a36a5983` (prio 82, exempt); impact bound pending | |
| GENESIS_MANIFEST | **TOOLING READY** (Codex `94a15624` APPROVED: `genesis_manifest.py build/verify/seal-launch`, `sunday_preflight.py`; D2g6 rehearsal verify PASS 0 drift, preflight NO_GO 17 GREEN / 8 RED / 3 NOT_CHECKABLE as expected for the pre-Sunday trial) — the Sunday manifest itself is built Saturday per the runbook | `docs/ftmo/genesis/`, `2026-09-21_ftmo_genesis_manifest_tooling/` |
| DEMO_ACCOUNT_IDENTITY (runbook §1) | **DECIDED A** (OWNER 2026-09-21 ~19:55Z, receipt `46ea4491`, Claude execution task `90847e73`): fresh FTMO Free-Trial account. **Credentials arrive Sunday 2026-09-27 (OWNER creates the account that morning; needed by 12:00Z):** login/server/password into `.private/secrets/ftmo_demo_gen2_20260927.md` (git-ignored) | runbook §1, §3 timing |
| DEMO_GEN1_STATUS (PRE_SUNDAY_LIVE_TRIAL) | ENDED_BY_BROKER 2026-09-21T23:02Z: FTMO cancelled the XAUUSD stops and force-closed USDCAD (CLOSED_BY_FTMO), account_trade_allowed=false since (all symbols FULL) - Codex 6fa7831a; trial evidence window 2026-09-18..21; EAs keep running as KS-rehearsal host; Sunday preflight adds account_trade_allowed=true | |
| P80_DAYS_TO_FIRST_NET_PAYOUT (primary KPI) | 1300 calendar days (bd 929, LCB 0.8013); P_PAYOUT_30/45/60/90D = 0; P_PAYOUT_EVER LCB 0.8762; conditional p50 682 cd — Codex e5cc5e95 accepted; venue costs UNMEASURED (73434cab) | |
| FTMO_BOOK_INCUMBENT | D2g6 = PRE_SUNDAY_LIVE_TRIAL since 2026-09-18 04:50Z (3.5 validation days, not representative, pulse WARN ks_day_anchor_missing 0/6) | `D:/QM/reports/state/ftmo_demo_cycle.json`, `ftmo_trial_pulse.json` |
| FTMO_BOOK_SHADOW | **D2g6 + 12710 + 20266 XTIUSD D1** (2.34 %): LCB 0.8805 vs 0.8648, first payout 460 vs 492 bd, max-loss 0.017 — pending symbol-input rebuild + identity proof (Codex `273f2de8`); Sunday only if the proof lands Saturday, else next generation | `FTMO_BOOK_CURRENT.md` §2, pool sweep evidence |
| SHADOW_BOOK_BEST_PENDING_SLEEVE | 12710 XTIUSD D1 commodity-tsmom-12m-atr (+0.025 marginal, 7 of 8 years positive; class B rebuild pending) ahead of 20266; 11708 stays SHADOW_BOOK-neutral | pool sweep README |
| 11708_SIGN_FLIP | **EXPLAINED** (EXPECTED_MODEL_IMPROVEMENT; the +0.020 was unfinanced 1k-path noise; old −0.028 was a joint add with 11910 on a shorter window) | same |

## Go / No-Go checklist (OWNER §R) — current state

| Area | Check | State | Owner / ticket |
|---|---|---|---|
| CODE/ARTIFACT | all six EAs compile 0 errors / 0 warnings against the new KS include | RED (awaiting d6189118 build_check) | Codex d6189118 → Fable deploy |
| CODE/ARTIFACT | exact EX5 + setfile binding, magic registry clean, no drift | GREEN today for the running D2g6 (alias receipt 2026-09-18 re-verified by 4fd8222f); must be re-bound after the KS rebuild | genesis manifest 94a15624 |
| ACCOUNT RISK | governor, Daily-Loss anchor, Prague rollover, Max-Loss, combined open risk, KS tested, book-generation identity | RED (d6189118 + runtime proofs) | Codex d6189118 → Fable |
| EXECUTION | spread/commission realistic, no unrealistic fill dependency, OCO verified, calendars/DST/news valid | AMBER — commission/financing modelled (financed run) but **venue spread unmeasured for 4 of 6 symbols and the book is cost-sensitive (LCB 0.87 → 0.61 under +1 bps/+2 USD/lot)** → Codex `73434cab` VENUE_ADJUSTED; news archive DST audit open (a36a5983); OCO not relevant to the six | a36a5983, 73434cab |
| PORTFOLIO | dependence matrix current, weights intentional, no duplicate exposure, XAU cluster understood, first-passage current | GREEN (financed re-run 2026-09-21) | Fable |
| OPERATIONS | sleeve P&L attribution, logs, recovery procedure, demo account clean before attach, post-attach verification | AMBER — attribution tool delivered and accepted (74c41987: reconciliation to 0.00 over 4 days, Mission Control block); account-clean + post-attach = launch-day steps | Fable |
| DEMO DAYS | retro-audit classification of the 2026-09-18..27 days (BEHAVIOR_IDENTICAL / POTENTIALLY_DIFFERENT / MATERIALLY_INVALID) | GREEN for 09-18..21 (1 INVALID / 2 POTENTIALLY_DIFFERENT / 1 IDENTICAL; 2 valid completed days; all PRE_SUNDAY_LIVE_TRIAL, not merged) — re-run for 09-22..26 before launch | Codex 4505b206 APPROVED (`2026-09-21_ftmo_demo_day_retro_audit/`) |
| CODE/EXECUTION | live news feed binding: every sleeve preset points at the live calendar (D:/QM/data/news_calendar + FILE_COMMON, mtime < 24 h), never a static backtest CSV | RED (preflight row to be built; critique cb0eb674 #1) | 94a15624 |
| OPERATIONS | terminal AutoTrading flag: TERMINAL_TRADE_ALLOWED == 1 and trading_allowed == true on all six charts after attach | RED (launch-day proof; critique #2) | 94a15624 → Fable |
| ACCOUNT RISK | weekend non-tick rollover proof: KS_DAY_ROLLOVER after a no-tick boundary (TimeCurrent froze 09-18 23:54:59 → Sunday restarts restored stale anchors) | RED (d6189118 req 8; critique #3) | Codex d6189118 → Fable |
| OPERATIONS | server-request anomaly thresholds: pulse WARN 200 / LIMIT 500 + 60-s burst alarm (> 25 requests) — FTMO's 2,000 is the termination line, not a monitor | RED (d6189118 req 9; critique #4) | Codex d6189118 |
| ACCOUNT RISK | clean initial account before attach: balance == 100000.00, PositionsTotal() == 0, OrdersTotal() == 0 | RED (launch-day step; critique #5; decision A = fresh account, credentials pending) | Fable (task 90847e73) |
| CODE/ARTIFACT | sleeve attribution pre-launch dry-run: Sum(sleeve P&L) == account P&L to 0.00 | RED (74c41987; critique #6) | Codex 74c41987 → Fable |
| PROOF CHAIN | KS launch proof chain (critique Q5): build_check receipt + installed .ex5 sha → KS_DAY_ANCHOR_SET / KS_BOOK_TAG_SET per magic → ks_state readback → KS_DAY_ROLLOVER at the first Prague midnight without ticks | RED (d6189118 req 10) | Codex → Fable |

## Next five actions (ordered)

1. Codex `a36a5983` → `d6189118` → `7088da77` run in the orchestration lane now; Fable reviews each on return (cross-vendor), then deploys the KS
   rebuild to the demo under production discipline (readback, backup, hash binding, rollback, post-change verification, receipt) and collects the
   rollover-event proof at the next Prague midnight.
2. Route `3fae43b2` (simulator confidence), `4505b206` (demo-day retro audit), `74c41987` (attribution), `94a15624` (genesis + preflight) as the lane frees.
3. Harness v2 golden test result decides whether the NY/index cash-session family sweep (the STRONGEST_MISSING_BOOK_BEHAVIOR) runs before Sunday.
4. Saturday 2026-09-26: freeze the Sunday roster, build the genesis manifest, run the preflight; Sunday: clean account, attach, post-attach verification,
   genesis launch timestamp, 14-day clock starts.
5. Weekly review Friday: are we closer to a payout or merely busier (OWNER §89).
