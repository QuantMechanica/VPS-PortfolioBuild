# Strategy Card — Williams Hidden OOPS! (projected H/L formula gap-fade with stop entry; Bonds + S&P)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim Bonds-context § "4. HIDDEN OOPS! TRADES", PDF p. 36; S&P-context § "2.) HIDDEN OOPS!", PDF p. 40).
> Submitted for CEO + Quality-Business review per DL-032 + DL-030.

## Card Header

```yaml
strategy_id: SRC03_S03
ea_id: TBD
slug: williams-hidden-oops
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - gap-fade-stop-entry                       # canonical match — entry: gap THROUGH a calendar-pattern reference price (projected formula `(H+L+C)/3 × 2`) → stop-entry placed BACK at the reference. Same family as S02 Monday OOPS! with a different reference-price formula. CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - atr-hard-stop                             # generic V5 hard stop
  - long-only                                 # Williams' verbatim sub-rules describe LONG entries; short-side mirror is V5 ablation
  - friday-close-flatten                      # V5 default
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 36 (Bonds-context § '4. HIDDEN OOPS! TRADES', sub-rules A-C); PDF p. 40 (S&P-context § '2.) HIDDEN OOPS!', sub-rules A-D). Sister-pattern: S02 williams-monday-oops uses Friday's TRUE LOW as reference; S03 uses the projected-H/L formula `(H+L+C)/3 × 2` as reference."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 372-388 (Bonds Hidden OOPS! sub-rules A-C verbatim), lines 548-565 (S&P Hidden OOPS! sub-rules A-D verbatim).

## 2. Concept

A **projected-H/L gap-fade reversal entry** — sister pattern to S02 Monday OOPS! using a **calculated** reference price (the projected high/low formula) instead of the prior bar's actual extreme. Williams' projected-H/L formula:

```
projected_pivot = (High[t-1] + Low[t-1] + Close[t-1]) / 3 × 2
projected_low   = projected_pivot - High[t-1]
projected_high  = projected_pivot - Low[t-1]
```

When the next-day open gaps below the projected_low (or above the projected_high), Williams' rule places a stop-buy back at the projected_low (or stop-sell at the projected_high), fading the gap. Distinct from S02 because the reference price is **calculated** (projected) rather than **observed** (prior actual extreme).

Williams' verbatim Bonds-context framing, PDF p. 36:

> "4. HIDDEN OOPS! TRADES
>
> For these trades we use the projected high/low formula which is; (high + low + close)/3 *2. ... Subtract the high to arrive at the projected low, subtract the low to arrive at the projected h[igh]."

S&P-context framing, PDF p. 40:

> "2.) HIDDEN OOPS!
>
> A. If today is Friday or Monday and the open tomorrow is 2 ticks less than the projected TRUE LOW for that day, based on todays TH+TL+C/3*2, THEN buy tomorrow at the projected low."

The "Hidden" name reflects that the projected-H/L is not visible on the chart — it's a calculation that "hides" the intra-bar reversal level until computed. Per DL-033 Rule 1, distinct from S02 — different reference price = different mechanical trigger.

## 3. Markets & Timeframes

```yaml
markets:
  - bond_futures                              # Williams' Bonds context PDF p. 36
  - index_futures                             # Williams' S&P context PDF p. 40 → US500.DWX V5 proxy
timeframes:
  - D1                                        # daily bars
session_window: cash_session
primary_target_symbols:
  - "T-Bonds futures (Williams) → bond CFD if available; flag dwx_suffix_discipline otherwise"
  - "S&P 500 futures (Williams) → US500.DWX V5 proxy"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' multi-sub-rule structure.

```text
PARAMETERS:
- USE_TRUE_EXTREMES = true                    // Williams S&P uses "TH+TL+C/3*2" (true high/low); Bonds variant uses plain H/L
- OFFSET_TICKS      = 2                       // Williams S&P: "2 ticks less than the projected TRUE LOW"
- WEEKDAY_FILTER    = williams_sp_default     // {MON, FRI} per S&P sub-rule A; {MON, THU, FRI} per Bonds sub-rule A; varies per sub-rule

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- compute projected_pivot, projected_low, projected_high per § 2 formula on bar t-1
- if WEEKDAY_FILTER matches AND any sub-rule conditions hold:
  - if Open[t] < projected_low - OFFSET_TICKS:
      stage stop-buy at projected_low
      if intra-day High[t] >= projected_low: FILL_LONG at projected_low
  - if Open[t] < projected_high (sub-rule C/D variant — buy at PROJECTED HIGH):
      stage stop-buy at projected_high
      if intra-day High[t] >= projected_high: FILL_LONG at projected_high
```

**Sub-rule disambiguation** (S&P-context PDF p. 40):

```text
sub-rule A (canonical Hidden OOPS!):
  WEEKDAY = {FRI, MON}
  Open[t] < projected_low - 2 ticks
  → BUY at projected_low

sub-rule B (Thursday extension):
  WEEKDAY[t-1] = THU AND High[t-1] >= Close[t-2]
  Open[t] < projected_low - 2 ticks
  → BUY at projected_low

sub-rule C (any-day-but-Friday + Bonds-uptrend):
  WEEKDAY[t] != FRI AND Close[t-1] < Close[t-2] AND H-C[t-1] < H-C[t-2]
  AND Bonds_Close[t-1] > Bonds_Close[t-2 OR t-7]
  Open[t] < projected_high
  → BUY at projected_high

sub-rule D (gap-down-with-Bonds-trend):
  High[t-1] >= Close[t-2] AND Low[t-1] <= Close[t-2]
  AND Bonds_Close[t-1] > Bonds_Close[t-{2,3,5,9} bars ago]
  AND WEEKDAY[t-1] in {MON, THU, FRI}
  Open[t] < projected_low
  Exclude October
  → BUY at projected_low
```

**Williams' multi-sub-rule structure** is more complex than S02 Monday OOPS!. Each sub-rule is mechanically distinct (different conditions); for V5 deployment, default = sub-rule A canonical. P3 sweep enables sub-rules B/C/D as ablation axes.

## 5. Exit Rules

Identical to S02 Monday OOPS!: bail-out-on-profit-open + ATR-equivalent hard stop + 5-bar time-stop backstop. See S02 § 5 for details.

```text
DEFAULT EXIT:
- HARD_STOP_ATR_MULT = 2.0                    // ATR-equivalent of Williams' generic dollar stop
- BAIL_OUT_ON_PROFIT_OPEN = true
- TIME_STOP = 5 bars (backstop)
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- WEEKDAY_FILTER per sub-rule (default sub-rule A: {MON, FRI})
- October exclusion (sub-rule D verbatim Williams: "exclude Octobers")
- pyramiding: NOT allowed
- gridding: NOT allowed
```

## 7. Trade Management Rules

```text
- one open position per direction at any time
- single-attempt-per-day: stop-buy order valid only for trigger-day; cancel at close
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: sub_rule_set
  default: A_only                             # sub-rule A canonical
  sweep_range: [A_only, A_plus_B, A_plus_C, A_plus_D, A_through_D, B_only, C_only]
- name: use_true_extremes
  default: true                               # Williams S&P: TH+TL+C/3×2
  sweep_range: [true, false]
- name: offset_ticks
  default: 2                                  # Williams S&P explicit
  sweep_range: [0, 1, 2, 3, 5]
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.5, 2.0, 2.5, 3.0]
- name: time_stop_bars
  default: 5
  sweep_range: [3, 5, 7, 10]
- name: october_exclude
  default: false                              # only sub-rule D specifies; default off
  sweep_range: [false, true]
- name: bonds_trend_filter                    # sub-rules C and D require this
  default: off
  sweep_range: [off, bonds_above_2d, bonds_above_2d_or_7d, bonds_above_1_2_4_8d]
```

P3.5 (CSR) axis: same multi-market generalization profile as S02 Monday OOPS! — Index CFDs (US500.DWX, US100.DWX) high transfer expected; spot FX low transfer expected (FX has no weekend-gap dynamic).

## 9. Author Claims (verbatim, with quote marks)

Bonds Hidden OOPS! sub-rule A, PDF p. 36:

> "A. If today is a down close and today is Monday or Friday AND Gold is lower than 19 day[s ago] AND today's close is the lowest close of the last 8,10 or 12 days ago AND the open tomorrow is greater than the projected low THEN buy tomorrow on the open."

(Note: Bonds variant adds a Gold-trend filter and a multi-bar low-close condition; mechanically more restrictive than S&P variant.)

S&P Hidden OOPS! sub-rule A (canonical), PDF p. 40:

> "A. If today is Friday or Monday and the open tomorrow is 2 ticks less than the projected TRUE LOW for that day, based on todays TH+TL+C/3*2, THEN buy tomorrow at the projected low."

S&P Hidden OOPS! sub-rule D (October-exclude variant), PDF p. 40:

> "D. If today's high is greater than or equal to the prior days close while today's low is less than or equal the prior days close AND bonds have closed higher than the close 1,2,4 or 8 days ago and today is Monday, Thursday or Friday AND the open tomorrow is less than the projected low, then buy tomorrow at the projected low on a stop, (exclude Octobers)."

**Williams provides NO numeric performance claim for Hidden OOPS! specifically.** No backtest table for the Hidden OOPS! variant. Per BASIS rule, no extrapolated number asserted.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.3                              # rough estimate; sister to S02 Monday OOPS! with similar gap-fade thesis but more restrictive sub-rules
expected_dd_pct: 12
expected_trade_frequency: 5-12/year/symbol    # tighter than S02 due to projected-H/L threshold + multi-condition sub-rules
risk_class: low
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (calendar + projected-H/L formula + threshold + stop-buy)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1)
- [x] Friday Close compatibility: 1-3 day typical hold via bail-out
- [x] Source citation precise (PDF p. 36 Bonds + p. 40 S&P verbatim sub-rules)
- [x] No near-duplicate (S02 uses different reference price — actual prior-bar extreme vs projected)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "WEEKDAY_FILTER + sub-rule conditions + standard V5 default"
  trade_entry:
    used: true
    notes: "stop-buy at projected_low (or projected_high per sub-rule C/D); single-attempt-per-day"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "bail-out at first profitable open + ATR hard stop + time-stop backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Williams' deployment is CME futures
  - friday_close                              # NOT load-bearing — short hold
  - news_pause_default                        # standard V5 P8 applies
  - one_position_per_magic_symbol             # NOT load-bearing
  - kill_switch_coverage                      # gap-fade can fail (sister to S02 case); P5c crisis-slice load-bearing
  - enhancement_doctrine                      # load-bearing on sub_rule_set selection — Williams provides 4 sub-rules per context

at_risk_explanation: |
  Same risk profile as S02 Monday OOPS! (sister card). Hidden OOPS! adds enhancement_doctrine
  load-bearing on sub-rule-set selection (Williams provides 4 sub-rules per context, with
  different mechanical conditions). Default sub-rule A; P3 sweeps alternatives.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD
  entry: TBD                                  # projected-H/L formula + sub-rule dispatcher; ~150-200 LOC in MQL5
  management: TBD
  close: TBD
estimated_complexity: medium                  # multi-sub-rule logic
estimated_test_runtime: 1-3h                  # P3 sweep cell count moderate
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

(remaining phases TBD per V5 pipeline standard; same template as S02)

## 16. Lessons Captured

```text
- 2026-04-28: SRC03_S03 reuses S02-proposed `gap-fade-stop-entry` vocabulary-gap flag — same
  family as Monday OOPS! with a different reference-price calculation (projected vs actual).
  No new flag surfaced.

- 2026-04-28: Williams provides NO numeric performance claim for Hidden OOPS!. Per BASIS rule,
  no extrapolated number asserted.

- 2026-04-28: Cards-vs-fold decision (S02 vs S03): DISTINCT per DL-033 Rule 1. S02 uses Friday's
  observed TRUE LOW as reference; S03 uses the projected-H/L formula. Different mechanical
  triggers despite shared gap-fade thesis.

- 2026-04-28: Williams' multi-sub-rule structure (sub-rules A-D in S&P; sub-rules A-C in Bonds)
  is the most complex of any SRC03 entry pattern. Card consolidates all sub-rules under
  `sub_rule_set` parameter; default = sub-rule A canonical; P3 sweeps alternatives. This is
  consistent with the `enhancement_doctrine` discipline — once a live sub-rule-set is fixed,
  retune is enhancement_doctrine.

- 2026-04-28: Bonds and S&P variants use slightly different formulas (Bonds: H+L+C; S&P: TH+TL+C
  with true-high/true-low). The TRUE-extreme variant is gap-aware and is recommended default
  per Williams' S&P framing.
```
