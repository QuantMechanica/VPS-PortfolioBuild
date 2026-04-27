---
source_id: SRC02
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Quantitative Trading_ How to Bu - Ernest P. Chan.pdf"
extracted_section: "Chapter 7 § 'Seasonal Trading Strategies' (pp. 143-150) + § 'High-Frequency Trading Strategies' (pp. 151-153) + § 'Is It Better to Have a High-Leverage versus a High-Beta Portfolio?' (pp. 153-154) — combined raw evidence + skip-rationale"
book_pages: "143-154"
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# SRC02 raw evidence — Chapter 7 Seasonal + HFT + Leverage sections

This file aggregates verbatim source text for the four candidate seasonal strategies in Chan Ch 7 § "Seasonal Trading Strategies" (pp. 143-150) and documents the skip rationale for the two narrative-only sections that follow (HFT pp. 151-153, Leverage-vs-Beta pp. 153-154). Per DL-033 Rule 1, every distinct mechanical strategy gets a card; pure narrative or methodology-only sections do not.

| Source location | Cardability | Card slug |
|---|---|---|
| Example 7.6 January Effect (pp. 143-146) | CARDABLE — multi-stock cross-sectional | S05 `chan-january-effect` (later heartbeat) |
| Example 7.7 Year-on-Year same-month (pp. 146-148) | CARDABLE — multi-stock cross-sectional, deliberate-failure example | S06 `chan-yoy-same-month` (later heartbeat) |
| Gasoline RB calendar trade sidebar (p. 149) | CARDABLE — **single-symbol annual calendar trade**, 14-year track record | **S07 `chan-gasoline-rb-spring`** (this heartbeat) |
| Natural Gas NG calendar trade sidebar (p. 150) | CARDABLE — **single-symbol annual calendar trade**, 14-year track record | **S08 `chan-natgas-spring`** (this heartbeat) |
| HFT narrative (pp. 151-153) | SKIP — narrative-only, no specific entry/exit rules | (skip table in source.md) |
| Leverage-vs-Beta section (pp. 153-154) | SKIP — methodology, not a strategy | (skip table in source.md) |

This heartbeat (4) drafts S07 + S08; S05 + S06 (multi-stock cross-sectionals) bundle with the other multi-stock candidates (Ex 3.7 Khandani-Lo, Ex 7.4 PCA, Ch 7 PEAD) in subsequent heartbeats.

---

## A. Section opener — "Seasonal Trading Strategies" (verbatim, p. 143)

> "This type of trading strategy is also called the calendar effect. Generally, these strategies recommend that you buy or sell certain securities at a fixed date of every year, and close the position at another fixed date. These strategies have been applied to both equity and commodity futures markets. However, from my own experience, much of the seasonality in equity markets has weakened or even disappeared in recent years, perhaps due to the widespread knowledge of this trading opportunity, whereas some seasonal trades in commodity futures are still profitable."

Chan's structural claim: equity-side seasonals (January Effect, Heston-Sadka year-on-year) have decayed; commodity-futures seasonals (gasoline, natural gas) "are alive and well" (verbatim p. 148).

## B. Example 7.6 — January Effect on small-cap stocks (pp. 143-146)

### B.1 Concept (verbatim, p. 143)

> "The most famous seasonal trade in equities is called the January effect. There are actually many versions of this trade. One version states that small-cap stocks that had the worst returns in the previous calendar year will have higher returns in January than small-cap stocks that had the best returns (Singal, 2006). The rationale for this is that investors like to sell their losers in December to benefit from tax losses, which creates additional downward pressure on their prices. When this pressure disappeared in January, the prices recovered somewhat."

### B.2 Mechanical structure (from Ex 7.6 MATLAB, p. 144-145)

- Universe: S&P 600 small-cap stocks (Chan: `load('IJR 20080131')` — IJR is the iShares S&P SmallCap 600 ETF tracker)
- Annual sort key: prior year's annual return (close of last trading day in December year Y-1 vs close of last trading day in December year Y-2)
- Entry: at close of last trading day of December year Y-1 (each year)
- Position: long the BOTTOM decile (worst losers prior year), short the TOP decile (best winners prior year), equal-weighted within each decile
- Exit: at close of last trading day of January year Y
- Holding period: ~21 trading days (1 month)
- Transaction cost assumed: 5 bp one-way (`onewaytcost = 0.0005`)

### B.3 Performance (verbatim, p. 145)

```
Last holding date 20051230: Portfolio return = -0.0244     (-2.44%)
Last holding date 20061229: Portfolio return = -0.0068     (-0.68%)
Last holding date 20071231: Portfolio return =  0.0881     (+8.81%)
```

> "This strategy did not work in 2006-07, but worked wonderfully in January 2008, which was a spectacular month for mean-reversal strategies. (That January was the one that saw a major trading scandal at Société Générale, which indirectly may have caused the Federal Reserve to have an emergency 75-basis-point rate cut before the market opened. ...)" (p. 144)

V5 architecture concern: multi-stock daily-rebalance cross-section across 600 small-caps. Same architecture issue as S03 (Khandani-Lo) and S04 (PCA factor). Card drafted per Rule 1; G0 / P3.5 likely KILL.

## C. Example 7.7 — Heston-Sadka Year-on-Year Same-Month Anomaly (pp. 146-148)

### C.1 Concept (verbatim, p. 146)

> "Another seasonal strategy in equities was proposed more recently (Heston and Sadka, 2007; available at lcb1.uoregon.edu/rcg/seminars/seasonal072604.pdf). This strategy is very simple: each month, buy a number of stocks that performed the best in the same month a year earlier, and short the same number of stocks that performed poorest in that month a year earlier. The average annual return before 2002 was more than 13 percent before transaction costs. However, I have found that this effect has disappeared since then, as you can check for yourself in Example 7.7."

### C.2 Mechanical structure (from Ex 7.7 MATLAB, p. 147)

- Universe: S&P 500 stocks (`SPX 20071123`)
- Each month-end: sort stocks by their return in the SAME calendar month one year earlier
- Entry: top decile of last-year-same-month returns → long; bottom decile → short
- Hold: through next month
- Rebalance: monthly

### C.3 Performance (verbatim, p. 147)

```
Avg ann return = -0.9167                        (-91.67% — yes, ninety-one percent)
Sharpe ratio   = -0.1055
```

> "You can try the most recent five years instead of the entire data period, and you will find that the average returns are even worse." (p. 148)

**Deliberate-failure example**, similar to S02 chan-bollinger-es (Chan demonstrating that an academic anomaly has decayed out-of-sample). Card drafted per Rule 1.

V5 architecture concern: same multi-stock cross-section issue.

## D. Section transition (verbatim, p. 148)

> "In contrast to equity seasonal strategies, commodity futures' seasonal strategies are alive and well. That is perhaps because seasonal demand for certain commodities is driven by 'real' economic needs rather than speculations."

## E. Gasoline RB Calendar Trade — sidebar p. 149

### E.1 Concept (verbatim, p. 148-149)

> "One of the most intuitive commodity seasonal trades is the gasoline future trade: Simply buy the gasoline future contract that expires in May near the middle of April, and sell it by the end of April. This trade has been profitable for the last 11 years, as of this writing in April 2008. ... It appears that one can always depend on approaching summer driving seasons in North America to drive up gasoline futures prices in the spring."

### E.2 Mechanical specification (verbatim sidebar, p. 149)

> "Whenever the summer driving season comes up, it should not surprise us that gasoline futures prices will be rising seasonally. The only question for the trader is: which month contract to buy, and to hold for what period? After scanning the literature, the best trade I have found so far is one where we buy 1 contract of RB (the unleaded gasoline futures trading on the New York Mercantile Exchange [NYMEX]) at the close of April 13 (or the following trading day if it is a holiday), and sell it at the close of April 25 (or the previous trading day if it is a holiday). Historically, we would have realized a profit every year since 1995."

### E.3 Performance table (verbatim, p. 149)

| Year | P&L in $ | Maximum Drawdown in $ |
|---|---|---|
| 1995 | 1,037 | 0 |
| 1996 | 1,638 | -2,226 |
| 1997 | 227 | -664 |
| 1998 | 118 | 0 |
| 1999 | 197 | (none listed in table) |
| 2000 | 735 | -588 |
| 2001 | 1,562 | -315 |
| 2002 | 315 | (none listed in table) |
| 2003 | 1,449 | 0 |
| 2004 | 361 | 0 |
| 2005 | 6,985 | -38 |
| 2006 | 890 | -907 |
| 2007* | 2,286 | -25 |
| 2008* | 4,741 | 0 / -9,816 |

(Asterisks denote actual trading results expressed as 2 × QU mini-contracts. Some rows had drawdown column blank in the source layout; preserved as "none listed".)

> "For those who desire less risk, you can buy the mini gasoline futures QU at NYMEX which trade at half the size of RB, though it is illiquid."
>
> "(This research has been inspired by the monthly seasonal trades published by Paul Kavanaugh at PFGBest.com. You can read up on this and other seasonal futures patterns in Fielden, 2005, or Toepke, 2004.)"

### E.4 Mechanical structure summary

| Element | Specification |
|---|---|
| Symbol | NYMEX RB (unleaded gasoline futures, May expiry) — alternate: QU (mini, half-size) |
| Direction | Long only |
| Entry date | close of April 13 (or next trading day if holiday) |
| Exit date | close of April 25 (or previous trading day if holiday) |
| Holding period | ~12 calendar days (~9 trading days), spans ~2 weekends |
| Position size | 1 contract (or 2 contracts mini QU) |
| Stop-loss | none specified; max DD historically -$2,226 (1996) |
| Track record | 14 consecutive years of profitability (1995-2008 as of book writing, April 2008) |

## F. Natural Gas NG Calendar Trade — sidebar p. 150

### F.1 Concept (verbatim, pp. 149-150)

> "Besides demand for gasoline, natural gas demand also goes up as summer approaches due to increasing demand from power generators to provide electricity for air conditioning. Hence, another commodity seasonal trade that has been profitable for 13 consecutive years as of this writing is the natural gas trade: Buy the natural gas future contract that expires in June near the end of February, and sell it by the middle of April."

### F.2 Mechanical specification (verbatim sidebar, p. 150)

> "Summer season is also when natural gas demand goes up due to the increasing demand from power generators to provide electricity for air conditioning. This suggests a seasonal trade in natural gas where we long a June contract of NYMEX natural gas futures (Symbol: NG) at the close of February 25 (or the following trading day if it is a holiday), and exit this position on April 15 (or the previous trading day if it is a holiday). This trade has been profitable for 14 consecutive years at of this writing."

(Note the inconsistency in the source: section opener at p. 149 says "13 consecutive years," sidebar at p. 150 says "14 consecutive years." Card adopts "14 consecutive years 1995-2008" since the sidebar is the more specific statement and the corresponding P&L table starts at 1995.)

### F.3 Performance table (verbatim, p. 150)

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
| 2008* | 10,137 | -1,750 / -7,470 |

(Asterisk: actual trading results expressed as 4 × QG mini-contracts. Layout artifacts preserved.)

> "Natural gas futures are notoriously volatile, and we have seen big trading losses for hedge funds (e.g., Amaranth Advisors, loss = $6 billion) and major banks (e.g., Bank of Montreal, loss = $450 million). Therefore, one should be cautious if one wants to try out this trade—perhaps at reduced capital using the mini QG futures at half the size of the full NG contract."

(Sidebar attribution: "This article originally appeared in my subscription area epchan.com/subscription, and is updated with the latest numbers.")

### F.4 Mechanical structure summary

| Element | Specification |
|---|---|
| Symbol | NYMEX NG (natural gas futures, June expiry) — alternate: QG (mini, half-size) |
| Direction | Long only |
| Entry date | close of February 25 (or next trading day if holiday) |
| Exit date | close of April 15 (or previous trading day if holiday) |
| Holding period | ~50 calendar days (~36 trading days), spans ~7 weekends |
| Position size | 1 contract (or 4 contracts mini QG) |
| Stop-loss | none specified; max DD historically up to $7,470 (2008 actual trading) |
| Track record | 14 consecutive years of profitability (1995-2008) |
| Volatility warning (verbatim) | "Natural gas futures are notoriously volatile ... Amaranth Advisors, loss = $6 billion" |

## G. Common-template note (S07 vs S08)

S07 (gasoline) and S08 (natgas) are **mechanically near-identical** — both are "long a specific NYMEX commodity-futures contract on a fixed annual entry date, exit on a fixed annual exit date, equal-sized one-contract position, no stop-loss." They differ only in:

- Symbol (RB vs NG)
- Entry date (Apr 13 vs Feb 25)
- Exit date (Apr 25 vs Apr 15)
- Holding-period length (~9 trading days vs ~36 trading days — material risk difference)
- Volatility profile (gas/RB ~moderate; NG flagged as "notoriously volatile" with explicit hedge-fund-blow-up cautionary tale)

Per process 13 ("one strategy = one sub-issue under this parent"), they are TWO distinct cards. Per Rule 1, both extracted regardless of architecture-fit. The cards share:

- A `vocabulary-gap proposal` for `annual-calendar-trade` flag (4th SRC02 vocab gap)
- A `friday_close` Hard Rule waiver requirement (multi-day holds, can span weekends)
- A `dwx_suffix_discipline` flag (Darwinex stack does not natively offer NYMEX RB or NG; CTO confirms whether `OIL.DWX` / `NATGAS.DWX` exist as Darwinex-CFD substitutes at G0)
- A `kill_switch_coverage` flag (no native stop-loss)
- A `darwinex_native_data_only` note (calendar logic doesn't require external data)

## H. SKIP — High-Frequency Trading Strategies (pp. 151-153)

Verbatim opener (p. 151):

> "In general, if a high Sharpe ratio is the goal of your trading strategy (as it should be, given what I said in Chapter 6), then you should be trading at high frequencies, rather than holding stocks overnight."

Chan does NOT name a specific HFT strategy in this section. He discusses:
- Why HFT typically yields high Sharpe (law of large numbers)
- Backtesting difficulty (need bid/ask + order-book data, sometimes only real-time testing works)
- Execution dependencies (C language, server collocation, microsecond delays)
- Fund-management diversity ("there are as many such strategies as there are fund managers")

→ **No mechanical strategy specification.** Per DL-033 Rule 1, this section yields no cards. Documented in `source.md` skip table as "narrative-only / underspecified".

V5 framework note: HFT-style strategies that could be inferred from Chan's general description would all hit `scalping_p5b_latency` Hard Rule and `HFT_NOT_APPLICABLE` SOURCE_QUEUE flag (Aldridge book at row 11 of T1 carries the same flag). V5 stack (MT5 + DXZ live-only) cannot run HFT competitively. Per SOURCE_QUEUE.md row 13 v5_flags: "HFT_NOT_APPLICABLE — extract slippage / latency insights for QUA-228 only."

## I. SKIP — Is It Better to Have a High-Leverage versus a High-Beta Portfolio? (pp. 153-154)

This section is methodology comparison (Kelly-formula leverage vs Fama-French beta). Not a strategy. Documented in `source.md` skip table as "methodology-not-strategy".

---

## J. Vocabulary-gap proposal: `annual-calendar-trade`

This is the 4th SRC02-surfaced controlled-vocabulary gap (after `cointegration-pair-trade`, `mean-reach-exit`, `zscore-band-reversion` from S01-S02).

**Proposed flag**: `annual-calendar-trade` (Section A — entry mechanism)

**Definition**: Entry triggered on a fixed annual calendar date (typically a single date per year), exit triggered on a fixed annual calendar date. The strategy fires once per year per symbol; backtest sample size grows by 1 trade/year/symbol.

**Disambiguation from**:
- `intraday-day-of-month` (Gotobi 5/10/15/20/25 dates): operates on a monthly cycle, multiple entries per year per symbol; this flag operates on annual cycle, one-shot per year
- `session-close-seasonality` (post-NYSE-close drift): intraday window, not annual
- `time-stop` (clock-only exit by bar count): the `annual-calendar-trade` exit IS clock-based but on fixed calendar date, not bars-since-entry

**V4 evidence**: V4 had no annual-calendar-trade EAs in the SM_XXX deployed family per `strategy_type_flags.md` Mining-provenance table. This is a genuinely net-new family that V5 vocabulary needs to absorb if cards from Chan (S07, S08) advance past G0.

**Source citation**: Chan Ch 7 sidebars pp. 149-150; gasoline RB Apr 13 / Apr 25 trade and natgas NG Feb 25 / Apr 15 trade.

Research will batch-propose all 4 SRC02 vocabulary gaps to CEO + CTO via the addition-process documented in `strategy_type_flags.md` once SRC02 extraction stabilizes (after S03/S04/S05/S06 land in heartbeats 5-6).
