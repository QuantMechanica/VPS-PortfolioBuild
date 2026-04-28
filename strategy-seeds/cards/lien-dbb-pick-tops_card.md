# Strategy Card — Lien Double Bollinger Bands: Pick Tops & Bottoms (range / mean-reversion)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` (verbatim Lien Ch 9 § "Using Double Bollinger Bands to Pick Tops and Bottoms" + § "Using Double Bollinger Bands to Determine Trend versus Range").
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3 / DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC04_S02a
ea_id: TBD
slug: lien-dbb-pick-tops
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - bband-reclaim                             # vocabulary-gap PROPOSED — entry: close back across N·σ Bollinger band after a multi-bar dwell on the OUTER side of the band. Distinct from `zscore-band-reversion` (entry on band CROSS OUT, not reclaim BACK IN). V4 had no equivalent SM_XXX EA. Per-card precondition disambiguation: `precondition_mode = outer-band-zone` (S02a — range-bound between 1st-σ and 2nd-σ) vs `n-bars-opposite-1sigma` (S02b — n consecutive bars on outer side). Flagged at § 16; batch-ratified at SRC04 closeout.
  - atr-hard-stop                             # Lien: 50-pip / 30-pip protective stop below/above 1st-σ band; V5 maps to ATR(14) × M-multiple sweep
  - symmetric-long-short                      # Lien explicitly mirrors long and short rules (PDF pp. 103-104)
  - friday-close-flatten                      # V5 default; Lien examples typically resolve in 24 hours to 6 trading days, so weekend-hold rare
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 9 'Technical Strategy: Trading with Double Bollinger Bands' — § 'Using Double Bollinger Bands to Pick Tops and Bottoms' (PDF pp. 103-107) including 'Strategy Rules for Long Trade' and 'Strategy Rules for Short Trade'. Cross-reference: § 'Using Double Bollinger Bands to Determine Trend versus Range' (PDF p. 107) for regime-classification framing."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` lines 159-200 (Long + Short rule lists verbatim), lines 216-253 (USDJPY Short example + EURUSD Long example with explicit pip arithmetic), lines 279-288 (trend-vs-range regime framing). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Day Trading and Swing Trading t - Kathy Lien.pdf`.

## 2. Concept

Lien observes that the standard ±2σ Bollinger Band overbought/oversold approach produces "significant losses" in trending currencies because pairs "hug" the second-σ band on directional moves (Lien PDF p. 102). She replaces the single ±2σ band with a **double-band** construction (the 20-period 1st-σ AND 2nd-σ bands together — four lines on the chart) and uses the zone BETWEEN the 1st-σ and 2nd-σ bands as a regime-classifier: **price between the two lower bands ⇒ downtrend; price between the two upper bands ⇒ uptrend; price BETWEEN the 1st-σ bands above/below the mean ⇒ range**.

The "Pick Tops and Bottoms" rule fires at the regime transition: price has been pinned in the OUTER band zone (between lower 1st-σ and lower 2nd-σ for longs) — i.e. extended-bearish but inside the band envelope — and the first close back ABOVE the 1st-σ band signals exhaustion of the bearish leg. Buy at NY close (5 pm). The rationale is that trending currencies do not respect the ±2σ band as an extreme, but DO respect the 1st-σ band as the boundary between the trend zone and the range zone — a close back across that boundary is the structural signal that the trend is breaking.

Lien's verbatim framing, PDF p. 102:

> "If the currency pair rises to the upper Bollinger Band, it is considered overbought because the move extended to an extreme level and should therefore be faded. The same is true if it drops to the lower Bollinger Band. Unfortunately, currencies are trending, and using the 20-period two standard deviation bands may not be the best way to trade. ... The better technique would be to add another set of Bollinger Bands — the 20-period, one-standard deviation."

PDF p. 102-103:

> "The general rule of thumb is that we don't buy a bottom until the currency pair has traded above the first standard deviation Bollinger Band. Along the same lines, we do not sell a top until the pair trades below the first standard deviation Bollinger Band."

## 3. Markets & Timeframes

```yaml
markets:
  - forex                                     # Lien Ch 9 entire universe is forex spot pairs; examples: EURUSD, USDJPY, GBPUSD
timeframes:
  - D1                                        # Lien explicit: "Both of these strategies are for daily charts" (PDF p. 110)
  - H4                                        # H4 plausible D1-derivative (V5 internal P3 sweep variant); Lien notes "different strategies and rules can be used for intraday trading using the bands" without specifying — out-of-source extrapolation excluded from default
session_window: NY close (5 pm New York time)  # Lien: "BUY at close of candle or 5pm NY Time" (PDF p. 103, rule 3)
primary_target_symbols:
  - "EURUSD.DWX (Lien example: PDF pp. 102-103 daily chart, p. 105 Long entry @ 1.1151, p. 104 Short @ 1.1313)"
  - "USDJPY.DWX (cross-paired with EURUSD in Ch 9)"
  - "GBPUSD.DWX, USDCHF.DWX, AUDUSD.DWX, NZDUSD.DWX, USDCAD.DWX (multi-major generalization implicit in Lien's chapter framing)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Lien's PDF pp. 103-104 rule lists.

```text
PARAMETERS:
- BB_PERIOD          = 20         // Lien: "the 20-period moving average" (PDF p. 101)
- BB_INNER_SIGMA     = 1.0        // Lien: "the 20-period, one-standard deviation" (PDF p. 102)
- BB_OUTER_SIGMA     = 2.0        // Lien: "the two standard deviation bands" (PDF p. 101)
- BAR                = D1         // Lien: "Both of these strategies are for daily charts"
- ENTRY_TIME         = "17:00 NY" // Lien: "5pm NY Time" (PDF p. 103)
- LONG_STOP_PIPS     = 50         // Lien: "Stop 50 pips below first standard deviation Bollinger Band" (PDF p. 103, long rule 4)
- SHORT_STOP_PIPS    = 30         // Lien: "Stop 30 pips above first standard deviation Bollinger Band" (PDF p. 104, short rule 4)
                                  //   N.B. Lien's long-stop (50 pips) and short-stop (30 pips) are asymmetric verbatim;
                                  //   no rationale given in source. Card preserves the asymmetry; P3 sweep tests
                                  //   both directions at {30, 50} pips.

EACH-BAR (evaluated at NY close):
- mid          = SMA(close, BB_PERIOD)                                // 20-period MA
- inner_upper  = mid + BB_INNER_SIGMA * stdev(close, BB_PERIOD)
- inner_lower  = mid - BB_INNER_SIGMA * stdev(close, BB_PERIOD)
- outer_upper  = mid + BB_OUTER_SIGMA * stdev(close, BB_PERIOD)
- outer_lower  = mid - BB_OUTER_SIGMA * stdev(close, BB_PERIOD)

LONG ENTRY (close above inner_lower band after dwell in lower-outer-band zone):
- precondition: pair has been "trading between the lower first and second standard deviation Bollinger Bands"
                (Lien PDF p. 103, long rule 1) — price closes for ≥ DWELL_BARS consecutive bars
                with close[t-k] ∈ [outer_lower[t-k], inner_lower[t-k]] for k = 1..DWELL_BARS
- trigger:      close[t] > inner_lower[t]                              // Lien: "a close above the first standard deviation Bollinger Band"
- if both conditions: BUY at close of bar (NY 5pm)                     // Lien: "BUY at close of candle or 5pm NY Time"
- initial stop: entry - max(LONG_STOP_PIPS_at_entry, entry - inner_lower[t]) ≡ inner_lower[t] - LONG_STOP_PIPS
                                                                      // Lien: "Stop 50 pips below first standard deviation Bollinger Band"

SHORT ENTRY (mirror of long):
- precondition: pair "trading between the upper first and second standard deviation Bollinger Bands" for ≥ DWELL_BARS
- trigger:      close[t] < inner_upper[t]
- if both: SELL at close of bar (NY 5pm)
- initial stop: inner_upper[t] + SHORT_STOP_PIPS

DWELL_BARS default: 1                         // Lien's rule reads as "trading between" the two bands —
                                              //   ambiguous on minimum dwell length; default 1 (any prior bar
                                              //   in the zone qualifies); P3 sweeps {1, 2, 3, 4, 5}
```

Lien's rule wording leaves DWELL_BARS underspecified — "trading between the lower first and second standard deviation Bollinger Bands" describes a zone-state without a minimum bar count. Per BASIS rule, the card defaults to DWELL_BARS = 1 (any prior bar in the zone) and exposes the parameter to P3 sweep.

## 5. Exit Rules

Lien's exit rule list (PDF pp. 103-104, rules 5-6 for both long and short):

> "5. Close half of position when it moves by amount risked; move stop on rest to initial entry price (breakeven).
>  6. Close remainder of position at two times risk or trail the stop."

Pseudocode:

```text
PARAMETERS:
- TP1_RR             = 1.0        // Lien: "Close half of position when it moves by amount risked"
- TP2_RR             = 2.0        // Lien: "Close remainder of position at two times risk"
- TRAIL_AFTER_TP1    = "BE"       // Lien: "move stop on rest to initial entry price (breakeven)" — fixed BE move at TP1
- TRAIL_ALT          = "moving_average_or_percentage"
                                  // Lien (PDF p. 106): "If the stop was trailed using a moving average or percentage,
                                  //   a trader may have been able to capitalize on the selloff that ensued."
                                  //   Underspecified; P3 sweep axis between fixed-2R-target and trail variant.

EACH-BAR (in position):
- HARD STOP — fires at initial stop price (rule 4)
- TP1 (close half): if abs(price - entry) >= 1 * abs(entry - initial_stop):
    CLOSE_HALF
    move_remaining_stop to BE (entry price)
- TP2 (close remaining):
    EITHER fixed: if abs(price - entry) >= 2 * abs(entry - initial_stop): CLOSE_ALL
    OR trail: trail by SMA(close, 20) ± N pips (Lien suggests "moving average or percentage" without explicit N)
    P3 sweep selects between the two variants.

FRIDAY CLOSE: V5 default applies. Lien examples resolve in 24 hours to ~6 trading days
(EURUSD example: 2-day move; USDJPY Short Trade Fig 9.4: 1 day; sample second-target hits
take 1-6 sessions). Friday-21:00 hold occasionally binds; default-flatten preserves edge.
No waiver requested.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (Lien rules describe single-position-at-a-time)
- gridding: NOT allowed
- regime gate (Lien Ch 9 § "Trend versus Range" PDF p. 107):
  Lien explicitly subdivides by regime — RANGE mode (between 1st-σ bands) → use this card; TREND mode (between two upper or two lower bands) → use S02b "Trend Join" card. The two cards are co-regime mutually exclusive at the SAME bar.
  Card-level filter: skip entries when the SAME-bar precondition for S02b would also fire (i.e., when DWELL_BARS for S02b precondition ≥ S02b minimum). Otherwise both cards could fire in opposite directions on the same bar — the regime split is the conflict resolver.
- Lien Ch 7 PDF p. 73-89 ADX-range filter (optional sweep axis): trade only when ADX(14) < 25 (range regime), per Lien's regime-classification system. Off by default; on as a P3 axis variant.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- position size: V5 RISK_PERCENT / RISK_FIXED standard; Lien describes a "two-lot" trade in examples (PDF pp. 104-105) — V5 implements the 50% partial close, not the multi-lot construction
- TP1 (50% close + BE move): hard rule
- TP2: fixed-2R OR trail (P3 sweep axis)
- Friday Close: forced flat per V5 default (no waiver)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: bb_period
  default: 20                                 # Lien: "the 20-period moving average"
  sweep_range: [10, 14, 20, 26, 34]           # paired with stdev period
- name: bb_inner_sigma
  default: 1.0                                # Lien: "the 20-period, one-standard deviation"
  sweep_range: [0.75, 1.0, 1.25, 1.5]
- name: bb_outer_sigma
  default: 2.0                                # Lien: "the two standard deviation bands"
  sweep_range: [1.75, 2.0, 2.25, 2.5]
- name: dwell_bars
  default: 1                                  # underspecified by Lien; default = any prior bar in outer-band zone
  sweep_range: [1, 2, 3, 4, 5]
- name: long_stop_pips
  default: 50                                 # Lien: "Stop 50 pips below first standard deviation Bollinger Band"
  sweep_range: [25, 30, 40, 50, 65, 80]
- name: short_stop_pips
  default: 30                                 # Lien: "Stop 30 pips above first standard deviation Bollinger Band"
  sweep_range: [20, 25, 30, 40, 50, 65]
- name: tp2_mode
  default: fixed_2R                           # Lien primary: "Close remainder of position at two times risk"
  sweep_range: [fixed_2R, trail_sma20, trail_sma50, trail_atr2, trail_pct1]
- name: stop_pip_unification
  default: asymmetric                         # Lien's verbatim 50/30 long/short asymmetry
  sweep_range: [asymmetric, symmetric_avg, symmetric_at_50, symmetric_at_30]
                                              # Tests whether the asymmetry is essential or noise
```

P3.5 (CSR) axis: re-run on Darwinex FX cohort (`EURUSD.DWX`, `GBPUSD.DWX`, `USDJPY.DWX`, `USDCHF.DWX`, `AUDUSD.DWX`, `NZDUSD.DWX`, `USDCAD.DWX`) plus key crosses (`EURJPY.DWX`, `GBPJPY.DWX` if Darwinex offers).

## 9. Author Claims (verbatim, with quote marks)

Strategy framing, PDF p. 102:

> "The better technique would be to add another set of Bollinger Bands — the 20-period, one-standard deviation. ... Having two sets of Bollinger Bands on your chart is a much more effective way to pick a top or bottom in currencies."

Long rule list, PDF p. 103:

> "Strategy Rules for Long Trade
> 1. Look for the currency pair to be trading between the lower first and second standard deviation Bollinger Bands.
> 2. Look for a close above the first standard deviation Bollinger Band.
> 3. If so, BUY at close of candle or 5pm NY Time.
> 4. Stop 50 pips below first standard deviation Bollinger Band.
> 5. Close half of position when it moves by amount risked; move stop on rest to initial entry price (breakeven).
> 6. Close remainder of position at two times risk or trail the stop."

Short rule list, PDF p. 104:

> "Strategy Rules for Short Trade
> 1. Look for the currency pair to be trading between the upper first and second standard deviation Bollinger Bands.
> 2. Look for a close below the first standard deviation Bollinger Band.
> 3. If so, sell at close of candle or 5pm NY Time.
> 4. Stop 30 pips above first standard deviation Bollinger Band.
> 5. Close half of position when it moves by amount risked; move stop on rest to initial entry price (breakeven).
> 6. Close remainder of position at two times risk or trail the stop."

Worked example, PDF pp. 104-105 (EURUSD Short):

> "A two-lot trade is established at 1.1313 with a stop 30 pips above the first standard deviation Bollinger Band (1.1341) at 1.1371. The risk is 58 pips, which means that the first exit is 1.1313 minus 58 pips or 1.1255. The second profit target is 1.1197, which is two times risk or 116 pips. The first and second profit targets are reached on the very next day when the currency pair drops to a low of 1.1119, for a profit of 58 pips on the first half of the position and another 116 pips on the second half."

Worked example, PDF p. 105 (EURUSD Long):

> "A two-lot trade is established at 1.1151, with a stop 30 pips below the first standard deviation Bollinger Band (1.0970) at 1.0940. The risk is 211 pips, which means that the first exit is 1.1151 plus 211 pips, or 1.1361. This profit target is reached two days later, when the currency pair races to a high of 1.1380."

> N.B.: The Long-example "30 pips below" contradicts the rule list's "50 pips below" — Lien's worked example uses 30 pips, not 50. Card preserves the rule-list value (50 pips) as the default and exposes both as P3 sweep axis. The discrepancy is a source-text inconsistency, NOT a card error.

Regime classification, PDF p. 107:

> "When the pair is trading between the two lower or upper Bollinger Bands, it is in trend, and when it is trading between the first standard deviation Bollinger Bands, it is in range. ... When the currency pair is in trend mode, it is best to look for opportunities to join the trend. When it is in the range zone, picking tops and bottoms is preferred."

**Lien provides NO numeric performance claim** (no win-rate, profit-factor, max-drawdown, or annualized-return figure) for this strategy on its own — only the worked-example pip P&L on individual trades cited above. Per BASIS rule, no extrapolated performance number is asserted in this card; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.2                              # rough estimate; daily-bar BB-band MR with TP1=1R+BE / TP2=2R structure typically 1.0-1.4 PF range
expected_dd_pct: 18                           # rough estimate; D1 single-symbol MR strategies typically 12-25% DD in V4 archive
expected_trade_frequency: 25-50/year/symbol   # rough estimate; Lien's regime split (range mode only) reduces signal frequency vs an unconditional band MR
risk_class: medium                            # daily-bar single-symbol MR; not scalping, not gridding
gridding: false
scalping: false                               # D1 bars; not scalping
ml_required: false                            # threshold + pip arithmetic; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (Bollinger-band crossing + dwell-zone precondition; deterministic NY-close fill)
- [x] No Machine Learning required
- [x] If gridding: not applicable (one open position per direction)
- [x] If scalping: not applicable (D1 bars)
- [x] Friday Close compatibility: typical hold 1-6 sessions; V5 default Friday-close applies cleanly. No waiver required.
- [x] Source citation is precise enough to reproduce (PDF pp. 103-104 rule lists + pp. 104-105 worked examples + p. 107 regime framing; verbatim quotes preserved)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/`: SRC02 chan-bollinger-es uses ±2σ ES E-mini band MR — DIFFERENT mechanic: chan-bollinger-es triggers on band CROSS OUT, S02a triggers on band CROSS BACK IN after outer-zone dwell; chan is M5 ES futures, S02a is D1 forex)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "standard V5 default (kill-switch, news filter, MAX_DD trip, Friday-close); regime gate at S02b co-regime-fire suppression; optional ADX<25 range-regime filter (Lien Ch 7) as P3 sweep axis"
  trade_entry:
    used: true
    notes: "close back across inner-σ Bollinger band after multi-bar dwell in outer-band zone; NY-close (5pm) fill; long/short symmetric"
  trade_management:
    used: true
    notes: "TP1 = 1R partial close + move-rest-to-BE; TP2 = 2R fixed OR moving-average / percentage trail (P3 sweep axis)"
  trade_close:
    used: true
    notes: "exit on TP2 hit OR trail-fired OR initial stop (BE after TP1)"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # NOT load-bearing — typical 1-6 session hold; default V5 Friday-close applies cleanly. Listed for CTO completeness.
  - enhancement_doctrine                      # load-bearing on stop-pips asymmetry (50 long / 30 short); Lien's rule list is verbatim asymmetric but worked-example uses 30 for both. P3 sweep tests symmetric variants. Any post-PASS retune of stop-pips is enhancement_doctrine.
  - news_pause_default                        # standard V5 P8 news-blackout applies; Lien does not address news explicitly for this strategy.

at_risk_explanation: |
  friday_close — Daily-bar strategy with typical 1-6 session hold; weekend-gap risk
  rarely binds. Default V5 Friday-close applies cleanly. No waiver requested.

  enhancement_doctrine — Lien's verbatim rule list specifies 50-pip stop for longs and
  30-pip stop for shorts (PDF pp. 103-104), but her worked example uses 30 pips for the
  long EURUSD trade (PDF p. 105). This source-text inconsistency is preserved as a P3
  sweep axis (`stop_pip_unification ∈ {asymmetric, symmetric_avg, symmetric_at_50,
  symmetric_at_30}`). Once a live value is fixed at deployment, any subsequent retune
  is enhancement_doctrine.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Lien
  Ch 9 does not address news explicitly for this strategy; standard framework gating
  handles it.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + S02b co-regime-fire suppression
  entry: TBD                                  # BB(20, 1) + BB(20, 2) — close-cross-back-across with multi-bar zone-dwell precondition; NY 5pm fill; ~80-150 LOC in MQL5
  management: TBD                             # 50% partial close at 1R + move-rest-to-BE; 2R fixed exit OR MA/percentage trail (P3 sweep)
  close: TBD                                  # standard SL/TP plus optional trail
estimated_complexity: small                   # straightforward BB indicator + close-back-across trigger + standard partial/trail TM
estimated_test_runtime: 2-4h                  # P3 sweep ≈ 5×4×4×5×6×6×5×4 ≈ 28,800 cells; D1 bars; 10+ years; FX cohort — moderate
data_requirements: standard                   # D1 OHLC on Darwinex .DWX FX symbols; no external feeds
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
- 2026-04-28: SRC04_S02a surfaces a NEW `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `bband-reclaim` — entry mechanism: close back across N·σ Bollinger band after a multi-bar dwell on the
  OUTER side of the band (price was between Nσ and 2Nσ outer envelope, then closes back across the
  Nσ band). Distinct from `zscore-band-reversion` (which triggers entry when price crosses OUT of a
  ±N·σ band — opposite direction and opposite mechanic; reclaim triggers on the RETURN INTO the
  inner zone). Distinct from `n-period-min-reversion` (which uses N-bar minimum-extreme as the trigger,
  not a moving-stdev band). V4 had no equivalent SM_XXX EA per `strategy_type_flags.md` Mining-
  provenance table — Bollinger-Band-band-reclaim was net-new with SRC04 Lien Ch 9.
  Per-card precondition disambiguation (Card-level parameter `precondition_mode`):
    - `outer-band-zone` (S02a — range-bound between 1st-σ and 2nd-σ bands; this card)
    - `n-bars-opposite-1sigma` (S02b — n consecutive bars on opposite side of 1st-σ band; sibling card)
  Research will batch-propose this gap with subsequent SRC04 vocabulary findings at SRC04 closeout
  per process 13 § Exits + DL-033 Rule 1.

- 2026-04-28: Lien's source-text inconsistency on the long-side stop distance (rule list: 50 pips;
  worked example: 30 pips) is preserved as a P3 sweep axis (`stop_pip_unification`). Per BASIS rule,
  the card cites both verbatim and lets the parameter sweep pick the empirically-best variant.

- 2026-04-28: Lien provides NO numeric performance claim for this strategy on its own — only
  pip-P&L on the worked examples (EURUSD Short: 58/116 pips; EURUSD Long: 211/n.a. pips with BE
  hit on second half). Per BASIS rule, no extrapolated number is asserted; § 9 cites only what
  the source verbatim quotes. Pipeline P2-P9 produce the actual edge measurement.

- 2026-04-28: The S02a/S02b co-regime-fire suppression is novel for V5 — Lien explicitly defines
  the regime split (PDF p. 107 "trending vs range") such that S02a is the RANGE-mode card and
  S02b is the TREND-JOIN card. Both can technically fire on the same bar if precondition windows
  overlap; § 6 documents the conflict-resolver. CTO sanity-check at G0 + IMPL.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol forex, daily bars, no
  multi-leg / multi-stock / cointegration architecture concerns. Cleanest architecture-fit so far
  in SRC04 family. Expected G0 yield CLEAN.
```
