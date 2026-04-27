# Strategy Card — Chan Year-on-Year Same-Month Anomaly (cross-sectional decile MOMENTUM on S&P 500, monthly cycle)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § C (verbatim Ch 7 narrative + Ex 7.7 MATLAB code + Author Sharpe / annual-return print).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S06
ea_id: TBD
slug: chan-yoy-same-month
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:                          # closest existing values from strategy_type_flags.md;
                                              # 5th SRC02 vocabulary gap 'cross-sectional-decile-sort' applies (see § 16, shared with S05/S03/S04).
  - symmetric-long-short                      # long top decile + short bottom decile
  - signal-reversal-exit                      # closest available exit flag — exit fires when monthly rebalance computes new positions (signal recomputation)
  # *vocabulary-gap flag proposed for CEO + CTO ratification per strategy_type_flags.md addition-process (see § 16):
  #   - cross-sectional-decile-sort            # entry mechanism, shared with S05 (and S03/S04 candidates)
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 7 'Special Topics in Quantitative Trading', § 'Seasonal Trading Strategies' year-on-year narrative pp. 146 + Example 7.7 'Backtesting a Year-on-Year Seasonal Trending Strategy' pp. 146-148 (MATLAB code + Author print: avg ann return = -91.67%, Sharpe = -0.1055)."
    quality_tier: A
    role: primary
  - type: paper
    citation: "Heston, Steven L., and Sadka, Ronnie (2007). Seasonality in the Cross-Section of Stock Returns. Robert H. Smith School of Business / Pamplin College of Business, University of Oregon working paper."
    location: "lcb1.uoregon.edu/rcg/seminars/seasonal072604.pdf — cited by Chan p. 146 as the original anomaly source. Reported >13% pre-cost annual return on data prior to 2002."
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § C. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **cross-sectional decile momentum** strategy on the S&P 500 universe with a **monthly rebalance cycle** and a **same-month-last-year lookback signal**. At each month-end M of year Y: sort the universe by each stock's return in calendar month M of year Y-1 (i.e., the same calendar month one year ago). Long the TOP decile (best performers in same-month-last-year), short the BOTTOM decile. Hold for 1 month. The Heston-Sadka 2007 thesis is that calendar-month-specific anomalies persist year over year — stocks that did well in October last year tend to do well in October this year.

**Chan's deliberate-failure-example framing (verbatim, p. 146)**:

> "Another seasonal strategy in equities was proposed more recently (Heston and Sadka, 2007; ...). This strategy is very simple: each month, buy a number of stocks that performed the best in the same month a year earlier, and short the same number of stocks that performed poorest in that month a year earlier. The average annual return before 2002 was more than 13 percent before transaction costs. However, I have found that this effect has disappeared since then, as you can check for yourself in Example 7.7."

Chan's MATLAB-printed result (verbatim, p. 147): **`Avg ann return = -0.9167  Sharpe ratio = -0.1055`** — a near-100% loss across the post-2002 sample. Chan adds (p. 148): "You can try the most recent five years instead of the entire data period, and you will find that the average returns are even worse."

This is one of two **Chan-deliberate-failure cards** in SRC02 (the other being S02 chan-bollinger-es). Per DL-033 Rule 1, Chan's negative framing does not exclude the strategy — it gets a card; pipeline P4 walk-forward / P7 PBO confirm the failure.

**Architecture concern**: same multi-stock cross-section issue as S05 + S03 + S04. V5 single-symbol architecture incompatible.

## 3. Markets & Timeframes

```yaml
markets:
  - us_equities                               # Chan's deployment: S&P 500 (Chan: `load('SPX 20071123', 'tday', 'stocks', 'cl')`)
timeframes:
  - D1                                        # daily-bar data; entries and exits at end-of-day close on month-ends
session_window: per-month-end-close           # fires once per month at NYSE close on the last trading day of each month
primary_target_symbols:
  - "S&P 500 universe (~500 stocks at any time, with quarterly index reconstitution; Chan's snapshot dated 2007-11-23)"
  - "Darwinex equivalent: NONE — same architecture-incompatibility as S05. **Survivorship-bias warning** (Chan p. 146): 'the data contains survivorship bias, as it is based on the S&P 500 index on November 23, 2007' — pipeline P4 walk-forward must use point-in-time index membership, not the 2007 snapshot."
```

## 4. Entry Rules

Pseudocode reduced from Chan's MATLAB in Ex 7.7 (p. 147):

```text
MONTHLY CYCLE (each month-end m, evaluated at NYSE close):
- determine prev_year_same_month = m - 12  (i.e. same calendar month one year earlier)

PRECOMPUTE on month-end m (close):
- for each stock s in universe:
    monthlyret(s, m-1) = (close(s, last_trading_day_of_prior_month) - close(s, last_trading_day_of_2_months_ago))
                       / close(s, last_trading_day_of_2_months_ago)
- prev_year_returns(s) = monthlyret(s, prev_year_same_month)         // sort key
- universe_with_data = { s : prev_year_returns(s) is finite AND close(s, last_trading_day_of_prior_month) is finite }
- topN = floor(|universe_with_data| / 10)              // decile size; Chan's MATLAB: topN = floor(length(mySortIndex)/10)
- sort universe_with_data by prev_year_returns ASCENDING
- LONG_BASKET  = LAST  topN stocks (best performers in same-month-last-year)  ← OPPOSITE direction to S05 January Effect
- SHORT_BASKET = FIRST topN stocks (worst performers in same-month-last-year)

ENTRY (at close of month-end m):
- close any positions from prior month
- for each s in LONG_BASKET:  open_long  with weight = +1 / topN  (equal-weight within decile)
- for each s in SHORT_BASKET: open_short with weight = -1 / topN

NO INDICATOR / NO PRICE FILTER:
- entry is purely calendar-driven + cross-sectional sort by same-month-last-year return
- Chan does NOT add any individual-stock filters
```

## 5. Exit Rules

```text
MONTHLY EXIT (at close of next month-end m+1):
- close ALL positions in LONG_BASKET and SHORT_BASKET at NYSE close
- holding period: ~21 trading days (1 month) regardless of intermediate price action
- new basket opened immediately on the same close (signal-reversal-exit pattern)

NO STOP-LOSS, NO TRAILING, NO INTRA-MONTH REBALANCE.
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: would force-flat the basket each Friday — structurally incompatible with the
  21-trading-day hold spanning ~4 weekends. Card requires explicit `friday_close` Hard Rule waiver.
- pyramiding: NOT applicable (one entry per stock per month)
- monthly-cycle gate: at most one rebalance per calendar month per universe
```

## 7. Trade Management Rules

```text
- equal-weight within deciles: each long stock at +1/topN, each short stock at -1/topN
- transaction cost: Chan's MATLAB (p. 147) does NOT explicitly subtract transaction costs from the
  printed result; the -91.67% annual return is BEFORE transaction costs. Realistic 5 bp/one-way
  costs would worsen the result further.
- universe rebalancing: at each monthly entry, recompute topN; prior month's basket is closed
  before new basket is opened (signal-reversal-exit; 12 round-trips per year vs S05's 1 round-trip per year)
- gridding: NOT allowed
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: decile_n
  default: 10                                  # Chan's choice
  sweep_range: [5, 8, 10, 15, 20]              # per S05 standard
- name: lookback_months
  default: 12                                  # Chan's "same month a year earlier"
  sweep_range: [12, 24, 36]                    # 1y / 2y / 3y same-month lookbacks
- name: hold_months
  default: 1                                   # Chan's monthly rebalance
  sweep_range: [1, 2, 3, 6]                    # 1m / 2m / 3m / 6m holds
- name: universe
  default: "SP500_large_cap"                   # Chan's choice
  sweep_range:                                 # CSR-style universe-variant
    - "SP500_large_cap"
    - "SP400_mid_cap"
    - "SP600_small_cap"
    - "Russell_2000_small_cap"
- name: onewaytcost_bps
  default: 0                                   # Chan: pre-cost
  sweep_range: [0, 1, 5, 10]                   # post-cost evaluation
```

## 9. Author Claims (verbatim, with quote marks)

S&P 500 universe (snapshot 2007-11-23 with survivorship bias), monthly rebalance, pre-cost:

> "Avg ann return = -0.9167   Sharpe ratio = -0.1055" (verbatim MATLAB output, p. 147)

Pre-2002 anomaly framing (verbatim, p. 146):

> "The average annual return before 2002 was more than 13 percent before transaction costs."

Post-2002 disappearance (verbatim, p. 146):

> "However, I have found that this effect has disappeared since then, as you can check for yourself in Example 7.7."

Recent-period worsening (verbatim, p. 148):

> "You can try the most recent five years instead of the entire data period, and you will find that the average returns are even worse."

## 10. Initial Risk Profile

```yaml
expected_pf: 0.5                              # Chan's published Sharpe -0.1055 + avg ann return -91.67% pre-cost
                                              # → expected PF deeply below 1; deliberate-failure example.
expected_dd_pct: 50                           # extreme; -91.67% annualized return implies ~half-of-capital DD or worse
expected_trade_frequency: 12/year (universe-level basket)  # monthly rebalance; 12 round-trips per year per universe
risk_class: high                              # author-disclaimed strategy with negative Sharpe; full universe rebalance
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (cross-sectional sort + decile selection = fully deterministic)
- [x] No Machine Learning required
- [x] If gridding: not applicable
- [x] If scalping: not applicable (1-month hold)
- [ ] **Friday Close compatibility: DOES NOT survive forced flat** (1-month hold spans ~4 weekends). Per-card waiver request.
- [x] Source citation is precise enough to reproduce
- [x] No near-duplicate of existing approved card (sister to S05; distinct lookback signal + opposite direction)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "month-end calendar-date gates; standard V5 default; monthly-cycle gate. Friday-close: NOT used (waived)."
  trade_entry:
    used: true
    notes: "cross-sectional sort by same-month-last-year return + decile selection + equal-weight basket"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close"
  trade_close:
    used: true
    notes: "close-all-basket at next month-end + immediate re-open with new basket (signal-reversal pattern)"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY G0 BLOCKER — same Darwinex-no-equity-cross-section issue as S05
  - one_position_per_magic_symbol             # PRIMARY ARCHITECTURE INCOMPATIBILITY — ~100 simultaneous positions per basket
  - friday_close                              # 4-weekend span; per-card waiver request
  - darwinex_native_data_only                 # universe-level US equity data NOT available natively from Darwinex
  - kill_switch_coverage                      # no native stop-loss
  - magic_schema                              # multi-position basket + monthly-cycle = same structural incompatibility as S05

at_risk_explanation: |
  Same architecture-incompatibility cluster as S05 chan-january-effect: Darwinex doesn't offer the
  500-stock cross-section, V5 magic-formula registry doesn't natively support multi-position baskets,
  and external US equity data feed is required. Card is V5-architecture-INCOMPATIBLE in current form.
  Per DL-033 Rule 1 the card is drafted; G0 / P3.5 decide.

  Recommend G0 verdict path (2) — document as "V5-architecture-incompatible reference" alongside S05
  for future re-activation when QM acquires multi-stock-equity broker access.

  Additional consideration: Chan's own framing (Ex 7.7 p. 146-148) is that this anomaly DECAYED
  post-2002. Even if the architecture-fit problem is solved, P4 walk-forward and P7 PBO will likely
  confirm the negative-Sharpe verdict on out-of-sample 2008-onwards data. The card serves as a
  documented "anomaly that died" reference — useful for the V5 corpus's institutional memory but
  unlikely to advance past P4.

  friday_close — same per-card waiver pattern as S05.
  kill_switch_coverage — relies on V5 account-level kill-switch.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + monthly-cycle gate
  entry: TBD                                  # cross-sectional rank + decile selection — same primitive as S05;
                                              #   could share basket-EA primitive if built
  management: TBD                             # n/a
  close: TBD                                  # close-all-basket at month-end + immediate re-open
estimated_complexity: large                   # same as S05; basket-EA primitive needed
estimated_test_runtime: <1h                   # 12 trades/year × N years; small-but-not-tiny sample
data_requirements: custom_universe            # external feed required; Darwinex INSUFFICIENT
```

## 14. Pipeline History

| version | date | rebuild reason | P-stage reached | verdict |
|---|---|---|---|---|
| _v1 | 2026-04-27 | initial build | TBD | TBD |

## 15. Pipeline Phase Status (current `_v1`)

| Phase | Date | Verdict | Evidence path |
|---|---|---|---|
| G0 Research Intake | 2026-04-27 | DRAFT (awaiting CEO + Quality-Business review) | this card |
| P1 Build Validation | TBD | TBD (likely BLOCKED on V5-architecture-fit) | TBD |

(Remaining P-stages identical to template; omitted for length since architecture-incompatibility is expected to gate at G0/P1, and Chan's own published Sharpe is negative.)

## 16. Lessons Captured

```text
- 2026-04-27: SRC02_S06 is the SISTER card to S05 chan-january-effect. Same vocabulary-gap
  proposal: `cross-sectional-decile-sort` (5th SRC02 gap; see S05 § 16). They share the same
  V5-architecture-incompatibility cluster. They differ in:
    (a) Direction: S05 = MR (long bottom + short top); S06 = momentum (long top + short bottom)
    (b) Cycle: S05 = annual (Dec→Jan); S06 = monthly rebalance
    (c) Lookback: S05 = prior calendar year; S06 = same-calendar-month-last-year
    (d) Author framing: S05 = mixed (1 winner / 2 losers); S06 = explicit failure (-91.67% pre-cost)

- 2026-04-27: Per Rule 1 the card is drafted DESPITE Chan's explicit negative framing. SRC02 now
  has TWO documented Chan-deliberate-failure cards: S02 chan-bollinger-es (transaction-cost fail)
  and S06 chan-yoy-same-month (out-of-sample anomaly decay). Both serve as V5-corpus institutional-
  memory references — useful for cross-walk against V5 P-stage flow (does V5 P4 walk-forward catch
  these failures the way Chan's narrative documents them?). Cross-walk note for SRC02
  completion_report.md: Chan's two-failure-examples pattern matches Davey's (Davey Ch 13 walk-forward
  fail + Davey Ch 1 hogs underspecified). Both authors deliberately include failure cases in their
  pedagogy; V5 must do the same in P-stage validation.

- 2026-04-27: Survivorship-bias caveat important for P4 walk-forward. Chan's MATLAB explicitly warns
  (p. 146): "Note that the data contains survivorship bias, as it is based on the S&P 500 index on
  November 23, 2007." Pipeline P4 must use point-in-time index membership; the published -91.67%
  may UNDERSTATE the true historical loss.

- 2026-04-27: Friday-close incompatibility (1-month hold spans 4 weekends) — same per-card waiver
  pattern as S05 / S07 / S08.
```
