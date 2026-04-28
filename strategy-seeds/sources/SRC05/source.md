---
source_id: SRC05
tier: T1                                      # curated local PDF (OWNER-supplied)
parent_issue: QUA-352
status: scaffolded_and_first_pass_in_progress
authored-by: Research Agent
last-updated: 2026-04-28
budget_tracking:
  heartbeats_used: 4                          # h1 scaffold + 4-card extraction batch (S01, S02, S05, S06); h2 single-symbol-futures batch (S07, S08, S09); h3 intraday-gap batch (S12 single-symbol opening-gap + S03 cross-sectional buy-on-gap); h4 multi-stock-universe / cross-sectional-momentum batch (S04 SPY-arb + S10 XS futures momentum + S11 XS stock momentum)
  cards_drafted: 12                           # S01 chan-at-bb-pair, S02 chan-at-kf-pair, S05 chan-at-fx-coint-pair, S06 chan-at-cal-spread (h1 commits 23bd5a7 + 30e048c + a2d2f2a) + S07 chan-at-ts-mom-fut, S08 chan-at-roll-arb-etf, S09 chan-at-vx-es-roll-mom (h2 commit 7ff7d27) + S12 chan-at-fstx-gap-mom, S03 chan-at-buy-on-gap (h3 commit b810b18) + S04 chan-at-spy-arb, S10 chan-at-xs-mom-fut, S11 chan-at-xs-mom-stock (h4 batch this commit)
  cards_passed_g0: 0
  cards_killed_pre_p1: 0
extraction_pass_status: unconditional_extraction_complete  # 12/12 unconditional cards drafted across h1-h4. Remaining: S13/S14 conditional pending CEO ratification of darwinex_native_data_only exception per § 6 vocab-gap proposals + § 8 step 5; OR completion-report drafting if CEO declines conditional batch.
completion_report: pending                    # authored after all SRC05_S* sub-issues close

---

# SRC05 — Ernest P. Chan, *Algorithmic Trading: Winning Strategies and Their Rationale*

QUA-352 is the parent SRC issue per [DL-032](/QUA/issues/QUA-273) (CEO Autonomy Waiver v3 — autonomous source-queue ordering and per-batch source approval) and Process 13 (one-source-at-a-time, child sub-issue per strategy). Source rank: T1 Tier A, `proposed_order = 5` per [`SOURCE_QUEUE.md`](../SOURCE_QUEUE.md). Opened 2026-04-28 by CEO after SRC04 Lien ratification on QUA-333 closeout (CEO comment `6457c9fc`).

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: TBD                              # populated per-card with chapter + section + PDF page on extraction
    quality_tier: A                            # peer-known practitioner; founder of QTS Capital Management; Caltech PhD; widely-cited author of three Wiley-Trading books on quantitative/algorithmic trading; the first book (Quantitative Trading, 2009 = SRC02) was the founding extraction in V5 SRC02 batch
    role: primary
```

**Disambiguation from SRC02 Chan QT (Chan, 2009).** Chan AT (2013) is the same author's second Wiley book, published 4 years after Chan QT. Per QUA-352 description: "Chan QT (2009) was statistical-arbitrage focused — cointegration, factor models, multi-stock cross-section, commodity seasonals. Chan AT (2013) was published 4 years later and emphasizes algorithmic-execution methodology, mean-reversion vs momentum framing, market-microstructure trade implementation. Two distinct books with limited card-overlap risk." This holds in the survey: Chan AT covers Bollinger-band/Kalman-filter MR techniques (Ch3), futures calendar spreads (Ch5), interday/intraday momentum strategies (Ch6/Ch7) that are NOT in Chan QT. The single overt overlap is Ex 4.3 — Khandani-Lo cross-sectional MR — which Chan AT itself cites as "Example 3.7 of Chan, 2009; original paper is Khandani and Lo, 2007" (PDF p. 102) → SKIP per Rule 1 / DL-033 (already extracted as `chan-khandani-lo-mr` SRC02_S03).

## 2. Source-text status

```yaml
source_text_path: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Algorithmic Trading_ Winning St - Ernie Chan.pdf"
file_size_bytes: 9150037                       # 8.7 MB
file_modified: 2025-04-28                      # per ls -la mtime
text_extraction_method: poppler `pdftotext -layout` (verified text-clean across the entire 9442-line dump; book is text-rendered, not image-scanned)
status: on_disk_text_clean
```

**Extraction quality.** Unlike SRC03 Williams (which had image-scanned pages 47+), Chan AT is a text-rendered PDF and `pdftotext -layout` produces clean output across all 210 PDF pages (printed-book pagination 1-201 + front-matter + index). MATLAB code blocks are inline in the text and faithfully extracted; figure references (cumulative-returns curves, equity curves) are captioned but the figure raster content itself is omitted (acceptable — the rules and verbatim performance claims are in the captioned text).

Raw text excerpts archived under `raw/`:

- `raw/full_text.txt` — full PDF text dump (9442 lines)
- `raw/toc_pp1-12.txt` — front matter, copyright, dedication, contents, preface (PDF pp. 1-12)
- `raw/ch2_3_pp39-90.txt` — Chapter 2 *The Basics of Mean Reversion* + Chapter 3 *Implementing Mean Reversion Strategies* (PDF pp. 39-90); Examples 2.1-2.8 (mostly methodology demos) + Examples 3.1-3.3 (practical MR strategies)
- `raw/ch4_5_pp87-132.txt` — Chapter 4 *Mean Reversion of Stocks and ETFs* + Chapter 5 *Mean Reversion of Currencies and Futures* (PDF pp. 87-132); Examples 4.1-4.4 + 5.1-5.4
- `raw/ch6_7_pp133-168.txt` — Chapter 6 *Interday Momentum Strategies* + Chapter 7 *Intraday Momentum Strategies* (PDF pp. 133-168); Examples 6.1-6.2, 7.1-7.2 + multiple inline strategies (XLE-USO arb, VX-ES roll mom, leveraged ETF rebalance, HFT family)

Chapter 1 (Backtesting and Automated Execution, pp. 1-38) is methodology-only (no strategy candidates) — Example 1.1 is a kurtosis-simulation methodology demo for backtesting statistical-significance. Chapter 8 (Risk Management, pp. 169-186) is methodology-only — Examples 8.1-8.2 cover constant-leverage implications + Kelly capital allocation.

## 3. Why Chan AT #5 (per QUA-352)

Per QUA-352 description and `SOURCE_QUEUE.md` row 5:

- Chan AT was originally proposed as SRC01 ("Deferred from #1 because Davey is more procedurally aligned with the V5 build pipeline; Chan AT is still A-tier and processed early"). Reaching it after SRC01-04 (Davey, Chan QT, Williams, Lien) preserves the originally-justified A-tier early slot.
- **Diversity-bias check passes** — SRC04 Lien was forex-specialist (10 cards heavily forex-rules-tight). Chan AT is methodology + algorithmic-trading focused; closer texture to SRC02 Chan QT but with stronger algorithmic-execution and mean-reversion-framing emphasis. Predicted yield 5-8 cards (per QUA-352 prediction); survey-pass identified 14 candidates with ~10 surviving as cards (§ 6).
- **Disambiguation from SRC02 Chan QT confirmed** at survey-pass: only Ex 4.3 (Khandani-Lo) is a direct duplicate (Chan cites his own prior book + the original Khandani-Lo paper). All other 13 candidates introduce mechanisms or instrument-classes not extracted in SRC02.

## 4. Expected strategy count

Chan AT is **methodology-rich + strategy-rich**. Unlike Davey (process textbook, 5 cards) or pure rule-tight texts like Williams (15 cards), Chan AT mixes 12-14 numbered "Example X.Y" boxes with several inline strategies named-but-not-numbered. Per **DL-033 Rule 1** (every distinct mechanical strategy that passes V5 hard rules gets a card; pipeline G0 → P10 is the filter, not Research's prior beliefs), Research extracts cards for each.

```yaml
expected_strategy_count: 5-8                   # CEO prediction in QUA-352; survey-pass identified 14 candidates with ~10 surviving — discrepancy noted, drives § 6 fold/SKIP decisions
expected_chapter_count: 6                      # Ch2-7 are strategy-bearing; Ch1 + Ch8 methodology-only
strategy_locations:
  - "PDF p. 49 — Ex 2.5: USD.CAD linear MR (single-leg). DISQUALIFIED — author candor: 'I certainly don't recommend it as a practical trading strategy.' SKIP."
  - "PDF p. 59 — Ex 2.8: EWA-EWC-IGE Johansen triplet linear MR. DISQUALIFIED — author candor: 'obviously not a practical strategy, at least in its simplest version'; the practical version is Ex 3.2 Bollinger band on the same/similar pairs. SKIP (folded into S01)."
  - "PDF p. 67 — Ex 3.1: Trading Price Spread / Log Price / Ratio (GLD-USO). METHODOLOGY-COMPARISON demo, NOT a standalone strategy (compares 3 spread definitions). SKIP."
  - "PDF p. 71 — Ex 3.2: Bollinger Band MR on Pair Spread (GLD-USO). STRATEGY S01."
  - "PDF p. 78 — Ex 3.3: Kalman Filter MR on Pair Spread (EWA-EWC). STRATEGY S02."
  - "PDF p. 94 — Ex 4.1: Buy-on-Gap MR on SPX Stocks. STRATEGY S03."
  - "PDF p. 98 — Ex 4.2: SPY vs Components Cointegration Arbitrage. STRATEGY S04."
  - "PDF p. 103 — Ex 4.3: Khandani-Lo Linear Long-Short Stocks. SKIP — Chan cites 'Example 3.7 of Chan, 2009; original paper is Khandani and Lo, 2007' = SRC02_S03 chan-khandani-lo-mr. DUPLICATE."
  - "PDF p. 104 — Ex 4.4: Intraday Linear Long-Short Stocks (overnight return ranking, intraday liquidation). FOLD-CANDIDATE: variant of Ex 4.3 with intraday execution lifecycle. Lean: SKIP (variant of SKIPped duplicate); CEO discretion if to flag as `_v2` of SRC02_S03 chan-khandani-lo-mr."
  - "PDF p. 111 — Ex 5.1: USD.AUD vs USD.CAD Pair via Johansen. STRATEGY S05."
  - "PDF p. 114 — Ex 5.2: AUD.CAD direct cross-rate with rollover interest (variant of Ex 5.1). FOLD into S05 as parameter set 'direct cross-rate variant + rollover interest filter'."
  - "PDF p. 119 — Ex 5.3: Estimating spot/roll returns. METHODOLOGY (no trading rules). SKIP."
  - "PDF p. 124 — Ex 5.4: CL 12-month Calendar Spread MR. STRATEGY S06 (with VX calendar-spread variant as parameter set)."
  - "PDF p. 138 — Ex 6.1: TU Time-Series Momentum (250-day lookback, 25-day hold). STRATEGY S07 (with Table 6.2 generalization to BR/HG as parameter set)."
  - "PDF p. 141 — Inline: XLE-USO Roll-Return Arbitrage (long XLE / short USO under contango). STRATEGY S08."
  - "PDF p. 143 — Inline: VX-ES Roll-Return Momentum (Simon-Campasano). STRATEGY S09."
  - "PDF p. 145 — Inline: Cross-Sectional Futures Momentum (Daniel-Moskowitz, top/bottom future by 12-month return). STRATEGY S10."
  - "PDF p. 146 — Ex 6.2: Cross-Sectional Stock Momentum (Daniel-Moskowitz adapted to S&P 500, top/bottom decile by 12-month return). STRATEGY S11."
  - "PDF pp. 149-150 — Inline: Mutual Fund Flow-Pressure Momentum (Coval-Stafford). DISQUALIFIED — requires CRSP fund-holdings data ($10K/yr, NOT Darwinex-native per `darwinex_native_data_only` Hard Rule). SKIP."
  - "PDF p. 156 — Ex 7.1: FSTX Opening Gap Momentum (gap > 0.1·90d_stdev → enter direction at open, exit at close). STRATEGY S12 (with GBPUSD generalization as parameter set)."
  - "PDF p. 160 — Ex 7.2: PEAD (Post-Earnings Announcement Drift). STRATEGY-CANDIDATE-CONDITIONAL — requires earnings-calendar data (NOT in Darwinex-native feed). Flag `darwinex_native_data_only` at risk. S13 if CEO accepts the calendar-data exception, else SKIP."
  - "PDF p. 163 — Inline: Leveraged ETF Rebalance Momentum (DRN intraday return >2% threshold near market close). STRATEGY-CANDIDATE-CONDITIONAL — requires US-listed leveraged ETF (Darwinex universe lacks 3x leveraged sector ETFs like DRN). Flag `darwinex_native_data_only` + `dwx_suffix_discipline` at risk. S14 if CEO accepts an instrument-substitution path (e.g., test on a synthetic leveraged proxy of US500.DWX), else SKIP."
  - "PDF pp. 165-168 — HFT family (ratio trade / ticking / flipping / momentum ignition / stop hunting / order flow). DISQUALIFIED — V5 hard-fail by `scalping_p5b_latency` AND insufficiently mechanical (no concrete parameters, requires direct exchange-feed access). SKIP."

notes: |
  Chan AT distinguishes between *demonstration* strategies (Ex 2.5, 2.8, 3.1) where the author
  explicitly disqualifies the strategy as "not a practical strategy" and *prototype* strategies
  (Ex 3.2, 3.3, 4.1, 4.2, 5.1, 5.4, 6.1, 6.2, 7.1, 7.2 + several inline) which are practical
  candidates. Per **BASIS rule** (Research preserves verbatim author claims with citation), the
  demonstration strategies are honestly DISQUALIFIED-AT-SOURCE and Research SKIPs them with the
  author-quoted rationale on the source.md log; not extracted to cards.

  The Khandani-Lo direct-citation duplicate (Ex 4.3) is the cleanest example of the cross-source
  Rule 1 lookup: SRC02_S03 chan-khandani-lo-mr's first source_citation entry is
  `Chan, Ernest P. (2009). Quantitative Trading. Wiley.` and Chan AT (2013) explicitly references
  it on PDF p. 102: "I described in my previous book just such a strategy proposed by Khandani
  and Lo (Example 3.7 of Chan, 2009; original paper is Khandani and Lo, 2007)." Per Process 13 §
  Strategy lineage: "Same source = `_v2`; different source = new card. The test is *where the
  insight came from*, not how similar the EA looks." Khandani-Lo's insight came from
  Khandani-Lo (2007) → already extracted from SRC02 → SRC05 SKIP.

  Conditional V5-architecture-fit cards (S13 PEAD, S14 Leveraged ETF Rebalance) require
  CEO ratification of either a non-Darwinex-native data exception (earnings calendar / leveraged
  ETF universe) or an instrument-substitution path (proxy on Darwinex-native instruments). If
  CEO declines both, these are SKIP'd with rationale; if accepted, they're cards with explicit
  hard-rule-at-risk flagging.

  Multi-stock-universe cards (S03, S04, S10, S11) inherit the same V5-architecture-CHALLENGED
  status as SRC02_S03 chan-khandani-lo-mr / SRC02_S04 chan-pca-factor / SRC02_S05
  chan-january-effect / SRC02_S06 chan-yoy-same-month — V5 must either (a) implement a
  portfolio-of-N-symbols framework or (b) score these as architecture-pending until that
  framework lands. Cards drafted regardless per Rule 1; pipeline gates do the filtering.

  Rule 1 binds: every distinct mechanical strategy that passes V5 hard rules gets a card.
  Pipeline gates do the filtering. Research extracts; CEO + Quality-Business + CTO ratify per
  process 13.
```

## 5. v0 filter rules applied to this source

Inherited from QUA-352 acceptance criteria + DL-029 strategy-research workflow + DL-033 Rule 1 + the v5_flags conventions in `SOURCE_QUEUE.md`:

- **Mechanical only** — Chan AT's Examples are MATLAB-coded with concrete parameter values (entryZscore=1, lookback=20, holddays=25, etc.). All mechanical and MQL5-implementable. The HFT family (PDF pp. 165-168) is the only descriptive non-mechanical content; SKIPped per § 4.
- **No Machine Learning** — Chan AT predates the modern ML wave and explicitly avoids ML for the strategies presented. The closest is "PCA factor model" (cited from Chan QT), already in SRC02. `EA_ML_FORBIDDEN` does NOT bind for SRC05.
- **`.DWX` suffix discipline** — Chan AT's universe is heavily US ETF / equity / US futures (SPY, GLD, USO, EWA, EWC, IGE, XLE, FSTX, DRN, ES, VX, CL, TU, BR, HG). V5 deployment maps to Darwinex spot FX / indices / metals / futures-CFDs (`EURUSD.DWX`, `GOLD.DWX`, `US500.DWX`, etc.). Per-card § 11 flags `dwx_suffix_discipline` for cards where the source instrument has no clean Darwinex equivalent (S08 XLE-USO arb, S14 leveraged DRN, S04 SPY-Components — all multi-stock or US-ETF-specific).
- **`darwinex_native_data_only` Hard Rule** — Chan AT cites: earnings calendar data (S13 PEAD), CRSP fund-holdings data (mutual fund flow pressure — SKIPped), news-sentiment scores (Hafez-Xie cross-sectional momentum, RavenPack — methodology-mentioned, no specific strategy). Per-card flagging at extraction.
- **Magic-formula registry compatible** — Chan AT's strategies are all single-position-at-a-time at the symbol or pair level (S01-S09, S12-S14), or universe-cross-sectional (S03, S04, S10, S11) which require a different magic-schema treatment per the V5 architecture-pending list. Compatible with `one_position_per_magic_symbol` for single-symbol/pair cards; flagged for universe cards.
- **News-compliance compatible** — Most of SRC05's strategies are calendar-driven (Ex 7.1 opening gap), event-driven on calendar-known events (Ex 7.2 PEAD — earnings, Ex 6.1 TU momentum — daily roll), or unconditional MR/momentum (S01-S07). P8 News Impact handles standard high-impact-news pauses.
- **Friday Close compatibility** — Most cards Friday-close-compatible. Calendar spread cards (S06 CL/VX) hold positions across multiple weeks; flag `friday_close` for review at extraction.
- **`scalping_p5b_latency`** — None of S01-S14 are scalping-class (all daily-bar or open-of-day execution; PEAD is intraday but open-to-close hold). HFT family (SKIPped) is scalping. Flag does not bind for the surviving cards.

## 6. Sub-issue queue (per QUA-352 process-13 setup)

Per QUA-352 acceptance: "Each candidate that survives V5 v0_filter becomes a SRC05_S* child card and is opened with CEO G0 review." Slot table populated as cards are drafted. Slug pattern: `chan-at-<topic>` (matching SRC02 `chan-<topic>` pattern, with `-at-` suffix to disambiguate from Chan QT). Filenames follow `_TEMPLATE.md` (`<slug>_card.md`).

| Slot | Strategy slug | Card path | Sub-issue | Status | Source location | Notes |
|---|---|---|---|---|---|---|
| S01 | `chan-at-bb-pair` | `strategy-seeds/cards/chan-at-bb-pair_card.md` | TBD (h1 extraction) | DRAFT-PENDING | PDF p. 71 (Ex 3.2) | Bollinger-band mean-reversion on a regression-hedge-ratio pair spread (GLD-USO source case, generalizable to any cointegrating pair). entryZscore=1, exitZscore=0, lookback=20, dynamic OLS hedge ratio. APR 17.8%, Sharpe 0.96. Distinct from SRC02 chan-bollinger-es (single-leg ES M5 ±2σ). Reuses `cointegration-pair-trade` (entry mechanism via spread) + `zscore-band-reversion` (band trigger) + new `mean-reach-exit` (already V5-vocab). |
| S02 | `chan-at-kf-pair` | `strategy-seeds/cards/chan-at-kf-pair_card.md` | TBD (h1 extraction) | DRAFT-PENDING | PDF p. 78 (Ex 3.3) | Kalman-filter dynamic hedge ratio + dynamic mean + dynamic forecast-error variance MR on a pair (EWA-EWC source case). Entry: e(t) < -sqrt(Q(t)) for long, e(t) > sqrt(Q(t)) for short. Exit: e(t) crosses opposite. Parameters δ=0.0001, Vε=0.001 (training-set tuned). APR 26.2%, Sharpe 2.4. **Vocab gap candidate: `kalman-filter-mr`.** |
| S03 | `chan-at-buy-on-gap` | `strategy-seeds/cards/chan-at-buy-on-gap_card.md` | TBD (h3 extraction) | DRAFT (h3 commit pending) | PDF p. 94 (Ex 4.1) | Cross-sectional gap-down + above-MA + top-N selection on SPX universe. Buy at open if open < prev_low × (1 - entryZscore × 90d_stdev) AND open > 20d_MA; pick top-N most-negative-gap stocks; exit at close. APR 8.7%, Sharpe 1.5. Multi-stock-universe (V5-architecture-CHALLENGED — same as SRC02 chan-khandani-lo-mr). Reuses existing `cross-sectional-decile-sort` flag with extension parameters `weighting_scheme=top-N-screen` + `ranking_metric=prior-low-to-open-gap-return`. |
| S04 | `chan-at-spy-arb` | `strategy-seeds/cards/chan-at-spy-arb_card.md` | TBD (h4 extraction) | DRAFT (h4 commit pending) | PDF p. 98 (Ex 4.2) | Cointegration arbitrage between SPY and a Johansen-selected long-only basket of 98 SPX-component stocks that individually cointegrate with SPY. Linear MR on log market value of long-short portfolio (lookback=5 fixed-with-hindsight per Chan p. 100, training set 2007-01-01 to 2007-12-31, test 2008-01-02 to 2012-04-09). APR 4.5%, Sharpe 1.3. Reuses `cointegration-pair-trade` flag (basket-vs-ETF cardinality extension) + `zscore-band-reversion`. Multi-stock-universe (V5-architecture-CHALLENGED). |
| S05 | `chan-at-fx-coint-pair` | `strategy-seeds/cards/chan-at-fx-coint-pair_card.md` | TBD | DRAFT-PENDING | PDF pp. 111 + 114 (Ex 5.1 + Ex 5.2 folded) | Linear-MR pair trading on currency pair via Johansen-derived non-unity hedge ratio (USD.AUD vs USD.CAD source case; trainlen=250, lookback=20). APR 11%, Sharpe 1.6 for Ex 5.1 form; APR 6.2%, Sharpe 0.54 for direct-cross-rate Ex 5.2 form (with rollover interest). Distinct from SRC02 chan-pairs-stat-arb (which is GLD/GDX equity ETF pair via cadf, not currency pair via Johansen). |
| S06 | `chan-at-cal-spread` | `strategy-seeds/cards/chan-at-cal-spread_card.md` | TBD | DRAFT-PENDING | PDF p. 124 (Ex 5.4) | Linear-MR on futures calendar spread (CL 12-month spread source case + VX back/front-ratio variant). Long far + short near contracts; signal = Z-score of γ (roll return) over halflife=36 lookback. APR 8.3%, Sharpe 1.3 (CL); APR 17.7%, Sharpe 1.5 (VX). **Vocab gap candidate: `calendar-spread-mr`.** |
| S07 | `chan-at-ts-mom-fut` | `strategy-seeds/cards/chan-at-ts-mom-fut_card.md` | TBD (h2 extraction) | DRAFT (h2 commit pending) | PDF p. 138 (Ex 6.1) + Table 6.2 | Time-series momentum on a single futures contract: long if price > price-N-days-ago, short if price < price-N-days-ago, hold for M days, daily-rebalanced 1/M-allocation overlap. Source defaults: TU (250/25), BR (100/10), HG (40/40). APR 1.7-18%, Sharpe ≈1.1 across the 3-symbol table. **Vocab gap candidate: `time-series-momentum`.** |
| S08 | `chan-at-roll-arb-etf` | `strategy-seeds/cards/chan-at-roll-arb-etf_card.md` | TBD (h2 extraction) | DRAFT (h2 commit pending) | PDF p. 141 (inline) | ETF-vs-future roll-return arbitrage (XLE-USO source case, also applicable to GLD-GC variant): short USO + long XLE whenever CL is in contango; mirror in backwardation. Direction set by sign of computed roll return γ from Ex 5.3 estimator. APR 16%, Sharpe ≈1 (XLE-USO). **Vocab gap candidate: `futures-roll-return-arb`.** |
| S09 | `chan-at-vx-es-roll-mom` | `strategy-seeds/cards/chan-at-vx-es-roll-mom_card.md` | TBD (h2 extraction) | DRAFT (h2 commit pending) | PDF p. 143 (inline) | VX-ES roll-return momentum (Simon-Campasano 2012 derivative): if VX_front > VIX + 0.1·DTS (contango proxy) → short 0.3906 VX + short 1 ES; mirror if VX_front < VIX − 0.1·DTS (backwardation). Hold 1 day. APR 6.9%, Sharpe 1. Reuses `futures-roll-return-arb` flag (S08) with momentum-direction-go-with framing. |
| S10 | `chan-at-xs-mom-fut` | `strategy-seeds/cards/chan-at-xs-mom-fut_card.md` | TBD (h4 extraction) | DRAFT (h4 commit pending) | PDF p. 145 (inline, Daniel-Moskowitz) | Cross-sectional futures momentum: rank universe of 52 commodity futures by 252-day lagged return; long top-1 + short bottom-1 (or top/bottom decile), hold 25 days with daily 1/holddays overlap-rebalance. APR 18%/Sh 1.37 (2005-07), then -33% APR (2008-09 crisis — Chan p. 145 in-source declaration of P5c crisis-slice failure). **NEW VOCAB: `cross-sectional-momentum`** (sibling of existing `cross-sectional-decile-sort` MR — opposite direction). |
| S11 | `chan-at-xs-mom-stock` | `strategy-seeds/cards/chan-at-xs-mom-stock_card.md` | TBD (h4 extraction) | DRAFT (h4 commit pending) | PDF p. 146 (Ex 6.2, Daniel-Moskowitz S&P 500 adaptation) | Cross-sectional stock momentum: rank S&P 500 by 252-day lagged return; long top-50 + short bottom-50, hold 25 days with daily 1/holddays overlap-rebalance. APR 37%/Sh 4.1 (May-Dec 2007 short-window — sample-size-suspicious); Daniel-Moskowitz long-window 1947-2007 = APR 16.7%/Sh 0.83. APR -30% (2008-09 crisis). Reuses S10 `cross-sectional-momentum` flag with stock-universe parameter. Distinct from S10 by universe class (stocks vs futures) and per Chan p. 146 different causal explanation (slow news diffusion vs roll-return persistence). |
| S12 | `chan-at-fstx-gap-mom` | `strategy-seeds/cards/chan-at-fstx-gap-mom_card.md` | TBD (h3 extraction) | DRAFT (h3 commit pending) | PDF p. 156 (Ex 7.1) | Opening-gap momentum (go-with the gap, not fade): long if open > prev_high × (1 + 0.1·90d_stdev); short mirror; exit at close. FSTX source case + GBPUSD generalization (5am-ET London open / 5pm-ET NY close). APR 13%, Sharpe 1.4 (FSTX); APR 7.2%, Sharpe 1.3 (GBPUSD). **Vocab gap candidate: `opening-gap-momentum`** (sibling of existing `gap-fade-stop-entry` — opposite direction; AND distinct from `vol-expansion-breakout` because referenced extreme is prior_high/prior_low, not next-bar-open + N%·prior-range). Ch 8 cross-reference (constant-leverage degradation: APR 13%→2.6%, Sharpe 1.4→0.16) noted in card §9 as P5 stress evidence. |
| S13 | `chan-at-pead` | `strategy-seeds/cards/chan-at-pead_card.md` (CONDITIONAL) | TBD | DRAFT-PENDING-or-SKIP | PDF p. 160 (Ex 7.2) | Post-Earnings Announcement Drift: earnings announced after prev_close + before today_open → measure overnight return relative to 90d_stdev; long if return > 0.5·stdev, short if < -0.5·stdev; exit at close. APR 6.7%, Sharpe 1.5. **Hard-rule-at-risk: `darwinex_native_data_only` (requires earnings-calendar data feed).** Strategy is technically extractable as a card; CEO ratifies whether the calendar-data dependency is acceptable for V5 build queue. **Vocab gap candidate: `event-driven-momentum`.** |
| S14 | `chan-at-lev-etf-rebal` | `strategy-seeds/cards/chan-at-lev-etf-rebal_card.md` (CONDITIONAL) | TBD | DRAFT-PENDING-or-SKIP | PDF p. 163 (inline) | Leveraged-ETF MOC rebalancing momentum: buy DRN (3x REIT ETF) if return prev_close → T-15min > 2%, sell if < -2%, exit at close. APR 15%, Sharpe 1.8. **Hard-rule-at-risk: `darwinex_native_data_only` AND `dwx_suffix_discipline` (Darwinex universe lacks 3x leveraged sector ETFs).** Strategy extractable as concept-card; CEO ratifies whether to attempt instrument-substitution (e.g., synthetic 3x proxy on US500.DWX) or SKIP. **Vocab gap candidate: `leveraged-etf-rebalance-momentum`.** |

Slot count expected: **12 cards (S01-S12 unconditional) + 2 cards (S13-S14 conditional on CEO ratification)**, vs QUA-352's 5-8 prediction. The discrepancy is driven by:
- Inline strategies (S08 XLE-USO, S09 VX-ES, S10 XS futures, S14 leveraged ETF) which are not in numbered Examples but are concrete mechanical strategies with stated rules + performance.
- Folded variants kept (Ex 5.1 + 5.2 → S05; Table 6.2 generalization in S07; CL + VX in S06; FSTX + GBPUSD in S12) — saves card-count vs splitting.

Disambiguation against SRC02 cards (sanity check):

- SRC02 chan-pairs-stat-arb (GLD/GDX cadf 2-leg pair) ≠ S05 chan-at-fx-coint-pair (currency Johansen 2-leg pair) — different asset class + different cointegration test
- SRC02 chan-bollinger-es (M5 ES single-leg ±2σ) ≠ S01 chan-at-bb-pair (daily pair-spread ±1σ) — different cardinality (single-leg vs pair) + different timeframe class
- SRC02 chan-khandani-lo-mr (daily SPX cross-sectional MR) = Ex 4.3 — DUPLICATE; SKIP at SRC05
- SRC02 chan-pca-factor (PCA factor cross-sectional) ≠ S10/S11 chan-at-xs-mom — opposite direction (MR vs momentum) + different ranking metric
- SRC02 chan-january-effect (Jan small-cap decile by Dec return) ≠ S11 chan-at-xs-mom-stock — different cycle (annual calendar vs rolling 252-day) + opposite direction (calendar MR vs momentum)
- SRC02 chan-yoy-same-month (year-ago-same-month cycle decile sort) ≠ S10/S11 — different cycle (annual repeat vs rolling lookback)
- SRC02 chan-gasoline-rb-spring / chan-natgas-spring (annual fixed-date commodity seasonals) ≠ anything in SRC05

S04 vs SRC02 chan-pairs-stat-arb fold-vs-distinct: S04 is a basket-vs-ETF (98-stock basket cointegrating with SPY via Johansen), while SRC02_S01 is a 2-instrument cadf pair. Cardinality and method differ → DISTINCT.

**Running vocabulary-gap proposals (SRC05 first-pass: 7 entry/exit-side gaps)** — per-card § 16 details; batch-proposed to CEO + CTO via `strategy_type_flags.md` addition-process when extraction stabilizes:

1. `kalman-filter-mr` (S02) — entry mechanism: dynamic-state-space hedge ratio + mean + forecast-error variance, with entries triggered on the standardized prediction error e(t) crossing ±√Q(t) (one stdev band). Distinct from `cointegration-pair-trade` (static hedge from regression/Johansen) and `zscore-band-reversion` (single-leg own moving statistics, no state-space estimator).
2. `calendar-spread-mr` (S06) — entry mechanism: cross-maturity futures spread (long far + short near) as the mean-reverting series; signal = Z-score of estimated roll-return γ over a halflife-derived lookback. Distinct from `cointegration-pair-trade` (linear-combo of two assets where the spread is presumed stationary; calendar spread relies on roll-return mean reversion specifically, not on cointegration).
3. `futures-roll-return-arb` (S08, S09) — entry mechanism: position direction set by sign of computed futures roll return γ; long the spot/proxy + short the future when γ < 0 (contango); mirror when γ > 0 (backwardation). Distinct from `carry-direction` (carry sets direction on a single instrument; roll-return-arb pairs a future with a non-future-carrying instrument and trades the difference).
4. `time-series-momentum` (S07) — entry mechanism: long if price[t] > price[t-N], short if price[t] < price[t-N], hold for M days, daily-rebalanced 1/M-allocation overlap. Distinct from `donchian-breakout` (no rolling N-bar extreme, just a single price-vs-N-ago comparison) and `n-period-max-continuation` (no N-bar-max requirement, just a price-vs-N-ago direction; longer hold M).
5. `cross-sectional-momentum` (S10, S11) — entry mechanism: rank universe by N-day lagged return; long top-decile/top-N + short bottom-decile/bottom-N, hold M days. Sibling of existing `cross-sectional-decile-sort` (MR direction) — `cross-sectional-momentum` is the OPPOSITE direction (buy winners, sell losers). May be the cleanest path: unify both into one `cross-sectional-rank` flag with direction parameter, OR keep as separate flags. Recommendation: separate flags (matches V4 sibling-flag-not-generalize precedent for `intraday-day-of-month` / `intraday-day-of-week` sibling-additive pattern from SRC03 closeout).
6. `opening-gap-momentum` (S12) — entry mechanism: long if open > prev_high × (1 + N·90d_stdev), short if open < prev_low × (1 - N·90d_stdev), exit at close. Sibling of existing `gap-fade-stop-entry` (which is gap-FADE, opposite direction); distinct from `vol-expansion-breakout` (next-bar open + N%·prior-range; gap-momentum compares prev-bar-extreme not next-bar-open).
7. `event-driven-momentum` (S13, conditional) — entry mechanism: gap-direction momentum gated on a calendar-known corporate or macroeconomic event (earnings, M&A, index inclusion change, FOMC). Distinct from `opening-gap-momentum` (event-conditional vs unconditional) and `news-blackout` (which is a no-trade filter, not an entry trigger).

Optional vocab gap (S14 conditional):

8. `leveraged-etf-rebalance-momentum` (S14, conditional) — close-of-day momentum strategy specifically based on the deterministic rebalance flow of leveraged ETFs (LETF returns near MOC drive same-direction stock momentum). Distinct from `time-series-momentum` (this is intraday, leveraged-ETF-specific, with a fixed return-threshold trigger).

**Filters NOT extracted as separate cards** (Chan AT Chapter 1 backtesting methodology + Chapter 8 risk management — integrated into per-card § 6 Filters where applicable, or referenced as framework-level):

- Chapter 1: Backtesting hygiene (look-ahead bias avoidance, primary-vs-consolidated price selection, transaction-cost overlay) — V5 framework defaults; not a strategy filter.
- Chapter 8: Constant-leverage strategy (Ex 8.1) — methodology-only; covered in V5 framework's `risk_mode_dual` (RISK_PERCENT vs RISK_FIXED) settings.
- Chapter 8: Optimal Kelly capital allocation (Ex 8.2) — methodology-only; covered in V5 portfolio-stage P9 framework.
- Ch4 "Rule 2" momentum filter (price > 20-day MA) — applied within S03 chan-at-buy-on-gap; not a separate card.

These are setup / filter conditions, not entry strategies. Per DL-033 Rule 1, FILTERS are documented per-card under § 6 (Filters / No-Trade module) when they bind to a specific entry strategy, not as separate Strategy Cards.

## 7. Chapter index (validated at survey-pass)

Extracted from PDF pages 1-201 via `pdftotext -layout` 2026-04-28. Page numbers are PDF page numbers (printed-book pagination).

| Chapter | Title | PDF page | Strategy density |
|---|---|---|---|
| Front matter | Title, copyright, contents, preface | 1-12 | NONE |
| Chapter 1 | Backtesting and Automated Execution | 13-50 | NONE (methodology only) |
| Chapter 2 | The Basics of Mean Reversion | 51-74 | LOW (Ex 2.5/2.8 author-disqualified; Ex 2.1-2.4/2.6-2.7 are methodology tests) |
| Chapter 3 | Implementing Mean Reversion Strategies | 75-98 | **HIGH** (S01, S02 source here; Ex 3.1 methodology-comparison) |
| Chapter 4 | Mean Reversion of Stocks and ETFs | 99-118 | **HIGH** (S03, S04 source here; Ex 4.3 SRC02 duplicate; Ex 4.4 fold-into-Ex 4.3 SKIP) |
| Chapter 5 | Mean Reversion of Currencies and Futures | 119-144 | **HIGH** (S05, S06 source here; Ex 5.3 methodology-only) |
| Chapter 6 | Interday Momentum Strategies | 145-166 | **HIGH** (S07, S08, S09, S10, S11 source here) |
| Chapter 7 | Intraday Momentum Strategies | 167-180 | **HIGH** (S12, S13, S14 source here; HFT family SKIPped) |
| Chapter 8 | Risk Management | 181-202 | NONE (methodology only) |
| Back matter | Conclusion, Bibliography, About Author/Website, Index | 203-end | NONE |

Total strategy-bearing chapters: 6 (Ch3-Ch7, plus the "practical version" comment in Ch2 that defers to Ch3). Chapter 5 strategy-density is highest (S05 + S06 = 2 cards).

## 8. Extraction plan

Process 13 / DL-033 / QUA-352 binding constraints:

- One source actively worked at a time. **No SRC06+ until ALL SRC05 sub-issues close.**
- One sub-issue per strategy. First sub-issue `todo`, rest `blocked` with `blockedByIssueIds: [<prev_id>]` populated per DL-029. Status-alone is insufficient; sibling chain MUST be in `blockedByIssueIds`.
- Heartbeat budget: SRC03 yield ratio target was 1.5 cards/heartbeat (achieved 14 cards / 5 heartbeats = 2.8). SRC04 was 10 cards / 5 heartbeats = 2.0. SRC05 target ≥ 1.5 cards/heartbeat given Chan AT's mixed methodology+strategy density. Predicted: 12-14 cards over 6-9 heartbeats.

Extraction sequence:

1. **First pass (h1) — single-pair / single-symbol calling-card MR strategies.** Draft S01 (Bollinger pair), S02 (Kalman pair), S05 (Forex Johansen pair). These are V5-architecture-clean (single-pair = pair-trading magic schema) and the easiest to get to G0 review.
2. **Second pass — single-symbol futures strategies.** Draft S06 (Calendar Spread), S07 (TS Momentum), S08 (XLE-USO Roll Arb), S09 (VX-ES Roll Mom). All single-symbol or 2-symbol-pair strategies on futures or futures-vs-ETF; clean architecture-fit.
3. **Third pass — opening-gap intraday strategies.** Draft S12 (FSTX Opening Gap). Single-symbol intraday open-to-close lifecycle.
4. **Fourth pass — multi-stock-universe strategies (V5-architecture-CHALLENGED).** Draft S03 (Buy-on-Gap Stocks), S04 (SPY Cointegration Arb), S10 (XS Futures Momentum), S11 (XS Stock Momentum). Cards drafted regardless per Rule 1; V5-architecture-fit blocking is downstream concern.
5. **Fifth pass — conditional-data strategies.** Draft S13 (PEAD), S14 (Leveraged ETF Rebal) ONLY IF CEO ratifies the data-dependency exception. Otherwise SKIP with rationale.
6. **Sub-issue creation.** When all candidate cards drafted to DRAFT, open one sub-issue per surviving strategy under QUA-352 — first as `todo`, rest as `blocked` with **populated `blockedByIssueIds: [<prev_id>]` chain** per DL-029. Submit for CEO + Quality-Business G0 review per process 13.

Per-pass progress comments posted to QUA-352 at pass-boundary granularity. No noise comments on individual cards within a pass.

## 9. Completion report contract

When all S-sub-issues under QUA-352 close, Research authors `strategy-seeds/sources/SRC05/completion_report.md` covering at minimum (per QUA-352 acceptance criterion 4):

- Total strategies extracted vs. expected (5-8 per CEO; 12-14 per survey)
- Per-strategy verdict (PASS / FAIL / RETIRED) with terminal pipeline phase
- Skipped strategies (Ex 2.5, 2.8, 3.1, 4.3, 4.4, 5.3, mutual-fund-flow, HFT family) and reason
- **Strategy-type-flag distribution** (per `strategy_type_flags.md` controlled vocabulary; cross-walk vs SRC01 + SRC02 + SRC03 + SRC04 distribution to feed `STRATEGY_TYPE_DISTRIBUTION.md`)
- **Architecture-fit profile** — single-symbol/pair vs multi-stock-universe split, comparison vs SRC02 Chan QT's cross-section-heavy pattern
- Source quality and density observations
- Yield ratio: `cards_passed_g0 / heartbeats_used` for `budget_tracking` review (SRC03 benchmark: 2.8; SRC04 benchmark: 2.0)
- **Vocab-gap additions batch** — 7-8 new flags proposed (kalman-filter-mr, calendar-spread-mr, futures-roll-return-arb, time-series-momentum, cross-sectional-momentum, opening-gap-momentum, event-driven-momentum, optional leveraged-etf-rebalance-momentum) for CEO + CTO ratification per the SRC02/SRC03 batch-ratification precedent
- Recommendation: deeper mining worthwhile? Move on to SRC06 (TBD per CEO autonomy v3, candidates per `SOURCE_QUEUE.md`)?

## 10. Cross-references

- Parent issue: [QUA-352](/QUA/issues/QUA-352)
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
- SRC02 closeout (Chan QT vocab-batch ratification): `strategy-seeds/sources/SRC02/completion_report.md` + QUA-275 + QUA-332 back-port
- SRC03 closeout (Williams vocab-batch ratification + S13 ESCALATE precedent): `strategy-seeds/sources/SRC03/completion_report.md` + QUA-298 + QUA-334/QUA-335 back-port
- SRC04 closeout (Lien forex-rules-tight extraction): `strategy-seeds/sources/SRC04/completion_report.md` + QUA-333
