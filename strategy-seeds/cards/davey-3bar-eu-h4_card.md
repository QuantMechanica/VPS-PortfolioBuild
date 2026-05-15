# Strategy Card — Davey Baseline 3-Bar Mean-Reversion (corrected v2: EURUSD H4 with ATR-floor regime filter)

> Drafted by Research Agent on 2026-05-15 from `strategy-seeds/sources/SRC01/raw/appA_baseline_and_monkey_variants.md` § "Strategy 1" + Chapter 12 ("Limited Testing") § "Monkey See, Monkey Do" pp. 109-110.
> Corrected-parametrization sibling of `davey-baseline-3bar_card.md` (SRC01_S03, QM5_1003) per [QUA-1564](/QUA/issues/QUA-1564) and the 2026-05-15 P2 zero-pass lessons-learned doc `lessons-learned/2026-05-15_p2_zero_pass_eas_dropped.md`. The original SRC01_S03 was instrument-agnostic and timeframe-agnostic; this v2 fixes both omissions and adds a volatility-regime filter to suppress the dead-market signals that drove the original's high INVALID-rate at P2.

## Card Header

```yaml
strategy_id: SRC01_S06
ea_id: TBD
slug: davey-3bar-eu-h4
status: DRAFT
created: 2026-05-15
created_by: Research
last_updated: 2026-05-15

strategy_type_flags:
  - mean-reversion                            # 3-bar consecutive-direction trigger fires the OPPOSITE-side trade
  - atr-hard-stop                             # ATR(14)×0.75 OR fixed-USD-cap, whichever tighter
  - symmetric-long-short                      # entry rules mirror exactly
  - friday-close-flatten                      # added explicitly in this v2; original SRC01_S03 had no time exit
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Davey, Kevin J. (2014). Building Algorithmic Trading Systems: A Trader's Journey from Data Mining to Monte Carlo Simulation to Live Trading. Wiley Trading. ISBN 978-1-118-77898-2 (pbk.); ISBN 978-1-118-77891-3 (PDF). Hoboken, NJ: John Wiley & Sons."
    location: "Appendix A 'Monkey Trading Example, TradeStation Easy Language Code', Strategy 1 'Baseline Strategy (No Randomness)', pp. 247-249 (verbatim EasyLanguage code) + Chapter 12 'Limited Testing', § 'Monkey See, Monkey Do', pp. 109-110 (use as monkey-test baseline)."
    quality_tier: A
    role: primary
```

Same primary source as SRC01_S03. The corrections in this v2 are deployment-specification adjustments, not new mechanical content from the source.

## 2. Concept

A **3-bar mean-reversion strategy** that buys after three consecutive down closes (`close < close[1] < close[2]`) and sells short after three consecutive up closes, gated by a volatility-regime floor that suppresses signals when the market is in a low-volatility / illiquid drift state. Davey's original Strategy 1 is instrument-agnostic and presented as a "monkey-test baseline"; this v2 pins the deployment to EURUSD.DWX on H4 — a regime where the 3-bar pattern has a documented mean-reverting prior (FX-major H4 reversion is a textbook regime, distinct from D1 trend-follow regimes) — and adds an ATR(14) floor so the strategy declines to fire when trailing-60-bar ATR drops below 70% of its rolling median.

**Why this corrects the original failure mode.** SRC01_S03 / QM5_1003 returned 0 PASS / 20 FAIL / 16 INVALID at P2 on 2026-05-15. The lessons-learned doc flags "high INVALID rate suggests data-window/symbol mismatch." This v2 removes the symbol-and-timeframe degree of freedom — pinning explicitly to EURUSD.DWX H4 — and adds a regime gate that prevents triggers in dead markets (a common cause of MIN_TRADES_NOT_MET INVALID at P2). The strategy mechanic is unchanged; the corrections are scope tightening and a single additive filter.

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - H4
primary_target_symbols:
  - EURUSD.DWX                                # primary deployment symbol per v2 correction
  - GBPUSD.DWX                                # CSR candidate at P3.5 — second FX-major to test regime transferability
  - USDJPY.DWX                                # CSR candidate at P3.5 — JPY-cross regime test
```

## 4. Entry Rules

```text
PARAMETERS:
- ssl1            = 0.75                       // ATR multiplier for stop-loss (Davey default; per § 8)
- ssl_usd_cap     = 2000                       // dollar-cap on stop, per lot
- ATR_period      = 14
- ATR_floor_lookback = 60                      // trailing bars for median-ATR baseline
- ATR_floor_frac     = 0.70                    // require ATR(14) >= 0.70 × median(ATR(14), 60)
- nLots           = 1                          // RISK_FIXED stake per fill

REGIME GATE (must pass before entry trigger):
- atr_now      = ATR(14)[close]
- atr_median60 = median(ATR(14), 60)           // trailing 60-bar median
- if atr_now < ATR_floor_frac * atr_median60: SKIP_TRADE this bar

ENTRY RULE — LONG (mean-reversion after 3-bar down sequence):
- if regime gate passes
- and close < close[1] AND close[1] < close[2]
- and no position open on this magic-symbol
- then BUY nLots at market on next bar

ENTRY RULE — SHORT (mean-reversion after 3-bar up sequence):
- if regime gate passes
- and close > close[1] AND close[1] > close[2]
- and no position open on this magic-symbol
- then SELL_SHORT nLots at market on next bar
```

**Position-flip removal vs original.** The original SRC01_S03 allowed opposite-trigger reversals (TradeStation-style market-order flip). This v2 adds a `no position open on this magic-symbol` guard — explicit `one_position_per_magic_symbol` compliance — which removes the implicit-flip mechanic. Reason: V5 `one_position_per_magic_symbol` hard rule prefers explicit close-then-open over implicit flip; cleaner state for P5b / P6 randomized testing.

## 5. Exit Rules

```text
STOP LOSS:
- stop_usd_per_lot = min( ssl1 * point_value * ATR(14)_at_entry , ssl_usd_cap )
- attach as broker-side SL on the open position

NO PROFIT TARGET (Davey source has none; v2 preserves this).

TIME-STOP:
- close position after 12 H4 bars (~2 trading days) if neither stop nor opposite-trigger has fired.
  // Added in v2; original had none. Rationale: H4 mean-reversion priors decay within ~2 days; positions
  // held longer are no longer in the mean-reversion regime the strategy was designed for.

FRIDAY-CLOSE EXIT:
- close position at Friday 21:00 broker time per V5 framework default.
  // Added explicitly in v2; original SRC01_S03 had no Friday-close handler and flagged friday_close
  // as a hard_rules_at_risk. This v2 resolves it by enforcing the framework default.

OPPOSITE-TRIGGER BEHAVIOR:
- If an opposite-direction 3-bar sequence fires while in a position, IGNORE (do not flip).
  Wait for current position to exit via stop / time-stop / Friday-close, then evaluate fresh trigger.
  // Differs from SRC01_S03 which permitted implicit position-flip.
```

## 6. Filters (No-Trade module)

```text
- ATR(14) floor (see § 4 regime gate) — strategy-specific.

- Framework defaults (V5):
  - QM_NewsFilter — ON. Pause entries during high-impact news.
  - Friday Close — ON. Force flat at Friday 21:00 broker time.
  - Kill-switch — ON.
```

## 7. Trade Management Rules

```text
- One open position at a time per magic-symbol (V5 one_position_per_magic_symbol compliant).
- No move-to-break-even.
- No partial close.
- No trailing stop (Davey source has none; v2 preserves to keep mechanic simple).
- Pyramiding: NOT used.
- Gridding:   NOT used.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: ssl1
  default: 0.75
  sweep_range: [0.5, 0.75, 1.0, 1.25, 1.5]
- name: ssl_usd_cap
  default: 2000
  sweep_range: [1000, 2000, 3000]
- name: ATR_period
  default: 14
  sweep_range: [10, 14, 20]
- name: ATR_floor_frac
  default: 0.70
  sweep_range: [0.50, 0.70, 0.90]
- name: ATR_floor_lookback
  default: 60
  sweep_range: [40, 60, 100]
- name: time_stop_bars
  default: 12
  sweep_range: [6, 12, 24, 48]
```

Symbol and timeframe are pinned (EURUSD.DWX, H4); P3.5 CSR sweeps the symbol axis (GBPUSD.DWX, USDJPY.DWX) for regime-transferability validation.

## 9. Author Claims (verbatim, with quote marks)

```text
"With any strategy I create, the strategy's performance better be significantly improved over
what any monkey could do by just throwing darts. If it is not, then I have no desire to trade
such a strategy. I use three different monkey tests and two different time frames for testing.
Passing all of the tests gives me confidence I have something better than random." (Davey 2014, Ch 12, p. 109)

"Typically, a good strategy will beat the monkey 9 times out of 10 in net profit and in maximum
drawdown. For my 8,000 monkey trials, that means approximately 7,200 must have net profit worse
than my results, and the same number of runs with higher maximum drawdown than my walk-forward
results. If I don't reach these goals, I really have to wonder if my entry is truly better than
random." (Davey 2014, Ch 12, p. 109)
```

**Scope note (unchanged from SRC01_S03):** Davey provides no PF, no DD, no win rate, no annualized return for Strategy 1. He does not present it as a personally-traded strategy. The card's P2 Baseline Screening output is the first quantified performance evidence; no author-claim baseline to anchor against. Author-claim band: `author-claimed` per `processes/qb_reputable_source_criteria.md` § 5.

## 10. Initial Risk Profile

```yaml
expected_pf: TBD                              # Davey provides no PF
expected_dd_pct: TBD                          # Davey provides no DD
expected_trade_frequency: ~30-60/year on EURUSD H4   # rough estimate after ATR-floor gate; pre-gate the original triggered very high-frequency on H1 (see SRC01_S03 § 16 observation of 62 deals in 4 days)
risk_class: medium
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — entry is consecutive-close inequality + ATR-floor numeric gate; stop is ATR-multiple + USD cap; no discretion.
- [x] No Machine Learning required.
- [x] Gridding: N/A.
- [x] Scalping: N/A (H4 bar size).
- [x] Friday Close compatibility — v2 explicitly enforces Friday-close exit at 21:00 broker time per framework default.
- [x] Source citation precise (book + ISBN + appendix + Strategy 1 + page numbers + chapter cross-reference).
- [x] No near-duplicate of existing approved card. Distinct from SRC01_S03 on symbol-pinning, timeframe-pinning, regime gate, position-flip behavior, time-stop, and Friday-close handler.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "ATR(14) floor regime gate (atr_now >= 0.70 × median(ATR(14), 60))."
  trade_entry:
    used: true
    notes: "3-bar consecutive-close-direction mean-reversion trigger; market order at next bar; guarded by no-position-open check."
  trade_management:
    used: true
    notes: "ATR-multiple OR fixed-USD-cap stop, whichever tighter; broker-side SL."
  trade_close:
    used: true
    notes: "Time-stop after 12 H4 bars; Friday-close at 21:00 broker time; framework-default kill-switch."
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                      # symbol is EURUSD.DWX (compliant by-spec); naming check at P1.
  - enhancement_doctrine                       # ssl1, ATR_floor_frac, time_stop_bars are sweepable entry-side parameters; expected to drift through P3.
  - one_position_per_magic_symbol              # v2 enforces explicit no-position-open guard.
at_risk_explanation: |
  - dwx_suffix_discipline: symbol is explicit EURUSD.DWX in v2; CSR sweep includes GBPUSD.DWX, USDJPY.DWX — all .DWX suffix.
  - enhancement_doctrine: P3 will tune ssl1, ATR_floor_frac, time_stop_bars; CTO snapshots the post-P3 set as
    the production parameter block per V5 enhancement-doctrine framework.
  - one_position_per_magic_symbol: explicit no-position-open guard added in v2 (vs SRC01_S03 flip behavior).
    The EA must close the current position via stop, time-stop, or Friday-close before evaluating the next
    3-bar trigger.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD
  management: TBD
  close: TBD
estimated_complexity: small
estimated_test_runtime: TBD
data_requirements: standard
```

## 14. Pipeline History (per `_v<n>` rebuild)

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-05-15 | initial build (v2 of SRC01_S03 theme; new SRC ID SRC01_S06) | TBD | TBD |

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
- 2026-05-15: Authored as corrected-parametrization v2 of SRC01_S03 (davey-baseline-3bar / QM5_1003)
  which returned 0 PASS / 20 FAIL / 16 INVALID at P2 on 2026-05-15. Corrections vs original:
    (1) Symbol pinned to EURUSD.DWX (was: instrument-agnostic).
    (2) Timeframe pinned to H4 (was: timeframe-agnostic).
    (3) ATR(14) floor regime gate added (was: no regime filter).
    (4) Explicit no-position-open guard added (was: implicit TradeStation flip).
    (5) Time-stop after 12 H4 bars added (was: no time exit).
    (6) Friday-close at 21:00 broker time enforced explicitly (was: hard_rules_at_risk).
  Strategy mechanic (3-bar mean-reversion) and primary source (Davey 2014 App A Strategy 1) unchanged.
```
