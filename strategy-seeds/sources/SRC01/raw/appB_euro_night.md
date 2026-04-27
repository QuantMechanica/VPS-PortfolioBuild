---
source_id: SRC01
source_pdf: "G:\\My Drive\\QuantMechanica\\Ebook\\PDF resources\\Building Winning Algorithmic Tr - Kevin J. Davey.pdf"
extracted_section: Appendix B — Euro Night Strategy, TradeStation EasyLanguage Format
book_pages: 255-258
extraction_method: poppler `pdftotext -layout`
extracted_by: Research Agent
extracted_at: 2026-04-27
---

# Appendix B — Euro Night Strategy, TradeStation EasyLanguage Format

Verbatim text + code from Davey, *Building Winning Algorithmic Trading Systems* (Wiley 2014), Appendix B, pp. 255-258. Page-break artifacts and the running-header "EURO NIGHT STRATEGY, TRADESTATION EASY LANGUAGE FORMAT" interspersed by `pdftotext -layout` have been left in place; the EasyLanguage code itself is unaltered apart from joining lines that the layout-extractor split across columns.

## Page 255 — appendix opener

```
                                                                APPENDIX B

Euro Night Strategy,
TradeStation Easy
Language Format

                                                                            255
```

## EasyLanguage code (verbatim)

```easylanguage
vars: FirstTime (1800),
          LastTime (2359),
          ATRmult (3),
          TRmult (.5),
          Nb (10),
          NATR (60),
          Stoplo(275);

          FirstTime = 1800 ;
          LastTime = 2359 ;

   if date >= 1090721 and date < 1100104 then
   begin
          Nb = 9 ;
          NATR = 93 ;
          ATRmult = 3.15 ;
          TRmult = 0.51 ;
          Stoplo= 425 ;
   end ;
   if date >= 1100104 and date < 1100617 then
   begin
          Nb = 9 ;
          NATR = 93 ;
          ATRmult = 2.55 ;
          TRmult = 0.66 ;
          Stoplo= 375 ;
   end ;
   if date >= 1100617 and date < 1101129 then
   begin
          Nb = 14 ;
          NATR = 83 ;
          ATRmult = 2.75 ;
          TRmult = 0.71 ;
          Stoplo= 425 ;
   end ;
   if date >= 1101129 and date < 1110515 then
   begin
          Nb = 14 ;
          NATR = 83 ;
          ATRmult = 2.75 ;
          TRmult = 0.66 ;
          Stoplo= 425 ;
   end ;
   if date >= 1110515 and date < 1111026 then
   begin
          Nb = 19 ;
          NATR = 93 ;
          ATRmult = 3.15 ;
          TRmult = 0.56 ;
          Stoplo= 425 ;
   end ;
   if date >= 1111026 and date < 1120412 then
   begin
          Nb = 14 ;
          NATR = 83 ;
          ATRmult = 2.95 ;
          TRmult = 0.61 ;
          Stoplo= 425 ;
   end ;
   if date >= 1120412 and date < 1120924 then
   begin
          Nb = 14 ;
          NATR = 93 ;
          ATRmult = 2.95 ;
          TRmult = 0.61 ;
          Stoplo= 425 ;
   end ;
   if date >= 1120924 and date < 1130310 then
   begin
          Nb = 19 ;
          NATR = 73 ;
          ATRmult = 3.15 ;
          TRmult = 0.71 ;
          Stoplo= 425 ;
   end ;
   if date >= 1130310 and date < 1130826 then
   begin
          Nb = 14 ;
          NATR = 93 ;
          ATRmult = 2.95 ;
          TRmult = 0.51 ;
          Stoplo= 425 ;
   end ;
   if date >= 1130826 and date < 1140101 then
   begin
          Nb = 14 ;
          NATR = 93 ;
          ATRmult = 2.55 ;
          TRmult = 0.71 ;
          Stoplo= 425 ;
   end ;

Var: LongPrice(0), ShortPrice(0), LongTarget(0), ShortTarget(0);

//limit entry prices
ShortPrice = Average(Low, Nb) + ATRmult * AvgTrueRange(NATR);
LongPrice = Average(High, Nb) - ATRmult * AvgTrueRange(NATR);

{code to ensure only 1 order is entered at each bar - order closest to
price}
var:diff1(0),diff2(0),EntrytoPick(0);
EntrytoPick=0;
diff1=absvalue(close-LongPrice);
diff2=absvalue(close-ShortPrice);
If diff1<=diff2 then EntryToPick=1;
If diff1>diff2 then EntryToPick=2;

if date >= 1090721 and MarketPosition = 0 and EntriesToday(Date) < 1 and
Time >= FirstTime and Time < LastTime then begin
        If EntryToPick=1 then begin
           Buy("Long Entry") next bar at LongPrice limit;
        end;

        If EntryToPick=2 then begin
         Sell short("Short Entry") next bar at ShortPrice limit;
        end;
end;

If MarketPosition=-1 then begin
   ShortTarget = EntryPrice - TRmult * TrueRange;
   Buy to cover("Short Exit") next bar at ShortTarget limit;
end;

If MarketPosition =1 then begin
   LongTarget = EntryPrice + TRmult * TrueRange;
   Sell("Long Exit") next bar at LongTarget limit;
end;

Setstopposition;
setstoploss(stoplo);

SetExitOnClose;
```

## Research's reading notes (NOT verbatim — interpretation flagged)

- **Date format `1090721` etc. = `1`-prefixed YYMMDD.** TradeStation's date encoding for dates after 2000 prefixes years with `1` to disambiguate from pre-2000. So `1090721` = 2009-07-21, `1140101` = 2014-01-01. The `if date >= 1090721 and MarketPosition = 0 ...` guard means the strategy is INACTIVE for bars dated before 2009-07-21.
- **Time-varying parameters** — Davey ships ten parameter blocks, each ~6 months long, covering 2009-07-21 to 2014-01-01 (the book's coverage window through publication 2014-05). After 2014-01-01 the strategy reverts to the `vars:` default block (ATRmult=3, TRmult=0.5, Nb=10, NATR=60, Stoplo=275). This is the result of Davey's own walk-forward optimization documented in Parts III-IV of the book.
- **Default vars vs. final period** — defaults are `Stoplo=275`, but the last walk-forward period uses `Stoplo=425`. Davey's defaults are NOT the most-recently-walk-forward-optimized parameters; they appear to be the original Ch 18 walk-through values.
- **Entry side selection** — `EntryToPick` picks whichever limit (LongPrice or ShortPrice) is CLOSER to the current close. Both limits are placed each bar; only one of the two `Buy` or `Sell short` orders is sent to market.
- **LongPrice = Average(High, Nb) - ATRmult * AvgTrueRange(NATR)** — long limit is BELOW the average of recent highs by `ATRmult` ATRs. **ShortPrice = Average(Low, Nb) + ATRmult * AvgTrueRange(NATR)** — short limit is ABOVE the average of recent lows by `ATRmult` ATRs. Both prices sit INSIDE the recent extremes — this is a **mean-reversion** structure (buy a deep dip from recent highs; short a deep rally from recent lows).
- **Profit target** — `LongTarget = EntryPrice + TRmult * TrueRange` and mirror for short. With `TRmult ≈ 0.5-0.7`, the profit target is ~half of the prior bar's True Range. Small target consistent with mean-reversion mechanics.
- **Stop loss** — `setstoploss(stoplo)` is a TradeStation built-in; `stoplo` is in **dollars per contract** (TS-EasyLanguage convention for `setstoploss` when not given a per-share/per-contract argument). On Euro futures (`@EU`, big point value $12.50/tick = $125,000/contract notional) `Stoplo=425` ≈ 34 ticks ≈ 34 pips on EURUSD.
- **Time exit** — `SetExitOnClose` forces flat at the session close. Combined with `FirstTime=1800` and `LastTime=2359`, the strategy holds for at most ~6 hours, well within an overnight Euro futures session.
- **One trade per day** — `EntriesToday(Date) < 1` cap.

## What the appendix does NOT include

- No backtest performance numbers (PF, DD, win rate, annualized return) appear in the appendix itself. Performance claims for this strategy would need to be cross-referenced against Parts III-IV of the book where Davey walks through testing.
- No commission / slippage assumption stated (Davey's discussion of those lives in earlier chapters).
- No specification of which chart timeframe (intraday bar size) the strategy is applied to. The use of `Time >= 1800 and Time < 2359` and `EntriesToday(Date) < 1` plus `SetExitOnClose` strongly implies an intraday timeframe (likely M5 / M15 / H1) but the appendix does not state it. **First card to-do: cross-reference Ch 18 / 19 narrative for the bar-size used.**
