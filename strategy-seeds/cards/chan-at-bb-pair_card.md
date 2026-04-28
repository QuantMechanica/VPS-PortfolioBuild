# Strategy Card — Chan AT Bollinger-Band Pair-Spread Mean-Reversion (daily, dynamic OLS hedge, ±1σ entry / 0σ exit)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 3543-3623 (Ex 3.2 verbatim) + lines 3368-3500 (Ex 3.1 hedge-ratio precondition).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S01
ea_id: TBD
slug: chan-at-bb-pair
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - cointegration-pair-trade                  # entry mechanism: spread of two-leg pair (with regression-derived hedge ratio) crosses ±N·σ band
  - zscore-band-reversion                     # signal mechanism: spread Z-score band trigger
  - mean-reach-exit                           # exit mechanism: spread returns to within ±0σ of mean (Chan's exitZscore=0)
  - symmetric-long-short                      # both long-spread and short-spread directions deployable
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 3 'Implementing Mean Reversion Strategies', § 'Bollinger Bands' (PDF p. 71 / printed p. 70-72), Example 3.2 'Bollinger Band Mean Reversion Strategy'. Hedge-ratio precondition (rolling 20-day OLS regression) sourced from Example 3.1 (PDF p. 67-69 / printed p. 66-69) of the same chapter."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch2_3_pp39-90.txt` + `strategy-seeds/sources/SRC05/raw/full_text.txt` lines 3368-3623. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **classical Bollinger-band mean-reversion strategy applied to a regression-hedged two-leg pair spread**, evaluated each trading day. Chan demonstrates this on the GLD-USO pair (gold ETF vs WTI crude oil ETF) but the construction is generic: any two instruments where (a) a rolling-window OLS regression produces a stable hedge ratio and (b) the resulting spread is short-term mean-reverting. Each day, the spread's Z-score relative to its own moving average and standard deviation triggers entry at ±1σ and exit when the spread returns to within ±0σ (the moving average itself). The thesis is that ETF-pair spreads exhibit short-term mean reversion even when the underlying instruments are not strictly cointegrating — Chan explicitly notes (p. 67) that GLD and USO are *not* cointegrated, yet the strategy is profitable due to *short-term* mean reversion.

This card is the **practical version** Chan promises in Chapter 2 — the linear-MR strategies of Examples 2.5 (USD.CAD single-leg) and 2.8 (EWA-EWC-IGE Johansen triplet) are explicitly disqualified by Chan as "not a practical trading strategy" (p. 50) and "obviously not a practical strategy, at least in its simplest version" (p. 60). Chan p. 70: "For practical trading, we can use the Bollinger band, where we enter into a position only when the price deviates by more than entryZscore standard deviations from the mean." The Bollinger-band wrapper bounds the deployed capital and produces a deterministic entry/exit schedule, addressing the linear strategy's two main drawbacks (unbounded capital + parameter-free signal continuity) at the cost of one tunable trigger threshold.

Chan's verbatim summary, p. 72:

> "The Bollinger band strategy has an APR = 17.8 percent, and Sharpe ratio of 0.96, quite an improvement from the linear mean reversal strategy!"

Note: the GLD-USO instance is *one* example of the strategy; the *strategy* is the BB-MR-on-regression-hedged-pair *construction*, deployable on any cointegration-tested pair. P3.5 CSR (cross-symbol robustness) is the appropriate gate to test the construction's generalization.

## 3. Markets & Timeframes

```yaml
markets:
  - etf_pair                                  # Chan's deployment: GLD/USO commodity-ETF pair
  - equity_pair                               # generalizes per Ch 4 to pairs of equity ETFs (EWA-EWC, etc.)
  - commodities_pair                          # Ch 5 generalizes to currency / futures pairs (S05 chan-at-fx-coint-pair = sibling card on Forex)
  # V5 Darwinex re-mapping at CTO sanity-check: candidate pairs include GOLD.DWX/OIL.DWX (gold/crude proxy) and any cointegrating Darwinex-native pair
timeframes:
  - D1                                        # Chan's deployment: daily closes, lookback=20 trading days
session_window: end-of-day                    # Chan computes the hedge ratio + Z-score on daily closes; entries/exits on next-day open
primary_target_symbols:
  - "GLD-USO (Chan's primary case, p. 67) — V5 candidate proxy: GOLD.DWX / OIL.DWX"
  - "Generic cointegrating pair (Chan p. 70 generalization): any pair where rolling OLS hedge-ratio produces a stationary residual"
```

## 4. Entry Rules

Pseudocode — verbatim from Chan's Ch 3 Ex 3.2 MATLAB code (PDF p. 71-72) and Ex 3.1 hedge-ratio precondition (PDF p. 67-68).

```text
PARAMETERS (Chan-defaults from Ex 3.2 MATLAB code):
- LOOKBACK    = 20         // trading days for both rolling OLS hedge ratio AND for Z-score
                          //   moving average + std deviation; Chan p. 67: "set to near-optimal
                          //   20 trading days with the benefit of hindsight"
- ENTRY_K     = 1.0        // Chan: "entryZscore = 1"
- EXIT_K      = 0.0        // Chan: "exitZscore = 0"  (exit at the mean itself)
- BAR         = D1         // Chan deploys on daily closes

PER-DAY (at daily close, generating signals for next session):
- // Step 1 — rolling OLS regression to recompute the hedge ratio
- LOOKBACK_WINDOW = [t-LOOKBACK+1 .. t]
- regression_result = OLS(y_window = price[USO][t-LOOKBACK+1..t],
                          x_window = [price[GLD][t-LOOKBACK+1..t], ones(LOOKBACK)])
- hedgeRatio[t] = regression_result.beta[1]
- // Step 2 — compute the spread (Chan: "yport" = USO - hedgeRatio*GLD)
- spread[t] = price[USO][t] - hedgeRatio[t] * price[GLD][t]
- // Step 3 — Z-score the spread vs its own moving statistics
- MA_spread[t]  = MovingAverage(spread, LOOKBACK)[t]
- SD_spread[t]  = MovingStd(spread, LOOKBACK)[t]
- z[t]          = (spread[t] - MA_spread[t]) / SD_spread[t]

ENTRY (only when not already in position; one position max per direction):
- if z[t] < -ENTRY_K  then OPEN_LONG_SPREAD  at next bar's open
                          //  (long_spread = LONG USO + SHORT (hedgeRatio * GLD))
- if z[t] > +ENTRY_K  then OPEN_SHORT_SPREAD at next bar's open
                          //  (short_spread = SHORT USO + LONG (hedgeRatio * GLD))

NOTE on hedge-ratio retiming: Chan's MATLAB code re-computes hedgeRatio every day on the
trailing 20-day window. The position once opened is held with the hedge ratio fixed at entry
(per Bollinger-band convention; numUnits is set to 1 or -1 of the spread on entry and
fillMissingData carries the position forward unchanged until exit). The daily hedge-ratio
recomputation is for SIGNAL generation only.
```

## 5. Exit Rules

```text
EXIT (when in position):
- if z[t] >= -EXIT_K  then CLOSE_LONG_SPREAD  at next bar's open  // Chan: longsExit=zScore>=-exitZscore
- if z[t] <=  EXIT_K  then CLOSE_SHORT_SPREAD at next bar's open  // Chan: shortsExit=zScore<=exitZscore
                          //  with EXIT_K=0, both reduce to z crossing the mean

NO STOP-LOSS:
- Chan does not specify a per-trade stop-loss. The Ch 8 risk-management discussion (pp. 169-186)
  notes that mean-reverting strategies are inherently incompatible with stop-loss — "stop losses
  are not consistent with mean-reverting strategies, because they contradict mean reversion
  strategies' entry signals" (Ch 6 p. 153 verbatim).
- V5 framework's QM_KillSwitch + account MAX_DD trip is the catastrophic backstop.

NO TIME-STOP / NO TRAILING / NO PARTIAL CLOSE.
- Chan's Ex 3.2 MATLAB code holds the position until z reverts inside ±EXIT_K. If the spread
  expands further (z grows in magnitude), the position is held — no max-hold imposed.
- Friday Close: standard V5 default applies (force-flat at Friday 21:00 broker time); spread
  may need to be re-entered on Monday open if the signal is still active. Friday-close-compat
  flagged for review at extraction.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: ENABLED (V5 default; flag friday_close at risk per § 12 — multi-day spread holds may straddle weekends)
- pyramiding: NOT allowed (one open spread position per direction at a time)
- Optional cointegration self-test (P3 sweep axis):
    skip entries when the rolling-window cadf or Johansen p-value > THRESHOLD
    // Rationale: Chan (p. 67) notes that GLD-USO are NOT cointegrating — the strategy works
    // because of short-term MR, not long-term cointegration. A cadf-pass filter would
    // FORCE long-term-cointegration discipline at the cost of trade frequency. CEO/CTO call
    // at G0 whether to enable.
- Optional spread-volatility floor (P3 sweep axis):
    skip entries when SD_spread[t] < ATR_FLOOR_BPS · |spread[t]|
    // Rationale: at very low realized spread volatility, the Z-score band is so tight that
    // signal-to-noise collapses. Chan does not include this filter; sweep validates whether
    // it helps.
```

## 7. Trade Management Rules

```text
- one open spread position per direction at any time (no pyramiding)
- position sizing: spread = 1 unit USO + (hedgeRatio_at_entry) units GLD. Chan's "numUnits"
  is in {-1, 0, +1} per his MATLAB code (no scaling-in / scaling-out).
- gridding: NOT allowed
- hedge ratio frozen at entry (per Chan's MATLAB code, the position once opened uses the
  entry-time hedge ratio; the daily recomputation is for signal triggering only)
- position size in dollar terms: maps to V5 risk-mode framework at sizing-time;
  catastrophic risk handled by kill-switch since strategy has no native stop
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback_n
  default: 20
  sweep_range: [10, 15, 20, 30, 50]            # Chan reports 20 (with hindsight); sweep brackets short-to-medium term
- name: entry_k
  default: 1.0
  sweep_range: [0.75, 1.0, 1.25, 1.5, 2.0]     # Chan reports 1.0; tighter = more trades + smaller per-trade edge; wider = fewer + larger
- name: exit_k
  default: 0.0
  sweep_range: [0.0, 0.25, 0.5, 0.75]          # Chan reports 0.0 (exit at mean); positive = exit before full reversion
- name: bar
  default: D1
  sweep_range: [H4, D1, W1]                    # Chan deploys on D1; H4 amplifies trade frequency, W1 dampens
- name: hedge_method
  default: rolling_ols
  sweep_range: ["rolling_ols", "static_ols_train_test", "johansen_eigenvector"]
                                              # Chan p. 67: rolling OLS; alternatives are static OLS over a fixed training window
                                              #   or Johansen eigenvector (closer to Ex 5.1 sibling card S05)
- name: spread_form
  default: price_spread
  sweep_range: ["price_spread", "log_price_spread", "ratio"]
                                              # Chan Ex 3.1 explicitly compares all three: price spread (APR 10.9% / Sharpe 0.59),
                                              #   log price spread (APR 9% / Sharpe 0.5), ratio (negative APR — Chan p. 69)
                                              # Bollinger band on price spread (this card default, Ex 3.2) achieves APR 17.8% / Sharpe 0.96.
- name: cointegration_filter_p
  default: 0                                  # disabled by default
  sweep_range: [0, 0.05, 0.10, 0.20]           # cadf p-value threshold; 0 disables filter
```

P3.5 (CSR) axis: re-run on alternative pairs to test Chan's "any cointegrating pair" generalization. Candidates per Chan Ch 4: EWA-EWC (Australia/Canada commodity ETFs, p. 53), KO-PEP (Coca-Cola / Pepsi equities, Ex 7.3 cross-reference). V5 Darwinex-native candidates: GOLD.DWX/OIL.DWX (proxy for GLD/USO), AUDUSD.DWX/USDCAD.DWX (proxy for EWA-EWC commodity-currency pair).

## 9. Author Claims (verbatim, with quote marks)

GLD-USO pair, daily bars, default thresholds (entry_k = 1.0, exit_k = 0.0), lookback = 20, rolling OLS hedge ratio:

> "The Bollinger band strategy has an APR = 17.8 percent, and Sharpe ratio of 0.96, quite an improvement from the linear mean reversal strategy!" (p. 72)

Comparison of spread-form variants on the same GLD-USO pair (Ex 3.1, p. 68-69):

> "We obtain an annual percentage rate (APR) of about 10.9 percent and Sharpe ratio of about 0.59 using price spread with a dynamic hedge ratio, even though GLD and USO are by no means cointegrated." (p. 68)

> "The APR of 9 percent and Sharpe ratio of 0.5 are actually lower than the ones using the price spread strategy, and this is before accounting for the extra transactions costs associated with rebalancing the portfolio every day to maintain the capital allocation to each ETF." (p. 69, log-price-spread variant)

> "So it should not surprise us if we find the mean-reverting strategy to perform poorly, with a negative APR." (p. 69, ratio-form variant)

Theoretical framing for why Bollinger bands are the practical choice over the Ch 2 linear strategy:

> "For practical trading, we can use the Bollinger band, where we enter into a position only when the price deviates by more than entryZscore standard deviations from the mean. ... At any one time, we can have either zero or one unit (long or short) invested, so it is very easy to allocate capital to this strategy or to manage its risk." (p. 70)

Anti-stop-loss disposition (Ch 6 p. 153, applied to this strategy via § 5):

> "stop losses are not consistent with mean-reverting strategies, because they contradict mean reversion strategies' entry signals."

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Chan's reported APR 17.8% / Sharpe 0.96 implies ~PF in the 1.3-1.5 range on cost-free data;
                                              # P9b operational gating with realistic Darwinex spreads will likely compress this.
expected_dd_pct: 15                           # rough estimate; Chan does not publish max-DD numbers for Ex 3.2; Sharpe 0.96 + zero-stop strategy
                                              # implies meaningful interim drawdown
expected_trade_frequency: 20-50/year/pair     # at D1 with ±1σ trigger and 20-day lookback, expect ~20-50 round-trips per year per pair
risk_class: medium                            # daily-bar pair-MR with no native stop; medium between scalping (S02 Kalman is closer to high) and
                                              # multi-day annual seasonals (low)
gridding: false
scalping: false                               # D1 hold; not scalping
ml_required: false                            # rolling OLS regression + Bollinger band threshold logic; classical statistics, no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (rolling OLS regression + Z-score threshold-crossing is fully deterministic)
- [x] No Machine Learning required (classical statistics; no gradient descent, no fitted-function approximator)
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (D1 timeframe)
- [ ] **Friday Close compatibility:** spread-MR holds may straddle weekends (multi-day average hold); flag `friday_close` at risk (§ 12). Forced flat at Friday 21:00 means re-entry Monday if signal is still active; net effect on backtest TBD at P3.
- [x] Source citation is precise enough to reproduce (chapter + section + Example number + verbatim MATLAB code + verbatim performance quotes)
- [ ] **No near-duplicate of existing approved card** — distinct from SRC02_S01 chan-pairs-stat-arb (which is cadf-cointegration on GLD/GDX, NOT Bollinger-band on GLD/USO; different test, different pair, different exit mechanism: chan-pairs-stat-arb uses mean-reach + half-life-time-stop, this card uses Bollinger-exit-at-mean with no time-stop). DISAMBIGUATION confirmed at extraction.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); optional cointegration self-test filter as sweep axis; optional spread-vol floor as sweep axis."
  trade_entry:
    used: true
    notes: "rolling OLS hedge ratio + Z-score threshold-crossing on D1 close; one signal per direction at a time"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close, no pyramiding; hedge ratio frozen at entry"
  trade_close:
    used: true
    notes: "Z-score returns inside ±EXIT_K band (default ±0σ = mean); no time-stop, no native stop-loss"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # multi-day spread holds straddle weekends; force-flat at Friday 21:00 means re-entry Monday if signal still active
  - dwx_suffix_discipline                     # Chan's universe is US ETFs (GLD, USO, EWA, EWC); V5 deploys on Darwinex .DWX symbols. Candidate map: GOLD.DWX / OIL.DWX. CTO confirms tick-size + spread profile at G0; CSR (P3.5) tests on alternative Darwinex-native pairs.
  - kill_switch_coverage                      # no native stop-loss (Chan's anti-stop-loss disposition Ch 6 p. 153). Catastrophic backstop relies entirely on V5's QM_KillSwitch and account-level MAX_DD trip. CTO sanity-checks at P5.
  - enhancement_doctrine                      # entry/exit thresholds (entry_k=1, exit_k=0) and lookback=20 are Chan-stated-with-hindsight; any post-PASS retune counts as enhancement_doctrine event.

at_risk_explanation: |
  friday_close — D1 pair-MR with ±1σ entry and 0σ exit produces multi-day average holds (Chan
  doesn't publish hold-time stats but the 17.8% APR / Sharpe 0.96 with ~50 trades/year implies
  ~5-10 day average holds). Forced flat at Friday 21:00 truncates a fraction of those holds.
  Net backtest impact TBD at P3; the strategy survives Friday-close in concept (re-enter Monday
  if signal still active) but P&L impact requires testing.

  dwx_suffix_discipline — GLD/USO maps to GOLD.DWX/OIL.DWX (or to non-DWX equivalents if those
  CFDs are not available on the V5 Darwinex universe — CTO confirms at G0). The strategy
  generalizes to any cointegrating Darwinex-native pair per Chan's "any cointegrating pair"
  framing; CSR P3.5 tests this.

  kill_switch_coverage — no native stop-loss. V5 account-level kill-switch is the catastrophic
  backstop. CTO sanity-checks at P5 that kill-switch sizing covers the worst-case "spread blows
  out and never reverts" scenario (which is the canonical mean-reversion ruin mode — see SRC02
  chan-pairs-stat-arb's GDX-GLD 2008 fundamental-divergence anecdote).

  enhancement_doctrine — Chan: "set to near-optimal 20 trading days with the benefit of
  hindsight" (p. 67). The lookback was tuned in-sample; entry_k=1 / exit_k=0 are also reported
  with hindsight. Any P3 sweep result is the strategy's first proper out-of-sample tuning;
  any post-PASS retune is an enhancement_doctrine event.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default; optional cointegration filter + spread-vol floor as sweep axes
  entry: TBD                                  # rolling 20-day OLS hedge regression + Z-score on resulting spread; threshold cross at ±1σ. ~80-150 LOC in MQL5 (regression library may be needed; Darwinex Connector or QM helper).
  management: TBD                             # n/a (no trailing / BE / partial); hedge ratio frozen at entry
  close: TBD                                  # Z-score returns inside ±0σ (mean) — natural reversion
estimated_complexity: medium                  # OLS regression + spread synthesis + Z-score is more involved than a single-symbol strategy; ~100-200 LOC
estimated_test_runtime: 2-4h                  # P3 sweep (5×5×4×3×3×4 = 3,600 cells) over 5+ years of D1 data per pair
data_requirements: standard                   # D1 OHLC on two .DWX symbols simultaneously (synchronization important — Chan p. 51-52 warns about asynchronous quote pitfalls)
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
- 2026-04-28: SRC05_S01 is the FIRST V5 Strategy Card capturing Bollinger-band MR on a
  REGRESSION-HEDGED PAIR SPREAD (rather than on a single-leg own-statistics band, which is
  SRC02 chan-bollinger-es). Reuses existing flags `cointegration-pair-trade` (entry mechanism
  via spread, even though Chan acknowledges GLD-USO are not strictly cointegrating — the
  *construction* is the same as cadf/Johansen pair-trades) + `zscore-band-reversion` + new
  `mean-reach-exit` (already V5-vocab post-SRC02 ratification). NO new vocab gap surfaced —
  SRC05 S01 is fully covered by existing ratified V5 flags. Disambiguation from SRC02
  chan-pairs-stat-arb confirmed: SRC02_S01 uses cadf cointegration test on GLD/GDX
  (geological-mining-economic story), this card uses rolling OLS regression on GLD/USO
  (oil/gold cross-correlation, NOT cointegration per Chan p. 67). Different pair, different
  test, different exit (chan-pairs-stat-arb uses mean-reach + half-life time-stop; this card
  uses Bollinger 0σ exit with no time-stop).

- 2026-04-28: Chan explicitly positions Ex 3.2 as the PRACTICAL VERSION of the linear
  mean-reverting strategies of Examples 2.5 and 2.8 (which Chan disqualified as not-practical).
  The Bollinger-band wrapper bounds capital deployment + produces deterministic entry/exit
  schedule, addressing the linear strategy's two main drawbacks (unbounded capital + no fixed
  trigger threshold). This contrasts with the SRC02 chan-bollinger-es card (Chan QT 2009 Ch 2
  pp. 22-23) which Chan presents as a deliberate FAILURE example for the transaction-cost
  effect; chan-at-bb-pair (this card) is presented as a SUCCESS example showing a 17.8% APR /
  0.96 Sharpe pre-cost. Card draftbed per Rule 1; pipeline gates do the filtering.

- 2026-04-28: Chan does NOT specify hedge-ratio retiming policy when a position is open. Per
  his MATLAB code (Ex 3.2 referenced via Ex 3.1 PriceSpread.m), the hedge ratio is recomputed
  every day for signal generation only; the OPEN POSITION uses the entry-time hedge ratio
  (numUnits=±1 set on entry, fillMissingData carries it forward). This card adopts that
  reading. An alternative reading (continuously rebalance the hedge ratio every day per the
  rolling OLS) is the Kalman-filter strategy of S02 chan-at-kf-pair — which IS a separate
  card because the dynamic hedge ratio is the load-bearing feature there. Disambiguation
  documented at extraction.
```
