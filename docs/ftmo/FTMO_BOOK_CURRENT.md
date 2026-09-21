# FTMO_BOOK - current (v2, 2026-09-21 18:3xZ)

**Authority:** OWNER-DEC-FTMO-FINAL-MEGA-20260921 (`decisions/2026-09-21_owner_ftmo_final_mega_prompt_sunday_demo.md`, sections A-Z) on top of
OWNER-DEC-FTMO-BOOK-PORTFOLIO-20260921. **Machine mirror:** `D:/QM/reports/state/ftmo_book_current.json` (schema `qm.ftmo-book-current/v1`,
Codex writer e5c49db2 + Fable overlay fields `incumbent`, `shadow`, `delta_shadow_vs_incumbent`, `strongest_missing_book_behavior`, `financing`).
**Basis of v2:** the account-level simulator (`tools/strategy_farm/ftmo/book_sim.py`, Codex e5c49db2, accepted 2026-09-21 13:3xZ) re-run by Fable on the
**financed** 2026-09-18 Q08 streams (`docs/ops/evidence/2026-09-21_ftmo_book_sim_v1_financed/`, 5,000 paths, 1008-bd horizon, 20-day blocks, seed 20260921,
window 2019-01-22..2025-11-21 = 1,784 bd). The Codex 2026-09-21 12:00Z base run was UNFINANCED (financing library absent, swap fallback 0) and is
kept as evidence but no longer quoted as the book's headline (`2026-09-21_ftmo_11708_sign_change_reconciliation/README.md` §2.4).
v1 (quicklook + 2026-09-18 first-passage) is preserved in git history (`dfc697a28a`).

## 0. Book status at a glance (OWNER §Y fields, pre-Sunday)

| Field | Value |
|---|---|
| FTMO_BOOK_INCUMBENT | `FTMO_DEMO_BOOK_V3_D2G6_20260918` - six sleeves, 1.71875 % book risk, on the FTMO demo since 2026-09-18 04:50Z = **PRE_SUNDAY_LIVE_TRIAL** (OWNER §S) |
| FTMO_BOOK_SHADOW | = incumbent + nothing resolved. Shadow candidates: 11708 EURUSD D1 (`SHADOW_BOOK`, neutral LCB, +6 % density), no `ADD_NOW` / `QUEUE_FOR_NEXT_DEMO` |
| SUNDAY_FTMO_BOOK (2026-09-27 generation, planned) | the six D2g6 sleeves with the kill-switch governed initializer (d6189118) applied; roster changes only on resolved evidence |
| P_FIRST_NET_FTMO_PAYOUT_LCB (financed) | **0.8668** (P 0.8854; unfinanced would read 0.9194) |
| P_CHALLENGE_PASS / P_VERIFICATION_PASS given challenge | 0.9516 / 0.9775 |
| MEDIAN_CHALLENGE_DAYS / MEDIAN_FIRST_PAYOUT_DAYS | 289 bd phase 1 (p10 121 / p90 647); end-to-end 489 bd (p10 254 / p90 909); first reward 15 bd after funding |
| DAILY_LOSS_BREACH_PROB / MAX_LOSS_BREACH_PROB (phase 1) | 0.0 / 0.0202 |
| DEPENDENCE_HIGHEST_CLUSTER | {10403, 10700, 41219} XAUUSD (position overlap 39 % of the smaller exposure for 10403/41219; loss-day overlap 2.4-2.8x independence; max daily |r| 0.09) |
| STRONGEST_MISSING_BOOK_BEHAVIOR | session-flat, low-overlap, high-density NY / index cash-session sleeve (zero exposure today) - see section 5 |
| 11708_SIGN_FLIP | EXPLAINED / EXPECTED_MODEL_IMPROVEMENT; delta unresolved -> SHADOW_BOOK |

## 1. INCUMBENT = demo roster D2g6 (frozen 2026-09-18; book risk 1.71875 %)

| Sleeve | Symbol / TF | Risk % | Role | Trades (window) | /bd | E[R] | PF | med hold | Q08 stream sha (financed) |
|---|---|---|---|---|---|---|---|---|---|
| QM5_10403 | XAUUSD D1 | 0.3125 | Gold trend (D1 turtle) | 207 | 0.101 | +0.065 | 1.288 | 75.7 h | c225c4d1... |
| QM5_10700 | XAUUSD H1 | 0.3125 | Gold alpha (H1 swing) | 373 | 0.175 | +0.165 | 1.319 | 19.7 h | 5127da4d... |
| QM5_10706 | GBPUSD H1 | 0.3125 | GBP swing alpha (H1, 46 % overnight) | 360 | 0.168 | +0.192 | 1.331 | 7.7 h | 46e0768f... |
| QM5_11422 | USDCAD D1 | 0.3125 | stabilizer (USDCAD D1 trend, low density) | 195 | 0.095 | +0.094 | 1.246 | 41.0 h | 2eddc16d... |
| QM5_13213 | USDJPY H1 | 0.15625 | VELOCITY_SLEEVE (session-flat USDJPY, 0 % overnight) | 1596 | 0.743 | +0.064 | 1.149 | 7.2 h | d4e8d809... |
| QM5_41219 | XAUUSD D1 | 0.3125 | Gold mean-reversion (D1, very low density) | 72 | 0.040 | +0.071 | 1.716 | 48.0 h | 4a748771... |

**Account-level metrics (financed, chronological account path, Prague-midnight anchor, active-MAE open-risk envelope):**

| Metric | Financed (headline) | Unfinanced (Codex 12:00Z run, for reference) |
|---|---|---|
| BOOK_TRADES_PER_DAY / BOOK_ACTIVE_DAYS | 1.336 / 0.868 | same |
| BOOK_R_PER_DAY (sum at 1 %) | 0.108 | 0.131 |
| BOOK_EXPECTED_PROGRESS_USD_PER_DAY | **27.50** | 34.69 |
| BOOK_COST_DRAG_USD_PER_DAY (commission 9,671 + swap -12,822 USD over 1,784 bd) | **12.61** | 5.42 (commission only) |
| BOOK_MAX_DD (historical, USD) | 6,262 | 5,787 |
| P_DAILY_LOSS_BREACH / P_MAX_LOSS_BREACH (phase 1) | 0.0 / 0.0202 | 0.0 / 0.008 |
| P_CHALLENGE_PASS / P_FIRST_NET_FTMO_PAYOUT / LCB | 0.9516 / 0.8854 / **0.8668** | 0.9852 / 0.945 / 0.9194 |
| Time to phase-1 target (bd) p10 / p50 / p90 | 121 / 289 / 647 | 110 / 247 / 540 |
| End-to-end to first payout (bd) p10 / p50 / p90 | 254 / 489 / 909 | - |
| Demo state | RUNNING since 2026-09-18 04:50Z, 3.5 validation days, NOT representative, pulse WARN `ks_day_anchor_missing 0/6`, `ks_book_tag_missing 0/6` (diagnosis 4fd8222f, fix d6189118) | |

Reading: the incumbent is a **slow but breach-safe** book - the failure mode is time (median 489 bd end-to-end), not survival. Financing costs it
~0.05 of LCB and ~7 USD/bd; that is a real property of the XAU-heavy roster, not a modelling choice.

## 2. SHADOW book and DELTA_SHADOW_VS_INCUMBENT

No candidate has a **resolved** positive marginal contribution, so the shadow composition equals the incumbent. Candidate actions under OWNER §F:

| Candidate | Book action | Marginal LCB (financed; resolution) | Δ trades/bd | Δ DD USD | Δ cost USD/bd | Why |
|---|---|---|---|---|---|---|
| 11708 EURUSD D1 (anon-market-squeeze) | **SHADOW_BOOK** | +0.002 (old params) / +0.012 (5k, 504 bd) / -0.015 (1k, 504 bd) / 5k replicates +0.013 +/- 0.010 -> **UNRESOLVED, ~0 to +0.01** (seed SD 0.007-0.020) | +0.084 | -42 | +0.10 | cheap, genuinely independent FX density; does not move survival or speed measurably; DEMO_RESET_COST irrelevant for Sunday (fresh generation) but no evidence to add |
| 11421 EURUSD D1 | **HOLD** | -0.002 / -0.012 / 0.000 -> UNRESOLVED, ~0 | +0.045 | +580 | +0.30 | more drawdown and cost for no measurable LCB |
| 11910 NZDUSD D1 | **REJECT** (FTMO book) | -0.068 (old params) / -0.076 (5k) -> RESOLVED negative | +0.029 | +664 | +0.13 | raises max-loss breach 0.019 -> 0.032 |
| 10513 XAUUSD D1 | HOLD | -0.029 (Codex, unfinanced 1k) ; no financed stream on disk | +0.035 | +87 | +0.04 | third XAU D1 clone risk (cluster) |
| H-V4 / QM5_41485 | RETIRED, negative lineage `PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE` | NOT_MEASURABLE | - | - | - | OWNER §J |
| H-CW 41475 / H-MR 41476 / H-FXMR 41477 | HOLD until harness v2 (7088da77) prescreens the NY/index cash-session family | - | - | - | - | the missing behaviour, but the v1 harness is not trusted on NY-anchored cells |

**DELTA_SHADOW_VS_INCUMBENT = 0** on every §C metric (shadow == incumbent). The leave-one-out runs (unfinanced, Codex) keep every incumbent
sleeve: removing 10700 would cost 0.24 LCB, 10403 0.03, 41219 0.005.

## 3. Dependence summary (FTMO_BOOK_DEPENDENCE_MATRIX, financed re-run `FTMO_BOOK_DEPENDENCE_MATRIX_financed.md`)

Fail-together cluster {10403, 10700, 41219} XAUUSD (rule: same-symbol position overlap >= 25 % of the smaller exposure, or loss+tail overlap
>= 2x independence). Top pair 10403/41219: position overlap 39.5 % of the smaller exposure, loss-day overlap 2.37x independence, daily |r| 0.09,
downside r -0.42, lower-tail co-exceedance 0 - **they trade the same days, they do not lose together**; the cluster is an activity cluster, not a
tail cluster. Max daily |r| across the book 0.09. XAU carries 0.9375 % of the 1.71875 % (symbol HHI 0.37) - the known concentration, accepted
because the three XAU sleeves are economically different engines (turtle trend / H1 liquidity break / D1 mean reversion) and the 10700 leave-one-out
shows the book cannot spare it.

## 4. Strongest failure mode

**SLOW.** Median 289 bd to +10 % (phase 1), 489 bd end-to-end to a first payout at 27.5 USD/bd financed progress. Survival is not the binding
constraint (daily-loss breach 0.0, max-loss 0.020). Speed can only come from EDGE x DENSITY x DIVERSIFICATION (OWNER §D) - i.e. from a new,
independent, dense sleeve - never from re-weighting the six upward (D2g6r at 2.34 % tripled the breach probability for a 30 % speed gain, 2026-09-18).

## 5. STRONGEST_MISSING_BOOK_BEHAVIOR

A session-flat, low-overlap, high-density sleeve that earns in the New-York / index cash session, where the current book has ZERO exposure (all
sleeves except 13213 are overnight swing; 13213 is Tokyo/London USDJPY). Secondary: a second independent return engine on XAUUSD that is NOT a D1
trend/mean-reversion clone of 10403/41219 (activity clustering flag). Research path (OWNER §H loop): harness v2 with the §L golden test first
(7088da77), then the NY/index cash-session family (H-CW/H-MR mechanics on NDX/SP500/GDAXI) as pre-registered prescreen cells, build only
WORTH_MT5_TEST survivors, MT5 Q02-Q04, then the financed account-level marginal before any roster decision.

## 6. Loop state (CBE for FTMO) and Sunday plan

1. Book established and financed (this file). 2. Failure mode: slow. 3. Missing behaviour: NY/index cash session. 4. Hypotheses: none open
(H-V1..H-V4 falsified 2026-09-21; family-F1 anchors B/C withdrawn pending harness v2). 5. Prescreen: blocked on harness v2 + golden test.
6-7. Build/MT5: none in flight. 8. Marginal contribution: simulator financed; resolution rule pending Codex 3fae43b2. 9-10. Add only on a resolved
positive; conservative weights. **Sunday 2026-09-27:** genesis manifest + preflight (94a15624), kill-switch governed initializer (d6189118) deployed
and proven, demo-day retro audit (4505b206), sleeve attribution (74c41987); roster = the six unless a resolved improvement appears.
