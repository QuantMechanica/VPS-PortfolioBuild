---
source_id: SRC04
parent_issue: QUA-333
authored_by: Research Agent
authored_on: 2026-04-28
status: drafted_pending_ceo_review
budget_summary:
  heartbeats_used: 6                          # h1 scaffold + survey; h2 S02a/S02b/S03 (3 cards); h3 S05/S07 (2 cards); h4 S04/S06/S08 (3 cards); h5 S09/S11 + S01/S10 SKIP (2 cards + 2 SKIPs); h6 S12/S13/S14/S15/S16/S17 SKIPs/KILLs + completion_report + sub-issues
  cards_drafted: 10                           # S02a + S02b + S03 + S04 + S05 + S06 + S07 + S08 + S09 + S11
  cards_skipped: 6                            # S01 + S10 + S12 + S13 + S14 + S17 (with rationales)
  cards_killed_pre_p1: 2                      # S15 + S16 (darwinex_native_data_only on FX options data)
  cards_passed_g0: 0                          # all 10 DRAFT; awaiting CEO + Quality-Business review
  yield_ratio_cards_per_heartbeat: 1.67       # 10 / 6 — between SRC02's 1.0 and SRC03's 2.33
  draft_yield_pct: 56                         # 10 / 18 surveyed slots; lower-third of § 6.5.4 forecast (53-71%)
  vs_predecessors:
    src01: 5 cards / 5 hb (1.00 cards/hb)
    src02: 8 cards / 8 hb (1.00 cards/hb)
    src03: 14 cards / 6 hb (2.33 cards/hb)
    src04: 10 cards / 6 hb (1.67 cards/hb)
---

# SRC04 Completion Report — Lien, *Day Trading and Swing Trading the Currency Market*

This report closes out SRC04 per `processes/13-strategy-research.md` § "Per-step responsibilities" Step 5 and § "Exits" (parent close → completion_report.md). All strategy-bearing chapters of the source PDF (Ch 8-19, 21-25 = 17 chapters) have been surveyed; **10 Strategy Cards drafted** under V5 schema; **6 candidates SKIPPED** (methodology / discretionary / underspec rationales); **2 candidates KILLED_PRE_P1** on `darwinex_native_data_only` hard-rule block.

**SRC04 status from Research's side: extraction complete.** Awaiting CEO action on:
1. The 10 DRAFT cards (G0 review per DL-030 Class 2 Review-only execution policy) — sub-issues opened sequentially per DL-029
2. The 3 batched controlled-vocabulary additions per `strategy_type_flags.md` addition-process (`bband-reclaim`, `round-num-fade`, `ma-stack-entry`)
3. Two future-vocab-watches (NOT yet proposed; deferred to SRC05+ for deployment-precedent confirmation): `adx-trend-confirm-gate`+`adx-range-mr-gate` paired ADX-regime flags; `yield-spread-regime-filter` bond-yield-spread regime classifier
4. SRC05 dispatch per DL-032 Autonomy Waiver v3 (next source per `SOURCE_QUEUE.md` `proposed_order = 5`)

## 1. Source identity (recap)

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 9781119108412 (paperback) / 9781119220107 (ePDF) / 9781119220091 (ePub)."
    quality_tier: A                              # forex-industry insider; 15+ years FX experience; JPMorgan FX desk → FXCM/DailyFX → BK Asset Management; CNBC contributor; multi-book Wiley author
    role: primary
```

Source-text on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf` (4.9 MB; `pdftotext -layout` clean extraction; embedded text layer, no OCR needed). 33 chapters total; strategy-rich span Ch 8-25 (technical Ch 8-16 + fundamental Ch 17-19, 21-25).

## 2. Strategy harvest

Ten Strategy Cards drafted; full set summarized in the table below. All ten carry `status: DRAFT` and are awaiting CEO + Quality-Business G0 review.

| Slot | Sub-issue | Card slug | Source location | Strategy character | Author-claim type | Primary `hard_rules_at_risk` |
|---|---|---|---|---|---|---|
| S02a | [QUA-340](/QUA/issues/QUA-340) | `lien-dbb-pick-tops` | Ch 9 PDF pp. 103-107 | Double Bollinger Band PICK TOPS (range-mode mean-reversion): close back across 1st-σ band after outer-band-zone dwell | Verbatim rule + 1 worked example; no aggregate backtest | `enhancement_doctrine` (BB period + σ multipliers) |
| S02b | QUA-341 (in_progress) | `lien-dbb-trend-join` | Ch 9 PDF pp. 107-110 | Double Bollinger Band TREND JOIN (trend-mode breakout): close across 1st-σ band after K-bar opposite-side dwell. Sibling of S02a sharing proposed `bband-reclaim` flag | Verbatim rule + 1 worked example; co-regime-fire suppression vs S02a documented | `enhancement_doctrine` (precondition_mode), `friday_close` (multi-day swing variant) |
| S03 | [QUA-342](/QUA/issues/QUA-342) | `lien-fade-double-zeros` | Ch 10 PDF pp. 112-115 | Round-Number Psychological-Level FADE (M15, 20MA counter-trend filter, 10-15-pip entry offset, 20-pip stop) | Per-trade pip P&L on 3 worked examples; no aggregate backtest | `scalping_p5b_latency` (M15 + tight stops), `enhancement_doctrine` (pip offsets major-FX-calibrated) |
| S04 | [QUA-343](/QUA/issues/QUA-343) | `lien-waiting-deal` | Ch 11 PDF pp. 117-121 | London-Open Opening-Range FALSE-BREAKOUT FADE (M5-M15; 06:00-07:00 GMT range; 25-pip spike + reverse-back-through-opposite + 10p offset; 35p stop, +50p TP1, +3R TP2). GBPUSD-specific per Lien UK-dealer-stop-hunt thesis | Per-trade pip P&L on 3 GBPUSD worked examples | `scalping_p5b_latency`, `enhancement_doctrine` (GMT session window + pip thresholds) |
| S05 | [QUA-344](/QUA/issues/QUA-344) | `lien-inside-day-breakout` | Ch 12 PDF pp. 123-127 | Multi-Inside-Day VOLATILITY-COMPRESSION BREAKOUT (D1; ≥2 inside days; bracket stop-buy/sell at prev-inside-day extremes ±10p; stop-and-reverse at nearest-inside-day opposite extreme +10p) | Per-trade pip P&L on 3 worked examples | `friday_close` (multi-day swing), `risk_mode_dual` (Lien-verbatim 2-lot reversal exposed only as P3 variant) |
| S06 | [QUA-345](/QUA/issues/QUA-345) | `lien-fader` | Ch 13 PDF pp. 129-133 | ADX(14)<20 PRIOR-DAY-RANGE FALSE-BREAKOUT FADE (D1 setup + H1 entry; 15-pip spike past prev-day extreme + opposite-side stop-buy/sell at +5p offset, 20p stop, TP1 = +1R, 2-bar trail). DISTINCT from SRC03_S10 williams-spec-trap on FOUR axes (regime, range-window, reference-price, stop-sizing) | Per-trade pip P&L on 2 worked examples | `scalping_p5b_latency`, `enhancement_doctrine` (5p / 20p pip offsets) |
| S07 | [QUA-346](/QUA/issues/QUA-346) | `lien-20day-breakout` | Ch 14 PDF pp. 135-138 | Failed-Pullback Continuation 20-DAY BREAKOUT (D1; 3-state machine ARMED_SCAN → ARMED_PULLBACK → ARMED_REBREAK; first canonical Donchian-family card across all SRCs) | Per-trade pip P&L on 3 worked examples + descriptive "very high success rate" claim | `friday_close` (multi-day-to-multi-week hold; waiver candidacy), `enhancement_doctrine` ("a few pips" imprecise offsets) |
| S08 | [QUA-347](/QUA/issues/QUA-347) | `lien-channels` | Ch 15 PDF pp. 139-141 | Narrow-Channel BREAKOUT (M15 default; n-bar rolling high/low + width threshold + bracket stop-orders at channel ±10p; conservative TP1+BE+trail or full 2R exit) | Per-trade pip P&L on 3 worked examples (incl. one stop-out illustrating conservative-management rationale) | `news_pause_default` (Lien favors pre-economic-release entry; default V5 P8 applies), `scalping_p5b_latency` (narrow-channel pip-tolerance) |
| S09 | [QUA-348](/QUA/issues/QUA-348) | `lien-perfect-order` | Ch 16 PDF pp. 143-148 | 5-MA Sequential-Monotonic-Stack ENTRY (D1; 10>20>50>100>200 SMAs; entry 5 candles after formation + ADX>20; stop at formation-bar extreme with safe-SMA-20 fallback; multi-month signal-reversal exit on first-adjacent-pair break). NEW vocab gap PROPOSED `ma-stack-entry` | Descriptive "high profit but low probability and low frequency" + 3 worked examples (15.0R / 8.65R / 0.66R range) | `friday_close` (multi-month hold; STRONG waiver candidacy), `enhancement_doctrine` (MA periods + ADX threshold) |
| S11 | [QUA-349](/QUA/issues/QUA-349) | `lien-carry-trade` | Ch 18 PDF pp. 153-160 | Carry-Direction Signal (Darwinex-native swap reads) + Bond-Yield-Spread Risk-Aversion Gate (Lien Figure 18.4) + 6-month minimum hold + signal-reversal exit. **FIRST CARRY-FAMILY CARD across all SRCs** | One descriptive regime-performance claim ("extremely well 2000-2007, failed miserably 2008-2009, recovered late 2012-2015") + AUDCHF mechanics example | `friday_close` STRONGEST-IN-SRC04 (Lien thesis REQUIRES multi-month hold), `darwinex_native_data_only` LOAD-BEARING (bond-yield feed), `enhancement_doctrine` |

**Total: 10 cards, 10 distinct mechanical structures.** Yield is Lien-typical for the technical block (rule-tight 9-card harvest from Ch 9-16 with one Ch 8 SKIP + Ch 9 split into S02a+S02b) and SKIP-heavy for the fundamental block (1 draft from 8 fundamental candidates + 7 SKIPs/KILLs).

### Architecture-fit profile (V5)

| Architecture-fit | Cards | Recommended G0 path |
|---|---|---|
| **Clean (single-symbol Darwinex spot FX)** | S02a, S02b, S03, S04, S05, S06, S07, S08, S09 | All 9 technical-block cards single-symbol spot FX architecture-clean. Standard advance through P-pipeline. |
| **Clean-with-external-data-shim** | S11 (carry-trade, requires bond-yield feed for risk-aversion gate) | Carry-direction signal alone is Darwinex-native; risk-aversion ENHANCEMENT requires external bond-yield feed. CTO IMPL paths: (a) FRED API shim; (b) Darwinex bond-CFD proxy (`US10YR.DWX` if available); (c) drop the gate and ship V4-precedent carry-direction-only as `_v1`. |
| Architecture-incompatible | (none) | n/a |

**SRC04 yields 10/10 = 100% architecture-clean cards** (counting S11 as "clean-with-shim"). Confirms QUA-333 prediction of 100% architecture-clean rate. Best-tied with SRC03 Williams (14/14 = 100%) and well above SRC02 Chan (4/8 = 50%).

### Strategy-type-flag distribution (across the 10 drafted cards)

| Flag | S02a | S02b | S03 | S04 | S05 | S06 | S07 | S08 | S09 | S11 | Count |
|---|---|---|---|---|---|---|---|---|---|---|---|
| atr-hard-stop | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 10 |
| symmetric-long-short | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 10 |
| friday-close-flatten | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | 10 |
| trend-filter-ma | | | ✓ | | | | | | | | 1 |
| atr-trailing-stop | | | | | | ✓ | ✓ | | | | 2 |
| narrow-range-breakout | | | | | ✓ | | | ✓ | | | 2 |
| failed-breakout-fade | | | | | | ✓ | | | | | 1 |
| donchian-breakout | | | | | | | ✓ | | | | 1 |
| signal-reversal-exit | | | | | | | | | ✓ | ✓ | 2 |
| intraday-session-pattern | | | | ✓ | | | | | | | 1 |
| carry-direction | | | | | | | | | | ✓ | 1 |
| **proposed:** bband-reclaim | ✓ | ✓ | | | | | | | | | 2 |
| **proposed:** round-num-fade | | | ✓ | | | | | | | | 1 |
| **proposed:** ma-stack-entry | | | | | | | | | ✓ | | 1 |

**Mining provenance**: All 10 cards leverage existing controlled-vocabulary flags as primary entry mechanism (with three new flags proposed for batch ratification). No `cross-sectional-decile-sort` (SRC02 specialty), no `cointegration-pair-trade` (SRC02 specialty), no `vol-expansion-breakout` / `gap-fade-stop-entry` / `rejection-bar-stop-entry` (SRC03 specialties). Lien introduces FORTH and FIFTH cards in the `failed-breakout-fade` family (after SRC03_S10) — confirms the flag framework supports multiple distinct cards under one entry-mechanism flag via card-level parameter disambiguation.

### Direction-class diversity (cross-source)

| Class | SRC01 (Davey) | SRC02 (Chan) | SRC03 (Williams) | SRC04 (Lien) | Total |
|---|---|---|---|---|---|
| Trend-following / momentum / breakout | 1 (worldcup) | 0 | 3 (S01 vol-bo, S11 8wk-box, S12 18bar-ma) | 3 (S05 inside-day, S07 20-day, S08 channels) | 7 |
| Mean-reversion (single-bar) | 4 (Davey RSI/Bollinger family) | 1 (S02 chan-bollinger-es) | 4 (S07 Smash, S08 Fakeout, S09 Naked Close, S14 CDC) | 2 (S02a DBB pick-tops, S03 fade-zeros) | 11 |
| Trend-join / breakout-continuation | 0 | 0 | 0 | 2 (S02b DBB trend-join, S09 perfect-order) | 2 |
| Calendar-bias | 0 | 0 | 3 (S04 TDW, S05 TDOM, S06 Holiday) | 0 | 3 |
| Gap-fade reversal | 0 | 0 | 3 (S02 Monday OOPS!, S03 Hidden OOPS!, S15 Gap-Down) | 0 | 3 |
| Failed-breakout fade | 0 | 0 | 1 (S10 Spec Trap) | 1 (S06 Fader — distinct regime / range-window / reference / stop axes) | 2 |
| Cointegration / pair-trade | 0 | 1 (S01 chan-pairs-stat-arb) | 0 | 0 | 1 |
| Cross-sectional / multi-stock | 0 | 4 (S03/S04/S05/S06 chan multi-stock) | 0 | 0 | 4 |
| Annual calendar trade | 0 | 2 (S07/S08 chan seasonals) | 0 | 0 | 2 |
| Session-pattern intraday | 0 | 0 | 0 | 1 (S04 Waiting for Deal) | 1 |
| Carry / interest-rate-differential | 0 | 0 | 0 | 1 (S11 Carry Trade) | 1 |
| **TOTAL** | 5 | 8 | 14 | 10 | 37 |

**SRC04 broadens V5's direction-class coverage:** introduces TWO new direction-classes — "session-pattern intraday" (S04) and "carry / interest-rate-differential" (S11). Combined with predecessors, V5 corpus now spans 11 direction-classes across 37 cards.

**Diversity-bias check (per SOURCE_QUEUE):** No 3+ consecutive same-class trigger fires. Lien brings net-new strategy classes (forex-specialist + carry); SRC05 dispatch per `SOURCE_QUEUE.md` `proposed_order = 5` is acceptable next.

## 3. SKIPs (sections classified as no-card per Rule 1)

Six SKIPs documented with rationale:

| Slot | Chapter | SKIP type | Rationale |
|---|---|---|---|
| S01 | Ch 8 Multiple Time Frame Analysis | **SKIP_METHODOLOGY** | Methodology only — Lien provides 3 narrative examples (USDJPY RSI<30 in uptrend; USDCAD Fibonacci-retracement bounce; CHFJPY multi-frame downtrend) but NO mechanical entry/exit rule list. The methodology UNDERPINS the technical chapters Ch 9-16 which were operationalized as S02a-S09. Per Rule 1, no standalone mechanical strategy to extract. |
| S10 | Ch 17 Pairing Strong with Weak | **SKIP_DISCRETIONARY** | Discretionary observational — Lien provides 3 narrative case studies (EUR-QE → sell EURGBP near 0.74; oil-up + NZ-weak → sell NZDCAD; data-surprise dynamic → buy EURUSD breakout) but NO quantifiable strength/weakness scoring system. Lien's "monitor economic data surprises" hint (PDF p. 152) points to external data feeds (Citi Economic Surprise Index) NOT in Darwinex feed → secondary `darwinex_native_data_only` rationale. |
| S12 | Ch 19 Macro Event Driven Trade | **SKIP_DISCRETIONARY** | 5 historical case studies (Ukraine 2014, EU sov-debt 2009-13, GFC 2008, 2004 election, 2003 G7 Dubai, Iraq war) + "list of important events to know" but NO mechanical entry/exit rule list. Macro events irregular + magnitude-uncertain + sentiment-direction discretionary. |
| S13 | Ch 21 Commodity Prices as Leading Indicator | **SKIP_UNDERSPEC** | Lien provides specific correlation magnitudes (gold↔AUDUSD 0.83, oil↔CADUSD 0.67, gold↔CADUSD 0.67) and cohort identification (AUD/gold, CAD/oil, NZD/dairy, AUD/iron-ore) but NO mechanical entry/exit rule list. The "Trading Opportunity" section is descriptive: "monitor gold and oil prices to help determine where these currencies are headed" — no signal threshold, entry timing, stop, or time horizon. Mechanical translation would require Research-extrapolation across 5 dimensions exceeding BASIS-rule tolerance. **Note: commodity CFDs (XAU/OIL) ARE Darwinex-native, so SKIP is purely on rule-list completeness, NOT data-feed.** |
| S14 | Ch 22 Bond Spreads as Leading Indicator | **SKIP_UNDERSPEC** | Lien provides yield-spread definition (10Y differential between two countries), 3 worked examples (EURUSD/Bund-UST, GBPUSD/Gilt-UST, AUDNZD/AU-NZ 10Y), and "rule of thumb" ("when there is a big move in the yield spread, it will coincide with a big move in the currency pair") but NO specific threshold for "big move", entry timing, or stop. Same source-spec-completeness gap as S13. PLUS: 10Y bond yields are NOT Darwinex-native (`darwinex_native_data_only` would BIND, same dependency as S11 carry-trade risk-aversion gate). |
| S17 | Ch 25 Intervention | **SKIP_DISCRETIONARY** | 4 historical case studies (BoJ 2011 multiple, BoJ 2015, SNB EURCHF 1.20 peg break Jan 2015 — 30% one-day decline that bankrupted FX brokers) + vague "ride or fade" guidance but NO mechanical rules. Rare, irregular, magnitude-uncertain, news-driven. SNB peg break is a kill-switch event, NOT a trade opportunity. |

### KILLs (hard-rule fail rationale)

Two KILL_PRE_P1 candidates:

| Slot | Chapter | KILL trigger | Rationale |
|---|---|---|---|
| S15 | Ch 23 Risk Reversals | `darwinex_native_data_only` BIND | Strategy uses ±1σ risk-reversal-value (25-delta FX options skew) as overbought/oversold contrarian signal. Lien EXPLICITLY references data source (PDF p. 187): "FXCM News Plugin, under options, or on the Bloomberg/Reuters terminals" — institutional-only data ($1500/mo Bloomberg per Lien Ch 7 PDF p. 83). NOT in Darwinex CFD feed; no Darwinex-native proxy exists for FX options skew. Hard-rule block. |
| S16 | Ch 24 Option Volatilities | `darwinex_native_data_only` BIND | Strategy: 1-month implied vol < 3-month implied vol → expect breakout; 1-month vol > 3-month vol → expect reversion-to-range. Requires implied 1-month + 3-month FX option volatilities. Lien EXPLICITLY references data source (PDF p. 194): "Volatilities can be found on Bloomberg or Reuters" — institutional-only. NOT in Darwinex feed; realized-vol on spot prices is a DIFFERENT signal than implied-vol-from-options. Hard-rule block. |

**Filter chapters NOT extracted as separate cards** (Ch 1-7 + Ch 20 + Ch 26-33, integrated into per-card § 6 Filters where applicable):
- Ch 1-4: Market structure / OTC / dealer mechanics (foundational context)
- Ch 5: Most market-moving economic data (P8 News Impact filter context)
- Ch 6: Currency correlations (filter context for cross-pair selection)
- Ch 7: Trade parameters for various market conditions (regime-classification context for S06 ADX gate, S08 narrow-channel filter)
- Ch 20: Quantitative Easing impact on Forex (macro context, no rule list)
- Ch 26-33: Currency profiles (per-pair context — feeds into per-card "default symbols" decisions)

Per DL-033 Rule 1, FILTERS are documented per-card under § 6 (Filters / No-Trade module) when they bind to a specific entry strategy, not as separate Strategy Cards.

## 4. Methodology cross-walk — Lien vs SRC01 Davey + SRC02 Chan + SRC03 Williams

Four sources surveyed; methodology comparison:

| Aspect | SRC01 Davey | SRC02 Chan | SRC03 Williams | SRC04 Lien |
|---|---|---|---|---|
| Source character | Process textbook | Methodology + small set of named demos | Strategy textbook + setup tools | Forex-specialist textbook with chapter-per-strategy structure |
| Strategy density | ~5 cards over ~14 chapters | ~8 cards over 8 chapters | ~14 cards over ~46 PDF pages (rule-tight) | ~10 cards from 17 strategy-bearing chapters (rule-tight in technical block; thesis-narrative in fundamental block) |
| Backtest discipline | Per-strategy backtests with walk-forward | Per-strategy MATLAB code references; Sharpe pre/post-cost | Aggregate backtests; per-strategy verbatim rules without per-strategy backtests on most | Per-trade pip-P&L on 1-3 worked examples per strategy; no aggregate backtests; one descriptive non-numeric performance claim per strategy |
| Author candor on failure modes | Davey Ch 13 walk-forward FAILURE example (-$9,938 OOS) | Chan deliberate-failure examples × 3 | Williams "It may go on, or it may not" + "accuracy is low and replete with whipsaws" | Lien USDJPY perfect-order Fig 16.3 example explicit: "the profit was 425 pips for a risk of 645 pips, which was far from ideal" — published a sub-1R worked example as cautionary; Ch 16 closing line "high profit but low probability and low frequency" |
| V5-architecture concerns | Low (most Davey cards single-symbol) | High (4/8 multi-stock incompatible) | Low (14/14 architecture-clean) | Low-medium (9/10 fully Darwinex-native; 1/10 = S11 carry-trade requires external bond-yield feed for risk-aversion ENHANCEMENT, but core carry signal is Darwinex-native via SymbolInfoDouble swap reads — degraded path = ship V4-precedent carry-direction-only) |
| Vocabulary footprint | Mining baseline (V4 SM_XXX) | +5 new flags (cointegration, zscore-band-reversion, mean-reach-exit, annual-calendar-trade, cross-sectional-decile-sort) | +6 new flags (vol-expansion-breakout, gap-fade-stop-entry, rejection-bar-stop-entry, failed-breakout-fade, intraday-day-of-week, holiday-anchored-bias) | +3 new flags (bband-reclaim, round-num-fade, ma-stack-entry) + 2 future-vocab-watches (adx-regime-gate paired, yield-spread-regime-filter) |

**Cross-source methodology delta for V5 P-pipeline (cumulative)**:
- SRC01 Davey contributed walk-forward + Monte Carlo + live-trading-validation methodology (now V5 P4/P6/P10 standards)
- SRC02 Chan contributed transaction-cost stress-testing (P9b load-bearing) + survivorship-bias quantification (P3.5 CSR principle) + cointegration-vs-correlation disambiguation
- SRC03 Williams contributed `enhancement_doctrine` discipline by example + cross-symbol POSITIVE-validation pattern (S12 14-symbol backtest as P3.5 CSR model) + calendar-bias as legitimate strategy class
- **SRC04 Lien contributes:** (a) **multi-state-machine entry pattern as architectural signature** (5 of 10 cards use 3+ state ARMED_X → ARMED_Y → ARMED_Z entry machines: S04, S06, S07, S09, S11 — vs prior SRCs' single-bar entry triggers); (b) **first carry-family card across the corpus** (S11 fills a long-standing V5 gap on V4 SM_076 / Padysak-Vojtko spec / Good-Carry-Bad-Carry inspiration); (c) **forex-session-window patterns** (S04 GBPUSD London-open opening-range fade is the first session-window-conditional entry across SRCs); (d) **`darwinex_native_data_only` as a real binding constraint at scale** — SRC04 KILLED two cards (S15, S16) and SKIPPED two more (S10, S14) on this hard rule, providing concrete deployment evidence for the discipline.

## 5. Vocabulary additions surfaced (batch-proposed for CEO + CTO)

Per `strategy_type_flags.md` addition-process: **3 entry-side gaps + 2 future-vocab-watches** surfaced from SRC04.

### A. Three new entry-side flag proposals

```yaml
- name: bband-reclaim
  proposed_at_cards: [SRC04_S02a, SRC04_S02b]
  section: A. Entry-mechanism
  definition: "Close back ACROSS N·σ Bollinger band after multi-bar dwell on the OUTER side of the band (price was between Nσ and 2Nσ outer envelope OR below/above Nσ band for K bars, then closes back across the Nσ band). Card-level `precondition_mode ∈ {outer-band-zone, n-bars-opposite-1sigma}` distinguishes the range-MR vs trend-join variants."
  v4_evidence: "None — V4 had no Bollinger-Band-band-reclaim EAs per `strategy_type_flags.md` Mining-provenance table."
  disambiguation_from:
    - "zscore-band-reversion (entry on band CROSS OUT — opposite mechanic; reclaim triggers on RETURN INTO inner zone)"
    - "n-period-min-reversion (uses N-bar minimum extreme, not moving-stdev band)"

- name: round-num-fade
  proposed_at_cards: [SRC04_S03]
  section: A. Entry-mechanism
  definition: "Stop-buy/stop-sell at fixed pip offset (10-15) from a PSYCHOLOGICAL ROUND-NUMBER price (xx.00 / x.x000 / x.x500), conditioned on counter-trend MA-position filter. Reference price is an ABSOLUTE round-number anchor independent of prior bar's range, prior N-bar extreme, or candle shape."
  v4_evidence: "None — V4 had no round-number-anchored stop-entry EAs per `strategy_type_flags.md` Mining-provenance table."
  disambiguation_from:
    - "vol-expansion-breakout (relative range anchor, not round-number)"
    - "gap-fade-stop-entry (calendar-pattern + gap-through reference; round-num-fade has no calendar-pattern or gap-through condition)"
    - "n-period-min-reversion (N-bar minimum, not absolute level)"
    - "narrow-range-breakout / rejection-bar-stop-entry / failed-breakout-fade (each requires bar-internal or multi-bar pattern, not psychological-level anchor)"

- name: ma-stack-entry
  proposed_at_cards: [SRC04_S09]
  section: A. Entry-mechanism
  definition: "K consecutive moving averages of increasing periods are in MONOTONIC SEQUENTIAL ORDER (long: SMA(P1) > SMA(P2) > ... > SMA(PK) for P1 < P2 < ... < PK; short mirror). Lien's perfect-order canonical case: K=5 with periods (10, 20, 50, 100, 200). Entry fires N candles AFTER initial formation if stack still holds."
  v4_evidence: "None — V4 had no MA-stack-entry EA per `strategy_type_flags.md` Mining-provenance table. V4 had `trend-filter-ma` (SINGLE-MA filter) which is structurally distinct from K-MA monotonic-stack as ENTRY trigger."
  disambiguation_from:
    - "trend-filter-ma (single MA OVERLAY filter, not entry trigger)"
    - "cross-sectional-decile-sort (universe-ranked relative-strength, not single-instrument MA stack)"
    - "donchian-breakout (N-bar extreme, not MA crossover state)"
    - "vol-regime-gate (vol-bucket classifier, not SMA-based price state)"
    - "regime-filter-multi (multi-feature engineered tree, not single-feature monotonic-stack-state)"
```

### B. Two future-vocab-watches (NOT yet proposed; defer to SRC05+ for deployment-precedent confirmation)

These are NOT batch-proposed at SRC04 closeout. They are recorded for forward-watch:

1. **`adx-trend-confirm-gate` + `adx-range-mr-gate` (paired)** — ADX-based regime gate symmetric to existing `atr-regime-mr-gate`. Surfaced TWICE in SRC04: S06 lien-fader uses ADX<20 range-confirmation gate for fade entries; S09 lien-perfect-order uses ADX>20 trend-confirmation gate for trend-join entries. Two SRC04 cards using ADX-regime gating in opposite directions; if SRC05+ produces a third instance, propose paired flags. For now captured at card-level via filter parameters.

2. **`yield-spread-regime-filter`** — bond-yield-spread-based regime classifier (e.g., 10Y Bund − 10Y US Treasury for risk-aversion proxy). Surfaced in SRC04_S11 lien-carry-trade (Lien Figure 18.4 risk-aversion gate). Distinct from existing `skew-regime-filter` (FX options skew, V4 Good-Carry-Bad-Carry precedent) — bond yields are different data class. Originally expected to recur in S14 Bond-Spread leading indicator but S14 was SKIPPED (underspec); single-anchor S11 alone insufficient for vocab proposal under the discipline.

## 6. Yield ratio + budget review

```yaml
heartbeats_used: 6                           # h1 scaffold + survey; h2-h5 cards; h6 closeout
cards_drafted: 10
cards_skipped: 6                             # S01/S10/S12/S13/S14/S17
cards_killed_pre_p1: 2                       # S15/S16
cards_passed_g0: 0                           # awaiting CEO review
yield_ratio: 10/6 = 1.67                     # cards-per-heartbeat
benchmark_vs_src03: 1.67 / 2.33 = 0.72       # 72% of SRC03's ceiling (rule-tight Williams was an upper-bound outlier)
benchmark_vs_src02: 1.67 / 1.0 = 1.67×       # SRC04 yield is 67% above SRC02
extraction_rate: 10 / 18 = 56%               # surveyed slots = 17 chapters + 1 split (S02 → S02a+S02b); vs SRC02 8/13 = 62%, SRC03 14/15 = 93%
forecast_band_match: 56% within § 6.5.4 forecast 53-71%  # lower-third
```

**Yield-ratio drivers (Lien-vs-Williams analysis):**

1. Lien's TECHNICAL BLOCK (Ch 8-16) is rule-tight (matches SRC03 cadence) — all 9 technical chapters yielded a draft (S02 split into S02a+S02b for two distinct regimes; S01 was the only methodology SKIP)
2. Lien's FUNDAMENTAL BLOCK (Ch 17-19, 21-25) was thesis-narrative-heavy with most chapters lacking mechanical rule lists — 1 draft (S11 carry-trade) + 7 SKIPs/KILLs
3. The split between rule-tight technical (9/10 = 90% draft) and thesis-narrative fundamental (1/8 = 13% draft) drives the aggregate 56% draft yield
4. SRC03 had no fundamental block (Williams is purely tactical/short-term); SRC02 had fundamental concepts (cointegration, factor models) treated rule-tight; SRC04's fundamental block is closer to SRC02's qualitative-discretionary mix than SRC03's tactical density

**Counter-factors (where yield could have been higher):**

1. S13 + S14 (commodity-leading + bond-spread-leading) both SKIPPED on source-spec-completeness — borderline cases where Research could have extracted with substantial mechanical-translation extrapolation; chose strict BASIS-rule application
2. PDF Ch 26-33 currency profiles consciously NOT extracted as Strategy Cards (per-pair context, integrated as filter-parameters where applicable)

**SRC04 extraction-rate vs forecast (§ 6.5.4 said 9-12 cards = 53-71% yield):** Actual 10 cards = 56% yield = at the LOW BOUND of forecast range. The post-survey forecast was accurate.

## 7. Recommendation: deeper mining + next source

### Deeper SRC04 mining

**Recommendation: NO further SRC04 work.** All 17 strategy-bearing chapters surveyed; verdicts crystallized for all 18 candidate slots (S01 + S02a + S02b + S03 ... S17). The remaining context (Ch 1-7, Ch 20, Ch 26-33) is filter context already integrated into per-card § 6 Filters. No OCR-degraded sections; full PDF text-clean.

If pipeline P2-P9 reveals that Lien's patterns generalize beyond the 10 drafted cards in unexpected directions (e.g., commodity-leading or bond-spread-leading become tractable with future Darwinex-native data shims), Research can re-open SRC04 for follow-up at CEO discretion. Most likely candidate for re-extraction: **S14 bond-spread-leading** if S11 carry-trade IMPL successfully resolves the bond-yield-feed dependency — that path would unblock S14 mechanical translation as well.

### Next source

**Recommendation: dispatch SRC05 against the next entry in `SOURCE_QUEUE.md`** (`proposed_order = 5`, TBD per queue ratification at SRC04 closeout). Per DL-032 Autonomy Waiver v3, CEO is autonomous on source-queue ordering and per-batch source approval.

Diversity-bias check considerations for SRC05 selection:
- SRC04 introduced session-pattern-intraday + carry-family direction classes; SRC05 should ideally introduce additional net-new direction classes, OR provide complementary coverage on existing ones
- SRC04 was forex-specialist; SRC05 should ideally NOT be a 4th-consecutive forex source unless the source's strategy-class focus is non-forex-specific
- SRC04 introduced ADX-regime gating (potential vocab-watch); if SRC05 surfaces a third instance, the `adx-regime-gate` paired flags can be proposed
- SRC04 introduced yield-spread-regime-filter watch; if SRC05 surfaces a second instance, the flag can be proposed alongside `skew-regime-filter` differentiation

Per DL-029 sequential workflow, no SRC05 work begins until SRC04 sub-issues complete G0 review (or are explicitly unblocked by CEO).

## 8. Open CEO actions (closing checklist)

- [ ] **G0 review** of 10 SRC04 cards under sub-issues opened sequentially per DL-029 (first card unblocks the rest)
- [ ] **Vocabulary batch-proposal ratification** — 3 entry-side flag additions (`bband-reclaim`, `round-num-fade`, `ma-stack-entry`)
- [ ] **Future-vocab-watch acknowledgement** (no action required) — record `adx-trend-confirm-gate`+`adx-range-mr-gate` paired and `yield-spread-regime-filter` for SRC05+ deployment-precedent confirmation
- [ ] **`darwinex_native_data_only` IMPL path** for SRC04_S11 lien-carry-trade — CEO + CTO consultation on bond-yield-feed strategy: (a) FRED API external-fetch shim, (b) Darwinex bond-CFD proxy if `US10YR.DWX` / `BUND.DWX` are offered, (c) ship V4-precedent carry-direction-only `_v1` and defer the gate to a `_v2` rebuild
- [ ] **`risk_mode_dual` ratification** for SRC04_S05 lien-inside-day-breakout — CEO decision on the Lien-verbatim 2-lot reversal variant: (a) accept as P3 sweep variant only with risk_mode_dual flag; (b) drop the 2-lot variant entirely and ship V5-compliant 1-unit reversal only
- [ ] **`friday_close` waiver consideration** — multi-day-to-multi-month-hold cards (S05, S07, S09, S11) all flagged; S11 has the STRONGEST waiver case (Lien thesis REQUIRES multi-month hold). Precedent: SRC02_S01 chan-pairs-stat-arb + SRC03_S03 williams-cdc-pattern received P3 waiver consideration on similar theses
- [ ] **SRC05 dispatch** — open next source per `SOURCE_QUEUE.md` `proposed_order = 5` after SRC04 sub-issues progress

## 9. Cross-references

- Parent issue: [QUA-333](/QUA/issues/QUA-333)
- Sub-issues: [QUA-340](/QUA/issues/QUA-340) (S02a `lien-dbb-pick-tops`) through [QUA-349](/QUA/issues/QUA-349) (S11 `lien-carry-trade`) per DL-029 sequential chain — first opened as `todo`, rest opened as `blocked`. Order: S02a (QUA-340), S02b (QUA-341), S03 (QUA-342), S04 (QUA-343), S05 (QUA-344), S06 (QUA-345), S07 (QUA-346), S08 (QUA-347), S09 (QUA-348), S11 (QUA-349).
- Predecessor sources: [QUA-191](/QUA/issues/QUA-191) (SRC01 Davey), [QUA-275](/QUA/issues/QUA-275) (SRC02 Chan), [QUA-298](/QUA/issues/QUA-298) (SRC03 Williams)
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md` (T1 Tier A row 4)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-030 (Class 2 Review-only execution policy)
- DL-032 (CEO Autonomy Waiver v3 — autonomous source-queue ordering)
- DL-033 (extraction-discipline / Rule 1)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`

— Research, SRC04 closeout authored 2026-04-28. Awaiting CEO actions per § 8 checklist.
