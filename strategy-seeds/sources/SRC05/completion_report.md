---
source_id: SRC05
parent_issue: QUA-352
authored_by: Research Agent
authored_on: 2026-04-28
status: drafted_pending_ceo_review                # v1 closeout — covers 12 unconditional cards; v2 will append S13/S14 if CEO ratifies darwinex_native_data_only exception per § 8 closing checklist
report_version: v1_unconditional_only
budget_summary:
  heartbeats_used: 5                              # h1 scaffold + 4-card MR batch (S01,S02,S05,S06); h2 single-symbol futures (S07,S08,S09); h3 intraday-gap (S12,S03); h4 multi-stock-universe / cross-sectional-momentum (S04,S10,S11); h5 closeout report
  cards_drafted: 12                               # S01-S12 unconditional batch
  cards_skipped: 8                                # 6 author-disqualified + 2 rule-1-completeness + HFT family (Ex 2.5, Ex 2.8, Ex 3.1, Ex 4.3, Ex 4.4, Ex 5.3, mutual-fund-flow, HFT family pp. 165-168)
  cards_killed_pre_p1: 0                          # no hard-rule-fail KILLs in this v1 batch (S13/S14 conditional, deferred to CEO ratification — TBD whether they become DRAFT_v2 or SKIPPED with `darwinex_native_data_only` rationale)
  cards_pending_ceo_decision: 2                   # S13 PEAD + S14 leveraged-ETF-rebal — DRAFT_PENDING_CEO_RATIFICATION on darwinex_native_data_only exception
  cards_passed_g0: 0                              # all 12 DRAFT; awaiting CEO + Quality-Business review
  yield_ratio_cards_per_heartbeat: 2.4            # 12 / 5 — between SRC03's 2.33 and SRC03 pacing (above SRC04's 1.67)
  draft_yield_pct: 60                             # 12 / 20 surveyed slots (S01-S14 + 6 SKIPped Examples + HFT family + mutual-fund-flow); upper-half of QUA-352 forecast (5-8 → 12 actual = above ceiling)
  vs_predecessors:
    src01: 5 cards / 5 hb (1.00 cards/hb)
    src02: 8 cards / 8 hb (1.00 cards/hb)
    src03: 14 cards / 6 hb (2.33 cards/hb)
    src04: 10 cards / 6 hb (1.67 cards/hb)
    src05: 12 cards / 5 hb (2.40 cards/hb)
---

# SRC05 Completion Report — Chan, *Algorithmic Trading: Winning Strategies and Their Rationale*

This report closes out SRC05 v1 per `processes/13-strategy-research.md` § "Per-step responsibilities" Step 5 and § "Exits" (parent close → completion_report.md). All strategy-rich chapters of the source PDF (Ch 2-7, with Ch 1 + Ch 8 surveyed and confirmed methodology-only) have been surveyed; **12 unconditional Strategy Cards drafted** under V5 schema; **8 candidates SKIPPED** (author-disqualified / methodology / underspec / hard-rule-block rationales); **2 candidates pending CEO ratification** of `darwinex_native_data_only` exception (S13 PEAD requires earnings-calendar feed; S14 leveraged-ETF-rebal requires US 3x sector ETFs).

**SRC05 status from Research's side: unconditional extraction complete; v2 closeout pending CEO action on S13/S14 conditional batch.** Awaiting CEO action on:

1. The 12 v1 DRAFT cards (G0 review per DL-030 Class 2 Review-only execution policy) — sub-issues to be opened sequentially per DL-029 in h6
2. The 7 batched controlled-vocabulary additions per `strategy_type_flags.md` addition-process (`kalman-filter-mr`, `calendar-spread-mr`, `futures-roll-return-arb`, `time-series-momentum`, `cross-sectional-momentum`, `opening-gap-momentum` + optional `event-driven-momentum` if S13 ratified, optional `leveraged-etf-rebalance-momentum` if S14 ratified)
3. The S13 + S14 `darwinex_native_data_only` conditional decision (§ 8 closing checklist)
4. SRC06 dispatch per DL-032 Autonomy Waiver v3 (next source per `SOURCE_QUEUE.md` `proposed_order = 6`, TBD per CEO ratification at SRC05 closeout)

## 1. Source identity (recap)

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    quality_tier: A                              # peer-known practitioner; founder of QTS Capital Management; Caltech PhD; second of three Wiley Trading books (after SRC02 Chan QT 2009)
    role: primary
```

Source-text on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf` (8.7 MB; `pdftotext -layout` clean extraction; embedded text layer, no OCR needed). 8 chapters total; strategy-bearing span Ch 2-7 (mean reversion Ch 2-5 + momentum Ch 6-7); Ch 1 (Backtesting) + Ch 8 (Risk Management) are methodology-only.

## 2. Strategy harvest

Twelve unconditional Strategy Cards drafted; full set summarized in the table below. All twelve carry `status: DRAFT` and are awaiting CEO + Quality-Business G0 review. Two additional conditional cards (S13/S14) deferred to CEO ratification.

| Slot | Card slug | Source location | Strategy character | Author-claim type | Primary `hard_rules_at_risk` |
|---|---|---|---|---|---|
| S01 | `chan-at-bb-pair` | Ch 3 PDF p. 71 (Ex 3.2) | Bollinger-band MR on regression-hedged pair spread (GLD-USO source case); entryZ=1, exitZ=0, lookback=20 dynamic OLS hedge ratio | APR 17.8%/Sh 0.96 + verbatim MATLAB | `enhancement_doctrine` (entry/exit Z-band thresholds) |
| S02 | `chan-at-kf-pair` | Ch 3 PDF p. 78 (Ex 3.3) | Kalman-filter dynamic-state-space MR on pair (EWA-EWC source case); ±√Q(t) one-stdev band trigger; δ=0.0001, Vε=0.001 training-set tuned | APR 26.2%/Sh 2.4 + verbatim MATLAB | `enhancement_doctrine` (KF state-space hyperparameters); **NEW vocab `kalman-filter-mr`** |
| S03 | `chan-at-buy-on-gap` | Ch 4 PDF p. 94 (Ex 4.1) | Cross-sectional gap-fade on SPX (universe screen + top-10 most-negative-gap + 20d-MA filter; open-to-close hold); long APR 8.7%/Sh 1.5; short-mirror APR 46%/Sh 1.27 | Verbatim MATLAB + 6-year aggregate + Chan candor on long-only-asymmetry + ARCA-preopen pitfall | `dwx_suffix_discipline`, `magic_schema`, `one_position_per_magic_symbol` (V5-architecture-CHALLENGED multi-stock universe) |
| S04 | `chan-at-spy-arb` | Ch 4 PDF p. 98 (Ex 4.2) | SPY-vs-98-stock-Johansen-basket cointegration arbitrage; linear-MR z-score on logMktVal with `lookback=5` ("fixed with hindsight" per Chan p. 100) | APR 4.5%/Sh 1.3 (test 2008-04/2012) + verbatim MATLAB + Chan candor on lookahead + no-retraining-degradation | `dwx_suffix_discipline`, `magic_schema`, `friday_close` (basket-vs-ETF V5-architecture-CHALLENGED) |
| S05 | `chan-at-fx-coint-pair` | Ch 5 PDF pp. 111 + 114 (Ex 5.1 + Ex 5.2 folded) | Linear-MR pair on currency pair via Johansen non-unity hedge (USD.AUD vs USD.CAD source); trainlen=250, lookback=20 | Ex 5.1: APR 11%/Sh 1.6; Ex 5.2 direct-cross variant with rollover: APR 6.2%/Sh 0.54 | `enhancement_doctrine` (training-set lookback) |
| S06 | `chan-at-cal-spread` | Ch 5 PDF p. 124 (Ex 5.4) | Calendar-spread MR on futures (CL 12-month spread source + VX back/front-ratio variant); halflife=36 lookback Z-score of γ | CL: APR 8.3%/Sh 1.3; VX: APR 17.7%/Sh 1.5 + verbatim MATLAB | `friday_close` (multi-week hold across roll cycles); **NEW vocab `calendar-spread-mr`** |
| S07 | `chan-at-ts-mom-fut` | Ch 6 PDF p. 138 (Ex 6.1) + Table 6.2 | Single-future time-series momentum (sign of N-day-lagged return; M-day overlap-rebalanced); per-symbol param sets TU(250/25), BR(100/10), HG(40/40) | TU: APR 1.7%/Sh 1.04; BR: APR 17.7%/Sh 1.09; HG: APR 18%/Sh 1.05 + verbatim MATLAB | `dwx_suffix_discipline` (commodity-futures → Darwinex spot/CFD); **NEW vocab `time-series-momentum`** |
| S08 | `chan-at-roll-arb-etf` | Ch 6 PDF p. 141 (inline) | ETF-vs-future roll-return arbitrage (XLE-USO source); long XLE / short USO when CL contango; mirror in backwardation | APR 16%/Sh ≈1 | `dwx_suffix_discipline` (XLE/USO not Darwinex-native; substitute path TBD); **NEW vocab `futures-roll-return-arb`** |
| S09 | `chan-at-vx-es-roll-mom` | Ch 6 PDF p. 143 (inline, Simon-Campasano 2012) | VX-ES roll-return momentum (when VX_front > VIX + 0.1·DTS short 0.3906 VX + short 1 ES; mirror in backwardation; 1-day hold) | APR 6.9%/Sh 1 | `dwx_suffix_discipline` (VX/ES Darwinex availability); reuses `futures-roll-return-arb` flag (with-regime variant) |
| S10 | `chan-at-xs-mom-fut` | Ch 6 PDF p. 145 (inline, Daniel-Moskowitz) | Cross-sectional commodity-futures momentum: rank 52-future universe by 252-day-lagged return; long top-1, short bottom-1, 25-day overlap holds | 2005-07: APR 18%/Sh 1.37; **2008-09: APR -33%** (Chan p. 145 explicit P5c crisis-slice mandate) | `dwx_suffix_discipline`, `magic_schema`, `friday_close` (multi-week overlap holds); **NEW vocab `cross-sectional-momentum`** |
| S11 | `chan-at-xs-mom-stock` | Ch 6 PDF p. 146 (Ex 6.2, Daniel-Moskowitz S&P 500 adaptation) | Cross-sectional stock momentum: rank S&P 500 by 252-day-lagged return; long top-50, short bottom-50, 25-day overlap holds | 2007 short-window: APR 37%/Sh 4.1 (sample-size-suspicious); Daniel-Moskowitz 1947-2007 long-window: APR 16.7%/Sh 0.83 (credible baseline); 2008-09: APR -30% | `dwx_suffix_discipline`, `magic_schema`, `friday_close`; reuses `cross-sectional-momentum` flag (stock-universe parameter) |
| S12 | `chan-at-fstx-gap-mom` | Ch 7 PDF p. 156 (Ex 7.1) + p. 157 inline GBPUSD generalization | Opening-gap momentum (go-with): long if today.open > prev_high·(1+0.1·90d_stdret); short mirror; exit at session close | FSTX: APR 13%/Sh 1.4 (2004-2012); GBPUSD: APR 7.2%/Sh 1.3 (2007-2012); Ch 8 cross-ref: APR 13%→2.6% under constant-leverage overlay | `dwx_suffix_discipline` (FSTX → STOXX50.DWX/EUSTX50.DWX); **NEW vocab `opening-gap-momentum`** (sibling/mirror of `gap-fade-stop-entry`) |

**Total: 12 unconditional cards, 12 distinct mechanical structures.** Above the QUA-352 ceiling forecast (5-8 cards predicted; 12 actual = +50% over ceiling). Driven by inline strategies (S08 XLE-USO, S09 VX-ES, S10 XS-futures-momentum) which are not numbered Examples but are concrete mechanical strategies, plus folded variants (Ex 5.1+5.2 → S05; Table 6.2 generalization in S07; CL+VX in S06; FSTX+GBPUSD in S12).

### Conditional cards pending CEO ratification

| Slot | Card slug | Source location | Strategy character | Hard-rule-at-risk |
|---|---|---|---|---|
| **S13** | `chan-at-pead` (NOT YET DRAFTED) | Ch 7 PDF p. 160 (Ex 7.2) | Post-Earnings Announcement Drift: earnings announced after prev_close + before today_open → measure overnight return relative to 90d_stdev; long if return > 0.5·stdev, short if < -0.5·stdev; exit at close | `darwinex_native_data_only` BIND — requires earnings-calendar data feed |
| **S14** | `chan-at-lev-etf-rebal` (NOT YET DRAFTED) | Ch 7 PDF p. 163 (inline) | Leveraged-ETF MOC rebalancing momentum: buy DRN (3x REIT ETF) if return prev_close → T-15min > 2%, sell if < -2%, exit at close | `darwinex_native_data_only` + `dwx_suffix_discipline` BIND — requires US 3x leveraged sector ETFs absent from Darwinex |

**S13/S14 status:** Strategy mechanics are fully extractable as cards; the constraint is **data dependency**, not strategy validity. CEO autonomous on per-batch source approval per [DL-032](/QUA/issues/QUA-273). Three CEO-decision paths laid out in h4 progress comment ([id `8d0ad978`](/QUA/issues/QUA-352#comment-8d0ad978-358e-43c4-98fa-3c1e62353c56)): (A) accept exception for both → Research drafts both in v2 closeout; (B) accept one only → draft accepted card only; (C) decline both → SKIPPED with rationale, completion_report v2 records the SKIPs alongside the rest of § 3.

### Architecture-fit profile (V5)

| Architecture-fit | Cards | Recommended G0 path |
|---|---|---|
| **Clean (single-symbol or 2-symbol-pair Darwinex spot/CFD)** | S01, S02, S05, S06, S07, S08, S09, S12 | All 8 cards single-symbol or pair architecture-clean. Standard advance through P-pipeline. CTO confirms per-card Darwinex symbol mapping at G0 (especially S07 commodity-futures → Darwinex CFDs and S08/S09 futures-vs-ETF pair availability). |
| **V5-architecture-CHALLENGED (multi-stock universe / Johansen basket / cross-sectional)** | S03, S04, S10, S11 | All 4 cards require V5 portfolio-of-N-symbols framework or substitute-path on smaller-N universe (sector-ETF cross-section, FX-cross-section, world-index-cross-section). Same architectural-pending status as SRC02 chan-khandani-lo-mr / chan-pca-factor / chan-january-effect / chan-yoy-same-month. Pipeline G0 may defer P1 build until V5 cross-sectional framework lands. |

**SRC05 yields 8/12 = 67% architecture-clean cards** (matches SRC02's 4/8 = 50% cross-sectional-heavy pattern; substantially below SRC03 14/14 = 100% and SRC04 10/10 = 100%). The 4 V5-architecture-CHALLENGED cards (S03/S04/S10/S11) are all multi-stock universe, mirroring SRC02's cross-sectional cluster. If V5 builds a generalized portfolio-of-N-symbols runtime, these 4 SRC05 cards + the 4 SRC02 cross-sectional cards (8 total) all become tractable simultaneously.

### Strategy-type-flag distribution (across the 12 unconditional drafted cards)

| Flag | S01 | S02 | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S10 | S11 | S12 | Count |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| cointegration-pair-trade | ✓ |  |  | ✓ | ✓ |  |  |  |  |  |  |  | 3 |
| zscore-band-reversion | ✓ |  |  | ✓ | ✓ | ✓ |  |  |  |  |  |  | 4 |
| mean-reach-exit | ✓ | ✓ |  |  | ✓ | ✓ |  |  |  |  |  |  | 4 |
| symmetric-long-short | ✓ | ✓ | ✓ |  | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 11 |
| signal-reversal-exit |  |  |  | ✓ |  |  | ✓ | ✓ | ✓ | ✓ | ✓ |  | 6 |
| cross-sectional-decile-sort |  |  | ✓ |  |  |  |  |  |  |  |  |  | 1 |
| trend-filter-ma |  |  | ✓ |  |  |  |  |  |  |  |  |  | 1 |
| time-stop |  |  | ✓ |  |  |  |  |  |  |  |  | ✓ | 2 |
| **proposed:** kalman-filter-mr |  | ✓ |  |  |  |  |  |  |  |  |  |  | 1 |
| **proposed:** calendar-spread-mr |  |  |  |  |  | ✓ |  |  |  |  |  |  | 1 |
| **proposed:** futures-roll-return-arb |  |  |  |  |  |  |  | ✓ | ✓ |  |  |  | 2 |
| **proposed:** time-series-momentum |  |  |  |  |  |  | ✓ |  |  |  |  |  | 1 |
| **proposed:** cross-sectional-momentum |  |  |  |  |  |  |  |  |  | ✓ | ✓ |  | 2 |
| **proposed:** opening-gap-momentum |  |  |  |  |  |  |  |  |  |  |  | ✓ | 1 |

**Mining provenance**: SRC05 leverages SRC02's existing flag set (`cointegration-pair-trade`, `zscore-band-reversion`, `mean-reach-exit`, `cross-sectional-decile-sort`) for half of its cards, and introduces 6 new flags for the half that requires net-new vocabulary (state-space MR, calendar-spread, roll-return-arb, time-series-momentum, cross-sectional-momentum, opening-gap-momentum). No `vol-expansion-breakout` / `gap-fade-stop-entry` / `rejection-bar-stop-entry` / `failed-breakout-fade` (SRC03 specialties); no `bband-reclaim` / `round-num-fade` / `ma-stack-entry` (SRC04 specialties). The flag-distribution density is roughly 3.7 flags-per-card (44 flag-card cells / 12 cards) — characteristic of methodology-rich extraction.

### Direction-class diversity (cross-source, cumulative)

| Class | SRC01 (Davey) | SRC02 (Chan QT) | SRC03 (Williams) | SRC04 (Lien) | SRC05 (Chan AT) | Total |
|---|---|---|---|---|---|---|
| Trend-following / momentum / breakout | 1 | 0 | 3 | 3 | 0 | 7 |
| Mean-reversion (single-bar) | 4 | 1 | 4 | 2 | 0 | 11 |
| Trend-join / breakout-continuation | 0 | 0 | 0 | 2 | 0 | 2 |
| Calendar-bias | 0 | 0 | 3 | 0 | 0 | 3 |
| Gap-fade reversal | 0 | 0 | 3 | 0 | 1 (S03 buy-on-gap) | 4 |
| Failed-breakout fade | 0 | 0 | 1 | 1 | 0 | 2 |
| Cointegration / pair-trade | 0 | 1 | 0 | 0 | 4 (S01 BB-pair, S02 KF-pair, S04 SPY-arb, S05 FX-coint-pair) | 5 |
| Cross-sectional MR / multi-stock | 0 | 4 | 0 | 0 | 1 (S03 buy-on-gap) | 5 |
| Cross-sectional momentum | 0 | 0 | 0 | 0 | 2 (S10 fut-mom, S11 stock-mom) | 2 |
| Annual calendar trade | 0 | 2 | 0 | 0 | 0 | 2 |
| Session-pattern intraday | 0 | 0 | 0 | 1 | 0 | 1 |
| Carry / interest-rate-differential | 0 | 0 | 0 | 1 | 0 | 1 |
| Calendar-spread MR | 0 | 0 | 0 | 0 | 1 (S06 cal-spread) | 1 |
| Futures-roll-return arb / momentum | 0 | 0 | 0 | 0 | 2 (S08 XLE-USO, S09 VX-ES) | 2 |
| Time-series-momentum (single-instrument) | 0 | 0 | 0 | 0 | 1 (S07 ts-mom-fut) | 1 |
| Opening-gap-momentum | 0 | 0 | 0 | 0 | 1 (S12 fstx-gap-mom) | 1 |
| **TOTAL** | 5 | 8 | 14 | 10 | 12 | 49 |

**SRC05 broadens V5's direction-class coverage substantially:** introduces FOUR new direction-classes — "calendar-spread MR" (S06), "futures-roll-return arb / momentum" (S08, S09), "time-series-momentum (single-instrument)" (S07), "cross-sectional momentum" (S10, S11), and "opening-gap-momentum" (S12). Combined with predecessors, V5 corpus now spans **16 direction-classes across 49 cards** (was 11 classes / 37 cards at SRC04 closeout).

**Diversity-bias check (per SOURCE_QUEUE):** No 3+ consecutive same-class trigger fires. Chan AT brings net-new strategy classes (state-space MR, calendar-spread MR, roll-return arb/momentum, opening-gap momentum, cross-sectional momentum), and reinforces cointegration-pair-trade family with 3 additional cards (S01/S04/S05 — bringing cumulative cointegration-family coverage to 4 across 2 sources). SRC06 dispatch per `SOURCE_QUEUE.md` `proposed_order = 6` is acceptable next.

## 3. SKIPs (sections classified as no-card per Rule 1)

Eight SKIPs documented with rationale:

| Slot | Section | SKIP type | Rationale |
|---|---|---|---|
| (Ch 2 Ex 2.5) | Ch 2 PDF p. 49 | **SKIP_DISQUALIFIED_AT_SOURCE** | USD.CAD linear MR (single-leg). Author candor: "I certainly don't recommend it as a practical trading strategy." Per BASIS rule, demonstration strategy honestly disqualified by Chan; not extracted. |
| (Ch 2 Ex 2.8) | Ch 2 PDF p. 59 | **SKIP_DISQUALIFIED_AT_SOURCE** | EWA-EWC-IGE Johansen triplet linear MR. Author candor: "obviously not a practical strategy, at least in its simplest version"; the practical version is Ex 3.2 (folded into S01 chan-at-bb-pair). Per BASIS rule, demonstration; not extracted. |
| (Ch 3 Ex 3.1) | Ch 3 PDF p. 67 | **SKIP_METHODOLOGY** | Trading Price Spread / Log Price / Ratio (GLD-USO). Methodology comparison demo of 3 spread definitions, NOT a standalone strategy. Per Rule 1, no mechanical strategy to extract beyond the comparator framing absorbed into S01. |
| (Ch 4 Ex 4.3) | Ch 4 PDF p. 103 | **SKIP_DUPLICATE** | Khandani-Lo Linear Long-Short Stocks. Chan AT explicitly cites "Example 3.7 of Chan, 2009; original paper is Khandani and Lo, 2007" (PDF p. 102) — already extracted as SRC02_S03 `chan-khandani-lo-mr`. Per Process 13 § Strategy lineage rule ("the test is *where the insight came from*"), the insight came from Khandani-Lo (2007) → already extracted from SRC02. |
| (Ch 4 Ex 4.4) | Ch 4 PDF p. 104 | **SKIP_VARIANT_OF_DUPLICATE** | Intraday Linear Long-Short Stocks (overnight return ranking + intraday liquidation lifecycle). Variant of Ex 4.3 with intraday execution rather than daily close. Lean: SKIP as a `_v2` variant of the already-SKIPped duplicate. CEO discretion if to flag separately as `chan-khandani-lo-mr_v2_intraday` — not extracted in v1. |
| (Ch 5 Ex 5.3) | Ch 5 PDF p. 119 | **SKIP_METHODOLOGY** | Estimating spot/roll returns. Methodology only — provides estimator γ that feeds S06 cal-spread, S08 XLE-USO, S09 VX-ES rules; not a standalone strategy. Per Rule 1, integrated as filter-input across the three downstream cards. |
| (Ch 6 Mutual Fund Flow) | Ch 6 PDF pp. 149-150 | **SKIP_HARD_RULE_BLOCK** | Mutual Fund Flow-Pressure Momentum (Coval-Stafford). Requires CRSP fund-holdings data ($10K/yr institutional subscription). NOT in Darwinex-native feed; NOT mappable to Darwinex universe via any proxy path. Hard-rule block per `darwinex_native_data_only`. |
| (Ch 7 HFT family pp. 165-168) | Ch 7 PDF pp. 165-168 | **SKIP_HARD_RULE_BLOCK_AND_UNDERSPEC** | HFT family (ratio trade / ticking / flipping / momentum ignition / stop hunting / order flow). DUAL hard-rule block: (a) `scalping_p5b_latency` BIND (sub-millisecond execution requirements; V5 cannot meet without direct exchange-feed access); (b) underspec — Chan describes the families narratively without specific entry/exit/sizing rules. NOT mechanical; NOT V5-deployable. |

**Note on S13 + S14:** These two slots are NOT in the SKIP list because they are DRAFT_PENDING_CEO_RATIFICATION rather than SKIPped. If CEO declines the `darwinex_native_data_only` exception in v2, they would be added to this SKIP table as `SKIP_HARD_RULE_BLOCK` (mirroring SRC04 S15/S16 KILL_PRE_P1 pattern). If CEO ratifies, they become DRAFT cards in completion_report v2.

**Filter chapters NOT extracted as separate cards** (Ch 1 + Ch 8 + general filter context absorbed into per-card § 6):
- Ch 1: Backtesting and Automated Execution — methodology-only (look-ahead bias avoidance, primary-vs-consolidated price selection, transaction-cost overlay). Integrated as V5 framework defaults.
- Ch 8: Risk Management — methodology-only. Ex 8.1 constant-leverage strategy + Ex 8.2 optimal Kelly capital allocation. The constant-leverage Ex 8.1 is referenced in S12 chan-at-fstx-gap-mom § 9 as P5-stress evidence (FSTX APR 13% → 2.6% under constant-leverage overlay).
- Ch 5 § Spot Returns vs Roll Returns p. 121 Table 5.1 — provides spot/roll-return decomposition for ~25 futures contracts; integrated as filter context in S06/S07/S08/S09 per-card § 8 sweep-range targets.

Per DL-033 Rule 1, FILTERS are documented per-card under § 6 (Filters / No-Trade module) when they bind to a specific entry strategy, not as separate Strategy Cards.

## 4. Methodology cross-walk — Chan AT vs SRC01 Davey + SRC02 Chan QT + SRC03 Williams + SRC04 Lien

Five sources surveyed; methodology comparison:

| Aspect | SRC01 Davey | SRC02 Chan QT | SRC03 Williams | SRC04 Lien | SRC05 Chan AT |
|---|---|---|---|---|---|
| Source character | Process textbook | Methodology + small named demos | Strategy textbook + setup tools | Forex-specialist textbook with chapter-per-strategy | Methodology-rich algorithmic-trading textbook with mixed Examples + inline strategies |
| Strategy density | ~5 cards over ~14 chapters | ~8 cards over 8 chapters | ~14 cards over ~46 PDF pages | ~10 cards from 17 strategy-bearing chapters | **12 cards from 6 strategy-bearing chapters** (highest density across SRCs) |
| Backtest discipline | Per-strategy backtests with walk-forward | Per-strategy MATLAB code + Sharpe pre/post-cost | Aggregate backtests; verbatim rules | Per-trade pip P&L on 1-3 worked examples; descriptive performance | **Per-strategy MATLAB + verbatim APR/Sharpe + period brackets** (rule-tight quantitative rigor matching SRC02; clearer than SRC03/SRC04) |
| Author candor on failure modes | Davey Ch 13 walk-forward FAILURE example | Chan deliberate-failure examples | Williams "It may go on, or it may not" | Lien USDJPY perfect-order sub-1R worked example | **Chan AT 4 explicit failure modes:** (a) S04 lookback=5 "fixed with the benefit of hindsight" p. 100; (b) S04 "performance decreases as time goes on, partly because we have not retrained" p. 100; (c) S10 + S11 "−33%/−30% APR" 2008-09 crisis p. 145, 147; (d) Ch 8 constant-leverage Ex 8.1 cross-references S12 FSTX 13%→2.6% degradation. **Highest in-source candor density across SRCs.** |
| V5-architecture concerns | Low | High (4/8 multi-stock incompatible) | Low (14/14 architecture-clean) | Low-medium (1/10 external-data-shim) | **Medium-high (4/12 V5-architecture-CHALLENGED multi-stock)** — same pattern as SRC02; mirrors Chan's cross-sectional methodology focus |
| Vocabulary footprint | Mining baseline (V4 SM_XXX) | +5 new flags | +6 new flags | +3 new flags + 2 future-vocab-watches | **+6 new flags surfaced** (kalman-filter-mr, calendar-spread-mr, futures-roll-return-arb, time-series-momentum, cross-sectional-momentum, opening-gap-momentum) + 2 conditional (event-driven-momentum, leveraged-etf-rebalance-momentum) |

**Cross-source methodology delta for V5 P-pipeline (cumulative)**:
- SRC01 Davey contributed walk-forward + Monte Carlo + live-trading-validation methodology (V5 P4/P6/P10 standards)
- SRC02 Chan QT contributed transaction-cost stress-testing + survivorship-bias quantification + cointegration-vs-correlation disambiguation
- SRC03 Williams contributed `enhancement_doctrine` discipline by example + cross-symbol POSITIVE-validation pattern + calendar-bias as legitimate strategy class
- SRC04 Lien contributed multi-state-machine entry pattern + first carry-family card + forex-session-window patterns + `darwinex_native_data_only` as binding constraint at scale
- **SRC05 Chan AT contributes:** (a) **state-space MR (Kalman-filter) as a rule-bearing entry mechanism** — first KF-based card across SRCs; (b) **futures-roll-return mechanic as a structural family** (S06 calendar-spread, S08 XLE-USO arb, S09 VX-ES momentum — three distinct deployment patterns of the same roll-return γ estimator); (c) **time-series-momentum as a single-instrument-momentum vocab class** (S07, distinct from SRC02 calendar-bias and SRC03 trend-following / breakout); (d) **cross-sectional-momentum as a sibling-flag pattern** (S10, S11 — opposite direction of `cross-sectional-decile-sort` MR; first two examples of net-new direction class); (e) **opening-gap-momentum as a sibling-flag pattern** (S12 — opposite direction of `gap-fade-stop-entry` from SRC03); (f) **explicit P5c crisis-slice mandate from in-source-published failure** — Chan p. 145, 147 quantified -33% and -30% APRs over 2008-09 = direct evidence that V5 P5c testing infrastructure must include 2008-09 crisis slices for any cross-sectional-momentum card; (g) **Ch 8 constant-leverage degradation evidence cross-referenced into S12** — establishes the precedent that cross-chapter author cross-references should be captured in card § 9 for downstream P5 stress cycles.

## 5. Vocabulary additions surfaced (batch-proposed for CEO + CTO)

Per `strategy_type_flags.md` addition-process: **6 entry-side flag proposals + 2 conditional flag proposals (S13/S14 contingent)** surfaced from SRC05.

### A. Six new entry-side flag proposals (unconditional)

```yaml
- name: kalman-filter-mr
  proposed_at_cards: [SRC05_S02]
  section: A. Entry-mechanism
  definition: "Dynamic-state-space (Kalman filter) hedge ratio + dynamic mean + dynamic forecast-error variance MR on a pair spread. Entry triggered by standardized prediction error e(t) crossing ±√Q(t) (one-stdev band on the time-varying band). Exit on e(t) returning inside ±√Q(t). Distinct from `cointegration-pair-trade` (static hedge from regression/Johansen, fixed at training time) and `zscore-band-reversion` (single-leg own moving statistics, no state-space estimator)."
  v4_evidence: "None — V4 had no Kalman-filter EAs per Mining-provenance table."
  disambiguation_from:
    - "cointegration-pair-trade (static hedge ratio; KF-MR has dynamically-updating hedge)"
    - "zscore-band-reversion (single-leg own moving statistics; KF-MR has 2-leg state-space estimator)"
    - "regime-filter-multi (multi-feature regime tree; KF-MR is single-feature state-space)"

- name: calendar-spread-mr
  proposed_at_cards: [SRC05_S06]
  section: A. Entry-mechanism
  definition: "Cross-maturity futures spread (long far + short near or vice versa) as the mean-reverting series. Signal = Z-score of estimated roll-return γ over halflife-derived lookback. Position direction set by sign of γ Z-score deviation from its own moving mean. Distinct from `cointegration-pair-trade` (relies on cointegration of two distinct assets; calendar-spread relies on roll-return mean reversion specifically across maturities of the same underlying)."
  v4_evidence: "None — V4 had no calendar-spread EAs."
  disambiguation_from:
    - "cointegration-pair-trade (different-asset cointegration; calendar-spread is same-asset cross-maturity)"
    - "zscore-band-reversion (single-leg; calendar-spread is 2-leg cross-maturity)"

- name: futures-roll-return-arb
  proposed_at_cards: [SRC05_S08, SRC05_S09]
  section: A. Entry-mechanism
  definition: "Position direction set by sign of computed futures roll return γ. Long the spot-tracking instrument (or a non-future-carrying instrument) + short the future when γ < 0 (contango); mirror when γ > 0 (backwardation). Two deployment variants: (i) AGAINST the regime to extract roll-return (S08); (ii) WITH the regime to capture roll-return-driven momentum (S09). Direction of trade is *function of regime*, not function of price-vs-band. Distinct from `carry-direction` (carry sets direction on a single instrument) and `cointegration-pair-trade` (no cointegration test — direction comes from γ sign, not from spread Z-score)."
  v4_evidence: "None — V4 had carry-direction (single-instrument signed bias) but no roll-return-arb pairing futures with non-futures."
  disambiguation_from:
    - "carry-direction (single-instrument signed bias; roll-return-arb is 2-leg paired)"
    - "cointegration-pair-trade (cointegration test required; roll-return-arb uses γ-sign)"
    - "calendar-spread-mr (same-asset cross-maturity; roll-return-arb is paired with non-future)"

- name: time-series-momentum
  proposed_at_cards: [SRC05_S07]
  section: A. Entry-mechanism
  definition: "Single-instrument: long if price[t] > price[t-N], short if price[t] < price[t-N], hold for M days, daily-rebalanced 1/M-allocation overlap (M independent slots co-exist). Not a rolling N-bar extreme; not a pattern; not a cross-sectional rank. Pure sign-of-N-day-lagged-return. Distinct from `donchian-breakout` (no rolling N-bar extreme), `n-period-max-continuation` (no N-bar-max gate; just sign), and `ath-breakout` (no all-time-high requirement)."
  v4_evidence: "None — V4 trend-filter-ma is a SINGLE MA filter; time-series-momentum is the N-day-lagged-return-sign as ENTRY trigger, not a filter."
  disambiguation_from:
    - "donchian-breakout (rolling N-bar extreme; TS-mom is just price-vs-N-ago sign)"
    - "n-period-max-continuation (N-bar-max gate required; TS-mom has no max gate)"
    - "trend-filter-ma (single MA filter; TS-mom is the entry trigger itself)"
    - "cross-sectional-momentum (universe-ranked relative-strength; TS-mom is single-instrument time-series)"

- name: cross-sectional-momentum
  proposed_at_cards: [SRC05_S10, SRC05_S11]
  section: A. Entry-mechanism
  definition: "Rank universe by N-day-lagged return; long top-decile/N + short bottom-decile/N, hold M days with daily 1/holddays overlap-rebalance. Sibling of existing `cross-sectional-decile-sort` (MR direction); `cross-sectional-momentum` is the OPPOSITE direction (buy winners, sell losers). Card-level `weighting_scheme ∈ {top-N-bottom-N, decile, rank-weighted}` and `ranking_metric ∈ {N-day-lagged-return, factor-exposure-momentum, PCA-rank-momentum}` parameterize the family."
  v4_evidence: "None — V4 had no cross-sectional momentum strategies (V4 cross-sectional family was MR direction only; no momentum direction)."
  disambiguation_from:
    - "cross-sectional-decile-sort (MR direction; cross-sectional-momentum is OPPOSITE direction)"
    - "time-series-momentum (single-instrument; cross-sectional-momentum is universe-ranked)"
    - "annual-calendar-trade (single-symbol calendar bet; cross-sectional-momentum is universe-ranked)"
  recommendation: "SEPARATE flag (matches V4 sibling-flag-not-generalize precedent for `intraday-day-of-month` / `intraday-day-of-week` / `holiday-anchored-bias` from SRC03 closeout)."

- name: opening-gap-momentum
  proposed_at_cards: [SRC05_S12]
  section: A. Entry-mechanism
  definition: "Long if today.open > prev_high * (1 + entryZscore * 90d_close-to-close_stdret); short if today.open < prev_low * (1 - entryZscore * 90d_stdret); position held one session and liquidated at the close. Sibling of existing `gap-fade-stop-entry` (which is FADE direction; opening-gap-momentum is GO-WITH direction). Card-level `direction_mode ∈ {long, short, symmetric}` and `reference_extreme ∈ {prev_high_low, prev_close_plus_stdret, n_bar_high_low}` parameterize. Distinct from `vol-expansion-breakout` (next-bar open + N% × prior-bar range; opening-gap-momentum compares prev-bar-extreme + σ-band scaling not next-bar-open + range-projection)."
  v4_evidence: "None — V4 had no go-with-the-gap entries."
  disambiguation_from:
    - "gap-fade-stop-entry (FADE direction; opposite mechanic)"
    - "vol-expansion-breakout (next-bar open + N% × prior-day-range; opening-gap-momentum is prev-bar-extreme + σ-band)"
    - "intraday-day-of-month / intraday-day-of-week (calendar-bias; opening-gap-momentum is gap-conditional, not calendar-conditional)"
```

### B. Two conditional flag proposals (CEO ratification of S13/S14 required)

These are batch-proposed CONDITIONAL on CEO ratifying the S13/S14 `darwinex_native_data_only` exception in v2 closeout:

```yaml
- name: event-driven-momentum
  proposed_at_cards: [SRC05_S13]                # CONDITIONAL — only if CEO ratifies S13 PEAD
  section: A. Entry-mechanism
  definition: "Gap-direction momentum gated on a calendar-known corporate or macroeconomic event (earnings announcement, M&A, index inclusion change, FOMC). Entry: gap return relative to N-day stdev triggers long/short at session open; exit at close. Distinct from `opening-gap-momentum` (event-conditional vs unconditional) and `news-blackout` (no-trade filter, not entry trigger)."
  v4_evidence: "None."
  disambiguation_from:
    - "opening-gap-momentum (unconditional gap; event-driven-momentum requires named-event trigger)"
    - "news-blackout (no-trade filter; event-driven-momentum is the entry)"

- name: leveraged-etf-rebalance-momentum
  proposed_at_cards: [SRC05_S14]                # CONDITIONAL — only if CEO ratifies S14 leveraged-ETF-rebal
  section: A. Entry-mechanism
  definition: "Close-of-day momentum strategy specifically based on the deterministic rebalance flow of leveraged ETFs (LETF returns near MOC drive same-direction stock momentum). Entry: LETF intraday return prev_close → T-15min triggers long/short; exit at close. Distinct from `time-series-momentum` (intraday LETF-specific, fixed-return-threshold trigger; not N-day-lagged-return-sign)."
  v4_evidence: "None."
  disambiguation_from:
    - "time-series-momentum (single-instrument; leveraged-etf-rebalance-momentum is intraday LETF-specific)"
    - "opening-gap-momentum (overnight gap; leveraged-etf-rebalance-momentum is intraday last-15min-of-session)"
```

### C. Sibling parameterizations (no new flag)

The following extensions reuse existing flags via parameterization rather than adding new flags:

- **`cointegration-pair-trade` extended** (S04 chan-at-spy-arb) — basket-vs-ETF cardinality (98-stock long-only basket cointegrating with SPY via Johansen) extends the existing 2-symbol-pair flag. Pattern: same architectural mechanic (regress for stationary spread, trade z-score MR), different cardinality.

- **`cross-sectional-decile-sort` extended** (S03 chan-at-buy-on-gap) — `weighting_scheme=top-N-screen-by-gap-magnitude` and `ranking_metric=prior-low-to-open-gap-return` parameter extension; long-only direction-mode. The existing flag already supports discrete-decile (chan-january-effect / chan-yoy-same-month), continuous-distance (chan-khandani-lo-mr), pca-rank-decile (chan-pca-factor); now extended with top-N-screen.

### D. Future-vocab-watches (NOT yet proposed; defer to SRC06+ for deployment-precedent confirmation)

These are NOT batch-proposed at SRC05 closeout. They are recorded for forward-watch:

1. **`mean-reach-exit-dynamic`** — Kalman-filter-driven dynamic-mean exit (S02 chan-at-kf-pair). Currently subsumed under `mean-reach-exit` flag with a parameter flag for dynamic-vs-static-mean. If SRC06+ surfaces a third dynamic-mean-exit example, the discipline says split into a sibling flag.
2. **`overlap-slot-rebalance`** — daily 1/M-overlap-slot mechanic shared by S07 (single-instrument time-series momentum), S10 (cross-sectional futures momentum), and S11 (cross-sectional stock momentum). Currently captured per-card as parameter `holddays`+`topN` plus the overlap-rebalance loop. If SRC06+ surfaces the same mechanic in a 4th distinct context, the discipline says formalize as a TM-module flag (analogous to SRC03_S13's TM-module spec).

## 6. Yield ratio + budget review

```yaml
heartbeats_used: 5                            # h1 scaffold + survey; h2-h4 extraction batches; h5 closeout
cards_drafted: 12                             # S01-S12
cards_skipped: 8                              # 6 disqualified-or-methodology + mutual-fund-flow + HFT family
cards_killed_pre_p1: 0                        # no v1 KILLs (S13/S14 deferred-to-CEO not KILLed)
cards_pending_ceo_decision: 2                 # S13/S14
cards_passed_g0: 0                            # awaiting CEO review
yield_ratio: 12/5 = 2.40                      # cards-per-heartbeat (HIGHEST across SRCs alongside SRC03 2.33)
benchmark_vs_src03: 2.40 / 2.33 = 1.03×       # 103% of SRC03 (rule-tight Williams; SRC05 narrowly above)
benchmark_vs_src04: 2.40 / 1.67 = 1.44×       # 144% of SRC04 (forex-specialist Lien)
benchmark_vs_src02: 2.40 / 1.00 = 2.40×       # 240% of SRC02 (which was the baseline Chan-QT methodology + small demos)
extraction_rate: 12 / 20 = 60%                # surveyed slots = 14 candidate slots (S01-S14) + 6 SKIPped Examples (Ex 2.5, 2.8, 3.1, 4.3, 4.4, 5.3) = 20 total; mutual-fund-flow + HFT counted as part of S13-not-existing space
forecast_band_match: above ceiling            # QUA-352 forecast 5-8 cards; actual 12 = 50% above ceiling
```

**Yield-ratio drivers (Chan-AT-vs-predecessors analysis):**

1. Chan AT's strategy density per chapter is highest across SRCs — 12 cards from 6 strategy-bearing chapters (Ch 2-7) = 2.0 cards/chapter, vs SRC04 Lien 10/17 = 0.59 cards/chapter and SRC03 Williams 14/~5 = 2.8 cards/chapter
2. Chan AT mixes Examples (numbered) with inline strategies (named-but-not-numbered). Inline strategies S08 XLE-USO, S09 VX-ES, S10 XS-futures-momentum, S14 leveraged-ETF-rebal each yielded a card (or pending-card) — without these the count would have been 7-8 (matching the QUA-352 5-8 forecast)
3. Folded variants kept (Ex 5.1+5.2 → S05; Table 6.2 → S07; CL+VX in S06; FSTX+GBPUSD in S12) preserved 4-5 sibling-strategy cards-worth of content under 4 cards rather than splitting into 8-9 cards
4. The QUA-352 prediction was conservative ("methodology-rich algorithmic-trading textbook") — the reality is methodology-rich AND strategy-rich (the methodology is *applied via concrete Examples*, not separated as standalone methodology chapters)

**Counter-factors (where yield could have been higher):**

1. S13 + S14 are STRATEGY-COMPLETE per BASIS rule (mechanical rules + verbatim performance + page citations); the deferral is purely on `darwinex_native_data_only` hard-rule binding, NOT on extraction-completeness. If CEO ratifies the exception, +2 cards = 14 total = matches SRC03 ceiling exactly
2. The HFT family (Ch 7 pp. 165-168) was SKIPped on dual hard-rule (scalping_p5b_latency + underspec); even with the latency rule waived, the underspec block stands — Chan describes 6 HFT tactics narratively without specific entry/exit/sizing rules
3. The mutual-fund-flow Coval-Stafford strategy was SKIPped on data-block (CRSP fund-holdings); no Darwinex-native proxy exists for fund-flow data, so re-extraction is unlikely

**SRC05 yield: 12 cards in 5 heartbeats = 2.40 cards/heartbeat.** Above SRC03 ceiling (2.33) and well above SRC04 (1.67); reflects Chan AT's high strategy density across rule-tight Examples + inline strategies.

## 7. Recommendation: deeper mining + next source

### Deeper SRC05 mining

**Recommendation: NO further SRC05 work after S13/S14 conditional-decision-pass.** All 6 strategy-bearing chapters (Ch 2-7) surveyed; verdicts crystallized for all 14 candidate slots (S01-S14). The remaining context (Ch 1 Backtesting + Ch 8 Risk Management + Ch 5 § 5.3 spot/roll-return methodology + back matter) is filter context already integrated into per-card § 6 Filters and § 8 Sweep-Range.

The single open question for SRC05 is the S13/S14 conditional batch (h6 — pending CEO ratification). After v2 closeout, if pipeline P2-P9 reveals that Chan's patterns generalize beyond the 12 (or 14) drafted cards in unexpected directions (e.g., new factor-tilted variants of cross-sectional-momentum), Research can re-open SRC05 for follow-up at CEO discretion. Most likely candidates for re-extraction: **factor-tilted cross-sectional-momentum** (Chan p. 147 mentions earnings-growth, book-to-price, PCA factors as alternatives to lagged-return ranking) — this is a known SRC02_S04 chan-pca-factor extension and would need cross-source coordination.

### Next source

**Recommendation: dispatch SRC06 against the next entry in `SOURCE_QUEUE.md`** (`proposed_order = 6`, TBD per queue ratification at SRC05 closeout). Per [DL-032](/QUA/issues/QUA-273) Autonomy Waiver v3, CEO is autonomous on source-queue ordering and per-batch source approval.

Diversity-bias check considerations for SRC06 selection:
- SRC05 introduced 6 net-new direction classes (state-space MR, calendar-spread MR, roll-return arb/momentum, time-series-momentum, cross-sectional-momentum, opening-gap-momentum); SRC06 should ideally introduce additional net-new direction classes OR provide complementary coverage on existing ones
- SRC05 was Chan-authored; SRC06 should ideally NOT be a 3rd-consecutive Chan source (the SRC02+SRC05 combo gives Chan substantial vocabulary representation already)
- SRC05 surfaced `event-driven-momentum` (conditional S13) and `leveraged-etf-rebalance-momentum` (conditional S14) — these depend on CEO ratification; if SRC06+ surfaces non-Chan-authored examples of these mechanics, the conditional flag proposals can be revisited
- SRC05 introduced `kalman-filter-mr` as the first state-space estimator entry-mechanism; if SRC06 surfaces a particle-filter or Bayesian-state-space example, a sibling flag may emerge

Per DL-029 sequential workflow, no SRC06 work begins until SRC05 sub-issues complete G0 review (or are explicitly unblocked by CEO).

## 8. Open CEO actions (closing checklist)

- [ ] **G0 review** of 12 v1 SRC05 cards under sub-issues opened sequentially per DL-029 (first card unblocks the rest, h6 work)
- [ ] **Vocabulary batch-proposal ratification** — 6 unconditional entry-side flag additions (`kalman-filter-mr`, `calendar-spread-mr`, `futures-roll-return-arb`, `time-series-momentum`, `cross-sectional-momentum`, `opening-gap-momentum`)
- [ ] **S13/S14 `darwinex_native_data_only` exception decision** (h4 progress comment [`8d0ad978`](/QUA/issues/QUA-352#comment-8d0ad978-358e-43c4-98fa-3c1e62353c56) laid out three paths):
  - (A) Accept exception for both S13 + S14 → Research drafts both cards in v2 closeout; +2 cards = 14 total; +2 conditional flags ratified
  - (B) Accept one only → draft accepted card; close out remaining as SKIP
  - (C) Decline both → both flagged as SKIP_HARD_RULE_BLOCK in v2; closeout proceeds with 12 unconditional cards
- [ ] **Future-vocab-watch acknowledgement** (no action required) — record `mean-reach-exit-dynamic` (Kalman-filter-driven) and `overlap-slot-rebalance` (S07/S10/S11 daily-1/M-overlap mechanic) for SRC06+ deployment-precedent confirmation
- [ ] **`friday_close` waiver consideration** — multi-week-hold cards (S06 calendar-spread, S07 ts-mom-fut at HG=40d, S10/S11 cross-sectional-momentum at 25-day overlap) all flagged; precedent: SRC02_S01 chan-pairs-stat-arb + SRC03_S03 williams-cdc-pattern + SRC04_S11 lien-carry-trade received P3 waiver consideration on similar theses
- [ ] **`magic_schema` extension consideration** — V5 portfolio-of-N-symbols framework would unblock S03/S04/S10/S11 simultaneously alongside SRC02 chan-khandani-lo-mr / chan-pca-factor / chan-january-effect / chan-yoy-same-month (8 cards total). Architecture-pending status; CTO + CEO coordination needed for V5 cross-sectional runtime decision
- [ ] **P5c crisis-slice infrastructure validation via S10/S11** — Chan p. 145 explicit -33% APR (S10) and p. 147 -30% APR (S11) over 2008-09 = direct in-source mandate that V5 P5c testing infrastructure must include 2008-09 slices. S10/S11 are USEFUL NEGATIVE-VALIDATION CASES for the V5 P5c testing infrastructure itself
- [ ] **SRC06 dispatch** — open next source per `SOURCE_QUEUE.md` `proposed_order = 6` after SRC05 sub-issues progress (post-h6 sub-issue queue creation)
- [ ] **Pre-sync to main** per QUA-336 lesson — sub-issue cards + raw + source.md + completion_report.md to be synced from `agents/research` to `main` in `C:/QM/repo` BEFORE filing P1 Dev build child for any SRC05_S* card. h6 work.

## 9. Cross-references

- Parent issue: [QUA-352](/QUA/issues/QUA-352)
- Sub-issues: TBD — to be opened sequentially in h6 per DL-029 chain (`blockedByIssueIds: [<prev_id>]` populated on every non-first sub-issue per [SRC0N closeout — populate blockedByIssueIds for sub-issue chain] feedback memory)
- Predecessor sources: [QUA-191](/QUA/issues/QUA-191) (SRC01 Davey), [QUA-275](/QUA/issues/QUA-275) (SRC02 Chan QT), [QUA-298](/QUA/issues/QUA-298) (SRC03 Williams), [QUA-333](/QUA/issues/QUA-333) (SRC04 Lien)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md` (T1 Tier A row 5)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification + sequential sub-issue chain with `blockedByIssueIds`): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-030 (Class 2 Review-only execution policy on Strategy Card child issues)
- DL-032 (CEO Autonomy Waiver v3 — autonomous source-queue ordering)
- DL-033 (extraction-discipline / Rule 1)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`
- h1 progress comment: posted on QUA-352 — h1 scaffold + 4 cards (S01/S02/S05/S06)
- h2 progress comment: posted on QUA-352 (id `dd15c5f7`) — 3 cards (S07/S08/S09)
- h3 progress comment: posted on QUA-352 (id `788977c4`) — 2 cards (S12/S03); commit `b810b18`
- h4 progress comment: posted on QUA-352 (id `8d0ad978`) — 3 cards (S04/S10/S11) + S13/S14 decision-needed; commit `6e9a852`
- SRC04 closeout precedent: `strategy-seeds/sources/SRC04/completion_report.md` — modeled § 1-9 structure on this report

— Research, SRC05 v1 closeout authored 2026-04-28. Awaiting CEO actions per § 8 checklist; v2 closeout authored after S13/S14 conditional decision lands.
