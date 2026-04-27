---
source_id: SRC01
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
extracted_section: Chapter 13 — In-Depth Testing / Walk-Forward Analysis, "A Walk-Forward Primer" pp. 117-121
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# Chapter 13 — Countertrend "Breakout" Strategy on Mini S&P (ES) — Walk-Forward Demo

This is a fully-specified deployable mechanical strategy that Davey introduces in Chapter 13 to demonstrate walk-forward analysis. **Found during Pass-2 main-text sweep** per OWNER Rule 1 (CEO comment [`85b9ec8e`](/QUA/issues/QUA-191#comment-85b9ec8e-8461-4579-8110-2fb2621b0470)) — I missed it during the appendix-first extraction pass because Ch 13 is in the "methodology" cluster. Per Rule 1 it gets a card regardless of whether Davey treats it as a real recommendation or as a pedagogical example.

## Davey's introduction (verbatim, p. 117)

> "To bring the concept down to earth, I will first demonstrate the process on a simple breakout trading system. In this way, you can see step by step how the walk-forward analysis is done."

> "Our strategy will be a very simple one: a countertrend breakout-type system:
>    Enter short if the close is an 'X'-day high close
>    Enter long if the close is a 'Y'-day low close
>    Stop-loss of 'Z'"

> "In TradeStation Easy Language, the system code becomes:"

```easylanguage
input: X(5), Y(5), Z(200);

if close=highest(close,X) then buy next bar at market;

if close=lowest(close,Y) then sellshort next bar at market;

SetStopLoss(Z);
```

## ⚠ Internal contradiction in source — first code block has wrong directions

The verbal description above says **"Enter SHORT if the close is an X-day high close"** (countertrend), but the printed first code block above says **`if close=highest(close,X) then buy`** (i.e., BUY on X-day high — that's TREND-following, not countertrend). The first code block contradicts both the verbal description AND Davey's own framing of the strategy as "countertrend breakout-type."

A few pages later in Ch 13, Davey shows the walk-forward-history version of the same strategy, and there the code is FLIPPED to match the verbal description (this is the corrected version). Verbatim from p. 119:

```easylanguage
if close=highest(close,X) then sellshort next bar at market;
if close=lowest(close,Y) then buy next bar at market;
SetStopLoss(Z);
```

So the FIRST code block has a transcription error (`buy` and `sellshort` are swapped). The SECOND code block, used in the walk-forward demonstration on which Davey reports actual numerical results, is consistent with the verbal description.

**Card draft uses the corrected/countertrend version** (per Davey's verbal framing AND the second code block), with a § 16 Lessons-Captured note flagging the typo for P1 verification ("run BOTH versions and confirm Davey's quoted optimized net profit of $55,162 over 2000-2010 matches the corrected/countertrend version").

## Test parameters Davey specifies (verbatim, p. 117-118)

> "For this example, we will use the continuous contract for the mini S&P (ES), and use 10 years of data, from January 1, 2000, to January 1, 2010. We will use daily bars and include $25 slippage and commission per round trip trade."

> "For comparison purposes, first we will optimize over all the data from 2000 to 2010. Using net profit as our fitness function criteria, we get the optimum values:
>    X = 9
>    Y = 5
>    Z = $600"

> "This complete optimization produces a net profit of $55,162 over the 10-year period."

## Walk-forward setup (verbatim, p. 117)

> "First, some simple definitions regarding the walk-forward analysis are in order:
>    In period. This is the chunk of historical data that will be optimized.
>    Out period. This is the chunk of historical data that will be evaluated using optimized results from the adjacent in period.
>    Fitness factor. This is the criterion used to determine the 'best' result, allowing us to select the optimized parameters.
>    Anchored/Unanchored test. This tells us whether or not the in period start date shifts with time, or if the start date is always the same."

> "Although I will discuss the details of how to select these parameters a bit later, for our test case we will use a 5-year in period, a 1-year out period, fitness factor of net profit, and an unanchored test."

## Walk-forward results table (Table 13.1, verbatim, p. 118)

```
TABLE 13.1 Sample Walk-Forward Test Results

In-Sample Test Period   Best Parameters X, Y, Z   Out-of-Sample Period   Out-of-Sample Result
1/1/2000–1/1/2005       7, 17, 600                1/1/2005–1/1/2006      –$3,138
1/1/2001–1/1/2006       7, 45, 100                1/1/2006–1/1/2007      –$2,325
1/1/2002–1/1/2007       49, 7, 600                1/1/2007–1/1/2008      +$5,963
1/1/2003–1/1/2008       21, 11, 1000              1/1/2008–1/1/2009      –$19,113
1/1/2004–1/1/2009       9, 5, 600                 1/1/2009–1/1/2010      +$8,675
```

Cumulative OOS net profit 2005-2010 (5 OOS years): **–$9,938**.

## Walk-forward history strategy code (full, with the corrected entry directions, verbatim, p. 119)

```easylanguage
var: X(5), Y(5), Z(200);

If date>1050101 and date<1060101 then begin
    x=7; y=17; z=600;
end;
If date>1060101 and date<1070101 then begin
    x=7; y=45; z=100;
end;
If date>1070101 and date<1080101 then begin
    x=49; y=7; z=600;
end;
If date>1080101 and date<1090101 then begin
    x=21; y=11; z=1000;
end;
If date>1090101 and date<1100101 then begin
    x=9; y=5; z=600;
end;
If date>1100101 and date<1110101 then begin
    x=9; y=5; z=600;
end;
If date>1110101 and date<1120101 then begin
    x=9; y=5; z=700;
end;
If date>1120101 and date<1130101 then begin
    x=9; y=5; z=700;
end;
If date>1130101 and date<1140101 then begin
    x=9; y=5; z=700;
end;

if close=highest(close,X) then sellshort next bar at market;
if close=lowest(close,Y) then buy next bar at market;
SetStopLoss(Z);
```

## Davey's interpretation of the results (verbatim, p. 120)

> "The interesting points of this comparison are:
>    The optimized equity curve is much, much better than the walk-forward curve. This is to be expected, since the optimized curve is a result of optimization. This should tell you that practically any strategy can be made to look good, if you optimize the parameters over the time period you are interested in.
>    The walk-forward results are not very good. Walk-forward analysis is a tough test for a strategy to 'pass.' Most strategies fail at this analysis. But since this simulates real life more than fully optimized results do, it is a more accurate method of analysis."

> "It is a different story for the walk-forward analysis, as depicted in Figure 13.2. The years 2010-2013 were flat for the walk-forward equity curve also, but it mimics the 2005-2009 walk-forward results. In other words, the performance of the walk-forward system did not change through the years--it was consistently flat to down most of the years."

## Research's reading notes (NOT verbatim — interpretation flagged)

- **Strategy character:** countertrend on N-day-high-close / N-day-low-close. SHORT on a fresh X-day high close; LONG on a fresh Y-day low close. Davey's term: "countertrend breakout-type system" — note the apparent oxymoron (a true breakout system is trend-following; Davey's "breakout" here just means "fresh extreme close" and the trade direction is countertrend).
- **Instrument:** mini S&P (ES) continuous contract.
- **Bar size:** daily.
- **Test period in book:** 2000-01-01 to 2010-01-01 (10 years), with walk-forward extension through 2014-01-01.
- **Commissions/slippage:** $25 round-trip.
- **Walk-forward setup:** 5-year in / 1-year out, unanchored, fitness = net profit.
- **Walk-forward parameter blocks:** 9 blocks (2005-01 through 2014-01), each with its own X/Y/Z. Parameters drift substantially: X varies 7→49→21→9; Y varies 17→45→7→11→5; Z varies $100-$1,000.
- **Strategy result:** Davey explicitly demonstrates this as a walk-forward failure example. Cumulative OOS 2005-2010 = -$9,938; Davey notes 2010-2013 is "flat to down."
- **Per Rule 1:** Research extracts this as a card regardless of Davey's negative result — pipeline gates filter. The strategy has well-defined mechanical entry/exit/stop rules, passes V5 hard rules (mechanical, no ML, no martingale, no scalping, no paywall), and is therefore a "distinct mechanical strategy" within Rule 1's scope.
