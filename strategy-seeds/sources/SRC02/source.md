---
source_id: SRC02
tier: T1                                      # curated local PDF (OWNER-supplied)
parent_issue: QUA-275                         # CEO PATCHed in_review → done on 2026-04-28 (closeout comment 65e06e0e)
status: ceo_ratified_2026-04-28               # all 8 cards APPROVED at G0; 5 vocab additions ratified; 3 friday-close waivers granted
authored-by: Research Agent
last-updated: 2026-04-28
budget_tracking:
  heartbeats_used: 9                          # h1 scaffold; h2 S01 + Ex 7.1 SKIP; h3 S02; h4 S07+S08 + HFT/Leverage SKIPs; h5 S05+S06; h6 S03+S04; h7 PEAD SKIP + completion_report; h8 sub-issue creation + closeout comment; h9 CEO-ratification disposition update
  cards_drafted: 8                            # S01-S08; PEAD reclassified as SKIP (underspecified-beyond-cardable, same as SRC01 Davey hogs)
  cards_passed_g0: 8                          # CEO 2026-04-28 closeout (65e06e0e): all 8 APPROVED; S01/S02 Path 1; S03/S04/S05/S06 Path 2 cancelled; S07/S08 Path 2 conditional on QUA-331
  cards_killed_pre_p1: 0
  vocab_flags_ratified: 5                     # cointegration-pair-trade, mean-reach-exit, zscore-band-reversion, annual-calendar-trade, cross-sectional-decile-sort
extraction_pass_status: complete              # all chapters surveyed; final set 8 cards + 4 SKIPs; completion_report.md drafted in heartbeat 7; CEO ratified 2026-04-28
completion_report: ceo_ratified               # CEO 65e06e0e closeout adopted all 5 enhancement-loop recommendations into QUA-236 + back-port filed as QUA-332 (since committed e8da66f)

---

# SRC02 — Ernest P. Chan, *Quantitative Trading: How to Build Your Own Algorithmic Trading Business*

QUA-275 is the parent SRC issue per [QUA-188 waiver v3](/QUA/issues/QUA-188) (CEO-autonomous source-queue ordering) and Process 13 (one-source-at-a-time, child sub-issue per strategy). Source rank: T1 Tier A, `proposed_order = 2` per [`SOURCE_QUEUE.md`](../SOURCE_QUEUE.md). Opened 2026-04-27 evening as the next source after SRC01 (Davey, [QUA-191](/QUA/issues/QUA-191)) closeout.

## 1. Source identity

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: TBD                              # populated per-card with chapter/section/page on extraction
    quality_tier: A                            # peer-known quant practitioner; PhD physicist (Cornell); ex-Morgan Stanley / Credit Suisse / Maple Securities; principal of E.P. Chan & Associates; widely-cited *epchan.blogspot.com*
    role: primary
```

## 2. Source-text status

```yaml
source_text_path: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf"
file_size_bytes: 3714990                       # 3.7 MB
file_modified: 2025-04-28                      # per `ls -la` mtime
text_extraction_method: poppler `pdftotext -layout` (verified working on TOC pp. 1-14, Ch 2 pp. 9-30, Ch 3 pp. 31-73, Ch 7 pp. 116-165)
status: on_disk
```

Raw text excerpts archived under `raw/`:

- `raw/toc_pp1-14.txt` — front matter + TOC
- `raw/ch2_fishing_pp9-30.txt` — Ch 2 "Fishing for Ideas"
- `raw/ch3_backtesting_pp31-73.txt` — Ch 3 "Backtesting" front half (Examples 3.1-3.5)
- `raw/ch3_pitfalls_pp60-95.txt` — Ch 3 "Backtesting" back half (Examples 3.6-3.8) + start of Ch 4
- `raw/ch7_special_topics_pp116-165.txt` — Ch 7 "Special Topics" (Examples 7.1-7.6)

Additional `raw/` extractions added per chapter at extraction time.

## 3. Why Chan #2 (per QUA-275)

Per QUA-275 description and `SOURCE_QUEUE.md` § "Why this ordering":

> Chan, *Quantitative Trading* — clean structure, statistically-rigorous, mean-reversion + momentum classics. Strong V5 fit.

Three role-specific reasons reinforce the slot:

1. **Methodology complement to Davey.** SRC01 was a process-textbook (Davey: data → walk-forward → Monte Carlo → live). Chan covers the same lifecycle with a more statistical tilt: Sharpe-ratio rigor (Ch 2 pp. 18-21, Ch 3 § "Performance Measurement"), survivorship-bias quantification (Ch 2 p. 24, Ch 3 Example 3.3), look-ahead-bias detection procedure (Ch 3 § "Look-Ahead Bias", pp. 51-54). Cross-walk against V5's P-stage flow yields a second methodology-validation pass (input to QUA-236 enhancement loop).
2. **Diversity-bias relief on strategy classes.** SRC01 ratio: 4/5 cards mean-reversion-flagged. SOURCE_QUEUE `diversity_bias_rules` would force a non-mean-reversion next pick if 3+ consecutive same-class triggers fired. Chan's Ch 7 explicitly covers BOTH mean-reversion (cointegration / pairs / Bollinger) AND momentum (PEAD / seasonal / regime-switching), plus statistical-arbitrage and factor-model angles V4 has not deployed. Acceptable diversification — the second source covers mean-reversion AND adds momentum, pairs, and factor-model classes.
3. **Net-new strategy classes vs V4.** Chan introduces statistical-arbitrage / cointegration-pairs (Examples 3.6, 7.2, 7.3), PCA-based factor models (Example 7.4), seasonal-trades-in-stocks (Example 7.6), and post-earnings-announcement drift (PEAD; Ch 7 pp. 117-118). None of these have V4 SM_XXX deployment evidence per `strategy-seeds/strategy_type_flags.md` Mining-provenance table. SRC02 may surface candidates for new flag-vocabulary additions (per the addition-process documented at the bottom of `strategy_type_flags.md`).

## 4. Expected strategy count

Chan is **methodology-and-toolkit-heavy** by design — like Davey, this is a process textbook, not a strategy library. The named strategies are illustrative anchors for backtesting / Sharpe-ratio / cointegration / factor-model demonstrations. Per **DL-033 Rule 1** (every distinct mechanical strategy that passes V5 hard rules gets a card; pipeline G0 → P10 is the filter, not Research's prior beliefs), Research extracts cards regardless of perceived quality.

```yaml
expected_strategy_count: 4-7                  # preliminary; revised at extraction
expected_chapter_count: 8                     # plus 1 appendix (MATLAB quick-survey, methodology only)
strategy_locations:                            # validated at extraction
  - "Example 3.6 (pp. ~55-65) — GLD/GDX pair trading. Linear-regression hedge ratio + ±N·σ entry / mean-reversion exit. Cross-references Ch 7 cointegration analysis."
  - "Example 3.7 (pp. ~65-72) — Mean-reverting Bollinger-band model on ES futures (5-minute bars). Short on close > MA + 2σ, long on close < MA − 2σ; exit at ±1σ. Davey's transaction-cost demonstration; Chan uses it to show Sharpe-ratio collapse from +3 to −3 once 1bp/round-trip fee applied."
  - "Example 3.8 (pp. ~70-73) — Small variation on an existing strategy (data-snooping demonstration). May or may not be a distinct mechanical strategy; classify at extraction."
  - "Example 7.1 (pp. ~120-126) — Regime-switching with hidden-Markov / machine-learning detector for one specific stock. **EXPECTED V5 HARD-FAIL** per `EA_ML_FORBIDDEN` if the detector requires gradient-trained weights. Disambiguation per `strategy_type_flags.md` § E (HMM with EM is statistical fit, not ML — allowed; gradient-trained NN is ML — forbidden). Read the example carefully before deciding card-vs-skip."
  - "Example 7.2 (pp. ~128-132) — Cointegrating portfolio formation (two-or-more-leg hedge ratio via Johansen / Engle-Granger). Pair-trade execution rule may or may not be re-stated here vs Example 3.6; if same rule, single card cross-referenced; if distinct (multi-leg portfolio rather than 1:1 pair), separate card."
  - "Example 7.3 (pp. ~133-135) — Cointegration vs Correlation counterexample (KO/PEP). Davey-style methodology demo. **Likely not a deployable strategy by Chan's own framing** — pedagogical demonstration of why correlation is insufficient. Per Rule 1, classify card-vs-not-card after reading."
  - "Example 7.4 (pp. ~135-140) — Principal Component Analysis factor model. Multi-stock factor-model strategy. **Structural at-risk concern:** Darwinex DXZ deployment is single-symbol EA; multi-stock factor strategies map awkwardly to V5 architecture. Card carries `dwx_suffix_discipline` + structural-fit notes for CTO sanity-check."
  - "Example 7.5 (pp. ~141-143) — Half-Life of Mean-Reverting Series. **Methodology, not a strategy** — Ornstein-Uhlenbeck half-life calculation. Not card-eligible by itself; provides parameter-sweep guidance for the cointegration-pair cards."
  - "Example 7.6 (pp. ~144-150) — Seasonal trade in stocks/commodities. Specific calendar-window trade Chan's own blog (epchan.blogspot.com/2007/11/seasonal-trades-in-stocks.html) describes. **Chan disclaims** — 'I would not have traded this strategy' (Ch 2 pp. 9-12 reference). Per Rule 1, card extracted regardless; pipeline G0/P2 decide."
  - "Ch 7 narrative (pp. 117-118) — Post-Earnings-Announcement Drift (PEAD). Buy on positive earnings surprise, short on negative; momentum thesis. **Structural at-risk concern:** requires per-stock earnings-calendar data, which is not in Darwinex-native data feeds (`darwinex_native_data_only` Hard Rule binds). Card extracted with explicit data-fit note for CTO."
  - "Ch 2 (pp. 9-30) — 'Fishing for Ideas'. Methodology / source-list (TABLE 2.1 of trading-idea sources). Likely no extractable strategies of its own; check for inline mechanical sketches at extraction."
  - "Ch 5 (pp. 81-93) — Execution Systems. Infrastructure, no strategies expected. Confirm at extraction."
  - "Ch 6 (pp. 95-114) — Money and Risk Management (Kelly formula). Risk-sizing methodology, not a strategy. Confirm at extraction."
  - "Ch 8 (pp. 161-162) — Conclusion. Memoir / framing, no strategies expected."

notes: |
  Chan's structure is strongly methodology-weighted with a strategy-rich Ch 7 ("Special Topics").
  Expected harvest is 4-7 cards depending on:
    (a) Example 7.1 ML cardability (likely SKIP if neural-net detector required)
    (b) Example 7.3 KO/PEP whether deployable or pure counterexample
    (c) Example 7.4 PCA factor model whether the architecture-fit warning blocks G0
    (d) PEAD whether the data-feed-fit warning blocks G0
    (e) Examples 3.7 / 3.8 distinct vs nested in Example 3.6's Bollinger family

  Rule 1 binds: every distinct mechanical strategy that passes V5 hard rules gets a card. Pipeline
  gates do the filtering. Research extracts; CEO + Quality-Business + CTO ratify per process 13.
```

## 5. v0 filter rules applied to this source

Inherited from QUA-275 acceptance criteria + DL-029 strategy-research workflow + the v5_flags conventions in `SOURCE_QUEUE.md`:

- **Mechanical only** — Chan publishes MATLAB code at `epchan.com/book/exampleN.m` for most examples (TOC + Ch 3-7 inline references). Mechanical-discipline binding is verifiable from source code where available.
- **No Machine Learning** — Example 7.1 explicitly uses "machine learning tool" for regime detection. **EXPECTED V5 HARD-FAIL** per `EA_ML_FORBIDDEN` unless the detector reduces to an HMM-with-EM (statistical, allowed per `strategy_type_flags.md` § E disambiguation). Read Example 7.1 carefully at extraction before classification.
- **`.DWX` suffix discipline** — Chan's universe is US equities (GLD, GDX, KO, PEP, IGE) + ES futures + currency examples. V5 deployment maps to Darwinex spot FX / indices / metals (`EURUSD.DWX`, `GOLD.DWX`, `US500.DWX`). Cards from this source raise `dwx_suffix_discipline` in `hard_rules_at_risk`; per-card mapping happens at CTO sanity-check. **Stocks-without-Darwinex-equivalent (e.g., KO, PEP, GDX, GLD) are an architecture concern** — V5 has no multi-stock universe deployed today. CTO ratifies which cards survive at G0.
- **`darwinex_native_data_only` Hard Rule** — Chan strategies that require per-stock earnings-calendar (PEAD), survivorship-bias-free CRSP-style equity data (cointegration over hundreds of pairs), or extended-hours / pre-market data are at risk against Darwinex-native feeds. Per-card flagging at extraction.
- **Magic-formula registry compatible** — Chan's strategies are mostly position-at-a-time at the symbol level (one pair = one position). Multi-leg cointegration portfolios (Example 7.2 Johansen-style 3+ leg hedge) may push against `one_position_per_magic_symbol` — flag at extraction.
- **News-compliance compatible** — PEAD is event-driven (earnings); `news_pause_default` Hard Rule binds. Other Chan strategies (cointegration / Bollinger / seasonal) are pattern-based; should not bind beyond standard P8 windows.
- **Friday Close compatibility** — Pair-trading and cointegration strategies typically hold across weekends; may need explicit `friday_close` Hard Rule waiver documentation per card.
- **Stocks-vs-FX caveat** — V5 framework targets Darwinex spot FX + indices + metals. Chan trades US equities heavily. Per-card mapping decisions documented at CTO sanity-check; data-feed and contract-size differences flagged in each card's `hard_rules_at_risk`.

## 6. Sub-issue queue (per QUA-275 process-13 setup)

Per QUA-275: "All sub-issues created `blocked` EXCEPT the first (which is `todo`). Next sub-issue unblocks only when prior strategy completes its end-to-end pipeline (Programmer → P1 Build → P2..P8 → Quality-Tech sign-off)."

The slot table is populated as cards are drafted. Slug pattern: `chan-<topic>` per QUA-275. Filenames follow the QUA-243 update to `_TEMPLATE.md` (`<slug>_card.md` not `QM5_NNNN_<slug>_card.md`).

| Slot | Strategy slug | Card path | Sub-issue | Status | Source location |
|---|---|---|---|---|---|
| S01 | `chan-pairs-stat-arb` | `strategy-seeds/cards/chan-pairs-stat-arb_card.md` | [QUA-284](/QUA/issues/QUA-284) **`todo`** | **APPROVED Path 1 (CEO 2026-04-28)** | Example 3.6 (pp. 55-59) + Ex 7.2 (pp. 128-130) + Ex 7.3 (pp. 131-133) + Ex 7.5 (pp. 141-142) + Ch 7 narrative pp. 126-133 — folded into one card. Cointegration pair-trade with cadf filter, OLS hedge ratio, ±N·σ z-score entry/exit, OU-half-life time-stop. **`friday_close` waiver GRANTED** unconditionally per CEO 65e06e0e (rationale: OU-half-life-driven, not weekend-gap-sensitive; FX-pair spreads have bounded weekend-gap exposure). Sources ratified flags `cointegration-pair-trade` + `mean-reach-exit`. **Currently active first card; Pipeline-Op picks up next.** |
| S02 | `chan-bollinger-es` | `strategy-seeds/cards/chan-bollinger-es_card.md` | [QUA-285](/QUA/issues/QUA-285) `blocked` (by [QUA-284](/QUA/issues/QUA-284)) | **APPROVED Path 1 (deliberate-failure pedagogy) (CEO 2026-04-28)** | **Inline ES Bollinger demo, Ch 2 pp. 22-23** (NOT labeled Example 3.x by Chan). Single-symbol M5 Bollinger ±2σ entry / ±1σ exit on E-mini S&P. Sharpe +3 pre-cost, −3 with 1 bp/trade cost — Chan's deliberate transaction-cost FAILURE example #1. CEO PATCHed `blockedByIssueIds=[QUA-284]` (sequential after S01 per process 13). Maps to `US500.DWX`. Primary risk: `scalping_p5b_latency` (M5 churn). Sources ratified flag `zscore-band-reversion`. |
| S03 | `chan-khandani-lo-mr` | `strategy-seeds/cards/chan-khandani-lo-mr_card.md` | [QUA-286](/QUA/issues/QUA-286) **`cancelled`** | **APPROVED Path 2 (V5-arch-incompatible REF) (CEO 2026-04-28)** | Example 3.7 + Example 3.8 folded — Khandani-Lo continuous-weight cross-sectional MR on S&P 500. Sharpe 0.25/−3.19 close-bar; 4.43/**0.78** open-bar. Card stays on disk as institutional memory for future multi-stock-equity broker-expansion; sub-issue `cancelled` because V5 Darwinex stack cannot deploy ~500 simultaneous positions. Sources ratified flag `cross-sectional-decile-sort` (continuous-distance variant). |
| S04 | `chan-pca-factor` | `strategy-seeds/cards/chan-pca-factor_card.md` | [QUA-287](/QUA/issues/QUA-287) **`cancelled`** | **APPROVED Path 2 (REF + deliberate-failure) (CEO 2026-04-28)** | Example 7.4 — PCA factor model on S&P 600. Author result: `avgret = -1.8099` ("A very poor return!", p. 138). Chan's THIRD deliberate-failure example in SRC02. ML disambiguation explicit: PCA + OLS = classical linear algebra, NOT ML; EA_ML_FORBIDDEN does NOT bind. Card stays on disk as REF + deliberate-failure-pedagogy reference; sub-issue `cancelled` per Path 2. Sources ratified flag `cross-sectional-decile-sort` (pca-rank-decile variant). |
| S05 | `chan-january-effect` | `strategy-seeds/cards/chan-january-effect_card.md` | [QUA-288](/QUA/issues/QUA-288) **`cancelled`** | **APPROVED Path 2 (REF) (CEO 2026-04-28)** | Example 7.6 — annual cross-sectional decile MR on S&P 600 small-cap. Performance: −2.44% / −0.68% / +8.81% in 2005/2006/2007 (1 winner, 2 losers; +8.81% driven by SocGen/Fed tail event). Sub-issue `cancelled`; card stays on disk as REF. Sources ratified flag `cross-sectional-decile-sort` (discrete-decile + ranking_metric=prior-year-return). |
| S06 | `chan-yoy-same-month` | `strategy-seeds/cards/chan-yoy-same-month_card.md` | [QUA-289](/QUA/issues/QUA-289) **`cancelled`** | **APPROVED Path 2 (REF + deliberate-failure) (CEO 2026-04-28)** | Example 7.7 — Heston-Sadka year-on-year anomaly on S&P 500. Performance verbatim: **`Avg ann return = -0.9167   Sharpe ratio = -0.1055`** (p. 147) — Chan's deliberate-failure example #2 (anomaly decayed post-2002). Sub-issue `cancelled`; card stays on disk as REF + deliberate-failure-pedagogy reference. Sources ratified flag `cross-sectional-decile-sort` (discrete-decile + ranking_metric=year-ago-same-month). |
| S07 | `chan-gasoline-rb-spring` | `strategy-seeds/cards/chan-gasoline-rb-spring_card.md` | [QUA-290](/QUA/issues/QUA-290) `blocked` (by [QUA-331](/QUA/issues/QUA-331)) | **APPROVED Provisional Path 2 pending Darwinex-CFD-inventory check (CEO 2026-04-28)** | Sidebar p. 149 — long-only annual calendar trade on NYMEX RB unleaded gasoline futures (May expiry, Apr 13 → Apr 25). 14 consecutive years of profitability 1995-2008. **`friday_close` waiver GRANTED conditional on Path 1 promotion** per CEO 65e06e0e. Sub-issue blocked-by [QUA-331](/QUA/issues/QUA-331) (Darwinex commodity-CFD-inventory check); under default Path 2 the waiver is moot. Sources ratified flag `annual-calendar-trade`. |
| S08 | `chan-natgas-spring` | `strategy-seeds/cards/chan-natgas-spring_card.md` | [QUA-291](/QUA/issues/QUA-291) `blocked` (by [QUA-331](/QUA/issues/QUA-331)) | **APPROVED Provisional Path 2 pending Darwinex-CFD-inventory check (CEO 2026-04-28)** | Sidebar p. 150 — long-only annual calendar trade on NYMEX NG natural gas futures (June expiry, Feb 25 → Apr 15). 14 consecutive years of profitability 1995-2008; Amaranth-class blow-up risk explicit (Chan p. 150). **`friday_close` waiver + heightened `kill_switch_coverage` calibration GRANTED conditional on Path 1 promotion** per CEO 65e06e0e (heightened = tighter MAX_DD trip ~6% per-position vs V5 default 10%, plus EA-level `kill_switch_natgas_amaranth` ON). Sub-issue blocked-by [QUA-331](/QUA/issues/QUA-331). Sources ratified flag `annual-calendar-trade`. |
Slot count finalized at **8 cards + 4 SKIPs** (PEAD reclassified to SKIP per source-spec-completeness failure; see Skipped table below). Architecture-fit profile:

| Card | Single/multi-symbol | V5-architecture-fit | Friday-close compat |
|---|---|---|---|
| S01 chan-pairs-stat-arb | 2-symbol pair | flagged (no Darwinex GDX equiv; CSR scan needed) | waiver required |
| S02 chan-bollinger-es | single | clean (US500.DWX) | OK |
| S03 chan-khandani-lo-mr | multi-stock (500) | incompatible | OK (intraday) |
| S04 chan-pca-factor | multi-stock (600) | incompatible | OK (daily rebalance) |
| S05 chan-january-effect | multi-stock (600) | incompatible | OK (1-month hold; spans 4 weekends so technically waiver) |
| S06 chan-yoy-same-month | multi-stock (500) | incompatible | OK (1-month hold) |
| S07 chan-gasoline-rb-spring | single (CFD if available) | flagged (no native Darwinex gasoline) | waiver required |
| S08 chan-natgas-spring | single (CFD if available) | flagged (no native Darwinex natgas) | waiver required + Amaranth-class kill-switch load |

All architecture-incompatible cards (S03, S04, S05, S06) advance through G0 per Rule 1; pipeline G0 / P3.5 decides actual deployability against the Darwinex single-symbol stack.

Skipped sources (failed V5 HARD RULE OR underspecified-beyond-cardable):

| Source location | Reason for skip | Rule-1 classification |
|---|---|---|
| Example 7.1 (pp. 122-126) — "Using a Machine Learning Tool to Profit from Regime Switching in the Stock Market" | **V5 hard-fail per `EA_ML_FORBIDDEN`.** Chan's verbatim implementation: "Finally, we run a perceptron learning algorithm on the outputs of I7 and I9 (a perceptron is a type of neural network). This algorithm will find out the best weights for the different rules with different holding periods (among other parameters) based on a moving window of historical training data with the objective of maximizing the total profit in this window." (p. 124). Per `strategy_type_flags.md` § E `ml-required` definition: "neural net, gradient boost, random forest, online learner ... V5 hard-fail per CLAUDE.md". Perceptron = neural network = ML. The disambiguation against `hmm-regime-blend` (HMM with EM is NOT ML, allowed) does not save this strategy — Chan explicitly uses a perceptron, not an HMM. | V5 HARD-RULE FAILURE — `ml-required` true. |
| Ch 7 § "High-Frequency Trading Strategies" (pp. 151-153) | **Narrative-only; no specific entry/exit rules.** Chan discusses HFT generally — law-of-large-numbers Sharpe argument, backtesting-difficulty challenges, execution-collocation requirements — but does NOT name any specific mechanical strategy. Verbatim p. 152: "it is impossible to explain in general why high-frequency strategies are often profitable, as there are as many such strategies as there are fund managers." Per DL-033 Rule 1, no strategy specification = no card. Aligned with SOURCE_QUEUE.md `HFT_NOT_APPLICABLE` flag (V5 stack MT5 + DXZ live-only cannot run HFT competitively). | Source-spec-completeness failure (NOT a hard-rule failure). |
| Ch 7 § "Is It Better to Have a High-Leverage versus a High-Beta Portfolio?" (pp. 153-154) | **Methodology, not a strategy.** Chan compares Kelly-formula leverage (Ch 6) vs Fama-French beta (Ch 7 factor models) as alternative routes to higher portfolio return. No entry/exit/hold rules; pure portfolio-construction argument. | Source-spec-completeness failure (NOT a hard-rule failure). |
| Ch 7 § "Mean-Reverting versus Momentum Strategies" Post-Earnings Announcement Drift (PEAD) narrative, pp. 117-118 | **Underspecified-beyond-cardable.** Chan describes PEAD conceptually: "this strategy recommends that you buy a stock when its earnings exceed expectations, and short a stock when it falls short." Direction and rationale are specified, but Chan EXPLICITLY delegates the rest to the reader (verbatim p. 118): "As to what kind of news will trigger this, and how long the trending period will last, it is again up to you to find out." Threshold for "exceed expectations" (numeric surprise %), hold period, stop-loss, and universe are all undefined. To draft a card I'd have to import threshold + hold-period values from the referenced quantlogic.blogspot.com article — that would be Research extrapolation, not Chan extraction. **Same classification as SRC01 Davey Ch 1 hogs** ("Underspecified-beyond-cardable"). Compounding `darwinex_native_data_only` concern: PEAD requires per-stock quarterly earnings calendar + analyst-consensus data, neither of which is in Darwinex-native feeds. | Source-spec-completeness failure (NOT a hard-rule failure). |

## 7. Chapter index (TOC seeded; validate page numbers at extraction)

Extracted from PDF pages 1-14 via `pdftotext -layout` 2026-04-27. Page numbers from the printed TOC.

| Chapter | Title | Page | Strategy density (estimate) |
|---|---|---|---|
| 1 | The Whats, Whos, and Whys of Quantitative Trading | 1 | LOW (memoir / framing; "scalability", "demand on time", "non-necessity of marketing") |
| 2 | Fishing for Ideas | 9 | LOW (idea-source list; some inline strategy sketches possible — survey at extraction) |
| 3 | Backtesting | 31 | **MEDIUM** (Examples 3.1-3.8 mix methodology demos and named strategies; 3.6/3.7/3.8 likely card-yielding) |
| 4 | Setting Up Your Business | 75 | LOW (infrastructure; brokerage choice, retail vs prop) |
| 5 | Execution Systems | 81 | LOW (automation infrastructure; minimizing transaction costs) |
| 6 | Money and Risk Management | 95 | LOW (Kelly formula; risk-management methodology — NOT a strategy) |
| 7 | Special Topics in Quantitative Trading | 115 | **HIGH** (mean-reversion vs momentum; regime switching; cointegration; factor models; exit strategy; seasonal; HFT; leverage vs beta — Examples 7.1-7.6 are the strategy-rich core of the book) |
| 8 | Conclusion: Can Independent Traders Succeed? | 161 | LOW (memoir / next-steps narrative) |
| App A | Quick Survey of MATLAB | 163 | LOW (programming-language reference; no strategies) |

Total: 8 chapters + 1 appendix. Strategy-bearing chapters: 3 (Examples 3.6, 3.7, 3.8) and 7 (Examples 7.1-7.6 + PEAD narrative). Ch 1, 4, 5, 6, 8, App A are methodology / infrastructure / memoir; spot-check at extraction but expect zero card yield.

## 8. Extraction plan

Process 13 / DL-033 / QUA-275 binding constraints:

- One source actively worked at a time. **No SRC03+ until ALL SRC02 sub-issues close.**
- One sub-issue per strategy. First sub-issue `todo`, rest `blocked`. Next unblocks only when prior strategy completes its end-to-end pipeline.
- Heartbeat budget: SRC01 yield ratio was 0.71 cards/heartbeat. Track on QUA-275.

Extraction sequence:

1. **First pass — Chapter 7 strategy-rich examples.** Read Examples 7.1-7.6 in order. Disambiguate Ex 7.1 (ML vs HMM-with-EM) per `strategy_type_flags.md` § E. Identify whether Ex 7.2/7.3 fold into the Ex 3.6 pair-trade card or stand alone. Decide PCA factor model (Ex 7.4) cardability.
2. **Second pass — Chapter 3 named examples.** Read Examples 3.6 (GLD/GDX pair), 3.7 (ES Bollinger), 3.8 (data-snooping variation). Decide which are distinct mechanical strategies. Note: Ex 3.6 likely cross-references Ch 7 cointegration analysis; the *strategy* is one entity even if the *exposition* spans two chapters.
3. **Third pass — Ch 2 + Ch 7 narrative.** Survey Ch 2 "Fishing for Ideas" for inline mechanical sketches (none expected; confirm). Extract Ch 7 PEAD narrative if it qualifies as a distinct mechanical strategy under Rule 1 (likely yes; data-fit concerns flag at G0).
4. **Fourth pass — methodology cross-walk.** Ch 1 / 4-6 / 8 surveyed for completeness; produce Davey-style methodology delta in the completion report.
5. **Sub-issue creation.** When all candidate cards drafted to DRAFT, open one sub-issue per strategy under QUA-275 — first as `todo`, rest as `blocked`. Submit for CEO + Quality-Business G0 review per process 13.

Per-chapter progress comments posted to QUA-275 at chapter-boundary granularity. Methodology chapters batched as one combined comment per Part to keep thread noise reasonable.

## 9. Completion report contract

When all S-sub-issues under QUA-275 close, Research authors `strategy-seeds/sources/SRC02/completion_report.md` covering at minimum (per QUA-275 acceptance criterion 3):

- Total strategies extracted vs. expected (4-7)
- Per-strategy verdict (PASS / FAIL / RETIRED) with terminal pipeline phase
- Skipped strategies (failed V5 hard rule or underspecified-beyond-cardable) and reason
- **Strategy-type-flag distribution** (per `strategy_type_flags.md` controlled vocabulary; cross-walk vs SRC01 distribution to feed `STRATEGY_TYPE_DISTRIBUTION.md` once Doc-KM is hired)
- **Methodology-cross-walk delta** (Chan procedure vs V5 P-stage flow): wins / regressions / neutrals — second pass after Davey
- Source quality and density observations
- Yield ratio: `cards_passed_g0 / heartbeats_used` for `budget_tracking` review (SRC01 benchmark: 0.71)
- Recommendation: deeper mining worthwhile? Move on to SRC03 (Williams, *Long-Term Secrets to Short-Term Trading*, `proposed_order = 3`)?

## 10. Cross-references

- Parent issue: [QUA-275](/QUA/issues/QUA-275)
- SRC01 (predecessor): [QUA-191](/QUA/issues/QUA-191), `strategy-seeds/sources/SRC01/`
- Source-text PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`
- Source queue: `strategy-seeds/sources/SOURCE_QUEUE.md` (T1 Tier A row 2)
- Workflow doc: `processes/13-strategy-research.md`
- Card template: `strategy-seeds/cards/_TEMPLATE.md`
- Strategy-type vocabulary: `strategy-seeds/strategy_type_flags.md`
- DL-029 (workflow ratification): `decisions/2026-04-27_strategy_research_workflow.md`
- DL-033 (extraction-discipline / Rule 1): per QUA-275 binding pointer
- QUA-188 waiver v3 (CEO-autonomous source-queue ordering)
- QUA-243 (card-template filename convention update)
- BASIS rule (verbatim-quote citation discipline): `paperclip-prompts/research.md`
