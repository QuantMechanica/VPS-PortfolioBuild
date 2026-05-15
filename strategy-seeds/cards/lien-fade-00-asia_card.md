# Strategy Card — Lien Fade Double Zeros (corrected v2: Asian-session-only + ADX ranging-regime gate)

> Drafted by Research Agent on 2026-05-15 from `strategy-seeds/sources/SRC04/raw/ch08-12_technical.txt` lines 451-555 (Lien Ch 10 § "Fading the Double Zeros" rule list + Market Conditions + Further Optimization + worked examples).
> Corrected-parametrization sibling of `lien-fade-double-zeros_card.md` (SRC04_S03, QM5_SRC04_S03) per [QUA-1564](/QUA/issues/QUA-1564) and the 2026-05-15 P2 zero-pass lessons-learned doc `lessons-learned/2026-05-15_p2_zero_pass_eas_dropped.md`. The original SRC04_S03 was a 24-hour session-agnostic deployment that returned 1 FAIL / 0 INVALID at P2 (the cleanest of the four 0-PASS failures); this v2 narrows trading to the Asian session (00:00–04:00 GMT) and adds an ADX(14)<20 ranging-regime gate, both targeting the documented Lien "Market Conditions" passage that says the strategy "works best when the move happens in quieter market conditions" (PDF p. 113).

## Card Header

```yaml
strategy_id: SRC04_S18
ea_id: TBD
slug: lien-fade-00-asia
status: DRAFT
created: 2026-05-15
created_by: Research
last_updated: 2026-05-15

strategy_type_flags:
  - round-num-fade                              # SRC04 batch-ratified flag (CEO 2026-04-28 QUA-333 closeout)
  - trend-filter-ma                             # Lien rule 1: 20-MA position filter
  - atr-hard-stop
  - symmetric-long-short
  - friday-close-flatten
  - intraday-session-pattern                    # SRC04 batch-ratified flag; new in this v2 to express session-window gating
  - adx-range-mr-gate                           # proposed; expresses "ADX<20 ranging-regime entry-only" gating
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Lien, Kathy (3rd ed., 2015). Day Trading and Swing Trading the Currency Market: Technical and Fundamental Strategies to Profit from Market Moves. Wiley Trading. Hoboken, NJ: John Wiley & Sons. ISBN 9781119108412 (paperback) / 9781119220107 (ePDF) / 9781119220091 (ePub)."
    location: "Chapter 10 'Technical Trading Strategy: Fading the Double Zeros' (PDF pp. 111-115) including § 'Strategy Rules' (PDF pp. 112-113), § 'Market Conditions' (PDF p. 113: 'This strategy works best when the move happens in quieter market conditions without the influence of major reports'), § 'Further Optimization' (PDF p. 113), worked examples Fig 10.1/10.2/10.3 (PDF pp. 113-115)."
    quality_tier: A
    role: primary
```

Same primary source as SRC04_S03. v2 corrections operationalize Lien's verbatim "quieter market conditions" Market-Conditions passage into two explicit numeric gates: session-window restriction and ADX ranging-regime gate.

## 2. Concept

A **round-number psychological-level fade** that goes long 10-15 pips above the nearest round number (counter-trend below the 20MA) and short 10-15 pips below the nearest round number (counter-trend above the 20MA), restricted to the Asian session (00:00–04:00 GMT) when London and New York are closed and intraday FX flow is dominated by Asia-Pacific cross-deals rather than directional macro positioning. An ADX(14)<20 gate further restricts entries to ranging regimes — the inefficiency Lien claims (dealer stop-gunning around round numbers, then reversal) is structurally a range-bound phenomenon; in trending sessions the round-number "break" tends to be a real break, not a stop-gun.

**Why this corrects the original failure mode.** SRC04_S03 / QM5_SRC04_S03 returned 0 PASS / 1 FAIL / 0 INVALID at P2 on 2026-05-15. Lessons-learned doc: "single FAIL with zero INVALID is the cleanest of the four; if re-attempted, focus on the entry/exit logic rather than data plumbing." This v2 keeps the data plumbing (M15 EURUSD-class FX-major) unchanged and adds two entry filters Lien herself prescribes in her "Market Conditions" passage but the original card left as P3 sweep axes only. The session-window gate suppresses London-NY-overlap signals (which are dominated by macro flow, not dealer stop-gunning). The ADX gate suppresses trending-regime signals (where round-number breaks are real, not stop-guns).

## 3. Markets & Timeframes

```yaml
markets:
  - forex
timeframes:
  - M15                                         # Lien-specified bar size
primary_target_symbols:
  - EURUSD.DWX                                  # primary; Asia-session liquidity adequate for EURUSD
  - USDJPY.DWX                                  # CSR candidate at P3.5; Asia-session is USDJPY's "home" session, highest liquidity match
  - AUDUSD.DWX                                  # CSR candidate at P3.5; AUD is an Asia-Pacific-time-zone currency, naturally aligned
session_window: "Asian session 00:00-04:00 GMT (broker-time equivalent)"
```

**Session-window choice rationale.** Lien Ch 10 § "Market Conditions" (PDF p. 113) prefers "quieter market conditions." The London open (~07:00 GMT) and NY open (~13:00 GMT) are loudest; the Asia-session 00:00–04:00 GMT window is the quietest mid-week intraday block on FX-majors and is when Lien's stop-gun thesis is most plausible (Tokyo dealer flow rather than algorithmic-macro London/NY flow).

## 4. Entry Rules

```text
PARAMETERS:
- BAR                = M15
- TREND_MA_PERIOD    = 20                       // Lien: "intraday 20-period simple moving average"
- ENTRY_OFFSET_PIPS  = 12                       // Lien: "10 to 15 pips above the figure" — midpoint
- STOP_OFFSET_PIPS   = 20                       // Lien: "20 pips below the figure"
- ROUND_NUMBER_GRID  = double_zero              // nearest x.xx00 (non-JPY) or xxx.00 (JPY) level
- PROXIMITY_PIPS     = 50                       // max distance from current price to staged round number
- ADX_PERIOD         = 14                       // ranging-regime gate parameter
- ADX_MAX            = 20                       // entries only when ADX(14) < 20 (ranging regime)
- SESSION_START_GMT  = 00:00                    // Asia-session start
- SESSION_END_GMT    = 04:00                    // Asia-session end (latest entry; existing positions exit normally)

EACH-BAR (M15 close, only during 00:00-04:00 GMT):

REGIME GATE 1 — session window:
- if current_gmt_time NOT in [SESSION_START_GMT, SESSION_END_GMT]: SKIP_ENTRY this bar

REGIME GATE 2 — ranging regime:
- adx_now = ADX(14)
- if adx_now >= ADX_MAX: SKIP_ENTRY this bar

PRECOMPUTE:
- ma_20         = SMA(close, TREND_MA_PERIOD)
- nearest_round = round_to_grid(close, ROUND_NUMBER_GRID)
- dist_to_round = nearest_round - close

LONG ENTRY (counter-trend fade BELOW MA, anticipate stop-gun + reversal at round number):
- precondition: close < ma_20
- staging:      nearest_round > close AND (nearest_round - close) <= PROXIMITY_PIPS
- stop-buy:     nearest_round + ENTRY_OFFSET_PIPS
- on fill: initial stop at nearest_round - STOP_OFFSET_PIPS  (risk ≈ 30-35 pips)

SHORT ENTRY (mirror — counter-trend fade ABOVE MA):
- precondition: close > ma_20
- staging:      nearest_round < close AND (close - nearest_round) <= PROXIMITY_PIPS
- stop-sell:    nearest_round - ENTRY_OFFSET_PIPS
- on fill: initial stop at nearest_round + STOP_OFFSET_PIPS  (risk ≈ 30-35 pips)
```

## 5. Exit Rules

```text
PARAMETERS:
- TP1_RR             = 1.0                      // Lien: "When the position is profitable by the amount risked"
- TRAIL_AFTER_TP1    = "BE"                     // Lien: "move your stop on the remaining portion to breakeven"
- TRAIL_METHOD       = two_bar_low              // Lien USDJPY worked example, PDF p. 114
- TIME_STOP_BARS     = 16                       // exit after 16 M15 bars (= 4 hours) if neither TP1 nor stop has fired
                                                // — bounds intraday hold to the Asian session itself

EACH-BAR (in position):
- HARD STOP — fires at initial stop price
- TP1 (close half + BE move):
    if abs(price - entry) >= 1 * initial_stop_distance:
      CLOSE_HALF
      move_remaining_stop to entry price
- TRAIL on remaining: 2-bar-low (long) / 2-bar-high (short)
- TIME-STOP: close after TIME_STOP_BARS M15 bars in position
- FRIDAY-CLOSE: force flat at Friday 21:00 broker time per V5 default
```

## 6. Filters (No-Trade module)

```text
- Asian-session window 00:00-04:00 GMT — strategy-specific (v2 addition).
- ADX(14) < 20 ranging-regime gate — strategy-specific (v2 addition).
- Framework defaults (V5):
  - QM_NewsFilter — ON. Pre-news ±30min default applies.
  - Friday Close — ON.
  - Kill-switch — ON.
```

## 7. Trade Management Rules

```text
- One open position per direction at any time.
- TP1 50% close + BE move: hard rule.
- Trail on remainder: 2-bar-low/high default.
- Time-stop after 16 M15 bars (4h).
- Friday-close forced flat per V5 default.
- Pyramiding: NOT used.
- Gridding:   NOT used.
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: TREND_MA_PERIOD
  default: 20
  sweep_range: [10, 14, 20, 26, 34]
- name: ENTRY_OFFSET_PIPS
  default: 12
  sweep_range: [8, 10, 12, 15, 20]
- name: STOP_OFFSET_PIPS
  default: 20
  sweep_range: [10, 15, 20, 25, 30]
- name: PROXIMITY_PIPS
  default: 50
  sweep_range: [25, 50, 100]
- name: ADX_MAX
  default: 20
  sweep_range: [15, 18, 20, 25]
- name: SESSION_START_GMT
  default: 00:00
  sweep_range: ["00:00", "22:00", "23:00"]
- name: SESSION_END_GMT
  default: 04:00
  sweep_range: ["03:00", "04:00", "05:00", "06:00"]
- name: TIME_STOP_BARS
  default: 16
  sweep_range: [8, 12, 16, 24]
- name: TRAIL_METHOD
  default: two_bar_low
  sweep_range: [two_bar_low, ma20_plus_10, atr2_trail]
```

Symbol pinned to EURUSD.DWX; P3.5 CSR sweeps USDJPY.DWX, AUDUSD.DWX.

## 9. Author Claims (verbatim, with quote marks)

```text
"After noticing how many times a currency pair would bounce off double zero support or resistance
levels intraday despite the underlying trend, we have observed that these bounces are usually much
larger and more relevant that rallies off other price levels." (Lien 2015, Ch 10, PDF p. 112)

"Market participants as a whole tend to put conditional orders near or around the same levels.
While stop-loss orders are usually placed just beyond the round numbers, traders will cluster their
take profit orders at the round number. ... Large banks with access to conditional order flow,
like stops and limits, actively seek to exploit this clustering of positions to basically gun stops.
The fading the double zero strategy attempts to put traders on the same side as market makers by
positioning traders for a quick contra-trend move at the double zero level." (Lien 2015, Ch 10, PDF p. 112)

"This strategy works best when the move happens in quieter market conditions without the influence
of major reports. It is more successful for currency pairs with tighter trading ranges, crosses,
and commodity currencies." (Lien 2015, Ch 10, PDF p. 113)
```

Author-claim band: `author-claimed` per `processes/qb_reputable_source_criteria.md` § 5. Lien gives per-trade pip P&L on 3 worked examples but no aggregate backtest or annualized return claim.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; range-bound fades historically modest PF
expected_dd_pct: 12
expected_trade_frequency: ~20-40/year on EURUSD M15   # Asia-session + ADX<20 gates are highly selective; lower than 24h variant
risk_class: medium
gridding: false
scalping: false                               # M15 with ~35-pip stops; not scalping by V5 definition
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical — entry is round-number-grid + offset + MA-position + session-time + ADX threshold; all numeric.
- [x] No Machine Learning required.
- [x] Gridding: N/A.
- [x] Scalping: N/A (M15, ~35-pip stops, ≤ ~3-4 trades per week expected).
- [x] Friday Close compatibility — v2 enforces Friday-close at 21:00; intraday strategy with 4h time-stop closes well before.
- [x] Source citation precise (book + ISBN + chapter + page numbers + worked-example figure references).
- [x] No near-duplicate of existing approved card. SRC04_S03 (lien-fade-double-zeros) is 24h session-agnostic; this v2 is Asia-session-only with ADX gate. Distinct strategy_id; distinct filter stack; distinct expected trade frequency.

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "Asian-session window (00:00-04:00 GMT) + ADX(14)<20 ranging-regime gate."
  trade_entry:
    used: true
    notes: "Stop-order entry at round-number + offset, MA-position counter-trend filter."
  trade_management:
    used: true
    notes: "20-pip-anchored hard stop; TP1 = 1R close 50% + BE move on rest; 2-bar-low/high trail."
  trade_close:
    used: true
    notes: "16-bar (4h) time-stop; Friday-close at 21:00 broker time."
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                      # EURUSD.DWX primary; CSR adds USDJPY.DWX, AUDUSD.DWX
  - enhancement_doctrine                       # ENTRY_OFFSET_PIPS, STOP_OFFSET_PIPS, ADX_MAX, session window, TIME_STOP_BARS all P3-sweepable
  - one_position_per_magic_symbol              # explicit single-position-at-a-time
  - news_pause_default                         # Asia-session has lower news density but RBA/BOJ releases possible; framework default applies
at_risk_explanation: |
  - dwx_suffix_discipline: all candidate symbols .DWX-native.
  - enhancement_doctrine: P3 may move ADX_MAX, session window, time-stop substantially; CTO snapshots
    the post-P3 set as the production parameter block.
  - one_position_per_magic_symbol: stop-orders staged at round-number ± offset are pending until filled;
    if filled, no new entries until exit. EA implementation must use single-pending-order semantics.
  - news_pause_default: Asia session has BOJ / RBA / RBNZ / PBOC releases; framework pre-news ±30min
    pause applies. Lien's "quieter conditions" preference (PDF p. 113) is partially addressed by
    Asia-session pick; news-pause picks up the rest.
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
| _v1 | 2026-05-15 | initial build (v2 of SRC04_S03 theme; new SRC ID SRC04_S18) | TBD | TBD |

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
- 2026-05-15: Authored as corrected-parametrization v2 of SRC04_S03 (lien-fade-double-zeros /
  QM5_SRC04_S03) which returned 0 PASS / 1 FAIL / 0 INVALID at P2 on 2026-05-15. The lessons-
  learned doc identifies this as the cleanest of the four 0-PASS failures and recommends "focus
  on the entry/exit logic rather than data plumbing." Corrections vs original:
    (1) Asian-session-only entry window (00:00-04:00 GMT) — Lien's "quieter market conditions"
        preference operationalized as a hard time-gate.
    (2) ADX(14)<20 ranging-regime entry gate — Lien's stop-gun thesis is range-bound by
        construction; trending regimes break round numbers for real, not as a stop-gun.
    (3) 16-bar (4h) time-stop — bounds hold to the Asian session itself, prevents drift into
        London-NY trending regimes.
    (4) Friday-close at 21:00 broker time explicitly enforced.
    (5) Symbol pinned EURUSD.DWX primary; CSR sweep USDJPY.DWX, AUDUSD.DWX at P3.5.
  Strategy mechanic (round-number fade with counter-trend MA filter) and primary source
  (Lien 2015 Ch 10) unchanged. The two new gates (session, ADX) are both verbatim-justified
  by Lien's "Market Conditions" passage that the original card recorded but did not enforce
  as hard gates.
```
