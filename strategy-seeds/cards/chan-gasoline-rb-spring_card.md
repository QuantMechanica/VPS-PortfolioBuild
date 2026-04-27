# Strategy Card — Chan Gasoline RB Spring (long-only annual calendar trade on NYMEX gasoline futures)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § E (verbatim Ch 7 narrative + sidebar p. 149 + 14-year P&L table).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S07
ea_id: TBD
slug: chan-gasoline-rb-spring
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:                          # closest existing values from strategy_type_flags.md;
                                              # SRC02 surfaces a 4th vocabulary gap: 'annual-calendar-trade'.
                                              # See § 16 + raw/seasonal_calendar_trades.md § J.
  - long-only                                 # Chan p. 149 verbatim: "buy 1 contract of RB ... and sell it"; only long entries
  - time-stop                                 # closest available exit flag — exit IS clock-based on a fixed calendar date (Apr 25), though "annual-date-stop" would be cleaner than "bar-count time-stop"
  # *vocabulary-gap flag proposed for CEO + CTO ratification per strategy_type_flags.md addition-process (see § 16):
  #   - annual-calendar-trade                  # entry on fixed annual date, exit on fixed annual date; one-shot per year per symbol
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 7 'Special Topics in Quantitative Trading', § 'Seasonal Trading Strategies' opener pp. 148-149 + sidebar 'A Seasonal Trade in Gasoline Futures' p. 149 (mechanical specification + 14-year P&L table 1995-2008)."
    quality_tier: A
    role: primary
  - type: article
    citation: "Kavanaugh, Paul (ongoing). Monthly seasonal trades. PFGBest.com (cited by Chan, p. 149)."
    location: "publisher attribution per Chan p. 149: 'inspired by the monthly seasonal trades published by Paul Kavanaugh at PFGBest.com'"
    quality_tier: B                            # practitioner attribution, not directly available; included for citation completeness
    role: supplement
  - type: book
    citation: "Fielden, Sandy (2005). Cited by Chan, p. 149."
    location: "Chan's bibliographic anchor for seasonal-futures patterns research"
    quality_tier: B
    role: supplement
  - type: book
    citation: "Toepke, Jerry (2004). Cited by Chan, p. 149."
    location: "Chan's bibliographic anchor for seasonal-futures patterns research"
    quality_tier: B
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § E. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **long-only annual calendar trade on NYMEX unleaded gasoline futures (RB)** that enters at the close of April 13 and exits at the close of April 25 each year. The thesis is fundamental seasonal-demand pull: U.S. summer driving season (Memorial Day weekend onwards) drives refinery and retail-network demand for finished gasoline, and the spring inventory build-up phase shows persistent annual price pressure that quietly accumulates from mid-April through end-of-month. The strategy doesn't require any indicators or filters — only a calendar lookup. Chan reports profitability in **every year 1995-2008** (14 consecutive years through book publication, with 2007-2008 being live-traded results), with annual P&L from $118 to $6,985 per contract and the worst single-year drawdown at $2,226 (1996).

Chan's verbatim framing, p. 149:

> "Whenever the summer driving season comes up, it should not surprise us that gasoline futures prices will be rising seasonally. The only question for the trader is: which month contract to buy, and to hold for what period? After scanning the literature, the best trade I have found so far is one where we buy 1 contract of RB (the unleaded gasoline futures trading on the New York Mercantile Exchange [NYMEX]) at the close of April 13 (or the following trading day if it is a holiday), and sell it at the close of April 25 (or the previous trading day if it is a holiday). Historically, we would have realized a profit every year since 1995."

## 3. Markets & Timeframes

```yaml
markets:
  - commodity_futures                         # NYMEX RB unleaded gasoline futures, May expiry
timeframes:
  - D1                                        # daily-bar / close-based entry and exit; calendar-driven, no intraday
session_window: per-day-close                 # fires once at 14:30 ET (NYMEX close) on the entry-rule date
primary_target_symbols:
  - "RB (NYMEX unleaded gasoline futures, May expiry) — Chan's deployment, 1 contract"
  - "QU (NYMEX mini gasoline futures, May expiry, half-size) — Chan's reduced-risk alternative"
  - "Darwinex equivalent: TBD at CTO sanity-check — Darwinex CFD universe does NOT natively offer gasoline-specific futures.
     Closest related-product candidates: OIL.DWX (WTI crude) or BRENT.DWX (Brent crude). These are NOT direct substitutes
     for RB — gasoline is a refinery output, not crude — and the seasonal pattern may NOT translate. CTO confirms
     Darwinex symbol availability at G0; if no native gasoline product exists, this card REJECTS at G0."
```

## 4. Entry Rules

```text
PARAMETERS (Chan-fixed; minimal sweep surface):
- ENTRY_MONTH      = 4               // April
- ENTRY_DAY        = 13              // calendar day of month
- HOLIDAY_RULE     = "next_trading_day"  // Chan: "or the following trading day if it is a holiday"
- CONTRACT_EXPIRY  = "May"           // contract month relative to entry date
- POSITION_SIZE    = 1 contract RB   // or 2 contracts mini QU per Chan's reduced-risk alternative

ANNUAL TRIGGER (each calendar year Y, evaluated daily):
- if not in position
  and current_date == roll_to_next_trading_day(year_Y, ENTRY_MONTH, ENTRY_DAY)
  and time_of_day == NYMEX_session_close
  then OPEN_LONG 1 contract RB-MAY-YYYY at close

NO INDICATOR CHECK:
- entry is purely calendar-driven; no MA, no momentum confirm, no volatility filter, no spread check
- Chan deliberately does NOT add a confirmation filter (e.g., "only enter if RB has been below the 50-DMA")
- Per DL-033 Rule 1, the card preserves Chan's specification — adding filters would be Research extrapolation
```

## 5. Exit Rules

```text
EXIT (only when in position):
- CALENDAR-DATE EXIT:
  - if current_date == roll_to_previous_trading_day(year_Y, EXIT_MONTH=4, EXIT_DAY=25)
    and time_of_day == NYMEX_session_close
    then CLOSE position at close

NO STOP-LOSS:
- Chan does not specify a per-trade stop-loss. The 14-year max single-year DD was -$2,226 (1996),
  which is roughly 0.5x typical annual P&L. Chan's anti-stop-loss-on-MR-models stance (Ch 7 p. 143)
  is for mean-reversion strategies, not seasonals. For seasonals Chan provides no anti-stop-loss
  guidance, but also no per-trade stop is included in the example. The card preserves Chan's
  specification (no stop) and relies on V5 framework's account-level kill-switch as the catastrophic
  backstop. CTO + Quality-Tech may add a wide ATR-based safety stop at APPROVED stage if the
  unstopped historical DD becomes a P5 / P9 portfolio-fit issue.

NO TIME-STOP BY BAR-COUNT:
- the EXIT_DAY is itself a "time-stop" in the calendar-date sense, but it is NOT a bars-since-entry
  rule. The two cannot fire at different times: entry and exit are both calendar-anchored.

NO TRAILING / NO BREAK-EVEN / NO PARTIAL CLOSE.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- holiday-rule for entry date: ENTRY_DAY = April 13; if holiday/non-trading-day, roll to NEXT trading day (Chan)
- holiday-rule for exit date: EXIT_DAY = April 25; if holiday/non-trading-day, roll to PREVIOUS trading day (Chan)
- Friday Close: **WAIVER REQUIRED** — strategy holds 1 contract for ~9 trading days spanning ~2 weekends.
  V5 default Friday-close would force-flat the position each Friday and re-open Monday — destroying the
  contract and forcing 2 round-trips. Card asks for explicit Hard Rule waiver per V5 framework docs.
  Without waiver: G0 KILL.
- pyramiding: NOT allowed (one contract per year)
- annual-cycle gate: only one entry per calendar year per symbol; framework state must remember "already
  entered this year" to prevent duplicate entries from clock drift / restart edge cases
```

## 7. Trade Management Rules

```text
- one open position at a time (one contract per year)
- position size: 1 contract RB (Chan's full-size example) or 2 contracts mini QU (Chan's reduced-risk alternative)
  - V5 maps to risk-mode framework: contract notional ≈ 42,000 gallons × current RB price ≈ $80,000-$120,000
    per contract at 2008 prices; the relevant V5 risk-mode percent is calibrated to one-trade-fully-stopped
    catastrophic loss at the kill-switch trigger
- gridding: NOT allowed
- contract roll: NOT applicable — single ~9-trading-day hold; entry on May contract, exit before May expiry
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: entry_day
  default: 13
  sweep_range: [10, 11, 12, 13, 14, 15, 16, 17]   # Chan reports Apr 13 as best from his literature scan; sweep ±4 days
- name: exit_day
  default: 25
  sweep_range: [22, 23, 24, 25, 26, 27, 28, 29]   # Chan reports Apr 25; sweep ±4 days
- name: entry_month
  default: 4                                       # April; very narrow sweep — Chan's "spring" thesis is April-specific
  sweep_range: [3, 4]                              # March vs April; broader month-sweep would be a different strategy
- name: position_size_units
  default: 1                                       # 1 RB contract; OR 2 QU mini contracts (~equivalent)
  sweep_range: [1]                                 # not a P3 axis; size handled by V5 risk-mode at sizing-time
- name: optional_atr_safety_stop
  default: null                                    # Chan: no stop; ablation-only
  sweep_range: [null, 5, 10, 20]                   # ATR multiplier for an OPTIONAL safety stop; ablation P3 axis to inform CTO at APPROVED
```

P3.5 (CSR) axis: re-run on related Darwinex-eligible commodity futures if available (`OIL.DWX` WTI crude, `BRENT.DWX` Brent crude, `NATGAS.DWX` if it exists) — does the spring seasonal pattern survive on related products? Chan's broader claim (p. 148): "commodity futures' seasonal strategies are alive and well ... seasonal demand for certain commodities is driven by 'real' economic needs" — suggests a broader portfolio of seasonal trades, but each commodity has its own date pattern (NG = Feb 25 to Apr 15 per S08, gasoline = Apr 13 to Apr 25 per this card).

## 9. Author Claims (verbatim, with quote marks)

NYMEX RB May contract, Apr 13 → Apr 25 holding period, 1 contract:

> "Historically, we would have realized a profit every year since 1995." (p. 149)

14-year P&L table (verbatim, p. 149):

| Year | P&L in $ | Maximum Drawdown in $ |
|---|---|---|
| 1995 | 1,037 | 0 |
| 1996 | 1,638 | -2,226 |
| 1997 | 227 | -664 |
| 1998 | 118 | 0 |
| 1999 | 197 | (none listed) |
| 2000 | 735 | -588 |
| 2001 | 1,562 | -315 |
| 2002 | 315 | (none listed) |
| 2003 | 1,449 | 0 |
| 2004 | 361 | 0 |
| 2005 | 6,985 | -38 |
| 2006 | 890 | -907 |
| 2007 (actual) | 2,286 | -25 |
| 2008 (actual) | 4,741 | 0 / -9,816 |

(Asterisked rows in source: 2007-08 = actual trading expressed as 2 × QU mini-contracts. 2008 max-DD column has dual entries in source layout.)

Reduced-risk alternative (verbatim, p. 149):

> "For those who desire less risk, you can buy the mini gasoline futures QU at NYMEX which trade at half the size of RB, though it is illiquid."

Attribution (verbatim, p. 149):

> "(This research has been inspired by the monthly seasonal trades published by Paul Kavanaugh at PFGBest.com. You can read up on this and other seasonal futures patterns in Fielden, 2005, or Toepke, 2004.)"

## 10. Initial Risk Profile

```yaml
expected_pf: 4.0                              # 14/14 winning years → no losing trades in the published sample
                                              # (P&L always positive, only max-DD intra-trade); PF nominally infinite
                                              # but real-world out-of-sample 2009-onwards expected to add some losers.
                                              # Conservative estimate 4.0; pipeline P4 walk-forward refines.
expected_dd_pct: 5                            # rough estimate: max single-year DD $2,226 on a contract of ~$80K notional ≈ 2.8%;
                                              # the 2008 actual-trading $9,816 DD on 2 × QU mini = ~$160K combined notional ≈ 6.1%
                                              # → portfolio-level expected DD bounded by V5 risk-mode position-sizing at sizing time
expected_trade_frequency: 1/year/symbol       # one entry per calendar year per RB contract
risk_class: medium                            # 9-day hold on one contract; stop-less position; commodity-futures volatility moderate
gridding: false
scalping: false                               # D1 with 9-day hold is NOT scalping
ml_required: false                            # purely calendar-driven; no statistics, no ML
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (calendar-date lookup + holiday-roll = fully deterministic; no discretion)
- [x] No Machine Learning required (no statistical model at all)
- [x] If gridding: not applicable (one contract per year)
- [x] If scalping: not applicable (9-day hold)
- [ ] **Friday Close compatibility: DOES NOT survive forced flat at Friday 21:00 broker time.** 9-trading-day hold spans ~2 weekends; default Friday-close would force-flat each Friday. Card requires explicit `friday_close` Hard Rule waiver. Without waiver: G0 KILL.
- [x] Source citation is precise enough to reproduce (chapter + section + sidebar + page + verbatim quotes + dollar-precision P&L table)
- [x] No near-duplicate of existing approved card (`strategy-seeds/cards/index.md`: only Davey-family + grimes-pullback + chan-pairs-stat-arb + chan-bollinger-es as of 2026-04-27)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "calendar-date entry/exit gates; holiday-roll rule; standard V5 default (kill-switch, news filter); annual-cycle gate to prevent duplicate entries. Friday-close: NOT used (waived); see hard_rules_at_risk."
  trade_entry:
    used: true
    notes: "calendar-date trigger + holiday-roll-to-next-trading-day for entry; NYMEX session close fill"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close, no pyramiding"
  trade_close:
    used: true
    notes: "calendar-date trigger + holiday-roll-to-previous-trading-day for exit; NYMEX session close fill"
```

```yaml
hard_rules_at_risk:
  - friday_close                              # PRIMARY — 9-trading-day hold spans ~2 weekends; weekly forced-flat structurally incompatible.
                                              #   Card requests explicit V5 framework Hard Rule waiver.
  - dwx_suffix_discipline                     # Chan's universe is NYMEX RB futures; V5 deploys on Darwinex .DWX symbols.
                                              #   Darwinex CFD universe does NOT natively offer gasoline-specific futures.
                                              #   Closest related products: OIL.DWX, BRENT.DWX (NOT direct substitutes).
                                              #   CTO confirms at G0; if no native gasoline product exists, this card REJECTS at G0.
  - darwinex_native_data_only                 # calendar logic doesn't need external data; standard Darwinex feed sufficient
  - kill_switch_coverage                      # no native stop-loss; relies on V5 account-level kill-switch + MAX_DD trip.
                                              #   CTO sanity-checks kill-switch sizing covers worst-case "seasonal pattern breaks
                                              #   for the first time in 15 years" scenario at P5.
  - magic_schema                              # one-trade-per-year cadence may interact awkwardly with V5 magic-formula registry
                                              #   if the registry assumes ongoing strategies; CTO confirms registry slot allocation
                                              #   for annual-cycle strategies at G0.
  - news_pause_default                        # April 13-25 window may overlap with EIA petroleum-status reports (typically Wednesdays);
                                              #   standard V5 P8 news-blackout applies but Chan does not address this. Card flags
                                              #   this risk for P8 evaluation.

at_risk_explanation: |
  friday_close — 9-trading-day hold spans ~2 weekends. Strategy structurally incompatible with
  weekly forced-flat. Card requests documented Hard Rule waiver per V5 framework docs. If waiver
  denied at G0, this card REJECTS.

  dwx_suffix_discipline — primary deployment-blocker. NYMEX RB and QU are not Darwinex symbols.
  V5 stack deploys on Darwinex CFDs (.DWX suffix). The closest Darwinex commodity-futures
  surrogates are OIL.DWX (WTI crude) and BRENT.DWX (Brent crude); these are NOT gasoline products
  and Chan's spring-driving-season thesis may not transfer. CTO confirms at G0. If Darwinex offers
  no gasoline-specific product, this card cannot deploy as-is — Research recommends a P3.5 CSR
  scan over Darwinex-available commodity CFDs to test whether the spring-seasonal pattern survives
  on a related product (or, alternatively, document this card as a "V5-architecture-incompatible
  reference" for future broker-expansion).

  darwinex_native_data_only — calendar logic + standard Darwinex daily OHLC feed; no external
  data required. Not a binding risk.

  kill_switch_coverage — load-bearing. No native stop-loss. V5 account-level kill-switch + MAX_DD
  trip is the catastrophic backstop. CTO sanity-checks that the kill-switch sizing covers a
  hypothetical "seasonal pattern breaks for the first time in 15 years" downside event (e.g., a
  surprise hurricane / refinery closure causing reverse seasonality). P5 stress test models this
  explicitly as a regime-shift event.

  magic_schema — annual-cycle one-trade-per-year cadence is structurally different from V5's
  default ongoing-strategy assumption. CTO confirms magic-formula registry slot allocation
  convention for one-shot annual strategies at G0 / APPROVED.

  news_pause_default — April 13-25 contains 2 Wednesdays, both of which are EIA petroleum-status
  report days. Standard V5 P8 news-blackout could suppress entries inside the news-window, but
  the calendar entry/exit dates are FIXED — there's no "skip the trade if news today" option
  without changing the strategy. Card flags this for P8 evaluation: either (a) accept the news-
  window risk as part of the strategy's edge (Chan's framing implies the seasonal flow overrides
  short-term news noise), or (b) build an EIA-day pre-entry shift rule. P8 decides.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + holiday-roll calendar-date gates + annual-cycle once-per-year guard
  entry: TBD                                  # date-trigger + holiday-roll-to-NEXT — straightforward MQL5 implementation (~30 LOC)
  management: TBD                             # n/a (no trailing / BE / partial)
  close: TBD                                  # date-trigger + holiday-roll-to-PREVIOUS
estimated_complexity: small                   # ~50 LOC in MQL5; calendar arithmetic + once-per-year guard
estimated_test_runtime: <1h                   # single-trade-per-year × 14 years = 14 trades total per backtest run; very fast P3 sweep
data_requirements: standard                   # daily OHLC on Darwinex commodity CFD; NO external data
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-27 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | DRAFT (awaiting CEO + Quality-Business review) | this card |
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
- 2026-04-27: SRC02_S07 surfaces the 4th `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `annual-calendar-trade` — entry on fixed annual calendar date, exit on fixed annual calendar date,
  one-shot per year per symbol. Distinct from existing `intraday-day-of-month` (Gotobi monthly cycle,
  multiple entries per year) and `session-close-seasonality` (intraday window). V4 had no annual-
  calendar-trade SM_XXX EAs per `strategy_type_flags.md` Mining-provenance table. Chan citation:
  Ch 7 sidebar p. 149 (and S08 sidebar p. 150).

  SRC02 vocabulary-gap proposals now stand at 4 (S01 → cointegration-pair-trade + mean-reach-exit;
  S02 → zscore-band-reversion; S07 → annual-calendar-trade). Research will batch-propose all four
  to CEO + CTO via the addition-process documented at the bottom of `strategy_type_flags.md` once
  SRC02 extraction stabilizes (after S03/S04/S05/S06 land in heartbeats 5-6).

- 2026-04-27: Backtest-sample-size concern. With 1 trade/year/symbol, a 14-year backtest yields
  only 14 data points. V5 P7 Statistical Validation (PBO < 5%) and P3 sweep (default 252 data
  points per parameter per `cards/_TEMPLATE.md` § 8 sample-size rule) will struggle with this
  density. Per Chan's own Ch 3 p. 53 sample-size rule of thumb (252 data points per parameter),
  this strategy with even 1-2 free parameters would need ~252-504 years of history to safely
  P3-sweep. The card lists ENTRY_DAY/EXIT_DAY as sweep axes for completeness but flags that
  data-snooping bias is a structural risk: Chan himself selected Apr 13 / Apr 25 by "scanning
  the literature" (verbatim p. 149), which is itself a data-snooping selection. P7 evaluation
  must apply an extreme PBO penalty for low-N strategies, OR Research recommends FREEZING the
  Chan-published dates and disallowing P3-sweep on calendar parameters. CEO decides at APPROVED.

- 2026-04-27: Darwinex symbol availability is the load-bearing G0 risk. NYMEX RB and QU are not
  Darwinex products. The closest Darwinex commodity CFDs (OIL.DWX, BRENT.DWX) are CRUDE oil, not
  refined gasoline — different products, different seasonal-demand drivers, possibly different
  spring patterns. CTO confirms at G0; if no native Darwinex gasoline product exists, this card
  REJECTS. Research recommends Pipeline-Operator run a P3.5 CSR scan over Darwinex-available
  commodity CFDs to test whether the Apr 13 / Apr 25 spring pattern survives on a related product.

- 2026-04-27: Friday-close incompatibility (9-day hold spans 2 weekends) is the second G0 risk.
  Identical to S01 chan-pairs-stat-arb pattern: per-card Hard Rule waiver request.
```
