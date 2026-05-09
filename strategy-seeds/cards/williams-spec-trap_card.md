# Strategy Card — Williams Specialist Trap (failed-breakout reversal after 6-20 day box from established trend)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams Failure-Day-Family § "SPECIALISTS TRAP", PDF p. 20).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S10
ea_id: TBD
slug: williams-spec-trap
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - failed-breakout-fade                      # canonical match — entry: multi-bar pattern (trend + 6-20 day box + range-breakout that fails) → contrarian stop-entry at the OPPOSITE extreme of the breakout bar. Distinct from narrow-range-breakout (go-with the breakout direction) — Williams' Specialist Trap FADES the breakout. CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - trend-filter-ma                           # Williams: requires "strong uptrending market" (sells) or "down trend" (buys) — trend-precondition for the box; trend-filter-ma is the closest mapping
  - atr-hard-stop                             # generic dollar-stop V5 → ATR-equivalent
  - symmetric-long-short                      # Williams names BOTH directions verbatim (PDF p. 20): uptrend → box → up-breakout → SELL at true low; downtrend → box → down-breakout → BUY at high
  - friday-close-flatten                      # V5 default; 3-bar trail spec centralized at framework/V5_TM_MODULES.md § TM-3BAR-TRAIL.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 20 (Inner Circle Workshop companion volume), § 'THE FAILURE DAY FAMILY — SPECIALISTS TRAP'. Sister-pattern context: same § lists SMASH DAY (S07), FAKE OUT DAY (S08), NAKED CLOSE DAYS (S09); Specialist Trap is structurally distinct as a multi-bar pattern (trend + box + breakout) rather than single-bar candle-shape. Exit-rule cross-reference: PDF pp. 20-21 § 'WHEN TO EXIT' (4-option menu)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 224-230 (Specialist Trap verbatim). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **failed-breakout fade entry from an established-trend congestion box**. Williams' Specialist Trap is a multi-bar setup:

1. **Trend precondition**: market is in a strong uptrend (for sell-setup) or downtrend (for buy-setup)
2. **Congestion box**: market enters a sideways trading range lasting 6-20 days
3. **Breakout day**: a wide-range bar thrusts in the direction of the original trend (up-breakout from uptrend; down-breakdown from downtrend)
4. **Fade entry**: SELL at the breakout day's true low (uptrend version) or BUY at the breakdown day's true high (downtrend version) — fading the breakout on the assumption that "specialists" / institutional flow trapped the breakout buyers/sellers and prices will now reverse.

Williams' verbatim framing, PDF p. 20:

> "SPECIALISTS TRAP — For a sell look for a strong uptrending market that goes into a trading range or 'box' for 6 to 20 days, then thrusts up on big breakout day. It may go on, or it may not. Our sell will be at the true low of the break out day. If prices are in a down trend and go into that box the reverse of the above, buy long at the high of the breakdown day."

Williams' framing implies the trade is a **stop-entry placed at the breakout bar's opposite extreme** — i.e., the SHORT entry at the breakout-bar's true low only fires if price subsequently retraces back through the breakout-bar's true low (failing the breakout). The position is entered ON THE BREAKOUT DAY itself, not on a confirmation day; if the breakout doesn't fail intra-day, no entry occurs.

This is **mechanically the most complex pattern** in the Failure-Day-Family — it requires:
- Trend-direction classification (over what lookback?)
- Congestion-box detection (what defines the box edges?)
- Breakout-bar identification (what constitutes "thrust"?)
- Same-bar fade-entry execution

Per DL-033 Rule 1, distinct from S07 / S08 / S09 single-bar patterns. This card extracts Specialist Trap specifically.

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                             # generic — Williams' framing is multi-market. Original "specialists" reference is NYSE-specific (specialist market-makers); pattern translates to any liquid trend-prone instrument
  - bond_futures                              # generic
  - commodities                               # generic
  - forex                                     # generic; V5 proxy: spot Darwinex .DWX FX symbols
timeframes:
  - D1                                        # Williams: rules stated on daily bars; box duration "6 to 20 days"
session_window: not specified
primary_target_symbols:
  - "all major Darwinex .DWX index/metal/FX symbols (Williams: pattern is generic; original NYSE-specialists framing is anachronistic but pattern-thesis transfers)"
```

## 4. Entry Rules

Pseudocode — Williams' PDF p. 20 framing structurally translated; Williams leaves THREE quantification gaps (trend-classification lookback, box-edge definition, breakout-thrust quantification) which Research operationalizes per § 8 P3 sweep.

```text
PARAMETERS:
- BAR                = D1
- TREND_LOOKBACK     = 50         // Williams says "strong uptrend" / "down trend" — qualitative; default = 50 bars
                                  //   Operationalization: trend = SMA(50) slope over last 20 bars > THRESH
- BOX_MIN_DAYS       = 6          // Williams: "6 to 20 days"
- BOX_MAX_DAYS       = 20         // Williams: "6 to 20 days"
- BOX_RANGE_PCT_ATR  = 1.5        // Williams: qualitative "trading range or 'box'"; default = max(High) - min(Low)
                                  //   over box window must be < BOX_RANGE_PCT_ATR × ATR(14) at start of box
- BREAKOUT_PCT_BOX   = 0.5        // Williams: "thrusts up on big breakout day"; default = breakout-bar's range
                                  //   ≥ BREAKOUT_PCT_BOX × box_range — i.e., breakout bar is at least half the
                                  //   total box's range in a single bar (single-bar wide-range thrust)
- USE_TRUE_EXTREMES  = true       // Williams: "true low of the break out day" / "high of the breakdown day"
                                  //   "true low" implies true-low/true-high (gap-aware)
- ENTRY_OFFSET_TICKS = 0          // entry trigger at breakout-bar's opposite true extreme

EACH-BAR (intra-bar trigger on the breakout day; evaluate at breakout bar's close OR via stop-entry placed at session start of the breakout day):
- Step 1 (precondition): identify trend at bar t-1
    if uptrend(bars t-TREND_LOOKBACK to t-1):
      trend_direction = UP
    elif downtrend(...):
      trend_direction = DOWN
    else: NO_TRIGGER (no trend = no setup)

- Step 2 (precondition): identify congestion box ending at bar t-1
    Iterate window_size from BOX_MIN_DAYS to BOX_MAX_DAYS:
      box_window = bars t-window_size to t-1 (excluding bar t-1 if a breakout candidate)
      box_atr = ATR(14) at start of box_window
      box_high = max(High over box_window)
      box_low  = min(Low over box_window)
      box_range = box_high - box_low
      if box_range <= BOX_RANGE_PCT_ATR * box_atr:
        BOX_FOUND = true; box_high/low recorded
        break
    If no box found: NO_TRIGGER

- Step 3 (breakout-bar identification at bar t):
    breakout_bar_range = High[t] - Low[t]
    if trend_direction == UP and High[t] > box_high and breakout_bar_range >= BREAKOUT_PCT_BOX * box_range:
      // Up-breakout from uptrend → SELL setup
      stage stop-sell at TrueLow(t) - ENTRY_OFFSET_TICKS
      if intra-day Low[t] <= TrueLow(t): FILL_SHORT at TrueLow(t)
    elif trend_direction == DOWN and Low[t] < box_low and breakout_bar_range >= BREAKOUT_PCT_BOX * box_range:
      // Down-breakdown from downtrend → BUY setup
      stage stop-buy at TrueHigh(t) + ENTRY_OFFSET_TICKS
      if intra-day High[t] >= TrueHigh(t): FILL_LONG at TrueHigh(t)
    else: NO_TRIGGER
```

**Quantification gaps (load-bearing for `enhancement_doctrine`)**: Williams provides only qualitative descriptors for trend ("strong"), box ("trading range"), and breakout ("big breakout day"). Research operationalizes with default thresholds (TREND_LOOKBACK=50, BOX_RANGE_PCT_ATR=1.5, BREAKOUT_PCT_BOX=0.5) and P3 sweeps.

## 5. Exit Rules

Williams' standard exit menu (PDF pp. 20-21) applies; default is dollar-stop + 3-bar trail combo. The Specialist Trap is a counter-trend reversal, so the stop-loss must accommodate the failed-fade case (breakout was real and continues in trend direction). Initial-stop sizing is wider than the single-bar reversal patterns.

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout, comment `cc655c56`; back-port QUA-334). The pseudocode below is retained inline for self-contained card review and matches the canonical TM-module spec.

```text
DEFAULT EXIT:
- HARD_STOP_USD     = 1500       // V5 → ATR-equivalent; counter-trend reversal needs wider stop than single-bar patterns
- HARD_STOP_AT      = box_extreme_breached  // alternative: stop at breakout-bar's HIGH (for short) or LOW (for long) +/- buffer; if price re-takes the breakout direction, fade has failed
- TRAIL_BARS        = 3
- TRAIL_NO_INSIDE   = true
- TRAIL_ACTIVATE    = first_close_in_profit
- TIME_STOP         = 15 bars    // backstop; Specialist Trap reversal can take longer to develop than single-bar patterns

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry (or alternatively at breakout-bar's opposite extreme); whichever fires first
- TRAIL — identical 3-bar non-inside-day true-low/true-high trail as S07/S08/S09
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies; 5-15 day typical hold; Friday-close occasionally binds but
trail or stop usually fires first.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed
- gridding: NOT allowed
- Trend-precondition gating (per § 4 Step 1): trend-direction classification must be UP (sells) or DOWN (buys)
- Box-precondition gating (per § 4 Step 2): congestion box of 6-20 days with range ≤ 1.5×ATR
- Breakout-bar gating (per § 4 Step 3): breakout-bar range ≥ 0.5 × box_range (single-bar wide-range thrust)
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding)
- single-attempt-per-breakout: stop-buy / stop-sell order valid only for the breakout day; if not filled by close, NO new attempt on subsequent days (the specialist-trap thesis assumes the fade happens immediately)
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: trend_lookback
  default: 50                                 # Research operationalization of "strong trend"
  sweep_range: [20, 30, 50, 100, 200]
- name: trend_classification_method
  default: sma_slope                          # SMA(N) slope > 0 over last 20 bars
  sweep_range: [sma_slope, ma_above_below, adx_trending, donchian_extreme]
- name: box_min_days
  default: 6                                  # Williams: "6 to 20 days"
  sweep_range: [4, 6, 8, 10]
- name: box_max_days
  default: 20                                 # Williams: "6 to 20 days"
  sweep_range: [15, 20, 30]
- name: box_range_pct_atr
  default: 1.5                                # Research operationalization
  sweep_range: [1.0, 1.5, 2.0, 2.5, 3.0]
- name: breakout_pct_box
  default: 0.5                                # Research operationalization of "big breakout day"
  sweep_range: [0.3, 0.5, 0.7, 1.0]
- name: use_true_extremes
  default: true                               # Williams: "true low of the break out day"
  sweep_range: [true, false]
- name: entry_offset_ticks
  default: 0
  sweep_range: [0, 1, 2, 5]
- name: hard_stop_atr_mult
  default: 2.5                                # wider than single-bar patterns due to counter-trend nature
  sweep_range: [2.0, 2.5, 3.0, 4.0]
- name: stop_at_breakout_extreme
  default: false                              # use ATR-stop default
  sweep_range: [false, true]                  # true = stop at breakout-bar's opposite extreme; if price re-takes the breakout direction, fade has failed
- name: time_stop_bars
  default: 15
  sweep_range: [5, 10, 15, 20]
```

P3.5 (CSR) axis: Specialist Trap is the most parameter-heavy of the SRC03 family and benefits most from CSR validation across:
- Index CFDs: US500.DWX (Williams' implicit deployment domain), US100.DWX, GER40.DWX, UK100.DWX
- Spot FX: EURUSD.DWX, USDJPY.DWX (FX trends are different in character — slower, more swap-driven)
- Metals: GOLD.DWX (strong-trend instrument; pattern-density expected high)
- Energies: OIL.DWX, NATGAS.DWX (strong trends + sharp reversals; pattern-density expected high)

The pattern is mechanically rich enough that P3 + P3.5 may yield meaningfully different optimal parameter sets per asset class.

## 9. Author Claims (verbatim, with quote marks)

Specialist Trap pattern, PDF p. 20:

> "SPECIALISTS TRAP — For a sell look for a strong uptrending market that goes into a trading range or 'box' for 6 to 20 days, then thrusts up on big breakout day. It may go on, or it may not. Our sell will be at the true low of the break out day. If prices are in a down trend and go into that box the reverse of the above, buy long at the high of the breakdown day."

**Williams provides NO numeric performance claim for Specialist Trap specifically.** No backtest table is associated with this pattern in the source's text-clean range (PDF pp. 1-46). Williams' qualifier "It may go on, or it may not" is unusually candid about the failed-fade case — suggesting Williams himself views the pattern as moderate-edge rather than high-conviction. Per BASIS rule, no extrapolated number is asserted.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.15                             # rough estimate; counter-trend pattern with multiple precondition gates → moderate setup-density, moderate edge
expected_dd_pct: 22                           # rough estimate; counter-trend with wider stops; Williams' own "may go on, or it may not" qualifier suggests significant fail-rate
expected_trade_frequency: 4-12/year/symbol    # rough estimate; multi-condition setup with strong preconditions → relatively rare setups
risk_class: medium                            # counter-trend reversal with multi-bar precondition; intrinsic counter-trend risk class
gridding: false
scalping: false                               # D1
ml_required: false                            # threshold + bar-shape arithmetic + box-detection logic
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (multi-bar precondition checks + stop-buy/sell at fixed reference price)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable
- [x] Friday Close compatibility: 5-15 day typical hold; default V5 applies; occasional Friday-close binding handled via TIME_STOP backstop
- [x] Source citation is precise enough to reproduce — though THREE Williams qualitative gaps (trend, box, breakout) require Research operationalization with P3 sweeps
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "trend-precondition + box-precondition + breakout-bar gate + standard V5 default"
  trade_entry:
    used: true
    notes: "stop-buy at breakout-bar's opposite true extreme on the breakout day; one position per direction; single-attempt-per-breakout"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "3-bar non-inside-day trail + ATR-equivalent hard stop (or breakout-bar's-extreme stop variant) + 15-bar time-stop backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Williams' pattern is generic; CSR P3.5 validates breadth
  - friday_close                              # NOT load-bearing — TIME_STOP backstop
  - news_pause_default                        # standard V5 P8 applies; breakouts can correlate with macro news
  - one_position_per_magic_symbol             # NOT load-bearing
  - kill_switch_coverage                      # counter-trend fade can fail catastrophically if breakout was real and trend extends; hard-stop catches single-trade case; account-level kill-switch catches sequential fades. P5c crisis-slice load-bearing.
  - enhancement_doctrine                      # PRIMARY load-bearing — Williams provides THREE qualitative gaps (trend, box, breakout) which Research operationalizes with default thresholds. Once a live parameter set is fixed, retune = enhancement_doctrine.

at_risk_explanation: |
  dwx_suffix_discipline — generic pattern; CSR P3.5 validates breadth.

  friday_close / news_pause_default / one_position_per_magic_symbol — standard V5 handling.

  kill_switch_coverage — counter-trend fade against a strong trend can fail catastrophically
  if the breakout was genuine. Williams' own qualifier "It may go on, or it may not" acknowledges
  this. Hard-stop catches single-trade case; account-level kill-switch catches sequential adverse
  fades. P5c crisis-slice run on 2008-09 (sustained breakout-down trends), 2020-03 (COVID
  reversal cluster), 2022 (multi-cycle Fed-driven trend-reversals).

  enhancement_doctrine — Williams' THREE qualitative gaps (trend, box, breakout) are load-bearing.
  Card defaults to TREND_LOOKBACK=50 / BOX_RANGE_PCT_ATR=1.5 / BREAKOUT_PCT_BOX=0.5 as Research
  structural translations. P3 sweeps the alternatives. Once live values are fixed at deployment,
  any subsequent retune is enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # multi-precondition gate (trend + box + breakout); standard V5 default
  entry: TBD                                  # box-detection scan + breakout-bar identification + same-bar stop-entry; ~150-220 LOC in MQL5 (most complex of SRC03 cards due to multi-bar precondition logic)
  management: TBD
  close: TBD                                  # 3-bar trail + ATR hard stop (or breakout-extreme stop variant) + 15-bar backstop
estimated_complexity: medium                  # multi-bar precondition logic; box-detection scan is non-trivial
estimated_test_runtime: 4-8h                  # P3 sweep cell count large (5×4×4×3×5×4×2×4×4×2×4 ≈ 245,000 cells; aggressive trim required); D1 bars; multi-market
data_requirements: standard                   # D1 OHLC; no external feeds
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
- 2026-04-28: SRC03_S10 surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `failed-breakout-fade` — entry mechanism: range-breakout that FAILS (price reverses back through
  the range) → contrarian fade entry at the OPPOSITE extreme of the breakout bar. Distinct from
  `narrow-range-breakout` (go-with-breakout, NOT fade-the-breakout) and `gap-fade-stop-entry`
  (S02 — Monday-OOPS! gap; not range-bound). V4 had no equivalent SM_XXX EA per
  `strategy_type_flags.md` Mining-provenance table. Williams citation: PDF p. 20.
  Together with SRC03_S01 / S02 / S07 prior gaps, the running entry-side vocabulary-gap count
  is now FOUR. Plus the calendar-cycle refinement question (S04 / S06). Batch-proposal to
  CEO + CTO when SRC03 extraction stabilizes.

- 2026-04-28: Specialist Trap is the MOST PARAMETER-COMPLEX card in SRC03. Williams' qualitative
  gaps (trend / box / breakout) require Research operationalization with default thresholds.
  Once a live parameter set is fixed at deployment, any subsequent retune = enhancement_doctrine.
  P3 sweep cell count is large (~245k cells); aggressive trim required at the parameter-set
  selection stage of P3.

- 2026-04-28: Williams' own qualifier "It may go on, or it may not" is unusually candid for a
  trading textbook — Williams himself acknowledges the fade can fail. This is a strong signal
  that the strategy is moderate-edge rather than high-conviction. Pipeline P5c crisis-slice
  load-bearing on the failure mode "breakout was real and trend extends" (e.g., 2008-09 trend
  extension; 2020-03 reversal cluster).

- 2026-04-28: Cards-vs-fold decision retained as DISTINCT (S10 vs S07/S08/S09): Specialist Trap
  is a multi-bar pattern (trend + box + breakout day = ~30 bars precondition); S07/S08/S09 are
  single-bar candle-shape patterns. Mechanically distinct enough that P3 sweep alone would not
  collapse them into one card. Per DL-033 Rule 1, distinct cards.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE (single-symbol, daily bars), consistent
  with the SRC03 family pattern. Counter-trend reversal class adds direction-class diversity.
  Combined with S07/S08/S09, the SRC03 reversal-day family now has FOUR cards (single-bar
  Smash/Fakeout/Naked + multi-bar Specialist Trap) — diversifies SRC03 portfolio away from the
  trend-following S01 Vol-BO and calendar-bias S04/S05/S06 family.
```
