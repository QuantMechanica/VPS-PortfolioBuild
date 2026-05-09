# Strategy Card — Williams Smash Day (price-rejection bar with stop entry at extreme; multi-market)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams Failure-Day-Family § "SMASH DAY", PDF p. 19).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S07
ea_id: TBD
slug: williams-smash-day
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - rejection-bar-stop-entry                  # canonical match — entry: candle-shape rejection bar (close substantially against open, vs prior bar trend) → stop-entry at the OPPOSITE extreme of the rejection bar (Smash variant: close-vs-open rejection). CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - atr-hard-stop                             # Williams: $1,500-equivalent hard stop after entry
  - symmetric-long-short                      # Williams names BOTH directions verbatim (PDF p. 19): bullish smash → buy at takeout of high; bearish smash → sell at low
  - friday-close-flatten                      # V5 default; Williams' typical exit menu (3-bar trail / 18-bar MA / channel break / dollar stop). 3-bar trail spec centralized at framework/V5_TM_MODULES.md § TM-3BAR-TRAIL.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 19 (Inner Circle Workshop companion volume), § 'THE FAILURE DAY FAMILY — SMASH DAY'. Sister-pattern context: same § lists FAKE OUT DAY (long-bias variant) and same page transitions to NAKED CLOSE DAYS / SPECIALISTS TRAP (related candle-shape patterns extracted as separate cards in SRC03 source.md § 6 slots S08 / S09 / S10). Exit-rule cross-reference: PDF pp. 20-21 § 'WHEN TO EXIT' (4-option menu)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 214-217 (Smash Day verbatim), lines 205-217 (Failure-Day-Family framing). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **single-bar candle-rejection-pattern reversal entry**. A "Smash Day" bullish setup is a daily bar that LOOKS bullish on conventional metrics — higher high, higher low, higher close than the prior day — BUT closes substantially BELOW its own opening (a wide-range reversal candle, body in the lower half of the bar). Williams' thesis: the bar's intra-session distribution shows that early buyers were OVERWHELMED by late-session sellers, and the rejection signals exhaustion. Despite the deceptive higher-close-than-yesterday, the FAILED-RALLY structure means the next session's takeout of THIS bar's HIGH would be a strong contrarian buy signal — the very buyers who pushed THIS bar higher then capitulated, and a fresh rally above the rejection-bar high signals genuine demand.

Williams' verbatim framing, PDF p. 19:

> "SMASH DAY — This is a bit like a fakeout day. The pattern to look for is a day with a higher high, low and higher close. BUT, the close is substantially below the open. Taking out this day[']s high is very bullish. The sell is just the opposite, a down close substantially above the open, with a sell at that day's low tomorrow."

The pattern ties into Williams' broader Failure-Day-Family framing (PDF p. 19, prelude):

> "The market loves to catch people by surprise. ... The following patterns can be used to enter the market taking advantage of what looks like a strong market move. The underlying truth of these patterns is that the day after the pattern prices do exactly the opposite [of] what 'the crowd' was expecting."

This card extracts the **Smash Day specifically**. The other Failure-Day-Family patterns (FAKEOUT DAY p. 19, NAKED CLOSE DAYS p. 19-20, SPECIALISTS TRAP p. 20) are mechanically distinct trigger configurations and live in their own sister cards (SRC03 source.md § 6 slots S08 / S09 / S10). Fold-vs-distinct decisions retained at DISTINCT — each pattern uses different bar-shape conditions and reference prices for its stop entry.

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                             # Williams' broader Failure-Day-Family discussion does not specify markets — pattern is presented as generic. V5 proxies: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
  - bond_futures                              # candle-shape patterns generic; V5 proxy: bond CFD if Darwinex offers
  - commodities                               # generic
  - forex                                     # generic; V5 proxy: spot Darwinex .DWX FX symbols
timeframes:
  - D1                                        # Williams: rules stated on daily bars
  - H4                                        # H4 ablation in P3 sweep — bar-shape patterns transfer plausibly to H4
session_window: not specified                 # daily-bar pattern; entry at next bar open mechanics
primary_target_symbols:
  - "all major Darwinex .DWX index/metal/FX symbols (Williams: pattern is generic across markets)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF p. 19 § "SMASH DAY".

```text
PARAMETERS:
- BODY_REJECTION_PCT = 50         // Williams: "close is substantially below the open" — quantification gap;
                                  //   default = body fills ≤ 50% of range (close in lower half for buy setup).
                                  //   Williams does NOT cite a specific %; sweep axis [33, 50, 67, 75].
- BAR                = D1
- OFFSET             = 0          // entry trigger placed AT bar's high (long) / low (short); 0-tick offset.
                                  //   "+ 1 tick" is a microstructure-defensive variant on P3 axis.

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- bullish_smash_setup at bar t-1:
    High[t-1]   > High[t-2]                   # higher high
    Low[t-1]    > Low[t-2]                    # higher low
    Close[t-1]  > Close[t-2]                  # higher close (vs prior bar)
    Close[t-1]  < Open[t-1]                   # close BELOW open (down-candle within the bar)
    body_in_lower_half(t-1)                   # quantification of "substantially below":
      ((Open[t-1] - Close[t-1]) / (High[t-1] - Low[t-1])) >= BODY_REJECTION_PCT/100
- bearish_smash_setup at bar t-1:
    Low[t-1]    < Low[t-2]                    # lower low
    High[t-1]   < High[t-2]                   # lower high
    Close[t-1]  < Close[t-2]                  # lower close (vs prior bar)
    Close[t-1]  > Open[t-1]                   # close ABOVE open (up-candle within the bar)
    body_in_upper_half(t-1)                   # quantification of "substantially above":
      ((Close[t-1] - Open[t-1]) / (High[t-1] - Low[t-1])) >= BODY_REJECTION_PCT/100

ENTRY (only when not in position; orders staged at session start):
- if bullish_smash_setup at t-1:
    stage stop-buy at High[t-1] + OFFSET_ticks
    if intra-day High[t] >= High[t-1]: FILL_LONG at High[t-1]
- if bearish_smash_setup at t-1:
    stage stop-sell at Low[t-1] - OFFSET_ticks
    if intra-day Low[t] <= Low[t-1]: FILL_SHORT at Low[t-1]
- single-attempt-per-day: order cancelled at session close if not filled
```

**Williams quantification gap.** "Substantially below the open" is the LOAD-BEARING qualitative term that distinguishes a Smash Day from any down-close-but-still-higher-than-yesterday bar. Williams does NOT cite a specific percentage; default `BODY_REJECTION_PCT = 50` is Research's structural translation per the verbatim qualifier ("substantially"). P3 sweeps [33, 50, 67, 75] to validate sensitivity.

## 5. Exit Rules

Williams' standard exit menu (PDF pp. 20-21 § "When to Exit") applies; default is the dollar-stop + 3-bar trail combo (consistent with Smash Day's reversal-thesis + Williams' card-specific framing on PDF p. 19 that ends "Taking out this day[']s high is very bullish" — implies multi-day continuation expected post-entry).

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout, comment `cc655c56`; back-port QUA-334). The pseudocode below is retained inline for self-contained card review and matches the canonical TM-module spec.

```text
DEFAULT EXIT:
- HARD_STOP_USD     = 1500       // Williams' generic dollar-stop; V5 → ATR-equivalent
- TRAIL_BARS        = 3          // Williams' "Amazing 3 Bar Entry/Exit Technique" PDF p. 21
- TRAIL_NO_INSIDE   = true       // Williams: "None of these can be an inside day"
- TRAIL_ACTIVATE    = first_close_in_profit
- TIME_STOP         = 10 bars    // backstop; Williams does not specify a time stop, but a
                                 //   smash-reversal that hasn't triggered the trail in 10
                                 //   sessions has likely failed the thesis; sweep axis

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- TRAIL: identical to S01 williams-vol-bo § 5 (3-bar non-inside-day true-low/true-high trail)
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies. Smash Day reversals typically resolve within 5-10
sessions — Friday-close occasionally binds; usually the trail or stop fires first. No
waiver required.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one open position per direction)
- gridding: NOT allowed
- BODY_REJECTION_PCT threshold (per § 4): only fires on bars where the body fills
  ≥ BODY_REJECTION_PCT% of the range in the rejection direction
- "trend agreement" filter (OPTIONAL P3 sweep axis):
  - Bullish smash + Close[t-1] > SMA(L) for some L (200 default): trade only when
    pattern aligns with longer-term uptrend
  - Mirror for bearish smash
  - Off by default (Williams does NOT cite a trend filter for Smash Day specifically)
- "outside day" exclusion (OPTIONAL): the smash-bar should not be an outside day relative
  to the day before — this is consistent with Failure-Day-Family thesis but not verbatim
  Williams; sweep axis variant
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
- single-attempt-per-day rule: stop-buy / stop-sell order valid for trigger-day only
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: body_rejection_pct
  default: 50                                 # Research structural translation of Williams' "substantially"
  sweep_range: [33, 40, 50, 60, 67, 75]       # bracket: 33% (lenient) to 75% (strict)
- name: prior_bar_check
  default: prior_bar_lower_high_low_close     # Williams' verbatim setup conditions
  sweep_range: [prior_bar_lower_high_low_close, prior_close_only, body_only_no_prior]
                                              # ablation: what happens if we drop the
                                              #   higher-high / higher-low / higher-close requirement?
- name: entry_offset_ticks
  default: 0                                  # at bar's extreme
  sweep_range: [0, 1, 2, 5]                   # microstructure-defensive variants
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: alt_exit
  default: trail_3bar
  sweep_range: [trail_3bar, ma18_cross, donchian20_break, time_stop_5bars, time_stop_10bars]
- name: trend_agreement_filter
  default: off
  sweep_range: [off, sma50, sma200]
- name: bar
  default: D1
  sweep_range: [D1, H4]                       # H4 ablation; pattern plausibly transfers
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. Williams' Smash Day is presented as a generic candle-shape pattern; CSR validates breadth across:
- Index CFDs: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
- Metals: GOLD.DWX, XAGUSD.DWX
- Spot FX: EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX, AUDUSD.DWX
- Energies: OIL.DWX, NATGAS.DWX (if Darwinex offers)

Pattern-density on D1 bars is moderate (≈ 5-15 setups/year/symbol). CSR results indicate whether the pattern is universal or asymmetrically effective on certain instrument classes.

## 9. Author Claims (verbatim, with quote marks)

Smash Day pattern, PDF p. 19:

> "SMASH DAY — This is a bit like a fakeout day. The pattern to look for is a day with a higher high, low and higher close. BUT, the close is substantially below the open. Taking out this day[']s high is very bullish. The sell is just the opposite, a down close substantially above the open, with a sell at that day's low tomorrow."

Failure-Day-Family thesis prelude, PDF p. 19:

> "The market loves to catch people by surprise. Never forget that statement. The following patterns can be used to enter the market taking advantage of what looks like a strong market move. The underlying truth of these patterns is that the day after the pattern prices do exactly the opposite [of] what 'the crowd' was expecting."

**Williams provides NO numeric performance claim for Smash Day specifically.** No backtest table is associated with this pattern in the source's text-clean range (PDF pp. 1-46). Per BASIS rule, no extrapolated performance number is asserted; pipeline P2-P9 produce the actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.1                              # rough estimate; bar-pattern reversal entries with simple stop-trigger typically PF 0.9-1.3 in V4 archive (no Williams-specific anchor)
expected_dd_pct: 18                           # rough estimate; D1 reversal entries with 3-bar trail and ~5-10 day max hold
expected_trade_frequency: 5-15/year/symbol    # rough estimate; setup-density depends on body_rejection_pct threshold
risk_class: medium                            # bar-pattern reversal entries are reversal-against-prior-trend; intrinsic counter-trend risk class
gridding: false
scalping: false                               # D1 trigger
ml_required: false                            # threshold + bar-shape arithmetic
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (bar-shape conditions + stop-buy/sell at fixed price)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable
- [x] Friday Close compatibility: 5-10 day typical hold; Friday-close occasionally binds but trail or stop usually fires first; no waiver required
- [x] Source citation is precise enough to reproduce (PDF p. 19 verbatim; Williams' "substantially" qualifier is the lone quantification gap, addressed in § 4 default + P3 sweep)
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "BODY_REJECTION_PCT threshold + standard V5 default; optional trend-agreement and outside-day-exclusion filters as sweep axes"
  trade_entry:
    used: true
    notes: "stop-buy at smash-bar's high (or stop-sell at smash-bar's low); single-attempt-per-day; one position per direction"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "3-bar non-inside-day trail (default), or alt-exit (18-bar MA / 20-bar Donchian / time-stop) per P3 sweep; ATR-equivalent hard stop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Williams' pattern is generic across markets; V5 maps to .DWX symbols. CSR P3.5 validates breadth.
  - friday_close                              # NOT load-bearing on typical hold; listed for completeness
  - enhancement_doctrine                      # load-bearing on BODY_REJECTION_PCT — Williams' "substantially" is qualitative; P3 sweeps quantification; once a live value is fixed at deployment, any subsequent retune is enhancement_doctrine
  - news_pause_default                        # standard V5 P8 news-blackout applies
  - one_position_per_magic_symbol             # NOT load-bearing — single position per direction; listed for explicit confirmation

at_risk_explanation: |
  dwx_suffix_discipline — Pattern is candle-shape generic; cross-symbol portability is the
  thesis. CSR P3.5 runs the pattern across the full index/metal/FX/energy cohort to validate
  breadth. CTO sanity-check at G0 maps Williams' generic framing to specific Darwinex symbols.

  friday_close — Default V5 applies. Typical 5-10 day hold rarely binds Friday-close.

  enhancement_doctrine — BODY_REJECTION_PCT is the load-bearing parameter and Williams provides
  no numeric value. Card defaults to 50% per Research structural translation of "substantially";
  P3 sweeps [33, 40, 50, 60, 67, 75]. Once deployment-live value is fixed, any subsequent retune
  is enhancement_doctrine.

  news_pause_default — V5 P8 news-blackout applies at high-impact macro events. Williams does
  not address this; standard framework gating handles it.

  one_position_per_magic_symbol — single position per direction at a time; pyramiding/stacking
  not used.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 + BODY_REJECTION_PCT threshold + optional filters
  entry: TBD                                  # bar-shape evaluation at prior-bar close; stop-buy/stop-sell at session start; ~80-120 LOC in MQL5
  management: TBD                             # n/a
  close: TBD                                  # 3-bar non-inside-day trail; alt-exit axes; ATR hard stop
estimated_complexity: small                   # straightforward bar-shape arithmetic
estimated_test_runtime: 2-4h                  # P3 sweep (6×3×4×4×5×3×2 ≈ 8,640 cells); D1 bars; multi-market
data_requirements: standard                   # D1 OHLC on Darwinex .DWX symbols
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
- 2026-04-28: SRC03_S07 surfaces a THIRD `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `rejection-bar-stop-entry` — entry mechanism: candle-shape rejection bar (close substantially
  against open while higher/lower than prior close) → stop-buy / stop-sell at the OPPOSITE
  extreme of the rejection bar. Distinct from `narrow-range-breakout` (NR4/NR7 contraction
  precondition; Smash Day requires WIDE-RANGE rejection bar). Distinct from `gap-fade-stop-entry`
  (S02 proposed flag — gap THROUGH a calendar-pattern reference price; Smash Day requires
  bar-internal close-vs-open rejection structure, no gap). V4 had no equivalent SM_XXX EA.
  Williams citation: PDF p. 19 (primary) + Failure-Day-Family family context.
  Together with SRC03_S01's `vol-expansion-breakout` and S02's `gap-fade-stop-entry`, the running
  SRC03 vocabulary-gap count is now THREE. Research will batch-propose to CEO + CTO via the
  addition-process documented at the bottom of `strategy_type_flags.md` once SRC03 extraction
  stabilizes (next 2-3 heartbeats).

- 2026-04-28: "Substantially below the open" is the LOAD-BEARING qualitative term and Williams
  does NOT quantify it. Default BODY_REJECTION_PCT = 50 (close-in-lower-half) is Research
  structural translation; P3 sweeps [33, 40, 50, 60, 67, 75] to validate sensitivity. Once a
  live value is fixed at deployment, any subsequent retune is `enhancement_doctrine`.

- 2026-04-28: Williams provides NO numeric performance claim for Smash Day on PDF pp. 1-46.
  No backtest table is associated with this pattern. Per BASIS rule, no extrapolated number is
  asserted; § 9 cites only the verbatim pattern description. Pipeline P2-P9 produce actual edge.

- 2026-04-28: Sister Failure-Day-Family patterns (FAKEOUT DAY, NAKED CLOSE DAYS, SPECIALISTS
  TRAP) are slotted as DISTINCT cards (SRC03 source.md § 6 slots S08, S09, S10). Fold-vs-distinct
  decision: each pattern uses different bar-shape conditions and reference prices for its stop
  entry — mechanically distinct triggers. Combined family-card consideration deferred unless P2/P3
  evidence shows that bar-shape patterns share a common edge profile.

- 2026-04-28: Symmetric long/short is verbatim Williams ("The sell is just the opposite, a down
  close substantially above the open, with a sell at that day's low tomorrow."). Unlike S02
  Monday OOPS! where the short side is V5 ablation, here both directions are source-verbatim.
  `symmetric-long-short` flag applies cleanly.
```
