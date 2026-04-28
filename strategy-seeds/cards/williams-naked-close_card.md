# Strategy Card — Williams Naked Close Days (close-outside-prior-bar reversal with stop entry at same-bar extreme)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` (verbatim Williams Failure-Day-Family § "NAKED CLOSE DAYS", PDF pp. 19-20; pattern attributed by Williams to Joe Stowell).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S09
ea_id: TBD
slug: williams-naked-close
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - rejection-bar-stop-entry                  # canonical match — entry: candle-shape rejection bar (Naked Close variant: close-outside-prior-range — close < prior low → buy at high; close > prior high → sell at low; attributed by Williams to Joe Stowell) → stop-entry at the OPPOSITE extreme. Same family as S07 Smash Day + S08 Fakeout with a different sub-pattern. CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - atr-hard-stop                             # generic dollar-stop V5 → ATR-equivalent
  - symmetric-long-short                      # Williams names BOTH directions verbatim (PDF pp. 19-20): close < prior low → buy at high; close > prior high → sell at low
  - friday-close-flatten                      # V5 default; 3-bar trail spec centralized at framework/V5_TM_MODULES.md § TM-3BAR-TRAIL.
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF pp. 19-20 (Inner Circle Workshop companion volume), § 'THE FAILURE DAY FAMILY — NAKED CLOSE DAYS'. Williams attributes the pattern name to Joe Stowell. Sister-pattern context: Failure-Day-Family § also lists FAKE OUT DAY (S08), SMASH DAY (S07), SPECIALISTS TRAP (S10). Exit-rule cross-reference: PDF pp. 20-21 § 'WHEN TO EXIT' (4-option menu)."
    quality_tier: A
    role: primary
  - type: attribution
    citation: "Stowell, Joe — 'Naked Close' is Stowell's coinage per Williams' verbatim attribution (PDF p. 19); no specific Stowell publication is cited. Listed as supplementary attribution; the operative source is Williams' verbatim text."
    location: "Williams credits Stowell for the term but provides the operative rule himself"
    quality_tier: B
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp15-30.txt` lines 220-222 (Naked Close Days verbatim). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **single-bar close-outside-prior-bar reversal entry**. A "Naked Close" bullish setup is a daily bar that closes BELOW the prior bar's LOW — an unambiguous downside-extension close. Williams' thesis: a close that "leaves the prior bar naked" (no body overlap with prior bar's range on the close-side) signals capitulation; the reversal is taking out the SAME bar's HIGH on the next session, where buyers reclaim the range and signal exhaustion-of-sellers.

Williams' verbatim framing, PDF pp. 19-20:

> "NAKED CLOSE DAYS — This is a nice term coined by Joe Stowell. It's easy to spot, a naked close 'buy set up' requires a close lower than yesterdays low, buy at the high of this down close. A 'sell set up' requires a close above yesterdays high, sell at the low of this up close."

The pattern is mechanically the simplest of the Failure-Day-Family — a single inequality on close vs prior-bar-low (or prior-bar-high). Per DL-033 Rule 1, this card extracts Naked Close specifically:

- Mechanical distinction from S07 Smash Day: Smash Day requires the close to be substantially BELOW the SAME BAR's open (within-bar body rejection); Naked Close requires the close to be below the PRIOR BAR's low (cross-bar gap-equivalent close). Different conditions, different reference frames.
- Mechanical distinction from S08 Fake Out: Fake Out requires HH + HL + lower close vs prior bar; Naked Close requires only the close < prior low — no constraint on the bar's high or low extremes. Looser setup, different entry reference (THIS bar's high vs PRIOR bar's high).

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                             # generic; V5 proxies: US500.DWX, US100.DWX, GER40.DWX, UK100.DWX
  - bond_futures                              # generic
  - commodities                               # generic
  - forex                                     # generic; V5 proxy: spot Darwinex .DWX FX symbols
timeframes:
  - D1                                        # Williams: rules stated on daily bars
  - H4                                        # H4 ablation in P3 sweep
session_window: not specified
primary_target_symbols:
  - "all major Darwinex .DWX index/metal/FX symbols (Williams: pattern is generic)"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF pp. 19-20 § "NAKED CLOSE DAYS".

```text
PARAMETERS:
- BAR               = D1
- OFFSET_TICKS      = 0           // entry trigger at same-bar extreme; 0-tick offset
- USE_TRUE_EXTREMES = false       // Williams: "high of this down close" / "low of this up close" — plain not true

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- bullish_naked_close at bar t-1:
    Close[t-1] < Low[t-2]                     # close BELOW prior bar's low — the "naked" condition
- bearish_naked_close at bar t-1:
    Close[t-1] > High[t-2]                    # close ABOVE prior bar's high

ENTRY (only when not in position; orders staged at session start):
- if bullish_naked_close at t-1:
    stage stop-buy at High[t-1] + OFFSET_TICKS    # THIS bar's HIGH (the naked-close bar)
    if intra-day High[t] >= High[t-1]: FILL_LONG at High[t-1]
- if bearish_naked_close at t-1:
    stage stop-sell at Low[t-1] - OFFSET_TICKS    # THIS bar's LOW
    if intra-day Low[t] <= Low[t-1]: FILL_SHORT at Low[t-1]
- single-attempt-per-day: order cancelled at session close if not filled
```

**Reference-price disambiguation**: Williams says "buy at the high of THIS down close" — meaning at the high of the naked-close bar (bar t-1 in indexing above), NOT at the prior bar's high (which would be Fake Out's reference). This distinguishes Naked Close from Fake Out cleanly.

## 5. Exit Rules

Williams' standard exit menu (PDF pp. 20-21) applies; default is dollar-stop + 3-bar trail combo (consistent with S07 Smash Day + S08 Fake Out per the Failure-Day-Family thesis).

> **3-bar trail spec ratified at `framework/V5_TM_MODULES.md` § TM-3BAR-TRAIL** (Williams PDF p. 21; CEO ratified 2026-04-28 in QUA-298 closeout, comment `cc655c56`; back-port QUA-334). The pseudocode below is retained inline for self-contained card review and matches the canonical TM-module spec.

```text
DEFAULT EXIT:
- HARD_STOP_USD     = 1500       // V5 → ATR-equivalent
- TRAIL_BARS        = 3          // Williams' "Amazing 3 Bar Entry/Exit"
- TRAIL_NO_INSIDE   = true
- TRAIL_ACTIVATE    = first_close_in_profit
- TIME_STOP         = 10 bars    // backstop

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- TRAIL — identical 3-bar non-inside-day true-low/true-high trail as S07 / S08
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies; 5-10 day typical hold; rarely binds.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed
- gridding: NOT allowed
- Setup-bar gating: only fires when bar t-1 satisfies the naked-close pattern per § 4
- Trend-agreement filter (OPTIONAL P3 sweep axis): suppress counter-trend signals; Williams
  does NOT cite for Naked Close; ablation only
- Outside-day-exclusion (OPTIONAL): a naked-close bar that is also an outside day may have
  different reversion characteristics; ablation variant
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
  default: false                              # Williams: "high"/"low" — plain
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

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. Same multi-market generalization profile as S07 Smash Day / S08 Fake Out. Setup-density at D1 is higher than S07/S08 (≈ 15-30 setups/year/symbol — close-outside-prior-bar is a looser setup than the multi-condition Smash/Fakeout patterns).

## 9. Author Claims (verbatim, with quote marks)

Naked Close Days pattern, PDF pp. 19-20:

> "NAKED CLOSE DAYS — This is a nice term coined by Joe Stowell. It's easy to spot, a naked close 'buy set up' requires a close lower than yesterdays low, buy at the high of this down close. A 'sell set up' requires a close above yesterdays high, sell at the low of this up close."

**Williams provides NO numeric performance claim for Naked Close Days specifically.** No backtest table is associated with this pattern in the source's text-clean range (PDF pp. 1-46). Per BASIS rule, no extrapolated number is asserted; pipeline P2-P9 produce actual edge measurement.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.05                             # rough estimate; loosest setup of the Failure-Day-Family → highest setup-density but most likely lowest per-trade edge → modest PF
expected_dd_pct: 22                           # rough estimate; counter-trend with high signal density → larger DD
expected_trade_frequency: 15-30/year/symbol   # rough estimate; loosest setup of the family
risk_class: medium                            # counter-trend bar-pattern reversal
gridding: false
scalping: false                               # D1
ml_required: false                            # threshold + bar-shape arithmetic
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (single-condition close-vs-prior-bar-extreme + stop-buy/sell at same-bar extreme)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable
- [x] Friday Close compatibility: 5-10 day typical hold; default V5 applies
- [x] Source citation is precise enough to reproduce (PDF pp. 19-20 verbatim; no quantification gaps — the close-vs-prior-low/high condition is unambiguous)
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "naked-close setup condition + standard V5 default; optional trend-agreement and outside-day filters"
  trade_entry:
    used: true
    notes: "stop-buy at same-bar high (long) / stop-sell at same-bar low (short); single-attempt-per-day"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "3-bar non-inside-day trail (default) or alt-exit per P3 sweep; ATR-equivalent hard stop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Williams' pattern is generic; CSR P3.5 validates breadth across .DWX symbols
  - friday_close                              # NOT load-bearing
  - news_pause_default                        # standard V5 P8 applies; naked closes can cluster around macro events with large gap moves
  - one_position_per_magic_symbol             # NOT load-bearing
  - kill_switch_coverage                      # naked-close bar means a meaningful gap-equivalent move; the reversal-fade can fail if the gap is event-driven (earnings, macro shock). Hard-stop catches single-trade case; account-level kill-switch catches sequential adverse fades. P5c crisis-slice load-bearing.

at_risk_explanation: |
  dwx_suffix_discipline — generic pattern, multi-market CSR P3.5 validation.

  news_pause_default — naked closes are MORE LIKELY to print on high-impact-news days (sharp
  range expansion + close at the new extreme). The pattern's edge may be CONFOUNDED with
  news-event-driven moves. P8 ablation: does the pattern survive when high-impact-news days
  are excluded? If pattern collapses post-news-removal, the edge is news-driven not flow-driven.

  kill_switch_coverage — load-bearing on the failure mode "naked close DOES NOT reverse and
  continues in the same direction" (sustained event-driven trends). Hard-stop catches single-
  trade case; account-level kill-switch catches sequential adverse fades. P5c crisis-slice
  ABL-12-09 (Lehman week, sustained naked-close-down sequence) and 2020-03 (COVID) load-bearing.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # single-condition bar-shape check at prior-bar close; stop-buy/sell at session start; ~50-80 LOC in MQL5 (simplest of Failure-Day-Family)
  management: TBD
  close: TBD
estimated_complexity: small
estimated_test_runtime: 1-3h                  # P3 sweep cell count moderate (2×4×4×5×3×2 = 960 cells); D1 bars; setup-density higher than S07/S08
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
- 2026-04-28: SRC03_S09 reuses the SRC03_S07-proposed `rejection-bar-stop-entry` vocabulary-gap
  flag — same family as Smash Day + Fake Out. The mechanical distinction across the three:
    S07 Smash Day:      close-vs-OPEN body rejection + entry at same bar's high
    S08 Fake Out:       close-vs-PRIOR-CLOSE direction failure + entry at PRIOR bar's high
    S09 Naked Close:    close-vs-PRIOR-BAR-LOW outside extension + entry at SAME bar's high
  All three fit one vocabulary flag (`rejection-bar-stop-entry`); no new gap surfaced.

- 2026-04-28: Williams provides NO numeric performance claim for Naked Close Days. Per BASIS
  rule, no extrapolated number asserted; pipeline P2-P9 produces actual edge.

- 2026-04-28: Cards-vs-fold decision retained as DISTINCT (S09 vs S07 vs S08) — different
  setup conditions (single-condition close-outside-prior-bar vs 3-condition Fake Out vs
  body-rejection Smash Day) and different entry references (same bar's high vs prior bar's
  high vs same bar's high). Per DL-033 Rule 1.

- 2026-04-28: P5c CRISIS-SLICE LOAD-BEARING. Naked closes are MORE LIKELY to print on
  high-impact-news days (sharp range expansion + close at extreme). The reversal-fade thesis
  fails on sustained event-driven trends (Lehman Sep-Oct 2008; COVID Feb-Mar 2020). P5c
  crisis-slice mandatory; kill-switch coverage validation at P5.

- 2026-04-28: Joe Stowell attribution noted in § 1 as supplement (role: supplement). Williams
  is the operative source (provides the rule); Stowell is credited for the term-coining.
  Per `_TEMPLATE.md` § 1 multi-source convention — primary + supplement is the correct
  structure.
```
