# STR-075-rsi-cci-ema-cross — Source extract (verbatim pypdf text, 2026-07-25)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/34 =====
S.1
Simple RSI & EMA high Profitable ratio Strategy
ForexFactory Thread 599061 — 99 Beiträge, KOMPLETT (5 Seite(n))
ahmedabbas
Time frame : H1 , H4
In this Strategy , indicators are:
 
5-period Exponential Moving Average (EMA 5) applied to the Close.
12-period Exponential Moving Average (EMA 12) applied to the Close.
21-period RSI (RSI 21)
CCI (80)
Entry Rules for Long Trades:
Its simple. We enter a long trade when EMA 5 crosses above EMA 12 to the
upside AND our RSI (21) & CCI (80) > 50 level both are green and RSI Candles Green
Entry Rules for Short Trades:
Enter short when EMA 5 crosses EMA 12 to the downside AND RSI (21) & CCI (80) < 50 level both are Red and RSI Candles Red
SL/TP as you perceive feasible according to market/Pairs
Stop loss = between Approximately 35-60 or more/less pips depending on the volatility of the currency pair and your trading perception.
For more volatile pair, like GBP/USD, and EUR/USD less Volatile
Exit Rules for Long Trades:
Exit the trade when EMA 5 crosses back below EMA 12 or when RSI 21 & CCI (80) < 50
Exit Rules for Short Trades:
Exit short trade when EMA 5 crosses above EMA 12 OR RSI (21) & CCI (80) > 50
Attached Image (click to enlarge)
===== PAGE 2/34 =====
S.1
S.1
S.1
Attached File(s)
RSI & CCI & EMA Tmp.tpl   10 KB | 6,087 downloads | Uploaded Aug 27, 2016 5:42am
updated indicators.zip   26 KB | 7,191 downloads | Uploaded Aug 27, 2016 5:43am
swati58
Hi Ahmed Abbas, I am Sajid Ahmed from Pakistan. Thank you for sharing your strategy. I am also using EMA's in my trading. I use 8
and 21 moving average along with 200SMA. I have subscribed to your thread. Hope we will share good setups and will have green
pips.
ahmedabbas
Quoting swati58
 Disliked
Hi Ahmed Abbas, I am Sajid Ahmed from Pakistan. Thank you for sharing your strategy. I am also using EMA's in my
trading. I use 8 and 21 moving average along with 200SMA. I have subscribed to your thread. Hope we will share good
setups and will have green pips.
Thank swati58 , in this strategy trader will trade on both side of RSI 50 Level.
Xxfx
Hi!looks good
Attached Image (click to enlarge)
===== PAGE 3/34 =====
S.1
S.1
S.1
S.1
swati58
Quoting ahmedabbas
 Disliked
{quote} Thank swati58 , in this strategy trader will trade on both side of RSI 50 Level.
Thank you and you are welcome. Glad to see a thread from my country. How long have you been trading your strategy? and do you
think it is profitable or you are on finding it out. I can get it automated(EA) if you think it could be profitable.
justomonla
Must the cross of the rsi 50level and the cross of the two emas occur simultaneously to get a valid trade? thanks
lghr
Quoting justomonla
 Disliked
Must the cross of the rsi 50level and the cross of the two emas occur simultaneously to get a valid trade? thanks
Thank you ahmedabbas. it is simple, but very profitable, by backtest manually.
emmanuel7788
Quoting ahmedabbas
 Disliked
Time frame : H1 , H4 In this Strategy , we use 3 indicators: 5-period Exponential Moving Average (EMA 5) applied to the
Close. 12-period Exponential Moving Average (EMA 12) applied to the Close. 21-period RSI (RSI 21) Entry Rules for
Long Trades: Its simple. We enter a long trade when EMA 5 crosses above EMA 12 to the upside AND our RSI 21 > 50.
Entry Rules for Short Trades: Enter short when EMA 5 crosses EMA 12 to the downside. AND RSI 21 < 50. Stop loss =
20 30 pips depending on the volatility of the currency pair. For more volatile pair, like...
Hi Ahmedabbas,
I love trading strategy using the RSI and since I trade using RSI for more than 20 years.
However, using the EMA crosses may not be the best add-on to the RSI strategy.
Since you use the 5EMA, you may want to consider using the same 5-period MA but set that to show as a Price Channel instead. This
===== PAGE 4/34 =====
S.1
S.1
way, you will eliminate the 'weak' crosses using the 5EMA /12EMA when market volatility is low and you can rely more on the price
action and volatility. You do not need to rely on the EMA crosses but look at the price candles closing above or below the PAC for buy
and sell with the same RSI above/below 50-level. Price closing inside the PAC is for trade exits..
Read attached pdf : "High Probability Trading Opportunities Using Moving Averages" page 6 Moving Average Price Channel.
Attached File(s)
High Probability using Moving Average.pdf   1.3 MB | 14,447 downloads
Good Luck with your new thread.
Attached Image (click to enlarge)
ahmedabbas
Quoting lghr
 Disliked
{quote} Thank you ahmedabbas. it is simple, but very profitable, by backtest manually.
Thank you lghr
ahmedabbas
Quoting emmanuel7788
 Disliked
{quote} Hi Ahmedabbas, I love trading strategy using the RSI and since I trade using RSI for more than 20 years.
However, using the EMA crosses may not be the best add-on to the RSI strategy. Since you use the 5EMA, you may want
to consider using the same 5-period MA but set that to show as a Price Channel instead. This way, you will eliminate the
'weak' crosses using the 5EMA /12EMA when market volatility is low and you can rely more on the price action and
volatility. You do not need to rely on the EMA crosses but look at the price candles closing...
===== PAGE 5/34 =====
S.1
S.1
Thank emmanuel7788 for your nice contribution . off course , you can also use/add another indicator with this strategy according to you
feel feasible and which emphasis your decision during low volatility.
hsn100
Hi ahmedabbas! Congratulations on your thread, again nice to see somebody from my country. Hopefully you'll keep posting your
charts as charts are great illustration of anybody's strategy, besides it will eliminate all the confusion among new traders. Wish u best of
luck.
Best regards,
trenki2
Hello ahmedabbas, I have backtested your strategy on EURUSD H1 1 Lot per trade and 30 pips SL using my own backtesting
framework for the timeframe from 2001 to 2016.
The program logic is as follows:
Inserted Code
int ticketBuy;
int ticketSell;
 
if (!GetCurrentOrders(p, out ticketBuy, out ticketSell))
       return false;
 
double ema1 = iMA(p.Symbol, PERIOD_H1, p.Ema1Period, 0, MODE_EMA, PRICE_CLOSE, 1);
double ema2 = iMA(p.Symbol, PERIOD_H1, p.Ema2Period, 0, MODE_EMA, PRICE_CLOSE, 1);
double rsi = iRSI(p.Symbol, PERIOD_H1, p.RsiPeriod, PRICE_CLOSE, 1);
double bid = MarketInfo(p.Symbol, MODE_BID);
double ask = MarketInfo(p.Symbol, MODE_ASK);
double currentLots = p.Lots;
if (ticketBuy == -1)
{
    if (ema1 > ema2 && rsi > 50)
    {
        int ok = OrderSend(p.Symbol, OP_BUY, currentLots, ask, 3, bid - p.StopLoss, 0, "RsiEma", p.MagicNumber);
        if (ok == -1)
            return false;
    }
}
else
{
    if (ema1 < ema2 || rsi < 50)
    {
        if (!OrderSelect(ticketBuy, SELECT_BY_TICKET))
            return false;
        bool ok = OrderClose(ticketBuy, OrderLots(), bid, 0);
        if (!ok)
            return false;
    }
}
if (ticketSell == -1)
{
    if (ema1 < ema2 && rsi < 50)
    {
        int ok = OrderSend(p.Symbol, OP_SELL, currentLots, bid, 3, ask + p.StopLoss, 0, "RsiEma", p.MagicNumber);
        if (ok == -1)
            return false;
    }
}
else
{
===== PAGE 6/34 =====
S.1
S.1
    if (ema1 > ema2 || rsi > 50)
    {
        if (!OrderSelect(ticketSell, SELECT_BY_TICKET))
            return false;
        bool ok = OrderClose(ticketSell, OrderLots(), bid, 0);
        if (!ok)
            return false;
    }
}
It fails badly with the standard parameters (5, 12, 21) 30 pips SL:
Attached Image
Using different parameters (136,195,191) 36 pips SL seems to give better results on the historical data:
Attached Image
hsn100
If we only enter/exit when there's the confluence of 5/12 ema as well as 21 RSI crossing 50, seems to be interesting. Will test it on
demo for further results.
ahmedabbas
===== PAGE 7/34 =====
S.1
S.1
S.1
Quoting trenki2
 Disliked
Hello ahmedabbas, I have backtested your strategy on EURUSD H1 1 Lot per trade and 30 pips SL using my own
backtesting framework for the timeframe from 2001 to 2016. The program logic is as follows: int ticketBuy; int ticketSell; if
(!GetCurrentOrders(p, out ticketBuy, out ticketSell)) return false; double ema1 = iMA(p.Symbol, PERIOD_H1,
p.Ema1Period, 0, MODE_EMA, PRICE_CLOSE, 1); double ema2 = iMA(p.Symbol, PERIOD_H1, p.Ema2Period, 0,
MODE_EMA, PRICE_CLOSE, 1); double rsi = iRSI(p.Symbol, PERIOD_H1, p.RsiPeriod, PRICE_CLOSE, 1); double bid
= MarketInfo(p.Symbol,...
Thank trenki2 your contribution in my thread , to set only 30 SL/TP is not hard & fast rule i have already mentioned SL/TP also depend
on pairs volatility . you can adjust it as you feel feasible according to pair volatility and market situation i.e many pairs become more
volatile when NY market open.
ahmedabbas
Quoting hsn100
 Disliked
Hi ahmedabbas! Congratulations on your thread, again nice to see somebody from my country. Hopefully you'll keep
posting your charts as charts are great illustration of anybody's strategy, besides it will eliminate all the confusion among
new traders. Wish u best of luck. Best regards,
thank hsn100
ahmedabbas
Quoting Xxfx
 Disliked
Hi!looks good {image}
Nice buddy
ahmedabbas
Attached Image (click to enlarge)
===== PAGE 8/34 =====
S.1
emmanuel7788
Hi,
Just completed a manual back-test using the RSI(21), Buy when RSI(21) above level 50, Sell when RSI(21) below level 50.
I used used the price data from June 24 (after the Brexit referendum) just to test the market volatility.
Attached Image (click to enlarge)
===== PAGE 9/34 =====
S.1
Attached Image (click to enlarge)
next week we should do some forward testing with demo account in live market conditions.
A simple trading methodology usually work with discipline in entry and exit strategy, money management and risk management.
Have a Good Weekend ... with back-testing.
ahmedabbas
For Volatility , you can also add these indicators in this strategy
Attached File(s)
===== PAGE 10/34 =====
S.1
S.2
S.2
volatility.mq4   2 KB | 2,278 downloads
bollinger-band-bars.mq4   4 KB | 1,963 downloads
swati58
Quoting ahmedabbas
 Disliked
{image}
Ahmed Abbas, bro can you share your testing software for back testing please.
hsn100
Quoting emmanuel7788
 Disliked
Hi, Just completed a manual back-test .......Have a Good Weekend ... with back-testing.
Hi emmanuel7788, good results, thnx for sharing, i like the simplicity of this method. I'll check this on demo and will wait for your
results/analysis likewise.
Regards
emmanuel7788
Quoting hsn100
 Disliked
{quote} Hi emmanuel7788, good results, thnx for sharing, i like the simplicity of this method. I'll check this on demo and
will wait for your results/analysis likewise. Regards
Hi,
I like simple trading methods. They all work only provided we as traders knows when to trade and when not to trade. We must know
when to place our entries and exits, and we must have the discipline to follow simple rules and not get distracted by things around us
especially discussions in forums like FF. We must learn to stay focus in doing the trading tasks every day no matter what the
surrounding environment we are in.
Here is another back-test for EURUSD H4, same period from June 24 (post Brexit) till Jul 16.
Attached Image (click to enlarge)
===== PAGE 11/34 =====
Looking at EURUSD RSI(21) on W1, D1 and H4, we should be selling next week. But what is the money management strategy we
should use?
Attached Image (click to enlarge)

===== PAGE 12/34 =====
S.2
S.2
S.2
Good trading next week...
ahmedabbas
Quoting emmanuel7788
 Disliked
{quote} Hi, I like simple trading methods. They all work only provided we as traders knows when to trade and when not to
trade. We must know when to place our entries and exits, and we must have the discipline to follow simple rules and not
get distracted by things around us especially discussions in forums like FF. We must learn to stay focus in doing the
trading tasks every day no matter what the surrounding environment we are in. Here is another back-test for EURUSD
H4, same period from June 24 (post Brexit) till Jul 16. {image} Looking at EURUSD...
Good Luck emmanuel7788
xuantianfeng
Hi ahmedabbas,
Thanks for your share of your profitable strategy.
But it seemed I didn't understand your strategy because according to my backtest, the strategy didn't show a very positive result.(Pic 1)
(enter and close long/short according to RSI and EMAs just like what you said and don't set a SL)
Even if I set an original stoploss of 100 Point and Move SL to OpenPrice when profit>100 points, it didn't work like others.(Pic 2)
So how did you get that curve by your strategy? What kind of SL and TP strategy do you use?
Attached Image(s) (click to enlarge)
cdeleeuw
Thanks Ahmed Abbas for this thread and Emmanuel7788 for the useful pdf-link.
I � m new on this forum and didn � t find posted answers on my below question yet.
It is often said that crossing MA � s � ONLY won � t result in a winning system.
You � ll need more pattern recognition or indicators, for instance the proposed RSI.
I � m certain that crossing MA � s will work if the system is able to recognize the unprofitable trades.
Then MA crossing and many other systems become profitable.
The NON-Entry warning is even more important than the Entry signal.
See for instance the attached graph;
===== PAGE 13/34 =====
S.2
Values below suffixed with � ? �  are suggestions and shoule be tested.
At the current completed bar[1] look back (10-11?) bars if there was a crossing, which may fall between 2 bars, therefore around bars
10 and 11
Measure the angle of both MA � s from several bars (5?) after the crossing till the current bar[1].
If there is another crossing in this (10-11?) bar-period, skip and wait till the system sees this next crossing.
Use for instance a LRL and its Slope-Angle, not on the bars but on the MA � s.
A LRL is a strait linear regression line between 2 points only in stead of a moving and curved regression like a MA.
If both slope values differ more than (?) degrees the price very often falls back and results in a lozing trade.If less than (?) degrees this
is an incomplete entry signal, see point 4 below.
- Point 1 is a NonEntry.
- The first crossing of point 2 is skipped because of the next crossing in the (10-11?) period.
- Point 3 could be a doubtful Entry and may result in a loss.
- Point 4 could be an Entry signal, but the barsize (H-L) around the crossing is quite large and 2 extra LRL � s from crossing till 5 bars
next confirm this and overrule the standard Entry signal, based on parallel LRL � s.
- Point 5 is where we waited for. Almost parallel LRL � s -and- slope values must confirm trend.- No slope confirmation at point 6, even
mostly no (10-11?) bars lookback.
I � m working this out, but do not have the complete and tested indicator version yet to upload. I expect coming soon.
See attached an incomplete MT4 testversion for LRL which is drawn several times and not calculated on the MA � s
Above was a suggestion for finding NonEntry signals, please think also about how to recognize and avoid lozing trades.
Cheers, cdeleeuw
Attached Image (click to enlarge)
Attached File(s)
#-Linear-Regression-Line1-CW.mq4   8 KB | 1,036 downloads
Bardy
Quoting ahmedabbas
 Disliked
Time frame : H1 , H4 In this Strategy , we use 3 indicators: 5-period Exponential Moving Average (EMA 5) applied to the
Close. 12-period Exponential Moving Average (EMA 12) applied to the Close. 21-period RSI (RSI 21) Entry Rules for
Long Trades: Its simple. We enter a long trade when EMA 5 crosses above EMA 12 to the upside AND our RSI 21 > 50.
Entry Rules for Short Trades: Enter short when EMA 5 crosses EMA 12 to the downside. AND RSI 21 < 50. SL/TP as you
perceive feasible according to market/Pairs Stop loss = between Approximately 35-60 or more/less...
You got this strategy from an ebook by Thomas Carter https://www.amazon.com/gp/aw/d/15033...1VL&ref=plSrch
I recommend always back testing a strategy, especially from low budget ebook said sold on Amazon because anyone can write and sell
===== PAGE 14/34 =====
S.2
S.2
S.2
S.2
S.2
S.2
an ebook nowadays.
jusiur
this is a solid strategy but rsi have some tricks.
You also will want to check Bagovino s (here) and Teb63 s (here) threads for many invaluable information, but for some reason, they
abandoned the method.
jusiur
in my long experience with this method might suggest soften rsi activity incorporating an MA, please analize the template.
Attached File(s)
emas and rsi smoothed.tpl   2 KB | 1,264 downloads
redoktober
Quoting jusiur
 Disliked
this is a solid strategy but rsi have some tricks. You also will want to check Bagovino s (here) and Teb63 s (here) threads
for many invaluable information, but for some reason, they abandoned the method.
Right Jusiur , it's evident that ahmedabbas has copied the Bagovino Method.
ahmedabbas
Quoting redoktober
 Disliked
{quote} Right Jusiur , it's evident that ahmedabbas has copied the Bagovino Method.
never , i have seen your mentioned before or copied , there lot of strategies which concepts relates , but i have using this strategy with
some indicators which i have mentioned in my posts.
TEB63
I use to use this system as my main system. it works fine. May I add a few things I found out that worked for me
,,,,,, ie. In an uptrend
1. Only open a trade from the london open to 2 hours before the London close
2. Enter with a candle pattern after a cross of the RSI and the MAs to the upside
3. Put a stop below the last main swing
4. do 1 to 3 RRR
5. Only enter a trade to the upside the 1st or 2nd times after a cross of the RSI over the 50% level
6. Make sure the RSI is not moving fast to the downward - even if the RSI is over the 50%
7. if you are trading on the hour chart check to confirm the 4 hour RSI is in line. Maybe even check the day chart.
8. The best candle entries. for. me were _ pin candle _ inside candle_outside candle _ best is key bar
good luck
ahmedabbas
Quoting TEB63
 Disliked
I use to use this system as my main system. it works fine. but may I add a few things I found out 1. only open a trade. in
the london open to 2 hours before the close 2. you need to have a candle enty after the cross 3. put a stop below or
above a swing 4. do 1 to 3 rrrr 5. only take a trade 1 or 2 times after a cross of the rsi 6. make sure the rsi is not moving
fast the wrong way even if over the 50% 7. f you are trading on the hour make sure you have the rsi on at least the 4 hour
is in line. may even want the day 8. best candle entry. for. me...
Thank TEB63 for your nice suggestions
===== PAGE 15/34 =====
S.2
S.2
S.2
S.2
S.2
S.2
Macdon
Quoting Bardy
 Disliked
{quote} You got this strategy from an ebook by Thomas Carter https://www.amazon.com/gp/aw/d/15033...1VL&ref=plSrch
I recommend always back testing a strategy, especially from low budget ebook said sold on Amazon because anyone can
write and sell an ebook nowadays.
And he got it from one of our members here, TEB63 who posted it years before this book.
http://www.forexfactory.com/showthread.php?t=229238
alyssum
Quoting TEB63
 Disliked
I use to use this system as my main system. it works fine. but may I add a few things I found out that worked for me ,,,,,,
In an uptrend 1. Only open a trade from the london open to 2 hours before the London close 2. Enter with a candle
pattern after the cross of the RSI and the MAs to the upside 3. Put a stop below the last main swing 4. do 1 to 3 RRR 5.
only take a trade to the upside the 1st or 2nd times after a cross of the RSI over the 50% level 6. make sure the RSI is not
moving fast the downward even if the RSI is over the 50% 7. if you...
kindly explain your points with examples please
TEB63
Quoting alyssum
 Disliked
{quote} kindly explain your points with examples please
Sorry kind of doing another system now.
If you have a question I might have an answers
cheers
mkfx
Quoting emmanuel7788
 Disliked
{quote} Hi, I like simple trading methods. They all work only provided we as traders knows when to trade and when not to
trade. We must know when to place our entries and exits, and we must have the discipline to follow simple rules and not
get distracted by things around us especially discussions in forums like FF. We must learn to stay focus in doing the
trading tasks every day no matter what the surrounding environment we are in. Here is another back-test for EURUSD
H4, same period from June 24 (post Brexit) till Jul 16. {image} Looking at EURUSD...
 Hi Emmanuel,
Thanks for sharing back teste results what is the difference in both testing. sorry I was not able to understand .
What is the Target Profit / SL or close criteria in 2nd testing
Thanks
lucariga
Hi guys, do you wait the close of the candle to enter trades?
swetrader
===== PAGE 16/34 =====
S.2
S.2
S.3
Quoting lucariga
 Disliked
Hi guys, do you wait the close of the candle to enter trades?
I do.
ahmedabbas
Quoting lucariga
 Disliked
Hi guys, do you wait the close of the candle to enter trades?
yes off course
Kubiasty
Quoting emmanuel7788
 Disliked
{quote} Hi, I like simple trading methods. They all work only provided we as traders knows when to trade and when not to
trade. We must know when to place our entries and exits, and we must have the discipline to follow simple rules and not
get distracted by things around us especially discussions in forums like FF. We must learn to stay focus in doing the
trading tasks every day no matter what the surrounding environment we are in. Here is another back-test for EURUSD
H4, same period from June 24 (post Brexit) till Jul 16. {image} Looking at EURUSD...
emmanuel how do you avoid fake signals??
Lot of fake signals look closer:
Attached Image (click to enlarge)
emmanuel7788
Quoting Kubiasty
 Disliked
{quote} emmanuel how do you avoid fake signals?? Lot of fake signals look closer: {image}
one way is to know when the market is sideways in a range, you avoid taking any trade setups and also look at recent swing high/low
as support and resistance.
most trading methods are designed to trade in trending market condition but will not work efficiently when market is sideways.
===== PAGE 17/34 =====
S.3
S.3
S.3
S.3
S.3
that is obvious on that M5 chart you posted. that 1st 'negative' vertical line 2016.07.18 10:45 shows a big candle and after that the
market went sideways.
avoid trading until there is breakout of that range.
emmanuel7788
Quoting mkfx
 Disliked
{quote}  Hi Emmanuel, Thanks for sharing back teste results what is the difference in both testing. sorry I was not able to
understand . What is the Target Profit / SL or close criteria in 2nd testing Thanks
Hi MKFX,
both back-testing with GU and EU used the same parameters. important that the 3 timeframes Weekly, Daily and H4 RSI(21) must be
above or below the level-50 as the basic rule to define the Buy or Sell condition.
Both the TP and SL set to use the market volatility ADR-100 days.
I use a minimum TP = 50pips, this means when the market is trending in favor of the trade, I will trail after the min TP 50pips is reached.
The trade(s) will exit when the RSI M15 cross in the reverse direction.
regards,
harrah
What's your backtest result of this strategy, because it is important to validate the consistency and profitability over the long term.
mkfx
Quoting emmanuel7788
 Disliked
{quote} Hi MKFX, both back-testing with GU and EU used the same parameters. important that the 3 timeframes Weekly,
Daily and H4 RSI(21) must be above or below the level-50 as the basic rule to define the Buy or Sell condition. Both the
TP and SL set to use the market volatility ADR-100 days. I use a minimum TP = 50pips, this means when the market is
trending in favor of the trade, I will trail after the min TP 50pips is reached. The trade(s) will exit when the RSI M15 cross
in the reverse direction. regards,
Hi Emmanuel,
I belive both testings were based on SE/SE.
I am learning lot and progressing inch by inch not in hurry. i reached to 5% for this month till now and will see where i land end of
month.
Thanks Emmanuel for your help.
Thanks
MK
ELgenius
hello Ahmed
thank you for sharing you strategy
My question .. is there time to use this strategy or not ??
what is the best time frame (1H or 4H) ?
Kubiasty
Quoting emmanuel7788
===== PAGE 18/34 =====
S.3
S.3
S.3
S.3
 Disliked
{quote} one way is to know when the market is sideways in a range, you avoid taking any trade setups and also look at
recent swing high/low as support and resistance. most trading methods are designed to trade in trending market condition
but will not work efficiently when market is sideways. that is obvious on that M5 chart you posted. that 1st 'negative'
vertical line 2016.07.18 10:45 shows a big candle and after that the market went sideways. avoid trading until there is
breakout of that range.
Can you mark on my print screen which range ??
avibe
Attached File(s)
2 ma cross - alerts & mtf nmc.ex4   24 KB | 1,048 downloads
Attached File(s)
3 MA Cross with alert mtf 3.02.ex4   51 KB | 1,048 downloads
ahmedabbas
Quoting ELgenius
 Disliked
hello Ahmed thank you for sharing you strategy My question .. is there time to use this strategy or not ?? what is the best
time frame (1H or 4H) ?
Welcome Elgenius , better trading time is after open the London , NY markets and time frames both are compatible but its depend on
pairs i.e H1 is better for EU/US and H4 for GBP/US , but you also need to check ADR
izeik
Quoting ahmedabbas
 Disliked
{quote} Thank you lghr
hi emanuel..pls share nur tpl..tq
emmanuel7788
GBPUSD July 19 H4 trade setup during London session.
Attached Image (click to enlarge)
===== PAGE 19/34 =====
S.3
emmanuel7788
Quoting TEB63
 Disliked
{quote} Just wondering were do you see the set up? I would see 3 things against taking this trade cheers
Hi TEB63,
I look at the candles price action for the setup and using the RSI 21 and 5/12EMAs.
There were risk with that trade setup.
Please share what the 3 things you saw against taking that trade.
Below is my updated chart. I changed the background/foreground colors to have better color contrast.
Attached Image (click to enlarge)
===== PAGE 20/34 =====
S.3
regards,
emmanuel7788
Quoting Kubiasty
 Disliked
{quote} Can you mark on my print screen which range ??
here, see my comments made on your UJ M5 chart posted.
always pay attention to big candles when we trade.
a big candle is one which high-low is largest when compare to the previous 3 to 5 candles before it.
These big candles are commonly known as Wide Range Bar aka WRB ( it is the price bar High - Low, not the body which is the Open
and Close)
Use the WRB High - Low as support and resistance, i.e.
we sell at resistance and
buy as support in the direction of the higher timeframe 'trend'/direction.
Be patient when the price action is within the WRB High-Low range. Pick only the best setup to trade.
Attached Image (click to enlarge)
===== PAGE 21/34 =====
S.3
S.3
hsn100
Just entered long, let's see??
Attached Image (click to enlarge)
closed +12 pips
Kubiasty
Quoting emmanuel7788
 Disliked
{quote} Hi Ahmedabbas, I love trading strategy using the RSI and since I trade using RSI for more than 20 years.
However, using the EMA crosses may not be the best add-on to the RSI strategy. Since you use the 5EMA, you may want
to consider using the same 5-period MA but set that to show as a Price Channel instead. This way, you will eliminate the
'weak' crosses using the 5EMA /12EMA when market volatility is low and you can rely more on the price action and
volatility. You do not need to rely on the EMA crosses but look at the price candles closing...
===== PAGE 22/34 =====
S.3
Emmanuel, hi
is this a correct entry on GOLD : ?
Consolidation breakout confirmation candle closed below consolidation, and below RSI 50
Attached Image (click to enlarge)
emmanuel7788
Quoting Kubiasty
 Disliked
{quote} Emmanuel, hi is this a correct entry on GOLD : ? Consolidation breakout confirmation candle closed below
consolidation, and below RSI 50 {image}
market was sideways in the raneg of that H4 Wide Ranage Bar WRB.
possible entries which fit the RSI(21) 5EMA cross 12EMA rules, but with risks...
Attached Image (click to enlarge)

===== PAGE 23/34 =====
S.3
S.3
S.3
S.3
S.3
rkkgs
Quoting ahmedabbas
 Disliked
Time frame : H1 , H4 In this Strategy , indicators are: 5-period Exponential Moving Average (EMA 5) applied to the Close.
12-period Exponential Moving Average (EMA 12) applied to the Close. 21-period RSI (RSI 21) Entry Rules for Long
Trades: Its simple. We enter a long trade when EMA 5 crosses above EMA 12 to the upside AND our RSI 21 > 50 level
and RSI Candles Green Entry Rules for Short Trades: Enter short when EMA 5 crosses EMA 12 to the downside AND
RSI 21 < 50 level and RSI Candles Red SL/TP as you perceive feasible according to market/Pairs...
its possible create ea (robot)
thank you
advance
ahmedabbas
Quoting rkkgs
 Disliked
{quote} its possible create ea (robot) thank you advance
Yes its Possible
rkkgs
Quoting ahmedabbas
 Disliked
{quote} Yes its Possible
dear coders
doing create ea
thank you
advance
TEB63
Quoting rkkgs
 Disliked
{quote} dear coders doing create ea thank you advance
I never seen an ea work with this system
But make sure you only code between 4am and 10am est
and make sure you code out major news events
these two things I have seen kill at least 20 ea
cheers
TEB
ahmedabbas
===== PAGE 24/34 =====
S.4
S.4
S.4
S.4
S.4
Quoting TEB63
 Disliked
{quote} I never seen an ea work with this system But make sure you only code between 4am and 10am est and make
sure you code out major news events these two things I have seen kill at least 20 ea cheers TEB
i have update the strategy , now result are more better and EA will be profitable
mickael58
Quoting ahmedabbas
 Disliked
{quote} i have update the strategy , now result are more better and EA will be profitable
hello ahmedabbas you can show us your updated strategy? you can also share your Expert Advisor?
ahmedabbas
Quoting mickael58
 Disliked
{quote} hello ahmedabbas you can show us your updated strategy? you can also share your Expert Advisor?
you see the first post , i have add the CCI(80) in previous strategy ,while EA still not developed .
TEB63
Quoting ahmedabbas
 Disliked
{quote} you see the first post , i have add the CCI(80) in previous strategy ,while EA still not developed .
I know its harder but I found the best way not to be on the wrong side of a trade or trend
was to use the RSI from one major time frame up (so you are using 2 RSI not just one)
I find RSI MUCH better for trend and CCI MUCH better for entries
ie.
if you are trading on the 1 hour take the RSI from the 4 hour
if you are trading on the 4 hour take the RSI from the day
if you are trading on the day take the RSI from the week
cheers
TEB
irhe21
bro im quite confuse with the setup..
The note indicated CCI period 80, but in your screen shot the CCI is preiod 30, and the indicators you posted is in reset mode, CCI
period 14.
Please help
tillionaire
Quoting ahmedabbas
 Disliked
Time frame : H1 , H4 In this Strategy , indicators are: 5-period Exponential Moving Average (EMA 5) applied to the Close.
12-period Exponential Moving Average (EMA 12) applied to the Close. 21-period RSI (RSI 21) CCI (80) Entry Rules for
Long Trades: Its simple. We enter a long trade when EMA 5 crosses above EMA 12 to the upside AND our RSI (21) &
===== PAGE 25/34 =====
S.4
S.4
S.4
S.4
CCI (80) > 50 level both are green and RSI Candles Green Entry Rules for Short Trades: Enter short when EMA 5
crosses EMA 12 to the downside AND RSI (21) & CCI (80) < 50 level both are Red and RSI Candles...
Nice, it would be even better if we could be provided real trade screenshots to refer to...!
ahmedabbas
Quoting irhe21
 Disliked
bro im quite confuse with the setup.. The note indicated CCI period 80, but in your screen shot the CCI is preiod 30, and
the indicators you posted is in reset mode, CCI period 14. Please help
you use the CCI(80) and RSI 21 , if you use my temp file then CCI & RSI are in default settings
ahmedabbas
Quoting tillionaire
 Disliked
{quote} Nice, it would be even better if we could be provided real trade screenshots to refer to...!
today trade
Attached Image (click to enlarge)
Pipbox
This is the same system here in forex factory named Bagovino Method.
TEB63
Quoting Pipbox
 Disliked
This is the same system here in forex factory named Bagovino Method.
in fact its not it uses the same tools but rules are very diff cheers
TEB
Inserted Code
[code]
[/code]
===== PAGE 26/34 =====
S.4
S.4
S.4
S.4
S.4
TEB63
I am not trading this system at this time but here is how I do . this would have been a great trade
Attached Image (click to enlarge)
danmo68
I am very interested in the technique, I am currently testing it out myself by using a sample of 20 trades and micro lots (I don't believe in
back testing, you cant back test the emotions of actually going through the trades).
I just have one question at this point... I assume this strategy works best in trends but is it also possible for ranges?
Thanks!
ahmedabbas
Quoting danmo68
 Disliked
I am very interested in the technique, I am currently testing it out myself by using a sample of 20 trades and micro lots (I
don't believe in back testing, you cant back test the emotions of actually going through the trades). I just have one
question at this point... I assume this strategy works best in trends but is it also possible for ranges? Thanks!
yes you can use it
le celte
Bonsoir,
Simple and clear
I will try this srategy next week
thanks
jf
danmo68
I would like to ask another question.
I love the h1 time frame so of course I am using it over h4. But I have noticed that when the market is in a "tight" range and the EMA's
are crossing over potentially 5-6 times in an hour. Obviously it is seems not that difficult to know that these signals are not dependable
===== PAGE 27/34 =====
S.4
S.4
S.4
S.4
S.4
S.4
S.5
but... In my experience, in the long run you should take all signals if they meet all the entry rules for the strategy, but this would not be
good for success as it concerns this strategy.
My question is, when the market is producing these large amounts of signals in a short amount of time what drives your judgement to
take or not to take these signals even know all of the entry rules are met?
Dan
chunshuo
Quoting emmanuel7788
 Disliked
{quote} Hi Ahmedabbas, I love trading strategy using the RSI and since I trade using RSI for more than 20 years.
However, using the EMA crosses may not be the best add-on to the RSI strategy. Since you use the 5EMA, you may want
to consider using the same 5-period MA but set that to show as a Price Channel instead. This way, you will eliminate the
'weak' crosses using the 5EMA /12EMA when market volatility is low and you can rely more on the price action and
volatility. You do not need to rely on the EMA crosses but look at the price candles closing...
Hi emmanuel7788. Thanks for you share your idea.
I have 2 question:
1. what mean is "PAC"?
2. what is period for channel? The pdf use 20 period for channel.
Thanks
English555
Why is this thread died? This method dont work?
csubbra
Quoting English555
 Disliked
Why is this thread died? This method dont work?
i'm still using this method.. it's working perfectly. We can't get 100% winning signals but with good money management, we can make
100% profit. Trust me. Forex is a tool to increase your equity and not the other way.. always think about your equity, not the holy grail to
find the direction 100% correctly. cheers
tillionaire
Can we make an EA out of this
ahmedabbas
Quoting English555
 Disliked
Why is this thread died? This method dont work?
you just follow the rules which i have mentioned in my 1st post , i sure you will also get good result .
English555
But what are rules about stop loss?
alexmccullie
Hi, I backtested the original strategy on my custom EA rules system that allows easy configuration of rules like this. I used EURUSD
from 4 Jan to 22 Oct 2016 on a 10,000 demo account. The bottom line it was profitable. Here some settings I used to context the result.
I set all indicators to 4 hours using shifts 1 & 2. I used ATR (1 day) to size the stops with 1.5 x larger take profit settings. I also
===== PAGE 28/34 =====
S.5
S.5
S.5
S.5
implemented Trailing stops using the ATR calculations. Finally I used 1% account risk to size the lots. These features are part of my EA,
if enabled. With more time I'd would play with other settings and also on other currency pairs. I've attached the results of these settings.
ÂÂ 
I got a slight worse result (still profitable) if I just closed orders with reverse signals rather than relying on trailing stops or take profits.
Finally trailing stops seemed to improve returns. Alex
ÂÂ 
Attached Image (click to enlarge)
Sanbernardin
This strategy seems clear and simple but why the thread died?
dominusbruno
Quoting ahmedabbas
 Disliked
{image}
What is this program...?
SunnyCoast
Hello.
I'm fairly new to Forex and have just joined Forex Factory after reading many of the "How To" posts over the past month.
I like this Trading System so I would like to follow this thread.
I'll learn how to post charts from my Demo Account, etc and see if anybody here would like to discuss and/or reflect on trades taken
using this system.
SunnyCoast
===== PAGE 29/34 =====
S.5
Just seeing if I can post a picture.
AUDUSD still 3 hours before candle closes so nothing to do here.
Attached Image (click to enlarge)
SunnyCoast
1st Few Trades:
Attached Image (click to enlarge)
Attached Image (click to enlarge)
===== PAGE 30/34 =====
S.5
SunnyCoast
Attached Image (click to enlarge)
Attached Image (click to enlarge)
===== PAGE 31/34 =====
S.5
S.5
S.5
SunnyCoast
Last One as 5 trades are now open at 2% risk each.
Attached Image (click to enlarge)
SunnyCoast
I tried to post screenshots of all the losing trades and new trades but as I'm a newbie I think the mods deleted them.
Not sure why, but... As THE CLASH sang, "I fought the law and the law won" so I won't bother arguing.
deanolee32g
===== PAGE 32/34 =====
S.5
S.5
S.5
ahmedabbas YOU A GENIUS
reteid2222
Quoting deanolee32g
 Disliked
ahmedabbas YOU A GENIUS
ahmedabbas 4 president..... great work
A system does not need be complex to work....as hanover wrote...
My extention:
A system does not have to be one of the systems here to have the most responses... the guys just go for systems like pivot points
which are not defined clearly... that makes it unproovable... or is packed with junk indicators which show friday significant other
lines=signals as monday and changeds complete in one day... from my point of view complete crap....
But this is a masterpiece... still there are improvements possible like avoid flat market....
Attached Image (click to enlarge)
ahmedabbas
Quoting reteid2222
 Disliked
{quote} ahmedabbas 4 president..... great work A system does not need be complex to work....as hanover wrote... My
extention: A system does not have to be one of the systems here to have the most responses... the guys just go for
systems like pivot points which are not defined clearly... that makes it unproovable... or is packed with junk indicators
which show friday significant other lines=signals as monday and changeds complete in one day... from my point of view
complete crap.... But this is a masterpiece... still there are improvements possible...
thank you....if you know the coding then create a auto system on it with some improvements.
reteid2222
Quoting ahmedabbas
 Disliked
{quote} thank you....if you know the coding then create a auto system on it with some improvements.
I ll run the corresponding EA on my VPS on M5 next week to proove entries and exits correctly live....
Remind me in 8 days and I ll send you the EA....
Attached Image
===== PAGE 33/34 =====
S.5
S.5
S.5
S.5
S.5
decodagobert
Quoting reteid2222
 Disliked
{quote} ahmedabbas 4 president..... great work A system does not need be complex to work....as hanover wrote... My
extention: A system does not have to be one of the systems here to have the most responses... the guys just go for
systems like pivot points which are not defined clearly... that makes it unproovable... or is packed with junk indicators
which show friday significant other lines=signals as monday and changeds complete in one day... from my point of view
complete crap.... But this is a masterpiece... still there are improvements possible...
Hi Master,
may I ask how you avoid flat market conditions?
greetings
dc
reteid2222
Quoting decodagobert
 Disliked
{quote} Hi Master, may I ask how you avoid flat market conditions? greetings dc
I use an volume indicator... recoded the tradingview "HawkEye Volume Indicator [LazyBear]" for me...
Volume is the key to this... or just use adx and a distinct value...
LeviMG22
hello
can u guys help me
i need a ema cross over bot which aslo take trade on pullback or retracement and with sl trial and tp and include martingle
thank you
mianyamin
Thank you for nice contribution
jameboy9864
After I manually backtest it on H1, It feels almost the same as the TMS(R) Robinhood's original strategy. Anyone has the same feeling?
And of course it is profitable. Both of them.
===== PAGE 34/34 =====
S.5
Attached Image (click to enlarge)
greenpip90
I have create custom indicator for mt5 to follow this custom system . You can follow the left upper text to buy ,sell and wait .
Attached Image (click to enlarge)
Attached File(s)
dolarmoro_simple_trading_rsi.ex5   13 KB | 145 downloads```
