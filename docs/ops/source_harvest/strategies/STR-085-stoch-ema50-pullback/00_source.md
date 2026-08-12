# STR-085-stoch-ema50-pullback — Source extract (verbatim pypdf text, 2026-07-25)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/6 =====
S.1
Trend Continuation Strategy
ForexFactory Thread 837301 — 11 Beiträge, KOMPLETT (1 Seite(n))
GazFx
Trend Continuation Strategy. Any time frame. Any symbol.
My personal experience with this strategy is an approximate 60% win rate and 2.45 profit factor. The profit factor is
the key, not the win rate. Tight stops keep losses to an absolute minimum, while a take profit equal to at least 3
times the stop maximizes profit. I add a trailing stop equal in value to the entry stop and just let my trades run. In a
typical trend I will win 3 to 4 trades and lose 1 to 2 trades. Do the math and you will see why this strategy is so
profitable and reliable. Simple rules eliminate emotion, which is a giant step forward for newbies and experienced
traders alike.
About the strategy
Trade alerts are triggered by Stochastic (5,3,3, Close/Close) crossovers that occur at or below the 20 level (buy)
and at or above the 80 level (sell), which are confirmed by the slope of the EMA50 (Close). A Stochastic cross-up is
confirmed if the EMA50 is sloping up, and a Stochastic cross-down is confirmed if the EMA50 is sloping down.
Trade alerts are ignored if the EMA50 is flat and trending sideways. Entry stop loss is set just below the previous
low for a buy, and just above the previous high for a sell. I trade the H4 time frame so I use a 10 pip buffer. Take
profit is set at 3 times the stop loss value, i.e. 30 pip stop equals a 90 pip take profit. Very simple rules.
I learned about this strategy from Sam Seiden, a veteran floor trader with 15 years experience on the Chicago
Mercantile Exchange. I put it into practice straight away, and the results were immediate. That gets me excited so I
want to share this strategy with you and others. The strategy is free for anyone willing to watch Sam Seiden's 44
minute video below. If you like it, have tested it, and want to automate trade alerts, my Market Scanner indicator is
the solution. First, here's the video:
http://youtu.be/sUM-6vuuadU
About Market Scanner
I don't like to spend too much time at the computer scanning for trade alerts, so I have put together the Market
Scanner indicator to automate this task. Market Scanner applies the strategy rules to 28 currency pairs plus Gold
and Silver, and generates trade alerts when the rules are met. Trade alerts are highlighted in gold in the symbol list
displayed on the chart screen. Click the symbol button to open the relevant price chart for visual confirmation
according to the strategy rules.
Tip: Create a chart template with EMA50 and Stochastic, and Market Scanner attached, and save it as the "default"
template. This template will automatically open whenever you click a symbol button on Market Scanner.
When an order is opened, Market Scanner will display (B) for a buy and (S) for a sell, and tag the current order
profit/loss next to this. The button will change color to red for a losing position and green for winning position. This
makes it easy to view the status of all open positions at a glance. Just a simple piece of software that you can use
to save a lot of time and improve trading efficiency!
View Market Scanner: https://www.mql5.com/en/market/product/32600
===== PAGE 2/6 =====
S.1
S.1
S.1
S.1
S.1
GazFx
Market Scanner has been updated. You can now enter your own parameters for Stochastic and EMA period.
Marc82Much
I downloaded your Market Scanner. Good work. Question, you say use Stochastics 5,3,3 close, close. Using MT4,
that is easy to do. But, I am trying to replicate the strategy in Think Or Swim...and when I choose Stochastic from
the list of indicators, I get 9 options and none of them allow to enter parameters like 5,3,3, close, close. Any
suggestions.
Attached Image (click to enlarge)
GazFx
Quoting Marc82Much
 Disliked
I downloaded your Market Scanner. Good work. Question, you say use Stochastics 5,3,3 close, close.
Using MT4, that is easy to do. But, I am trying to replicate the strategy in Think Or Swim...and when I
choose Stochastic from the list of indicators, I get 9 options and none of them allow to enter
parameters like 5,3,3, close, close. Any suggestions.{image}
I am not familiar with Think Or Swim at all, so I am not sure if I can help. The parameters may be available as
inputs: %K = 5, Slowing = 3, %D = 3, Price Field = Close/Close (as opposed to High/Low). Do you see input
parameter options when you select StochasticFast, Slow, or Full option in Think Or Swim? Hope this helps!
GazFx
Market Scanner has been updated to allow Stochastic MA type input.
GazFx
My personal results last week trading the H4 timeframe.
===== PAGE 3/6 =====
S.1
Attached Image (click to enlarge)
GazFx
My results last week trading the H1 timeframe, then switching back to the H4 timeframe on the last four trades.
What can I say? The H4 timeframe and default settings work best for me. I was down -215 pips in H1, but gained
+173 pips from 4 consecutive winners as soon as I switched back to H4. Of course, it's entirely up to you which
timeframe you choose to trade, and I am sure that fine-tuning the input parameters for a given timeframe will
produce good results regardless, but for me H4 works best.
I've upgraded Market Scanner with pop-up alerts, clearer input parameters, and minor improvements to trade rule
identification.
Attached Image (click to enlarge)
===== PAGE 4/6 =====
S.1
S.1
GazFx
7-Day Free Demo
� HI, i tried the indicator in the strategy test but it would not load it just crashes after freezing mt4, nothing is
possible to test before buying the trend continuation market scanner � , 2018.11.06 15:09
After receiving this message I realized that the MQL5 market place demo download won � t allow you to test my
market scanner. This is because the scanner monitors multiple currency pairs, which is not supported by the MT4
strategy tester. In response I have made a 7-day demo version that is available by sending me an email at
[email protected] with � MS demo �  written in the subject line. I will respond as quickly as possible by sending you
the demo file.
View Market Scanner: https://www.mql5.com/en/market/product/32600
GazFx
My personal results last week trading the H4 timeframe.
Attached Image (click to enlarge)
===== PAGE 5/6 =====
S.1
reteid2222
A strat which definitely makez money....This one was DAX!
Attached Image (click to enlarge)
===== PAGE 6/6 =====
S.1
Aar
Quoting reteid2222
 Disliked
A strat which definitely makez money....This one was DAX! {image}
Simple rules & seems a very good strategy. Looks like you got another good ea in the arsenal .```
