# Strategy Card — Chan AT Cross-Sectional Momentum on Commodity Futures (Daniel-Moskowitz, 252-day-lookback rank-buy-top-1 / sell-bottom-1, 25-day overlapping holds, 52-future universe)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 1109-1147 (inline Daniel-Moskowitz cross-sectional futures momentum + Chan's commentary on universe extensibility + 2008-2009 crisis-period failure).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC05_S10
ea_id: TBD
slug: chan-at-xs-mom-fut
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - cross-sectional-momentum                    # NEW VOCAB GAP — entry mechanism: rank universe of N futures by 252-day lagged return; long top-1 (or top-decile) + short bottom-1 (or bottom-decile); hold 25 days. Sibling of existing `cross-sectional-decile-sort` (which is the MR direction); `cross-sectional-momentum` is the OPPOSITE direction (buy winners, sell losers). Vocab gap proposal: separate flag (matches V4 sibling-flag-not-generalize precedent for `intraday-day-of-month` / `intraday-day-of-week` from SRC03 closeout). Distinct from `time-series-momentum` (S07 chan-at-ts-mom-fut) which is single-instrument N-day-ago-sign comparison without cross-sectional ranking.
  - signal-reversal-exit                        # exit mechanism: position rebalanced every 25 days when the new top-N/bottom-N ranking displaces the held names (or position shrinks via daily 1/holddays overlap-rebalance like S07 chan-at-ts-mom-fut)
  - symmetric-long-short                        # long top-rank + short bottom-rank simultaneously; dollar-neutral by construction
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2013). Algorithmic Trading: Winning Strategies and Their Rationale. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 978-1-118-46014-6 (cloth) / 978-1-118-46019-1 (ebk)."
    location: "Chapter 6 'Interday Momentum Strategies', § 'Cross-Sectional Strategies' (PDF pp. 144-145 / printed pp. 144-145). Inline strategy (no numbered Example) — described narratively as a 'simplified version' of Daniel-Moskowitz cross-sectional commodity futures momentum, with explicit parameter values (lookback=252, holddays=25, top-1/bottom-1) and 2005-2009 multi-period performance."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Daniel, Kent, and Tobias Moskowitz. (2011). Momentum Crashes. NBER Working Paper / Columbia Business School Working Paper."
    location: "cited by Chan p. 144 as the source paper for the cross-sectional commodity futures momentum strategy"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC05/raw/ch6_7_pp133-168.txt` lines 1109-1147 (extracted via `pdftotext -layout` 2026-04-28). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Algorithmic Trading_ Winning St - Ernie Chan.pdf`.

## 2. Concept

A **cross-sectional commodity-futures momentum strategy** that buys the top-N futures and shorts the bottom-N futures by 252-day lagged return, holding 25 days with daily 1/holddays overlap-rebalancing (similar mechanic to S07 chan-at-ts-mom-fut but cross-sectional rather than single-instrument). Chan's causal explanation is the **roll-return-persistence** thesis (p. 144) — the same that motivates S07 (time-series momentum) and S08 (XLE-USO roll arb):

> "There is a third way to extract the often large roll returns in futures besides buying and holding or arbitraging against the underlying asset (or against an instrument correlated with the underlying asset). This third way is a cross-sectional strategy: We can just buy a portfolio of futures in backwardation, and simultaneously short a portfolio of futures in contango. The hope is that the returns of the spot prices cancel each other out (a not unreasonable expectation if we believe commodities' spot prices are positively correlated with economic growth or some other macroeconomic indices), and we are left with the favorable roll returns. Daniel and Moskowitz described just such a simple 'cross-sectional' momentum strategy that is almost a mirror image of the linear long-short mean-reverting stock model proposed by Khandani and Lo described in Chapter 3, albeit one with a much longer look-back and holding period (Daniel and Moskowitz, 2011)." (p. 144)

The full source rule (verbatim narrative from Chan p. 145):

> "A simplified version of the strategy is to rank the 12-month return (or 252 trading days in our program below) of a group of 52 physical commodities every day, and buy and hold the future with the highest return for 1 month (or 25 trading days) while short and hold the future with the lowest return for the same period." (p. 145)

The mechanic is therefore:

1. Universe = 52 physical commodity futures
2. Per bar: compute 252-day lagged return for each future
3. Rank futures by this metric
4. Long the highest-ranked, short the lowest-ranked
5. Hold 25 days

Chan does not provide explicit MATLAB for this S10 case (the MATLAB given on p. 146-147 is for S11, the stock variant Ex 6.2). The rule is parameterized identically to S11 with `lookback=252, holddays=25, topN=1` (vs S11's `topN=50` for the larger SPX-stock universe). The implicit overlapping-hold mechanic is inherited from Ex 6.2 (S11's MATLAB code, lines 1182-1196).

Chan's commentary on **performance and 2008-2009 crisis failure** (p. 145):

> "I tested this strategy from June 1, 2005, to December 31, 2007, and the APR is an excellent 18 percent with a Sharpe ratio of 1.37. The cumulative returns are plotted in Figure 6.5. Unfortunately, this model performed very negatively from January 2, 2008, to December 31, 2009, with an APR of −33 percent, though its performance recovered afterwards. The financial crisis of 2008-2009 ruined this momentum strategy, just like it did many others, including the S&P DTI indicator mentioned before." (p. 145)

This is **a direct in-source declaration that V5 P5c crisis-slice testing is required** — the strategy is documented to have failed catastrophically in the 2008-09 period, and any V5 P5c stress test that excludes 2008-09 from the test slice would be insufficient.

Chan's commentary on **universe extensibility** (p. 145-146):

> "Daniel and Moskowitz have also found that this same strategy worked for the universe of world stock indices, currencies, international stocks, and U.S. stocks — in other words, practically everything under the sun. Obviously, cross-sectional momentum in currencies and stocks can no longer be explained by the persistence of the sign of roll returns. We might attribute that to the serial correlation in world economic or interest rate growth in the currency case, and the slow diffusion, analysis, and acceptance of new information in the stock case." (p. 145-146)

This is the bridge to **S11 chan-at-xs-mom-stock** — the same cross-sectional momentum mechanic applied to stocks, but with a different causal explanation (slow news diffusion rather than roll-return persistence).

## 3. Markets & Timeframes

```yaml
markets:
  - commodities_futures                         # Daniel-Moskowitz original universe: 52 physical commodities; Chan does not enumerate the specific 52 contracts but cites it as Daniel-Moskowitz' published universe
  - currencies                                  # Daniel-Moskowitz finding: same strategy worked for FX universe (Chan p. 145)
  - indices                                    # Daniel-Moskowitz finding: same strategy worked for world stock indices (Chan p. 145)
  # V5 Darwinex re-mapping: V5-architecture-CHALLENGED. Substitute paths: (a) Darwinex commodity-CFD universe (GOLD.DWX, SILVER.DWX, COPPER.DWX, BRENT.DWX, NATGAS.DWX, etc.) — limited to ~5-10 names vs Daniel-Moskowitz 52-future universe; (b) FX-cross-sectional (G10 + EM majors via Darwinex spot FX); (c) world-index-cross-sectional (US500.DWX, GER40.DWX, UK100.DWX, NIKKEI.DWX, etc.); (d) defer to V5 portfolio-of-N-symbols framework.
timeframes:
  - D1                                          # daily-bar 252-day lagged return; daily 1/holddays overlap-rebalance
session_window: end-of-day                      # signals at close, rebalance at next close
primary_target_symbols:
  - "Daniel-Moskowitz 52 commodity futures universe (Chan source case): not enumerated by Chan; presumably standard CME/NYMEX/CBOT/ICE liquid contracts"
  - "V5 Darwinex mapping: TBD — V5-architecture-CHALLENGED. Candidate paths: (a) Darwinex commodity-CFD universe ~10 names (constraint: smaller cross-section reduces ranking-edge dispersion); (b) FX-cross-sectional G10+EM ~15 pairs; (c) world-index-cross-sectional ~10 indices; (d) defer to V5 portfolio-of-N-symbols framework."
```

## 4. Entry Rules

```text
- on each new daily bar, for EACH future f in the universe:
    let ret_252d_f = (close[f, t] - close[f, t-252]) / close[f, t-252]   # 252-day lagged return
- after iterating all symbols on bar t, rank futures ASCENDING by ret_252d_f (most-negative-return first)
- LONG TOP-1 = highest-ranked future (most-positive 252-day return)
- SHORT BOTTOM-1 = lowest-ranked future (most-negative 252-day return)
- hold each long/short slot for HOLD_DAYS=25 days
- daily overlap-rebalance: M=25 simultaneous slots per direction; on each new bar, the OLDEST slot (entered HOLD_DAYS ago) closes and a NEW slot opens via the current ranking
- equal capital allocation: each slot uses 1/M of the long-side / short-side total capital
- not in news blackout window per QM_NewsFilter (V5 framework default)
- not in framework Friday-Close window per V5 framework default
```

The overlapping-hold mechanic is identical to S07 chan-at-ts-mom-fut (single-instrument time-series momentum) and S11 chan-at-xs-mom-stock (cross-sectional stock momentum) — Chan reuses the same daily-1/holddays-rebalance pattern across all three cards.

## 5. Exit Rules

```text
- per-slot time-stop = HOLD_DAYS=25 days from slot-entry
- on bar t+25 from entry: slot-position closes; new slot opens with current ranking
- daily overlap-rebalance means at any given bar, M=25 slot-positions are active per direction (long top-N + short bottom-N)
- no SL or TP referenced in the source; pure rolling-rank reversion exit
- no trailing stop in source rule
- Friday Close enforced (default per V5 framework — multi-future cross-sectional with continuous holds; flag friday_close at risk for the equity-leg and FX-leg variants)
- explicit MQL5 V5 mapping: `QM_TM_TimeStop(N=25*24*60 minutes for D1 bars)` per-slot; documented as the mechanic implementation
```

## 6. Filters (No-Trade module)

```text
- isfinite(ret_252d_f) — exclude futures with missing 252-day-prior data (e.g., futures with insufficient history)
- universe-size requirement: at least 2 futures with finite ret_252d to rank — otherwise skip the bar
- V5 framework defaults (kill-switch + news-pause + Friday Close) apply
- (V5 enhancement candidate, NOT in source rule) — momentum-crash filter: Daniel-Moskowitz' own 2011 paper title is "Momentum Crashes"; the 2008-09 -33% APR Chan cites is the canonical momentum-crash scenario. V5 P5c crisis-slice MUST include 2008-09. Optional: skip entries during VIX > N or DXY > N regime gates as a proposed enhancement; not in Chan's rule.
- (V5 enhancement candidate, NOT in source rule) — universe-rebalancing for delisted futures: physical commodity futures change over time (new contracts, delisted contracts); training the strategy requires a survivorship-corrected universe.
```

## 7. Trade Management Rules

```text
- M=25 simultaneous long-slot positions + M=25 simultaneous short-slot positions = 50 total active slots at any bar
- each slot allocated 1/M of the long-side / short-side total capital
- pyramiding: NOT allowed (default V5 one-position-per-magic-symbol per slot; the slots are distinct)
- gridding: NOT allowed (default V5)
- no break-even-move (continuous-holding, time-stop only)
- no partial close (slot positions are entered + exited at opposite ends of the time-stop)
- the strategy is dollar-neutral by construction (long and short legs have equal capital allocation)
- per-slot magic_schema requires a multi-slot extension of V5 default ea_id*10000+symbol_slot — same V5-architecture-CHALLENGED status as S03/S04
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback
  default: 252
  sweep_range: [60, 120, 180, 252, 504]
  notes: "Chan p. 145 / Daniel-Moskowitz original = 252 (12 months). Shorter lookbacks pick up short-term momentum; longer pick up multi-year trends."
- name: holddays
  default: 25
  sweep_range: [10, 25, 60, 120]
  notes: "Chan p. 145 / Daniel-Moskowitz original = 25 (1 month). Shorter holds increase rebalance frequency; longer holds reduce turnover."
- name: topN
  default: 1
  sweep_range: [1, 3, 5, 10]
  notes: "Chan's source case = top-1 / bottom-1 (extreme concentration). Daniel-Moskowitz published variant uses top-decile / bottom-decile. Higher topN diversifies risk but dilutes the ranking-edge concentration."
- name: direction_mode
  default: "symmetric-long-short"
  sweep_range: ["symmetric-long-short", "long-only", "short-only"]
  notes: "Chan presents the dollar-neutral long-short variant. Long-only (skip short leg) and short-only variants are CTO-discretion at G0."
- name: universe_substitution
  default: "52 commodity futures (Daniel-Moskowitz)"
  sweep_range: ["52 commodity futures", "Darwinex commodity-CFD universe ~10", "Darwinex FX-cross-section ~15", "Darwinex world-index-CFD ~10"]
  notes: "V5-architecture-CHALLENGED. Smaller cross-sections may degrade the ranking-edge dispersion. CTO selects path at G0."
```

Conditional / V5-architecture-pending parameters (CTO + CEO discretion at G0):

```yaml
- name: weighting_scheme
  default: "top-N-bottom-N (extreme concentration)"
  sweep_range: ["top-N-bottom-N", "decile (top-10% / bottom-10% equally weighted)", "rank-weighted (linear in rank)"]
  notes: "Chan's source = top-N-bottom-N. Daniel-Moskowitz published version uses decile sort. Rank-weighted is a smoother variant."
```

## 9. Author Claims (verbatim, with quote marks)

```text
"A simplified version of the strategy is to rank the 12-month return (or 252 trading days in our program below) of a group of 52 physical commodities every day, and buy and hold the future with the highest return for 1 month (or 25 trading days) while short and hold the future with the lowest return for the same period. I tested this strategy from June 1, 2005, to December 31, 2007, and the APR is an excellent 18 percent with a Sharpe ratio of 1.37." (p. 145)

"Unfortunately, this model performed very negatively from January 2, 2008, to December 31, 2009, with an APR of −33 percent, though its performance recovered afterwards. The financial crisis of 2008-2009 ruined this momentum strategy, just like it did many others, including the S&P DTI indicator mentioned before." (p. 145)

"Daniel and Moskowitz have also found that this same strategy worked for the universe of world stock indices, currencies, international stocks, and U.S. stocks — in other words, practically everything under the sun. Obviously, cross-sectional momentum in currencies and stocks can no longer be explained by the persistence of the sign of roll returns. We might attribute that to the serial correlation in world economic or interest rate growth in the currency case, and the slow diffusion, analysis, and acceptance of new information in the stock case." (p. 145-146)

"Daniel and Moskowitz described just such a simple 'cross-sectional' momentum strategy that is almost a mirror image of the linear long-short mean-reverting stock model proposed by Khandani and Lo described in Chapter 3, albeit one with a much longer look-back and holding period (Daniel and Moskowitz, 2011)." (p. 144)
```

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # Sharpe 1.37 (favorable period) → rough PF ≈ 1.4-1.6 for 25-day-holding cross-sectional momentum
expected_dd_pct: 35                           # Chan p. 145 -33% APR over 2008-09 = ~35% MaxDD over 2-year crisis slice; longer-horizon MaxDD across full sample likely 20-30%
expected_trade_frequency: 252_rebalances/year_per_slot  # daily overlap-rebalance; 25 slots per direction × ~10 rotations/year = ~250 trades per slot per year
risk_class: medium                            # cross-sectional commodity futures; not scalping; symmetric long-short; cited momentum-crash regime risk
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — full ranking + sort + slot-rebalance rule, fully discretionary-judgment-free
- [x] No Machine Learning required — pure rule-based ranking
- [ ] Friday Close compatibility — multi-future continuous-rebalance; the futures-leg has Friday-close enforcement risk (CTO confirms at G0; flag friday_close at risk)
- [x] Source citation precise — Chan AT (2013), Ch 6 p. 145, with Daniel-Moskowitz 2011 supplement
- [ ] No near-duplicate of existing approved card — **NEAR-DUPLICATE-CHECK**: SRC02 `chan-pca-factor` and `chan-khandani-lo-mr` are cross-sectional MR (opposite direction); S07 `chan-at-ts-mom-fut` is single-instrument time-series momentum (different cardinality + different mechanic); S11 `chan-at-xs-mom-stock` (sibling card in same h4 batch) is the same mechanic on a stock universe. DISTINCT confirmed via the asset-class universe + the explicit Daniel-Moskowitz vs Moskowitz-Yao-Pedersen citation distinction.
- [x] No gridding, no scalping, no ML
- [x] V5-architecture-CHALLENGED status acknowledged — multi-future + cross-sectional architecture; pipeline G0 review may defer P1 build until V5 cross-sectional framework lands

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "framework defaults (kill-switch + news-pause + Friday-Close) apply; no strategy-specific override; momentum-crash filter as enhancement candidate"
  trade_entry:
    used: true
    notes: "Strategy_EntrySignal: rank universe by 252-day lagged return; long top-N, short bottom-N; daily 1/holddays overlap-rebalance opens new slot every bar"
  trade_management:
    used: true
    notes: "M=25 simultaneous slots per direction; slot-allocation 1/M of side capital; daily rebalance via overlap mechanism"
  trade_close:
    used: true
    notes: "Strategy_ExitSignal: per-slot time-stop = 25 days; oldest slot closes on each bar"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # 52-commodity-futures universe → Darwinex commodity-CFD universe (limited ~10 names); architectural substitution required
  - magic_schema                              # multi-future cross-sectional architecture (50 simultaneous slot-positions = 25 long + 25 short) conflicts with V5 default ea_id*10000+symbol_slot — same architectural-pending status as SRC02 chan-khandani-lo-mr / chan-pca-factor + SRC05 S03/S04
  - one_position_per_magic_symbol             # 50 simultaneous positions across 50 distinct slot-magic-IDs; per-slot single-position is compliant, but architecture-level requires per-strategy-magic-prefix extension
  - friday_close                              # multi-future cross-sectional with 25-day continuous holds; positions held over Fri 21:00 broker time + multi-week holds. Strategy survives if framework-default Friday-Close is allowed, OR documented exception is approved (linear-MR continuous-rebalance is a known exception class for cointegration-pair-trade siblings; cross-sectional-momentum may require analogous exception class).
at_risk_explanation: |
  dwx_suffix_discipline + magic_schema + one_position_per_magic_symbol: 52-commodity-futures
  universe → Darwinex commodity-CFD universe (~10 names) is a substantial substitution. Substitute
  paths: (a) commodity-CFD-only universe (GOLD/SILVER/COPPER/BRENT/NATGAS/etc., ~5-10 names);
  (b) FX-cross-sectional (G10+EM ~15 pairs); (c) world-index-cross-sectional (~10 indices); (d)
  defer to V5 portfolio-of-N-symbols framework. CTO selects path at G0.

  friday_close: 25-day continuous holds + daily overlap-rebalance = positions held across 5+ weeks
  including multiple Fri-Mon weekend boundaries. Strategy survives if Friday-Close-default is
  suspended via documented exception OR if positions are forcibly flat on Fri 21:00 (which
  interrupts the rolling-25-day-hold mechanic and likely degrades the edge). Standard exception
  class for `cross-sectional-momentum` siblings (analogous to cointegration-pair-trade exception).
  CTO confirms at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # cross-sectional ranking + 25-day overlap-slot rebalance; per-slot magic_schema extension
  management: TBD
  close: TBD                                  # per-slot time-stop = 25 days
estimated_complexity: large                   # multi-future architecture + per-slot magic_schema + 50-position concurrency
estimated_test_runtime: TBD                   # large — cross-sectional sweep is O(N_universe × N_param_combos × N_bars × N_slots)
data_requirements: standard                   # commodity-futures daily OHLC; survivorship-corrected universe is enhancement (P5c)
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
- 2026-04-28: VOCAB-GAP candidate `cross-sectional-momentum` proposed (per source.md §6 batch). Sibling of existing `cross-sectional-decile-sort` (which is the MR direction). Recommendation: SEPARATE flag rather than parameterizing the existing flag with a `direction_mode` parameter, matching V4 sibling-flag-not-generalize precedent for `intraday-day-of-month` / `intraday-day-of-week` / `holiday-anchored-bias` from SRC03 closeout. Add to `strategy_type_flags.md` as a new heading, parameterized by `weighting_scheme` ∈ {top-N-bottom-N, decile, rank-weighted} and `ranking_metric` ∈ {N-day-lagged-return, factor-exposure-momentum}.
- 2026-04-28: Chan's p. 145 explicit declaration of 2008-09 -33% APR is a direct in-source mandate for V5 P5c crisis-slice testing on 2008-09. Daniel-Moskowitz' paper title is literally "Momentum Crashes" — this is a known momentum-strategy failure mode and not a black swan. V5 P3 / P5c MUST validate the strategy survives a 2008-09-class crisis or document it as an explicit accepted-failure-regime.
- 2026-04-28: Chan's p. 145 universe extensibility claim ("Daniel and Moskowitz have also found that this same strategy worked for the universe of world stock indices, currencies, international stocks, and U.S. stocks") is the bridge to S11 chan-at-xs-mom-stock (same mechanic, stock universe) and motivates the FX-cross-sectional / world-index-cross-sectional substitute paths in V5 deployment. The asset-class shift changes the causal explanation (no longer roll-return persistence) but the mechanic is preserved.
- 2026-04-28: This card is THE most-likely candidate for V5 P5c FAIL among SRC05 cards — Chan himself documents the 2008-09 -33% APR. If V5 P5c crisis-slice testing is set up correctly, this card should fail it (and the failure is documented as expected). This is a useful negative-validation case for the V5 P5c testing infrastructure itself.
```
