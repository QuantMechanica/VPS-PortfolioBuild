# STR-042-pb-dual-stochastic — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/3 =====
S.1
PB dual stochastic system
ForexFactory Thread 297661 — 1 Beiträge, KOMPLETT (1 Seite(n))
Radu_C
PB dual stochastic system.
This is a simple set of rules which was one of my first developed systems and was primarily intended to be
presented in my courses as an example of what a trading system is. It is a basic, easy to understood and easy to
follow system, which is also robust and profitable (though, not highly profitable ).
It is optimized specifically for EUR/USD and for the 15 min timeframe. It is not intended to be traded on auto pilot ,
though it is able to generate profit if left on its own. Best use is to consider it as a "statistically correct friend" and to
be used with support and trend lines and as a entry / exit point and also general market direction.
Requirements:
 
first stochastic with following settings: %K period: 72 and slowing: 1. If %D is built in the indicator just
disable, or set to 1 to overlap with indicator as %D is not required.
we will name this indicator green stochastic
second stochastic with following settings: %K period: 285 and slowing: 246. If %D is built in the indicator just
disable, or set to 1 to overlap with indicator as %D is not required.
we will name this indicator red stochastic
two lines drawn at 76 and 24.
Setting-up:
 
Insert a new indicator window with the green stochastic and set the values as described above.
insert in the same window the red stochastic and set the values as described above.
In metatrader, to insert a second indicator into the trading window you have to enable the navigator.
Then, form the newly appeared menu open indicators and drag-and-drop into the green stochastic
window the stochastic oscillator indicator. Then modify the second indicator with the parameters of the
red stochastic.
For the green stochastic parameter window should look like this (click for image). and for the red
stochastic parameter window should look like this: click for image.
Very important: in Metatrader synchronize the two stochastics. This is done by selecting for both of them min
and max values as 0 respectively 100. Parameter windows should look like this click for image.
Put on one of them two levels at 76 and 24. Since they are synchronized it is enough to put those levels at
just one of them. If put on both they will just overlap.
Finally it should look like this: click for image
Strategy:
Strategy is composed of four trading signals:
===== PAGE 2/3 =====
 
Long: green stochastic is above red stochastic and green stochastic is above 24 and there are two
consecutive negative (bearish) candles finished on chart. Enter on open of third candle.
All conditions must be met simultaneously to enter a long position.
green stochastic is the fast one and if it is above 24 then there is no obvious negative trend.
when I first started trading i was frustrated by the fact that all momentum indicators are lagging.
They rise/fall only after price rose/fell. The rule to enter a long trade after two negative closed
candles has the purpose of trading on pull-backs from the main trend which are almost 100%
to happen. I know it is counter-intuitive, but it is the backbone of this system.
Close Long: green stochastic is below red stochastic and there are two consecutive positive (bullish)
candles. Close on open of third candle.
All conditions must be met simultaneously to close a long position.
Short: green stochastic is below red stochastic and green stochastic is below 76 and there are two
consecutive positive (bullish) candles finished on chart. Enter on open of third candle.
All conditions must be met simultaneously to enter a short position.
green stochastic is the fast one and if it is below 76 then there is no obvious positive trend.
Close Short: green stochastic is above red stochastic and there are two consecutive negative (bearish)
candles finished on chart. Close on open of third candle.
All conditions must be met simultaneously to close a short position.
As you can see this is a open system, meaning that on opening of a position you don't know at what price you will
take profit or loss. So, there are no stop-loss and take-profit orders to be set, and indicators must be watched 24/7.
PROS:
 
simple system
can function on auto trade (but not advised)
robust
can be used as a general market momentum evaluation tool
CONS:
 
If traded exactly cannot be left unsupervised since exit orders are not preset
too simple to provide high profit
can have big drawdown so do not overleverage.
needs constant supervision
Statistics calculated without leverage in 2000-2011 period (spot trading):
 
Expected annual return: 6.91 %
===== PAGE 3/3 =====
Max. system % drawdown -14.61 %
Max. trade drawdown -785.00
detalied statistics about the sistem you can find here
Radu Ciofu, ProfitBursier.ro/en```
