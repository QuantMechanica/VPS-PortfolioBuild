---
source_id: SRC01
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
extracted_section: Appendix C — Euro Day Strategy, TradeStation EasyLanguage Format
book_pages: 259-261
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# Appendix C — Euro Day Strategy, TradeStation EasyLanguage Format

Verbatim text + code from Davey, *Building Winning Algorithmic Trading Systems* (Wiley 2014), Appendix C, pp. 259-261. Page-break artifacts and the running-header "EURO DAY STRATEGY, TRADESTATION EASY LANGUAGE FORMAT" interspersed by `pdftotext -layout` have been left in place; the EasyLanguage code itself is unaltered apart from joining lines that the layout-extractor split across columns.

## Page 259 — appendix opener

```
                                                                APPENDIX C

Euro Day Strategy,
TradeStation Easy
Language Format

                                                                            259
```

## EasyLanguage code (verbatim)

```easylanguage
var:xb(2),xb2(50),pipadd(1),Stopl(400),proft(5000);

   if date >= 1091118 and date < 1101025 then
   begin
          xb = 4 ;
          xb2 = 70 ;
          pipadd = 2 ;
          Stopl = 275 ;
   end ;
   if date >= 1101025 and date < 1110929 then
   begin
          xb = 4 ;
          xb2 = 72 ;
          pipadd = 5 ;
          Stopl = 225 ;
   end ;
   if date >= 1110929 and date < 1120904 then
   begin
          xb = 3 ;
          xb2 = 74 ;
          pipadd = 8 ;
          Stopl = 425 ;
   end ;
   if date >= 1120904 and date < 1130812 then
   begin
          xb = 3 ;
          xb2 = 74 ;
          pipadd = 11 ;
          Stopl = 425 ;
   end ;
   if date >= 1130812 and date < 11400101 then     // NB: literal value as printed in source; likely typo for 1140101 (= 2014-01-01) per App B convention
   begin
          xb = 5 ;
          xb2 = 80 ;
          pipadd = 8 ;
          Stopl = 425 ;
   end ;

var:cs(0),tradestoday(0),startprof(0),starttrades(0),stoplo(0);

cs = currentsession(0);

If cs<>cs[1] then begin
   tradestoday = 0;
   startprof   = NetProfit + OpenPositionProfit;
   starttrades = TotalTrades;
   Stoplo      = stopl;
end;

If totaltrades<>starttrades or marketposition<>0 or startprof<>NetProfit + OpenPositionProfit then tradestoday = 1;

If tradestoday = 0 and time < 1500 and date >= 1091118 then begin

   //entry rules

   If (high >= highest(high, xb) and close < close[xb2]) then begin
      sellshort next bar at high + pipadd/10000 limit;
   end;

   If (low <= lowest(low, xb) and close > close[xb2]) then begin
      buy next bar at low - pipadd/10000 limit;
   end;

end;

//exit rules
Setstopposition;
setstoploss(stoplo);
setprofittarget(proft);

setexitonclose;
```

## Research's reading notes (NOT verbatim — interpretation flagged)

- **Date format `1091118` etc. = `1`-prefixed YYMMDD** (TradeStation EasyLanguage convention). So `1091118` = 2009-11-18, `1140101` = 2014-01-01. The first walk-forward window starts about 4 months after the Euro Night strategy's start (which began 2009-07-21).
- **Source typo `< 11400101`** in the final walk-forward block (line `if date >= 1130812 and date < 11400101 then`). 11400101 is an 8-digit value; the printed value is likely a typo for `1140101` (= 2014-01-01) matching App B's convention. The card's `default` parameter values use the final-block values (xb=5, xb2=80, pipadd=8, Stopl=425); the typo means the final block is effectively never deactivated within the book's coverage window, which is the intended behavior.
- **Walk-forward parameter blocks (5 windows)** vs. App B's 10 — Davey re-optimizes the day strategy on a coarser cadence (~1-year windows) than the night strategy (~6-month windows). Possibly because day-strategy trades are less frequent and need more data per window for reliable optimization.
- **Default `vars:` block** (xb=2, xb2=50, pipadd=1, Stopl=400, proft=5000) is NOT the post-walk-forward optimal block; like App B, these are legacy walk-through values. The most-recently-walk-forward-derived block is xb=5, xb2=80, pipadd=8, Stopl=425.
- **`proft = 5000`** profit target is the constant across all walk-forward windows; Davey's narrative explains why: "Since there has never been a $5,000 intraday move in euro, the $5,000 limit is effectively saying, 'Go for as much profit as you can, and hold until the end of the trading session'" (Ch 18 p. 157). The real exit is the session-close exit OR the stop-loss.

### Entry-logic decode

- **`currentsession(0)`** — TradeStation function returning the current session number for the chart. When `cs <> cs[1]` (session changed), reset day-state.
- **Day-state tracking via `tradestoday`** — set to 1 if anything has happened today (a new trade has been opened, or a position is open, or net profit changed since session start). Used to enforce one-trade-per-day.
- **Entry gate**: `tradestoday = 0` (no trade taken today yet) AND `time < 1500` (chart-time before 3:00 PM) AND `date >= 1091118` (activation guard).
- **Short entry condition**:
  - `high >= highest(high, xb)` — the current bar's high is the highest of the last `xb` bars (a fresh xb-bar high).
  - AND `close < close[xb2]` — the current close is below the close `xb2` bars ago (longer-term momentum is down).
  - → place a SHORT LIMIT at `high + pipadd/10000` (a few pips ABOVE the current bar's high).
- **Long entry condition** (mirror): fresh xb-bar low + close above close[xb2] → place LONG LIMIT at `low - pipadd/10000` (a few pips BELOW the current bar's low).
- **Davey's narrative** (Ch 18 p. 157): *"For strategy 2, the euro day strategy, when a highest high of the past Y bars is hit, and the X bar momentum is down, then a limit order to sell short will be placed Z ticks above the current high. The opposite logic holds for long trades. Thus, to get filled, the strategy is planning on one more price thrust before the price reverses."*
- **Edge framing**: the entry expects "one more price thrust" before the reversal — i.e., the limit is placed so it only fills if price overshoots the recent extreme by `pipadd` ticks/pips, then reverts. Mean-reversion against a longer-term momentum filter.

### Exit-logic decode

- **`Setstopposition`** — TS keyword (force position-protective stop on the position rather than per-share/per-contract).
- **`setstoploss(stoplo)`** — fixed dollar-per-contract stop. Walk-forward range: $225-$425.
- **`setprofittarget(proft)`** — fixed $5,000 profit target. Effectively unreachable intraday on Euro futures; primary exits are the stop-loss or session close.
- **`setexitonclose`** — forced flat at session close (~3:00 PM ET per Davey's narrative; trades close BEFORE strategy 2's stop-time of 1500 chart time, which the entry gate enforces).

## Cross-references in main text

### Ch 18 — strategy specification (pp. 156-158)

> "Strategy 2: Daytime strategy 'euro day.' Runs on 60-minute bars from 7 a.m. to 3 p.m. ET, with all trades exited by 3 p.m. The end of the trading day is 5 p.m., but I am closing all trades at 3 p.m., since trading volume is a lot less from 3 p.m. to 5 p.m." (p. 156)

> "For both strategies, I want to lose no more than $450 per trade, after slippage and commission of $17.50 per trade. This equates to a loss of 34 ticks." (p. 157)

> "For profit, with both strategies I will allow the profit target to be optimized for euro night strategy, and fixed at $5,000 for the euro day strategy. Since there has never been a $5,000 intraday move in euro, the $5,000 limit is effectively saying, 'Go for as much profit as you can, and hold until the end of the trading session.'" (p. 157)

> "What do I think my edge actually is? Based on the reversal entries I am employing, I feel my edge is in identifying very-short-term (for night strategy 1) and medium-term (for day strategy 2) areas where the price is likely to reverse. By having limit orders away from the current market, I liken my edge to a rubber band." (p. 158)

### Ch 19 — Monte Carlo results for Euro Day (pp. 163-164)

> "For the day strategy, if I keep the risk of ruin below 10 percent (my personal threshold for ruin), I find I need $6,250 to begin trading this system, and in an 'average' year I can expect:
>    23.7 percent maximum drawdown
>    129 percent return
>    5.45 return/drawdown ratio" (p. 164)

> "Other points of interest are that I have a 4 percent chance of ruin in that first year, where my equity would drop below $3,000. I also have a 94 percent probability of making money in that first year (i.e., ending the year with more than $6,250)." (p. 164)

### Ch 15 — diversification tables (pp. 135-136)

| Metric | Euro Day | Source |
|---|---|---|
| R² correlation coefficient (equity-curve linearity) | 0.9745 | Table 15.1 (p. 135) |
| Maximum Drawdown | $3,523 | Table 15.2 (p. 136) |
| Return / Drawdown ratio | 5.2 | Table 15.3 (p. 136) |
| Probability of profit in 1 year | 97% | Table 15.3 (p. 136) |

### Ch 7 — comparative metrics (p. 2632 of full pdftotext extract)

A reference to "# Trades, 1 Year   Euro Day   23.7%  $8,049   ...   129%" appears in extracted text near line 2632 (likely a Table 7.x summary in Ch 7 Detailed Analysis); to be cross-referenced when the card is built. Initial parse: 23.7% max DD, $8,049 [some absolute metric], 129% return — matching Ch 19 Monte Carlo.

## What the appendix does NOT include

- No EasyLanguage comments inside the code beyond the inline section markers (`//entry rules`, `//exit rules`).
- No bar-size specification inside App C; per Ch 18 narrative the day strategy uses **60-minute bars** (vs. 105-minute bars for the night strategy).
- No timezone specification inside App C; per Ch 18 narrative the entry window is **7 AM ET to 3 PM ET** with chart-time `time < 1500` enforced inside the code (so the chart is set to ET, not the CME default CT, OR the chart is on CT and the 1500 cutoff = 3:00 PM CT = 4:00 PM ET — discrepancy to verify at CTO sanity-check).
