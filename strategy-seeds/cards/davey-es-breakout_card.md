# Strategy Card — Davey ES Countertrend "Breakout" (Ch 13 walk-forward demonstration)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC01/raw/ch13_walkforward_breakout.md` + cross-references within Chapter 13 (In-Depth Testing / Walk-Forward Analysis), pp. 117-121.
> Submitted for CEO review (Quality-Business not yet hired).

> ⚠ **Note to reviewers:** Davey explicitly demonstrates this strategy as a **walk-forward failure example** (cumulative OOS 2005-2010 = -$9,938). Per OWNER Rule 1 ([CEO comment 85b9ec8e](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470)) Research extracts every distinct mechanical strategy regardless of perceived quality; the V5 pipeline gates G0/P2 are the filter. This card is the "expected fail" specimen in the Davey extraction set — useful as a calibration reference for V5's P2 Baseline Screening (a real countertrend ES system that we know underperforms; if our pipeline rates it favorably, that's a red flag for the pipeline calibration itself).

## Card Header

```yaml
strategy_id: SRC01_S04
ea_id: TBD
slug: davey-es-breakout
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:
  - mean-reversion                            # Davey calls it "countertrend breakout-type" — countertrend = mean-reversion in our taxonomy
  - breakout                                  # the trigger is a fresh N-day high/low close (a breakout-shaped event), even though the trade direction is countertrend
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 13 'In-Depth Testing/Walk-Forward Analysis', § 'A Walk-Forward Primer', pp. 117-121 (verbatim EasyLanguage code at p. 117 [first block, with typo] and p. 119 [second block, corrected]; Table 13.1 walk-forward results at p. 118; Davey's verdict at p. 120)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC01/raw/ch13_walkforward_breakout.md`. Source PDF: `G:\My Drive\QuantMechanica\Ebook\PDF resources\Building Winning Algorithmic Tr - Kevin J. Davey.pdf`.

## 2. Concept

A **countertrend "breakout"** strategy on the mini S&P (ES) continuous futures contract: SHORT when the close prints a fresh X-day high; LONG when the close prints a fresh Y-day low. Stop-loss is a fixed dollar amount (Z). No profit target, no time exit. Davey's verbal description (Ch 13 p. 117):

> "Our strategy will be a very simple one: a countertrend breakout-type system:
>    Enter short if the close is an 'X'-day high close
>    Enter long if the close is a 'Y'-day low close
>    Stop-loss of 'Z'"

The "breakout" here refers to the TRIGGER (a fresh N-day extreme close, breakout-shaped), not the trade direction — the trade direction is countertrend (fade the breakout, expecting reversion). This is structurally similar to the App C Euro Day strategy (which also fades fresh extremes against a momentum filter), but on a different instrument, different timeframe (daily vs 60-min), and without a momentum gate.

## 3. Markets & Timeframes

```yaml
markets:
  - equity_index_futures                      # CME mini S&P (ES) continuous contract
  # V5 Darwinex re-mapping at CTO sanity-check: candidate proxy is US500.DWX (S&P 500 CFD)
timeframes:
  - daily bars                                # Davey, Ch 13 p. 117: "We will use daily bars"
test_period_in_source:
  - 2000-01-01 to 2010-01-01                  # primary test
  - 2010-01-01 to 2013-11-14                  # walk-forward extension (Davey p. 120)
slippage_commission_in_source:
  - "$25 per round-trip trade"                # Davey, Ch 13 p. 117
primary_target_symbols:
  - "@ES (mini S&P continuous futures, CME) — Davey's deployment"
  - "US500.DWX — V5 Darwinex CFD proxy (proposed; CTO confirms tick-size + contract-size mapping)"
```

## 4. Entry Rules

```text
PARAMETERS (Davey's full-period optimum from Ch 13 p. 117; per-walk-forward-window values in § 8 below):
- X = 9          // bar count for highest(close, X) — short trigger
- Y = 5          // bar count for lowest(close, Y) — long trigger
- Z = 600        // stop-loss in USD per contract

CODE (corrected version per Davey p. 119; the first code block at p. 117 has buy/sellshort SWAPPED — TYPO):

if close = highest(close, X) then sellshort next bar at market;   // SHORT on fresh X-day high close
if close = lowest(close, Y)  then buy next bar at market;          // LONG  on fresh Y-day low close
SetStopLoss(Z);                                                     // fixed dollar stop

ENTRY GATE: none beyond the trigger conditions; existing positions can flip on opposite-side triggers
            (no marketposition=0 guard; same pattern as App A Strategy 1).
```

**Source-text typo flagged:** Ch 13 p. 117's first code block prints `if close=highest(close,X) then buy` and `if close=lowest(close,Y) then sellshort` — that's the OPPOSITE direction (trend-following). The verbal description above and the second code block at p. 119 (used in the walk-forward demonstration) both use the COUNTERTREND directions. P1 Build Validation should run BOTH versions and confirm Davey's quoted optimized net profit of **$55,162** over 2000-2010 matches the corrected/countertrend version.

## 5. Exit Rules

```text
STOP LOSS:
- SetStopLoss(Z) where Z = 600 (USD per contract)
  // Walk-forward Z values across 9 blocks: $100, $600, $700, $1000

NO PROFIT TARGET in source.
NO TIME-BASED EXIT in source.
NO SESSION-CLOSE EXIT in source.

POSITION REVERSAL via entry trigger:
- When opposite-direction trigger fires while in a position, the next-bar market order REVERSES
  the position (no separate "close" rule). Same pattern as App A Strategy 1.
```

## 6. Filters (No-Trade module)

```text
- NO time-of-day filter (daily bars; one trigger evaluation per day at close).
- NO news filter (V5 framework default applies).
- NO volatility-floor filter.
- NO higher-timeframe-trend filter.

- Framework defaults (V5):
  - QM_NewsFilter — V5 default ON.
  - Friday Close — strategy can hold positions across Friday 21:00 broker time. See § 12.
  - Kill-switch — V5 default; not affected.
```

## 7. Trade Management Rules

```text
- One open position at a time, but the position can flip on opposite-side triggers.
- No move-to-break-even rule in source.
- No partial close in source.
- No trailing stop in source.
- Pyramiding: NOT used (position-flip pattern; max one position; V5 hard rule complies).
- Gridding:   NOT used.
```

## 8. Parameters To Test (P3 Sweep)

Davey provides **9 walk-forward parameter blocks** (one per ~12-month OOS window from 2005 to 2014). Reproduced verbatim in raw evidence. Plus a full-period optimum (X=9, Y=5, Z=600).

```yaml
- name: X                                     # bar count for short trigger (close = highest(close, X))
  default: 9                                  # Davey's full-period optimum
  per_window_values: [7, 7, 49, 21, 9, 9, 9, 9, 9]
  sweep_range: [5, 7, 9, 11, 15, 21, 30, 49]  # union of values Davey used + endpoints
- name: Y                                     # bar count for long trigger (close = lowest(close, Y))
  default: 5                                  # Davey's full-period optimum
  per_window_values: [17, 45, 7, 11, 5, 5, 5, 5, 5]
  sweep_range: [5, 7, 11, 17, 30, 45]
- name: Z                                     # stop-loss in USD per ES contract
  default: 600                                # Davey's full-period optimum
  per_window_values: [600, 100, 600, 1000, 600, 600, 700, 700, 700]
  sweep_range: [100, 200, 400, 600, 800, 1000]
- name: bar_size                              # Davey uses daily; sweep candidate
  default: D1
  sweep_range: [H4, D1, W1]
```

**V5 deployment will need to:**
- Convert ES contract Z (USD-per-contract stop) to a pip-or-percent equivalent on US500.DWX. ES tick = 0.25 = $12.50; $600 stop ≈ 48 ticks ≈ 12 S&P points. On US500.DWX (CFD, $1/point typical) the equivalent stop is ~12 points but contract-size and leverage interact differently — CTO confirms.
- Re-derive walk-forward parameters at P3 on Darwinex US500.DWX data (futures-vs-CFD price-series divergence is real).

## 9. Author Claims (verbatim, with quote marks)

Davey provides **specific historical performance numbers** for this strategy — the most fully-quantified card from Davey SRC01 so far. From Ch 13:

```text
Optimized result over 2000-2010 (full-period optimization, fitness = net profit):
"This complete optimization produces a net profit of $55,162 over the 10-year period."
(Ch 13, p. 117)

Walk-forward Out-of-Sample results (Table 13.1, p. 118):
- 2005-2006 OOS:  -$3,138  (params 7, 17, 600)
- 2006-2007 OOS:  -$2,325  (params 7, 45, 100)
- 2007-2008 OOS:  +$5,963  (params 49, 7, 600)
- 2008-2009 OOS: -$19,113  (params 21, 11, 1000)
- 2009-2010 OOS:  +$8,675  (params 9, 5, 600)
Cumulative OOS 2005-2010: -$9,938

Davey's verdict (Ch 13, p. 120):
"The optimized equity curve is much, much better than the walk-forward curve. This is to
be expected, since the optimized curve is a result of optimization. This should tell you
that practically any strategy can be made to look good, if you optimize the parameters
over the time period you are interested in."

"The walk-forward results are not very good. Walk-forward analysis is a tough test for
a strategy to 'pass.' Most strategies fail at this analysis."

Out-of-sample extension 2010-2013 (Ch 13, p. 120):
"It is a different story for the walk-forward analysis, as depicted in Figure 13.2. The
years 2010-2013 were flat for the walk-forward equity curve also, but it mimics the
2005-2009 walk-forward results. In other words, the performance of the walk-forward
system did not change through the years--it was consistently flat to down most of
the years."
```

**Crucial scope note:** unlike the App B / App C Monte Carlo claims, these are **actual historical backtest results** Davey produces on ES daily data 2000-2014. The optimized $55,162 number is overfit-by-design (Davey is using it to demonstrate optimization-vs-walk-forward divergence); the walk-forward numbers are the realistic forward-looking estimates. **The walk-forward equity curve is flat-to-down across 2005-2013 by Davey's own report.** V5's P2 Baseline Screening on Darwinex US500.DWX should produce similar (negative or marginal) results if Davey's underlying numbers transfer.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Davey reports net profit but not PF
expected_dd_pct: TBD                          # Davey reports OOS net profit per year but not max DD
expected_trade_frequency: TBD                 # not stated
risk_class: medium-high                       # operator's read; flat-to-down equity curve over 9 years; high parameter drift across walk-forward windows
gridding: false
scalping: false                               # daily bars
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — close-vs-N-day-extreme + fixed dollar stop; no discretion.
- [x] No Machine Learning required.
- [x] Gridding: N/A.
- [x] Scalping: N/A (daily bars).
- [ ] Friday Close compatibility — see § 12. **Likely binds:** strategy has no time exit; positions persist until stop or opposite trigger. V5 Friday-Close handler must cover.
- [x] Source citation precise (book + ISBN + chapter + section + page numbers + table reference).
- [x] No near-duplicate of existing approved card. Distinct from the other Davey cards on instrument (ES vs Euro futures vs unspecified), bar size (daily vs 60-min vs 105-min vs unspecified), entry trigger (close-vs-N-day-extreme vs ATR-band-offset vs xb-bar-extreme+momentum-gate vs 3-bar-consecutive).

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: false                                # source has NO no-trade conditions; framework defaults must cover.
    notes: "Strategy has no entry filters of its own. V5 framework defaults supply news/Friday-close/kill-switch."
  trade_entry:
    used: true
    notes: "close = highest(close, X) → sellshort; close = lowest(close, Y) → buy. Market order at next bar. Existing positions flip on opposite-side triggers."
  trade_management:
    used: true
    notes: "Fixed dollar stop (per contract). NO trailing, NO partial close, NO BE-move."
  trade_close:
    used: false                                # close is governed by stop OR position-flip-via-trigger only.
    notes: "Same pattern as App A Strategy 1: position flip via trigger is NOT a separate close in framework terms."
```

```yaml
hard_rules_at_risk:
  - friday_close                               # NO time exit; positions held across Friday 21:00 broker time unless externally forced flat. V5 Friday-Close handler MUST be applied.
  - dwx_suffix_discipline                      # @ES futures vs US500.DWX CFD; tick-size + contract-size mapping required.
  - darwinex_native_data_only                  # walk-forward parameter values (X, Y, Z) discovered on @ES daily 2000-2014; won't transfer 1-for-1; full re-optimization on US500.DWX at P3.
  - one_position_per_magic_symbol              # position-flip-via-trigger pattern complies with the V5 hard rule (max one position) but EA must explicitly close before re-opening.
  - kill_switch_coverage                       # no native time exit makes kill-switch coverage especially important.
  - enhancement_doctrine                       # walk-forward parameter drift is HIGH (X varies 7-49, Y varies 5-45). Entry-side instability is the rule, not the exception. V5 _v<n> rebuild cadence likely high.
at_risk_explanation: |
  - friday_close: same caveat as App A Strategy 1 — no time exit means open positions cross Friday
    21:00 broker. V5 framework default Friday-Close handler is the mitigation.

  - dwx_suffix_discipline / darwinex_native_data_only: ES futures continuous price series has
    contract-roll discontinuities and settlement vs tick-data differences vs US500.DWX CFD spot.
    All Davey parameters stripped at P3; re-derive on Darwinex US500.DWX data.

  - kill_switch_coverage: same as App A Strategy 1 — no native time-out for runaway positions;
    P9b Operational Readiness should specifically validate kill-switch behavior.

  - enhancement_doctrine: walk-forward parameter drift is among the highest in the Davey set:
    X varies 7→49 (factor of 7), Y varies 5→45 (factor of 9), Z varies $100-$1000 (factor of 10).
    This suggests the underlying signal is unstable across regime. V5 enhancement doctrine implies
    frequent _v<n> rebuilds; Pipeline-Operator should pre-budget for this. Alternatively, this
    parameter instability may itself be evidence that the strategy has no real edge (Davey's own
    walk-forward result: -$9,938 cumulative across 5 OOS years), in which case V5 P2 should kill
    it cleanly.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                                # framework defaults only
  entry: TBD                                   # close-vs-N-day-extreme trigger; flip on opposite-side
  management: TBD                              # fixed dollar stop, per contract
  close: TBD                                   # framework Friday-Close handler; position-flip via opposite trigger
estimated_complexity: small                    # ~15 lines of EasyLanguage; trivial port to MQL5
estimated_test_runtime: TBD
data_requirements: standard                    # Darwinex US500.DWX daily bars
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | TBD | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v<n>`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | DRAFT | this card |
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
- 2026-04-27: SOURCE-TEXT TYPO. Ch 13 p. 117's first EasyLanguage code block has buy/sellshort
  SWAPPED relative to the verbal description and Davey's own framing ("countertrend breakout-type
  system"). The corrected version appears at p. 119 (used in the walk-forward demonstration on
  which Davey reports actual results). Card uses the corrected version. P1 Build Validation
  should run BOTH versions and confirm Davey's $55,162 optimized net profit number matches the
  corrected/countertrend version (it should).

- 2026-04-27: This is the ONLY Davey card so far with quantified historical-backtest numbers
  (vs Apps B/C Monte Carlo claims; vs App A Strategy 1 with no claims). Use Davey's specific
  walk-forward losses (-$9,938 cumulative 2005-2010) as a P2 calibration reference: if V5's
  P2 on US500.DWX produces a similar negative/flat result, the pipeline calibration is in the
  right ballpark.

- 2026-04-27: Davey explicitly demonstrates this strategy as a walk-forward FAILURE example.
  Per Rule 1 the card was drafted anyway. Pipeline G0/P2 will rule on whether to advance.
  This card is essentially the "expected fail" specimen in the Davey extraction set — useful
  precisely BECAUSE we have a strong prior it should fail.

- 2026-04-27: Walk-forward parameter drift here is the highest in the Davey set (X varies
  7-49, factor of 7). Either (a) the strategy needs frequent _v<n> rebuilds in V5's enhancement
  loop, or (b) the parameter instability is itself evidence of no real edge.

- 2026-04-27: ES futures vs Darwinex US500.DWX CFD: contract-size and tick-size differ enough
  that Davey's $600 stop won't transfer mechanically. CTO sanity-check at G0 produces the
  correct mapping; P3 sweep re-optimizes from scratch.
```
