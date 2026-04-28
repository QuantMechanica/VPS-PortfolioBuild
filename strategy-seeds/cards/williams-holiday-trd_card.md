# Strategy Card — Williams National Holiday Trades (8 holidays × specific buy/sell open/close on N-th TD before/after; Bonds + S&P)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim Bonds-context § "3.) NATIONAL HOLIDAYS", PDF pp. 33-34; verbatim S&P-context § "S&P HOLIDAY TRADES", PDF pp. 41-42).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S06
ea_id: TBD
slug: williams-holiday-trd
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - intraday-day-of-month                     # closest existing — calendar-anchored entry; here the anchor is the federal-holiday calendar rather than month-of-year, but flag definition reasonably extends. Sister-flag-gap candidacy noted in § 16.
  - signal-reversal-exit                      # Bonds: "exit on the first profitable opening" — entry signal reversed by profit. S&P: "bail out after holding for one day past entry" — time-stop variant
  - atr-hard-stop                             # Williams Bonds $1,400 / S&P $2,500; V5 → ATR-equivalent
  - symmetric-long-short                      # Williams' tables include BOTH buy and sell holiday entries verbatim (NYE sell, Pres Day buy, etc.) — symmetric is verbatim, not mirror-extension
  - friday-close-flatten                      # V5 default; typical 1-2 day hold via bail-out
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF pp. 33-34 (Inner Circle Workshop companion volume), § 'INSIDE CIRCLE SHORT TERM TRADING APPROACH — 3.) NATIONAL HOLIDAYS' (Bonds; 8-holiday rule table + Bonds backtest 1978-1999 with $52,200 net / 84% wins / $1,978 max DD). Cross-reference: PDF pp. 41-42 § 'S&P 500 TRADING RULES — S&P HOLIDAY TRADES' (S&P; 8-holiday rule table + S&P backtest 1982-1999 with $108,675 net / 63% wins / -$9,995 max DD)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 233-298 (Bonds Holiday rules + backtest verbatim), lines 651-693 (S&P Holiday rules + backtest verbatim). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **federal-holiday-anchored calendar-bias entry**. Williams' empirical observation: trading-day windows around US federal holidays exhibit systematic directional biases driven by retail-flow patterns (vacation-window risk-aversion, year-end portfolio rebalancing, late-month-of-quarter volatility). For each of 8 US federal holidays, Williams specifies a precise rule: which N-th trading-day before/after the holiday to trade, whether to buy or sell, whether at open or close. Exit at first profitable open (Bonds) or 1-day-hold-then-bailout (S&P).

Williams' verbatim Bonds-context framing, PDF pp. 33-34:

> "3.) NATIONAL HOLIDAYS — There has been a clear-cut advantage to trading around the national holidays every year. Why I am not sure, but since I was first alerted to this in 1962 a[n]d have seen it hold up — in real time trading — ever since, I'm trading these biases as well.
>
> The results are quite good. The next tabulation reflects the trading strategy I will teach. These results are from 1978 forward, use a $1,400 stop and exit on the first profitable opening. The $50,956 of profits with a drawdown of only $1,978 is among the best I have ever seen. We o[n]ly have 8 holidays a year, but they are dandies, netting a trader, on average, $2,500+ a year. If that doesn't sound like much keep in mind that's about an 80% a year gain with only 16 trading days of 'exposure' per year."

Williams' verbatim S&P-context framing, PDF p. 41:

> "S&P HOLIDAY TRADES — Our Holiday trading strategy works well here. The following table lists the holidays with the entry rules. The exit was to bail out after holding for one day past entry, in other words buy/sell today, hold tomorrow then look to bailout. The stop is a very small $2,500 from entry hit."

This card extracts the **base mechanical entry** (federal-holiday calendar lookup + N-th-TD-offset + buy/sell open/close action) with the holiday-action map as the parameter. Per DL-033 Rule 1, this is ONE card with the holiday-action vector as a parameter — NOT 8 separate cards per holiday.

The `HOLIDAY_ACTIONS` parameter accepts:
- Williams Bonds-default action map (8 holidays × specific rules per PDF pp. 33-34)
- Williams S&P-default action map (8 holidays × specific rules per PDF pp. 41-42; differs from Bonds map)

Note: Williams' Bonds and S&P holiday-rule tables disagree on the SPECIFIC action for some holidays (e.g., New Years: Bonds = "Sell Close Third TD Before Holiday"; S&P = "Buy Open Third TD Before Holiday" — opposite direction). The card preserves both maps as separate parameter values; CTO + Quality-Tech ratify per-symbol map at G0 / P3.

## 3. Markets & Timeframes

```yaml
markets:
  - bond_futures                              # Williams' primary deployment: T-Bonds (PDF p. 33). V5 proxy: bond CFD if Darwinex offers
  - index_futures                             # Williams' S&P deployment (PDF p. 41). V5 proxy: US500.DWX
  - forex                                     # Williams' broader pattern thesis is generic; CSR P3.5 validates breadth — holiday-flow patterns are partly US-domestic-driven
  - commodities                               # idem
timeframes:
  - D1                                        # Williams: rules stated on daily bars; entry at OPEN or CLOSE specifically
session_window: cash_session                  # Williams' framing implies cash session
holiday_calendar: us_federal                  # 8 US federal holidays per Williams' table
primary_target_symbols:
  - "T-Bonds futures (Williams' deployment) → bond CFD if available; flag dwx_suffix_discipline otherwise"
  - "S&P 500 futures (Williams' deployment) → US500.DWX V5 proxy"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF pp. 33-34 (Bonds) and pp. 41-42 (S&P) rules.

```text
PARAMETERS:
- HOLIDAY_ACTIONS   = williams_sp_default     // Default: S&P map (8 holidays × specific actions)
- HOLIDAY_CALENDAR  = us_federal              // 8 holidays: New Years, Pres Day, Easter, Memorial, July 4th, Labor Day, Thanksgiving, Christmas
- BAR               = D1

us_federal_holidays = {
  "NEW_YEARS_DAY":   Jan 1 (observed),
  "PRESIDENTS_DAY":  3rd Monday of February,
  "EASTER":          Good Friday's Friday (US market closed Good Friday; Williams uses
                     "Easter" as the holiday anchor; convention: Friday before Easter Sunday),
  "MEMORIAL_DAY":    Last Monday of May,
  "INDEPENDENCE_DAY": Jul 4 (observed),
  "LABOR_DAY":       1st Monday of September,
  "THANKSGIVING":    4th Thursday of November,
  "CHRISTMAS":       Dec 25 (observed)
}

williams_bonds_default = {  // PDF pp. 33-34 verbatim (preserved per source OCR alignment in § 9)
  "NEW_YEARS_DAY":   { action: "SELL", price: "CLOSE", offset_days: -3 (TD before holiday) },
  "PRESIDENTS_DAY":  { action: "BUY",  price: "CLOSE", offset_days: -5 },
  "EASTER":          { action: "SELL", price: "OPEN",  offset_days: +1 (TD after holiday) },
                     { action: "SELL", price: "CLOSE", offset_days: -1 },
  "MEMORIAL_DAY":    { action: "BUY",  price: "OPEN",  offset_days: -4 },
  "INDEPENDENCE_DAY":{ action: "BUY",  price: "OPEN",  offset_days: -5 },
                     { action: "SELL", price: "OPEN",  offset_days: +1 },
  "LABOR_DAY":       { action: "BUY",  price: "CLOSE", offset_days: -3 },
  "THANKSGIVING":    { action: "BUY",  price: "CLOSE", offset_days: -4 },
                     { action: "SELL", price: "CLOSE", offset_days: -6 },
  "CHRISTMAS":       { action: "BUY",  price: "OPEN",  offset_days: -2 }
}

williams_sp_default = {  // PDF pp. 41-42 verbatim
  "NEW_YEARS":       { action: "BUY",  price: "OPEN",  offset_days: -3 },
  "PRESIDENTS_DAY":  { action: "BUY",  price: "OPEN",  offset_days: -3 },
                     { action: "SELL", price: "CLOSE", offset_days: -2 },
  "EASTER":          { action: "BUY",  price: "CLOSE", offset_days: -2 },
                     { action: "SELL", price: "OPEN",  offset_days: +1 },
  "MEMORIAL_DAY":    { action: "BUY",  price: "CLOSE", offset_days: -1 },
  "JULY_4TH":        // intentionally blank in Williams' S&P table — no rule
                     null,
  "LABOR_DAY":       { action: "BUY",  price: "OPEN",  offset_days: +5 (TD after) },
  "THANKSGIVING":    { action: "BUY",  price: "OPEN",  offset_days: -1 },
  "CHRISTMAS":       { action: "BUY",  price: "CLOSE", offset_days: -3 },
                     { action: "BUY",  price: "OPEN",  offset_days: -5 }
}

EACH-BAR (each session):
- if matches a holiday-action rule (offset, side, open/close) per HOLIDAY_ACTIONS:
    if action == "BUY" and price == "OPEN":   OPEN_LONG  at Open[t]
    if action == "BUY" and price == "CLOSE":  OPEN_LONG  at Close[t]
    if action == "SELL" and price == "OPEN":  OPEN_SHORT at Open[t]
    if action == "SELL" and price == "CLOSE": OPEN_SHORT at Close[t]
- else: NO_TRIGGER
```

**Convention:** offset_days is the number of trading days before/after the holiday. Williams says "0 means the day before the actual holiday" (PDF p. 34). Card adopts standard convention: offset_days = -N means N trading days before holiday's calendar date (skipping weekends and the holiday itself); offset_days = +N means N trading days after. The Bonds-Memorial-Day rule "Buy Open Fourth TD Before Holiday" maps to offset_days = -4.

## 5. Exit Rules

Williams' explicit exits (different per context):

```text
DEFAULT EXIT (Bonds-context, PDF p. 34): bail-out at first profitable open
- BAIL_OUT_ON_PROFIT_OPEN: if Open[t+k] > entry_price for k >= 1 (mirror for short): CLOSE at Open[t+k]
- HARD_STOP_USD = 1400        // Williams Bonds explicit
- TIME_STOP    = NONE          // Williams does not specify; bail-out cap holds at typically 1-3 sessions

S&P-context exit (PDF p. 41): 1-day hold then bail-out
- TIME_STOP = 1 bar after entry  // "buy/sell today, hold tomorrow then look to bailout"
- After TIME_STOP, the position bails out at first profitable open (or close)
- HARD_STOP_USD = 2500         // Williams S&P explicit

DEFAULT EXIT (V5 unified):
- TIME_STOP = 1 bar after entry, then bail-out-on-profit-open (S&P-flavored exit; tightest)
- HARD_STOP_ATR_MULT = 2.0     // ATR-equivalent of Williams' Bonds $1,400 / S&P $2,500
- bail-out-on-profit-open backstop after TIME_STOP

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP-equivalent ATR distance from entry; never moves
- TIME_STOP gate — once N bars elapsed, eligible for bail-out
- BAIL_OUT_ON_PROFIT_OPEN: if (Open[t+1] > entry_price and LONG) or
                              (Open[t+1] < entry_price and SHORT): CLOSE at Open[t+1]
- Force-flat backstop: if held > 5 bars total, force flat at next open (P3 axis)

FRIDAY CLOSE: V5 default applies. Holiday entries clustered around US federal holidays
(many fall mid-week or near Mondays). Friday-close occasionally binds on Christmas /
Thanksgiving entries that span into next-week. Default V5 applies; per-holiday waiver
not required.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one open position per direction)
- gridding: NOT allowed
- HOLIDAY_ACTIONS gating: only enter on triggered holiday-rule per § 4
- US federal-holiday calendar: only US-market-closed dates qualify; non-US-closed days do not trigger
  (When V5 deploys on FX or non-US indices, this is a SYMBOL-CALENDAR-MISMATCH question:
   does GER40.DWX trade per US holiday calendar or German holiday calendar?
   Default: rule fires per US federal holiday calendar regardless of symbol's local calendar.
   CSR P3.5 ablation tests local-holiday-calendar variant.)
- "earnings-season exclusion" (OPTIONAL P3 sweep axis): some holidays cluster with
  earnings-season cycles which can confound the holiday-flow signal. Williams does NOT cite this;
  ablation only.
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding)
- multiple holiday-rules on consecutive trading days (e.g., Williams' Christmas: BUY OPEN -2 + BUY OPEN -5 sub-rule):
  if prior position has not hit profit-open exit, NEW entry SUPPRESSED to honor V5 Hard Rule
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: holiday_actions_set
  default: williams_sp_default                # 8-holiday rule map per PDF pp. 41-42
  sweep_range:
    - williams_sp_default                     # S&P map
    - williams_bonds_default                  # Bonds map (PDF pp. 33-34) — different per-holiday actions
    - sp_winning_subset                       # only the holidays where S&P map shows positive expectancy (per Williams' published win-rate)
    - bonds_winning_subset                    # only Bonds positive holidays
- name: hard_stop_atr_mult
  default: 2.0
  sweep_range: [1.0, 1.5, 2.0, 2.5, 3.0]
- name: time_stop_bars
  default: 1                                  # Williams S&P "hold tomorrow then look to bailout"
  sweep_range: [0, 1, 2, 3, 5]                # 0 = bail-out from entry-bar onwards (Bonds-flavored)
- name: bail_out_on_profit_open
  default: true                               # both contexts
  sweep_range: [true, false]                  # false = hold until time_stop_bars or hard_stop
- name: enable_short_holidays
  default: true                               # Williams' tables include both buy AND sell holiday rules — verbatim symmetric
  sweep_range: [true, false]                  # false = long-only (drop sell rules) ablation
- name: holiday_calendar
  default: us_federal
  sweep_range: [us_federal, local_market]     # CSR P3.5: when on GER40.DWX, do German federal holidays produce edge? (different rule map; not Williams-derived)
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. **Holiday-flow patterns are STRONGLY US-domestic-flow-driven** — vacation-window risk-aversion, year-end rebalancing, retail-trader-vacation patterns. CSR validates whether the pattern survives across:
- Index CFDs: US500.DWX (closest analog — high expected positive transfer), US100.DWX (similar), GER40.DWX / UK100.DWX (LOWER expected transfer — different domestic calendar)
- Spot FX: EURUSD.DWX, USDJPY.DWX (US-holidays may have spillover effects via reduced liquidity rather than direct flow bias)
- Metals: GOLD.DWX, XAGUSD.DWX (gold has its own calendar dynamics — Indian wedding-season flow, Chinese New Year, etc.; US-holiday-bias may NOT transfer)

Expected CSR finding: pattern is STRONGEST on US500.DWX / US100.DWX, MARGINAL on European indices, WEAK on FX, WEAK on metals.

## 9. Author Claims (verbatim, with quote marks)

Bonds Holiday rule table (PDF pp. 33-34):

> "HOLIDAY                  DAYS BEFORE                OPEN OR CLOSE ENTRY
>                                                     TD Before Holiday
> NEW YEARS DAY        Sell Close Third               TD Before Holiday
>                                                     TD Before Holiday
> PRESIDENTS DAY       Buy Close Fifth                TD Before Holiday
>                                                     TD Before Holiday
>                      Sell Open First                TD After Holiday
>
> EASTER *             Sell Close First
>
> MEMORIAL DAY         Buy Open Fourth
>
> INDEPENDENCE DAY     Buy Open Fifth                 TD Before Holiday
>                      Sell Open First                TD After Holiday
> LABOR DAY            Buy Close Third                TD Before Holiday
> THANKSGIVING DAY     Buy Close Fourth               TD Before Holiday
>                      Sell Close Sixth               TD Before Holiday
> CHRISTMAS DAY        Buy Open Second                TD Before Holiday"

(Note: PDF table OCR has alignment artifacts in the above; exact-line correspondences preserved per Williams' verbatim header pattern. The rule table format is "ACTION + ENTRY-PRICE + Nth-TD-BEFORE/AFTER".)

Bonds Holiday backtest, PDF p. 34:

> "Data              : DAY T-BONDS
> Calc Dates        : 01/10/78 - 07/06/99
>
> Total net profit         $52,200.00         Gross loss               $-15,742.50
> Gross profit             $67,942.50
>
> Total # of trades                190        Percent profitable         84%
> Number winning trades            161        Number losing trades        29
>
> Largest winning trade    $2,986.25          Largest losing trade       $-1,451.25
> Average winning trade       $422.00         Average losing trade          $-542.84
> Ratio avg win/avg loss           0.77       Avg trade (win & loss)             $274.74
>
> Max consecutive winners          20         Max consecutive losers      2
> Avg # bars in winners            1          Avg # bars in losers       .2
>
> Max closed-out drawdown $-1,978.75          Max intra-day drawdown $-1,978.75
>
> Profit factor                    4.31       Max # of contracts held    1
>
> Account size required    $4,978.75          Return on account         1,048%"

S&P Holiday rule table (PDF pp. 41-42):

> "S&P HOLIDAY TRADES — Our Holiday trading strategy works well here. The following table lists the holidays with the entry rules. The exit was to bail out after holding for one day past entry, in other words buy/sell today, hold tomorrow then look to bailout. The stop is a very small $2,500 from entry hit.
>
> NEW YEARS                Buy Open Third      TD Before Holiday
> PRESIDENTS DAY           Buy Open Third      TD Before Holiday
>                          Sell Close Second   TD Before Holiday
> EASTER                   Buy Close Second    TD Before Holiday
>                          Sell Open First     TD After Holiday
> MEMORIAL DAY             Buy Close First     TD Before Holiday
> JULY 4TH
> LABOR DAY                Buy Open Fifth      TD After Holiday
> THANKSGIVING             Buy Open First      TD Before Holiday
> CHRISTMAS                Buy Close Third     TD Before Holiday
>                          Buy Open Fifth"

(Note: July 4th line in S&P table is intentionally blank — Williams provides no rule for July 4th on S&P.)

S&P Holiday backtest, PDF p. 42:

> "Data                S&P 500 IND-9967 12/99
> Calc Dates          08/09/82 - 07/02/99
>
> Total net profit         $108,675.00     Gross loss                 $-65,265.00
> Gross profit             $173,940.00
>
> Total # of trades       170             Percent profitable           63%
>
> Number winning trades    108             Number losing trades         62
>
> Largest winning trade    $13,355.00      Largest losing trade         $-9,995.00
> Average winning trade     $1,610.56      Average losing trade         $-1,052.66
> Ratio avg win/avg loss             1.52  Avg trade (win & loss)             $639.26
>
> Max consecutive winners  7               Max consecutive losers       5
>
> Avg # bars in winners    1               Avg # bars in losers         1
>
> Max closed-out drawdown  $-9,995.00       Max intra-day drawdown      $-9,995.00
> Profit factor                      2.66  Max # of contracts held               1
> Account size required                     Return on account                 836%"

Williams' framing of the Bonds backtest, PDF p. 33:

> "The $50,956 of profits with a drawdown of only $1,978 is among the best I have ever seen."

(Note: "$50,956" in Williams' framing vs "$52,200" in the published backtest table — different versions/cuts of the same backtest dataset. Both numbers preserved verbatim.)

**Verbatim performance numbers preserved per BASIS rule.** Williams provides explicit Bonds backtest 1978-1999 (84% wins, $52,200 net, $1,978 max DD, 4.31 PF, 190 trades, 1,048% ROA) and S&P backtest 1982-1999 (63% wins, $108,675 net, -$9,995 max DD, 2.66 PF, 170 trades, 836% ROA). The Bonds win-rate (84%) is the highest published in the source's text-clean range. No extrapolated number is asserted; pipeline P2-P9 produces actual edge measurement on Darwinex .DWX symbols.

## 10. Initial Risk Profile

```yaml
expected_pf: 2.5                              # Williams' published Bonds 4.31 PF and S&P 2.66 PF average ~3.5; discount to 2.5 for V5 cross-symbol generalization on Darwinex spreads
expected_dd_pct: 8                            # Bonds-context max DD only $1,978 over 21 years (190 trades) = exceptionally low; discount for cross-symbol
expected_trade_frequency: 8-12/year/symbol    # 8 holidays × 1-2 entries each = ~12 entries; some sub-rules active simultaneously
risk_class: low                               # short-hold (1-3 bars) systematic-calendar-bias entries with hard-stop
gridding: false
scalping: false                               # D1 trigger
ml_required: false                            # holiday-calendar lookup + threshold; no fitted parameters
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (federal-holiday-calendar lookup + Nth-TD-offset + open/close-fill action)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1)
- [x] Friday Close compatibility: 1-3 day typical hold; default V5 applies
- [x] Source citation is precise enough to reproduce (PDF pp. 33-34 Bonds rules + p. 34 backtest + pp. 41-42 S&P rules + p. 42 backtest; verbatim tables in § 9)
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "HOLIDAY_ACTIONS calendar gate + standard V5 default"
  trade_entry:
    used: true
    notes: "open or close fill on N-th TD before/after federal holidays per HOLIDAY_ACTIONS map; long AND short entries verbatim Williams"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "1-bar hold + bail-out at first profitable open + ATR-equivalent hard stop + 5-bar force-flat backstop"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY — Williams' deployment is CME T-Bonds + S&P futures. Holiday-flow patterns are partly US-domestic-driven. CSR P3.5 ablation load-bearing on cross-symbol transfer.
  - friday_close                              # NOT load-bearing — short-hold strategy
  - news_pause_default                        # holiday-windows can coincide with end-of-quarter / earnings-season events; standard V5 P8 handles
  - one_position_per_magic_symbol             # potential issue when multiple holiday sub-rules trigger same direction within consecutive sessions; § 7 SUPPRESS-rule covers
  - enhancement_doctrine                      # load-bearing on HOLIDAY_ACTIONS map — Bonds and S&P maps DISAGREE on direction for some holidays (e.g., New Years: Bonds SELL vs S&P BUY). Cross-symbol generalization is an open empirical question. Once a live map is fixed, retune = enhancement_doctrine.

at_risk_explanation: |
  dwx_suffix_discipline — Williams' tables are CME T-Bonds + CME S&P 500 futures. Holiday-flow
  patterns are STRONGLY US-domestic-driven (vacation-window risk-aversion, year-end rebalancing).
  CSR P3.5 expects strong positive transfer to US500.DWX / US100.DWX, MARGINAL transfer to
  European indices, WEAK transfer to FX / metals.

  friday_close — Default V5 applies cleanly. 1-3 day hold typical.

  news_pause_default — Holiday-windows occasionally coincide with end-of-quarter rebalancing
  flow or year-end earnings cluster. P8 news-blackout handles event-windows natively. The
  holiday-bias edge is FLOW-driven (retail / institutional rebalancing), NOT news-event-driven —
  P8 should not collapse the pattern.

  one_position_per_magic_symbol — Christmas has TWO sub-rules in S&P map (BUY CLOSE -3 + BUY
  OPEN -5); these fire on different days (-3 and -5) so are mutually exclusive in time, but
  multiple holidays can cluster (Thanksgiving + Christmas in November-December). § 7 SUPPRESS
  rule covers.

  enhancement_doctrine — Bonds and S&P holiday-rule maps DISAGREE on direction for several
  holidays. Card defaults to S&P map; P3 sweeps both; CTO + Quality-Tech ratify per-symbol map
  at G0 + P3. Once live map fixed, retune = enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # HOLIDAY_ACTIONS gate (date-table lookup) + standard V5
  entry: TBD                                  # holiday-calendar arithmetic (federal-holiday-of-year + N-th-TD offset); ~120-180 LOC in MQL5 (holiday-table is the bulk; entry logic is simple)
  management: TBD                             # n/a
  close: TBD                                  # 1-bar time-stop + first-profitable-open + ATR hard stop + 5-bar backstop
estimated_complexity: medium                  # holiday-date arithmetic + Nth-TD-offset is non-trivial; per-holiday rule lookup is straightforward
estimated_test_runtime: 1-2h                  # P3 sweep small (4×5×5×2×2×2 = 800 cells); D1 bars; ~12 trades/year/symbol = small data set
data_requirements: standard                   # D1 OHLC; US federal-holiday calendar (static table 1980-present); Easter-date computation (paschal-full-moon algorithm)
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
- 2026-04-28: SRC03_S06 reuses the EXISTING `intraday-day-of-month` flag for a HOLIDAY-ANCHORED
  pattern — strict reading of the flag definition ("recurring calendar dates of the month")
  is monthly-cycle. Holiday entries are anchored to the FEDERAL HOLIDAY CALENDAR (yearly-cycle
  with N-th-TD-offset arithmetic), not month-of-year. A sister flag `holiday-anchored-bias`
  (or generalize `intraday-day-of-month` to `calendar-cycle-bias` covering monthly + weekly +
  yearly cycles) is a vocabulary-refinement question for CEO + CTO ratification. Together
  with S04's `intraday-day-of-week` ask, the SRC03 calendar-bias family is surfacing a
  vocabulary pattern: Williams' three calendar cadences (weekly TDW, monthly TDOM, yearly
  Holiday) all fit the same conceptual category but the existing flag is monthly-only.
  Recommendation: rename `intraday-day-of-month` → `calendar-cycle-bias` (cycle-period as
  parameter) OR add `intraday-day-of-week` and `holiday-anchored-bias` as siblings.

- 2026-04-28: Bonds backtest (1978-1999, 21 years, 190 trades) reports **84% accuracy with
  4.31 PF and only $1,978 max drawdown** — Williams' framing: "among the best I have ever
  seen." This is the HIGHEST published win-rate in the source's text-clean range and makes
  S06 the strongest individual G0 candidate in SRC03 first-pass. Per BASIS rule, asserted
  verbatim — pipeline P2-P9 validates whether the pattern survives V5 spread / slippage /
  Darwinex-symbol-mapping concerns.

- 2026-04-28: Bonds and S&P holiday-rule maps DISAGREE on direction for several holidays:
  - New Years: Bonds = SELL CLOSE -3; S&P = BUY OPEN -3 (OPPOSITE direction)
  - Pres Day: Bonds = BUY CLOSE -5; S&P = BUY OPEN -3 (same direction, different timing)
  - Easter: Bonds = SELL OPEN +1 + SELL CLOSE -1; S&P = BUY CLOSE -2 + SELL OPEN +1
  This is consistent with the THESIS that Bonds and S&P respond OPPOSITELY to risk-on / risk-off
  flow patterns — bonds rally when equities fall — so opposite-direction holiday rules are
  internally consistent. Card defaults to S&P map for V5 deployment on US500.DWX; CTO confirms
  per-symbol map at G0.

- 2026-04-28: Williams' Easter rule references "TD After Holiday" sub-rule for the SELL OPEN +1
  variant — implying entry is the trading day AFTER Easter Monday. US markets are closed Good
  Friday (not Easter Monday), so "TD After Holiday" = first trading day after Good Friday =
  Monday after Easter. Implementation note: holiday-anchor for Easter is GOOD FRIDAY's date
  (US market close), not Easter Sunday.

- 2026-04-28: V5-architecture-fit profile is STRONG — single-symbol, daily bars, US-domestic-
  flow-driven calendar bias. Confirms SRC03 source.md prediction that Williams cards have
  cleaner V5 fit than SRC02 Chan multi-stock. S06 alongside S01 / S02 / S07 forms a coherent
  Williams single-symbol calendar+pattern bundle for the V5 P9 portfolio-construction stage.
```
