---
source_id: SRC02
parent_issue: QUA-275
authored_by: Research Agent
authored_on: 2026-04-28
status: drafted_pending_ceo_review
budget_summary:
  heartbeats_used: 7                          # h1 scaffold; h2 S01 + Ex 7.1 SKIP; h3 S02; h4 S07+S08 + HFT/Leverage SKIPs; h5 S05+S06; h6 S03+S04; h7 PEAD SKIP + completion_report
  cards_drafted: 8                            # S01-S08
  cards_passed_g0: 0                          # all DRAFT; awaiting CEO + Quality-Business review
  cards_killed_pre_p1: 0
  yield_ratio_cards_per_heartbeat: 1.14       # 8 / 7 — recompute when G0 ratification lands
  vs_src01_yield: 1.14 / 0.71 = 1.6× SRC01    # SRC02 yield is 60% above SRC01's; primarily because Chan Ch 7 packs ~6 cards into one chapter
---

# SRC02 Completion Report — Chan, *Quantitative Trading: How to Build Your Own Algorithmic Trading Business*

This report closes out SRC02 per `processes/13-strategy-research.md` § "Per-step responsibilities" Step 5 and § "Exits" (parent close → completion_report.md). All chapters and the appendix of the source have been surveyed; **8 Strategy Cards drafted** under V5 schema; **3 strategies / sections classified SKIP** for hard-rule or source-spec-completeness reasons (perceptron NN ML hard-fail; HFT narrative; Leverage methodology); **PEAD reclassified SKIP** for source-spec-completeness (matching SRC01 Davey Ch 1 hogs precedent).

**SRC02 status from Research's side: extraction complete.** Awaiting CEO action on (1) the 8 DRAFT cards (G0 review), (2) the 5 batched controlled-vocabulary additions per `strategy_type_flags.md` addition-process, (3) SRC03 dispatch per QUA-188 waiver v3.

## 1. Source identity (recap)

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: full book (8 chapters + Appendix A MATLAB quick-survey, 175 pages)
    quality_tier: A
    role: primary
```

Source-text on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf` (3.7 MB; `pdftotext -layout` extraction-method verified working on TOC pp. 1-14, Ch 2 pp. 9-30, Ch 3 pp. 31-95, Ch 7 pp. 116-165).

## 2. Strategy harvest

Eight Strategy Cards drafted; full set summarized in the table below. All eight carry `status: DRAFT` and are awaiting CEO + Quality-Business G0 review.

| Slot | Card slug | Source location | Strategy character | Author-claim type | Primary `hard_rules_at_risk` |
|---|---|---|---|---|---|
| S01 | `chan-pairs-stat-arb` | Ex 3.6 + 7.2 + 7.3 + 7.5 + Ch 7 narrative pp. 126-133 | Cointegration pair-trade (cadf filter + OLS hedge-ratio + ±N·σ z-score entry/exit + OU-half-life time-stop) | Real backtest: Sharpe 1.5/2.1 test (default/refined thresholds) on GLD/GDX | `friday_close` (PRIMARY), `dwx_suffix_discipline` (no Darwinex GDX equivalent), `one_position_per_magic_symbol`, `kill_switch_coverage`, `enhancement_doctrine` |
| S02 | `chan-bollinger-es` | Ch 2 pp. 22-23 inline example (NOT labeled Ex 3.x) | Single-symbol M5 Bollinger ±2σ entry / ±1σ exit on E-mini S&P | Author Sharpe: +3 pre-cost / **−3 with 1 bp/trade** — Chan's deliberate FAILURE example #1 (transaction-cost demo) | **`scalping_p5b_latency` (PRIMARY)**, `dwx_suffix_discipline`, `kill_switch_coverage`, `enhancement_doctrine` (lookback unspecified) |
| S03 | `chan-khandani-lo-mr` | Ex 3.7 (close-bar baseline) + Ex 3.8 (open-bar refinement) | Continuous-weight cross-sectional MR; weight ∝ −(r_i − r_market) / N_valid; daily rebalance, dollar-neutral | Author Sharpe: 0.25/−3.19 close-bar; 4.43/**+0.78** open-bar at 5 bp — Chan's transaction-cost-vs-execution-timing demo | `dwx_suffix_discipline` (no Darwinex SP500 cross-section), `one_position_per_magic_symbol` (~500 positions/bar), `darwinex_native_data_only`, `magic_schema` |
| S04 | `chan-pca-factor` | Ex 7.4 | Rolling 252-bar PCA + top-5 eigenvectors as factor exposures + OLS factor returns + project Rexp + long top-50 / short bottom-50 on S&P 600 | Author result: avg ann return = **−1.81%** ("A very poor return!") — Chan's deliberate FAILURE example #2 (factor-momentum-assumption violated) | `dwx_suffix_discipline`, `one_position_per_magic_symbol` (100 positions/bar), `darwinex_native_data_only`, `magic_schema`, `kill_switch_coverage` |
| S05 | `chan-january-effect` | Ex 7.6 | Annual cross-sectional decile MR on S&P 600 small-cap; sort by prior-year annual return, long bottom decile + short top decile, hold Dec close → Jan close | Author 3-year sample (2005-2007): −2.44% / −0.68% / +8.81% (1 winner, 2 losers; +8.81% driven by SocGen tail-event) | `dwx_suffix_discipline`, `one_position_per_magic_symbol`, `friday_close` (4-weekend hold), `darwinex_native_data_only`, `magic_schema` |
| S06 | `chan-yoy-same-month` | Ex 7.7 | Monthly cross-sectional decile momentum on S&P 500; sort by same-month-last-year return, long top decile + short bottom decile | Author result: avg ann return = **−91.67%**, Sharpe = **−0.1055** — Chan's deliberate FAILURE example #3 (Heston-Sadka anomaly decayed post-2002); SP500 snapshot has explicit survivorship bias | `dwx_suffix_discipline`, `one_position_per_magic_symbol`, `friday_close`, `darwinex_native_data_only`, `magic_schema` |
| S07 | `chan-gasoline-rb-spring` | Ch 7 sidebar p. 149 | Long-only annual calendar trade on NYMEX RB unleaded gasoline futures (May expiry); Apr 13 → Apr 25 | Real P&L: **14 consecutive years of profitability 1995-2008**; per-contract P&L from $118 to $6,985, max-DD $2,226 (1996) | **`dwx_suffix_discipline` (PRIMARY G0 BLOCKER — no Darwinex gasoline)**, `friday_close` (waiver required, 9-day hold spans 2 weekends), `kill_switch_coverage`, `magic_schema` (annual cycle) |
| S08 | `chan-natgas-spring` | Ch 7 sidebar p. 150 | Long-only annual calendar trade on NYMEX NG natural gas futures (June expiry); Feb 25 → Apr 15 | Real P&L: 14 consecutive years 1995-2008; per-contract P&L from $450 to $10,137, max-DD $5,550 (2005); 2008 actual-trading hit −$7,470 mid-trade | **`kill_switch_coverage` (PRIMARY OPERATIONAL RISK — Amaranth-class blow-up explicit in Chan p. 150)**, `dwx_suffix_discipline` (no Darwinex natgas), `friday_close` (7-weekend hold), `magic_schema` |

**Total: 8 cards, 8 distinct mechanical structures.** Reasonable harvest density given Chan's methodology-and-toolkit weighting (Ch 1 + Ch 4 + Ch 5 + Ch 6 + Ch 8 + App A are all infrastructure / methodology / memoir).

### Strategy-type-flag distribution (across the 8 drafted cards)

| Flag | S01 | S02 | S03 | S04 | S05 | S06 | S07 | S08 | Count |
|---|---|---|---|---|---|---|---|---|---|
| symmetric-long-short | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | | | 6 |
| signal-reversal-exit | ✓ | ✓ | ✓ | ✓ | | ✓ | | | 5 |
| time-stop | ✓ | | | | ✓ | | ✓ | ✓ | 4 |
| long-only | | | | | | | ✓ | ✓ | 2 |
| scalping | | ✓ | | | | | | | 1 |
| **proposed:** cointegration-pair-trade | ✓ | | | | | | | | 1 |
| **proposed:** mean-reach-exit | ✓ | | | | | | | | 1 |
| **proposed:** zscore-band-reversion | | ✓ | | | | | | | 1 |
| **proposed:** annual-calendar-trade | | | | | | | ✓ | ✓ | 2 |
| **proposed:** cross-sectional-decile-sort | | | ✓ | ✓ | ✓ | ✓ | | | 4 |

Per OWNER 17:28 directive `diversity_bias_rules` (3+ consecutive same-class triggers a switch): SRC02 is **strongly diverse** vs SRC01:
- SRC01 was 4/5 mean-reversion-flagged + 1 trend-following. Concern: too narrow.
- SRC02 covers cointegration-pair-trade (1) + zscore-band-reversion MR (1) + cross-sectional MR/momentum (4) + annual-calendar-trade (2) — 5 distinct strategy families.
- Combined SRC01+SRC02 = ~13 strategies across mean-reversion / momentum / breakout / pair-trade / cross-sectional / calendar / trend-following.

**For SRC03 selection**, the diversity-bias rule does NOT trigger; any T1 Tier A source on the SOURCE_QUEUE is acceptable. SOURCE_QUEUE.md proposed_order #3 is **Williams, *Long-Term Secrets to Short-Term Trading*** — futures breakout strategies (Volatility Breakout being the canonical). Adds another strategy family (short-horizon breakout) to the V5 corpus. Recommendation: dispatch SRC03 against Williams.

### V5-architecture-fit distribution

A useful angle for CEO + CTO ratification of the SRC02 set:

| Architecture-fit | Cards | Recommended G0 path |
|---|---|---|
| **Clean (single-symbol Darwinex CFD)** | S02 chan-bollinger-es | Standard advance through P-pipeline; primary risk is `scalping_p5b_latency` |
| **Flagged (Darwinex symbol mapping issue, but deployable on chosen pair/symbol)** | S01 chan-pairs-stat-arb (deploy on AUDCAD spot or AUDUSD-vs-NZDUSD or GOLD-vs-SILVER, NOT GLD/GDX) | Path 1 — advance with explicit Hard Rule waivers documented; CSR scan over Darwinex-eligible pairs/symbols |
| **Flagged (no native Darwinex commodity-futures product; CFD substitute may exist)** | S07 chan-gasoline-rb-spring, S08 chan-natgas-spring | Path 1 IF Darwinex offers native gasoline/natgas CFDs; else Path 2 |
| **Architecture-incompatible (multi-stock cross-section; Darwinex stack offers no equivalent)** | S03 chan-khandani-lo-mr, S04 chan-pca-factor, S05 chan-january-effect, S06 chan-yoy-same-month | **Path 2 recommended** — document as "V5-architecture-incompatible reference for future broker-expansion"; preserves spec for re-activation when QM acquires multi-stock-equity broker access |

The Path 2 group (4 cards) is a substantive Research finding for SRC02: Chan's most academically-rigorous strategies (cointegration variants, cross-sectional models, factor models) require multi-stock or specialty-futures broker access that V5's Darwinex stack does not provide. This is **expected** — Chan's intended audience is institutional / multi-broker quants — and does not reduce the value of the cards as V5-corpus institutional memory.

## 3. Skipped strategies / sections

| Source location | Reason for skip | Rule-1 classification |
|---|---|---|
| Example 7.1 (pp. 122-126) — "Using a Machine Learning Tool to Profit from Regime Switching in the Stock Market" | **V5 hard-fail per `EA_ML_FORBIDDEN`.** Chan explicitly: "we run a perceptron learning algorithm on the outputs of I7 and I9 (a perceptron is a type of neural network)" (p. 124). Per `strategy_type_flags.md` § E `ml-required` definition, perceptron = neural network = ML. Disambiguation against `hmm-regime-blend` (HMM with EM is allowed) does not save this strategy — perceptron ≠ HMM. | V5 HARD-RULE FAILURE — `ml-required` true. |
| Ch 7 § "High-Frequency Trading Strategies" (pp. 151-153) | **Narrative-only; no specific entry/exit rules.** Chan p. 152 verbatim: "it is impossible to explain in general why high-frequency strategies are often profitable, as there are as many such strategies as there are fund managers." Aligned with `SOURCE_QUEUE.md HFT_NOT_APPLICABLE` flag (V5 stack MT5 + DXZ live-only cannot run HFT competitively). | Source-spec-completeness failure (NOT hard-rule). |
| Ch 7 § "Is It Better to Have a High-Leverage versus a High-Beta Portfolio?" (pp. 153-154) | **Methodology, not a strategy.** Pure portfolio-construction argument (Kelly leverage vs Fama-French beta); no entry/exit/hold rules. | Source-spec-completeness failure. |
| Ch 7 § "Mean-Reverting vs Momentum" PEAD narrative (pp. 117-118) | **Underspecified-beyond-cardable.** Chan describes PEAD direction (long on positive earnings surprise, short on negative) and economic rationale, but explicitly delegates the rest (verbatim p. 118): "As to what kind of news will trigger this, and how long the trending period will last, it is again up to you to find out." Threshold for "exceed expectations", hold period, stop-loss, and universe all undefined. **Same classification as SRC01 Davey Ch 1 hogs** ("Underspecified to the point of being uncardable" — SRC01 source.md). To draft a card would require importing thresholds and hold-period values from the referenced quantlogic.blogspot.com article = Research extrapolation, not Chan extraction. Compounding concern: PEAD also requires per-stock quarterly earnings calendar + analyst-consensus data, neither in Darwinex-native feeds. | Source-spec-completeness failure (NOT hard-rule). |

**4 skips total.** Source-spec-completeness failures (3) are NOT counted against Rule 1's "every distinct mechanical strategy gets a card" mandate, because Chan does not provide a complete mechanical specification for those sections. The single hard-rule failure (Ex 7.1 ML) is the only true exclusion.

## 4. Methodology cross-walk: Chan procedure vs V5 P-stage flow

Chan's *Quantitative Trading* is structurally a process textbook like Davey. Chan's 8-chapter structure maps onto V5's P-stage flow as follows:

### Direct mapping

| Chan | V5 | Notes |
|---|---|---|
| Ch 1 "The Whats, Whos, and Whys of Quantitative Trading" | framing only (pre-G0) | Memoir + business-case discussion; not a P-stage. |
| Ch 2 "Fishing for Ideas" | G0 Strategy Card § 1 (sources) + § 2 (concept) + § 9 (author claims) + V5 Sharpe / DD intro | Chan's Table 2.1 of trading-idea sources mirrors the SOURCE_QUEUE.md tier discipline. Chan p. 17-21 introduces Sharpe ratio + drawdown — V5 Strategy Card § 10 risk profile uses the same metrics. |
| Ch 3 "Backtesting" | P1 Build + P2 Baseline + P3 Sweep + P4 Walk-Forward + P9b Operational Readiness (transaction costs) | Chan Ch 3 covers data, performance measurement, look-ahead-bias, data-snooping bias, transaction costs, strategy refinement — the entire P1-P4 pipeline. Examples 3.6-3.8 are V5-pipeline-grade walkthroughs (data train/test split, sweep-vs-test consistency, cost-sensitivity analysis). |
| Ch 4 "Setting Up Your Business" | not a P-stage | Brokerage choice, retail vs prop firm — operational setup. |
| Ch 5 "Execution Systems" | P10 Shadow Deploy + Live Promotion infrastructure | Automated trading systems, paper trading, expectation-divergence diagnosis. Maps to V5's P10 + monitoring infrastructure. |
| Ch 6 "Money and Risk Management" (Kelly formula) | V5 risk-mode framework + portfolio-level position sizing | Chan's Kelly leverage discussion ≈ V5 risk-mode-percent calibration; explicit warning against over-leverage ("75% max DD acceptable for contest" caveat aligns with SRC01 davey-worldcup `risk_mode_dual` flag). |
| Ch 7 "Special Topics" — section-by-section | (per-section mapping below) | Strategy-rich core of the book; 6 of 8 SRC02 cards source from Ch 7. |
| Ch 7 "Mean-Reverting vs Momentum" | G0 framing + PEAD SKIP entry | Conceptual taxonomy; PEAD narrative documented as SKIP (underspecified). |
| Ch 7 "Regime Switching" + Ex 7.1 | V5 hard-fail (ML) | Perceptron NN → `EA_ML_FORBIDDEN` hard-rule failure; SKIP. |
| Ch 7 "Stationarity and Cointegration" + Ex 7.2/7.3 + Ex 7.5 (S01) | G0 cadf filter at deployment + P3.5 CSR pair-scan + V5 trade_close module (mean-reach + half-life-time-stop) | Cointegration is genuinely net-new vs V4; V5 vocabulary needs `cointegration-pair-trade` + `mean-reach-exit` flags (proposed). |
| Ch 7 "Factor Models" + Ex 7.4 (S04) | P5 Stress + P7 PBO ablation (factor-momentum vs mean-reversion vs shrink-to-zero); cross-sectional ranking primitive | PCA-derived expected-return ranking is a `cross-sectional-decile-sort` family member (5th proposed flag). |
| Ch 7 "What Is Your Exit Strategy?" pp. 140-143 | V5 trade_close module taxonomy | Chan enumerates exit types (fixed-hold / target-price / latest-signal / stop-price). Maps to V5 Strategy Card § 5 exit-rules conventions. |
| Ch 7 "Seasonal Trading Strategies" + Ex 7.6/7.7 + RB/NG sidebars (S05/S06/S07/S08) | V5 calendar-anchored entries (`annual-calendar-trade` 4th proposed flag) + `cross-sectional-decile-sort` 5th proposed flag | Chan distinguishes equity seasonals (decayed, S05/S06) from commodity-futures seasonals ("alive and well", S07/S08). V5 vocabulary needs the `annual-calendar-trade` flag for the commodity-futures family. |
| Ch 7 "High-Frequency Trading Strategies" pp. 151-153 | not applicable (narrative-only SKIP; HFT_NOT_APPLICABLE per SOURCE_QUEUE.md) | V5 stack cannot run HFT. SKIP. |
| Ch 7 "Leverage vs High-Beta Portfolio" pp. 153-154 | V5 risk-mode framework + Kelly formula reference | Methodology comparison; SKIP (not a strategy). |
| Ch 8 "Conclusion: Can Independent Traders Succeed?" | not a P-stage | Memoir + framing. |
| App A "Quick Survey of MATLAB" | not applicable | Programming-language reference. |

### Wins (V5 is more rigorous than Chan)

- **P3.5 CSR pair-scan** — V5's P3.5 explicitly tests strategy edge across instrument variants of the same category. Chan's pair-trade examples (Ex 3.6 GLD/GDX, Ex 7.2 cointegrating portfolios, Ex 7.3 KO/PEP counterexample) are individually-evaluated; V5's P3.5 systematizes the per-strategy pair-scan.
- **P5b Calibrated Noise** — Chan acknowledges transaction costs (Ex 3.7/3.8) and basic slippage but does not test against realistic VPS-latency calibration. V5's P5b is mandatory for scalping-class strategies (S02 chan-bollinger-es flagged).
- **P7 Statistical Validation with PBO < 5% hard gate** — Chan does not formalize a probability-of-overfitting test. He warns about data-snooping bias (Ch 3 pp. 51-54) and proposes sample-size rules of thumb (Ch 3 p. 53: 252 data points per parameter), but no formal PBO gate. V5's P7 is genuinely net-new vs Chan.
- **Cross-walk note for the deliberate-failure cards**: Chan's three deliberate-failure examples (S02 chan-bollinger-es, S04 chan-pca-factor, S06 chan-yoy-same-month) map to **three distinct V5 P-stages** (P9b Operational Readiness, P5/P7 Stress + PBO, P4 Walk-Forward respectively). V5's gate structure correctly captures all three failure modes that Chan documents.
- **`hard_rules_at_risk` declarative system** — Chan covers all the same concerns (no martingale, no over-optimization, transaction-cost honesty, survivorship-bias caveats) but as advice. V5's machine-checkable `hard_rules_at_risk` field on every Strategy Card is structurally more rigorous.

### Regressions (V5 is less rigorous than Chan — none observed)

- None identified. V5's pipeline subsumes Chan's at every gate.

### Neutrals (similar rigor, different mechanics)

- **Cointegration / pair-trade methodology** — Chan Ch 7 cadf-test methodology is mathematically equivalent to what V5 P3.5 would do for any cointegrating-pair candidate. V5 has no separate cointegration step yet because no V4 EA used cointegration; SRC02 surfaces the need.
- **Backtesting look-ahead-bias self-test** — Chan Ch 3 (Ex 3.6 § B.5) prescribes a programmatic test: re-run with N-day truncation, verify position equality. V5 does not yet have this as a formal P-stage step. Recommendation: add to V5 P1 Build Validation as a standard sub-procedure (input to QUA-236 enhancement loop).
- **Cross-sectional weighting schemes** — Chan distinguishes continuous-distance weighting (Ex 3.7 Khandani-Lo) from discrete decile bucketing (Ex 7.6/7.7) by example, not by formal taxonomy. V5's `cross-sectional-decile-sort` proposed flag should formalize the distinction via `weighting_scheme` parameter.

### Recommendations to the V5 framework (input to QUA-236 enhancement loop)

1. **Add Chan's look-ahead-bias programmatic self-test as a standard P1 Build Validation sub-procedure.** Re-run the strategy on truncated data (last N=10-100 bars removed), verify positions on the trailing portion match. SRC02 Ex 3.6 § B.5 has the verbatim procedure (Ch 3 pp. 58-59).
2. **Adopt cointegrating augmented Dickey-Fuller (cadf) as a P3.5 CSR sub-procedure** for any pair-trade or two-leg-spread strategy candidate. Chan Ex 7.2 + 7.3 show the canonical implementation; KO/PEP is the canonical correlated-but-not-cointegrated negative-example for the test bench.
3. **Formalize the `cross-sectional-decile-sort` family in V5 vocabulary** with `weighting_scheme` ∈ {discrete-decile, continuous-distance, pca-rank-decile} and `ranking_metric` ∈ {prior-period-return, factor-exposure, expected-return-from-model}. SRC02 surfaces the gap; CEO + CTO ratify per `strategy_type_flags.md` addition-process.
4. **Document the "deliberate-failure pedagogy" pattern across V5 corpus.** Chan provides 3 such cards (S02/S04/S06); Davey provided 2 (Ch 13 walk-forward, Ch 1 hogs underspecified). Combined: 5 documented failure-or-pedagogy cards spanning the V5 P-stage flow. Pipeline-Operator can use this corpus as a pre-deployment validation suite — does V5 actually catch what the source authors flag?
5. **Annual-calendar-trade backtest-sample-size special handling.** S07 + S08 (gasoline + natgas spring trades) + S05 (January Effect) all have 1 trade/year/symbol structures. V5 P7 PBO and P3 sweep sample-size discipline (Chan's own Ch 3 p. 53 rule of thumb: 252 data points per parameter) is structurally unmeetable for annual-cycle strategies. Recommend FREEZING author-published calendar parameters (entry_day, exit_day) and disallowing P3-sweep on them — only universe / position-sizing axes are appropriate sweep dimensions.

## 5. Source quality observations

- **Methodology coverage:** very strong, complementary to Davey. Davey covers strategy development workflow; Chan covers statistical-arbitrage methodology + cointegration + factor models + cross-sectional discipline. Together they form a near-complete V5 P-pipeline reference set.
- **Strategy density:** medium (8 cards in 175 pages). Chan's Ch 7 ("Special Topics") concentrates 6 of 8 cards into one chapter; Ch 1, 4, 5, 6, 8, App A yield zero cards (memoir / infrastructure / methodology). Ch 2-3 yields 1-2 cards (Bollinger ES inline + Khandani-Lo Ex 3.7+3.8 fold).
- **Author-claim density:** mixed but genuinely diverse. S01 (real backtest), S02/S03/S04/S06 (deliberate failure or transaction-cost demonstrations), S05 (mixed real backtest), S07/S08 (real + actual-trading P&L tables, 14-year track records). Reviewers should expect this card-set to span the full claim-evidence spectrum, similar to SRC01.
- **Code precision:** very high. Chan provides full MATLAB code for every Example 3.x and 7.x at `epchan.com/book/exampleN.m`. The cards' Pseudocode sections in § 4-5 are direct reductions of Chan's MATLAB.
- **BASIS-rule precision:** excellent. Chapter + section + example + page citations available throughout; verbatim quotes supported with exact location anchors in every card. No source-text typos identified (in contrast to SRC01 davey-es-breakout's flagged Ch 13 buy/sellshort swap).
- **V5-hard-rule compatibility:** mixed. 1 hard-fail (Ex 7.1 perceptron NN). 4 cards (S03/S04/S05/S06) are V5-architecture-incompatible (multi-stock cross-section; recommended Path 2). 2 cards (S07/S08) are flagged on `dwx_suffix_discipline` (no native Darwinex commodity-futures products). 1 card (S01) requires Friday-close waiver. Only S02 is unambiguously deployable on the current Darwinex stack.
- **Universe-effect sensitivity (genuinely Chan-distinctive):** Chan's framing throughout Ch 3 / Ch 7 emphasizes that strategy edge is heavily universe-dependent (e.g., Khandani-Lo's 4.47 Sharpe disappears at 0.25 on SP500 vs original small/microcap universe). V5 P3.5 CSR axis must explicitly sweep universe variants for any cross-sectional card. Not a regression — V5 already supports this — but Chan's emphasis is a useful reminder.

## 6. Yield ratio

| Metric | Value |
|---|---|
| Heartbeats used | 7 |
| Cards drafted | 8 |
| Cards passed G0 | 0 (all DRAFT) |
| Cards killed pre-P1 | 0 |
| Skips (hard-fail + source-spec-completeness) | 4 (1 hard-fail Ex 7.1 ML + 3 source-spec-completeness: HFT, Leverage, PEAD) |
| Cards/heartbeat | **1.14** |
| G0-pass-rate (cards_passed_g0 / cards_drafted) | TBD pending CEO + Quality-Business review |

**SRC02 yield (1.14) is 1.6× SRC01's yield (0.71).** Why?

1. **Ch 7 density**: Chan packs 6 cards into one chapter (vs Davey's 1 card per appendix + 2 from Ch 3/13). A methodology-heavy book with one strategy-rich chapter is a high-yield SRC.
2. **Card-template internalization**: heartbeats 4-6 each landed 2 cards because the template is now well-practiced from SRC01 + SRC02 H1-H3. New cards reuse infrastructure (raw evidence files, common Hard Rule patterns, vocabulary-gap proposals).
3. **Some cards are tighter** (S05/S06/S03/S04 multi-stock cards reuse the architecture-incompatibility rationale and Path-2-recommendation pattern; less per-card prose needed).

**Pacing recommendation for SRC03+**: 1.0-1.2 cards/heartbeat is sustainable on methodology-rich Tier A sources. SOURCE_QUEUE.md already plans T1 sources at proposed_order 3-13; expect sustained high yield through Williams (#3), Lien (#4), Chan-AT (#5), with declining yield on the SMC / Elliott / pdfcoffee Tier-C tail.

## 7. Recommendation: deeper mining or move on?

**Move on to SRC03.** Rationale:

- All chapters and Appendix A surveyed; no remaining strategy-bearing sections.
- The 8 cards span the full evidence-quality spectrum (real backtest / deliberate-failure / 14-year track record).
- Chan's statistical-arbitrage methodology is cross-walked into V5 P-stages with 5 enhancement-loop recommendations captured.
- 5 controlled-vocabulary additions surfaced and documented for batched CEO + CTO ratification.
- Per OWNER 17:28 `diversity_bias_rules`, SRC02 + SRC01 combined is well-diversified across strategy classes. Any T1 Tier A source qualifies for SRC03.
- SOURCE_QUEUE.md proposed_order #3 = **Williams, *Long-Term Secrets to Short-Term Trading*** — futures breakout strategies (Volatility Breakout being the canonical). Adds short-horizon breakout to the V5 corpus's strategy-family coverage.

CEO action requested per QUA-188 waiver v3:

1. **G0 review** of the 8 DRAFT cards (S01-S08).
2. **Controlled-vocabulary additions** — batched proposal of 5 new flags per `strategy_type_flags.md` addition-process:
   - `cointegration-pair-trade` (entry, S01)
   - `mean-reach-exit` (exit, S01)
   - `zscore-band-reversion` (entry, S02)
   - `annual-calendar-trade` (entry, S07/S08)
   - `cross-sectional-decile-sort` (entry, S03/S04/S05/S06; with `weighting_scheme` + `ranking_metric` Strategy Card-level parameters)
3. **G0 verdict path** for the architecture-incompatible cluster (S03/S04/S05/S06): recommended **Path 2** (V5-architecture-incompatible reference for future broker-expansion). Confirm or override.
4. **Hard Rule waiver requests**:
   - S01 chan-pairs-stat-arb: `friday_close` waiver (10-day OU half-life)
   - S07 chan-gasoline-rb-spring: `friday_close` waiver (9-trading-day hold)
   - S08 chan-natgas-spring: `friday_close` waiver (36-trading-day hold) + heightened `kill_switch_coverage` calibration for Amaranth-class risk
5. **SRC03 dispatch** — open new SRC03 issue against Williams, *Long-Term Secrets to Short-Term Trading* per SOURCE_QUEUE proposed_order #3.

## 8. Cross-references

- Parent issue: [QUA-275](/QUA/issues/QUA-275)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`
- Source-queue: `strategy-seeds/sources/SOURCE_QUEUE.md`
- SRC02 source.md: `strategy-seeds/sources/SRC02/source.md`
- SRC01 (predecessor): [QUA-191](/QUA/issues/QUA-191), `strategy-seeds/sources/SRC01/`, `completion_report.md` 2026-04-27
- 8 Strategy Cards:
  - `strategy-seeds/cards/chan-pairs-stat-arb_card.md`
  - `strategy-seeds/cards/chan-bollinger-es_card.md`
  - `strategy-seeds/cards/chan-khandani-lo-mr_card.md`
  - `strategy-seeds/cards/chan-pca-factor_card.md`
  - `strategy-seeds/cards/chan-january-effect_card.md`
  - `strategy-seeds/cards/chan-yoy-same-month_card.md`
  - `strategy-seeds/cards/chan-gasoline-rb-spring_card.md`
  - `strategy-seeds/cards/chan-natgas-spring_card.md`
- 3 raw evidence files:
  - `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md` (S01)
  - `strategy-seeds/sources/SRC02/raw/bollinger_es_inline.md` (S02)
  - `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` (S05/S06/S07/S08)
  - `strategy-seeds/sources/SRC02/raw/cross_sectional_family.md` (S03/S04)
- 4 raw text extractions:
  - `strategy-seeds/sources/SRC02/raw/toc_pp1-14.txt`
  - `strategy-seeds/sources/SRC02/raw/ch2_fishing_pp9-30.txt`
  - `strategy-seeds/sources/SRC02/raw/ch3_backtesting_pp31-73.txt` + `ch3_pitfalls_pp60-95.txt`
  - `strategy-seeds/sources/SRC02/raw/ch7_special_topics_pp116-165.txt` + `ch7_seasonal_pp143-160.txt`
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-033 (extraction-discipline / Rule 1): per QUA-275 binding pointer
- QUA-188 waiver v3 (CEO-autonomous source-queue ordering)
- QUA-243 (card-template filename convention update)
- QUA-244 (controlled-vocabulary ratification + addition-process)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`
