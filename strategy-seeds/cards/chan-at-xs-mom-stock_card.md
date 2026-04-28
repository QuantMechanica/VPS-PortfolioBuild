# Strategy Card — Chan AT Cross-Sectional Momentum on S&P 500 Stocks (Daniel-Moskowitz, 252-day-lookback rank long top-50 / short bottom-50, 25-day overlapping holds)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 1148-1226 (Ex 6.2 verbatim MATLAB + 2007 / 2008-09 multi-period performance + Chan's commentary on factor extensibility).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S11
ea_id: TBD
slug: chan-at-xs-mom-stock
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - cross-sectional-momentum                    # NEW VOCAB GAP — same flag introduced by S10 chan-at-xs-mom-fut. Here parameterized for stock universe (lookback=252, holddays=25, topN=50). Sibling of existing `cross-sectional-decile-sort` (MR direction); `cross-sectional-momentum` is OPPOSITE direction (buy winners, sell losers). Distinct from `time-series-momentum` (S07; single-instrument; not cross-sectional).
  - signal-reversal-exit                        # exit mechanism: position rolled every 25 days when ranking displaces names; daily 1/holddays overlap-rebalance
  - symmetric-long-short                        # long top-50 + short bottom-50; dollar-neutral by construction
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 6 'Interday Momentum Strategies', § 'Cross-Sectional Strategies' (PDF pp. 145-148 / printed pp. 145-148). Example 6.2 'Cross-Sectional Momentum Strategy for Stocks' (PDF pp. 146-147 / printed pp. 146-147) is the primary case with full MATLAB code (download = kentdaniel.m), 2007 performance, and 2008-2009 crisis-period failure."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Daniel, Kent, and Tobias Moskowitz. (2011). Momentum Crashes. NBER Working Paper / Columbia Business School Working Paper."
    location: "cited by Chan p. 147 as the source paper for the cross-sectional stock momentum strategy; also reports a longer-window 1947-2007 16.7%-APR / 0.83-Sharpe figure"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 1148-1226 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **cross-sectional stock-momentum strategy** that ranks the S&P 500 by 252-day lagged return, longs the top decile (top 50) and shorts the bottom decile (bottom 50), holds 25 days with daily 1/holddays overlap-rebalancing. The strategy is the **stock-universe sibling** of S10 chan-at-xs-mom-fut (cross-sectional commodity futures momentum, same mechanic). Chan's causal explanation differs by asset class — for stocks, the source isn't roll-return persistence (which only applies to futures) but rather **slow diffusion of news** (Chan p. 146):

> "Obviously, cross-sectional momentum in currencies and stocks can no longer be explained by the persistence of the sign of roll returns. We might attribute that to the serial correlation in world economic or interest rate growth in the currency case, and the slow diffusion, analysis, and acceptance of new information in the stock case." (p. 146)

Chan's introduction to the stock variant (p. 146):

> "Applying this strategy to U.S. stocks, we can buy and hold stocks within the top decile of 12-month lagged returns for a month, and vice versa for the bottom decile. I illustrate the strategy in Example 6.2." (p. 146)

The full source rule, **verbatim** from Ex 6.2 MATLAB (p. 146-147):

```matlab
lookback=252;
holddays=25;
topN=50;

ret = (cl - backshift(lookback, cl)) ./ backshift(lookback, cl);
% daily returns over 252-day lookback per stock

longs = false(size(ret));
shorts = false(size(ret));
positions = zeros(size(ret));

for t = lookback+1 : length(tday)
    [foo idx] = sort(ret(t, :), 'ascend');
    nodata = find(isnan(ret(t, :)));
    idx = setdiff(idx, nodata, 'stable');
    longs(t,  idx(end-topN+1:end)) = true;  % top-50 winners
    shorts(t, idx(1:topN))         = true;  % bottom-50 losers
end

for h = 0:holddays-1
    long_lag = backshift(h, longs);
    long_lag(isnan(long_lag)) = false;
    long_lag = logical(long_lag);

    short_lag = backshift(h, shorts);
    short_lag(isnan(short_lag)) = false;
    short_lag = logical(short_lag);

    positions(long_lag)  = positions(long_lag)  + 1;
    positions(short_lag) = positions(short_lag) - 1;
end

dailyret = smartsum(backshift(1, positions) .* (cl - lag(cl)) ./ lag(cl), 2) ...
           / (2 * topN) / holddays;
dailyret(isnan(dailyret)) = 0;
```

The mechanic is therefore:

1. Universe = S&P 500 stocks
2. Per bar: compute 252-day lagged return per stock, exclude NaNs, sort ascending
3. Mark top-50 (highest 252-day return) as longs; bottom-50 as shorts on bar t
4. Overlap-rebalance: positions(t,:) is the SUM of long/short signals from bars t-25 to t (overlapping 25-day holds)
5. PnL: positions_lagged_1_bar · daily_return / (2·topN·holddays) — capital-normalized

The overlapping-hold mechanic is **identical** to S07 chan-at-ts-mom-fut and the (non-explicit-MATLAB) S10 chan-at-xs-mom-fut. This is the only Chan-AT card with explicit verbatim MATLAB for the cross-sectional momentum mechanic — S10's MATLAB is implicit by inheritance from this card.

Chan's commentary on **2007 performance and 2008-09 crisis failure** (p. 147):

> "The APR from May 15, 2007, to December 31, 2007, is 37 percent with a Sharpe ratio of 4.1. The cumulative returns are shown in Figure 6.6. (Daniel and Moskowitz found an annualized average return of 16.7 percent and a Sharpe ratio of 0.83 from 1947 to 2007.) However, the APR from January 2, 2008, to December 31, 2009, is a miserable −30 percent. The financial crisis of 2008-2009 also ruined this momentum strategy. The return after 2009 did stabilize, though it hasn't returned to its former high level yet." (p. 147)

The 2007 short-window 37%/4.1 is **suspicious from a sample-size standpoint** (~7 months of data, post-crash recovery period); the Daniel-Moskowitz 1947-2007 16.7%/0.83 long-window figure is more credible as a long-term expected baseline. V5 P3 / P4 walk-forward must use a multi-decade test window if available, not the 2007-only Chan slice.

Chan's commentary on **factor-extensibility** (p. 147-148):

> "Just as in the case of the cross-sectional mean reversion strategy discussed in Chapter 4, instead of ranking stocks by their lagged returns, we can rank them by many other variables, or 'factors,' as they are usually called. While we wrote total return = spot return + roll return for futures, we can write total return = market return + factor returns for stocks. A cross-sectional portfolio of stocks, whether mean reverting or momentum based, will eliminate the market return component, and its returns will be driven solely by the factors. These factors may be fundamental, such as earnings growth or book-to-price ratio, or some linear combination thereof. Or they may be statistical factors that are derived from, for example, Principal Component Analysis (PCA) as described in Quantitative Trading (Chan, 2009)." (p. 147)

This is the bridge to **SRC02 chan-pca-factor** (PCA-rank cross-sectional MR) — Chan explicitly notes the PCA-factor variant is in his prior book. The factor-extension is NOT a separate card here (the lagged-return ranking variant is the source case); CEO can flag if a factor-tilted variant should be a future SRC.

## 3. Markets & Timeframes

```yaml
markets:
  - stocks                                      # S&P 500 universe (~500 stocks); presumably with same survivorship-bias caveat as S03 (Chan does NOT explicitly reflag survivorship for Ex 6.2, but the universe is the same)
  # V5 Darwinex re-mapping: V5-architecture-CHALLENGED. Substitute paths: (a) full Darwinex single-name CFD universe if/when expanded; (b) sector-ETF cross-section (XLK/XLF/XLE/XLV/XLP/XLY/XLI/XLU.DWX vs each other, ~10 names); (c) world-index-cross-sectional (US500.DWX, GER40.DWX, UK100.DWX, NIKKEI.DWX, AUS200.DWX, ~10 indices); (d) defer to V5 portfolio-of-N-symbols framework.
timeframes:
  - D1                                          # daily-bar 252-day lagged return; daily 1/holddays overlap-rebalance
session_window: end-of-day                      # signals at close, rebalance at next close
primary_target_symbols:
  - "S&P 500 universe (Chan source case): all SPX stocks; daily close prices; T × N close-price matrix"
  - "V5 Darwinex mapping: TBD — V5-architecture-CHALLENGED. Candidate paths: (a) sector-ETF cross-section (~10 ETFs); (b) world-index-cross-section (~10 indices); (c) defer to V5 portfolio-of-N-symbols framework."
```

## 4. Entry Rules

```text
- on each new daily bar t, for EACH stock s in the universe:
    let ret_252d_s = (close[s, t] - close[s, t-252]) / close[s, t-252]   # 252-day lagged return
- after iterating all symbols on bar t:
    sort ret_252d_s ASCENDING; exclude NaN entries
    mark top-50 (highest 252-day return) as longs[t]
    mark bottom-50 (lowest 252-day return) as shorts[t]
- overlap-rebalance: for h = 0..holddays-1:
    add longs[t-h] to positions[t]
    subtract shorts[t-h] from positions[t]
  This means positions[t] is the SUM of all overlapping 25-day holds; a stock can be in positions[t] with a value > 1 (if it was a long-mark on multiple of the past 25 bars) or < -1 (similarly for shorts) or 0 (no signal in past 25 bars).
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

## 5. Exit Rules

```text
- per-slot time-stop = HOLD_DAYS=25 days from slot-entry
- on bar t+25 from entry: slot-position closes (the long/short mark from bar t falls out of the overlap-sum on bar t+25)
- daily overlap-rebalance: at any given bar, M=25 slot-positions are active per direction
- pnl per bar = sum_over_stocks(positions[t-1] · daily_return[t]) / (2 · topN · holddays)  [capital-normalized]
- no SL or TP referenced in the source; pure rolling-rank reversion exit
- no trailing stop in source rule
- Friday Close enforced (default per V5 framework — multi-stock with continuous holds; flag friday_close at risk)
- explicit MQL5 V5 mapping: `QM_TM_TimeStop(N=25*24*60 minutes for D1 bars)` per-slot
```

## 6. Filters (No-Trade module)

```text
- isfinite(ret_252d_s) — exclude stocks with NaN 252-day-prior data (the source MATLAB explicitly does setdiff(idx, nodata, 'stable'))
- universe-size requirement: at least 2·topN = 100 stocks with finite ret_252d to rank — otherwise the long-50 + short-50 selection is impossible
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — momentum-crash filter: 2008-09 -30% APR is a known crash-failure regime. V5 P5c crisis-slice MUST include 2008-09. Optional: VIX > N or 252d-realized-vol > N gate as proposed enhancement; not in Chan's rule.
- (V5 enhancement candidate, NOT in source rule) — survivorship-bias correction: the SPX universe Chan uses is presumably the same as Ex 4.1 (S03), where Chan p. 94 noted "but one that has survivorship bias". V5 P5/P5c stress should include a survivorship-corrected re-test.
- (V5 enhancement candidate, NOT in source rule) — short-sale-constraint correction: similar to S03 / S04, a non-trivial fraction of SPX stocks may be hard-to-borrow during crisis periods, distorting backtest results.
```

## 7. Trade Management Rules

```text
- M=25 simultaneous long-slot positions per name (each name can be in 0-25 overlapping slots) + same for shorts
- positions[t] aggregates the overlap-sum; per-name capital scales with the position-magnitude (a name flagged in 5 of last 25 bars carries 5/25 = 1/5 of the per-side capital)
- capital normalization: pnl divided by (2 · topN · holddays) — gross book ≈ N · holddays / topN-ratio of 2·topN (long + short)
- pyramiding: NOT allowed (default V5; the per-slot positions are deterministically scaled by the rolling overlap-mark, not added incrementally)
- gridding: NOT allowed (default V5)
- no break-even-move (continuous overlap-holding, time-stop only)
- no partial close (slot positions are entered + exited at opposite ends of the 25-day time-stop)
- per-slot magic_schema requires multi-slot extension of V5 default ea_id*10000+symbol_slot — same V5-architecture-CHALLENGED status as S03/S04/S10
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback
  default: 252
  sweep_range: [60, 120, 180, 252, 504]
  notes: "Chan p. 146 / Daniel-Moskowitz original = 252 (12 months). Same parameter as S10."
- name: holddays
  default: 25
  sweep_range: [10, 25, 60, 120]
  notes: "Chan p. 146 / Daniel-Moskowitz original = 25 (1 month). Same parameter as S10."
- name: topN
  default: 50
  sweep_range: [10, 25, 50, 100, 250]
  notes: "Chan's source case = 50 (top decile of SPX-500). Smaller topN concentrates signal but increases idiosyncratic risk; larger topN dilutes."
- name: direction_mode
  default: "symmetric-long-short"
  sweep_range: ["symmetric-long-short", "long-only", "short-only"]
  notes: "Chan presents the dollar-neutral long-short variant. Long-only / short-only as CTO-discretion variants at G0."
- name: ranking_metric
  default: "252-day-lagged-return"
  sweep_range: ["252-day-lagged-return", "factor-exposure (book-to-price, earnings-growth)", "PCA-rank-decile"]
  notes: "Chan p. 147 explicitly mentions factor-tilted variants and references his prior book (SRC02) for the PCA-rank variant. Sweep is heavily V5-architecture-pending — factor-data feed is a non-Darwinex-native data dependency. PCA-rank is already an SRC02 card (chan-pca-factor)."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: universe_substitution
  default: "S&P 500 (~500 stocks)"
  sweep_range: ["SPX (Chan source)", "Sector-ETF cross-section ~10", "World-index-cross-section ~10", "Custom Darwinex-native universe TBD"]
  notes: "V5-architecture-CHALLENGED. Smaller cross-sections may degrade ranking-edge dispersion. Same status as S03/S04/S10."
- name: weighting_scheme
  default: "top-50 / bottom-50 (decile)"
  sweep_range: ["top-50/bottom-50", "rank-weighted (linear in rank)", "z-score-weighted"]
  notes: "Chan source = decile sort (top-50 / bottom-50 of 500). Rank-weighted is a smoother variant."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"The APR from May 15, 2007, to December 31, 2007, is 37 percent with a Sharpe ratio of 4.1. The cumulative returns are shown in Figure 6.6. (Daniel and Moskowitz found an annualized average return of 16.7 percent and a Sharpe ratio of 0.83 from 1947 to 2007.) However, the APR from January 2, 2008, to December 31, 2009, is a miserable −30 percent. The financial crisis of 2008-2009 also ruined this momentum strategy. The return after 2009 did stabilize, though it hasn't returned to its former high level yet." (p. 147)

"Applying this strategy to U.S. stocks, we can buy and hold stocks within the top decile of 12-month lagged returns for a month, and vice versa for the bottom decile." (p. 146)

"Just as in the case of the cross-sectional mean reversion strategy discussed in Chapter 4, instead of ranking stocks by their lagged returns, we can rank them by many other variables, or 'factors,' as they are usually called. ... A cross-sectional portfolio of stocks, whether mean reverting or momentum based, will eliminate the market return component, and its returns will be driven solely by the factors. These factors may be fundamental, such as earnings growth or book-to-price ratio, or some linear combination thereof. Or they may be statistical factors that are derived from, for example, Principal Component Analysis (PCA) as described in Quantitative Trading (Chan, 2009)." (p. 147)

"All these factors with the possible exception of PCA tend to change slowly, so using them to rank stocks will result in as long holding periods as the cross-sectional models I discussed in this section." (p. 148)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Daniel-Moskowitz long-window Sharpe 0.83 → rough PF ≈ 1.2-1.4; Chan's short-window 2007-only Sh 4.1 is unrepresentative
expected_dd_pct: 35                           # 2008-09 -30% APR over 2 years = ~30-35% MaxDD; analogous to S10 momentum-crash regime
expected_trade_frequency: 252_rebalances/year_per_slot  # daily overlap-rebalance; 25 slots per direction × ~10 rotations/year = ~250 trades per slot per year
risk_class: medium                            # cross-sectional stock momentum; not scalping; symmetric long-short; cited momentum-crash regime risk
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — full ranking + sort + overlap-slot-rebalance rule, fully discretionary-judgment-free
- [x] No Machine Learning required — pure rule-based ranking
- [ ] Friday Close compatibility — multi-stock cross-sectional with 25-day continuous overlap-holds; flag friday_close at risk (CTO confirms at G0)
- [x] Source citation precise — Chan AT (2013), Ch 6 Ex 6.2, PDF pp. 146-147, with Daniel-Moskowitz 2011 supplement
- [ ] No near-duplicate of existing approved card — **NEAR-DUPLICATE-CHECK**: SRC02 `chan-khandani-lo-mr` is cross-sectional MR (opposite direction); SRC02 `chan-pca-factor` is cross-sectional MR with PCA-factor ranking (different ranking metric + opposite direction); S03 `chan-at-buy-on-gap` is cross-sectional MR with gap-fade ranking metric (different metric + opposite direction); S10 `chan-at-xs-mom-fut` (sibling card) is the same momentum mechanic on a futures universe (different asset class + different causal explanation per Chan p. 146). DISTINCT confirmed via the asset-class universe + the explicit different-causal-explanation note from Chan.
- [x] No gridding, no scalping, no ML
- [x] V5-architecture-CHALLENGED status acknowledged — multi-stock + cross-sectional architecture; pipeline G0 review may defer P1 build until V5 cross-sectional framework lands

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) apply; no strategy-specific override; momentum-crash filter and survivorship-correction as enhancement candidates"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: rank universe by 252-day lagged return; long top-50, short bottom-50; daily 1/holddays overlap-rebalance opens new slot every bar"
  trade_management:
    used: true
    notes: "M=25 simultaneous slots per direction; per-name positions = sum of overlap-marks over last 25 bars; capital normalization via /(2·topN·holddays)"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal: per-slot time-stop = 25 days; oldest slot drops out of overlap-sum on each bar"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # SPX-universe → Darwinex single-name CFD universe (limited); architectural substitution required (sector-ETF / world-index cross-section)
  - magic_schema                              # multi-stock cross-sectional architecture (~100+ simultaneous slot-positions = 50 long-overlap-sums + 50 short-overlap-sums × variable per-name) conflicts with V5 default ea_id*10000+symbol_slot
  - one_position_per_magic_symbol             # per-stock positions are sum of overlap-marks (can be 0..25 long or 0..-25 short for any given name); requires multi-slot magic_schema extension
  - friday_close                              # 25-day continuous overlap-holds; positions held over multiple Fri-Mon weekend boundaries; standard exception class for cross-sectional-momentum siblings (analogous to cointegration-pair-trade exception)
at_risk_explanation: |
  Same architectural-pending pattern as S10 chan-at-xs-mom-fut (futures universe variant), S03
  chan-at-buy-on-gap (cross-sectional MR), S04 chan-at-spy-arb (basket cointegration), and SRC02
  cross-sectional cards (chan-khandani-lo-mr, chan-pca-factor, chan-january-effect,
  chan-yoy-same-month). V5 portfolio-of-N-symbols framework would unblock all of these
  simultaneously. CTO confirms at G0 the path forward; substitute paths via sector-ETF or
  world-index cross-section reduce N from ~500 to ~10 and may be the practical V1 deployment.

  friday_close: 25-day overlap-holds = positions across multiple Fri-Mon weekend boundaries.
  Standard exception class for cross-sectional-momentum siblings; CTO confirms at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # cross-sectional ranking at strategy-init + per-bar overlap-mark recomputation
  entry: TBD                                  # rank-mark logic + overlap-sum positions + per-magic-slot allocation
  management: TBD
  close: TBD                                  # per-slot time-stop = 25 days; overlap-sum naturally deactivates oldest mark
estimated_complexity: large                   # multi-stock + cross-sectional architecture + per-slot magic_schema + ~100-position concurrency
estimated_test_runtime: TBD                   # large — cross-sectional sweep is O(N_universe × N_param_combos × N_bars × N_slots × N_symbols)
data_requirements: standard                   # SPX-style daily close × N stocks; survivorship-corrected universe is enhancement (P5c)
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
- 2026-04-28: VOCAB-GAP `cross-sectional-momentum` is reused from S10 chan-at-xs-mom-fut (introduced there). This is the sibling stock-universe variant; same flag with different parameterization (universe_class=stock, topN=50, ranking_metric=252-day-lagged-return). Note that S11 vs S10 share the same exact mechanic but different causal explanation (slow news diffusion for stocks per Chan p. 146 vs roll-return-persistence for futures p. 144) — V5 P3 / P5c may want to test the asset-class generalization explicitly.
- 2026-04-28: Chan's 2007-only Sh 4.1 figure is suspicious as a sample-size artifact (~7 months); the Daniel-Moskowitz 1947-2007 long-window Sh 0.83 is the more credible expected baseline. V5 P3 / P4 walk-forward MUST use a multi-decade test window if available.
- 2026-04-28: 2008-09 -30% APR is the same momentum-crash regime as S10. V5 P5c crisis-slice MUST include 2008-09 across BOTH S10 and S11 (and any other future cross-sectional-momentum cards). The pattern: cross-sectional momentum is documented to fail catastrophically in regime-change periods (2008-09 financial crisis). This is a known momentum-strategy failure mode and not a black swan.
- 2026-04-28: Chan p. 147 factor-extension commentary is the bridge to SRC02 chan-pca-factor (already extracted as PCA-rank cross-sectional MR). The factor-momentum variant is NOT a separate SRC05 card (the lagged-return ranking is the source case); CEO can flag if a factor-tilted variant should be a future SRC.
- 2026-04-28: With this card S11, all 12 unconditional SRC05 cards (S01-S12) are drafted. Remaining S13/S14 are conditional on CEO ratification of `darwinex_native_data_only` exception (S13 PEAD requires earnings-calendar feed; S14 leveraged-ETF-rebal requires US 3x sector ETFs absent from Darwinex). h4 closes the unconditional batch; closeout-pass next per source.md §8.
```
