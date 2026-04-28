# Strategy Card — Chan AT Forex Cointegrating-Pair Linear Mean-Reversion (daily, rolling-Johansen non-unity hedge, optional rollover-interest filter)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 5229-5430 (Ex 5.1 + Ex 5.2 verbatim) + Ex 5.1 setup discussion lines 5170-5228 (FX returns formula equations 5.1-5.4).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S05
ea_id: TBD
slug: chan-at-fx-coint-pair
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - cointegration-pair-trade                  # entry mechanism: Johansen-tested cointegrating currency pair with non-unity hedge ratio; spread = h1·log(y1) + h2·log(y2) (using Johansen first eigenvector as hedge weights)
  - zscore-band-reversion                     # signal mechanism: spread Z-score (linear-proportional or Bollinger-band-thresholded as parameter)
  - mean-reach-exit                           # exit mechanism: spread returns to within ±N·σ of training-set mean
  - symmetric-long-short                      # both long-spread and short-spread directions deployable
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 5 'Mean Reversion of Currencies and Futures', § 'Trading Currency Cross-Rates' (PDF pp. 109-115 / printed pp. 109-115). Example 5.1 'Pair Trading USD.AUD versus USD.CAD Using the Johansen Eigenvector' (PDF pp. 110-112) is the primary form. Example 5.2 'Pair Trading AUD.CAD with Rollover Interests' (PDF pp. 114-115) is the variant with direct cross-rate trading + rollover interest treatment."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch4_5_pp87-132.txt` + `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 5229-5430. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **linear mean-reversion strategy on a cointegrating currency pair**, where the hedge ratio is derived from a rolling Johansen eigenvector (rather than from a static OLS regression as in S01 chan-at-bb-pair). The two-symbol Johansen test runs on the two relevant currency-quoted-against-USD price series (e.g., AUD.USD and CAD.USD) over a 250-day rolling training window, the first eigenvector becomes the hedge weights, and the resulting spread's daily Z-score (over a 20-day moving statistics lookback) drives a linear-proportional unit allocation: numUnits = -zScore. The thesis is that two commodity-currency exchange rates (Australian dollar + Canadian dollar, both quoted against USD) cointegrate due to shared exposure to commodity-driven economic factors — and that rolling-Johansen with non-unity hedge ratios captures the cointegration dynamics better than direct cross-rate trading or unity-hedge-ratio methods.

The strategy folds two source variants:

- **Variant A (Ex 5.1, PDF p. 111):** Johansen test on AUD.USD vs CAD.USD ⇒ non-unity hedge ratio between the two USD-quoted rates ⇒ trade USD-denominated portfolio with capital allocation per Johansen eigenvector. APR 11%, Sharpe 1.6 (Dec 2009 - Apr 2012).
- **Variant B (Ex 5.2, PDF p. 114):** Linear MR on the directly-tradable cross-rate AUD.CAD with simpler unity hedge ratio + rollover interest treatment in the daily P&L. APR 6.2%, Sharpe 0.54 (worse than Variant A — Chan attributes the gap to the non-unity hedge advantage in Variant A).

Chan's verbatim summary of Variant A:

> "Taking care to exclude the first 250 days of rolling training data when computing the strategy performance, the APR is 11 percent and the Sharpe ratio is 1.6, for the period December 18, 2009, to April 26, 2012." (p. 112)

Chan's verbatim summary of Variant B:

> "This simple mean reversion strategy yields an APR of 6.2 percent, with a Sharpe ratio of 0.54, which are much weaker results than those in Example 5.1, which, as you may recall, use a nonunity hedge ratio." (p. 115)

The card's default is Variant A (Ex 5.1) — the higher-performing form. Variant B is a parameter-set alternative (and a P3 sweep axis): direct cross-rate trading (`hedge_form = unity`) with optional rollover interest treatment toggled on. The rollover interest treatment is per Chan's Equation 5.6 (excess return formula, p. 113-114).

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Chan's deployment: AUD/USD vs CAD/USD currency pair (commodity-economy currencies)
  # V5 Darwinex-native fit is excellent: AUDUSD.DWX, USDCAD.DWX, AUDCAD.DWX (cross-rate) all available
timeframes:
  - D1                                        # Chan deploys on daily closes
session_window: end-of-day                    # signals computed on daily close (5 p.m. ET per Chan's "overnight" definition, p. 113); entries/exits on next-day open
primary_target_symbols:
  - "AUD.USD vs CAD.USD (Chan Ex 5.1, p. 111)"
  - "AUD.CAD direct cross-rate (Chan Ex 5.2, p. 114; unity-hedge variant)"
  - "V5 Darwinex mapping: AUDUSD.DWX + USDCAD.DWX simultaneously (Variant A) or AUDCAD.DWX directly (Variant B)"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 5 Ex 5.1 (default, PDF p. 111-112) and Ex 5.2 (variant, PDF p. 114-115).

```text
PARAMETERS (Chan-defaults; mostly unspecified - explicitly stated in his MATLAB code):
- TRAINLEN    = 250        // rolling Johansen training-window length in days; Chan reports
                          //   "fixed training set of 250 days (which gives better results in
                          //   hindsight)" (p. 110)
- LOOKBACK    = 20         // Z-score moving average + std dev lookback in days; Chan uses 20.
- ENTRY_K     = 0.0        // LINEAR mode: position is proportional-to-z (no threshold) by
                          //   default. Chan's Ex 5.1 code: numUnits(t) = -zScore (no thresh-
                          //   olding; linearity = unbounded capital but smooth capital scaling).
                          //   BOLLINGER mode (sweep axis): ENTRY_K=1.0, EXIT_K=0.0 ≡ S01-style.
- HEDGE_FORM  = johansen   // {johansen, ols, unity}; Chan Ex 5.1 default = johansen first
                          //   eigenvector; Ex 5.2 default = unity (direct cross-rate trading).
- ROLLOVER    = false      // Ex 5.1 default OFF (Chan: "the impact of rollover interests is
                          //   usually not large for short-term strategies", p. 110); Ex 5.2
                          //   default ON (Chan adds rollover treatment for the multi-day cross-
                          //   rate variant).
- BAR         = D1

PER-DAY (at daily close, generating signals for next session; t indexed from TRAINLEN+1):
- // Step 1 — rolling Johansen test on the pair over the trailing TRAINLEN window
- WINDOW = log(y(t-TRAINLEN : t-1, :))                       // y is Tx2 array of two USD-quoted rates
- res = johansen(WINDOW, det_order=0, lag_k=1)                // det_order=0 (non-zero offset, zero drift)
- hedgeRatio(t, :) = res.evec(:, 1)'                          // first eigenvector = hedge ratio (Variant A)
- // alternative: hedgeRatio(t, :) = [1, -1] for unity (Variant B); or OLS regression slope (Bollinger sibling)
- // Step 2 — synthesize the unit portfolio's market value over the trailing LOOKBACK
- yport = sum(y(t-LOOKBACK+1 : t, :) .* repmat(hedgeRatio(t, :), [LOOKBACK, 1]), 2)   // Tx1 spread series
- // Step 3 — Z-score the spread vs its own LOOKBACK moving statistics
- ma   = mean(yport)
- mstd = std(yport)
- z(t) = (yport(end) - ma) / mstd

ENTRY (LINEAR mode, Chan's Ex 5.1 default — proportional-to-z, no Bollinger thresholding):
- numUnits(t) = -z(t)
- positions(t, :) = numUnits(t) .* hedgeRatio(t, :) .* y(t, :)   // dollar capital per leg

ENTRY (BOLLINGER mode, P3 sweep alternative — discrete ±1 unit thresholding ≡ S01-style):
- if z(t) < -ENTRY_K then OPEN_LONG_SPREAD  at next bar's open with hedgeRatio(t, :)
- if z(t) > +ENTRY_K then OPEN_SHORT_SPREAD at next bar's open with hedgeRatio(t, :)

NOTE on rollover interest: When ROLLOVER=true (Ex 5.2 default), the daily P&L formula is
adjusted per Chan's Equation 5.6 (p. 113-114) to include log(1 + i_B) - log(1 + i_Q) for an
overnight position in B.Q, with TRIPLE rollover interest on Wednesdays for AUD/CAD (per
Chan's MATLAB "isWednesday" / "isThursday" handling, p. 114-115). Implementation requires
historical interest-rate series for both currencies (Reserve Bank of Australia + Bank of
Canada money market rates per Chan p. 114).
```

## 5. Exit Rules

```text
EXIT (LINEAR mode):
- numUnits is rebalanced each bar to -z(t); when z(t) returns to 0 (the training-set mean),
  numUnits naturally goes to 0 (no position). Entry and exit are continuous.

EXIT (BOLLINGER mode, P3 sweep alternative):
- if z(t) >= -EXIT_K then CLOSE_LONG_SPREAD  at next bar's open
- if z(t) <=  EXIT_K then CLOSE_SHORT_SPREAD at next bar's open  // EXIT_K=0 ≡ exit at mean

NO STOP-LOSS:
- Chan, Ch 6 p. 153: "stop losses are not consistent with mean-reverting strategies."
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop.

NO TIME-STOP / NO TRAILING / NO PARTIAL CLOSE.
- Chan's Ex 5.1 and Ex 5.2 hold positions until z reverts; no max-hold imposed.
- Friday Close: standard V5 default applies (force-flat at Friday 21:00 broker time);
  multi-day cross-rate holds may straddle weekends. Friday close + rollover interest
  interaction discussed in § 6.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — multi-day
  cross-rate holds may straddle weekends; rollover-interest-treatment interaction at
  Friday-close means re-entry Monday loses the weekend rollover)
- pyramiding: NOT allowed in BOLLINGER mode (one open spread position per direction at a time);
  in LINEAR mode, "position size = -z" is the natural size proxy (numUnits is signed and
  proportional)
- Optional Johansen training-window warm-up (P3 sweep axis):
    skip entries for the first WARMUP days = TRAINLEN (Chan's default: 250). Per Chan p. 112:
    "Taking care to exclude the first 250 days of rolling training data when computing the
    strategy performance" — already enforced in default workflow.
- Optional cointegration p-value floor (P3 sweep axis):
    skip entries when Johansen trace statistic < critical value at threshold (e.g., r<=0
    fails the 95% test) — i.e., the pair has stopped cointegrating, so don't trust the
    eigenvector. CEO/CTO call at G0.
```

## 7. Trade Management Rules

```text
- LINEAR mode: numUnits rebalanced each bar (continuous adjustment); no pyramiding in the
  position-stacking sense; one signed position
- BOLLINGER mode: one open spread position per direction at any time (no pyramiding)
- gridding: NOT allowed
- hedge ratio TRACKED dynamically (recomputed daily from rolling 250-day Johansen);
  P3 sweep includes "freeze_hedge_at_entry" as alternative axis (BOLLINGER mode only;
  LINEAR mode requires daily rebalance by definition)
- position size in dollar terms: maps to V5 risk-mode framework at sizing-time;
  catastrophic risk handled by kill-switch since strategy has no native stop
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: trainlen
  default: 250
  sweep_range: [125, 250, 500, 750]            # Chan reports 250 with hindsight; sweep brackets 6mo-3y rolling Johansen window
- name: lookback
  default: 20
  sweep_range: [10, 15, 20, 30, 50]            # Chan uses 20; sweep brackets short-to-medium term
- name: signal_mode
  default: linear
  sweep_range: ["linear", "bollinger"]         # LINEAR (Chan Ex 5.1 default, numUnits ∝ -z) vs BOLLINGER (S01-style with thresholding)
- name: entry_k
  default: 0.0                                 # LINEAR mode: continuous (effective entry_k=0)
  sweep_range: [0.0, 0.75, 1.0, 1.25, 1.5, 2.0]
                                              # 0.0 = linear; 1.0 = Bollinger ±1σ; sweep covers both modes
- name: exit_k
  default: 0.0
  sweep_range: [0.0, 0.25, 0.5]                 # Bollinger-mode exit threshold; 0.0 = exit at mean
- name: hedge_form
  default: johansen
  sweep_range: ["johansen", "ols", "unity"]    # Chan Ex 5.1 = johansen; Ex 5.2 = unity; OLS = sibling form (S01)
- name: rollover_treatment
  default: false
  sweep_range: [false, true]                   # Chan Ex 5.1 OFF, Ex 5.2 ON; Chan p. 115: with rollover treatment OFF on Variant B, "the APR would increase just slightly to 6.7 percent and the Sharpe ratio to 0.58", so rollover effect is modest in his test period
- name: cointegration_filter_p
  default: 0
  sweep_range: [0, 0.05, 0.10, 0.20]           # Johansen trace-stat p-value threshold; 0 disables filter
```

P3.5 (CSR) axis: re-run on alternative cointegrating Forex pairs to test the Johansen-pair construction's generalization. Candidates per Chan Ch 5: NZD/USD vs AUD/USD (Antipodean commodity pair); USD/NOK vs USD/MXN (oil-exporter currencies); EUR/USD vs GBP/USD (European currencies). V5 Darwinex-native: all of NZDUSD.DWX, AUDUSD.DWX, USDNOK.DWX, USDMXN.DWX, EURUSD.DWX, GBPUSD.DWX should be available.

## 9. Author Claims (verbatim, with quote marks)

Variant A (Ex 5.1) — AUD.USD / CAD.USD pair via Johansen, daily bars, trainlen=250, lookback=20, linear MR:

> "Taking care to exclude the first 250 days of rolling training data when computing the strategy performance, the APR is 11 percent and the Sharpe ratio is 1.6, for the period December 18, 2009, to April 26, 2012." (p. 112)

Variant B (Ex 5.2) — direct AUD.CAD cross-rate, lookback=20, unity hedge, with rollover interest:

> "This simple mean reversion strategy yields an APR of 6.2 percent, with a Sharpe ratio of 0.54, which are much weaker results than those in Example 5.1, which, as you may recall, use a nonunity hedge ratio." (p. 115)

Variant B with rollover treatment OFF (Chan's sensitivity check):

> "It is also worth noting that even if we had neglected to take into account the rollover interest in this case, the APR would increase just slightly to 6.7 percent and the Sharpe ratio to 0.58, even though the annualized average rollover interest would amount to almost 5 percent." (p. 115)

Cointegration premise for AUD/USD vs CAD/USD pair:

> "ETFs provide a fertile ground for finding cointegrating price series — and thus good candidates for pair trading. For example, both Canadian and Australian economies are commodity based, so they seem likely to cointegrate." (Ch 2 p. 51, applied here to the currencies of those economies in Ch 5)

Why the non-unity hedge ratio matters (p. 110-111):

> "However, our current strategy is very different from a typical forex strategy such as the one in Example 2.5. Here, the hedge ratio between the two currencies is not one, so we cannot trade it as one cross-rate AUD.CAD."

Anti-stop-loss disposition (Ch 6 p. 153, applied to this strategy via § 5):

> "stop losses are not consistent with mean-reverting strategies."

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Chan's reported Variant A APR 11% / Sharpe 1.6 implies ~PF in the 1.3-1.5 range
                                              # pre-cost. Forex spreads on Darwinex (typically 0.5-2 pip on majors) are tighter than
                                              # ETF spreads, so post-cost erosion may be modest.
expected_dd_pct: 12                           # rough estimate; Sharpe 1.6 + zero-stop strategy implies modest interim drawdown
expected_trade_frequency: 50-150/year         # at D1 LINEAR mode with continuous rebalancing, every bar can adjust position;
                                              # in BOLLINGER mode at ±1σ, ~50/year per typical pair-MR cadence
risk_class: medium                            # daily-bar pair-MR with no native stop; non-unity hedge adds robustness vs unity-hedge unity-rate forex
gridding: false                               # neither mode pyramids
scalping: false                               # D1 hold; not scalping
ml_required: false                            # Johansen test + linear regression + threshold or proportional-z is classical statistics
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (Johansen test + Z-score linear or threshold-crossing is fully deterministic given fixed parameters)
- [x] No Machine Learning required (classical statistics; Johansen is generalized eigenvalue decomposition, equivalent pedigree to OLS)
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1 timeframe)
- [ ] **Friday Close compatibility:** multi-day cross-rate holds may straddle weekends; rollover-interest treatment interacts. Flag `friday_close` at risk (§ 12). Net effect on backtest TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + Example numbers + verbatim MATLAB code + verbatim performance quotes)
- [ ] **No near-duplicate of existing approved card** — distinct from S01 chan-at-bb-pair (rolling OLS hedge on ETF pair, NOT Forex Johansen); distinct from S02 chan-at-kf-pair (Kalman state-space on ETF pair, NOT Forex); distinct from SRC02_S01 chan-pairs-stat-arb (cadf on equity ETFs, NOT Johansen on currencies). DISAMBIGUATION confirmed at extraction.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional Johansen warm-up + cointegration p-value filter as sweep axes."
  trade_entry:
    used: true
    notes: "Johansen-derived hedge ratio (rolling 250-day) + spread Z-score on D1 close; linear-proportional or Bollinger-thresholded entry per signal_mode parameter"
  trade_management:
    used: true
    notes: "LINEAR mode: continuous rebalance to -z(t); BOLLINGER mode: hedge ratio dynamically updated each bar (sweep includes freeze_at_entry alternative)"
  trade_close:
    used: true
    notes: "LINEAR mode: numUnits → 0 as z → 0; BOLLINGER mode: z returns inside ±EXIT_K; no time-stop, no native stop-loss"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # multi-day cross-rate holds straddle weekends
  - dwx_suffix_discipline                     # Chan's pair AUD.USD/CAD.USD is directly available as AUDUSD.DWX/USDCAD.DWX. Variant B's AUD.CAD = AUDCAD.DWX. CTO confirms tick-size + spread profile at G0; CSR P3.5 tests on alternative Darwinex-native pairs.
  - kill_switch_coverage                      # no native stop-loss (Chan's anti-stop-loss disposition Ch 6 p. 153). Catastrophic backstop relies entirely on V5's QM_KillSwitch and account-level MAX_DD trip.
  - enhancement_doctrine                      # trainlen=250 is Chan-stated-with-hindsight; lookback=20 is Chan's default. Any post-PASS retune counts as enhancement_doctrine event.

at_risk_explanation: |
  friday_close — D1 cross-rate MR with rolling Johansen produces multi-day average holds.
  Forced flat at Friday 21:00 truncates a fraction of those holds; rollover-interest treatment
  interacts because the LINEAR mode's continuous rebalancing means partial Friday liquidation
  loses some of the daily rollover P&L. Net backtest impact TBD at P3.

  dwx_suffix_discipline — All three Chan-cited symbols (AUD.USD, CAD.USD, AUD.CAD) map cleanly
  to Darwinex CFDs (AUDUSD.DWX, USDCAD.DWX, AUDCAD.DWX). Direction convention may differ
  (USD.CAD vs USDCAD.DWX) — sanity-check at G0.

  kill_switch_coverage — no native stop-loss. V5 account-level kill-switch is the catastrophic
  backstop. CTO sanity-checks at P5 that kill-switch sizing covers the worst-case "cointegration
  breaks down mid-position and pair diverges indefinitely" scenario (e.g., a fundamental shift
  in commodity-currency correlations during a Bank of Canada / Reserve Bank of Australia rate
  divergence event).

  enhancement_doctrine — Chan: "fixed training set of 250 days (which gives better results in
  hindsight)" (p. 110). Both trainlen and lookback are reported with hindsight. Any P3 sweep
  result is the strategy's first proper out-of-sample tuning; any post-PASS retune is an
  enhancement_doctrine event.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional Johansen warm-up + cointegration p-value filter as sweep axes
  entry: TBD                                  # rolling 250-day Johansen test on log-prices (need a Johansen library or implementation; ~200-400 LOC native MQL5 for the eigendecomposition + trace-statistic computation; Phase 1 CTO may decide to use a precomputed Python preprocessing layer if the daily Johansen recomputation is too costly in MQL5)
  management: TBD                             # LINEAR: continuous rebalance to -z(t) each bar; BOLLINGER: discrete ±1 unit threshold
  close: TBD                                  # LINEAR: numUnits → 0; BOLLINGER: z returns inside ±EXIT_K
estimated_complexity: medium                  # the dominant implementation cost is the Johansen eigendecomposition; everything else is small
estimated_test_runtime: 4-8h                  # P3 sweep over the Johansen window grid + signal_mode + thresholds + hedge_form is meaningful (~5,000 cells effective); rolling Johansen recomputation is ~250 ops per backtest day
data_requirements: standard                   # D1 OHLC on two .DWX FX symbols simultaneously; Variant B with rollover requires daily interest-rate series for AUD + CAD (per-card filter, not blocking the standard variant)
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT (awaiting CEO + Quality-Business review) | this card |
| P1 Build Validation | TBD | TBD | TBD |
| P2 Baseline Screening | TBD | TBD | TBD |
| P3 Parameter Sweep | TBD | TBD | TBD |
| P3.5 CSR | TBD | TBD | TBD |
| P4 Walk-Forward | TBD | TBD | TBD |
| P5 Stress | TBD | TBD | TBD |
| P5b Calibrated Noise | TBD | TBD | TBD |
| P5c Crisis Slices | TBD | TBD | TBD |
| P6 Multi-Seed | TBD | TBD | TBD |
| P7 Statistical Validation | TBD | TBD | TBD |
| P8 News Impact | TBD | TBD | TBD |
| P9 Portfolio Construction | TBD | TBD | TBD |
| P9b Operational Readiness | TBD | TBD | TBD |
| P10 Shadow Deploy | TBD | TBD | TBD |
| Live Promotion | TBD | TBD | TBD |

## 16. Lessons Captured

```text
- 2026-04-28: SRC05_S05 folds Chan AT Ex 5.1 + Ex 5.2 into ONE card (rather than two
  separate cards) per the SRC03 fold-pattern precedent (e.g., Williams S05 chan-at-tdom-bias
  consolidated dozens of "best buy/sell day of year" tabulations into one card with
  parameter sets). The two source variants represent distinct PARAMETER POINTS in a single
  strategy space (`hedge_form` ∈ {johansen, unity, ols} × `rollover_treatment` ∈ {false, true})
  rather than distinct mechanical strategies. Variant A (Ex 5.1, johansen + no-rollover) is
  the higher-performing default; Variant B (Ex 5.2, unity + rollover) is a P3 sweep point
  that doubles as the rollover-interest-impact ablation. CEO/Quality-Business sanity-checks
  the fold at G0.

- 2026-04-28: This card extends V5 vocab coverage by reusing existing flags. NO new vocab
  gap surfaced for S05. The Johansen-derived non-unity hedge ratio is an implementation
  detail of `cointegration-pair-trade` (currently parameterized via OLS / cadf in SRC02
  chan-pairs-stat-arb; Johansen is a multi-instrument generalization of cadf that produces
  the same flag class). The LINEAR proportional-to-z signaling is captured by
  `zscore-band-reversion` with ENTRY_K=EXIT_K=0 (limiting case). The mean-reach exit (LINEAR
  mode: numUnits → 0 as z → 0) is `mean-reach-exit`.

- 2026-04-28: Disambiguation against SRC02 chan-pairs-stat-arb (GLD/GDX cadf 2-leg pair):
  - SRC02_S01 uses the cadf test (Engle-Granger 2-step) on equity ETFs for a long-term
    fundamental-cointegration story (GLD ≈ value of gold; GDX ≈ value of gold-mining
    companies; Chan p. 51-52 economic explanation).
  - This card uses the Johansen test (multi-equation cointegration) on FOREX cross-rates
    for a commodity-currency cointegration story (AUD ≈ Aussie commodity exporter; CAD ≈
    Canadian commodity exporter).
  - Different test method (cadf is single-equation; Johansen is multi-equation generalized
    eigenvalue decomposition).
  - Different asset class (equity ETFs vs Forex cross-rates).
  - Different exit mechanism (chan-pairs-stat-arb uses mean-reach + half-life-OU time-stop;
    this card uses linear-proportional or Bollinger-mean-reach without time-stop).
  Decision: DISTINCT cards, NOT a fold. Same flag set (`cointegration-pair-trade` +
  `mean-reach-exit` + `zscore-band-reversion`) but distinct strategy_id per the
  asset-class-and-test-method axis.

- 2026-04-28: Forex-architecture-fit is EXCELLENT for V5. AUDUSD.DWX, USDCAD.DWX, and
  AUDCAD.DWX are all standard Darwinex CFD symbols. Unlike S01 (GLD/USO → no perfect DWX
  equivalent) or S02 (EWA/EWC → no DWX MSCI ETFs), this card maps directly to the V5
  default deployment universe.
```
