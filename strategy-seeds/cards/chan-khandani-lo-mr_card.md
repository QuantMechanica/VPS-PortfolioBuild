# Strategy Card — Chan Khandani-Lo Cross-Sectional MR (continuous-weight long-short on S&P 500, daily rebalance)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC02/raw/cross_sectional_family.md` § A + § B (verbatim Ex 3.7 + Ex 3.8 MATLAB code, performance prints, and universe-effect framing).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S03
ea_id: TBD
slug: chan-khandani-lo-mr
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:                          # closest existing values from strategy_type_flags.md;
                                              # 5th SRC02 vocabulary gap 'cross-sectional-decile-sort' applies (continuous-weighting variant; see § 16)
  - symmetric-long-short                      # both directions; dollar-neutral by construction
  - signal-reversal-exit                      # closest available exit flag — daily rebalance recomputes weights every bar
  # *vocabulary-gap flag proposed for CEO + CTO ratification (shared with S05/S06/S04):
  #   - cross-sectional-decile-sort            # entry mechanism: rank universe + long-short positioning;
  #                                              this card uses CONTINUOUS-WEIGHT variant (weight ∝ −distance-from-market-mean)
  #                                              rather than discrete decile bucketing (S05/S06/S04). Vocab proposal accommodates both.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 3 'Backtesting', § 'Transaction Costs', Example 3.7 'A Simple Mean-Reverting Model with and without Transaction Costs', pp. 61-65 (close-bar baseline, MATLAB code, Sharpe 0.25 pre-cost / -3.19 post-cost) + Example 3.8 'A Small Variation on an Existing Strategy', pp. 65-66 (open-bar refinement variant, Sharpe 4.43 pre-cost / 0.78 post-cost — folded into this card as the `execution_bar_time` parameter)."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Khandani, Amir E. and Lo, Andrew W. (2007). What Happened to the Quants in August 2007? MIT working paper, web.mit.edu/alo/www/Papers/august07.pdf."
    location: "cited by Chan p. 61 as the original anomaly source. Reported Sharpe 4.47 in 2006 (vs Chan's 0.25 reproduction on SP500 — universe-effect, original used small/microcaps)."
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/cross_sectional_family.md` § A + § B. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **continuous-weight cross-sectional mean-reversion** strategy on a US-equity universe, rebalanced every trading day. At the close (Ex 3.7) or open (Ex 3.8) of each bar t: each stock's weight is set proportional to the **negative** of its prior-bar deviation from the equal-weighted market mean — `weight_i(t) = -(r_i(t-1) - r_market(t-1)) / N_valid_stocks(t-1)`. Stocks that under-performed the market get positive (long) weight; outperformers get negative (short) weight. Total exposure is dollar-neutral by construction. Every valid stock holds a position every day; the sign and size are continuously rescaled by the prior bar's deviation from market.

Chan's verbatim framing (Ex 3.7, p. 61):

> "Here is a simple mean-reverting model that is due to Amir Khandani and Andrew Lo at MIT. ... This strategy is very simple: Buy the stocks with the worst previous one-day returns, and short the ones with the best previous one-day returns. Despite its utter simplicity, this strategy has had great performance since 1995, ignoring transaction costs (it has a Sharpe ratio of 4.47 in 2006). Our objective here is to find out what would happen to its performance in 2006 if we assume a standard 5-basis-point-per-trade transaction cost."

Chan's Ex 3.8 refinement framing (p. 65):

> "Lo and behold, the Sharpe ratio before costs increases to 4.43, and after costs, it increases to a profitable 0.78! I will leave it as an exercise for the reader to improve the Sharpe ratio further by testing the strategy on the S&P 400 mid-cap and S&P 600 small-cap universes."

**Architecture concern**: same multi-stock cross-section issue as S05/S06; V5 single-symbol architecture incompatible. Card drafted per DL-033 Rule 1 with the recommended Path 2 G0 verdict (V5-architecture-incompatible reference for future broker-expansion).

## 3. Markets & Timeframes

```yaml
markets:
  - us_equities                               # Chan's deployment: S&P 500 (Chan: load('SPX 20071123'))
timeframes:
  - D1                                        # daily-bar; entry weight evaluated each bar; held one bar then recomputed
session_window: per-day-close-or-open         # depends on execution_bar_time parameter (close per Ex 3.7, open per Ex 3.8)
primary_target_symbols:
  - "S&P 500 universe (Chan's deployment, snapshot 2007-11-23 with explicit survivorship-bias warning)"
  - "Universe-variant CSR axis: S&P 400 mid-cap, S&P 600 small-cap, Russell 2000 (per Chan's Ex 3.8 p. 66 reader-exercise note: '...by testing the strategy on the S&P 400 mid-cap and S&P 600 small-cap universes' — small-cap was the original Khandani-Lo high-Sharpe universe)"
  - "Darwinex equivalent: NONE — same architecture-incompatibility cluster as S05/S06"
```

## 4. Entry Rules

Pseudocode reduced from Chan's MATLAB in Ex 3.7 (pp. 63) — open-bar variant per Ex 3.8 substitutes `cl` → `op`:

```text
PARAMETERS:
- EXECUTION_BAR_TIME = "open"               // Chan's Ex 3.8 refinement (default); Ex 3.7 baseline = "close"
- UNIVERSE           = "SP500"              // Chan's choice; CSR axis sweeps SP400 / SP600 / Russell_2000
- ONE_WAY_TCOST_BPS  = 5                    // Chan's assumption (per p. 61)

EACH-BAR (D1, at close or open per parameter):
- for each stock i in universe with valid (price_i(t), price_i(t-1)):
    r_i(t-1) = (price_i(t-1) - price_i(t-2)) / price_i(t-2)
- N_valid = count of stocks with finite r_i(t-1)
- r_market(t-1) = mean(r_i(t-1) over valid stocks)

POSITION COMPUTATION:
- for each stock i with valid r_i(t-1):
    weight_i(t) = - (r_i(t-1) - r_market(t-1)) / N_valid
- weights sum to ≈ 0 (dollar-neutral by construction)
- daily PnL on bar t computed against bar-t-to-bar-t+1 returns:
    pnl(t) = sum over i of weight_i(t) * r_i(t)        // i.e., positions held one bar, lagged 1

NO INDICATOR / NO PRICE FILTER:
- entry is purely cross-sectional ranking by prior-bar return-vs-market-mean
- Chan does NOT add filters (e.g., min market cap, min price, no penny stocks, liquidity floors)
- Per DL-033 Rule 1, the card preserves Chan's specification

FILL ASSUMPTION:
- close-bar variant (Ex 3.7): positions filled at the SAME-day close where signal is computed
- open-bar variant (Ex 3.8): positions filled at the SAME-day open where signal is computed
  → Chan's Ex 3.8 explicitly: "update the positions at the market open instead of the close"
```

## 5. Exit Rules

```text
DAILY REBALANCE (each bar):
- prior bar's positions are CLOSED at the same time (close or open) as new positions are OPENED
- effective hold = 1 bar (~24 hours) per position
- 100% of positions turn over every bar → high transaction-cost sensitivity (load-bearing per Chan's Ex 3.7 demonstration)

NO STOP-LOSS, NO TRAILING, NO TIME-STOP BEYOND 1-BAR HOLD.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: 1-bar hold means most positions naturally exit before Friday's close;
  positions opened Friday close (Ex 3.7 variant) would carry into Monday — needs handling.
  Open-bar variant (Ex 3.8): positions opened Monday open, held until Tuesday open;
  Friday-open positions held until Monday open spans the weekend.
  Card flags `friday_close` for evaluation; not as severe as multi-day-hold cards.
- pyramiding: NOT applicable (one position per stock, recomputed each bar)
```

## 7. Trade Management Rules

```text
- continuous weight per stock: weight_i ∝ -(r_i - r_market) / N_valid; sum ≈ 0 (dollar-neutral)
- no equal-weighting deciles (DIFFERENCE from S05/S06): every valid stock holds a position scaled by its deviation
- transaction-cost accounting per Chan's Ex 3.7:
    daily_pnl_post_cost(t) = daily_pnl_pre_cost(t) - sum_i abs(weight_i(t) - weight_i(t-1)) * onewaytcost
  → costs incurred whenever weights change (always, since they're recomputed every bar)
- universe-level rebalance every bar; ~500 simultaneous positions on SP500
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: execution_bar_time
  default: "open"                              # Ex 3.8 refinement (Chan's preferred)
  sweep_range: ["open", "close"]               # close = Ex 3.7 baseline
- name: universe
  default: "SP500"                             # Chan's example universe
  sweep_range:                                 # Chan's reader-exercise hint (p. 66)
    - "SP500_large_cap"                        # 0.25 / -3.19 / 4.43 / 0.78 Sharpe regime
    - "SP400_mid_cap"
    - "SP600_small_cap"
    - "Russell_2000_small_cap"                 # original Khandani-Lo universe with 4.47 Sharpe
- name: lookback_bars
  default: 1                                   # Chan's choice (use prior-bar return as ranking signal)
  sweep_range: [1, 3, 5, 10]                   # multi-bar cumulative-return rank
- name: weighting_scheme
  default: "continuous_distance"               # Chan's choice (continuous weight)
  sweep_range:                                 # ablation against discrete bucketing per S05/S06 family
    - "continuous_distance"
    - "decile_sort_top10_bottom10"
    - "decile_sort_top20_bottom20"
- name: onewaytcost_bps
  default: 5                                   # Chan's assumption
  sweep_range: [0, 1, 5, 10, 20]               # cost-sensitivity sweep
```

P3.5 (CSR) axis: universe variants (per Chan's reader-exercise) — does the open-bar variant maintain Sharpe > 0 across SP500/SP400/SP600/Russell?

## 9. Author Claims (verbatim, with quote marks)

S&P 500 universe, 2006 calendar year, close-bar baseline (Ex 3.7):

> "Sharpe ratio should be about 0.25, not 4.47 as stated by the original authors. The reason for this drastically lower performance is due to the use of the large market capitalization universe of S&P 500 in our backtest. If you read the original paper by the authors, you will find that most of the returns are generated by small and microcap stocks." (p. 63-64)

Same setup with 5 bp/one-way transaction cost:

> "Sharpe ratio should be about -3.19" / "The strategy is now very unprofitable!" (p. 65)

Open-bar variant (Ex 3.8):

> "the Sharpe ratio before costs increases to 4.43, and after costs, it increases to a profitable 0.78!" (p. 65)

Universe-effect framing (verbatim, p. 64):

> "If you read the original paper by the authors, you will find that most of the returns are generated by small and microcap stocks."

Reader-exercise (p. 65):

> "I will leave it as an exercise for the reader to improve the Sharpe ratio further by testing the strategy on the S&P 400 mid-cap and S&P 600 small-cap universes."

Survivorship-bias warning (verbatim, p. 61):

> "Here, we will put aside the question of survivorship bias because of the expensive nature of such data and just bear in mind that whatever performance estimates we obtained are upper bounds on the actual performance of the strategy."

Universe-incompatible-with-large-caps:

> "It also illustrates the power of MATLAB in backtesting a model that trades multiple securities—in other words, a typical statistical arbitrage model. Backtesting a model with a large number of symbols over multiple years is often too cumbersome to perform in Excel." (p. 61)

## 10. Initial Risk Profile

```yaml
expected_pf: 1.1                              # Open-bar SP500 post-cost Sharpe 0.78 → PF ≈ 1.1-1.2.
                                              # Close-bar SP500 post-cost Sharpe -3.19 → PF < 1.
                                              # Conservative midpoint estimate; pipeline confirms.
expected_dd_pct: 25                           # rough estimate; cross-sectional MR can DD severely in trend regimes
expected_trade_frequency: 500/day on SP500    # ~500 stock-positions per bar, 100% turnover daily
risk_class: high                              # high-frequency cross-section + extreme transaction-cost sensitivity
gridding: false
scalping: false                               # D1 strategy though daily rebalance
ml_required: false                            # no statistical model beyond cross-sectional ranking
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (continuous weight = -(r_i − r_market)/N is fully deterministic)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1 hold)
- [x] Friday Close compatibility: 1-bar hold mostly compatible; Friday-evening signals carry one weekend (acceptable per V5 default with the standard Friday-close behaviour)
- [x] Source citation is precise enough to reproduce
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default; no strategy-specific filters beyond universe membership"
  trade_entry:
    used: true
    notes: "continuous weight per stock per bar based on prior-bar deviation from market mean; computed at close or open per parameter"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close — daily-recomputed weights replace all positions"
  trade_close:
    used: true
    notes: "all positions closed at next bar's same-time-of-day; immediate re-open with new weights (signal-reversal pattern)"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY G0 BLOCKER — Darwinex CFD universe does NOT offer SP500/600 individual stocks
  - one_position_per_magic_symbol             # PRIMARY ARCHITECTURE INCOMPATIBILITY — ~500 simultaneous positions per bar (SP500); V5 has no basket-EA primitive
  - darwinex_native_data_only                 # universe-level US equity data NOT native to Darwinex
  - kill_switch_coverage                      # no native stop-loss; relies on V5 account-level kill-switch
  - magic_schema                              # daily basket-rebalance + 500 positions = structurally novel for V5

at_risk_explanation: |
  Same V5-architecture-incompatibility cluster as S05 / S06 / S04. Darwinex doesn't offer
  the cross-section; V5 magic-formula registry doesn't support multi-position baskets;
  external US equity data feed required.

  Recommended G0 verdict: **Path 2** — document as "V5-architecture-incompatible reference"
  for future broker-expansion. Same pattern as S05/S06/S04. Preserves the strategy spec.

  ADDITIONAL CONSIDERATION: Chan's published results show extreme transaction-cost sensitivity
  (Sharpe collapses from 0.25 to -3.19 at 5 bp/trade on close-bar; Sharpe goes 4.43 → 0.78
  at the same cost on open-bar). At Darwinex spreads (typical 1-4 bp on liquid US equities IF
  Darwinex offered them), the open-bar variant lands somewhere on Chan's cost-Sharpe curve.
  If/when QM acquires multi-stock equity broker access, the live-cost-vs-edge ratio is THE
  load-bearing test at P9b Operational Readiness.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default
  entry: TBD                                  # cross-sectional rank + continuous weight assignment — basket-EA primitive needed
  management: TBD                             # n/a
  close: TBD                                  # close-all-and-immediately-recompute pattern at each bar
estimated_complexity: large                   # basket-EA primitive + universe-level data integration
estimated_test_runtime: 1-4h                  # daily rebalance × N years × universe × P3 cells
data_requirements: custom_universe            # external feed required; Darwinex INSUFFICIENT
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT (awaiting CEO + Quality-Business review) | this card |

(Remaining P-stages omitted; architecture-incompatibility is expected to gate at G0/P1 with Path 2 recommendation.)

## 16. Lessons Captured

```text
- 2026-04-28: SRC02_S03 reinforces the 5th SRC02 vocabulary-gap proposal: `cross-sectional-decile-sort`
  (entry mechanism). This card uses a CONTINUOUS-WEIGHT variant (weight ∝ −distance-from-market-mean)
  rather than the discrete decile bucketing of S05/S06/S04. The vocab proposal should accommodate
  both — likely via a single flag with `weighting_scheme` ∈ {discrete-decile, continuous-distance,
  pca-rank-decile} as a Strategy Card-level parameter. CEO + CTO ratification at addition time
  decides whether to split into multiple flags or keep as one with a sub-parameter.

- 2026-04-28: Folds Ex 3.7 (close-bar Sharpe 0.25 / -3.19) and Ex 3.8 (open-bar Sharpe 4.43 / 0.78)
  into a single card via `execution_bar_time` parameter. Same pattern as Davey App A Strategy 2/3/4
  (CEO Q1 ruling pending in QUA-191 SRC01) — the question of whether minor parameter variants are
  separate strategies or sub-parameters of one strategy is a recurring extraction-discipline issue.
  Research's read here: open-bar vs close-bar = parameter, NOT distinct strategy. Card preserves both
  via P3 sweep; pipeline P3.5 / P4 decide live deployment.

- 2026-04-28: The transaction-cost sensitivity pattern (Sharpe collapses from 0.25 → -3.19 with 5bp,
  but partly recovers in open-bar variant 4.43 → 0.78) is the LOAD-BEARING insight for V5 P9b
  Operational Readiness gating. Chan's framing (Ex 3.7) is explicitly that this is a transaction-cost
  demonstration. Same family of "Chan-deliberate-pedagogy" cards as S02 chan-bollinger-es and S06
  chan-yoy-same-month — three cards in SRC02 documenting different methodology gates (P9b cost,
  P4 anomaly-decay, P5 factor-stability respectively). Cross-walk note for completion_report.md:
  Chan uses 3 deliberate-failure-or-pedagogy examples to V5's 3 gates.

- 2026-04-28: Architecture-incompatibility cluster shared with S04 / S05 / S06. Recommended Path 2
  (V5-architecture-incompatible reference) preserves all four cards in the V5 corpus for future
  re-activation. CEO + CTO confirm Path 2 vs Path 1 (REJECT) at G0 ratification.
```
