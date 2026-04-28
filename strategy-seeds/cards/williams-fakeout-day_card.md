# Strategy Card — Williams Fake Out Day (close-against-direction reversal with stop entry at prior bar's extreme)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams Failure-Day-Family § "FAKE OUT DAY", PDF p. 19).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S08
ea_id: TBD
slug: williams-fakeout-day
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - rejection-bar-stop-entry                  # canonical match — entry: candle-shape rejection bar (Fakeout variant: close-vs-prior-extreme — close back inside prior range after intraday extension beyond) → stop-entry at the OPPOSITE extreme. Same family as S07 Smash Day with a different sub-pattern. CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - atr-hard-stop                             # Williams: $1,500-equivalent generic dollar stop after entry
  - symmetric-long-short                      # Williams names BOTH directions verbatim (PDF p. 19): bullish fakeout → buy at prior day high; bearish fakeout → sell at prior day low
  - friday-close-flatten                      # V5 default; 3-bar trail spec centralized at framework/V5_TM_MODULES.md § TM-3BAR-TRAIL.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 19 (Inner Circle Workshop companion volume), § 'THE FAILURE DAY FAMILY — FAKE OUT DAY'. Sister-pattern context: same § lists SMASH DAY (S07; close-vs-open rejection variant), NAKED CLOSE DAYS (S09 — same page), SPECIALISTS TRAP (S10 — same page). Exit-rule cross-reference: PDF pp. 20-21 § 'WHEN TO EXIT' (4-option menu)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 210-212 (Fake Out Day verbatim), lines 205-217 (Failure-Day-Family framing). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **single-bar close-direction-failure reversal entry**. A "Fake Out Day" bullish setup is a daily bar that prints a higher high AND higher low than the prior bar (looks bullish on extremes) BUT closes BELOW the prior bar's close (close-side failure). Williams' thesis: the bar's day-traders pushed the extremes higher in apparent continuation but the bar's close revealed the rally was unsupported — taking out the PRIOR DAY'S high is the contrarian entry, signaling that a fresh rally now overrides the failed-rally bar.

Williams' verbatim framing, PDF p. 19:

> "FAKE OUT DAY — Here we have a higher high, higher low and lower close than the prior [d]ay for a buy. The sell is just the opposite, a lower -high and low with a higher close. Buy/Sell at the prior days high/low."

Williams positions Fake Out as the parent of the Failure-Day-Family (PDF p. 19 prelude); Smash Day (S07) is described as "a bit like a fakeout day" but with the close-vs-open rejection condition layered on. The Naked Close (S09) and Specialist Trap (S10) are described in the same § as cousin patterns. Per DL-033 Rule 1, this card extracts Fake Out specifically — the setup is mechanically distinct from S07 Smash Day (different close-condition reference: prior CLOSE vs same-bar OPEN) and from S09 Naked Close (different entry reference: prior bar's HIGH vs same-bar HIGH).

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                             # generic — Williams' Failure-Day-Family discussion is multi-market. V5 proxies: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
  - bond_futures                              # generic
  - commodities                               # generic
  - forex                                     # generic; V5 proxy: spot Darwinex .DWX FX symbols
timeframes:
  - D1                                        # Williams: rules stated on daily bars
  - H4                                        # H4 ablation in P3 sweep — bar-shape patterns transfer plausibly
session_window: not specified
primary_target_symbols:
  - "all major Darwinex .DWX index/metal/FX symbols (Williams: pattern is generic across markets)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF p. 19 § "FAKE OUT DAY".

```text
PARAMETERS:
- BAR               = D1
- OFFSET_TICKS      = 0           // entry trigger at prior bar's high/low; 0-tick offset
- USE_TRUE_EXTREMES = false       // Williams says "prior days high/low" — plain high/low, NOT true high/low.
                                  //   Sweep axis variant.

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- bullish_fakeout_setup at bar t-1:
    High[t-1]   > High[t-2]                   # higher high
    Low[t-1]    > Low[t-2]                    # higher low
    Close[t-1]  < Close[t-2]                  # LOWER close vs prior bar — the "fake out" component
- bearish_fakeout_setup at bar t-1:
    High[t-1]   < High[t-2]                   # lower high
    Low[t-1]    < Low[t-2]                    # lower low
    Close[t-1]  > Close[t-2]                  # HIGHER close vs prior bar

ENTRY (only when not in position; orders staged at session start):
- if bullish_fakeout_setup at t-1:
    stage stop-buy at High[t-2] + OFFSET_TICKS    # prior day's HIGH (i.e., bar t-2's high)
    if intra-day High[t] >= High[t-2]: FILL_LONG at High[t-2]
- if bearish_fakeout_setup at t-1:
    stage stop-sell at Low[t-2] - OFFSET_TICKS    # prior day's LOW (i.e., bar t-2's low)
    if intra-day Low[t] <= Low[t-2]: FILL_SHORT at Low[t-2]
- single-attempt-per-day: order cancelled at session close if not filled
```

**Reference-price disambiguation** (load-bearing): Williams says "Buy/Sell at the prior days high/low" — meaning at the high/low of the day BEFORE the fakeout bar (i.e., bar t-2 in the indexing above), NOT at the fakeout bar's high. This is what distinguishes Fake Out from Smash Day (which fires at THE SMASH BAR's high) and from Naked Close (which fires at THE NAKED CLOSE BAR's high). The mechanical distinction is real even though the qualitative framing is similar across patterns.

## 5. Exit Rules

Williams' standard exit menu (PDF pp. 20-21) applies; default is dollar-stop + 3-bar trail combo (consistent with S07 Smash Day per the same Failure-Day-Family thesis).

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout, comment `cc655c56`; back-port QUA-334). The pseudocode below is retained inline for self-contained card review and matches the canonical TM-module spec.

```text
DEFAULT EXIT:
- HARD_STOP_USD     = 1500       // V5 → ATR-equivalent
- TRAIL_BARS        = 3          // Williams' "Amazing 3 Bar Entry/Exit" PDF p. 21
- TRAIL_NO_INSIDE   = true
- TRAIL_ACTIVATE    = first_close_in_profit
- TIME_STOP         = 10 bars    // backstop

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- TRAIL — identical 3-bar non-inside-day true-low/true-high trail as S07
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies; 5-10 day typical hold; rarely binds.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed
- gridding: NOT allowed
- Setup-bar gating: only fires when bar t-1 satisfies the fakeout pattern per § 4
- Trend-agreement filter (OPTIONAL P3 sweep axis): suppress counter-trend signals against
  longer-term trend — Williams does NOT cite for Fake Out specifically; ablation only
- Outside-day-exclusion (OPTIONAL): ablation variant
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding)
- single-attempt-per-day: stop-buy / stop-sell order valid only for trigger-day; cancel at close
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: use_true_extremes
  default: false                              # Williams says "high/low" not "true high/low"
  sweep_range: [false, true]
- name: entry_offset_ticks
  default: 0
  sweep_range: [0, 1, 2, 5]
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
  sweep_range: [D1, H4]
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. Same multi-market generalization profile as S07 Smash Day. Setup-density at D1 is moderate (≈ 8-20 setups/year/symbol — fakeouts are more common than smash bars since the close-side failure condition is broader than the body-rejection condition).

## 9. Author Claims (verbatim, with quote marks)

Fake Out Day pattern, PDF p. 19:

> "FAKE OUT DAY — Here we have a higher high, higher low and lower close than the prior [d]ay for a buy. The sell is just the opposite, a lower -high and low with a higher close. Buy/Sell at the prior days high/low."

Failure-Day-Family thesis prelude (cross-referenced from S07), PDF p. 19:

> "The market loves to catch people by surprise. Never forget that statement. The following patterns can be used to enter the market taking advantage of what looks like a strong market move. The underlying truth of these patterns is that the day after the pattern prices do exactly the opposite [of] what 'the crowd' was expecting."

**Williams provides NO numeric performance claim for Fake Out Day specifically.** No backtest table is associated with this pattern in the source's text-clean range (PDF pp. 1-46). Per BASIS rule, no extrapolated number is asserted; pipeline P2-P9 produce actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.1                              # rough estimate; bar-pattern reversal entries with simple stop-trigger typically PF 0.9-1.3 in V4 archive
expected_dd_pct: 18                           # rough estimate; D1 reversal entries with 3-bar trail and ~5-10 day max hold
expected_trade_frequency: 8-20/year/symbol    # rough estimate; fakeout setups more frequent than smash bars
risk_class: medium                            # bar-pattern reversal entries are counter-trend; intrinsic counter-trend risk class
gridding: false
scalping: false                               # D1
ml_required: false                            # threshold + bar-shape arithmetic
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (3-condition bar-shape check + stop-buy/sell at fixed reference price)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable
- [x] Friday Close compatibility: 5-10 day typical hold; default V5 applies
- [x] Source citation is precise enough to reproduce (PDF p. 19 verbatim; no quantification gaps unlike S07 — the higher-H/lower-L/lower-C conditions are unambiguous)
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "fakeout setup conditions + standard V5 default; optional trend-agreement and outside-day filters as P3 sweep axes"
  trade_entry:
    used: true
    notes: "stop-buy at prior day's high (long) / stop-sell at prior day's low (short); single-attempt-per-day; one position per direction"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "3-bar non-inside-day trail (default) or alt-exit per P3 sweep; ATR-equivalent hard stop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Williams' pattern is generic across markets; CSR P3.5 validates breadth across .DWX symbols
  - friday_close                              # NOT load-bearing; default V5 applies
  - news_pause_default                        # standard V5 P8 news-blackout applies
  - one_position_per_magic_symbol             # NOT load-bearing — single position per direction

at_risk_explanation: |
  dwx_suffix_discipline — Pattern is candle-shape generic; CSR P3.5 runs the pattern across the
  full index/metal/FX/energy cohort to validate breadth.

  friday_close / news_pause_default / one_position_per_magic_symbol — standard handling per
  V5 framework; no card-specific waivers required.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # bar-shape evaluation at prior-bar close; stop-buy/sell at session start; ~70-100 LOC in MQL5
  management: TBD
  close: TBD
estimated_complexity: small
estimated_test_runtime: 1-3h                  # P3 sweep cell count moderate (2×4×4×5×3×2 = 960 cells); D1 bars; multi-market
data_requirements: standard
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
- 2026-04-28: SRC03_S08 reuses the SRC03_S07-proposed `rejection-bar-stop-entry` vocabulary-gap
  flag. Fake Out and Smash Day are SISTER patterns in Williams' Failure-Day-Family — both are
  bar-shape rejection patterns with stop-entry at a fixed reference price. The mechanical
  distinction:
    S07 Smash Day: close-vs-OPEN rejection (within-bar body) + stop-entry at THIS bar's high
    S08 Fake Out: close-vs-PRIOR-CLOSE failure + stop-entry at PRIOR bar's high
  Both fit `rejection-bar-stop-entry` per the proposed flag definition. No new gap surfaced.

- 2026-04-28: Williams provides NO numeric performance claim for Fake Out Day. § 9 cites only
  verbatim pattern description. Per BASIS rule, no extrapolated number asserted; pipeline P2-P9
  produces actual edge.

- 2026-04-28: Cards-vs-fold decision retained as DISTINCT (S07 vs S08): different reference
  prices for stop entry (THIS bar's H vs PRIOR bar's H) + different setup conditions (close-vs-
  OPEN body rejection vs close-vs-PRIOR-CLOSE direction failure). Per DL-033 Rule 1, distinct
  mechanical triggers warrant distinct cards even when the thesis (failed-bar reversal) is shared.

- 2026-04-28: Cards-vs-fold decision retained as DISTINCT (S08 vs S09 Naked Close): different
  setup-bar conditions and different entry-reference prices.
    S08 Fake Out: 3-condition bar-shape (HH + HL + LowerC) + entry at PRIOR bar's high
    S09 Naked Close: 1-condition (close < prior LOW) + entry at THIS bar's high
  Per DL-033 Rule 1, mechanically distinct.

- 2026-04-28: V5-architecture-fit profile is FAVOURABLE — single-symbol, daily bars; consistent
  with the SRC03 family pattern. Counter-trend reversal class adds direction-class diversity
  vs SRC03's heavily-trend-following S01 Vol-BO and the calendar-bias S04/S05/S06 family.
```
