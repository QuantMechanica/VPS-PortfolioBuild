# Strategy Card — Williams Monday OOPS! (gap-below-Friday-true-low fade with stop entry at Friday's low)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim S&P 500 Trading Rules § "MONDAY OOPS!" + Bonds-context cross-reference § "FRIDAY SET UP TRADES FOR MONDAY").
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S02
ea_id: TBD
slug: williams-monday-oops
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - gap-fade-stop-entry                       # canonical match — entry: gap THROUGH a calendar-pattern reference price (Friday's TRUE LOW) → stop-buy placed BACK at the reference, fading the gap. The flag's definition subsumes the calendar-pattern precondition (Monday-after-Friday-down-close). CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - atr-hard-stop                             # Williams: catastrophic stop after entry; fixed-distance from fill
  - symmetric-long-short                      # Williams names long Monday OOPS!; Workshop "Failure Day Family" (PDF p. 19) is symmetric, implying Monday OOPS! short-mirror is "Friday down-close → Monday open ABOVE Friday TRUE HIGH → sell at Friday high on stop"
  - friday-close-flatten                      # V5 default; Williams' typical exit is first-profitable-open + bail-out (1-3 day max hold)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF pp. 39-40 (Inner Circle Workshop companion volume), § 'S&P 500 TRADING RULES — 1.) MONDAY OOPS!' (sub-rules A, B). Cross-reference: PDF pp. 35-36 § 'TREASURY BOND TRADING RULES — 3.) FRIDAY SET UP TRADES FOR MONDAY' (sub-rules A-E, Bonds-context analog with multiple Friday-bar variants including the OOPS! base pattern at sub-rule B). Performance numbers (Monday-buys composite): PDF p. 31 ($79,200 / 69% accuracy on Bonds 'simple system that buys on the opening every Monday if that opening is less than Fridays close')."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 539-547 (S&P MONDAY OOPS! sub-rules A and B verbatim), lines 346-369 (Bonds Friday Set-Up Trades sub-rules A-E with the OOPS! variant at sub-rule B), lines 40-44 (Monday-buys-composite performance data on Bonds). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **calendar-conditional gap-fade reversal** — when Monday's session opens BELOW Friday's TRUE LOW (a gap-below-Friday's-low), Williams treats this as a public-driven panic gap that is statistically likely to recover within the day. The entry trigger is a stop-buy placed at Friday's low: if price recovers back through Friday's low intra-day, the position fills at that level. Williams positions this as "the ultimate S&P trade" (PDF p. 39) — the public's emotional weekend-decision-making produces gap-down opens that are systematically faded by professional flow during the session.

Williams' verbatim framing, PDF p. 39:

> "1.) MONDAY OOPS!
>
> A. It's the ultimate S&P trade, to take an OOPS! Buy on Monday as long as Friday was not an outside day. That's all there is to it, [if] prices open below Fridays TRUE LOW, on Mond[ay], buy long at Fridays low on a stop.
>
> B. If the day that has just closed is Thursday or Friday and the open tomorrow is below the lowest low of the last 2 days, buy on a stop at that low."

The "OOPS!" name (Williams' coinage) refers to the trader-psychology framing — once the gap-down fails, sellers realize "OOPS!" they were wrong and reverse. Sub-rule B generalizes the pattern from "Monday after Friday" to "Friday or Saturday after Thurs/Fri", broadening the calendar window.

This card extracts the **base Monday OOPS! mechanical entry** (sub-rule A) plus its Thurs/Fri-source extension (sub-rule B). The Hidden OOPS! variant (PDF p. 40 § 2, projected-low formula) is a STRUCTURALLY DISTINCT calculation method and lives in a sister card (`williams-hidden-oops`); fold-vs-distinct decision retained at extraction time per Rule 1 — the projected-H/L formula uses a different reference price (`(H+L+C)/3 × 2 − H` instead of Friday's TRUE LOW), which makes it a mechanically distinct entry trigger.

The Bonds-context Friday-Set-Up family (PDF p. 36 sub-rules A-E) contains the OOPS! pattern at sub-rule B; this card folds in the Bonds analog. The remaining Friday-Set-Up sub-rules (A, C, D, E) are non-OOPS! patterns and live in their own card if extracted (currently not slotted in SRC03 source.md § 6 — to be revisited at the S14 / S15 family pass).

## 3. Markets & Timeframes

```yaml
markets:
  - index_futures                             # Williams' primary deployment: S&P 500 futures (PDF p. 39 "ultimate S&P trade"). V5 proxy: US500.DWX
  - bond_futures                              # Williams' Bonds-context: PDF pp. 35-36 sub-rule B. V5 proxy: bond CFD if Darwinex offers; flag dwx_suffix_discipline otherwise
timeframes:
  - D1                                        # Williams: rules stated on daily bars (Friday's close, Monday's open, Friday's TRUE LOW)
  - intraday_session_trigger                  # entry fires intra-session as price recovers back through Friday's low; D1 bar-timeframe with intraday stop-fill mechanics
session_window: cash_session                  # Williams' S&P framing implies the cash session (09:30-16:15 ET). V5 deployment: respects broker session window.
primary_target_symbols:
  - "S&P 500 futures (Williams' deployment, 'ultimate S&P trade') → US500.DWX V5 proxy"
  - "T-Bonds futures (Williams' Bonds analog) → bond CFD if available; flag otherwise"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF p. 39 sub-rules A and B; the symmetric short-side mirror is implicit in Williams' broader Failure-Day-Family framing (PDF p. 19) and is added here for V5 completeness.

```text
PARAMETERS:
- LOOKBACK_BARS    = 2          // Williams: "lowest low of the last 2 days" (sub-rule B)
                                //   sub-rule A is special case of LOOKBACK_BARS=1 with Friday-only constraint
- USE_TRUE_LOW     = true       // Williams: "Fridays TRUE LOW" — explicit
                                //   true_low(t) = MIN(Low[t], Close[t-1])
- WEEKDAY_FILTER   = monday_only_or_thurs_fri   // sub-rule A = Monday only; sub-rule B = Thurs|Fri prior bar
- EXCLUDE_OUTSIDE_DAY = true    // Williams sub-rule A: "as long as Friday was not an outside day"
                                //   outside_day(t) = High[t] > High[t-1] AND Low[t] < Low[t-1]

EACH-BAR (next-day open trigger, evaluated at prior-day close):
- if WEEKDAY_FILTER == monday_only AND DayOfWeek(t-1) != FRIDAY: NO_TRADE
- if EXCLUDE_OUTSIDE_DAY AND outside_day(t-1): NO_TRADE
- ref_low = USE_TRUE_LOW ? min(true_low(b) for b in last LOOKBACK_BARS bars) : min(Low(b) for b in last LOOKBACK_BARS bars)
- ref_high = USE_TRUE_LOW ? max(true_high(b) for b in last LOOKBACK_BARS bars) : max(High(b) for b in last LOOKBACK_BARS bars)
- buy_trigger  = ref_low                              // stop-BUY placed AT ref_low
- sell_trigger = ref_high                             // stop-SELL placed AT ref_high (symmetric mirror)

ENTRY (only when not in position; orders staged at session start):
- LONG SIDE (Williams verbatim):
  - if Open[t] < ref_low (gap below):
      stage stop-buy order at ref_low
      if intra-day High[t] >= ref_low: FILL_LONG at ref_low (price recovered back through ref_low)
  - if Open[t] >= ref_low: NO_TRIGGER (no gap-down, no Monday-OOPS! signal)
- SHORT SIDE (V5 symmetric mirror; not verbatim Williams):
  - if Open[t] > ref_high (gap above):
      stage stop-sell order at ref_high
      if intra-day Low[t] <= ref_high: FILL_SHORT at ref_high
```

Williams sub-rule B disambiguation:

```text
sub-rule A (canonical Monday OOPS!):
  WEEKDAY_FILTER = monday_only
  LOOKBACK_BARS  = 1                          // Friday only
  EXCLUDE_OUTSIDE_DAY = true
  USE_TRUE_LOW    = true

sub-rule B (Thurs/Fri-source extension):
  WEEKDAY_FILTER = prior_bar_in_{Thu, Fri}
  LOOKBACK_BARS  = 2                          // "lowest low of the last 2 days"
  EXCLUDE_OUTSIDE_DAY = (not specified by Williams; default true to preserve gap-fade thesis)
  USE_TRUE_LOW    = (not specified; default true for consistency with sub-rule A; sweep axis)
```

## 5. Exit Rules

Williams' exit framing for short-term trades (PDF p. 31 § "INSIDE CIRCLE SHORT TERM TRADING APPROACH"):

```text
DEFAULT EXIT (Williams' standard short-term combo):
- BAIL_OUT_ON_PROFIT_OPEN: exit at first profitable open after entry
  // Williams' standard short-term-trade exit; "exit on the first profitable opening"
  // referenced repeatedly (PDF pp. 31, 33, 41 contexts)
- HARD_STOP_USD = 1750         // Williams' Bonds-context; PDF p. 31: "Our exit is standard
                               //   Bail Out with a $ 1,750 stop." S&P holiday context p. 41
                               //   uses $2,500. V5 translates to ATR-equivalent.
- TIME_STOP   = 5 bars         // Williams does NOT specify a hard time-stop for Monday OOPS!,
                               // but "first profitable open" naturally caps holds at 1-3
                               // sessions. Time-stop is a P3 backstop axis.

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP_USD-equivalent ATR distance from entry; never moves
- BAIL_OUT_ON_PROFIT_OPEN:
  if LONG:
    if Open[t+1] > entry_price: CLOSE_LONG at Open[t+1]
  if SHORT:
    if Open[t+1] < entry_price: CLOSE_SHORT at Open[t+1]
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies. Monday-OOPS! holds typically resolve within 1-3 sessions
via bail-out-on-profit; Friday-close rarely binds. No waiver required.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one open position per direction at a time)
- gridding: NOT allowed
- WEEKDAY_FILTER: Monday-only (sub-rule A) or Thurs/Fri-prior (sub-rule B); enforced at entry per § 4
- OUTSIDE_DAY_EXCLUSION: Friday-was-outside-day disqualifies (sub-rule A); axis variant for sub-rule B
- "October exclusion" (Williams' Hidden OOPS! sub-rule D footnote, PDF p. 40: "exclude Octobers"):
  not specified for Monday OOPS! sub-rule A — but the October-crash seasonal-tail is
  documented elsewhere by Williams. Off by default for Monday OOPS!; sweep-axis variant.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
- single-attempt-per-day rule: if stop-buy / stop-sell does not fill intra-day, order
  cancelled at session close — Williams does NOT carry the order to subsequent days
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: lookback_bars
  default: 1                                  # sub-rule A canonical (Friday only)
  sweep_range: [1, 2, 3]                      # 1 = sub-rule A; 2 = sub-rule B; 3 = generalization extension
- name: weekday_filter
  default: monday_only                        # sub-rule A
  sweep_range: [monday_only, monday_or_tuesday, prior_bar_thurs_fri, all_weekdays]
- name: use_true_low
  default: true                               # Williams: "Fridays TRUE LOW"
  sweep_range: [true, false]                  # plain LOW as ablation
- name: exclude_outside_day
  default: true                               # Williams sub-rule A explicit
  sweep_range: [true, false]
- name: hard_stop_atr_mult
  default: 2.5                                # ATR-equivalent of Williams' $1,750 Bonds / $2,500 S&P
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: bail_out_first_profit_open
  default: true                               # Williams' standard
  sweep_range: [true, false]                  # false = hold to TIME_STOP only
- name: time_stop_bars
  default: 5
  sweep_range: [2, 3, 5, 10]
- name: october_exclude
  default: false                              # not specified for Monday OOPS!; off by default
  sweep_range: [false, true]
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. Williams' calling out of "ultimate S&P trade" (PDF p. 39) signals a deployment preference for index futures; CSR validates whether the Monday-gap-fade edge generalizes to:
- Other indices: US100.DWX, GER40.DWX, UK100.DWX, NIKKEI.DWX (cross-time-zone variant)
- Spot FX with weekend-gap exposure: EURUSD.DWX (rare), USDJPY.DWX (rare), GBPUSD.DWX (rare)
- Metals with weekend-gap: GOLD.DWX, XAGUSD.DWX

The Monday-gap thesis is index-microstructure-specific (US public weekend-decision-making → Monday-open gap → professional fade). CSR results are expected to be STRONG on US indices, MARGINAL on global indices, WEAK on spot FX (FX gaps less due to 24/5 trading even with the weekend break).

## 9. Author Claims (verbatim, with quote marks)

Monday OOPS! sub-rule A (canonical entry), PDF p. 39:

> "1.) MONDAY OOPS!
>
> A. It's the ultimate S&P trade, to take an OOPS! Buy on Monday as long as Friday was not an outside day. That's all there is to it, [if] prices open below Fridays TRUE LOW, on Mond[ay], buy long at Fridays low on a stop."

Monday OOPS! sub-rule B (Thurs/Fri-source extension), PDF p. 39:

> "B. If the day that has just closed is Thursday or Friday and the open tomorrow is below the lowest low of the last 2 days, buy on a stop at that low."

Bonds-context analog Friday-Set-Up sub-rule B (PDF p. 36):

> "B. Fridays high is greater than or equal to Thursdays close and Mondays open is below Fridays low then buy Monday at Fridays low on a stop. (OOPS!)"

Monday-buys-composite Bonds performance (PDF p. 31), separate from but motivationally adjacent to the Monday OOPS! pattern:

> "We'll use a very simple system that buys on the opening every Monday if that opening is less than Fridays close. Our exit is standard Bail Out with a $ 1,750 stop. Trading just one contract on all signals makes $79,200 with 69% accuracy and a risk reward ratio of .81."

(Note: that Bonds composite is the OPENING-BUY-IF-OPEN-BELOW-FRIDAY-CLOSE rule, NOT the OOPS! stop-buy-at-Friday-low rule. They are RELATED but mechanically DIFFERENT triggers. Per BASIS rule, the $79,200 / 69% number is preserved as Williams' verbatim claim for the related-but-distinct Bonds-Monday-buys composite, NOT asserted as Monday OOPS! S&P performance. Pipeline P2-P9 produce the actual Monday-OOPS!-S&P edge measurement.)

S&P holiday-context bail-out parameter (PDF p. 41 § "S&P HOLIDAY TRADES"):

> "The stop is a very small $2,500 from entry hit."

(referenced for the dollar-stop value used in the S&P Bond-comparison context; informs the ATR-mult default in § 8 P3 sweep.)

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # rough estimate; Williams' "ultimate S&P trade" framing + Bonds-Monday-buys composite at $79,200 / 69% accuracy / 0.81 risk-reward suggests positive edge with high win rate
expected_dd_pct: 12                           # rough estimate; bail-out-on-profit-open + 1-3 day holds suggest tight DD profile
expected_trade_frequency: 8-15/year/symbol    # Monday gap-below-Friday-low events on S&P historical: ~10-15 per year. Sub-rule B extension adds Tues entries.
risk_class: low                               # short-hold gap-fade with bail-out + hard-stop; canonical low-risk-class
gridding: false
scalping: false                               # D1 trigger with intraday fill mechanics; not scalping
ml_required: false                            # threshold + calendar-day arithmetic
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (calendar-day check + gap-vs-prior-low arithmetic + stop-buy at fixed price)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1 trigger, intraday fill but no sub-M5 churn)
- [x] Friday Close compatibility: 1-3 day typical hold via bail-out-on-profit-open; Friday-close rarely binds
- [x] Source citation is precise enough to reproduce (PDF p. 39 verbatim + PDF p. 36 Bonds analog + PDF p. 31 Bonds-Monday-buys composite — note the LAST is a related-but-distinct rule)
- [x] No near-duplicate of existing approved card (no Williams-family in `strategy-seeds/cards/` yet)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "WEEKDAY_FILTER + OUTSIDE_DAY_EXCLUSION + standard V5 default (kill-switch, news, MAX_DD, Friday-close)"
  trade_entry:
    used: true
    notes: "stop-buy at Friday's TRUE LOW (sub-rule A) or last-2-days low (sub-rule B); only when next-day open gaps below; one position per direction"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "bail-out at first profitable open + ATR-equivalent hard stop + time-stop backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # Williams' rule originates on S&P / T-Bonds futures; V5 maps to .DWX CFDs. CTO sanity-check at G0.
  - friday_close                              # NOT load-bearing — typical 1-3 day hold via bail-out. Listed for completeness.
  - news_pause_default                        # Monday gaps frequently coincide with weekend macro news (Asia / Europe market open). P8 news-blackout may exclude pre-market-news Mondays. Standard V5 P8 handles it.
  - one_position_per_magic_symbol             # NOT load-bearing — single position per direction; listed for explicit confirmation.
  - kill_switch_coverage                      # gap-down trade can morph into a continuation-down trade if the OOPS! reversal fails. Hard-stop catches catastrophic case; CTO confirms kill-switch sizing covers worst-case "Monday gap-down DOES NOT reverse" scenario (e.g., 2020-03 COVID Monday gaps). P5 stress + P5c crisis-slice load-bearing.

at_risk_explanation: |
  dwx_suffix_discipline — Williams' S&P / T-Bonds futures → V5 .DWX CFD mapping. Index CFDs
  (US500.DWX) replicate cleanly; bond-CFD availability is a CTO check at G0.

  friday_close — Bail-out-on-profit-open caps typical hold at 1-3 sessions. Friday-close
  rarely binds. Default V5 applies cleanly.

  news_pause_default — Monday opens often correlate with Sunday-evening macro events (Asia
  open, weekend geopolitics). P8 news-blackout may legitimately exclude pre-news Mondays.
  Standard V5 P8 gating handles it; no card-specific waiver.

  one_position_per_magic_symbol — single position per direction at a time; pyramiding/stacking
  not used. Listed for explicit confirmation.

  kill_switch_coverage — load-bearing on the failure mode "Monday gap-down DOES NOT reverse"
  (2020-03-09 COVID Monday is the canonical adverse case). Hard-stop catches single-trade
  catastrophic loss; account-level kill-switch catches sequential adverse Mondays. CTO
  sanity-check at P5; P5c crisis-slice run on 2008-09, 2010-05 (Flash Crash week), 2020-03.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # WEEKDAY_FILTER + OUTSIDE_DAY_EXCLUSION + standard V5
  entry: TBD                                  # stop-buy at session start when conditions met; ~80-120 LOC in MQL5
  management: TBD                             # n/a
  close: TBD                                  # bail-out-on-profit-open + hard stop + time-stop backstop
estimated_complexity: small                   # straightforward calendar + range arithmetic
estimated_test_runtime: 1-3h                  # P3 sweep cell count moderate (3×4×2×2×5×2×4×2 = 3,840 cells); D1 bars; ~10 trades/year/symbol
data_requirements: standard                   # D1 OHLC on Darwinex .DWX symbols; no external feeds
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
- 2026-04-28: SRC03_S02 surfaces a SECOND `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `gap-fade-stop-entry` — entry mechanism: gap THROUGH a calendar-pattern reference price (here:
  Friday's TRUE LOW or last-2-days low); stop-buy / stop-sell placed BACK at the reference
  price; entry fills when intra-session price recovers through the reference (fading the gap).
  Distinct from `n-period-min-reversion` (uses N-bar minimum as the entry, fires at next-bar
  open without a gap-through condition; Williams' rule REQUIRES a gap-through). Distinct from
  `intraday-day-of-month` (calendar-day-of-month bias, not weekday-after-weekday gap-fade).
  V4 had no equivalent SM_XXX EA per `strategy_type_flags.md` Mining-provenance table.
  Williams citation: PDF p. 39 (S&P) + p. 36 sub-rule B (Bonds analog).
  Together with SRC03_S01's `vol-expansion-breakout` proposal, the running SRC03 vocabulary-gap
  count is now TWO. Research will batch-propose with subsequent SRC03 findings.

- 2026-04-28: Williams' Bonds-Monday-buys composite ($79,200 / 69% accuracy / 0.81 RR on PDF p. 31)
  is RELATED BUT DISTINCT from Monday OOPS!. The Bonds composite is "buys on the opening every
  Monday if that opening is less than Fridays close" — a direct market-buy on the open; Monday
  OOPS! is a stop-buy AT Friday's TRUE LOW only when the open gaps BELOW Friday's TRUE LOW. The
  two patterns share the calendar gating (Mon-open-vs-Fri framing) but the trigger is different.
  Per BASIS rule, the $79,200 number is preserved as the source claim for the BONDS-MONDAY-BUYS-
  COMPOSITE in § 9 — NOT asserted as Monday-OOPS!-S&P performance. Pipeline P2-P9 produces the
  actual Monday-OOPS!-S&P edge.

- 2026-04-28: Symmetric short-side (sell on gap-above-Friday-TRUE-HIGH at Friday's TRUE HIGH stop)
  is V5 ablation, NOT verbatim Williams. Williams' workshop "Failure Day Family" (PDF p. 19)
  is structurally symmetric long/short, so the short-side mirror is consistent with his broader
  framing. P3 sweeps both sides; ablation result determines whether the strategy is best deployed
  symmetrically (`symmetric-long-short`) or long-only (`long-only`) — the calendar-asymmetric
  flow thesis (public-weekend-decisions are systematically bearish-biased, less so bullish)
  predicts the long side will dominate. Empirical verdict at P2/P3.

- 2026-04-28: 2020-03-09 COVID Monday is the canonical adverse case — Sunday-evening Saudi-
  Russian oil price war + COVID escalation produced a -7% S&P futures gap that did NOT reverse
  intra-day. P5c crisis-slice MUST include this date plus 2008-09 (Lehman week) and 2010-05
  (Flash Crash week). Hard-stop covers single-trade catastrophic loss; account-level kill-
  switch covers sequential adverse Mondays.

- 2026-04-28: Hidden OOPS! (PDF p. 40 § 2) is a STRUCTURALLY DISTINCT entry trigger using the
  projected-low formula `(H+L+C)/3 × 2 − H` instead of Friday's TRUE LOW. Lives in sister card
  `williams-hidden-oops` (S03 slot in SRC03 source.md § 6). Fold-vs-distinct decision was retained
  as DISTINCT — different reference price = different mechanical trigger, even though the
  thesis (gap-fade reversal) is shared.
```
