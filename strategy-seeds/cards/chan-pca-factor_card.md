# Strategy Card — Chan PCA Factor Model (rolling-window eigen-decomposition long/short on S&P 600 small-cap)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC02/raw/cross_sectional_family.md` § C (verbatim Ex 7.4 MATLAB code, PCA derivation, Chan's avg-ret print).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S04
ea_id: TBD
slug: chan-pca-factor
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:                          # SRC02 batch ratified by CEO 2026-04-28 (QUA-275 closeout, back-port QUA-332)
  - cross-sectional-decile-sort               # entry mechanism: PCA-derived expected-return ranking → top/bottom-N selection (weighting_scheme=pca-rank-decile, ranking_metric=expected-return-from-model)
  - symmetric-long-short                      # 50 long + 50 short equal-weighted positions
  - signal-reversal-exit                      # daily rebalance recomputes positions every bar
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 7 'Special Topics in Quantitative Trading', § 'Factor Models' narrative pp. 133-135 (factor-model APT framework + Fama-French 3-factor reference) + Example 7.4 'Principal Component Analysis as an Example of Factor Model', pp. 135-140 (MATLAB code + avgret = -1.81% print + 'A very poor return!' comment)."
    quality_tier: A
    role: primary
  - type: book
    citation: "Grinold, Richard C. and Kahn, Ronald N. (1999). Active Portfolio Management: A Quantitative Approach for Producing Superior Returns and Controlling Risk. McGraw-Hill (2nd ed.). ISBN 978-0-07-024882-1."
    location: "cited by Chan p. 135 for the R² benchmark of a good factor model: 'According to experts (Grinold and Kahn, 1999), the R² statistic of a good factor model with monthly returns of 1,000 stocks and 50 factors is typically about 30 percent to 40 percent.'"
    quality_tier: A
    role: supplement
  - type: paper
    citation: "Fama, Eugene F. and French, Kenneth R. (1992). The Cross-Section of Expected Stock Returns. Journal of Finance, 47(2): 427-465."
    location: "cited by Chan p. 134 as the canonical 3-factor model reference (beta + market-cap + book-to-price). PCA Ex 7.4 is the data-driven cousin of Fama-French (no fundamental factor data needed)."
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/cross_sectional_family.md` § C. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **rolling-window PCA factor-model** strategy on the S&P 600 small-cap universe. At each daily close: compute the covariance matrix of the trailing 252-day return matrix; extract the top-5 eigenvectors as factor exposures; compute factor returns via OLS on the most recent bar's returns; project expected next-bar returns assuming **factor-return momentum** (factor returns persist from bar t-1 to bar t). Rank universe by expected return; long the top 50, short the bottom 50, equal-weighted. Hold one bar.

Chan's verbatim conceptual framing (p. 135):

> "However, there is one kind of factor model that relies on nothing more than historical returns to construct. This method is the so-called principal component analysis (PCA). ... If we use the eigenvectors of the covariance matrix R R^T as the columns of the matrix X in the APT equation R = X b + u above, we will find via elementary linear algebra that bb^T is indeed diagonal; and furthermore, the eigenvalues of R R^T are none other than the variances of the factor returns b."

Chan's verbatim performance comment (p. 137):

> "It is a strategy based on the assumption that factor returns have momentum: They remain constant from the current time period to the next. Hence, we can buy the stocks with the highest expected returns based on these factors, and short the ones with the lowest expected returns. You will find that the average return of this strategy is negative, indicating that this assumption may be quite inaccurate, or that specific returns are too large for this strategy to work."

**Chan's third deliberate-failure example in SRC02** (after S02 chan-bollinger-es transaction-cost fail, S06 chan-yoy-same-month anomaly-decay fail). MATLAB-printed `avgret = -1.81%` annualized. Chan (p. 138) labels it explicitly: "A very poor return!" Card drafted per DL-033 Rule 1; serves as documented failure-of-factor-momentum-assumption reference for V5 P5 stress / P7 PBO methodology validation.

**Architecture concern**: same multi-stock cross-section issue as S03/S05/S06; V5 single-symbol architecture incompatible. Recommended G0 Path 2 verdict (V5-architecture-incompatible reference).

## 3. Markets & Timeframes

```yaml
markets:
  - us_equities                               # Chan's deployment: S&P 600 small-cap (Chan: load('IJR 20080114'))
timeframes:
  - D1                                        # daily-bar close-based rebalance
session_window: per-day-close
primary_target_symbols:
  - "S&P 600 small-cap universe (~600 stocks at any time, monthly index reconstitution)"
  - "Universe-variant CSR axis: SP500_large_cap, SP400_mid_cap, Russell_2000 — Chan does NOT explore these in Ex 7.4 but the PCA framework is universe-agnostic"
  - "Darwinex equivalent: NONE — same architecture-incompatibility cluster as S03/S05/S06"
```

## 4. Entry Rules

Pseudocode reduced from Chan's MATLAB in Ex 7.4 (pp. 137-138):

```text
PARAMETERS:
- LOOKBACK_BARS    = 252                      // training window for covariance estimation; Chan's choice
- NUM_FACTORS      = 5                        // top-5 eigenvectors retained; Chan's choice
- TOP_N            = 50                       // long top 50 + short bottom 50; Chan's choice
- UNIVERSE         = "SP600_small_cap"        // Chan's choice; CSR axis sweeps SP500/SP400/Russell

DAILY (each bar t > LOOKBACK_BARS, at NYSE close):
- R = matrix of [LOOKBACK_BARS × N_stocks] daily returns ending at bar t
- transpose R so observations are columns (N_stocks rows × LOOKBACK_BARS columns)
- hasData = stocks with all finite returns over the lookback
- restrict R to hasData stocks
- avgR = row-mean of R    (per-stock average return over lookback)
- center: R = R - avgR
- covR = covariance matrix of R^T  (N_stocks × N_stocks)
- [X, B] = eig(covR)      (X = N_stocks × N_stocks eigenvectors; B = diagonal of eigenvalues)
- retain top NUM_FACTORS eigenvectors → X is N_stocks × 5

FACTOR-RETURN ESTIMATION (last bar's returns):
- b = OLS regression of R[:, last_bar] on X       (5 × 1 vector of factor returns)

EXPECTED-RETURN PROJECTION (next bar):
- Rexp = avgR + X * b                              // N_stocks × 1, key assumption: factor returns persist

POSITION ASSIGNMENT (held one bar at bar t+1):
- sort stocks by Rexp ascending
- SHORT the stocks with bottom TOP_N expected returns → weight -1
- LONG  the stocks with top    TOP_N expected returns → weight +1
- equal-weight within each basket

NO INDICATOR / NO PRICE FILTER:
- entry is purely PCA-derived expected-return ranking
- Chan does NOT add filters (e.g., min market cap, no penny stocks, factor-stability gate, eigenvalue magnitude floor)
- Per DL-033 Rule 1, the card preserves Chan's specification

KEY ASSUMPTION (Chan-flagged, p. 137):
- "factor returns have momentum: They remain constant from the current time period to the next"
- Chan's avgret = -1.81% confirms this assumption is wrong → strategy is a documented failure
```

## 5. Exit Rules

```text
DAILY REBALANCE (each bar):
- prior bar's positions are CLOSED at next bar; new basket opened on the same bar's close
- effective hold = 1 bar (~24 hours) per position

NO STOP-LOSS, NO TRAILING, NO TIME-STOP BEYOND 1-BAR HOLD.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- universe-data sufficiency: skip the day if fewer than (e.g.) 100 stocks have full LOOKBACK_BARS history
- Friday Close: 1-bar hold pattern same as S03 — most positions naturally exit, but Friday-close
  signals carry a weekend. Not severe; standard V5 default applies.
- pyramiding: NOT applicable
```

## 7. Trade Management Rules

```text
- equal-weight within each TOP_N basket: each long stock at +1/TOP_N, each short stock at -1/TOP_N
  (Chan's MATLAB uses ±1 raw weights without normalization — the card adopts +1/TOP_N for V5 risk-mode compatibility)
- daily 100% turnover (every bar's basket fully replaced) → very high transaction cost sensitivity
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback_bars
  default: 252                                 # Chan's choice (1 trading year)
  sweep_range: [126, 189, 252, 378, 504]       # 0.5y / 0.75y / 1y / 1.5y / 2y
- name: num_factors
  default: 5                                   # Chan's choice
  sweep_range: [3, 5, 8, 10, 15]               # how many eigenvectors retained
- name: top_n
  default: 50                                  # Chan's choice (top 50 + bottom 50 = 100 positions per bar)
  sweep_range: [10, 20, 30, 50, 75, 100]       # decile-vs-quintile-vs-quartile axis
- name: universe
  default: "SP600_small_cap"                   # Chan's choice
  sweep_range:                                 # universe variant CSR axis
    - "SP500_large_cap"
    - "SP400_mid_cap"
    - "SP600_small_cap"
    - "Russell_2000_small_cap"
- name: factor_return_assumption
  default: "momentum"                          # Chan's choice: factor returns persist t-1 → t
  sweep_range:                                 # ablation against the load-bearing assumption Chan flags as wrong
    - "momentum"                               # Chan's default (failed at -1.81%)
    - "mean_reversion"                         # invert sign: assume factor returns reverse → expected MR
    - "shrink_to_zero"                         # Bayesian shrink toward zero (no factor-return view)
- name: onewaytcost_bps
  default: 5                                   # standard V5 assumption
  sweep_range: [0, 1, 5, 10, 20]
```

P3.5 (CSR) axis: factor-return assumption sweep is itself a CSR-style ablation — does the "momentum" failure pattern reverse if we assume "mean_reversion"? Chan's broader Ch 7 framing (p. 137-138) hints that small-cap stock returns are mean-reverting at short horizons, so a sign-flip on the factor-return assumption may rescue the strategy. P3 sweep validates.

## 9. Author Claims (verbatim, with quote marks)

S&P 600 small-cap universe, 252-bar lookback, 5 factors, top/bottom-50 baskets, factor-return-momentum assumption:

> "avgret = -1.8099" (verbatim MATLAB output, p. 138)
>
> "% A very poor return!" (verbatim MATLAB comment, p. 138)

Chan's diagnosis (verbatim, p. 137):

> "You will find that the average return of this strategy is negative, indicating that this assumption may be quite inaccurate, or that specific returns are too large for this strategy to work."

Broader factor-model context (verbatim, p. 139):

> "Factor models that are dominated by fundamental and macroeconomic factors have one major drawback—they depend on the fact that investors persist in using the same metric to value companies. This is just another way of saying that the factor returns must have momentum for factor models to work."

Reference R² benchmark (verbatim, p. 135, citing Grinold & Kahn 1999):

> "According to experts (Grinold and Kahn, 1999), the R² statistic of a good factor model with monthly returns of 1,000 stocks and 50 factors is typically about 30 percent to 40 percent."

→ Per the Grinold-Kahn benchmark, a 5-factor model on 600 stocks is at the low end of the R² spectrum; Chan's PCA approach with only 5 factors is effectively below the "good model" benchmark. Card flags this for P7 PBO sensitivity at APPROVED stage.

## 10. Initial Risk Profile

```yaml
expected_pf: 0.7                              # Chan's avgret -1.81% annualized → expected PF < 1; deliberate-failure example
expected_dd_pct: 30                           # rough estimate; cross-sectional MR + factor-decay can DD severely
expected_trade_frequency: 100/day             # 50L+50S = 100 simultaneous positions, full daily turnover
risk_class: high                              # daily multi-position rebalance + author-disclaimed strategy + extreme cost-sensitivity
gridding: false
scalping: false
ml_required: false                            # PCA / OLS / eig are classical linear algebra, NOT ML per strategy_type_flags.md § E
                                              # (per the same disambiguation rationale used for S01 chan-pairs-stat-arb's cadf+OLS)
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (PCA + OLS + sort + decile-N selection = fully deterministic)
- [x] No Machine Learning required — PCA is classical linear algebra (eigen-decomposition); same disambiguation as `strategy_type_flags.md` § E for HMM-with-EM (statistical fit ≠ ML)
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1 rebalance)
- [x] Friday Close compatibility: 1-bar hold mostly compatible (same as S03)
- [x] Source citation is precise enough to reproduce
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default + universe-data-sufficiency gate (skip day if too few stocks have full lookback history)"
  trade_entry:
    used: true
    notes: "PCA covariance decomposition + OLS factor-return estimation + expected-return projection + decile selection of long/short baskets"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close — daily-recomputed baskets replace all positions"
  trade_close:
    used: true
    notes: "all positions closed at next bar; immediate re-open with new PCA-derived baskets"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY G0 BLOCKER — no Darwinex SP600 cross-section
  - one_position_per_magic_symbol             # PRIMARY ARCHITECTURE INCOMPATIBILITY — 100 simultaneous positions per bar
  - darwinex_native_data_only                 # universe-level US equity data NOT native to Darwinex; AND PCA needs lookback
  - kill_switch_coverage                      # no native stop-loss
  - magic_schema                              # daily basket-rebalance + 100 positions = same novel pattern as S03

at_risk_explanation: |
  Same V5-architecture-incompatibility cluster as S03 / S05 / S06. Recommended G0 verdict: Path 2
  (V5-architecture-incompatible reference for future broker-expansion).

  ADDITIONAL ML-DISAMBIGUATION NOTE: PCA + OLS + eigen-decomposition are CLASSICAL LINEAR ALGEBRA,
  not Machine Learning. Same disambiguation as strategy_type_flags.md § E `ml-required` definition
  ("HMM with EM is a maximum-likelihood statistical fit, *not* machine learning in the V5 sense —
  no gradient descent on a parameterised function approximator, no held-out validation set").
  PCA computes eigenvalues/eigenvectors of a covariance matrix in closed form; OLS computes
  regression coefficients in closed form. Neither requires gradient descent, neural-network
  training, or held-out validation. V5 hard rule EA_ML_FORBIDDEN does NOT bind on this card.

  This disambiguation contrasts with Chan Ex 7.1 (perceptron neural network — DOES bind on
  EA_ML_FORBIDDEN, SKIP per S01-S02 source.md updates).
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # PCA + eigen-decomposition + OLS in MQL5 — non-trivial; consider native MQL5
                                              #   linear-algebra library or external precomputation
  management: TBD
  close: TBD
estimated_complexity: large                   # PCA in MQL5 is ~200-400 LOC; basket-EA primitive needed
estimated_test_runtime: 4-12h                 # daily PCA × N years; covariance + eig is O(N_stocks²) per bar
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

(Remaining P-stages omitted; architecture-incompatibility expected to gate at G0/P1 with Path 2 recommendation.)

## 16. Lessons Captured

```text
- 2026-04-28: SRC02_S04 reinforces the 5th SRC02 vocabulary-gap proposal: `cross-sectional-decile-sort`
  with PCA-rank as the lookback-metric variant. The vocab proposal now spans:
    - S05: cross-sectional MR, prior-year annual return ranking, discrete decile
    - S06: cross-sectional momentum, same-month-last-year return ranking, discrete decile
    - S03: cross-sectional MR, prior-bar deviation-from-market continuous-weight
    - S04: cross-sectional momentum-of-factors, PCA-derived expected-return ranking, discrete top-N
  Single flag with `weighting_scheme` + `ranking_metric` Strategy Card-level parameters covers all four.
  Research will batch-propose to CEO + CTO with this synthesis.

- 2026-04-28: Chan's THIRD deliberate-failure example in SRC02 (after S02 chan-bollinger-es and
  S06 chan-yoy-same-month). The three together provide V5 with a structured "cross-walk" of
  methodology-failure modes that map directly to V5 P-stages:
    - S02: P9b Operational Readiness fail (transaction-cost wipes pre-cost edge)
    - S06: P4 Walk-Forward fail (anomaly decayed out-of-sample)
    - S04: P5 Stress / P7 PBO fail (factor-momentum assumption violated)
  Cross-walk note for completion_report.md: Chan provides three deliberate-failure cards to V5's
  three corresponding gates. Davey provided two (Ch 13 walk-forward fail mapping to P4, Ch 1 hogs
  underspecified mapping to source-spec-completeness). Combined: SRC01+SRC02 has 5 deliberate-
  failure / pedagogy-only cards across the V5 P-stage flow — a useful corpus for Pipeline-Operator
  to validate that V5 actually catches what the source authors flag.

- 2026-04-28: ML disambiguation explicitly preserved. PCA + OLS + eigen-decomposition are CLASSICAL
  linear algebra, NOT Machine Learning per strategy_type_flags.md § E `ml-required` definition.
  V5 hard rule EA_ML_FORBIDDEN does NOT bind on this card. Same disambiguation rationale as S01
  chan-pairs-stat-arb (cadf + OLS classical hypothesis testing). Contrasts with the Ex 7.1 SKIP
  (perceptron NN — DOES bind on EA_ML_FORBIDDEN).

- 2026-04-28: Architecture-incompatibility cluster shared with S03 / S05 / S06. Recommended Path 2
  for all four cards. CEO + CTO confirm at G0 ratification.

- 2026-04-28: P3 sweep includes a `factor_return_assumption` ablation axis (momentum vs mean_reversion
  vs shrink_to_zero). Chan's published "momentum" assumption fails at -1.81%. The mean-reversion
  inversion is mechanically just a sign flip; if Chan's broader Ch 7 framing about short-term mean-
  reversion in stock returns is correct, the inverted strategy could be a salvage candidate.
  P3 sweep validates; Pipeline-Operator at P3 reports whether the failure-mode insight reverses.
```
