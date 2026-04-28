# Strategy Card — Chan Natural Gas NG Spring (long-only annual calendar trade on NYMEX natural gas futures)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § F (verbatim Ch 7 narrative + sidebar p. 150 + 14-year P&L table + Amaranth volatility warning).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S08
ea_id: TBD
slug: chan-natgas-spring
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:                          # SRC02 batch ratified by CEO 2026-04-28 (QUA-275 closeout, back-port QUA-332)
  - annual-calendar-trade                     # entry on fixed annual date (Feb 25), exit on fixed annual date (Apr 15); one-shot per year per symbol
  - long-only                                 # Chan p. 150 verbatim: "we long a June contract of NYMEX natural gas futures"
  - time-stop                                 # paired with annual-calendar-trade — exit IS clock-based on a fixed calendar date (Apr 15)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 7 'Special Topics in Quantitative Trading', § 'Seasonal Trading Strategies' transition pp. 149-150 + sidebar 'A Seasonal Trade in Natural Gas Futures' p. 150 (mechanical specification + 14-year P&L table 1995-2008 + Amaranth volatility warning)."
    quality_tier: A
    role: primary
  - type: web
    citation: "Chan, Ernest P. (ongoing). Subscription-area updates. epchan.com/subscription."
    location: "Chan p. 150 attribution: 'This article originally appeared in my subscription area epchan.com/subscription, and is updated with the latest numbers.' Username/password 'sharperatio' published in the book footnote — historical reference; Research does NOT log in for extraction (paywall-respect per V5 hard rules)."
    quality_tier: B
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § F. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **long-only annual calendar trade on NYMEX natural gas futures (NG, June expiry)** that enters at the close of February 25 and exits at the close of April 15 each year. The thesis is fundamental seasonal-demand pull: U.S. summer cooling-load on power generators drives natural-gas demand for electricity, and the late-winter / early-spring pre-summer inventory build-up phase shows persistent annual price pressure from late February through mid-April. Like the gasoline RB sister-strategy (S07), the trade is purely calendar-driven — no indicators, no filters, just a date lookup. Chan reports profitability in **every year 1995-2008** (14 consecutive years through book publication, with 2008 being live-traded results), with annual P&L from $450 to $10,137 per contract.

**Material distinction from S07 (gasoline)**: NG is materially more volatile than RB. The 14-year max single-year drawdown was -$5,550 (2005) on a notional of ~$30K-$60K per contract — roughly 10-18% intra-trade DD — and the 2008 actual-trading run hit -$7,470 mid-trade. Chan explicitly cites the **Amaranth Advisors $6 billion blow-up and Bank of Montreal $450 million loss** on natural-gas futures as a cautionary tale. The strategy is mechanically identical to S07 but operationally far riskier; the position-sizing layer has to translate this into smaller deployment.

Chan's verbatim framing, p. 150:

> "Summer season is also when natural gas demand goes up due to the increasing demand from power generators to provide electricity for air conditioning. This suggests a seasonal trade in natural gas where we long a June contract of NYMEX natural gas futures (Symbol: NG) at the close of February 25 (or the following trading day if it is a holiday), and exit this position on April 15 (or the previous trading day if it is a holiday). This trade has been profitable for 14 consecutive years at of this writing."

Volatility warning (verbatim, p. 150):

> "Natural gas futures are notoriously volatile, and we have seen big trading losses for hedge funds (e.g., Amaranth Advisors, loss = $6 billion) and major banks (e.g., Bank of Montreal, loss = $450 million). Therefore, one should be cautious if one wants to try out this trade—perhaps at reduced capital using the mini QG futures at half the size of the full NG contract."

## 3. Markets & Timeframes

```yaml
markets:
  - commodity_futures                         # NYMEX NG natural gas futures, June expiry
timeframes:
  - D1                                        # daily-bar / close-based entry and exit; calendar-driven, no intraday
session_window: per-day-close                 # fires once at NYMEX close on the entry-rule date
primary_target_symbols:
  - "NG (NYMEX natural gas futures, June expiry) — Chan's deployment, 1 contract"
  - "QG (NYMEX mini natural gas futures, June expiry, half-size) — Chan's reduced-risk alternative"
  - "Darwinex equivalent: TBD at CTO sanity-check — Darwinex CFD universe MAY offer NATGAS.DWX or similar
     natural-gas product. CTO confirms availability at G0. If unavailable, this card REJECTS at G0
     (no natural-gas-related products on Darwinex would be an even cleaner G0 KILL than gasoline since
     the seasonal thesis is power-generation-demand-driven, more product-specific than gasoline)."
```

## 4. Entry Rules

```text
PARAMETERS (Chan-fixed; minimal sweep surface):
- ENTRY_MONTH      = 2               // February
- ENTRY_DAY        = 25              // calendar day of month
- HOLIDAY_RULE     = "next_trading_day"  // Chan: "or the following trading day if it is a holiday"
- CONTRACT_EXPIRY  = "June"          // contract month relative to entry date
- POSITION_SIZE    = 1 contract NG   // or 2-4 contracts mini QG per Chan's reduced-risk alternative

ANNUAL TRIGGER (each calendar year Y, evaluated daily):
- if not in position
  and current_date == roll_to_next_trading_day(year_Y, ENTRY_MONTH, ENTRY_DAY)
  and time_of_day == NYMEX_session_close
  then OPEN_LONG 1 contract NG-JUN-YYYY at close

NO INDICATOR CHECK:
- entry is purely calendar-driven; no MA, no momentum confirm, no volatility filter, no inventory-storage check
- Chan deliberately does NOT add a confirmation filter despite the explicit volatility warning
- Per DL-033 Rule 1, the card preserves Chan's specification — adding filters would be Research extrapolation
```

## 5. Exit Rules

```text
EXIT (only when in position):
- CALENDAR-DATE EXIT:
  - if current_date == roll_to_previous_trading_day(year_Y, EXIT_MONTH=4, EXIT_DAY=15)
    and time_of_day == NYMEX_session_close
    then CLOSE position at close

NO STOP-LOSS:
- Chan does not specify a per-trade stop-loss for this strategy. The 14-year max single-year DD
  was -$5,550 (2005) full contract, or -$7,470 (2008) on actual trading expressed as 4 × QG.
  Chan's anti-stop-loss disposition (Ch 7 p. 143) is for mean-reversion strategies, not seasonals.
  The Amaranth / BMO cautionary tale (Chan p. 150) implies CTO should consider adding a wide
  ATR-based safety stop at APPROVED stage, even though Chan does not specify one.
- The card preserves Chan's specification (no stop) but the `kill_switch_coverage` Hard Rule
  flag in § 12 is more load-bearing here than for S07 because of the Amaranth-class blow-up risk.

NO TIME-STOP BY BAR-COUNT.
NO TRAILING / NO BREAK-EVEN / NO PARTIAL CLOSE.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- holiday-rule for entry date: ENTRY_DAY = February 25; if holiday/non-trading-day, roll to NEXT trading day (Chan)
- holiday-rule for exit date: EXIT_DAY = April 15; if holiday/non-trading-day, roll to PREVIOUS trading day (Chan)
- Friday Close: **WAIVER REQUIRED** — strategy holds 1 contract for ~36 trading days spanning ~7 weekends.
  Substantially longer hold than S07 (gasoline, ~9 trading days). V5 default Friday-close would force-flat
  every Friday and re-open every Monday — destroying the contract and forcing 14 round-trips. Card asks
  for explicit Hard Rule waiver per V5 framework docs. Without waiver: G0 KILL.
- pyramiding: NOT allowed (one contract per year)
- annual-cycle gate: only one entry per calendar year per symbol
- NO inventory-storage filter (e.g., "skip year if EIA storage exceeds 5-year-avg + 2σ"). Chan does not
  include such a filter. CTO + Quality-Tech may consider an OPTIONAL fundamental-overlay filter at
  APPROVED stage given the Amaranth-class risk; not in this card by default.
```

## 7. Trade Management Rules

```text
- one open position at a time (one contract per year)
- position size: 1 contract NG (Chan's full-size example) or 2-4 contracts mini QG (Chan's reduced-risk alternative)
  - V5 maps to risk-mode framework: NG contract notional ≈ 10,000 mmBtu × current NG price ≈ $30K-$80K
    per contract at 2008 prices; the relevant V5 risk-mode percent is calibrated to Amaranth-class
    catastrophic-loss scenarios at the kill-switch trigger
  - Chan's "perhaps at reduced capital using the mini QG futures at half the size of the full NG contract"
    explicitly endorses position-size reduction; V5 risk-mode framework handles this at sizing-time
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: entry_day
  default: 25                                  # Feb 25
  sweep_range: [22, 23, 24, 25, 26, 27, 28]   # ± 3 days
- name: exit_day
  default: 15                                  # Apr 15
  sweep_range: [12, 13, 14, 15, 16, 17, 18]   # ± 3 days
- name: entry_month
  default: 2                                   # February
  sweep_range: [1, 2, 3]                       # Jan / Feb / Mar — broader month-sweep
- name: exit_month
  default: 4                                   # April
  sweep_range: [3, 4, 5]                       # Mar / Apr / May — broader month-sweep
- name: position_size_units
  default: 1                                   # 1 NG contract; OR 2-4 QG mini contracts
  sweep_range: [1]                             # not a P3 axis; size handled by V5 risk-mode at sizing-time
- name: optional_atr_safety_stop
  default: null                                # Chan: no stop; ablation-only
  sweep_range: [null, 5, 10, 20]               # ATR multiplier for OPTIONAL safety stop given Amaranth-class risk
                                               # — recommended P3 axis here vs. S07 because of explicit volatility warning
```

P3.5 (CSR) axis: re-run on related Darwinex-eligible commodity products if available. If `NATGAS.DWX` exists, this card deploys directly. If not, the card REJECTS at G0 — no related Darwinex CFD has the same fundamental-demand seasonal driver (heating/cooling-load on power generation).

## 9. Author Claims (verbatim, with quote marks)

NYMEX NG June contract, Feb 25 → Apr 15 holding period, 1 contract:

> "This trade has been profitable for 14 consecutive years at of this writing." (p. 150)

14-year P&L table (verbatim, p. 150):

| Year | P&L in $ | Maximum Drawdown in $ |
|---|---|---|
| 1995 | 1,970 | 0 |
| 1996 | 3,090 | -630 |
| 1997 | 450 | -430 |
| 1998 | 2,150 | -1,420 |
| 1999 | 4,340 | -370 |
| 2000 | 4,360 | (none listed) |
| 2001 | 2,730 | 0 |
| 2002 | 9,860 | -1,650 |
| 2003 | 2,000 | (none listed) |
| 2004 | 5,430 | 0 |
| 2005 | 2,380 | -5,550 |
| 2006 | 2,250 | (none listed) |
| 2007 | 800 | 0 |
| 2008 (actual, 4×QG) | 10,137 | -1,750 / -7,470 |

(2008 row: actual trading expressed as 4 × QG mini-contracts. Layout artifacts preserved.)

Volatility warning (verbatim, p. 150):

> "Natural gas futures are notoriously volatile, and we have seen big trading losses for hedge funds (e.g., Amaranth Advisors, loss = $6 billion) and major banks (e.g., Bank of Montreal, loss = $450 million). Therefore, one should be cautious if one wants to try out this trade—perhaps at reduced capital using the mini QG futures at half the size of the full NG contract."

## 10. Initial Risk Profile

```yaml
expected_pf: 4.0                              # 14/14 winning years → no losing trades in published sample.
                                              # Out-of-sample 2009-onwards expected to add some losers.
                                              # Same conservative estimate as S07 (gasoline); pipeline P4 walk-forward refines.
expected_dd_pct: 12                           # rough estimate: max single-year DD $5,550 (2005) on contract notional ~$50K
                                              #   ≈ 11%; 2008 actual-trading $7,470 DD on 4 × QG ≈ $90K combined notional ≈ 8%.
                                              # Higher than S07 estimate of 5%; matches Chan's volatility warning.
expected_trade_frequency: 1/year/symbol       # one entry per calendar year per NG contract
risk_class: high                              # 36-trading-day hold spanning ~7 weekends; stop-less position; commodity-futures
                                              # volatility EXTREME (Amaranth-class risk per Chan's explicit warning).
                                              # Higher risk_class than S07 (gasoline = medium).
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (calendar-date lookup + holiday-roll = fully deterministic)
- [x] No Machine Learning required (no statistical model)
- [x] If gridding: not applicable (one contract per year)
- [x] If scalping: not applicable (36-day hold)
- [ ] **Friday Close compatibility: DOES NOT survive forced flat at Friday 21:00 broker time.** 36-trading-day hold spans ~7 weekends; default Friday-close is structurally incompatible. Card requires explicit `friday_close` Hard Rule waiver. Without waiver: G0 KILL.
- [x] Source citation is precise enough to reproduce (chapter + section + sidebar + page + verbatim quotes + dollar-precision P&L table + Amaranth/BMO volatility warning)
- [x] No near-duplicate of existing approved card (sister strategy S07 chan-gasoline-rb-spring uses different symbol + different dates → distinct card per process 13)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "calendar-date entry/exit gates; holiday-roll rule; standard V5 default (kill-switch, news filter, MAX_DD trip); annual-cycle gate. Friday-close: NOT used (waived); see hard_rules_at_risk."
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
  - friday_close                              # PRIMARY — 36-trading-day hold spans ~7 weekends; weekly forced-flat structurally incompatible.
                                              #   Card requests explicit V5 framework Hard Rule waiver. Heavier load than S07 due to longer hold.
  - dwx_suffix_discipline                     # Chan's universe is NYMEX NG / QG futures; V5 deploys on Darwinex .DWX.
                                              #   CTO confirms NATGAS.DWX availability at G0; if absent, this card REJECTS.
  - kill_switch_coverage                      # **HEAVIER LOAD HERE THAN ON ANY OTHER SRC02 CARD.** No native stop-loss + Amaranth-class
                                              #   volatility risk per Chan's explicit warning + 36-day hold = catastrophic-loss scenarios
                                              #   are real (not hypothetical). CTO sanity-checks kill-switch sizing covers a hypothetical
                                              #   "natural-gas seasonal pattern reverses + supply shock simultaneously" event at P5.
                                              #   Recommend P5c crisis slice include 2005-2006 hurricane-season natgas dislocations.
  - magic_schema                              # one-trade-per-year cadence may interact awkwardly with V5 magic-formula registry
  - news_pause_default                        # Feb 25 - Apr 15 window contains ~7 weekly EIA natural-gas storage reports (Thursdays 10:30 ET);
                                              #   Chan does not address this. Standard V5 P8 news-blackout applies but the calendar entry/exit
                                              #   dates are FIXED. P8 evaluation: same trade-off as S07 (accept news-window risk OR shift dates).
  - darwinex_native_data_only                 # calendar logic doesn't need external data; standard Darwinex feed sufficient

at_risk_explanation: |
  friday_close — 36-trading-day hold spans ~7 weekends. Strategy structurally incompatible with weekly
  forced-flat. Card requests documented Hard Rule waiver per V5 framework docs.

  dwx_suffix_discipline — primary deployment-blocker if Darwinex doesn't offer NATGAS.DWX or similar.
  Unlike S07 (gasoline) where OIL.DWX / BRENT.DWX are loosely-related crude-oil products, natural gas
  has NO close substitute in the Darwinex commodity-CFD universe — the seasonal thesis is power-
  generation-cooling-demand-specific. CTO confirms at G0; if no native natgas product exists, this card
  REJECTS without a CSR fallback.

  kill_switch_coverage — load-bearing AND THE PRIMARY OPERATIONAL RISK ON THIS CARD. No native stop-loss.
  Amaranth-class volatility warning (Chan p. 150). 36-day hold provides 7 weekends of weekend-gap
  exposure. CTO confirms kill-switch sizing covers an Amaranth-class scenario at P5; P5c crisis slice
  must include 2005-2006 hurricane-season natgas dislocations (Katrina/Rita 2005, Ike 2008) and the
  March 2020 oil-collapse correlated dislocation. Even with the kill-switch backstop, the V5 risk-mode
  position-sizing for this card should be smaller than S07 by a factor of ~2-4× to absorb the higher
  per-contract DD.

  magic_schema — same as S07; CTO confirms registry slot allocation for annual-cycle strategies.

  news_pause_default — Feb 25 - Apr 15 contains ~7 weekly EIA natgas storage reports (Thursdays
  10:30 ET) plus the spring AGA-storage-build narrative. Standard V5 P8 news-blackout could suppress
  intra-trade exposure to weekly storage prints, but the calendar entry/exit dates are FIXED. P8
  evaluation: accept news-window exposure as part of the strategy's edge OR build an "exit before
  EIA storage report, re-enter after" rule. P8 decides.

  darwinex_native_data_only — calendar logic + standard Darwinex daily OHLC feed; no external data
  required. Not a binding risk.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + holiday-roll calendar-date gates + annual-cycle once-per-year guard
                                              # OPTIONAL: fundamental-overlay filter (e.g., skip year if EIA storage > 5-yr avg + 2σ)
                                              #   given Amaranth-class risk. CTO + Quality-Tech decide at APPROVED.
  entry: TBD                                  # date-trigger + holiday-roll-to-NEXT — straightforward MQL5 (~30 LOC)
                                              # IDENTICAL TO S07 IMPLEMENTATION; symbol + dates parameterized
  management: TBD                             # n/a (no trailing / BE / partial)
  close: TBD                                  # date-trigger + holiday-roll-to-PREVIOUS
estimated_complexity: small                   # ~50 LOC in MQL5; SHARED IMPLEMENTATION with S07 (different parameters)
estimated_test_runtime: <1h                   # 1 trade/year × 14 years = 14 trades total per backtest run
data_requirements: standard                   # daily OHLC on Darwinex commodity CFD; no external data feed required
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
- 2026-04-27: SRC02_S08 is the SISTER card to S07 chan-gasoline-rb-spring. They share an identical
  mechanical template (annual-calendar-trade), differ only in symbol + dates + risk profile. Per
  process 13 ("one strategy = one sub-issue"), they are TWO cards; per implementation expedience,
  CTO can build them as one parameterized module at APPROVED stage. The shared 4th SRC02
  vocabulary-gap proposal `annual-calendar-trade` covers both.

- 2026-04-27: Amaranth-class catastrophic-loss risk is the LOAD-BEARING differentiator vs S07.
  Chan p. 150 explicitly warns: "Natural gas futures are notoriously volatile ... Amaranth Advisors,
  loss = $6 billion ... Bank of Montreal, loss = $450 million." V5 P5 Stress + P5c Crisis Slices
  must include 2005-2006 hurricane-season natgas dislocations (Katrina, Rita, Ike) and 2020-Q1
  energy-collapse dislocations. Without these crisis slices in the test bench, this card cannot
  pass P5c. Recommend Pipeline-Operator pre-document the required P5c slices at G0 ratification
  rather than discovering them at P5c run-time.

- 2026-04-27: Same backtest-sample-size concern as S07 (1 trade/year × 14 years = 14 data points).
  Chan's own Ch 3 p. 53 sample-size rule of thumb (252 data points per parameter) is structurally
  unmeetable for annual-calendar-trade strategies. P7 PBO evaluation must apply the same extreme
  penalty as S07; CEO decides at APPROVED whether to FREEZE Chan-published dates and disallow
  P3-sweep on calendar parameters, vs. accept the small-sample risk.

- 2026-04-27: Darwinex symbol availability is the LOAD-BEARING G0 risk for this card AND it is
  STRICTER than S07's. Gasoline has loosely-related crude-oil substitutes (OIL.DWX, BRENT.DWX) on
  Darwinex; natural gas has NO close substitute. If NATGAS.DWX (or equivalent) doesn't exist on
  Darwinex, this card REJECTS at G0 with no CSR fallback option. Research recommends Pipeline-
  Operator survey Darwinex's commodity-CFD list at G0 before this card advances to P1.

- 2026-04-27: Friday-close incompatibility (36-day hold spans 7 weekends) is the second G0 risk —
  HEAVIER load than S07's 9-day / 2-weekend hold. Same per-card Hard Rule waiver request pattern.
```
