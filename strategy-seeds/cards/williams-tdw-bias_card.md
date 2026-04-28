# Strategy Card — Williams Trade Day of Week Bias (positive-day open-buy with first-profitable-open exit; Bonds + S&P)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim Bonds-context § "1.) TRADE DAY OF THE WEEK", PDF p. 33; verbatim S&P-context § "TRADE DAY OF THE WEEK", PDF p. 38).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S04
ea_id: TBD
slug: williams-tdw-bias
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - intraday-day-of-week                      # canonical match — weekday-of-week (Mon/Tue/Wed/Thu/Fri) calendar-cycle bias; sibling-of intraday-day-of-month, weekly cycle anchor (additive sibling, NOT generalize-rename — V4 Gotobi precedent on intraday-day-of-month preserved). CEO ratified 2026-04-28 in QUA-298 closeout (comment cc655c56); back-port QUA-334.
  - signal-reversal-exit                      # exit fires when "first profitable open" condition met — the bullish-signal that triggered entry has been reversed by a profitable close; falls within the signal-reversal exit family
  - atr-hard-stop                             # Williams: $3,500 S&P stop / no stop on basic Bonds table — V5 translation: ATR-equivalent hard stop
  - long-only                                 # Williams' tables show LONG-side performance only ("buying on the opening"); short-side bias is implicitly "fade the negative days" but Williams does NOT publish that table
  - friday-close-flatten                      # V5 default; Williams' "first profitable opening" exit caps holds at typically 1-3 sessions
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 33 (Inner Circle Workshop companion volume), § 'INSIDE CIRCLE SHORT TERM TRADING APPROACH — 1.) TRADE DAY OF THE WEEK' (Bonds context). Cross-reference: PDF p. 38 § 'S&P 500 TRADING RULES — TRADE DAY OF THE WEEK' (S&P context). Power-of-Gold variant: PDF p. 35 § 'THE POWER OF GOLD' (Bonds: TDW filtered by Gold-down-trend, win rates climb)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 163-176 (Bonds TDW table verbatim), lines 432-448 (S&P TDW table verbatim), lines 300-316 (Bonds TDW with Gold-filter variant). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **calendar-day-of-week directional bias** evaluated each trading-day open. Williams' empirical observation: certain weekdays exhibit systematic positive expectancy for long entries (Bonds: Mon/Tue/Fri; S&P: Mon/Tue) and systematic negative expectancy on others (Bonds: Wed/Thu; S&P: Wed/Fri). Buy at session open on positive-bias days; exit at first profitable open thereafter.

Williams' verbatim Bonds-context framing, PDF p. 33:

> "1.) TRADE DAY OF THE WEEK — The following table reflects buying on the opening of each trading day of the week and exiting on the first profitable opening. Note it is clear that some days are not so good, by [a]n large, for trading"

| DAY OF WEEK | +/- $ PROFITS | % WINS | AVERAGE $ TRADE |
|---|---|---|---|
| MONDAY | 41,568 | 79 | 83 |
| TUESDAY | 32,951 | 76 | 73 |
| WEDNESDAY | -18,615 | 73 | -37 |
| THURSDAY | -13,108 | 70 | -26 |
| FRIDAY | 14,426 | 73 | 30 |

> "There are 52 Monday opportunities a year for trading, 52 Tuesdays and 52 Fridays giving us a total of 156 potential trades. Maybe we should just feast[,] upon these!"

S&P-context cross-reference, PDF p. 38:

> "As with bonds, TDW, TDOM reveal a great deal to the short term trader[.] The first table reflects buying on the opening and exiting on the first profitable close with a $3,500 stop for every day of the week"

| DAY OF WEEK | $ PROFITS | % WINS | AVG $ TRADE |
|---|---|---|---|
| MONDAY | $169,810 | 71% | $230 |
| TUESDAY | 39,927 | 65% | (table OCR partial — see § 9 verbatim block) |
| WEDNESDAY | -33,842 | 65% | -39 |
| THURSDAY | -34,665 | 65% | -40 |
| FRIDAY | 30,592 | 63% | 35 |

(Note: PDF table OCR has alignment artifacts; verbatim numerics preserved per § 9 quote block. Wednesday is the strongest negative-bias day on S&P; Tuesday and Friday are weakly positive.)

This card extracts the **base mechanical entry** (open-buy on positive-bias weekdays, exit at first-profitable-open) with weekday-set as the parametrized switch covering Bonds-default, S&P-default, and the Power-of-Gold-filtered Bonds variant. Per DL-033 Rule 1, this is ONE card with the calendar-day vector as a parameter, NOT separate cards per weekday.

## 3. Markets & Timeframes

```yaml
markets:
  - bond_futures                              # Williams' primary deployment: T-Bonds (PDF p. 33). V5 proxy: bond CFD if Darwinex offers
  - index_futures                             # Williams' S&P deployment (PDF p. 38). V5 proxy: US500.DWX
  - forex                                     # Williams' broader pattern thesis is generic; CSR P3.5 validates breadth
  - commodities                               # idem
timeframes:
  - D1                                        # Williams: rules stated on daily bars; entry at session OPEN; exit at first profitable OPEN/CLOSE
session_window: cash_session                  # Williams' framing implies cash session (US Bond pit; CME S&P pit/electronic)
primary_target_symbols:
  - "T-Bonds futures (Williams' deployment) → bond CFD if available; flag dwx_suffix_discipline otherwise"
  - "S&P 500 futures (Williams' deployment) → US500.DWX V5 proxy"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF p. 33 (Bonds) and p. 38 (S&P) rules.

```text
PARAMETERS:
- BUY_DAYS          = [MON, TUE, FRI]         // Williams Bonds default (positive-bias weekdays)
                                              //   Williams S&P alternative: [MON, TUE]
                                              //   Variant Bonds + Gold filter: same set, with filter applied
- ENTRY_AT          = open                    // Williams: "buying on the opening of each trading day of the week"
- BAR               = D1

EACH-BAR (open trigger, evaluated at session open):
- if DayOfWeek(t) in BUY_DAYS:
    OPEN_LONG at Open[t]
- else:
    NO_TRIGGER
```

Power-of-Gold filter variant (Bonds-only per Williams' p. 35 framing):

```text
- BUY_DAYS_FILTERED = [MON, TUE, FRI]
- GOLD_FILTER       = Gold_Close[t-1] < Gold_Close[t-25]   // Williams: "buy require[s] that the closing price of Gold be less than 25 days ago"

EACH-BAR (open trigger):
- if DayOfWeek(t) in BUY_DAYS_FILTERED AND GOLD_FILTER:
    OPEN_LONG at Open[t]
- else: NO_TRIGGER
```

Williams' Bonds-with-Gold-filter table (PDF p. 35) shows win rates climb (Monday 79% → 84%, Tuesday 76% → 82%; verbatim numbers preserved in § 9). The Gold-filter variant is a P3 sweep axis on this card.

## 5. Exit Rules

Williams' explicit Bonds-context exit (PDF p. 33):

```text
DEFAULT EXIT (Bonds): bail-out at first profitable open
- if Open[t+k] > entry_price for k >= 1: CLOSE_LONG at Open[t+k]
- HARD_STOP_USD = NONE explicit on basic Bonds TDW table
                                   //   Williams' general short-term-trade convention is $1,500 (PDF p. 21 calling-card stop)
                                   //   V5 translation: ATR-equivalent hard stop, default ATR(14) × 2.0

S&P-context exit (PDF p. 38):
- exit at first profitable CLOSE (not open)
- HARD_STOP_USD = 3500             // Williams' S&P explicit
                                   //   V5 translation: ATR(14) × ~3 for US500.DWX

DEFAULT EXIT (V5 unified):
- bail-out at first profitable open   (more conservative than first-profitable-close; sweep axis)
- HARD_STOP_ATR_MULT = 2.0
- TIME_STOP = 5 bars (backstop)        // Williams does not specify; 5-bar backstop prevents
                                       //   indefinite holds on losing day-of-week entries

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP-equivalent ATR distance from entry; never moves
- BAIL_OUT_ON_PROFIT_OPEN: if Open[t+1] > entry_price: CLOSE_LONG at Open[t+1]
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies. TDW entries on Fri/Mon/Tue with first-profitable-open exit
typically resolve within 1-3 sessions; Friday-close rarely binds. If Mon entry doesn't profit
by Friday, time-stop forces flat. No waiver required.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one open position per direction; cannot stack day-of-week entries)
- gridding: NOT allowed
- BUY_DAYS gating: only enter on positive-bias weekdays per § 4
- Gold-filter (OPTIONAL P3 sweep axis, Bonds-context):
    Gold_Close[t-1] < Gold_Close[t-25]
  Off by default for non-Bonds symbols; on-by-default-on-Bonds variant tested in P3
- "month-of-year" filter (OPTIONAL P3 sweep axis): some calendar-day biases interact with seasonal
  factors (e.g., Williams documents "best short-term buy days of the year" combining month + day,
  PDF pp. 42-43; that is the S05 TDOM card territory, but TDW + month-of-year combinations may
  show edge — sweep axis variant)
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- Williams' tables assume a NEW entry every positive-bias day — if prior day's position has not
  yet hit first-profitable-open exit, the new day's entry is SUPPRESSED to honor V5
  one_position_per_magic_symbol Hard Rule. P3 ablation tests "stacked entries" variant under
  V5 grid_1pct_cap waiver if data warrants.
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: buy_days
  default: [MON, TUE, FRI]                    # Williams Bonds default — strongest cumulative positive expectancy
  sweep_range:
    - [MON, TUE, FRI]                         # Bonds full set
    - [MON, TUE]                              # S&P set — Williams' top-2 positive-edge weekdays
    - [MON]                                   # single-day Monday-only
    - [MON, TUE, WED, THU, FRI]               # all-days ablation (control)
- name: exit_at
  default: profit_open                        # Bonds-context Williams
  sweep_range: [profit_open, profit_close]    # S&P-context uses profit_close
- name: hard_stop_atr_mult
  default: 2.0                                # ATR-equivalent of Williams' Bonds-implicit / S&P-explicit $3,500
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: time_stop_bars
  default: 5
  sweep_range: [3, 5, 7, 10]
- name: gold_filter
  default: off                                # off-by-default for cross-symbol generalization
  sweep_range: [off, gold_below_25d, gold_below_15d]
- name: enable_shorts                         # Williams does NOT publish a short-side table for negative-bias days; ablation only
  default: false
  sweep_range: [false, true]                  # symmetric ablation: short on Wed/Thu (Bonds) or Wed/Fri (S&P)
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. The bond-context calendar-day biases (Mon/Tue/Fri positive, Wed/Thu negative) are documented for **CME T-Bonds futures** specifically; whether they generalize to:
- Index CFDs: US500.DWX (Williams' S&P table is closest analog), US100.DWX, GER40.DWX, UK100.DWX
- Spot FX: EURUSD.DWX, USDJPY.DWX, GBPUSD.DWX (FX day-of-week effects are documented in Lien — SRC04 — and may differ from US-Bonds biases)
- Metals: GOLD.DWX, XAGUSD.DWX

is the CSR question. Expected: pattern is partly **time-zone-dependent** (US Bonds biases are NY-session-specific); cross-time-zone instruments may show different biases.

## 9. Author Claims (verbatim, with quote marks)

Bonds TDW table, PDF p. 33:

> "1.) TRADE DAY OF THE WEEK — The following table reflects buying on the opening of each trading day of the week and exiting on the first profitable opening. Note it is clear that some days are not so good, by [a]n large, for trading
>
> DAY OF WEEK   +/-$ PROFITS    % WINS    AVERAGE $ TRADE
>
> MONDAY         41,568           79         83
> TUESDAY        32,951           76         73
> WEDNESDAY     -18,615           73        -37
> THURSDAY      -13,108           70        -26
> FRIDAY         14,426           73         30
>
> There are 52 Monday opportunities a year for trading, 52 Tuesdays and 52 Fridays giving us a total of 156 potential trades. Maybe we should just feast[,] upon these!"

Bonds TDW with Power-of-Gold filter, PDF p. 35:

> "If we do this same study above but buy require that the closing price of Gold be less than 25 days ago we notice the following results;
>
> DAY OF WEEK    +/- $ PROFITS    %WINS    $ +/- AV. TRADE
>
> MONDAY         25,883            84       187
> TUESDAY        31,168            82       222
> WEDNESDAY      1,037             74       7
> THURSDAY       8,825             76       53
> FRIDAY         22,075            81       133"

(Note: Williams' Gold-filter table reduces total trades but materially boosts per-day win rates — Monday 79% → 84%, Tuesday 76% → 82%, even Wed/Thu flip from negative to small-positive expectancy.)

S&P TDW table, PDF p. 38:

> "As with bonds, TDW, TDOM reveal a great deal to the short term trader[.] The first table reflects buying on the opening and exiting on the first profitable close with a $3,500 stop for every day of the week
>
> MONDAY     $169,810   71%   $230
> TUESDAY     39.927    65    50
> WEDNESDAY  -33,842    65   -39
> THURSDAY   -34,665    65   -40
> FRIDAY      30,592    63    35"

(Note: source PDF table OCR shows artifacts in column alignment; the Monday-S&P $169,810 / 71% / $230 numbers are unambiguous from context. Tuesday/Wednesday/Thursday/Friday numbers preserved verbatim.)

**Verbatim performance numbers preserved per BASIS rule.** No extrapolated number is asserted; pipeline P2-P9 produces actual edge measurement on Darwinex .DWX symbols.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.4                              # rough estimate; Williams' high win-rate on positive-bias days (71-79%) + bail-out exit suggests favorable PF — Bonds composite +$70k profits / $42k losses = ~1.7 PF. Discount for cross-symbol generalization.
expected_dd_pct: 12                           # rough estimate; high win-rate + bail-out exit = tight DD profile
expected_trade_frequency: 80-150/year/symbol  # 3 positive-bias days/week × ~50 weeks × any-direction = ~150/year if all days fire
risk_class: low                               # short-hold systematic-day-bias entries with bail-out + ATR stop
gridding: false
scalping: false                               # D1 trigger
ml_required: false                            # day-of-week classification + threshold; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (DayOfWeek check + open-buy + first-profitable-open exit)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1)
- [x] Friday Close compatibility: 1-3 day typical hold; Friday-close rarely binds; default V5 applies
- [x] Source citation is precise enough to reproduce (PDF p. 33 Bonds + p. 38 S&P + p. 35 Gold-filter; verbatim tables in § 9)
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "BUY_DAYS day-of-week gate + standard V5 default; optional Gold-filter and month-of-year filter as P3 sweep axes"
  trade_entry:
    used: true
    notes: "open-buy on positive-bias weekdays; one position per direction"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "bail-out at first profitable open (or close — sweep axis) + ATR-equivalent hard stop + time-stop backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY — Williams' deployment is CME futures; V5 maps to .DWX. Pattern's time-zone-dependent biases require CSR P3.5 cross-symbol validation.
  - friday_close                              # NOT load-bearing — short-hold strategy with bail-out exit
  - news_pause_default                        # standard V5 P8 news-blackout applies; high-impact macro events (FOMC, NFP) cluster on specific weekdays which would skew TDW signal — P8 handles natively
  - one_position_per_magic_symbol             # NOT load-bearing — single position per direction; positive-bias-day overlap suppressed via § 7

at_risk_explanation: |
  dwx_suffix_discipline — Williams' tables are CME T-Bonds + CME S&P 500 futures. V5 deploys
  on Darwinex .DWX CFDs. Day-of-week effects can be partly time-zone-driven (NY-session-specific
  flow patterns); CSR P3.5 validates whether pattern survives across spot FX (24/5 trading) and
  cross-time-zone CFDs (DAX, FTSE, Nikkei).

  friday_close — Default V5 applies cleanly. 1-3 day hold typical.

  news_pause_default — High-impact macro events (FOMC Wednesdays, NFP Fridays, ECB Thursdays)
  cluster on specific weekdays. The TDW pattern's Wed/Thu negative-bias may PARTLY reflect
  scheduled-news clustering. P8 news-blackout handles event-windows natively; whether the
  underlying pattern persists OUTSIDE news windows is a P8 ablation question.

  one_position_per_magic_symbol — single position per direction at a time; if Mon entry hasn't
  hit profit-open exit by Tuesday, Tuesday entry is SUPPRESSED to honor V5 Hard Rule. P3
  ablation tests "stacked entries" variant under V5 grid_1pct_cap waiver if data warrants.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # BUY_DAYS gate + standard V5 + optional filters
  entry: TBD                                  # session-open open-buy on positive-bias days; ~50-80 LOC in MQL5
  management: TBD                             # n/a
  close: TBD                                  # first-profitable-open bail-out + ATR hard stop + time-stop backstop
estimated_complexity: small                   # day-of-week + bail-out logic
estimated_test_runtime: 1-3h                  # P3 sweep cell count moderate (4×2×5×4×3×2 = 960 cells); D1 bars; ~150 trades/year/symbol
data_requirements: standard                   # D1 OHLC on Darwinex .DWX symbols; Gold-filter variant requires GOLD.DWX OHLC
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
- 2026-04-28: SRC03_S04 reuses the EXISTING `intraday-day-of-month` flag for a WEEKLY-cycle
  pattern — strict reading of the flag definition ("entry triggered or biased by recurring
  calendar dates of the month") is monthly-cycle. TDW is weekly-cycle. Whether
  `intraday-day-of-month` should be RENAMED to `calendar-cycle-bias` (covering both weekly and
  monthly cycles) OR a sister flag `intraday-day-of-week` should be added is a vocabulary-
  refinement question for CEO + CTO ratification. Proposed batch with the SRC03_S01/S02/S07
  vocabulary gaps. Per `strategy_type_flags.md` § A definition explicitly lists "5/10/15/20/25
  dates" as Gotobi example — date-of-month framing — so TDW is structurally adjacent but not
  identical. Recommendation: add sister flag `intraday-day-of-week` to disambiguate.

- 2026-04-28: P8 News-blackout interaction is an OPEN QUESTION for this card. Williams' Wed/Thu
  negative-bias on Bonds may PARTLY reflect FOMC-Wednesday + ECB-Thursday clustering. P8
  ablation: does the TDW pattern survive when scheduled-high-impact-news days are excluded?
  If pattern collapses post-news-removal, the strategy is news-driven (and `news_pause_default`
  is load-bearing rather than incidental).

- 2026-04-28: Williams does NOT publish short-side TDW tables. The Wed/Thu negative-expectancy
  (Bonds) and Wed/Fri negative-expectancy (S&P) are documented but Williams does not propose
  fading them. Card flags `enable_shorts: false` as default with sweep-axis ablation — an
  open empirical question whether the negative-bias-day SHORT entry produces edge or merely
  symmetric mean-reversion-back-to-zero.

- 2026-04-28: Power-of-Gold filter (Bonds-only) materially boosts Williams' published win
  rates — Mon 79% → 84%, Tue 76% → 82%, even Wed/Thu flip from net-negative to small-positive.
  This is one of the few Williams-published "filter-improves-system" examples with concrete
  win-rate uplift. P3 sweep axis includes Gold-filter ON for Bonds; OFF for non-Bonds (since
  Gold-Bonds correlation is the underlying mechanism per Williams p. 35).
```
