# Strategy Card — Chan Single-Leg Cointegration Mean-Reversion (corrected v2: AUDCAD.DWX single-symbol implementation)

> Drafted by Research Agent on 2026-05-15 from `strategy-seeds/sources/SRC02/raw/cointegration_pair_family.md` § Chapter 7 Stationarity & Cointegration + Example 7.3 (cadf-pair filter) + Example 7.5 (OU half-life as time-stop).
> Corrected-parametrization sibling of `chan-pairs-stat-arb_card.md` (SRC02_S01, QM5_1017) per [QUA-1564](/QUA/issues/QUA-1564) and the 2026-05-15 P2 zero-pass lessons-learned doc `lessons-learned/2026-05-15_p2_zero_pass_eas_dropped.md`. The original SRC02_S01 was a two-leg ETF pair (GLD vs GDX) with Darwinex re-mapping deferred; this v2 collapses to a single-leg implementation on AUDCAD.DWX — Chan's own cross-currency generalization (Ch 7 p. 133) — eliminating the "second leg not defined cleanly" failure mode flagged in lessons-learned.

## Card Header

```yaml
strategy_id: SRC02_S09
ea_id: TBD
slug: chan-audcad-mr
status: DRAFT
created: 2026-05-15
created_by: Research
last_updated: 2026-05-15

strategy_type_flags:
  - mean-reversion
  - zscore-band-reversion                       # SRC02 batch-ratified flag (QUA-275 closeout)
  - mean-reach-exit                             # SRC02 batch-ratified flag
  - time-stop                                   # OU half-life used as max-hold
  - symmetric-long-short
  - friday-close-flatten
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 7 'Stationarity and Cointegration' pp. 126-127 + p. 133 (verbatim claim that 'the Canadian dollar / Australian dollar (CAD/AUD) cross-currency rate is quite stationary') + Example 3.6 'Pair Trading of GLD and GDX' pp. 55-59 (z-score entry / exit mechanics, applied here as single-series statistic) + Example 7.5 'Calculation of the Half-Life of a Mean-Reverting Time Series' pp. 141-142 (Ornstein-Uhlenbeck half-life as time-stop)."
    quality_tier: A
    role: primary
```

Same primary source as SRC02_S01. v2 corrections are scope adjustments: collapse from two-leg ETF spread to single-leg cross-currency series per Chan's own p. 133 generalization, removing the second-leg ambiguity.

## 2. Concept

A **single-symbol z-score mean-reversion strategy** on AUDCAD.DWX, applied at the D1 bar. Chan's *Quantitative Trading* Ch 7 names the AUD/CAD cross as a directly stationary series — meaning the spread *is the price* rather than a constructed two-asset linear combination. The strategy computes a rolling-window z-score of close vs trailing 252-bar mean/std, opens a long when z ≤ −2.0 (price is unusually low relative to its 1-year trailing mean), opens a short when z ≥ +2.0, exits on mean-reach into the ±0.5 band, or after the OU half-life elapses (whichever fires first).

**Why this corrects the original failure mode.** SRC02_S01 / QM5_1017 returned 0 PASS / 8 FAIL / 28 INVALID at P2 on 2026-05-15. The lessons-learned doc flags "pairs strategies need the second leg defined cleanly; the prior card may have run as single-leg." Two recovery paths exist: (a) properly specify the second leg with hedge-ratio precompute, or (b) collapse to a single-leg series where no second leg exists by construction. This v2 takes path (b) — Chan p. 133 explicitly endorses AUDCAD as a single-series mean-reverting target — which has the cleanest Darwinex deployment story (one symbol, .DWX-native) and the most-deterministic P1 build.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - D1
primary_target_symbols:
  - AUDCAD.DWX                                # primary deployment per Chan's p. 133 endorsement
  - NZDCAD.DWX                                # CSR candidate at P3.5 — cousin cross with similar AUD/NZD ↔ CAD commodity-currency thesis
  - AUDNZD.DWX                                # CSR candidate at P3.5 — AUD/NZD cross is also documented stationary in practitioner literature
session_window: 24-hour                         # D1 bar evaluation
```

## 4. Entry Rules

```text
PARAMETERS (Chan Ex 3.6 defaults; Ex 7.5 half-life):
- LOOKBACK         = 252                      // trailing D1 bars for z-score mean/std
- ENTRY_Z          = 2.0                      // |z| threshold for entry
- HALF_LIFE_BARS   = 10                       // Chan's reported OU half-life for similar mean-reverting FX
                                              // series; sweepable in P3 below
- nLots            = 1                        // RISK_FIXED stake per fill

EACH-BAR PRECOMPUTE (D1 close):
- mu     = mean(close, LOOKBACK)              // 252-bar trailing mean
- sigma  = std(close, LOOKBACK)               // 252-bar trailing std
- zscore = (close - mu) / sigma

REGIME GATE (cadf check, performed once at deployment / re-evaluated weekly out-of-process):
- run cadf(close[trainset]) → require t_stat <= -3.343
- if cadf fails on the current 252-bar trainset: SKIP_ENTRY this week (do not open new positions;
  existing positions exit per § 5)
  // Implemented as a state variable refreshed at the weekly cron tick; intra-week the
  // cached value is used. Documented as `regime_active=true` in the EA state.

ENTRY RULE — LONG:
- if regime_active
- and zscore <= -ENTRY_Z
- and no position open on this magic-symbol
- then BUY nLots at market on next bar

ENTRY RULE — SHORT:
- if regime_active
- and zscore >= +ENTRY_Z
- and no position open on this magic-symbol
- then SELL_SHORT nLots at market on next bar
```

## 5. Exit Rules

```text
MEAN-REACH EXIT (primary):
- if position is LONG  and zscore >= -EXIT_Z   then CLOSE     // EXIT_Z = 0.5 (Chan Ex 3.6 refined default)
- if position is SHORT and zscore <= +EXIT_Z   then CLOSE

TIME-STOP (secondary, fires only if mean-reach hasn't):
- close position after HALF_LIFE_BARS × 2 D1 bars (= 20 bars default) per Chan Ex 7.5 logic:
  expected mean-reversion completes within ~1 half-life; doubling provides slack.

HARD STOP (tertiary, defensive):
- close position if drawdown on this trade exceeds 5 × initial-spread-σ_at-entry × point-value × lot
  // Chan does not specify this; v2 adds it because Darwinex live deployment requires bounded loss per trade.

FRIDAY-CLOSE EXIT:
- close position at Friday 21:00 broker time per V5 framework default.

NO PROFIT TARGET (mean-reach handles this).
```

## 6. Filters (No-Trade module)

```text
- cadf weekly regime gate (see § 4) — strategy-specific.
- Framework defaults (V5):
  - QM_NewsFilter — ON.
  - Friday Close — ON.
  - Kill-switch — ON.
```

## 7. Trade Management Rules

```text
- One open position at a time per magic-symbol.
- No move-to-break-even (mean-reversion strategy; BE-stops would lose edge).
- No partial close.
- No trailing stop (Chan source uses mean-reach exit, not trailing).
- Pyramiding: NOT used.
- Gridding:   NOT used.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: LOOKBACK
  default: 252
  sweep_range: [126, 189, 252, 378, 504]
- name: ENTRY_Z
  default: 2.0
  sweep_range: [1.5, 1.75, 2.0, 2.25, 2.5]
- name: EXIT_Z
  default: 0.5
  sweep_range: [0.0, 0.25, 0.5, 0.75, 1.0]
- name: HALF_LIFE_BARS
  default: 10
  sweep_range: [5, 10, 15, 20, 30]
- name: hard_stop_sigma_mult
  default: 5.0
  sweep_range: [3.0, 4.0, 5.0, 7.0]
```

Symbol and timeframe are pinned (AUDCAD.DWX D1); P3.5 CSR sweeps NZDCAD.DWX and AUDNZD.DWX.

## 9. Author Claims (verbatim, with quote marks)

```text
"Traders have long been familiar with this so-called pair-trading strategy. They buy the pair
portfolio when the spread of the stock prices formed by these pairs is low, and sell/short the
pair when the spread is high—in other words, a classic mean-reverting strategy." (Chan 2009, Ch 7, p. 126)

"Even if you can't find a good cointegrating pair of stocks, you might find a stock whose price
series itself is already stationary, in which case all you need to do is trade this individual
stock in a mean-reverting fashion. For instance, the Canadian dollar / Australian dollar (CAD/AUD)
cross-currency rate is quite stationary." (Chan 2009, Ch 7, p. 133)

"As an illustration, the example just mentioned ... shows that this pair-trading strategy ...
gives an annualized Sharpe ratio of 1.4 on the out-of-sample data set, after deducting transactions
costs." (Chan 2009, Example 3.6, p. 58; refers to the GLD/GDX two-leg variant — included here for
context only since v2 is single-leg)
```

Author-claim band: `author-claimed` per `processes/qb_reputable_source_criteria.md` § 5 — Chan provides a Sharpe claim for the two-leg GLD/GDX variant, no single-leg AUD/CAD performance number; the single-leg deployment is the natural extension Chan endorses but does not separately backtest in this book.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2                              # rough estimate; Chan's GLD/GDX Sharpe 1.4 OOS suggests modest PF
expected_dd_pct: 15                           # rough estimate; pair-trades historically run 10-20% DD
expected_trade_frequency: ~8-15/year on AUDCAD D1   # |z|>=2 + cadf-regime-active is selective
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — z-score thresholds + cadf regime gate + OU half-life time-stop; no discretion.
- [x] No Machine Learning required.
- [x] Gridding: N/A.
- [x] Scalping: N/A (D1 bar size).
- [x] Friday Close compatibility — v2 enforces Friday-close exit explicitly.
- [x] Source citation precise (book + ISBN + chapter + page numbers + example numbers).
- [x] No near-duplicate of existing approved card. SRC02_S01 (chan-pairs-stat-arb) is two-leg ETF pair; this v2 is single-leg FX cross. Distinct strategy_id; distinct mechanical structure (no hedge-ratio); distinct deployment.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "cadf weekly regime gate; require t_stat <= -3.343 on trailing 252-bar series."
  trade_entry:
    used: true
    notes: "z-score >= 2.0 or <= -2.0 entry; market order at next D1 bar; guarded by no-position-open."
  trade_management:
    used: true
    notes: "Hard stop at 5σ initial spread × point-value × lot; broker-side SL."
  trade_close:
    used: true
    notes: "Mean-reach exit at |z|<=0.5; time-stop at 2× half-life bars; Friday-close at 21:00 broker time."
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                      # symbol pinned to AUDCAD.DWX; CSR adds NZDCAD.DWX, AUDNZD.DWX
  - enhancement_doctrine                       # LOOKBACK, ENTRY_Z, EXIT_Z, HALF_LIFE_BARS, hard_stop_sigma_mult sweepable
  - one_position_per_magic_symbol              # explicit no-position-open guard
  - news_pause_default                         # D1 mean-reversion exposure spans news windows; framework default applies
at_risk_explanation: |
  - dwx_suffix_discipline: AUDCAD.DWX is Darwinex-native; .DWX-suffix compliance by-spec.
  - enhancement_doctrine: P3 tunes the z-score thresholds and lookback; the cadf significance level
    is held at 5% per Chan, not swept.
  - one_position_per_magic_symbol: v2 enforces no-position-open guard explicitly.
  - news_pause_default: AUDCAD spans AU + CA central-bank decisions and US-data spillovers; news-pause
    default applies. If P8 reveals pause-cost is too high, exception can be requested at G1.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: medium
estimated_test_runtime: TBD
data_requirements: standard
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-05-15 | initial build (v2 of SRC02_S01 theme; new SRC ID SRC02_S09) | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-05-15 | DRAFT | this card |
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
- 2026-05-15: Authored as corrected-parametrization v2 of SRC02_S01 (chan-pairs-stat-arb / QM5_1017)
  which returned 0 PASS / 8 FAIL / 28 INVALID at P2 on 2026-05-15. Corrections vs original:
    (1) Collapsed two-leg ETF pair to single-leg cross-currency series per Chan p. 133 endorsement.
    (2) Symbol pinned to AUDCAD.DWX (Darwinex-native; no second leg).
    (3) cadf regime gate retained but applied to single series, not to a hedge-ratio-fitted spread.
    (4) Hard stop added at 5σ × point-value × lot (was absent; defensive for live deployment).
    (5) Friday-close at 21:00 broker time enforced explicitly.
  Strategy mechanic (z-score mean-reversion + cadf + OU half-life) and primary source (Chan QT 2009)
  unchanged. The single-leg simplification removes the "second leg not defined cleanly" failure mode
  the lessons-learned doc identified for SRC02_S01.
```
