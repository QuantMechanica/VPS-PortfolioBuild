# Strategy Card — Williams 18-Bar Two-Bar MA Entry (two consecutive bars on opposite side of 18-bar MA, no inside days, enter at extreme; multi-market)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams § "HARD AND FAST RULES FOR THE 18 DAY AVERAGE", PDF p. 17 + chapter context PDF pp. 16-17).
> Submitted for CEO + Quality-Business review per DL-032 + DL-030.

## Card Header

```yaml
strategy_id: SRC03_S12
ea_id: TBD
slug: williams-18bar-ma
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - trend-filter-ma                           # canonical match — entry conditional on price-vs-MA position
  - n-period-max-continuation                 # closest existing entry-side flag — 2-bar continuation pattern with stop-entry at extreme of confirmation window
  - atr-hard-stop                             # generic V5 stop
  - symmetric-long-short                      # Williams names BOTH directions verbatim
  - friday-close-flatten                      # V5 default; 3-bar trail spec centralized at framework/V5_TM_MODULES.md § TM-3BAR-TRAIL.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 17 (Inner Circle Workshop companion volume), § 'THE 18 BAR PATH OF RIGHTEOUSNESS — HARD AND FAST RULES FOR THE 18 DAY AVERAGE'. Chapter context: PDF pp. 16-17 § 'THE IMMUTABLE LAW OF AVERAGES' + § 'PATTERNS TO THE LAW OF AVERAGES' (Kiss-and-Collapse, Bump-and-Run, Break-and-Go context — supplementary; the operative entry rule is the explicit two-bar / no-inside-day / 18-MA mechanic)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 60-128 (18-Bar context + HARD AND FAST RULES verbatim), lines 130-160 (10-year backtest table for 14 symbols).

## 2. Concept

A **trend-confirmation entry on the 18-bar moving average** with a strict two-bar / no-inside-day filter. Williams' thesis: the 18-day moving average separates "law-of-averages" trend regimes; sustained closes ABOVE the 18-MA (for buys, with no inside days) identify genuine uptrends and the entry at the 2-bar window's HIGHEST HIGH catches the breakout on the third bar.

Williams' verbatim framing, PDF p. 17:

> "HARD AND FAST RULES FOR THE 18 DAY AVERAGE
>
> A buy signal will require that we have two consecutive days with lows that are above (greater than) the 18 day moving average of closing prices. Neither of these day[s] can be an inside day (that's a day with a lower high than the previous day as well as a higher low). Given this condition we will go long at the highest high of these two bars.
>
> A sell signal will require that we have two consecutive days with highs that are below (less than) the 18 day average of closing prices. Neither of these can be an inside day. Given this condition we will go short at the lowest low of these two bars."

Williams provides a 10-year backtest snapshot for 14 symbols (PDF pp. 17-18) showing positive expectancy on Copper, Swiss Franc, British Pound, Corn, Gold, Japanese Yen, Coffee, Heating Oil, Beans, Euro, Sugar, Wheat, D-Mark, T-Bonds. This is the only Williams-published cross-symbol backtest in the source.

Williams' framing positions this as a "naked" trend system (no setup tools): "This system does make money on its' own as you can see from the following listing of taking all buys and sells without any setup criteria. This is comforting, we know it works, but the accuracy is low and it is replete with whipsaws." (PDF p. 17). The "primed market" filter (workshop §§ 1-8) is recommended as overlay.

## 3. Markets & Timeframes

```yaml
markets:
  - all_major                                 # Williams' 14-symbol backtest universe: Copper, Swiss Franc, British Pound, Corn, Gold, Japanese Yen, Coffee, Heating Oil, Beans, Euro, Sugar, Wheat, D-Mark, T-Bonds — all-asset multi-market
timeframes:
  - D1                                        # Williams: "18 day moving average"
session_window: not specified
primary_target_symbols:
  - "all major Darwinex .DWX FX/index/metal/energy symbols (Williams: pattern is universally applicable; backtest spans 14 symbols)"
```

## 4. Entry Rules

```text
PARAMETERS:
- MA_PERIOD          = 18                     // Williams: "18 day moving average"; flexible per his note "no magic to this average"
- MA_TYPE            = SMA                    // Williams uses simple MA on closes
- BAR                = D1
- USE_TRUE_EXTREMES  = false                  // Williams: "highest high of these two bars" — plain
- ENTRY_OFFSET_TICKS = 0                      // entry at 2-bar window's extreme

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- ma = SMA(Close, MA_PERIOD) at bar t-1
- inside_day(b) = High[b] < High[b-1] AND Low[b] > Low[b-1]

- bullish_setup at bars t-2, t-1:
    Low[t-2] > ma_at_t-2 AND Low[t-1] > ma_at_t-1
    AND not inside_day(t-2) AND not inside_day(t-1)

- bearish_setup at bars t-2, t-1:
    High[t-2] < ma_at_t-2 AND High[t-1] < ma_at_t-1
    AND not inside_day(t-2) AND not inside_day(t-1)

ENTRY (only when not in position; orders staged at session start):
- if bullish_setup:
    stage stop-buy at max(High[t-2], High[t-1]) + ENTRY_OFFSET_TICKS
    if intra-day High[t] >= trigger: FILL_LONG at trigger
- if bearish_setup:
    stage stop-sell at min(Low[t-2], Low[t-1]) - ENTRY_OFFSET_TICKS
    if intra-day Low[t] <= trigger: FILL_SHORT at trigger
- single-attempt-per-day: order cancelled at session close if not filled
```

## 5. Exit Rules

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout, comment `cc655c56`; back-port QUA-334). The pseudocode below is retained inline for self-contained card review and matches the canonical TM-module spec.

```text
DEFAULT EXIT (Williams' standard menu):
- HARD_STOP_USD     = 1500
- TRAIL_BARS        = 3                       // Williams' "Amazing 3 Bar"
- TRAIL_NO_INSIDE   = true
- ALT_TRAIL         = 18-bar MA cross         // Williams' "PATTERNS TO THE LAW OF AVERAGES" — when price closes back across MA, exit
- TIME_STOP         = 20 bars (backstop)

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP-equivalent ATR distance
- TRAIL — 3-bar non-inside trail (default) OR 18-MA-cross exit (alt; Williams-internally consistent)
- TIME_STOP backstop

FRIDAY CLOSE: V5 default applies. Trend-following hold can span multiple weeks; sweep-axis
includes friday_close=disabled variant.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults
- 2-bar setup gating per § 4 (both bars on same MA-side, neither inside)
- pyramiding: NOT allowed
- gridding: NOT allowed
- "primed market" filter (OPTIONAL P3 sweep): require additional setup-tool agreement (WVI / COT / Sentiment / etc.) — Williams' recommended overlay
- ATR floor (OPTIONAL): skip when ATR-percentile is unusually low (avoid choppy MA crosses)
```

## 7. Trade Management Rules

```text
- one open position per direction
- single-attempt-per-day for stop-buy/sell trigger
- position size: V5 risk-mode framework
- Friday Close: V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: ma_period
  default: 18                                 # Williams default
  sweep_range: [10, 14, 18, 21, 50, 100]
- name: ma_type
  default: sma
  sweep_range: [sma, ema]
- name: confirmation_bars
  default: 2                                  # Williams: "two consecutive days"
  sweep_range: [1, 2, 3, 4]                   # 1 = single-bar variant; 3-4 = stricter
- name: require_no_inside_days
  default: true                               # Williams explicit
  sweep_range: [true, false]
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: alt_exit
  default: trail_3bar
  sweep_range: [trail_3bar, ma_cross_18, ma_cross_50, atr_trail_3, donchian_trail_20]
- name: primed_filter
  default: off
  sweep_range: [off, wvi_extreme, cot_12mo, ANY_2_AGREE]
- name: friday_close_disable
  default: false
  sweep_range: [false, true]
```

P3.5 (CSR) axis: Williams' 14-symbol backtest is the explicit multi-market validation set; CSR runs across full Darwinex .DWX cohort to confirm the "naked" trend system generalizes — expected POSITIVE on most major instruments per Williams' published table.

## 9. Author Claims (verbatim, with quote marks)

Hard-and-fast rules, PDF p. 17:

> "A buy signal will require that we have two consecutive days with lows that are above (greater than) the 18 day moving average of closing prices. Neither of these day[s] can be an inside day (that's a day with a lower high than the previous day as well as a higher low). Given this condition we will go long at the highest high of these two bars.
>
> A sell signal will require that we have two consecutive days with highs that are below (less than) the 18 day average of closing prices. Neither of these can be an inside day. Given this condition we will go short at the lowest low of these two bars."

10-year multi-symbol backtest, PDF pp. 17-18 (in $1000s):

> "18 DAY MOVING AVERAGE WITH 2 OUTSIDE BARS 10 YEAR RESULTS
>
> COPPER        29.2 (THOUSANDS)
> S FRANC       48.9
> B POUND       132.9
> CORN          35.8
> GOLD          83.4
> JYEN          147.5
> COFFEE        188.0
> HOIL          30.2
> BEANS         87.9
> EURO          30.5
> SUGAR         96.0
> WHEAT         41.5
> DMARK         79.1
> T BONDS       44.8"

(All 14 symbols positive over a 10-year window.) Williams' framing of these results, PDF p. 17:

> "This system does make money on its' own as you can see from the following listing of taking all buys and sells without any setup criteria. This is comforting, we know it works, but the accuracy is low and it is replete with whipsaws."

**Williams provides explicit cross-symbol positive-expectancy results on 14 symbols** — this is the broadest source-published validation set in SRC03. Per BASIS rule, the 14-symbol $-amount table is preserved verbatim above; no extrapolation asserted. Pipeline P2-P9 produces actual edge measurement on Darwinex .DWX symbols.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; Williams' "low accuracy + whipsaws" framing tempers PF expectation
expected_dd_pct: 22                           # whipsaw character implies meaningful DD
expected_trade_frequency: 30-60/year/symbol   # 18-MA breaks are moderately frequent on D1
risk_class: medium                            # trend-following with whipsaw exposure
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Mechanical (MA + 2-bar / no-inside-day check + extreme stop-entry)
- [x] No ML
- [x] Not gridding / not scalping
- [x] Friday Close compatibility: trend hold may span weekends; sweep-axis variant
- [x] Source citation precise (PDF p. 17 verbatim + 14-symbol backtest)
- [x] No near-duplicate

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "2-bar setup gate + standard V5 default; optional primed-filter and ATR-floor"
  trade_entry:
    used: true
    notes: "stop-buy/sell at 2-bar window extreme; single-attempt-per-day"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "3-bar non-inside trail (default) or 18-MA-cross / ATR-trail per P3"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # multi-market generic; CSR P3.5 validates breadth
  - friday_close                              # potentially load-bearing on extended trend holds
  - news_pause_default                        # standard V5 P8
  - one_position_per_magic_symbol             # NOT load-bearing
  - enhancement_doctrine                      # MA_PERIOD 18 is Williams' deliberate convention; ablation across [10, 14, 18, 21, 50, 100] tests sensitivity

at_risk_explanation: |
  dwx_suffix_discipline / friday_close — standard handling.

  enhancement_doctrine — Williams calls out that MA_PERIOD = 18 has "no magic" — chosen for
  convenience. P3 sweep validates that the edge survives across MA_PERIOD ablation. Once
  live MA_PERIOD fixed, retune is enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # MA + bar-shape check + stop-entry; ~80-120 LOC in MQL5
  management: TBD
  close: TBD                                  # trail + alt-exits
estimated_complexity: small
estimated_test_runtime: 2-4h                  # P3 sweep multi-market
data_requirements: standard
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-28 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-28 | DRAFT | this card |

(remaining phases TBD)

## 16. Lessons Captured

```text
- 2026-04-28: SRC03_S12 fits the EXISTING `n-period-max-continuation` flag (closest match) +
  `trend-filter-ma` overlay. Williams' rule is structurally a 2-bar continuation pattern with
  a 18-MA gate — adjacent to V4 Padysak-Vojtko trend-follow leg in
  `specs/seasonality-trend-mr-bitcoin.md` § 3 Sub-signal B (default N=10, hold 5 days). No
  new vocab gap.

- 2026-04-28: Williams provides EXPLICIT cross-symbol backtest table (14 symbols, all positive,
  10-year window) — broadest source-published validation set in SRC03. Per BASIS rule, table
  preserved verbatim; pipeline P2-P9 validates V5 deployment generalization.

- 2026-04-28: Williams' framing 'accuracy is low and it is replete with whipsaws' is candid
  about the strategy's character — the cross-symbol POSITIVE expectancy is achieved despite
  per-symbol whipsaw exposure. This makes S12 a STRONG P9 portfolio-construction candidate
  (ensemble of 14 instruments smooths whipsaw DD via diversification).

- 2026-04-28: MA_PERIOD = 18 is Williams' acknowledged-arbitrary choice ('no magic to this
  average'). Card defaults to 18 per source convention; P3 sweeps [10, 14, 18, 21, 50, 100]
  to validate sensitivity. Once deployment-live MA_PERIOD fixed, retune = enhancement_doctrine.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE. Trend-following class adds direction
  diversity vs SRC03's reversal-heavy S02/S07/S08/S09/S10 family.
```
