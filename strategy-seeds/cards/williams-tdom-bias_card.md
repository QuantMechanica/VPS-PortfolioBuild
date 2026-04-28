# Strategy Card — Williams Trade Day of Month Bias (positive-TDOM open-buy with first-profitable-open exit; Bonds + S&P)

> Drafted by Research Agent on 2026-04-28 from `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` (verbatim Bonds-context § "2.) TRADE DAYS OF THE MONTH AS WELL", PDF p. 33; verbatim S&P-context § "TRADE DAY OF THE MONTH", PDF p. 38; "BEST SHORT TERM BUY/SELL DAYS OF THE YEAR" tables PDF pp. 42-45).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per DL-032 + DL-030 Class 2 Review-only execution policy).

## Card Header

```yaml
strategy_id: SRC03_S05
ea_id: TBD
slug: williams-tdom-bias
status: DRAFT
created: 2026-04-28
created_by: Research
last_updated: 2026-04-28

strategy_type_flags:
  - intraday-day-of-month                     # canonical match — V4 Gotobi (SM_124) is the cited V4 example for monthly-cycle date-of-month bias
  - signal-reversal-exit                      # exit fires when "first profitable open" — entry signal reversed by profit
  - atr-hard-stop                             # Williams: $3,500 S&P / $1,400-$1,800 Bonds-best-day; V5 → ATR-equivalent
  - long-only                                 # Williams' positive-TDOM tables show LONG-side only; sell-side is "best sell days" sub-table (separate parameter set), but Williams treats them as separate strategies — long-only is the dominant framing
  - friday-close-flatten                      # V5 default; Williams' first-profitable-open exit caps holds
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Williams, Larry R. (1999). Long-Term Secrets to Short-Term Trading. Wiley Trading. New York: John Wiley & Sons."
    location: "PDF p. 33 (Inner Circle Workshop companion volume), § 'INSIDE CIRCLE SHORT TERM TRADING APPROACH — 2.) TRADE DAYS OF THE MONTH AS WELL' (Bonds; T-Bond TDOM table with Gold-filter variant). Cross-reference: PDF p. 38 § 'S&P 500 TRADING RULES — TRADE DAY OF THE MONTH' (S&P; TDOM table with $3,500 stop). 'BEST SHORT TERM BUY/SELL DAYS OF THE YEAR' tables PDF pp. 42-43 (S&P month × TDOM combos). T-BONDS BEST BUY/SELL TRADE DAYS WITH 4-DAY HOLD tables PDF pp. 43-45 (Bonds month × TDOM combos with 7%-of-prior-day-range stop-buy entry)."
    quality_tier: A
    role: primary
```

Raw evidence: `strategy-seeds/sources/SRC03/raw/probe_pp30-60.txt` lines 178-232 (Bonds TDOM table, two columns), lines 450-483 (S&P TDOM table), lines 731-892 (S&P best buy/sell days year + Bonds best buy/sell trade days year). Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Long-Term Secrets to Short-Term - Larry R. Williams.pdf`.

## 2. Concept

A **calendar-day-of-month directional bias** evaluated each trading-day open. Williams' empirical observation: certain TDOMs (e.g., S&P TDOM 9, 12, 22; Bonds TDOM 1, 5, 9, 11, 16, 18, 19, 20) exhibit systematic positive expectancy for long entries; other TDOMs (e.g., S&P TDOM 4, 8, 15) are systematically negative. Buy at session open on positive-TDOM days; exit at first profitable open thereafter (or 4-day hold + 7%-of-prior-range stop-buy entry for the Bonds best-trade-days variant on PDF p. 43).

Williams' verbatim Bonds-context framing, PDF p. 33:

> "2.) TRADE DAYS OF THE MONTH AS WELL — The same bias or advantage car. [be] garnered from TDOM's. The first table list[s] buying on the opening of every TDOM, the second only buying if Gold has closed lower than 25 days ago. Clearly there is a difference, clearly [the] short term trader should be alerted to these set up opportunities."

S&P-context framing, PDF p. 38:

> "TRADE DAY OF THE MONTH — Some times of the month are better than others for buying or selling as our next table exhibits. Here you see each TDOM with our bail out and $3,500 stop."

This card extracts the **base mechanical entry** with the positive-TDOM vector as a parametrized switch. Per DL-033 Rule 1, this is ONE card with the calendar-day vector as a parameter — NOT separate cards for each of the dozens of "best buy day of year" tabulations. Williams himself frames the year-by-year-month-specific tables (PDF pp. 42-45) as REFINEMENTS of the basic TDOM rule, not as distinct strategies.

The `BEST_TDOM_DAYS` parameter accepts:
- Williams' generic Bonds positive-TDOM set (TDOM 1, 5, 9, 11, 16, 18, 19, 20 — derived from positive-profit cells in the Bonds-with-Gold-filter table)
- Williams' generic S&P positive-TDOM set (TDOM 1, 9, 11, 12, 16, 18, 19, 20, 21, 22 — derived from positive-profit cells in S&P TDOM table)
- Williams' month-specific best-buy-days vector for S&P (PDF p. 42, e.g., Jan 9, Feb 4, Mar 18, Apr 2, ...)
- Williams' month-specific best-buy-days vector for T-Bonds (PDF pp. 43-45, e.g., Jan 15, Jan 7, Feb 14, Apr 4, May 21, ...)

## 3. Markets & Timeframes

```yaml
markets:
  - bond_futures                              # Williams' primary deployment: T-Bonds (PDF p. 33). V5 proxy: bond CFD if Darwinex offers; flag dwx_suffix_discipline otherwise
  - index_futures                             # Williams' S&P deployment (PDF p. 38). V5 proxy: US500.DWX
  - forex                                     # Williams' broader pattern thesis is generic; CSR P3.5 validates breadth — TDOM patterns may be PARTLY US-domestic-flow driven (mutual fund inflows on Bonds 1st-of-month, etc.)
  - commodities                               # idem
timeframes:
  - D1                                        # Williams: rules stated on daily bars
session_window: cash_session                  # Williams' framing implies cash session
primary_target_symbols:
  - "T-Bonds futures (Williams' deployment) → bond CFD if available; flag otherwise"
  - "S&P 500 futures (Williams' deployment) → US500.DWX V5 proxy"
```

## 4. Entry Rules

Pseudocode — verbatim translation of Williams' PDF p. 33 (Bonds), p. 38 (S&P), p. 43 (T-Bonds best-trade-days with 7%-stop-buy variant) rules.

```text
PARAMETERS:
- BEST_TDOM_DAYS    = williams_sp_default     // Default: S&P generic positive-TDOM set
                                              //   {1, 9, 11, 12, 16, 18, 19, 20, 21, 22}
                                              //   per Williams S&P TDOM table positive-profit cells
- ENTRY_AT          = open                    // Williams: "buying on the opening" / "buy on the opening of the day shown"
- BAR               = D1
- USE_RANGE_PCT_STOP_BUY = false              // Williams T-Bonds best-trade-days variant (PDF p. 43):
                                              //   "buy on the opening of the day shown, plus 7% of the previous days range added to the opening"

EACH-BAR (open trigger, evaluated at session open):
- if TradeDayOfMonth(t) in BEST_TDOM_DAYS:
    if USE_RANGE_PCT_STOP_BUY:
      stop_trigger = Open[t] + 0.07 * (High[t-1] - Low[t-1])    // 7% Williams' T-Bonds explicit
      stage stop-buy at stop_trigger
      if intra-day High[t] >= stop_trigger: FILL_LONG at stop_trigger
    else:
      OPEN_LONG at Open[t]
- else: NO_TRIGGER
```

**TradeDayOfMonth (TDOM) definition** is Williams' convention: TDOM = N-th trading day from start of calendar month (skips weekends + holidays). Implementation: count trading days since the first trading day of the calendar month inclusive.

## 5. Exit Rules

Williams' explicit exits (different per context):

```text
DEFAULT EXIT (Williams S&P-context, PDF p. 38): bail-out + $3,500 stop
- BAIL_OUT_ON_PROFIT_OPEN: if Open[t+k] > entry_price for k >= 1: CLOSE_LONG at Open[t+k]
- HARD_STOP_USD = 3500           // S&P explicit
- TIME_STOP = 5 bars             // backstop; Williams does not specify on basic TDOM table

T-Bonds best-trade-days variant (PDF p. 43): 4-day hold + $1,800 stop
- TIME_STOP = 4 bars             // Williams: "exit on any profitable opening after 3 days"
                                 //   = exit on first profitable open up to and including bar 4
- HARD_STOP_USD = 1800           // T-Bonds explicit
- BAIL_OUT_ON_PROFIT_OPEN: as above

DEFAULT EXIT (V5 unified):
- bail-out at first profitable open
- HARD_STOP_ATR_MULT = 2.5       // ATR-equivalent of Williams' Bonds $1,800 / S&P $3,500
- TIME_STOP = 5 bars

EACH-BAR (in position):
- HARD STOP — fires at HARD_STOP-equivalent ATR distance from entry; never moves
- BAIL_OUT_ON_PROFIT_OPEN: if Open[t+1] > entry_price: CLOSE_LONG at Open[t+1]
- TIME_STOP backstop: if held > TIME_STOP bars, force flat at next open

FRIDAY CLOSE: V5 default applies. TDOM entries with first-profitable-open exit typically
resolve within 1-5 sessions. Friday-close occasionally binds at TIME_STOP=5 if entry is
Mon/Tue and pattern doesn't profit by Fri 21:00. Default V5 cleanly applies.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip, Friday Close
- pyramiding: NOT allowed (one open position per direction; cannot stack TDOM entries)
- gridding: NOT allowed
- BEST_TDOM_DAYS gating: only enter on positive-bias TDOMs per § 4
- Gold-filter (OPTIONAL P3 sweep axis, Bonds-context):
    Gold_Close[t-1] < Gold_Close[t-25]   // Williams Bonds-with-Gold-filter variant (PDF p. 33)
- Bond-trend filter (OPTIONAL P3 sweep axis, S&P-context):
    Bond_Close[t-1] > Bond_Close[t-15]   // Williams S&P-with-Bonds-up-trend variant (PDF p. 39 "THE POWER OF BONDS")
- Month-specific best-day overlay (P3 sweep axis):
    constrain BEST_TDOM_DAYS by current month; e.g., Jan-only allow TDOM=9, Feb-only allow TDOM=4
    (Williams' "best short term buy days of the year" tabulation, PDF pp. 42-45)
```

## 7. Trade Management Rules

```text
- one open position per direction at any time (no pyramiding, no stacking)
- consecutive positive-TDOMs (e.g., TDOM 18, 19, 20, 21, 22 are all in S&P best-buys set):
  if prior position has not hit profit-open exit, NEW entry SUPPRESSED to honor V5
  one_position_per_magic_symbol Hard Rule
- position size: V5 risk-mode framework
- Friday Close: forced flat per V5 default
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: best_tdom_days_set
  default: williams_sp_generic                  # {1, 9, 11, 12, 16, 18, 19, 20, 21, 22}
  sweep_range:
    - williams_sp_generic                       # S&P TDOM table positive cells
    - williams_bonds_generic                    # {1, 5, 9, 11, 16, 18, 19, 20} — Bonds TDOM positive cells
    - williams_bonds_gold_filter                # subset that turns positive ONLY when Gold-filter applied
    - williams_sp_top5                          # {9, 12, 18, 21, 22} — top-5 by avg-profit-per-trade
    - williams_sp_month_specific                # month-specific best-buy day per Williams pp. 42-43 (single day per month, dictionary lookup)
    - williams_bonds_month_specific             # month-specific best-buy day per Williams pp. 43-45
- name: entry_method
  default: open_buy                             # Williams basic-TDOM
  sweep_range: [open_buy, range_pct_stop_buy]   # _stop_buy = Williams T-Bonds best-trade-days variant; 7% of prior range
- name: range_pct                               # only relevant when entry_method == range_pct_stop_buy
  default: 0.07                                 # Williams T-Bonds best-trade-days
  sweep_range: [0.05, 0.07, 0.10, 0.15, 0.20]
- name: hard_stop_atr_mult
  default: 2.5                                  # ATR-equivalent of Williams' $1,800-$3,500
  sweep_range: [1.5, 2.0, 2.5, 3.0, 4.0]
- name: time_stop_bars
  default: 5
  sweep_range: [3, 4, 5, 7]                     # 4 = Williams T-Bonds best-trade-days variant
- name: bond_uptrend_filter                     # S&P-context Williams variant
  default: off
  sweep_range: [off, bond_above_15d, bond_above_10d_or_15d]
- name: gold_filter                             # Bonds-context Williams variant
  default: off
  sweep_range: [off, gold_below_25d, gold_below_15d_or_24d]
```

P3.5 (CSR) axis: re-run on Darwinex symbol cohort. TDOM patterns are documented for **CME T-Bonds + S&P** — partly US-domestic-flow-driven (mutual-fund inflows on TDOM 1, options-expiration cycle on TDOM 12-15, end-of-month rebalancing). CSR validates whether the pattern survives across:
- Index CFDs: US500.DWX (closest analog), US100.DWX, GER40.DWX, UK100.DWX, NIKKEI.DWX
- Spot FX: EURUSD.DWX, USDJPY.DWX (TDOM patterns may differ — Williams himself notes "currencies do well with the WVI but perhaps better spreading against the Dollar Index", PDF p. 4 — implying FX has its own calendar dynamics)
- Metals: GOLD.DWX, XAGUSD.DWX

## 9. Author Claims (verbatim, with quote marks)

Bonds TDOM table, PDF p. 33-34 (left col = no filter; right col = Gold-filter):

> "TDOM $+/-     %Wins  Avg Profit        TDOM $+/-  %Wins  Avg Profit
>
>  1 18,827       68%    72              1 15,507   70%        100
>  2 -22,641      56%  -159              2 -19,711  57%        ...
>  3 -41,047      67%   ...              3 -22,158  70%        ...
>  4 -18,547      60%  -109              4 10,457   61%        ...
>  5   6046       69%   114              5 12,500   71%         43
>  6 -28,297      63%    68              6 -6060    69%         57
>  7 -18,797      63%    53              7 -6271    64%        -24
>  8 29,608       68%   -42              8 6153     70%        -52
>  9 17,640       65%   139              9 18,603   68%         10
> 10  7015        67%   -13              10  8740   68%         10
> 11 -14,422      68%   -18              11  5370   72%        -37
> 12 -16,047      73%    30              12 -3791   85%        162
> 13 -11,016      ...   169              13  1670
> 14 -20,096                              14 -7740
> 15  353                                 15  808
> ..."

(Note: PDF table OCR has alignment artifacts; numerics preserved verbatim where unambiguous.)

S&P TDOM table, PDF p. 38:

> "TRADE DAY OF THE MONTH — Some times of the month are better than others for buying or selling as our next table exhibits. Here you see each TDOM with our bail out and $3,500 stop.
>
>            TDOM $+/-             %Wins      Avg Profit
>
>               1            4175      64%         20
>               2          -5970      61%         -29
>               3         16,867      67%         83
>               4        -31,490      64%       -155
>               5          -4412      62% -       -21
>               6         14,170      70%         69
>               7          -7947      68%         -39
>               8        -16,210      62%         -79
>               9        48,202       69%        237
>               10       -10,535      60%         -51
>               11       12,262       68%         60
>               12       54,505       65%        268
>               13        -7282       61%        -35
>               14       11,307       66%         55
>               15       -32,915      60%       -162
>               16       17,205       70%         84
>               17       -12,927      66%       -64
>               18       25,635       64% .      130
>               19       35,490       70%       209
>               20       27,922       73%       234
>               21       21,124       72%       286
>               22          7975      90%       398"

T-Bonds best-trade-days variant, PDF p. 43:

> "In the Bond Market I have found the best short-term trades to be those below. The rules are slightly different, buy on the opening of the day shown, plus 7% of the previous days range added to the opening. Use an $1,800 protective stop or exit on any profitable opening after 3 days.
>
> T BONDS BEST BUY TRADE DAYS WITH 4 DAYS HOLD
>
> JANUARY 15  7756   15/18 83%  -2050   3106    430
>          7  10025  13/17 75%  -2018   3325    589
> FEBRUARY 14 10150  12/17 70%  -3725   5075    597
> MARCH NONE
> APRIL    4  8443   13/18 72%  -5075   2950    469
> MAY     21  11575  10/11 90%  -1862   3168   1052
>         22  5250    5/5 100%                  1450
> JUNE     6  15737  16/19 84%  -1862   5200    828
>          1  7881   14/18 77%  -2143   4512    437
>         17  7325   14/16 87%  -1862   1825    457
> JULY    18  9106   13/16 81%  -1862   2356    569
>          5  7962   16/17 94%  -1862   1981    468
> AUGUST  21  6056   12/17 70%  -4662   2825    356
> SEPTEMBER 20 15606 13/16 81%  -1862   4075    975
>          2  6012   14/16 87%  -1862   2293    375
> OCTOBER 18(19,20) 14818 16/18 88%  -2081   3106   883
>         15  8781   13/15 86%  -1862   2606    585
> NOVEMBER 5  13662  15/18 83%  -1925   2387    759
>         20  8993   10/12 83%  -2887   2887    749
>         13  7800   12/14 85%  -1862   2548    557
>         21  4418    4/4 ...
> DECEMBER 10 12018  15/19 78%  -1862   5168    652
>         12  11443  14/18 77%  -1987   4356    635
>         14  11412  16/18 88%  -1862   2293    634
>         15  6518   13/14 92%  -1862   1512    ..."

S&P best short-term buy days of the year, PDF p. 42-43:

> "BEST SHORT TERM BUY DAYS OF THE YEAR
>
> JANUARY   9   9/13 69%   10,710
> FEBRUARY  4   12/13 92%  12,170
> MARCH     18  9/11 81%   9,075
> APRIL     2   11/13 84%  11,585
> MAY       15  ...        ...
> JUNE      14  ...
> JULY      17  ...
> AUGUST    18  ...
> SEPTEMBER 20  12/13 92%  13,545
> OCTOBER   11  13/15 86%  14,040
> NOVEMBER  6   ...
> DECEMBER  12  ..."

(Note: source lists win counts per total trades, win-rate %, total $-profit per single-day trading from 1982-1999.)

**Verbatim performance numbers preserved per BASIS rule.** Williams provides explicit per-TDOM expectancy for ~22 TDOM cells × 2 contexts (Bonds, S&P) × 2 filter variants (raw, with-Gold/Bond-filter) and ~12 × 2 contexts of best-day-of-year tables. No extrapolated number is asserted; pipeline P2-P9 produces actual edge measurement on Darwinex .DWX symbols.

## 10. Initial Risk Profile

```yaml
expected_pf: 1.6                              # rough estimate; Williams' best TDOMs report 70-90% win rates with positive expectancy; selecting only top-5 TDOMs likely produces strong PF
expected_dd_pct: 10                           # rough estimate; high win-rate + bail-out exit on selectively-chosen TDOMs
expected_trade_frequency: 50-150/year/symbol  # depends on best_tdom_days_set; williams_sp_generic = ~10 TDOMs/month × 12 months = 120/year
risk_class: low                               # systematic-day-bias short-hold strategy
gridding: false
scalping: false                               # D1
ml_required: false                            # day-of-month classification + threshold
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (TDOM count + open-buy + first-profitable-open exit)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (D1)
- [x] Friday Close compatibility: 1-5 day typical hold; default V5 applies
- [x] Source citation is precise enough to reproduce (PDF p. 33 Bonds + p. 38 S&P + pp. 42-45 month-specific tables; verbatim tables in § 9)
- [x] No near-duplicate of existing approved card

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "BEST_TDOM_DAYS gate + standard V5 default; optional Gold-filter / Bond-trend-filter / month-specific overlays as P3 sweep axes"
  trade_entry:
    used: true
    notes: "open-buy on positive-TDOM days (or stop-buy at open + range_pct × prior-range for T-Bonds variant); one position per direction"
  trade_management:
    used: false
    notes: "no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "bail-out at first profitable open + ATR-equivalent hard stop + time-stop backstop (3-7 bars per variant)"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY — Williams' deployment is CME futures; TDOM patterns may be partly US-domestic-flow-driven; CSR P3.5 multi-symbol validation load-bearing
  - friday_close                              # NOT load-bearing — short-hold strategy
  - news_pause_default                        # standard V5 P8 news-blackout applies; high-impact macro events cluster on specific TDOMs (NFP = first Friday = TDOM ~5; FOMC = TDOM 16-22 typically) which would interact with TDOM signal — P8 ablation question
  - one_position_per_magic_symbol             # not load-bearing on default; consecutive-positive-TDOMs suppression covers it
  - enhancement_doctrine                      # load-bearing on BEST_TDOM_DAYS — Williams cites multiple sets (Bonds-generic, S&P-generic, month-specific Bonds, month-specific S&P, top-5, etc.); once a live set is fixed at deployment, any subsequent retune is enhancement_doctrine

at_risk_explanation: |
  dwx_suffix_discipline — Williams' tables are CME T-Bonds + CME S&P 500 futures. TDOM patterns
  may be partly US-domestic-flow-driven (mutual-fund inflow / option-expiration / month-end-
  rebalancing). CSR P3.5 validates whether pattern survives across spot FX (different TZ flow)
  and cross-time-zone CFDs.

  friday_close — Default V5 applies. Typical 1-5 day hold rarely binds.

  news_pause_default — Macro events cluster on specific TDOMs (NFP first Friday ≈ TDOM 5; FOMC
  meeting Tues/Wed in TDOM 16-22 range; CPI mid-TDOM 9-15). The TDOM pattern's edge may be
  PARTLY news-driven on those specific TDOMs. P8 ablation: does the pattern persist when
  news-window TDOMs are excluded? P8 handles event-windows natively.

  one_position_per_magic_symbol — single position per direction at a time; consecutive-positive-
  TDOMs (e.g., TDOM 18-22 all in S&P best-buys set) suppress new entries while prior is open.

  enhancement_doctrine — Williams cites MULTIPLE positive-TDOM sets (Bonds-generic, S&P-generic,
  Bonds-with-Gold, month-specific Bonds, month-specific S&P, top-5). Card defaults to S&P-
  generic; P3 sweeps the alternatives. Once live set fixed, retune = enhancement_doctrine.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # BEST_TDOM_DAYS gate (per-month dictionary lookup possible) + standard V5
  entry: TBD                                  # session-open open-buy (or stop-buy at +N%×range); ~80-120 LOC in MQL5; TDOM counter requires session-day arithmetic
  management: TBD                             # n/a
  close: TBD                                  # first-profitable-open + hard stop + time-stop backstop
estimated_complexity: small                   # TDOM counting + day-list-membership check
estimated_test_runtime: 2-4h                  # P3 sweep cell count moderate (6×2×5×5×4×3×3 ≈ 5,400 cells); D1 bars; multi-set
data_requirements: standard                   # D1 OHLC; Gold-filter variant requires GOLD.DWX
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
- 2026-04-28: SRC03_S05 cleanly fits the EXISTING `intraday-day-of-month` flag (V4 SM_124
  Gotobi precedent). No vocabulary gap surfaced from this card — Williams' TDOM is the same
  category as Gotobi: monthly-cycle calendar-bias entry. The S04 sister card (TDW) surfaces
  a sister-flag-gap question (`intraday-day-of-week`) but S05 is non-gap.

- 2026-04-28: The DOZENS of "best buy/sell day of year" tabulations (PDF pp. 42-45) consolidate
  into ONE card via the `best_tdom_days_set` parameter — they are different parameter values
  of the SAME mechanical entry, not distinct strategies. This is the PRIMARY DECISION that
  source.md § 6 flagged for extraction-time resolution. Decision: ONE CARD with parameter set.
  Per DL-033 Rule 1 — distinct mechanical strategies get distinct cards; minor parameter
  variants do not.

- 2026-04-28: Williams' T-Bonds best-trade-days variant (PDF p. 43) introduces a SECONDARY
  entry method: stop-buy at open + 7% of prior-day range, instead of plain open-buy. This is
  STRUCTURALLY DIFFERENT enough to be a P3 axis but NOT a separate card — Williams himself
  frames it as "rules are slightly different" within the same TDOM-bias category.

- 2026-04-28: Williams' BEST_SELL_DAYS tables (PDF pp. 42-43, S&P sells: Jan 1, Feb 13, Mar 15,
  Apr 14, May 3, ..., Dec 21) and Bonds sell tables (PDF p. 45) are SHORT-SIDE counterparts,
  treated by Williams as a separate trading rule (different per-TDOM expectancy table). Card
  defaults `long-only`; short-side ablation is a P3 axis but is not the primary deployment
  framing in the source. Recommendation: if P3 ablation shows short side has independent edge,
  consider sister card `williams-tdom-sell-bias` rather than folding into this card.

- 2026-04-28: P8 News-blackout interaction is OPEN — TDOMs cluster around scheduled macro
  events (NFP TDOM 5, FOMC TDOM 16-22, CPI TDOM 9-15). Williams' TDOM pattern's edge may be
  PARTLY news-driven. P8 ablation: does the pattern persist when news-window TDOMs are excluded?
  Critical for P8 NEWS_MODE selection (OFF / PAUSE / SKIP_DAY per `decisions/2026-04-25_news_
  compliance_variants_TBD.md`).
```
