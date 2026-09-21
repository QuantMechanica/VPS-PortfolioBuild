# OWNER-DEC-FTMO-FINAL-MEGA-20260921 — FINAL FTMO MEGA Master Prompt: Sunday 2026-09-27 Demo generation, Codex plan upgraded, book artifacts (OWNER 2026-09-21)

- **Status:** CURRENT OWNER DIRECTIVE, highest precedence (the "CURRENT OWNER SUPERSEDING UPDATE" section wins over every
  older page, handoff, standing authority, routing table or quota assumption that conflicts with it).
- **Verbatim:** `docs/ops/evidence/2026-09-21_ftmo_final_mega_prompt/owner_directive_verbatim.md`
  (sha256 `edc5af61f2f574719a5c2cdaacf92b64e4f05b8e39d10c7d36bf89868d4d2559`, 4185 lines; sections A–Z are new, the
  numbered §1–§95 body restates OWNER-DEC-FABLE-FULL-EXECUTIVE-AUTHORITY-20260917 and stays binding where not superseded).
- **Supersedes / extends:** `2026-09-21_owner_ftmo_book_portfolio_not_hero_ea.md` (A–I restate it), `2026-09-17_owner_fable_full_executive_authority.md`
  (authority unchanged; sole mandatory OWNER approval stays the paid FTMO Challenge purchase), the OWNER 2026-09-13 Codex
  budget-line assumption of a scarce "prolite" plan (section O), the 2026-09-18 D2g6 demo cycle as the representative
  Demo (sections P–T).
- **Recorded by:** Fable 5.1, 2026-09-21 ~18:1xZ.

## Binding changes (new vs the 2026-09-21 morning directive)

1. **§J — H-V4 / QM5_41485 is a permanent negative lineage**, tag `PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE`; never revived
   without new evidence / new lineage. Applied: card front matter (repo + `D:` mirror) carries `negative_lineage_tag`.
2. **§K — Harness v2 is a prescreen, not an economic validator.** Cell states are exactly `CLEAR_REJECT` / `WORTH_MT5_TEST` /
   `UNKNOWN`; it never emits `ECONOMICALLY_VALIDATED`. **§L — golden test** against MT5 Every Real Tick on known difficult
   days (2024 release days that broke H-V4, non-news days, spread expansions, gap-through, one-sided, dual-trigger/OCO,
   DST weeks) comparing entry/exit time, direction, prices and R per trade is acceptance-blocking. Applied: appended as
   requirements to Codex ticket `7088da77`.
3. **§M — news/time archive audit** must bound the impact (years, event classes, symbols, strategies, Q-gates, FTMO
   sleeves); affected binding evidence is remeasured or explicitly marked non-binding; old evidence preserved.
   Ticket `a36a5983`.
4. **§N — Demo kill-switch / Prague rollover = pre-Sunday P0**: implementation → tests → independent review → deployment →
   runtime proof → rollover-event proof → Daily-Loss-anchor proof → book-generation-identity proof; the current Demo days
   are retro-audited and classified `BEHAVIOR_IDENTICAL` / `POTENTIALLY_DIFFERENT` / `MATERIALLY_INVALID`; structurally
   invalid days are not counted toward 14. Ticket `d6189118` (implementation); retro-audit = new ticket (see evidence README).
5. **§O — Codex plan upgraded and freshly reset.** Verified at runtime 2026-09-21T17:57Z (`quota_pull.py` after a token
   refresh): `plan_type = pro` (was `prolite`), weekly window `used_percent 0`, `reset_at 2026-09-28T17:57:49Z`. The quota
   governor was re-run, the Codex budget line re-anchored at 0 % (`codex_budget_line.py --activate`, slope 0.55 %/h to 92 %
   at reset), the three critical-path tickets marked `codex_budget_line_exempt` and re-prioritised in the directive's order
   (KS 86 > harness v2 84 > news audit 82). Codex priority list §O 1–10 is the dispatch order until Sunday; low-value backlog
   (card builds, census) only afterwards. The **card-build fleet pacer** (`QM_StrategyFarm_CodexFleetPacer`, prompt rotation
   focus_fx / focus_commodity / focus_backlog = "more certified sleeves") is **disabled** for the pre-Sunday window so it
   cannot spend the fresh 5-hour windows on §O-rank-10 work; re-enable (`Enable-ScheduledTask`) once §O 1–9 are in REVIEW.
6. **§P–§T — the next FTMO Demo account starts Sunday 2026-09-27** as the formal representative account-level experiment
   (launch date, not a quality waiver; no OWNER approval needed for the launch). At launch: immutable
   `FTMO_DEMO_GENESIS_MANIFEST` (§Q), Go/No-Go checklist (§R), the current Demo (D2g6 since 2026-09-18) is reclassified
   `PRE_SUNDAY_LIVE_TRIAL` (§S) and its days are not merged into the Sunday generation; the 14-calendar-day clock starts
   at the Sunday launch timestamp (§T).
7. **§F/§G — Incumbent + Shadow book.** `FTMO_BOOK_INCUMBENT` (frozen roster under Demo) and `FTMO_BOOK_SHADOW` (best
   evidence-supported next composition), candidate actions `ADD_NOW / QUEUE_FOR_NEXT_DEMO / SHADOW_BOOK / HOLD / REJECT`,
   `DEMO_RESET_COST` in roster decisions; `FTMO_BOOK_CURRENT.md` + `ftmo_book_current.json` expose INCUMBENT, SHADOW,
   `DELTA_SHADOW_VS_INCUMBENT`, `STRONGEST_MISSING_BOOK_BEHAVIOR`; Mission Control surfaces them.
8. **§V — 11708 sign change** (negative marginal LCB in the 2026-09-18 quicklook vs positive in the 2026-09-21 account
   simulator) must be reconciled (OLD_METHOD / NEW_METHOD / INPUT_STREAM / RISK_WEIGHT / DEPENDENCE_MODEL / FIRST_PASSAGE
   differences, WHY_SIGN_CHANGED, `EXPECTED_MODEL_IMPROVEMENT` vs `SIMULATOR_DEFECT`) before any roster action uses 11708.
9. **§W — free factory capacity is not failure**; do not reopen prescreen-rejected cells for utilisation. **§X — cheap
   one-time taxonomy of the compile-fail pool** (REAL_EA_DEFECT / SHARED_FRAMEWORK_DEFECT / SETFILE_DEFECT /
   BUILD_BINDING_DEFECT / STALE_HISTORICAL / SUPERSEDED / INFRA / OTHER) to find trapped high-EV FTMO candidates; repair
   systemic + FTMO-critical first.
10. **§Y — pre-Sunday status fields** (CODEX_PLAN, SUNDAY_DEMO_READY, SUNDAY_FTMO_BOOK, SLEEVE_COUNT, TOTAL_BOOK_RISK,
    P_FIRST_NET_FTMO_PAYOUT_LCB, P_CHALLENGE_PASS, MEDIAN_CHALLENGE_DAYS, MEDIAN_FIRST_PAYOUT_DAYS, DAILY/MAX_LOSS_BREACH_PROB,
    DEPENDENCE_HIGHEST_CLUSTER, KILL_SWITCH, ROLLOVER, HARNESS_V2, NEWS_TIME_ARCHIVE, GENESIS_MANIFEST, INCUMBENT, SHADOW,
    SHADOW_BOOK_BEST_PENDING_SLEEVE, 11708_SIGN_FLIP) are reported before launch; Fable launches autonomously when the critical
    preflight checks are green. Living surface: `docs/ftmo/FTMO_SUNDAY_LAUNCH_STATUS.md`.
11. **§Z** — no hero-EA search, no terminal-utilisation / card-count / isolated R-per-day optimisation.

## Pre-Sunday priority order (§U, binding until 2026-09-27)

1 Kill-Switch / Prague rollover · 2 Codex quota/governor refresh (**done 2026-09-21**) · 3 Harness-v2 fidelity · 4 news/time
archive audit · 5 account-simulator confidence · 6 book dependence + risk allocation · 7 sleeve-level P&L attribution ·
8 credible Shadow-Book candidates · 9 Genesis Manifest + deployment tooling · 10 non-critical backlog.

## Invariants retained

Evidence immutability, no secrets, licence/security review, bounded risk, FTMO/broker compliance, HR14 (no ML in the EA
runtime), production discipline for live/demo changes, §68A versioned gate contracts. Sole mandatory OWNER approval: paying
for a paid FTMO Challenge.
