# Strategy Card — Chan January Effect (cross-sectional decile MR on small-cap equities, Dec-close → Jan-close)

> Drafted by Research Agent on 2026-04-27 from `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § B (verbatim Ch 7 narrative + Ex 7.6 MATLAB code + 3-year P&L printouts).
> Submitted for CEO + Quality-Business review (Quality-Business not yet hired → CEO-only review per QUA-188 waiver v3).

## Card Header

```yaml
strategy_id: SRC02_S05
ea_id: TBD
slug: chan-january-effect
status: DRAFT
created: 2026-04-27
created_by: Research
last_updated: 2026-04-27

strategy_type_flags:                          # closest existing values from strategy_type_flags.md;
                                              # SRC02 surfaces a 5th vocabulary gap: 'cross-sectional-decile-sort' (see § 16).
  - symmetric-long-short                      # long bottom decile + short top decile = both directions
  - time-stop                                 # closest available exit flag — exit IS clock-based on a fixed calendar date (Jan 31)
  # *vocabulary-gap flags proposed for CEO + CTO ratification per strategy_type_flags.md addition-process (see § 16):
  #   - cross-sectional-decile-sort            # entry mechanism: sort universe by a lookback metric, long top/bottom decile + short opposite decile
  #   - annual-calendar-trade                  # entry on fixed annual date (Dec close), exit on fixed annual date (Jan close); shared with S07/S08
```

## 1. Source

```yaml
source_citations:
  - type: book
    citation: "Chan, Ernest P. (2009). Quantitative Trading: How to Build Your Own Algorithmic Trading Business. Wiley Trading. ISBN 978-0-470-28488-9 (cloth). Hoboken, NJ: John Wiley & Sons."
    location: "Chapter 7 'Special Topics in Quantitative Trading', § 'Seasonal Trading Strategies' January Effect narrative pp. 143-144 + Example 7.6 'Backtesting the January Effect' pp. 144-146 (MATLAB code + 3-year P&L printouts 2005-2007)."
    quality_tier: A
    role: primary
  - type: book
    citation: "Singal, Vijay (2006). Beyond the Random Walk: A Guide to Stock Market Anomalies and Low-Risk Investing. Oxford University Press."
    location: "cited by Chan p. 143 as the canonical reference for the January Effect's tax-loss-selling rationale"
    quality_tier: A
    role: supplement
```

Raw evidence: `strategy-seeds/sources/SRC02/raw/seasonal_calendar_trades.md` § B. Source PDF on disk at `G:\My Drive\QuantMechanica\Ebook\PDF resources\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf`.

## 2. Concept

A **cross-sectional decile mean-reversion** trade on the S&P 600 small-cap universe. At the close of the last trading day of December year Y-1: sort the universe by **prior-year (year Y-1) annual return**. Long the BOTTOM decile (worst losers), short the TOP decile (best winners). Hold the long-short basket through the close of the last trading day of January year Y. The thesis is **tax-loss selling** — investors sell their losers in December to harvest tax losses, which creates additional downward pressure that reverses when the selling pressure disappears in January.

Chan's verbatim framing, p. 143:

> "The most famous seasonal trade in equities is called the January effect. There are actually many versions of this trade. One version states that small-cap stocks that had the worst returns in the previous calendar year will have higher returns in January than small-cap stocks that had the best returns (Singal, 2006). The rationale for this is that investors like to sell their losers in December to benefit from tax losses, which creates additional downward pressure on their prices. When this pressure disappeared in January, the prices recovered somewhat."

**Mixed performance**: of the 3 published years (2005, 2006, 2007), the strategy lost in 2 (2005-2006: -2.44% / -0.68% portfolio return) and won in 1 (2007: +8.81%). Chan attributes the 2008 win partly to the Société Générale unwind / Federal Reserve emergency 75bp cut that "slaughtered momentum strategies" but rewarded mean-reversal strategies.

**Architecture concern**: this is a multi-stock cross-section over ~600 small-caps. V5 single-symbol EA architecture is structurally incompatible. Card drafted per DL-033 Rule 1; G0 / P3.5 decide actual deployability.

## 3. Markets & Timeframes

```yaml
markets:
  - us_equities                               # Chan's deployment: S&P 600 small-cap stocks (Chan: `load('IJR 20080131')` — IJR = iShares S&P SmallCap 600 ETF, used as universe definition)
timeframes:
  - D1                                        # daily-bar data; entries and exits at end-of-day close on calendar dates
session_window: per-day-close                 # fires once per year at NYSE close on the last trading day of December (entry) and last trading day of January (exit)
primary_target_symbols:
  - "S&P 600 small-cap universe (~600 stocks at any time, with monthly index reconstitution)"
  - "Darwinex equivalent: NONE — Darwinex CFD universe does NOT offer 600 individual US small-cap stocks. Card is V5-architecture-INCOMPATIBLE; CTO confirms at G0 likely G0 KILL."
```

## 4. Entry Rules

Pseudocode reduced from Chan's MATLAB in Ex 7.6 (pp. 144-145):

```text
ANNUAL CYCLE (each calendar year Y, evaluated at end-of-day):
- determine last_trading_day_of_December year Y-1 (= entry_date)
- determine last_trading_day_of_December year Y-2 (= prior_year_endpoint)

PRECOMPUTE on entry_date (close):
- for each stock s in universe:
    annret(s) = (close(s, last_trading_day_of_December_Y-1) - close(s, last_trading_day_of_December_Y-2))
              / close(s, last_trading_day_of_December_Y-2)
- universe_with_data = { s : annret(s) is finite }
- topN = round(|universe_with_data| / 10)              // decile size; Chan's MATLAB: topN = round(length(hasData)/10)
- sort universe_with_data by annret ASCENDING
- LONG_BASKET  = first topN stocks (worst-loser decile)
- SHORT_BASKET = last  topN stocks (best-winner decile)

ENTRY (at close of entry_date):
- for each s in LONG_BASKET:  open_long  with weight = +1 / topN  (equal-weight within decile)
- for each s in SHORT_BASKET: open_short with weight = -1 / topN

NO INDICATOR / NO PRICE FILTER:
- entry is purely calendar-driven + cross-sectional sort by annual return
- Chan does NOT add any individual-stock filters (e.g., min market cap, min price, no penny stocks)
- Per DL-033 Rule 1, the card preserves Chan's specification
```

## 5. Exit Rules

```text
EXIT (at close of last_trading_day_of_January year Y):
- close ALL positions in LONG_BASKET and SHORT_BASKET at NYSE close
- holding period: ~21 trading days (1 month) regardless of intermediate price action

NO STOP-LOSS, NO TRAILING, NO INTRA-MONTH REBALANCE:
- Chan's anti-stop-loss disposition (Ch 7 p. 143) for mean-reversal models applies here
- Constituent stocks that exit the universe mid-trade (delisting, M&A) require ad-hoc handling;
  Chan's MATLAB does not address this — assume hold-to-end-of-month and accept the mark
```

## 6. Filters (No-Trade module)

```text
- standard V5 framework defaults: kill-switch, news filter, MAX_DD trip
- Friday Close: would force-flat the basket each Friday — structurally incompatible with the
  21-trading-day hold spanning ~4 weekends. Card requires explicit `friday_close` Hard Rule waiver.
- pyramiding: NOT applicable (one entry per stock per year)
- annual-cycle gate: only one entry per calendar year per universe; framework state must remember
  "already entered this year" to prevent duplicate entries from clock drift / restart edge cases
```

## 7. Trade Management Rules

```text
- equal-weight within deciles: each long stock at +1/topN, each short stock at -1/topN
- transaction cost in Chan's backtest: 5 bp one-way (`onewaytcost = 0.0005`), applied at entry AND exit
  → portfolio return formula (verbatim Ch 7 p. 145):
      portRet = (mean(janret_top_losers) - mean(janret_top_winners)) / 2 - 2 * onewaytcost
    The 2 * onewaytcost term covers entry + exit one-way costs for both legs combined;
    the / 2 averages across the two equal-weighted halves of the long-short.
- gridding: NOT allowed
- universe rebalancing: at each annual entry, recompute topN based on stocks with valid annret data;
  prior year's basket is closed before new basket is opened
```

## 8. Parameters To Test (P3 Sweep)

```yaml
- name: decile_n
  default: 10                                  # top/bottom decile (Chan's choice)
  sweep_range: [5, 8, 10, 15, 20]              # quintile (5) / octile (8) / decile (10) / 15-tile / 20-tile
- name: lookback_period
  default: "calendar_year_Y-1"                 # Chan's choice: full prior calendar year
  sweep_range:                                 # alternative lookback windows
    - "calendar_year_Y-1"
    - "trailing_252_trading_days_from_entry_date"
    - "trailing_126_trading_days_from_entry_date"
    - "trailing_63_trading_days_from_entry_date"  // Q4 only
- name: hold_month
  default: 1                                   # January (Chan's choice)
  sweep_range: [1]                             # NOT a sweep axis — the entire thesis IS January-specific
- name: universe
  default: "SP600_small_cap"                   # Chan's choice
  sweep_range:                                 # CSR-style universe-variant axis
    - "SP600_small_cap"
    - "SP400_mid_cap"
    - "SP500_large_cap"
    - "Russell_2000_small_cap"
- name: onewaytcost_bps
  default: 5                                   # Chan's assumption
  sweep_range: [1, 3, 5, 10]                   # validate transaction-cost sensitivity (a key driver per Chan's broader Ch 3 discussion)
```

P3.5 (CSR) axis: re-run on universe variants (S&P 400 mid-cap, S&P 500 large-cap, Russell 2000) to test whether the January Effect is small-cap-specific (Chan's claim) or generalizes upward into the cap distribution.

## 9. Author Claims (verbatim, with quote marks)

S&P 600 small-cap universe, Dec-close → Jan-close holding, 5 bp/one-way transaction cost:

> "Last holding date 20051230: Portfolio return = -0.0244" (verbatim MATLAB output, p. 145)
>
> "Last holding date 20061229: Portfolio return = -0.0068" (verbatim MATLAB output, p. 145)
>
> "Last holding date 20071231: Portfolio return = 0.0881" (verbatim MATLAB output, p. 145)

Chan's qualitative framing (verbatim, p. 144):

> "This strategy did not work in 2006-07, but worked wonderfully in January 2008, which was a spectacular month for mean-reversal strategies. (That January was the one that saw a major trading scandal at Société Générale, which indirectly may have caused the Federal Reserve to have an emergency 75-basis-point rate cut before the market opened. The turmoil slaughtered many momentum strategies, but mean-reverting strategies benefited greatly from the initial severe downturn and then dramatic rescue by the Fed.)"

Chan's broader equity-seasonality stance (verbatim, p. 143):

> "much of the seasonality in equity markets has weakened or even disappeared in recent years, perhaps due to the widespread knowledge of this trading opportunity, whereas some seasonal trades in commodity futures are still profitable."

## 10. Initial Risk Profile

```yaml
expected_pf: 0.9                              # 1/3 winning years in published 3-year sample → PF < 1 likely;
                                              # Chan's broader "much of the seasonality in equity markets has weakened" framing suggests
                                              # out-of-sample 2009-onwards continues to disappoint. Conservative estimate 0.9.
expected_dd_pct: 10                           # rough estimate; max single-year loss in published sample = -2.44% in 2005,
                                              # but multi-year compounded DD could exceed that
expected_trade_frequency: 1/year (universe-level basket)  # one entry per calendar year per universe; ~120 stock-positions per entry
risk_class: medium                            # equity-cross-section with no leverage; basket-level DD bounded
gridding: false
scalping: false
ml_required: false
```

## 11. Strategy Allowability Check (V5 framework)

- [x] Strategy concept is mechanical (cross-sectional sort + top/bottom decile + equal-weight = fully deterministic)
- [x] No Machine Learning required (no statistical model)
- [x] If gridding: not applicable
- [x] If scalping: not applicable (1-month hold)
- [ ] **Friday Close compatibility: DOES NOT survive forced flat at Friday 21:00 broker time** (1-month hold spans ~4 weekends). Card requires explicit `friday_close` Hard Rule waiver. Without waiver: G0 KILL.
- [x] Source citation is precise enough to reproduce (chapter + section + Example + page + verbatim MATLAB + verbatim 3-year P&L printouts)
- [x] No near-duplicate of existing approved card (closest cousin: SRC01 davey-eu-day uses 60-min bars on Euro futures — different universe, different timeframe)

## 12. Framework Alignment

```yaml
modules_used:
  no_trade:
    used: true
    notes: "calendar-date entry/exit gates; standard V5 default (kill-switch, news filter, MAX_DD trip); annual-cycle gate. Friday-close: NOT used (waived); see hard_rules_at_risk."
  trade_entry:
    used: true
    notes: "cross-sectional sort + decile selection + equal-weight basket on annual entry date"
  trade_management:
    used: false
    notes: "no trailing, no break-even, no partial close, no intra-month rebalance"
  trade_close:
    used: true
    notes: "calendar-date trigger on last_trading_day_of_January; close all basket positions at NYSE close"
```

```yaml
hard_rules_at_risk:
  - dwx_suffix_discipline                     # PRIMARY G0 BLOCKER — Darwinex CFD universe does NOT offer 600 individual US small-cap stocks.
                                              #   Closest substitutes: an ETF tracker (IJR.DWX, if it exists) gives MARKET-AVERAGE exposure, NOT
                                              #   the long-loser/short-winner cross-section. The strategy IS the cross-section; without per-stock
                                              #   exposure, the strategy cannot deploy. **G0 likely KILL.** CTO confirms at G0.
  - one_position_per_magic_symbol             # PRIMARY ARCHITECTURE INCOMPATIBILITY — strategy holds ~120 simultaneous positions
                                              #   (60 long + 60 short stocks per decile basket on a 600-stock universe). V5 magic-formula
                                              #   registry is ea_id*10000+symbol_slot, with one position per magic. Cross-sectional baskets
                                              #   require a different framework primitive (basket-level magic) that V5 does NOT have.
  - friday_close                              # 1-month hold spans ~4 weekends; weekly forced-flat is structurally incompatible. Per-card waiver request.
  - darwinex_native_data_only                 # universe-level data (split/dividend-adjusted close on 600 stocks) is NOT available natively from
                                              #   Darwinex (which is a forex/CFD broker, not a US equity broker). External data feed required;
                                              #   Hard Rule binds.
  - kill_switch_coverage                      # no native stop-loss; relies on V5 account-level kill-switch
  - magic_schema                              # annual-cycle one-trade-per-year cadence + multi-position basket = double-incompatibility with V5 schema

at_risk_explanation: |
  dwx_suffix_discipline + one_position_per_magic_symbol + darwinex_native_data_only — these three risks
  combine to make the card V5-ARCHITECTURE-INCOMPATIBLE in its current form. The strategy IS the
  cross-section over a US small-cap universe; an ETF-tracker substitute (IJR.DWX) gives the wrong
  exposure. Per DL-033 Rule 1 the card is drafted regardless; G0 / P3.5 decide.

  Two paths forward at G0:
    (1) REJECT the card as architecture-incompatible — preserves the V5 single-symbol stack discipline
    (2) Document the card as a "V5-architecture-incompatible reference" for future broker-expansion
        (when QM acquires a multi-stock-equity broker, this card and its sister S06 / S03 / S04
        become deployable)
  Recommend path (2) so the V5 corpus retains the strategy specification for future re-activation.

  friday_close — 4-weekend span; per-card waiver request (same pattern as S07 + S08).

  kill_switch_coverage — V5 account-level kill-switch is the catastrophic backstop. Less load-bearing
  here than for S08 (no Amaranth-class single-event risk in equity cross-sectionals).

  magic_schema — annual-cycle + multi-position-basket combination is structurally novel for V5.
  CTO sanity-checks how the magic-formula registry would absorb a basket-level annual-cycle EA at G0.
```

## 13. Implementation Notes (CTO fills in at APPROVED stage)

```yaml
target_modules:
  no_trade: TBD                               # standard V5 default + holiday-roll + annual-cycle once-per-year guard
  entry: TBD                                  # cross-sectional sort over universe + decile selection + equal-weight basket
                                              #   — V5 has NO basket-EA primitive; either build one or reject card at G0
  management: TBD                             # n/a (no trailing / BE / partial)
  close: TBD                                  # calendar-date trigger + close-all-basket-positions
estimated_complexity: large                   # multi-position basket + cross-sectional rank computation + universe-level data integration
                                              #   = substantially more involved than any other SRC02 card
estimated_test_runtime: <1h                   # 1 trade/year/universe × N years; tiny sample size, tiny runtime
data_requirements: custom_universe            # external feed required for ~600 small-cap stocks with split/dividend adjustment;
                                              #   Darwinex feed is INSUFFICIENT
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

(Remaining P-stages identical to template; omitted for length since architecture-incompatibility is expected to gate at G0/P1.)

## 16. Lessons Captured

```text
- 2026-04-27: SRC02_S05 surfaces the 5th `strategy_type_flags` controlled-vocabulary GAP (entry side):
  `cross-sectional-decile-sort` — entry mechanism: rank a universe of N securities by a lookback
  metric (annual return, monthly return, value-factor exposure, etc.), long the top decile + short
  the bottom decile (or vice-versa for MR-style). Distinct from any single-security entry mechanism
  in `strategy_type_flags.md` Section A. V4 had no cross-sectional-decile-sort EAs in the SM_XXX
  deployed family per the Mining-provenance table — V4 was entirely single-symbol-EA-based.

  This same flag covers S05 (january-effect, MR-direction: long bottom decile + short top decile)
  AND S06 (yoy-same-month, momentum-direction: long top decile + short bottom decile)
  AND S03 (khandani-lo, weight-by-distance-from-mean, related but not strictly decile-sort)
  AND S04 (pca-factor, top/bottom-N rank by expected return, related but PCA-derived).

  SRC02 vocabulary-gap proposals now stand at 5:
    S01 → cointegration-pair-trade (entry), mean-reach-exit (exit)
    S02 → zscore-band-reversion (entry)
    S07/S08 → annual-calendar-trade (entry)
    S05/S06/S03/S04 → cross-sectional-decile-sort (entry)
  Will batch-propose all 5 to CEO + CTO via the strategy_type_flags.md addition-process once SRC02
  extraction stabilizes (after S03/S04/S06/S09 land in heartbeats 6-7).

- 2026-04-27: V5-architecture-incompatibility is the load-bearing G0 risk. Strategy holds ~120
  simultaneous stock positions on a 600-stock universe; V5 magic-formula registry is single-position-
  per-magic-symbol. The card is drafted per DL-033 Rule 1 and serves as a "V5-architecture-
  incompatible reference" — preserves the strategy specification for future re-activation when QM
  acquires multi-stock-equity broker access. Same pattern as S03 / S04 / S06 (all multi-stock).

- 2026-04-27: Tiny backtest sample size (1 trade/year × 14 years = 14 data points) shares the same
  P7 PBO concern as S07/S08 (commodity calendar trades). Calendar parameters should be FROZEN at
  Chan-published values to avoid data-snooping; only universe-variant CSR axis (P3.5) is appropriate
  for sweeping.

- 2026-04-27: Chan's broader equity-seasonality stance (p. 143) explicitly warns that "much of the
  seasonality in equity markets has weakened or even disappeared in recent years." Author's own
  3-year sample (2005-2007) shows 1 winner / 2 losers, with the win driven by a tail event
  (Société Générale unwind + Fed emergency rate cut, January 2008). P4 walk-forward and P7 PBO
  evaluation must apply the standard out-of-sample skepticism.
```
