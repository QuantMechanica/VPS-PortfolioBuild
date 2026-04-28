# Strategy Card — Chan AT SPY-vs-Component-Basket Cointegration Arbitrage (Johansen-selected long-only basket of SPX stocks paired against SPY, fixed lookback=5 linear MR on log market value)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch4_5_pp87-132.txt` lines 1163-1413 (Ex 4.2 verbatim MATLAB across two code blocks + Johansen-test output + 4-year SPX-vs-SPY performance + Chan's commentary on training-set methodology and dynamic-rebalance enhancement).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S04
ea_id: TBD
slug: chan-at-spy-arb
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - cointegration-pair-trade                    # existing — Johansen-derived multi-symbol cointegration where the second "leg" is a 98-stock long-only portfolio cointegrating with SPY (rather than a 2-symbol pair). The card uses the Johansen eigenvector to determine the dollar-capital allocation across {98 stocks, SPY}, treating the long-only stock portfolio as one synthetic leg and SPY as the other. Sibling parameterization of `cointegration-pair-trade` (which existing SRC02 cards use for the GLD-GDX 2-symbol cadf pair) — same architectural mechanic (regress for a stationary spread, trade the spread mean reversion) but with a basket-vs-ETF cardinality.
  - zscore-band-reversion                       # existing — entry/exit on the lookback=5 z-score of the log market value of the long-short portfolio; numUnits = -(logMktVal - movingAvg)/movingStd; positions are continuous (-numUnits proportional to the deviation); position is recomputed every bar (linear MR strategy from Ch 2).
  - signal-reversal-exit                        # existing — daily rebalance recomputes weights every bar; exit fires when numUnits flips sign or amplitude
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 4 'Mean Reversion of Stocks and ETFs', § 'Arbitrage between an ETF and Its Component Stocks' (PDF pp. 96-101 / printed pp. 96-101). Example 4.2 'Arbitrage between SPY and Its Component Stocks' (PDF pp. 98-100 / printed pp. 98-100) is the primary case with full MATLAB code (download = indexArb.m), Johansen-test output (98 stocks cointegrate; long-only basket re-cointegrates with SPY), and 4-year test-set performance."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch4_5_pp87-132.txt` lines 1163-1413 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **multi-symbol cointegration-arbitrage strategy** that constructs a long-only equal-capital basket of SPX-component stocks individually cointegrating with SPY (via Johansen test) on a training set, then trades the linear-MR z-score of the log-market-value of the resulting long-short portfolio (basket vs SPY) using the Johansen eigenvector for hedge-ratio capital allocation. Chan motivates the strategy as a generalization of "index arbitrage" (futures vs basket) where the basket is *deliberately constructed* to be sparse + cointegrating rather than weighted-to-replicate-the-index. From Ch 4 § "Arbitrage between an ETF and Its Component Stocks" (p. 97):

> "All but the most sophisticated traders can profit from this strategy [classic index arb], and it most certainly needs to be traded intraday, perhaps at high frequency. In order to increase this difference, we can select only a subset of the stocks in the index to form the portfolio. The same concept can be applied to the arbitrage between a portfolio of stocks constituting an ETF and the ETF itself. In this case, we choose just a proper subset of the constituent stocks to form the portfolio. One selection method is to just pick all the stocks that cointegrate individually with the ETF. We will demonstrate the method by using the most famous ETF of all: SPY." (p. 97)

The full source procedure (verbatim MATLAB pseudocode from Ex 4.2):

**Step 1 — Per-stock cointegration screen on training set:**
```matlab
trainDataIdx = find(tday >= 20070101 & tday <= 20071231);
testDataIdx  = find(tday > 20071231);

isCoint = false(size(stks.stocks));
for s = 1:length(stks.stocks)
    y2 = [stks.cl(trainDataIdx, s), etf.cl(trainDataIdx)];
    badData = any(isnan(y2), 2);
    y2(badData, :) = [];
    if size(y2, 1) > 250
        results = johansen(y2, 0, 1);  % non-zero offset, zero drift, lag k=1
        if results.lr1(1) > results.cvt(1, 1)  % at 90% confidence
            isCoint(s) = true;
        end
    end
end
% Result: 98 stocks cointegrate
```

**Step 2 — Construct + verify long-only basket:**
```matlab
yN = stks.cl(trainDataIdx, isCoint);
logMktVal_long = sum(log(yN), 2);  % long-only basket log market value
ytest = [logMktVal_long, log(etf.cl(trainDataIdx))];
results = johansen(ytest, 0, 1);  % verify basket-vs-SPY cointegrates
prt(results);
% Output confirms cointegration with > 95% probability.
% Eigenvector (first column): [1.0939, -105.5600] → relative weights.
```

**Step 3 — Apply linear MR on test set:**
```matlab
yNplus  = [stks.cl(testDataIdx, isCoint), etf.cl(testDataIdx)];
weights = [repmat(results.evec(1, 1), size(yN, 2)), ...  % 98 stock weights
           repmat(results.evec(2, 1), size(etf, 1))];     % 1 SPY weight
logMktVal = smartsum(weights .* log(yNplus), 2);  % synthetic spread
lookback  = 5;  % FIXED with hindsight per Chan
numUnits  = -(logMktVal - movingAvg(logMktVal, lookback)) ./ ...
            movingStd(logMktVal, lookback);
positions = repmat(numUnits, [1 size(weights, 2)]) .* weights;
pnl       = smartsum(lag(positions, 1) .* (log(yNplus) - lag(log(yNplus), 1)), 2);
ret       = pnl ./ smartsum(abs(lag(positions, 1)), 2);
```

The strategy runs on **log market values** (not prices) because the Johansen test was performed on log prices, so the eigenvector weights represent dollar capital allocation, not number of shares (per Chan's Ch 3 framing). The basket capital weights are equal across the 98 stocks (`results.evec(1, 1)` repeated), and the SPY weight is the second eigenvector entry (`results.evec(2, 1)`). This produces a long-stocks / short-SPY (or long-SPY / short-stocks) portfolio depending on the sign of `numUnits`.

Chan's commentary on the **training-set / test-set choice + lookback=5 hindsight** (p. 100):

> "We then apply the linear mean reversion strategy on this portfolio over the test period January 2, 2008, to April 9, 2012, much in the same way as Example 2.8, except that in the current program we have fixed the look-back used for calculating the moving average and standard deviations of the portfolio market value to be 5, with the benefit of hindsight." (p. 100)

The "with the benefit of hindsight" is **a candor flag from Chan himself** — V5 P3 / P4 must explicitly out-of-sample-validate the lookback=5 choice. This is also relevant for V5 P5c crisis-slice testing.

Chan's commentary on the **lack of dynamic re-training** (p. 100) and **why direct full-Johansen-on-500 fails** (p. 101):

> "As you can see from the cumulative returns chart (Figure 4.3), the performance decreases as time goes on, partly because we have not retrained the model periodically to select new constituent stocks with new hedge ratios. In a more complete backtest, we can add this dynamic updating of the hedge ratios. The same methodology can, of course, be applied to any ETFs, indices, or subindices you like. Furthermore, we can use a future instead of an ETF if such a future exists that tracks that index or subindex, although in this case one has to be careful that the prices of the future used in backtest are contemporaneous with the closing prices for the stocks." (p. 100)

> "You may wonder why we didn't just directly run a Johansen cointegration test on all 500 stocks in SPX plus SPY ... 1. The Johansen test implementation that I know of can accept a maximum of 12 symbols only. 2. The eigenvectors will usually involve both long and short stock positions. This means that we can't have a long-only portfolio of stocks that is hedged with a short SPY position or vice versa." (p. 101)

The 98-stock-count is then a *training-set-specific number* — it changes with re-training; the strategy as Chan presents it is a 4-year out-of-sample run on a fixed 2007-trained basket without re-training (which Chan acknowledges is suboptimal).

## 3. Markets & Timeframes

```yaml
markets:
  - stocks                                      # 98-stock cointegrating subset of SPX (training-set-determined; varies with re-training period) + SPY ETF
  - etf                                         # SPY (the index ETF leg of the spread)
  # V5 Darwinex re-mapping: V5-architecture-CHALLENGED at higher level than S03 — this card requires (a) a multi-stock-CFD universe (Darwinex-current-universe limitation), (b) Johansen-test infrastructure inside V5, and (c) per-name dollar-capital allocation across 99 instruments. Substitute paths: (i) US500.DWX vs sector-ETF-basket (XLK.DWX, XLF.DWX, XLE.DWX, etc.) on smaller N; (ii) defer until V5 portfolio-of-N-symbols framework lands; (iii) replicate Chan's procedure on Darwinex-native instruments only (e.g., GBPUSD vs an FX-basket, or US500.DWX vs sector-ETFs).
timeframes:
  - D1                                          # daily-bar log-prices; signals + rebalance once-per-bar
session_window: end-of-day                      # signals at close, rebalance at next close; Chan's source pnl uses log-price-difference accounting
primary_target_symbols:
  - "SPX universe (~500 stocks, training-set-cointegrating subset = 98 names per Chan's 2007 training period) + SPY ETF (Chan's source case)"
  - "V5 Darwinex mapping: V5-architecture-CHALLENGED. Candidate paths: (a) full Darwinex single-name CFD universe + index CFD if/when expanded; (b) sector-ETF universe vs broad-market-CFD on smaller N (XLK/XLF/XLE/XLV.DWX vs US500.DWX, with Johansen test on 5-10 sector-ETFs); (c) defer to V5 portfolio-of-N-symbols framework."
```

## 4. Entry Rules

Two-phase strategy: a **training phase** (run periodically per re-training cadence) and a **per-bar trading phase** (run continuously on test data).

**Training phase** (run on N_train daily bars, re-run periodically):

```text
- on training-window bars (Chan: 1 calendar year, ~252 bars):
    for each stock s in universe:
        run Johansen test with offset=non-zero, drift=zero, lag k=1 on (s, ETF) log-prices
        if results.lr1(1) > results.cvt(1, 1):  # 90% confidence trace statistic
            mark s as cointegrating with ETF
- form long-only basket = all marked stocks (equal capital weight = 1/N_marked)
- compute logMktVal_long = sum(log(stock_prices)) across basket
- run Johansen test on (logMktVal_long, log(ETF_price)) → confirm cointegration
- store eigenvector (first column) = [w_basket, w_etf] for capital-allocation
  (Chan's training case: w_basket = +1.0939, w_etf = -105.56 → long basket / short SPY at sign=positive numUnits)
```

**Per-bar trading phase** (run on each daily-bar close):

```text
- compute logMktVal_t = w_basket · sum(log(stock_prices_t)) + w_etf · log(ETF_price_t)
- compute ma_t  = simple_moving_average(logMktVal, lookback=5, lagged 0 bars)
  (Note: Chan does NOT lag ma/std in source code — entry is on the same bar's logMktVal; this is a P1 build-validation point)
- compute std_t = simple_moving_stdev(logMktVal, lookback=5, lagged 0 bars)
- compute numUnits = -(logMktVal_t - ma_t) / std_t
- positions_per_instrument_i = numUnits · w_i  (i ∈ {basket_stocks, ETF})
  (per-stock dollar capital = numUnits · w_basket; per-ETF dollar capital = numUnits · w_etf)
- pnl_per_bar = sum(positions_lagged_1_bar · (log_price_t - log_price_{t-1}))
- ret_per_bar = pnl_per_bar / sum(abs(positions_lagged_1_bar))
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

The strategy is continuous-positioning (no discrete entry/exit threshold; numUnits adjusts proportionally to z-score deviation), which is the linear-MR pattern from Chan Ch 2 § "Linear Mean-Reverting Strategies" (cited in Ex 4.2 Continued, p. 100).

## 5. Exit Rules

```text
- continuous-positioning: numUnits is recomputed every bar; the position is the proportional-to-deviation linear-MR pattern. There is no discrete TP/SL exit — the position naturally unwinds as logMktVal returns to its 5-bar moving average.
- "exit signal" = numUnits crosses zero (logMktVal touches the 5-bar MA), at which point positions flip to zero or the opposite sign.
- no SL or TP referenced in the source; pure linear-MR exposure.
- no trailing stop in source rule.
- Friday Close enforced (default per V5 framework — daily MR portfolio with overnight + weekend hold; flag friday_close at risk for the equity-leg / SPY-ETF wrapper)
- explicit MQL5 V5 mapping: optional `QM_StopRules.QM_StopAbsolute(stop_loss = N · logMktVal_stdev_disaster_threshold)` per-leg disaster stop; documented as enhancement-doctrine candidate, not in source rule.
```

## 6. Filters (No-Trade module)

```text
- isCoint screen: a stock is NOT in the basket unless it passed the per-stock Johansen test on the training set (90% confidence, trace statistic > critical value)
- size(y2, 1) > 250 — minimum data requirement per stock (250 days = 1 year of daily training data)
- isfinite(numUnits) — implicit; stocks with missing data on a bar drop out via smartsum semantics
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — periodic re-training cadence (e.g., quarterly or annual re-Johansen-test): Chan p. 100 acknowledges static training is a weakness causing degradation post-2009; V5 P3/P4 should validate re-training cadence as a sweep dimension.
- (V5 enhancement candidate, NOT in source rule) — basket-size cap: 98-stock portfolio is unwieldy for V5 magic-schema; substitute paths (sector-ETF basket of N=5-10) limit basket size at training time.
```

## 7. Trade Management Rules

```text
- continuous-rebalance: positions recomputed every bar; per-instrument dollar capital scales with numUnits and per-instrument weight w_i
- pyramiding: NOT allowed (default V5; positions are scaled deterministically by numUnits, not added incrementally)
- gridding: NOT allowed (default V5)
- no break-even-move (linear-MR continuous exposure; no discrete entry to anchor a BE move)
- no partial close (continuous exposure)
- 99 simultaneous instruments active at any bar (98 stocks + SPY); per-magic-symbol slot allocation needed (V5-architecture-CHALLENGED — same status as SRC02 chan-pca-factor)
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback_z
  default: 5
  sweep_range: [3, 5, 10, 20, 60, 120]
  notes: "Chan p. 100 explicitly says lookback=5 was 'fixed with the benefit of hindsight'. P3 sweep MUST validate this on out-of-sample basis. Range covers daily / weekly / monthly / quarterly z-score windows."
- name: training_window
  default: "1 year (~252 bars), Chan default"
  sweep_range: ["6 months", "1 year", "2 years", "3 years"]
  notes: "Chan uses 1 year (Jan-Dec 2007). Larger training windows reduce noise but trade off responsiveness to regime shifts. P4 walk-forward validates this."
- name: johansen_confidence
  default: "90% (trace statistic > cvt(1,1))"
  sweep_range: ["90%", "95%", "99%"]
  notes: "Chan uses the 90%-confidence trace statistic (results.lr1(1) > results.cvt(1, 1)). Higher confidence = stricter filter = smaller basket (fewer cointegrating stocks pass)."
- name: retraining_cadence
  default: "static (Chan's source: trained once on 2007, traded 2008-2012 unchanged)"
  sweep_range: ["static", "annual", "semi-annual", "quarterly", "monthly"]
  notes: "Chan p. 100 acknowledges static training is a weakness causing degradation post-2009. P4 walk-forward should sweep retraining cadence as a primary dimension."
- name: basket_size_cap
  default: "no cap (98 stocks per Chan's 2007-training case)"
  sweep_range: ["no cap", "top-30", "top-10", "top-5"]
  notes: "V5-architecture-pragmatism: 98-stock portfolios are infeasible at the V5 magic-schema level without portfolio-of-N-symbols framework. Smaller basket caps may degrade edge but make V5 deployment tractable."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: universe_substitution
  default: "SPX (~500) + SPY"
  sweep_range: ["SPX (Chan source)", "Sector-ETF basket vs US500.DWX (5-10 ETFs)", "FX-basket vs FX-index", "Custom Darwinex-native universe TBD"]
  notes: "V5-architecture-CHALLENGED (multi-stock universe + Johansen infrastructure). Initial baseline likely runs on a sector-ETF subset until full universe lands. CTO confirms at G0."
- name: hedge_pair_swap
  default: "SPY (the ETF leg)"
  sweep_range: ["SPY", "SPX index future", "US500.DWX index CFD"]
  notes: "Chan p. 100 mentions the strategy generalizes to using a future instead of an ETF; the price-contemporaneity caveat applies."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"Based on the Johansen test between each stock in SPX with SPY over the training set, we find that there are 98 stocks that cointegrate (each separately) with SPY." (p. 99)

"The Johansen test indicates that the long-only portfolio does cointegrate with SPY with better than 95 percent probability." (p. 99)

"The APR of this strategy is 4.5 percent, and the Sharpe ratio is 1.3." (p. 100)

"As you can see from the cumulative returns chart (Figure 4.3), the performance decreases as time goes on, partly because we have not retrained the model periodically to select new constituent stocks with new hedge ratios. In a more complete backtest, we can add this dynamic updating of the hedge ratios." (p. 100)

"the current program we have fixed the look-back used for calculating the moving average and standard deviations of the portfolio market value to be 5, with the benefit of hindsight." (p. 100)

"You may wonder why we didn't just directly run a Johansen cointegration test on all 500 stocks in SPX plus SPY ... [Two reasons:] 1. The Johansen test implementation that I know of can accept a maximum of 12 symbols only (LeSage, 1998). 2. The eigenvectors will usually involve both long and short stock positions. This means that we can't have a long-only portfolio of stocks that is hedged with a short SPY position or vice versa." (p. 101)

"This strategy suffers from the same short-sale constraint that plagued any strategies involving short stock positions. However, the problem is not too serious here because the stock portfolio is quite diversified with about 98 stocks. If a few stocks have to be removed due to the short-sale constraint, the impact should be limited." (p. 102)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # Sharpe 1.3 → rough PF ≈ 1.3-1.5 for daily linear-MR multi-stock cointegration
expected_dd_pct: 15                           # rough estimate from 4-year Sharpe-1.3 daily MR with cited time-decay + 2008-09-crisis exposure (Chan p. 100 acknowledges performance decreases post-2009)
expected_trade_frequency: 252/year_of_rebalancing  # continuous rebalance daily; ~252 portfolio adjustments per year
risk_class: medium                            # multi-stock cointegration MR; not scalping; long-only basket + short ETF (or reverse)
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — full Johansen-test + linear-MR rule, fully discretionary-judgment-free
- [x] No Machine Learning required — Johansen test is closed-form linear algebra (eigendecomposition), not ML training
- [ ] Friday Close compatibility — multi-stock MR portfolio with overnight + weekend hold; the SPY-ETF leg has Friday-close enforcement risk (CTO confirms at G0; flag friday_close at risk)
- [x] Source citation precise — Chan AT (2013), Ch 4 Ex 4.2, PDF pp. 98-100
- [ ] No near-duplicate of existing approved card — **NEAR-DUPLICATE-CHECK**: SRC02 `chan-pairs-stat-arb` (SRC02_S01) is a 2-symbol cadf cointegration pair (GLD-GDX); S04 is a basket-vs-ETF (98-stock-basket vs SPY) with Johansen rather than cadf. Different cardinality + different cointegration test → DISTINCT card. Disambiguation also vs S05 chan-at-fx-coint-pair (currency pair via Johansen) — same Johansen mechanic but different asset class + different cardinality. DISTINCT confirmed.
- [x] No gridding, no scalping, no ML
- [x] V5-architecture-CHALLENGED status acknowledged — multi-stock + Johansen-infrastructure; pipeline G0 review may defer P1 build until V5 cross-sectional framework lands

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) plus the strategy-internal training-set Johansen-cointegration-screen as a constituent-selection filter at training time, not per-bar"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: continuous-positioning linear-MR; per-bar compute numUnits = -(logMktVal - 5d_MA) / 5d_std; per-instrument capital = numUnits · w_i where w_i is the Johansen eigenvector entry for instrument i"
  trade_management:
    used: true
    notes: "continuous rebalance every bar; positions scaled by numUnits; no per-bar discretionary management beyond the linear-MR formula"
  trade_close:
    used: false
    notes: "no discrete close signal; position naturally unwinds as numUnits crosses zero (logMktVal returns to its 5d MA)"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Chan source instruments are SPX-component stocks (~500 US stocks) + SPY ETF; V5 deployment requires Darwinex single-name CFD universe (currently limited) or substitute (sector-ETF universe / FX-basket-vs-FX-index). Cross-sectional architecture is V5-default-incompatible at the magic_schema level.
  - magic_schema                              # multi-instrument N-symbol architecture (98 stocks + 1 ETF = 99 simultaneous instruments per bar) conflicts with V5 default ea_id*10000+symbol_slot — same architectural-pending status as SRC02 chan-pca-factor / chan-khandani-lo-mr / chan-january-effect / chan-yoy-same-month + S03 chan-at-buy-on-gap.
  - one_position_per_magic_symbol             # 99 simultaneous positions across 99 distinct symbol-magic-slots; per-symbol single-position is compliant, but architecture-level requires per-strategy-magic-prefix extension
  - friday_close                              # multi-stock cointegration MR portfolio with continuous-rebalance daily; positions held over Fri 21:00 broker time (and weekend hold). Strategy survives if framework-default Friday-Close is allowed, OR documented exception is approved (linear-MR continuous-rebalance is a known exception class for cointegration-pair-trade siblings). CTO confirms at G0.
at_risk_explanation: |
  dwx_suffix_discipline + magic_schema + one_position_per_magic_symbol: SPX-universe + SPY → Darwinex
  spot-CFD universe is a non-trivial substitution (same as S03). Substitute paths: (a) sector-ETF
  universe (XLK.DWX, XLF.DWX, etc., ~5-10 names) vs US500.DWX (CFD); (b) FX-basket vs DXY-CFD; (c)
  defer to V5 portfolio-of-N-symbols framework. CTO selects path at G0.

  friday_close: continuous-rebalance daily MR portfolio with overnight + weekend hold. Strategy
  survives if Friday-Close-default is suspended via documented exception OR if positions are
  forcibly flat on Fri 21:00 (which interrupts the linear-MR continuous-rebalance and defeats the
  edge). Standard exception class for `cointegration-pair-trade` siblings. CTO confirms at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # training-time Johansen-screen at strategy-init
  entry: TBD                                  # cross-sectional linear-MR; per-bar logMktVal computation across 99 instruments; numUnits formula; per-instrument capital allocation
  management: TBD                             # continuous-rebalance positions
  close: TBD                                  # no discrete close
estimated_complexity: large                   # multi-instrument architecture + Johansen-test infrastructure + continuous-rebalance per-bar = highest of any SRC05 card so far
estimated_test_runtime: TBD                   # large — Johansen-test screen alone is O(N_stocks · N_train_bars · cubic_eigendecomp); per-bar trading is O(N_basket · N_test_bars)
data_requirements: standard                   # SPX-style daily close × N stocks + SPY; Darwinex-native equivalents; basket constituents change with re-training cadence
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build (h4 SRC05 batch) | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT | this card |
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
- 2026-04-28: VOCAB extension — `cointegration-pair-trade` flag is reused with a basket-vs-ETF cardinality. The existing flag's V4 examples are 2-symbol cadf pairs; this card extends to N+1-symbol Johansen baskets. Pattern: same architectural mechanic (regress for stationary spread, trade z-score MR), different cardinality. NO new flag proposed for SRC05 closeout from this card; if subsequent SRCs introduce a different flavor (e.g., factor-tilt-cointegration), Research will revisit.
- 2026-04-28: Chan's p. 100 candor about lookback=5 being chosen "with the benefit of hindsight" is a standout example of in-source-disclosed look-ahead-bias. V5 P3 P4 walk-forward MUST out-of-sample-validate this parameter. This card will likely fail naive in-sample evaluation if lookback=5 is treated as load-bearing without out-of-sample re-fitting.
- 2026-04-28: Chan's p. 100 acknowledgment of "performance decreases as time goes on, partly because we have not retrained the model periodically" is an explicit invitation to enhance via dynamic re-training. V5 P4 walk-forward should sweep retraining_cadence as a primary dimension.
- 2026-04-28: V5-architecture-CHALLENGED status (multi-stock + Johansen-infrastructure) is the highest of any SRC05 card. Pipeline G0 review may defer P1 build until V5 cross-sectional framework lands. If V5 builds a generalized portfolio-of-N-symbols runtime (V5 magic_schema extension), this card and S03/S10/S11/SRC02_chan-khandani-lo-mr/SRC02_chan-pca-factor all become tractable simultaneously.
- 2026-04-28: Chan's p. 101 "12-symbol Johansen-test implementation limit" is a software-engineering caveat that V5 may not inherit (modern numerical libraries support arbitrarily large eigendecompositions); CTO confirms at G0 whether V5 has a Johansen-test implementation and what its symbol-count limits are.
```
