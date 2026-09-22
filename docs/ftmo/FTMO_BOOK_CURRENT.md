# FTMO_BOOK - current (v2.1, 2026-09-21 20:1xZ - shadow composition from the pool sweep)

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
| FTMO_BOOK_SHADOW | **D2g6 + 12710 XTIUSD D1 + 20266 XTIUSD D1 (2.34375 %)** - pending symbol-input rebuild + identity proof (Codex `273f2de8`): LCB 0.8805 vs 0.8648 (5 seeds), median first payout 460 vs 492 bd, max-loss 0.017 vs 0.020, 1.59 trades/bd, 30.0 USD/bd; cost-stressed 0.679 vs 0.629. Status `QUEUE_FOR_NEXT_DEMO` candidate, not Sunday unless the proof lands by Saturday |
| SUNDAY_FTMO_BOOK (2026-09-27 generation, planned) | the six D2g6 sleeves with the kill-switch governed initializer (d6189118) applied; roster changes only on resolved evidence |
| P_FIRST_NET_FTMO_PAYOUT_LCB (financed) | **0.8668** (P 0.8854; unfinanced would read 0.9194) |
| P_CHALLENGE_PASS / P_VERIFICATION_PASS given challenge | 0.9516 / 0.9775 |
| MEDIAN_CHALLENGE_DAYS / MEDIAN_FIRST_PAYOUT_DAYS | 289 bd phase 1 (p10 121 / p90 647); end-to-end 489 bd (p10 254 / p90 909); first reward 15 bd after funding |
| DAILY_LOSS_BREACH_PROB / MAX_LOSS_BREACH_PROB (phase 1) | 0.0 / 0.0202 |
| DEPENDENCE_HIGHEST_CLUSTER | {10403, 10700, 41219} XAUUSD (position overlap 39 % of the smaller exposure for 10403/41219; loss-day overlap 2.4-2.8x independence; max daily |r| 0.09) |
| STRONGEST_MISSING_BOOK_BEHAVIOR | session-flat, low-overlap, high-density NY / index cash-session sleeve (zero exposure today) - see section 5 |
| 11708_SIGN_FLIP | EXPLAINED / EXPECTED_MODEL_IMPROVEMENT; delta unresolved -> SHADOW_BOOK |

## 0a. Payout-speed frontier — primary KPI `P80_DAYS_TO_FIRST_NET_FTMO_PAYOUT` (Codex e5cc5e95, accepted 2026-09-21T21:27:32Z)

Incumbent financed D2g6, first-passage engine 2.1.0, 40,000 pathwise Challenge→Verification→funded paths, seed 20260921
(`docs/research/ftmo_intake/2026-09-21_br_nnfx/results/PAYOUT80.md`, diagnostic JSON sha256 `fb25ec50…aa708`). Calendar days are the engine's 5/7 conversion of business days.

| Field | Value |
|---|---:|
| P_PAYOUT_WITHIN_30D / 45D / 60D / 90D | 0.000 / 0.000 / 0.000 / 0.000 |
| **P80_DAYS_TO_FIRST_NET_PAYOUT** (first cutoff with 90 % batch LCB ≥ 0.80) | **1300 calendar days** (business day 929, LCB 0.8013) |
| P_PAYOUT_EVER (full chain, positive net) | 0.8913 point, **0.8762** LCB90 |
| Days to payout conditional on paying out, p10 / p50 / p90 | 352 / 682 / 1253 calendar (251 / 487 / 895 bd) |
| Stress 1.5× costs + 2 USD/lot | LCB 0.8143; P80 1839 calendar days (1314 bd); conditional p50 / p90 748 / 1374 |
| Failure mass | challenge max-loss 1.9 %, challenge unresolved 2.5 %, verification max-loss 1.8 %, funded unresolved 4.3 %, daily-loss breach 0 in all stages |

Reading: the incumbent pays out with high probability but slowly — the 80 % crossing sits at about 3.6 years because the
unconditional curve carries the failure and censoring mass; even the conditional median is 682 calendar days. Every Track B/C
candidate is now judged by `DELTA_P80_DAYS` against this table. Caveats bind: not a bank-receipt t80 (administrative hand-offs,
rejection probability, payment-method minimum and bank lag are unbound); venue costs are UNMEASURED (73434cab ABSTAIN —
FTMO spreads measured, no matched Darwinex minutes, no request-vs-fill slippage), so the 0.8762 LCB is the financed reference,
not a venue-adjusted headline.

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

> **Rebuilt identities (2026-09-21T23:27:17Z, Codex 273f2de8 accepted):** the shadow sleeves 12710 and 20266 were rebuilt under the symbol-input rule as
> **QM5_41488** (`commodity-tsmom-12m-atr-symbolinput`, magic 414880000) and **QM5_41489** (`collins-66mom-symbolinput`, magic 414890000);
> identity proof `EQUIVALENT_EXACT` on the governed Q02 window (95/95 and 491/491 deal rows). Their own chain is progressing in the factory
> (Q02 PASS, Q04 PASS, Q05 active); 41489 may inherit the qualified parent Q08 evidence (20266 PASS), 41488 needs its own Q08 (parent 12710
> FAIL_SOFT). The shadow roster maps 12710→41488 and 20266→41489 as soon as the rebuilt Q08 streams exist. Evidence:
> `docs/ops/evidence/2026-09-22_oil_symbol_input_rebuilds/README.md`.

> **Shadow downgrade (2026-09-22T04:29:16Z):** the rebuilt identities ran their own Q08 on the governed 2017-2025 window after the promotion-window fix
> (Codex 5de65240): **QM5_41488 (12710 lineage) = FAIL_SOFT, QM5_41489 (20266 lineage) = FAIL_HARD** (8.2 DSR FAIL, 8.4 losing months
> 1/10/11/12, 8.6 chopping block PF 0.80 after removing the top 5 % of trades — the edge sits in a few trades). Under the identity
> doctrine neither rebuild is admissible on its own evidence, and the parent 20266 Q08 PASS is not reproduced by the same rule under the
> current contract, so the shadow composition D2g6 + 12710 + 20266 is **withdrawn**: `FTMO_BOOK_SHADOW = D2g6` (no admissible addition)
> with 11708 as the only open candidate (SHADOW_BOOK, resolution −0.0056 under stress). The 2.34 % LCB / −32 bd figures above are kept as
> history of a composition that is no longer evidence-supported. Next: the news-archive requalification (f50a0bba) re-measures every
> roster Q10 seal; Track B family B5 (XNGUSD Thursday, two independent scanner leads) is the next shadow candidate source.



No candidate has a **resolved** positive marginal contribution, so the shadow composition equals the incumbent. Candidate actions under OWNER §F:

| Candidate | Book action | Marginal LCB (financed; resolution) | Δ trades/bd | Δ DD USD | Δ cost USD/bd | Why |
|---|---|---|---|---|---|---|
| 11708 EURUSD D1 (anon-market-squeeze) | **SHADOW_BOOK** | **+0.0058 (SE 0.0016) RESOLVED** at 5 paired seeds x 40k paths (Codex 3fae43b2, reproduced by Fable) but below the +0.01 roster bar, and **-0.0056 RESOLVED under +1 bps / +2 USD/lot cost stress** (`stress_11708/`) | +0.084 | -42 | +0.10 | small, cost-fragile positive; genuinely independent FX density; not QUEUE_FOR_NEXT_DEMO for Sunday |
| 12710 XTIUSD D1 (commodity-tsmom-12m-atr) | **SHADOW_BOOK** (rebuild pending `273f2de8`) | +0.025 (SE 0.001) marginal; joint +0.013 base | +0.043 | +339 | +0.13 | most robust pool profile (7 of 8 years positive, top-3 share 53 %); class B symbol literal |
| 20266 XTIUSD D1 (collins-66mom) | **SHADOW_BOOK** (rebuild pending `273f2de8`) | +0.025 (SE 0.001); with 12710 joint +0.016 | +0.211 | +725 | +0.50 | dense (0.21/bd), mixed years; second oil engine (66-day momentum) |
| 13054 XTIUSD D1 (brent-tom-mom) | HOLD | +0.020 (SE 0.001) | +0.039 | -201 | +0.06 | class A but the same tail as 12710 (loss overlap 7.4x, tail 147x) - redundant |
| 12855 XTIUSD D1 (brent-nov-fade) / 21505 XAGUSD D1 | HOLD (rare-winner) | +0.109 / +0.064 but top-3 trades = 134 % / 362 % of net; 12855 trades only in November | | | | seasonal / rare-winner artefacts; research notes only |
| 11660 NDX H4 (pp-wedge) | REJECT | +0.048 | +0.726 | **+3,148** | +5.63 | +0.014 max-loss breach; class B+C |
| 11421 EURUSD D1 | **HOLD** | **-0.0079 (SE 0.0022) RESOLVED negative** at 5 x 40k | +0.045 | +580 | +0.30 | more drawdown and cost, negative LCB |
| 11910 NZDUSD D1 | **REJECT** (FTMO book) | **-0.0759 (SE 0.0021) RESOLVED** at 5 x 40k | +0.029 | +664 | +0.13 | raises max-loss breach 0.019 -> 0.032; stream ends 2025-06-05 (re-open only with a coterminous financed stream) |
| 10513 XAUUSD D1 | HOLD | -0.029 (Codex, unfinanced 1k) ; no financed stream on disk | +0.035 | +87 | +0.04 | third XAU D1 clone risk (cluster) |
| H-V4 / QM5_41485 | RETIRED, negative lineage `PRESCREEN_EXECUTION_MODEL_FALSE_POSITIVE` | NOT_MEASURABLE | - | - | - | OWNER §J |
| H-CW 41475 / H-MR 41476 / H-FXMR 41477 | HOLD until harness v2 (7088da77) prescreens the NY/index cash-session family | - | - | - | - | the missing behaviour, but the v1 harness is not trusted on NY-anchored cells |

**Pool sweep 2026-09-21 (`docs/ops/evidence/2026-09-21_ftmo_pool_marginal_sweep/`, 14 validated sleeves, financed, 5 x 40k):** seven resolved
positive marginals, but the two largest (12855 XTIUSD brent-nov-fade +0.109, 21505 XAGUSD +0.064) are rare-winner artefacts (top-3 trades =
134 % / 362 % of net; 12855 trades only in November) -> `HOLD`; 11660 NDX H4 +0.048 but +3,148 USD DD and +0.014 max-loss breach -> `REJECT`;
the oil momentum sleeves 12710 / 13054 / 20266 are the serious additions (+0.02 each; 12710 and 13054 are the same tail, loss overlap 7.4x ->
keep 12710 only). Joint runs (`joint/JOINT_TABLE.md`):

| Roster | Risk | LCB (5 seeds) | p50 first payout bd | max-loss | trades/bd | USD/bd | stressed LCB |
|---|---:|---:|---:|---:|---:|---:|---:|
| D2g6 (incumbent) | 1.72 % | 0.8648 | 492 | 0.020 | 1.34 | 27.5 | 0.629 |
| **D2g6 + 12710 + 20266 (SHADOW)** | 2.34 % | **0.8805** | **460** | 0.017 | 1.59 | 30.0 | 0.679 |
| D2g6 + 12710 + 13054 + 20266 | 2.66 % | 0.8907 | 446 | 0.015 | 1.63 | 31.0 | 0.698 |
| D2g6 + 21505 + 13054 + 12855 | 2.66 % | 0.8549 | 493 | 0.025 | 1.52 | 28.9 | 0.624 |

**DELTA_SHADOW_VS_INCUMBENT:** LCB +0.016, first payout -32 bd, max-loss -0.003, +0.25 trades/bd, +2.5 USD/bd, cost drag +0.6 USD/bd; dependence:
12710/20266 form a second fail-together cluster (same-market momentum, loss overlap 5.5x), max daily |r| 0.09. The pool can buy roughly
+0.02 LCB and a month of speed - it cannot supply the missing NY-session role; velocity still has to come from Track B research.
The leave-one-out runs (unfinanced, Codex) keep every incumbent sleeve: removing 10700 would cost 0.24 LCB, 10403 0.03, 41219 0.005.

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

## 7. Cost sensitivity (2026-09-21 19:3xZ) — the strongest open economic uncertainty

A uniform +1 bps round-trip spread + 2 USD/lot slippage stress on the financed incumbent moves the payout LCB 0.8668 -> **0.6072**,
phase-1 max-loss breach 0.020 -> **0.102**, progress 27.5 -> 16.0 USD/bd, cost drag 12.6 -> 24.1 USD/bd
(`docs/ops/evidence/2026-09-21_ftmo_book_sim_v2_financed/stress_11708/`). The Q08 streams carry Darwinex `.DWX` spreads; the FTMO
venue spread is measured only for XAUUSD and GER40. Until the per-symbol FTMO-minus-Darwinex delta is measured and simulated
(Codex `73434cab`, VENUE_ADJUSTED headline), the 0.8668 headline is an upper bound for the FTMO venue, and the representative Demo's
observed spreads/fills (acceptance contract §2.4) are the binding evidence for the purchase packet.

