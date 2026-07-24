# STR-012-daily-wick-asymmetry-breakout — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/27 =====
S.1
Your EA v3 - Daily Low & High Strategy
ForexFactory Thread 1233107 — 65 Beiträge, KOMPLETT (4 Seite(n))
rockzz
*Your EA v3* backtest results looks promising and auspicious...
EXACT STRATEGY BEHIND THIS EA
1. The strategy trades on the daily (D1) timeframe.
2. The strategy uses two pending orders: a Buy Stop order and a Sell Stop order.
3. At the start of each new day, the code checks if a new candle has formed. If it's a new day, the
strategy resets the "orderPlaced" variable to false, allowing it to place a new order if conditions are
met.
4. The strategy calculates the "wickBuy" and "wickSell" values based on the difference between the open
price and the low price (wickBuy) and the high price and the open price (wickSell) of the previous daily
candle.
5. The strategy sets the Buy Stop price (buyStopPrice) above the previous day's high by a certain
number of pips specified by the "PipsAboveHigh" parameter.
6. The strategy sets the Sell Stop price (sellStopPrice) below the previous day's low by a certain number
of pips specified by the "PipsBelowLow" parameter.
7. The strategy sets the Stop Loss for the Buy Stop order (stopLossBuy) below the previous day's high
by a certain number of pips specified by the "StopLossPips" parameter.
8. The strategy sets the Stop Loss for the Sell Stop order (stopLossSell) above the previous day's low
by a certain number of pips specified by the "StopLossPips" parameter.
9. If the condition "wickBuy > wickSell" is met, the strategy places a Buy Stop order at the
"buyStopPrice" level with a specified lot size ("LotSize"), Stop Loss ("UseStopLoss" and
"StopLossPips"), and Take Profit ("UseTakeProfit" and "TakeProfitPips").
10. If the condition "wickSell > wickBuy" is met, the strategy places a Sell Stop order at the
"sellStopPrice" level with a specified lot size ("LotSize"), Stop Loss ("UseStopLoss" and
"StopLossPips"), and Take Profit ("UseTakeProfit" and "TakeProfitPips").
11. The "MagicNumber" is used to identify the orders placed by this specific EA, so it can distinguish its
orders from other EAs or manual trades.
12. The strategy uses a simple slippage setting ("Slippage") to account for potential order execution
variations.
No live trade results yet....But backtest results I will attach below.
Change the default Settings in EA for better profitable trades (Atleast 45% above Profitable while
backtesting):
Take Profit in Pips - 100
Stop Loss in Pips - 30
EA Currrent Profitable Settings
Attached Image (click to enlarge)
===== PAGE 2/27 =====
S.1
S.1
Scripts for better trading
Source Code file successfully uploaded....
Developers are welcome to develop this EA for further updates.
I have no coding knowledge and I used ChatGPT to built this EA. Do not ask for
further updates from me. Only Dev can do that. While live trading the EA hits
stop loss everytime and I don't know why. Do not fully believe the EA's
startegy tester results because it will be different results while live trading.
Me also looking for Updates like you.
Please make me to earn $100 per month...Becaause I am struggling a lot. Thank
you everyone.
Attached File(s)
Your EA v3.ex4   10 KB | 1,256 downloads
Change Time Frame All Open Charts.ex4   7 KB | 858 downloads
Template All OpenCharts.ex4   32 KB | 817 downloads
Your EA v3.mq4   5 KB | 1,418 downloads
rockzz
Reserved for FAQ
rockzz
Backtest results in all Major Currency Pairs
===== PAGE 3/27 =====
Pair: EURAUD
Spread: 10
Date: 2000 to 2023
Deposit: 100$
Attached Image(s) (click to enlarge)

===== PAGE 4/27 =====
S.1
rockzz
Pair: EURUSD
Date: 2000 to 2023
Attached Image (click to enlarge)
Pair: AUDUSD
Date: 2000 to 2023
Attached Image (click to enlarge)
===== PAGE 5/27 =====
Pair: USDJPY
Date: 2000 to 2023
Attached Image (click to enlarge)
Pair: GBPUSD
Date: 2000 to 2023
Attached Image (click to enlarge)
===== PAGE 6/27 =====
S.1
S.1
S.1
8tango
Thanks rockzz for this EA.
I made backtests from 2000 to 2023 and it works fine, is it possible to add into your EA a lot size calculate on risk
percentage (1%, 2%, etc...) from balance available?
What is the utility of the 2 others mt4 files (Change Time Frame All Open Charts.ex4 and ex4 Template All
OpenCharts.ex4)?
rockzz
Quoting 8tango
 Disliked
Thanks rockzz for this EA. I made backtests from 2000 to 2023 and it works fine, is it possible to add
into your EA a lot size calculate on risk percentage (1%, 2%, etc...) from balance available? What is
the utility of the 2 others mt4 files (Change Time Frame All Open Charts.ex4 and ex4 Template All
OpenCharts.ex4)?
Wait for the EA update...I noted your information better input variables.
If you want to run EA simultaneously on all major cureency pairs, then you need to first open all major pair charts in
a mt4 window. Apply EA on first chart, then drag and drop the Template All OpenCharts.ex4 to the first chart window.
The current EA settings applied to all open charts automatically.
Same steps for Change Time Frame All Open Charts.ex4 for all open charts that automatically turns into D1 charts.
anhkklun
===== PAGE 7/27 =====
S.1
S.1
S.1
hello rockzz thanks for your work, can you tell me how to install those two open chats in the ea section, sorry my
english is bad
rockzz
Quoting anhkklun
 Disliked
hello rockzz thanks for your work, can you tell me how to install those two open chats in the ea
section, sorry my english is bad
Here you go:
Inserted Video
And
Inserted Video
bountintern
Hi,
It looks really interesting, I tried backtesting and didnt get the same results as you. Do you have a set file you could
upload for each of the pairs please? or could you list the parameters used Thankyou
rockzz
Quoting bountintern
 Disliked
Hi, It looks really interesting, I tried backtesting and didnt get the same results as you. Do you have a
set file you could upload for each of the pairs please? or could you list the parameters used Thankyou
Attached Image (click to enlarge)

===== PAGE 8/27 =====
S.1
S.1
S.1
S.1
S.1
S.1
bountintern
Thankyou, I am assuming on the daily timeframe as well?
rockzz
Quoting bountintern
 Disliked
Thankyou, I am assuming on the daily timeframe as well?
Yep...only on Day Timeframe.
bountintern
I am getting a flat equity curve on all the pairs, any ideas? as i entered the same parameters?
rockzz
Quoting bountintern
 Disliked
I am getting a flat equity curve on all the pairs, any ideas? as i entered the same parameters?
Inserted Video
bountintern
Thankyou, I have done that, is a negative equity curve now
Erebus
Quoting bountintern
 Disliked
Thankyou, I am assuming on the daily timeframe as well?
You can assume, or read the rule(s)
Attached Image (click to enlarge)
Also, every chart posted about results is on the Daily charts
For me, it seems that a variable take profit linked to the ADR would be a desired addition to the settings, as 100 is
quite an arbitrary number.
For example, the current ADR(10) for the posted pairs are:
USDJPY - 154
EURAUD - 146
GBPUSD - 108
===== PAGE 9/27 =====
S.1
S.1
S.1
S.1
EURUSD - 77
AUDUSD - 68
rockzz
Quoting Erebus
 Disliked
{quote} You can assume, or read the rule(s) {image} Also, every chart posted about results is on the
Daily charts For me, it seems that a variable take profit linked to the ADR would be a desired addition
to the settings, as 100 is quite an arbitrary number. For example, the current ADR(10) for the posted
pairs are: USDJPY - 154 EURAUD - 146 GBPUSD - 108 EURUSD - 77 AUDUSD - 68
Hello sir...
I am ready to share the source code with you. Will you backtest and modify the changes for live trading. Because I
have no proper coding knowledge.
Erebus
Quoting rockzz
 Disliked
{quote} Hello sir... I am ready to share the source code with you. Will you backtest and modify the
changes for live trading. Because I have no proper coding knowledge.
That makes 2 of us
So, this looks like a trend following strategy, right?
Why did we need the terms "wicks" in there?
It could be simply yesterday's low, yesterday's high, and today's open price to describe the prices used for
calculations, correct?
The trade is taken in the direction of the smaller of the two readings, only when the level is broken, makes sense,
catch the trend, or if market reverses, no trading.
Good luck.
rockzz
Quoting Erebus
 Disliked
{quote} That makes 2 of us So, this looks like a trend following strategy, right? Why did we need the
terms "wicks" in there? It could be simply yesterday's low, yesterday's high, and today's open price to
describe the prices used for calculations, correct? The trade is taken in the direction of the smaller of
the two readings, only when the level is broken, makes sense, catch the trend, or if market reverses,
no trading. Good luck.
Actually friend...I have no coding knowledge and I built this EA through ChatGPT. If developers like you take care of
this EA, it will be more profitable while live trading. Please help me friend.
rockzz
===== PAGE 10/27 =====
S.2
Pair: AUDCAD
Exact same settings
Attached Image (click to enlarge)
Erebus
Quoting rockzz
 Disliked
{quote} Actually friend...I have no coding knowledge and I built this EA through ChatGPT. If
developers like you take care of this EA, it will be more profitable while live trading. Please help me
friend.
But I'm not a developer or coder, only a hobby trader; how can I make that clear?
Perhaps post it in the Platform Tech forum, under this thread -
https://www.forexfactory.com/thread/...indicators-for
I can see days where you will wish for a bigger exit strategy, see this chart, are the approximate entry levels
correct?
Attached Image (click to enlarge)
===== PAGE 11/27 =====
S.2
S.2
S.2
rockzz
Quoting Erebus
 Disliked
{quote} But I'm not a developer or coder, only a hobby trader; how can I make that clear? Perhaps
post it in the Platform Tech forum, under this thread - https://www.forexfactory.com/thread/...indicators-
for I can see days where you will wish for a bigger exit strategy, see this chart, are the approximate
entry levels correct? {image}
Thanks friend...Your idea is 100% correct...Can you clearly explain the exit and entry strategy?
Erebus
Quoting rockzz
 Disliked
{quote} Thanks friend...Your idea is 100% correct...Can you clearly explain the exit and entry
strategy?
You are confusing me: we are talking about the Your EA in Post #1 are we not?
rockzz
Quoting Erebus
 Disliked
{quote} You are confusing me: we are talking about the Your EA in Post #1 are we not?
Yes...
Actually the decision to place a Buy Stop or a Sell Stop order is based on comparing the lengths of two parts of the
previous daily candle called "wicks." The "wickBuy" represents the lower shadow of the candle (the distance
between the open price and the low price), and the "wickSell" represents the upper shadow of the candle (the
distance between the high price and the open price).
===== PAGE 12/27 =====
S.2
If the "wickBuy" is longer than the "wickSell," the strategy places a Buy Stop order. On the other hand, if the
"wickSell" is longer than the "wickBuy," the strategy places a Sell Stop order.
emmanuel7788
I like it simple .... simple rule for entry and exit
EURUSD Daily Jan 01 2018 to July 27 2023 ...
the winning 'edge' is a minimum risk : reward 1:2
Attached Image (click to enlarge)
Attached Image (click to enlarge)

===== PAGE 13/27 =====
S.2
S.2
S.2
S.2
...
emmanuel7788
Quoting Erebus
 Disliked
{quote} But I'm not a developer or coder, only a hobby trader; how can I make that clear? Perhaps
post it in the Platform Tech forum, under this thread - https://www.forexfactory.com/thread/...indicators-
for I can see days where you will wish for a bigger exit strategy, see this chart, are the approximate
entry levels correct? {image}
there need one more filter for sell stop and/or buy stop ...
I can call that filter Sell Only or Buy Only ...
gerval
Quoting bountintern
 Disliked
Thankyou, I have done that, is a negative equity curve now
Thanks rockzz for sharing.
Bountintern if you have a flat or negative curve, check the spread you have in the backtest.
What Erebus says about the ADR is right, it depends on each currency and each period of time, sometimes 100 will
be little potential travel and in other currencies it is too much, but you have a very good starting point.
What I do not know to what extent will affect the internal movement of the candle in the backtest.
tienphuc2910
Quoting rockzz
 Disliked
{quote} C � ... Tr � n thực tế, quyết định đặt lệnh Dừng Mua hoặc Dừng B � n dựa tr � n việc so s � nh
độ d � i của hai phần của nến h � ng ng � y trước đ �  được gọi l �  "bấc". "wickBuy" đại diện cho b � ng
dưới của nến (khoảng c � ch giữa gi �  mở v �  gi �  thấp) v �  "wickSell" đại diện cho b � ng tr � n của
nến (khoảng c � ch giữa...
It seems to me that the EA is wrong in logic, based on whether it should be bullish or bearish before, the logic of the
wick is different. for example if candlestick is bullish then wichBuy = OpenPrice - LowPrice, wickSell = HighPrice -
ClosePrice, wichSell is vice versa. Since I can't see the code, I'm just guessing based on the chart
emmanuel7788
Quoting emmanuel7788
 Disliked
I like it simple .... simple rule for entry and exit EURUSD Daily Jan 01 2018 to July 27 2023 ... the
winning 'edge' is a minimum risk : reward 1:2 {image} {image} ...
===== PAGE 14/27 =====
S.2
S.2
GBPUSD Daily Jan 01 t0 Jul 27 2023
Attached Image (click to enlarge)
...
emmanuel7788
Quoting rockzz
 Disliked
{quote} Yes... Actually the decision to place a Buy Stop or a Sell Stop order is based on comparing the
lengths of two parts of the previous daily candle called "wicks." The "wickBuy" represents the lower
shadow of the candle (the distance between the open price and the low price), and the "wickSell"
represents the upper shadow of the candle (the distance between the high price and the open price).
If the "wickBuy" is longer than the "wickSell," the strategy places a Buy Stop order. On the other hand,
if the "wickSell" is longer than the "wickBuy,"...
simple enough
"Cut-Losses Short" when you are wrong and "Let Profits Run" when you are correct.
Attached Image (click to enlarge)
...
gerval
Quoting emmanuel7788
 Disliked
{quote} simple enough "Cut-Losses Short" when you are wrong and "Let Profits Run" when you are
correct. {image} ...
===== PAGE 15/27 =====
S.2
S.2
S.2
simple but not easy
AleksDark
Quoting rockzz
 Disliked
*Your EA v3* backtest results looks promising and auspicious... EXACT STRATEGY BEHIND THIS
EA The strategy trades on the daily (D1) timeframe. The strategy uses two pending orders: a Buy
Stop order and a Sell Stop order. At the start of each new day, the code checks if a new candle has
formed. If it's a new day, the strategy resets the "orderPlaced" variable to false, allowing it to place a
new order if conditions are met. The strategy calculates the "wickBuy" and "wickSell" values based on
the difference between the open price and the low price...
Hmm, several principal problems:
1) you are not taking gaps and spreads into account. Mt4 issue. Try mt5.
2) Define your profitability expectation. +400% in 20 years? Lol. You will need huge capital for that being vital, and
then liquity questions coming in.
3) Why are you using graphs? If this is EA -- bother to provide minimal measurable values. If lazy -- publish at least
Recovery Factor, Sharpe and Sortino Ratio, and Kelly criterion, they are usually implemented as defaults. Not only
graphs.
4) Why fixed values? Easy to overfit backways, try not to use fixed values which just work out. Lead values for tp
and sl from ATR for example, with regular recalculating.
P.S. when you fix all those, and start calculating profit, you will notice that due to low winrate you have to place
minimal positions --> that thing is profitable, but not worth it. ( if remember correctly)
Merka
Quoting emmanuel7788
 Disliked
{quote} GBPUSD Daily Jan 01 t0 Jul 27 2023 {image} ...
@emmanuel7788
Did you modified the EA posted on page 1?
If yes, what did you do differently?
Thanks
emmanuel7788
Quoting Merka
 Disliked
{quote} @emmanuel7788 Did you modified the EA posted on page 1? If yes, what did you do
differently? Thanks
@Merka
No. The OP did not provide the .mq4 code file.
===== PAGE 16/27 =====
S.2
Run the EA as it is on Daily and observe the price action and how the 'wickBuy' and
'wickSell' and the pending order Buy Stop and Sell Stop are placed as explained in post
#24. There's something to learn here then you can further develop a 'strategy' for Day
chart trading.
https://www.forexfactory.com/thread/...0#post14515310
Run the EA with different Risk : Reward ratios and learn something more ... not just
entry and exit.
R:R 1:5 is not necessary better than 1:3
There is the Fear and Greed factors when trading the markets and knowing when to
Greedy will decide your profits.
Always be fearful and have a Stop Loss.
Attached Image (click to enlarge)
rockzz
Quoting tienphuc2910
 Disliked
{quote} It seems to me that the EA is wrong in logic, based on whether it should be bullish or bearish
before, the logic of the wick is different. for example if candlestick is bullish then wichBuy = OpenPrice
===== PAGE 17/27 =====
S.2
S.2
S.2
S.2
S.2
- LowPrice, wickSell = HighPrice - ClosePrice, wichSell is vice versa. Since I can't see the code, I'm
just guessing based on the chart
PMed you the logic of this strategy. Looking for further updates from you. THanks friend.
rockzz
Quoting emmanuel7788
 Disliked
{quote} @Merka No. The OP did not provide the .mq4 code file. Run the EA as it is on Daily and
observe the price action and how the 'wickBuy' and 'wickSell' and the pending order Buy Stop and
Sell Stop are placed as explained in post #24. There's something to learn here then you can further
develop a 'strategy' for Day chart trading. https://www.forexfactory.com/thread/...0#post14515310 Run
the EA with different Risk : Reward ratios and learn something...
PMed you the source code file friend. Looking for updates from you. Yes @AleksDark is exactly correct. We need to
mind his points.
rockzz
MQL4 file ie., source code file uploaded in the first post.
Looking for developers to takeover this thread for further EA updates.
Thanks everyone.
emmanuel7788
Quoting rockzz
 Disliked
{quote} PMed you the source code file friend. Looking for updates from you. Yes @AleksDark is
exactly correct. We need to mind his points.
Thank you.
emmanuel7788
Quoting AleksDark
 Disliked
{quote} / 2) Define your profitability expectation. +400% in 20 years? Lol. You will need huge capital
for that being vital, and then liquity questions coming in. //
400% in a 20-years trading cycle ... that is also possible and you need a plan.
Is USD10,000 considered as huge capital?
ramobomb
Quoting emmanuel7788
===== PAGE 18/27 =====
S.3
S.3
S.3
S.3
 Disliked
{quote} GBPUSD Daily Jan 01 t0 Jul 27 2023 {image} ...
Your backtests isnot correct . because u test in "control point" u should test in "every tick"
rockzz
Quoting ramobomb
 Disliked
{quote} Your backtests isnot correct . because u test in "control point" u should test in "every tick"
check @emmanuel7788 posts friend.
Erebus
Does anyone see similarities between this and the Daily green/red candle method?
https://www.forexfactory.com/thread/...reenred-candle
rockzz
Quoting Erebus
 Disliked
Does anyone see similarities between this and the Daily green/red candle method?
https://www.forexfactory.com/thread/...reenred-candle
Strategy
If day candle open low distance is greater than close high, then you need to place pending buy stop order at +2 pips
above that high. If day candle open high distance is greater than close low, then you need to place sell stop order at
+2 pips below that low. Close all pending orders at the next candle.
This is what the instruction I gave it to the ChatGPT
emmanuel7788
Today first trade closed +60pips
a +2R trade
Attached Image (click to enlarge)
===== PAGE 19/27 =====
S.3
...
emmanuel7788
GA Jul 31 Daily trade closed +60pips
+2R trade
Attached Image (click to enlarge)
...
===== PAGE 20/27 =====
S.3
S.3
emmanuel7788
EU Jul 31 Daily sell ... Frankfurt Open triggered the sell stop
- the market will decide if +60pips move
...
Attached Image (click to enlarge)
Erebus
Quoting emmanuel7788
 Disliked
EU Jul 31 Daily sell ... Frankfurt Open triggered the sell stop - the market will decide if +60pips move
... {image}
I cannot believe that you of all people are still under the illusion of Sunday candles.
EURUSD has only moved 23 pips today and you think that even smaller candle is actually Friday's full range?
Good Luck
Attached Image (click to enlarge)
===== PAGE 21/27 =====
S.3
S.3
Please name and shame this broker to save me the embarrassment of ever trying to open an account there, thanks.
emmanuel7788
Quoting Erebus
 Disliked
{quote} I cannot believe that you of all people are still under the illusion of Sunday candles. EURUSD
has only moved 23 pips today and you think that even smaller candle is actually Friday's full range?
Good Luck {image} Please name and shame this broker to save me the embarrassment of ever trying
to open an account there, thanks.
I knew only someone highly experienced like you would have spotted the Sunday candle
easily ...
I did tested with and without the Sunday candles ... the results are quite different
With the Sunday small candle you will always get a trade on Mondays using this buy stop
and sell stop orders...
When you have a big Daily candle followed with an Inside Day candle, you will not get any
trade in the Inside Day candle
....
rockzz
Quoting emmanuel7788
 Disliked
===== PAGE 22/27 =====
S.3
S.3
S.3
S.3
EU Jul 31 Daily sell ... Frankfurt Open triggered the sell stop - the market will decide if +60pips move
... {image}
Guys this results are unbelievable...I do not have the same chart you posted here. All are different.
I am unlucky guy.
All the best people
Erebus
Quoting emmanuel7788
 Disliked
{quote} I knew only someone highly experienced like you would have spotted the Sunday candle
easily ... I did tested with and without the Sunday candles ... the results are quite different ....
I knew only someone highly experienced like you could have replied sanely and without
malice.
Good Luck buddy!
Cunpa
I added an option to the bot to set variable exits depending on the ATR indicator based on Alek's suggestion. Also,
I'm not sure if this was intentional when you coded it, but the bot doesn't take into account the +2 pip offset when
calculating the stoploss.
Attached File(s)
Your EA v3.1.ex4   11 KB | 399 downloads
Your EA v3.1.mq4   5 KB | 617 downloads
kai.cao
Thanks for good EA.
The "wickBuy" and "wickSell" are the important element to enable this EA works well.
I hope to have these functions to be added :
Delete pending order(s) after 1 day if not executed, as they are no more complied with the rules.
Add option to select among (i) pre-define TP or (ii) closing of Daily candle to maximize the profit
driven18
US30 CFD. Are we comparing today Open or yesterday Open to Low and High of yesterday?
If we are comparing today Open to yesterday's Highs/Lows, then today open is closer to yesterday's High, then why
ea have pending Sell and not pending
Buy?
Attached Image (click to enlarge)
===== PAGE 23/27 =====
S.3
S.3
kai.cao
Quoting driven18
 Disliked
US30 CFD. Are we comparing today Open or yesterday Open to Low and High of yesterday? If we
are comparing today Open to yesterday's Highs/Lows, then today open is closer to yesterday's High,
then why ea have pending Sell and not pending Buy? {image}
Please read the OP:
Rule 4:
The strategy calculates the "wickBuy" and "wickSell" values based on the difference between the open price and
the low price (wickBuy) and the high price and the open price (wickSell) of the previous daily candle.
Rule 9:
If the condition "wickBuy > wickSell" is met, the strategy places a Buy Stop order at the "buyStopPrice" level with a
specified lot size ("LotSize"), Stop Loss ("UseStopLoss" and "StopLossPips"), and Take Profit ("UseTakeProfit" and
"TakeProfitPips").
Rule 10:
If the condition "wickSell > wickBuy" is met, the strategy places a Sell Stop order at the "sellStopPrice" level with a
specified lot size ("LotSize"), Stop Loss ("UseStopLoss" and "StopLossPips"), and Take Profit ("UseTakeProfit" and
"TakeProfitPips").
ForexSamsam
===== PAGE 24/27 =====
S.3
S.3
S.3
someone try with multiple pair ?
uncorrelated pair in same time.
Adding diversity and more trade.
rstranger
Quoting emmanuel7788
 Disliked
GA Jul 31 Daily trade closed +60pips +2R trade {image} ...
was this good trade based on the exact rules from post 1? or just simply following the breakout on the low?
emmanuel7788
Quoting rstranger
 Disliked
{quote} was this good trade based on the exact rules from post 1? or just simply following the
breakout on the low?
Yes. Follow Post#1 rules.
Wick Sell > Wick Buy ... Sell Stop
Attached Image (click to enlarge)
....
rockzz
===== PAGE 25/27 =====
S.3
Someone make this EA more robotic like auto trading on some specific time to avoid spread issues.
josi
Quoting kai.cao
 Disliked
{quote} Please read the OP: Rule 4: The strategy calculates the "wickBuy" and "wickSell" values
based on the difference between the open price and the low price (wickBuy) and the high price and
the open price (wickSell) of the previous daily candle. Rule 9: If the condition "wickBuy > wickSell" is
met, the strategy places a Buy Stop order at the "buyStopPrice" level with a specified lot size
("LotSize"), Stop Loss ("UseStopLoss" and "StopLossPips"), and Take Profit ("UseTakeProfit" and
"TakeProfitPips"). Rule 10: If the condition "wickSell > wickBuy"...
I try to simplify:
open-to-low (wickBuy) < open-to-high (wickSell) = Sell Stop
open-to-low (wickBuy) > open-to-high (wickSell) = Buy Stop
Is this the condition?
PS:
So - in this case: these would be the paradigmatic entries:
Attached Image (click to enlarge)
===== PAGE 26/27 =====
S.3
S.4
S.4
rockzz
Quoting josi
 Disliked
{quote} I try to simplify: open-to-low (wickBuy) < open-to-high (wickSell) = Sell Stop open-to-low
(wickBuy) > open-to-high (wickSell) = Buy Stop Is this the condition?
Exactly correct
MarcoOne
Hello
Anyone can insert in the code a martingala multiplayer from 1.0 to 2.0 ? whith 1.3 the strategy can better
MarcoOne
hey Guys , anyone here?
===== PAGE 27/27 =====
S.4
S.4
S.4
ghwatson19
The results on the backtests can't be legit. Can they?
tradertan
Quoting rockzz
 Disliked
*Your EA v3* backtest results looks promising and auspicious... EXACT STRATEGY BEHIND THIS
EA The strategy trades on the daily (D1) timeframe. The strategy uses two pending orders: a Buy
Stop order and a Sell Stop order. At the start of each new day, the code checks if a new candle has
formed. If it's a new day, the strategy resets the "orderPlaced" variable to false, allowing it to place a
new order if conditions are met. The strategy calculates the "wickBuy" and "wickSell" values based on
the difference between the open price and the low price...
In your live trading, what account balance are you starting with? Are you hitting margin requirements? Can you
reduce the lot size?
JesusW
I will program an improved robot based on that strategy for MT4 and MT5, and I will share the results when
it is ready.```
