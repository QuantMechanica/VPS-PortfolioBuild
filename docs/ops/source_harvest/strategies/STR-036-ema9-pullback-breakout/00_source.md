# STR-036-ema9-pullback-breakout — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/14 =====
S.1
S.1
S.1
S.1
Simple 1 EMA Strategy on M15
ForexFactory Thread 242787 — 45 Beiträge, KOMPLETT (3 Seite(n))
Feliks
Hi guys. I have found one profitable strategy.
It works on M15 with one EMA.
All rules I ll share if somebody will help me to develop this.
http://rapidshare.com/files/401904193/EMA.mq4.html
Feliks
I want to inculde here
-SL TP rules
-Break even
-Pip between MA and High/Low price
-Max orders
Can some one help me to do this?
Knez
Quoting Feliks
 Disliked
I want to inculde here
-SL TP rules
-Break even
-Pip between MA and High/Low price
-Max orders
Can some one help me to do this?
Are you looking to make an EA from that system or ....?
Regards,
Knez
Feliks
Quoting Knez
 Disliked
Are you looking to make an EA from that system or ....?
===== PAGE 2/14 =====
S.1
S.1
S.1
Regards,
Knez
I created some EMA EA but need help to develop. Below I attached file(rapidshare)
That rules I want to include to EMA EA
Knez
Quoting Feliks
 Disliked
I created some EMA EA but need help to develop. Below I attached file(rapidshare)
That rules I want to include to EMA EA
Your file from Rapidshare is not available anymore, as it's allow 10 downloads only.
Feliks
OK. Guys. Thats All rules
Tried on GBPUSD M15
9 EMA
Buy condition
-If price close above 9EMA and
-If second candles low at least 5 pip away form 9EMA and
-If second candles close > precious candle's high
So OPEN BUY
SL place under previous candle's low + 1 pip + spread
TP = 2 x SL
Sell condition
-If price close below 9EMA and
-If second candle's high at least 5 pip away form 9EMA and
-If second candle's close < previous candle's low
So OPEN SELL
SL place under previous candle's high + 1 pip + spread
TP = 2 x SL
Knez
Quoting Feliks
 Disliked
===== PAGE 3/14 =====
S.1
S.1
OK. Guys. Thats All rules
Tried on GBPUSD M15
9 EMA
Buy condition
-If price close above 9EMA and
-If second candles low at least 5 pip away form 9EMA and
-If second candles close > precious candle's high
So OPEN BUY
SL place under previous candle's low + 1 pip + spread
TP = 2 x SL
Sell condition
-If price close below 9EMA and
-If second candle's high at least 5 pip away form 9EMA and
-If second candle's close < previous candle's low
So OPEN SELL
SL place under previous candle's high + 1 pip + spread
TP = 2 x SL
If second candle low (for buy) is not 5 pips away from 9 ema, but let say 4 or 3 ... do you wait for such candle (with
min. 5 pips away from 9 ema) to appear, and then enter the trade, or trade has expiry?
Feliks
Quoting Knez
 Disliked
If second candle low (for buy) is not 5 pips away from 9 ema, but let say 4 or 3 ... do you wait for such
candle (with min. 5 pips away from 9 ema) to appear, and then enter the trade, or trade has expiry?
If after cross 3,4 candles I didn's see trade, so NO TRADE
Pips between MA and price can be 4 or 5
So can u code or include rules I sad above?
Attached File(s)
EMA.mq4   10 KB | 1,179 downloads
Feliks
The Outsider Method
But some rules I changed
Attached File(s)
===== PAGE 4/14 =====
S.1
S.1
S.1
S.1
S.1
The Outsider Method.pdf   45 KB | 3,326 downloads
Phreddy
Quoting Feliks
 Disliked
The Outsider Method But some rules I changed
What did you change Feliks?
Feliks
Quoting Phreddy
 Disliked
What did you change Feliks?
Pips beetween MA and Price
SL and TP rules. I think TL no need. Because some times if we use TL, we can exit from market very early.
Angle beetwen MA and price its very important. If MA is more horizontal NO TRADE, even MA 5 or more pips away
from price
Based on very big candles to enter is very dangerous
And This can be work on another pair. But need find more reliable parametrs EMA
Knez
Quoting Feliks
 Disliked
If after cross 3,4 candles I didn's see trade, so NO TRADE
Pips between MA and price can be 4 or 5
So can u code or include rules I sad above?
Sorry, I asked my friend to do it, but when he saw it, he says it is not worth as he already tried this and is not giving
any good results.
Feliks
Quoting Knez
 Disliked
Sorry, I asked my friend to do it, but when he saw it, he says it is not worth as he already tried this and
is not giving any good results.
Now I manually trade based on this. I see not bad results. By the way can your friend try to include other rules that i
said?
Feliks
This is EMA EA
I need include here
-SL TP rules
===== PAGE 5/14 =====
S.1
S.1
S.1
S.1
For Buy condition place SL previous candles Low+1pip+ spred
TP = 2 x SL
For Sell condition place SL previous candles High +1pip + spred
TP = 2 x SL
-Pip choosing between MA and HighLow of candle (which we gonna to enter)
-Max orders
-Can be risk ratio too
-If Sl = 10 punkt no trade
-if candle will open with gap no trade
Attached File(s)
EMA.mq4   10 KB | 1,104 downloads
Knez
Quoting Feliks
 Disliked
Now I manually trade based on this. I see not bad results. By the way can your friend try to include
other rules that i said?
I will ask, but I don't think so that he would be interested.
Feliks
I can show 5-6 days trading statement but I cant. Couldn't attach.
Here one picture.
http://img43.imageshack.us/img43/9953/ordere.gif
Feliks
Guys, This is my last try to show you how WE can earn money in this buisness. I am more than 1 year in this
market. I tried many strategies and the end I decided that THE BEST STRATEGY MUST BE VERY SIMPLE. SO
SIMPLE THAT I CAN REMEMBER ALL RULES....
http://img580.imageshack.us/img580/8227/orders.gif
roundrock
why would anyone spend time to write EA if they are not convinced about the profitability of the system. i am not
saying this system is not profitable. but you need to prove/convince the other members that it can be a good
profitable system. that proof of burden is on you.
pl take some charts, demo them for a period, log the trades, show to the world.
if you want a EA first to check if the system is good or not, then i dont think anyone will come forward.
===== PAGE 6/14 =====
S.1
S.1
Feliks
Quoting roundrock
 Disliked
why would anyone spend time to write EA if they are not convinced about the profitability of the
system. i am not saying this system is not profitable. but you need to prove/convince the other
members that it can be a good profitable system. that proof of burden is on you.
pl take some charts, demo them for a period, log the trades, show to the world.
if you want a EA first to check if the system is good or not, then i dont think anyone will come forward.
I cheked for 2 weeks in history. It takes a lot to write, test and analyze. Thats why I want EA. Fast test, Fast analyze.
If I ll do all the work, so why I need EA?!
roundrock
this is the EU M15 chart that i just took.
Candle1 pierced and closed below EMA
Candle 2 high just touched EMA, the gap is not 5 pips. so this is not entry candle
Candle 3 high is less than 5 pips from EMA. so this is entru candle.
now the SL is high of Candle 2 or Candle 3 ?
what is the need for 5 pips gap ? is there any reason ? we could have got better entry at Candle 2.
Attached Image (click to enlarge)
===== PAGE 7/14 =====
S.2
S.2
Feliks
Quoting roundrock
 Disliked
this is the EU M15 chart that i just took.
Candle1 pierced and closed below EMA
Candle 2 high just touched EMA, the gap is not 5 pips. so this is not entry candle
Candle 3 high is less than 5 pips from EMA. so this is entru candle.
now the SL is high of Candle 2 or Candle 3 ?
what is the need for 5 pips gap ? is there any reason ? we could have got better entry at Candle 2.
Moving Average is "Middle Price" of "Market Price" and you have to wait while candle close not touching EMA. If
you will check on history you can find false signal if you will choose "Candle 2". Candle 3 is entry because of gap
between Price and EMA. But this is a little dangerous, because Candle3's close less lower than Candle 2's low. Yes
SL is right and TP must be 2xSl. By the way I saw if we'll see SL is around 10 pips, no trade.
roundrock
Quoting Feliks
===== PAGE 8/14 =====
S.2
S.2
 Disliked
Moving Average is "Middle Price" of "Market Price" and you have to wait while candle close not
touching EMA. If you will check on history you can find false signal if you will choose "Candle 2".
Candle 3 is entry because of gap between Price and EMA. But this is a little dangerous, because
Candle3's close less lower than Candle 2's low. Yes SL is right and TP must be 2xSl. By the way I saw
if we'll see SL is around 10 pips, no trade.
" But this is a little dangerous, because Candle3's close less lower than Candle 2's low" -- can you explain this
statement ?
SL is high of candle 2 or 3 ?
roundrock
GU chart. long entry. can we go long on candle 3? but this is red candle and its close is then candle 2
Attached Image (click to enlarge)
Feliks
Quoting roundrock
 Disliked
" But this is a little dangerous, because Candle3's close less lower than Candle 2's low" -- can you
explain this statement ?
SL is high of candle 2 or 3 ?
===== PAGE 9/14 =====
S.2
S.2
S.2
S.2
http://img715.imageshack.us/img715/8286/19882405.gif
Feliks
Quoting roundrock
 Disliked
GU chart. long entry. can we go long on candle 3? but this is red candle and its close is then candle 2
http://img641.imageshack.us/img641/2389/66488592.gif
Feliks
This is results of trading from 18 June. I think Not bad. But nobody want to help me))
Attached Image (click to enlarge)
tinorio
Quoting Feliks
 Disliked
This is results of trading from 18 June. I think Not bad. But nobody want to help me))
hi feliks...
is that the result from manual trading or from the EA ?
Feliks
===== PAGE 10/14 =====
S.2
S.2
S.2
S.2
Quoting tinorio
 Disliked
hi feliks...
is that the result from manual trading or from the EA ?
Manual trading
finally
Quoting Feliks
 Disliked
OK. Guys. Thats All rules
Tried on GBPUSD M15
9 EMA
Buy condition
-If price close above 9EMA...
I have already read about and tried this system but I was not able to make a dime.
If you can find a way to make it work, the more power to you.
Feliks
Quoting finally
 Disliked
I have already read about and tried this system but I was not able to make a dime.
If you can find a way to make it work, the more power to you.
I say one thing to you. Even very famous traders never give all rules of their trading. They just show how he(she)
can trade. Trader must check all this and have to try from all this "mess around" create "candy" and "eat it".
Because its tasty only "for him".
Trading is very simple, if you will look at it simply.
For example, How many ways you think market has?
If i don't confuse 3 Up, Down, Range
Caillou
Hi Feliks,
Totally agree with you. Best systems are very simple. I � ve just done a visual backtest of it and looks very
promising. Just price action, no indicators (only 1 EMA as S/R), just present.
As soon as I start trade with your system next week, I � ll post some charts.
Thanks for sharing.
Feliks
===== PAGE 11/14 =====
S.2
S.2
S.2
S.2
Quoting Caillou
 Disliked
Hi Feliks,
Totally agree with you. Best systems are very simple. I � ve just done a visual backtest of it and looks
very promising. Just price action, no indicators (only 1 EMA as S/R), just present.
As soon as I start trade with your system next week, I � ll post some charts.
Thanks for sharing.
Hi. Thanks for your interest. But some "sides of this trading" I don't say. Actually because of users. I don't like lazy
traders which come to see but nothing to leave, to improve this thread. I'll say another "rules" who first of all create
an EA or backtest this manualy like you promising.
Best regards
Caillou
Yes, but I don � t really like EA � s, I prefer manual trades, you always need some of discretion, i.e. not trade 30 min
before/after news.
Anyway, obviously we need some filters before enter a trade after a pattern candle, I use ADR more than 40 and
fractals on M1, M5 and M15 bullish, and then enter the trade after a pattern candle.
Next week I � ll try it on E/U, E/J, G/U and A/U. I think we can improve this strategy if we believe in it.
Bests Regards
Caillou
Sorry, I mean fractal breakout, bullish or bearish.....
Feliks
First of all fractal repaint. Second I dont believe any ossilator.
Just a simple questions. Please answer them honestly
1. Who or what drives markets?
2. If I have 200-300 000$, how do you think I'll wait for ADR cross or RSI overbought or oversold or other ossilyator
signals?
By the way we don't need complicate what's already just simple. Try something find in what we have, but not
including another instrument.
Caillou
Sorry if I had disturb you, but a fractal don � t repaint, It � s just another fractal.
An Upper Fractal (Oposite for lower fractal) is a five bar pattern where the high of the middle bar (bar 3) is higher
than the highs of the other 4 bars (bars 1,2 & 4,5), so fractal don � t repaint. The fractal breakouts are powerfull.
And a small Average Dailly Range (ADR) just show a market choppy.
Anyway, I didn � t want to add more indicators, only to share the filters I use because I think your system needs
some filters... Just my opinion.
===== PAGE 12/14 =====
S.2
S.2
S.2
Feliks
Quoting Caillou
 Disliked
Sorry if I had disturb you, but a fractal don � t repaint, It � s just another fractal.
An Upper Fractal (Oposite for lower fractal) is a five bar pattern where the high of the middle bar (bar
3) is higher than the highs of the other 4 bars (bars 1,2 & 4,5), so fractal don � t repaint. The fractal
breakouts are powerfull.
And a small Average Dailly Range (ADR) just show a market choppy.
Anyway, I didn � t want to add more indicators, only to share the filters I use because I think your
system needs some filters... Just my opinion.
I know my system need some filters but not these. I'll say that filters after EA creation. If you are so interest in this
write to my e-mail or contact me another way(ICQ,MSN) i'll tell another rules of this strategy.
Caillou
Ok, I did it.....
Feliks
http://img69.imageshack.us/img69/4199/ordersh.gif
Attached Image (click to enlarge)

===== PAGE 13/14 =====
S.2
S.3
S.3
S.3
S.3
campco
Hi Felix,
I was reading this interesting thread, but unfortunately it stopped. What is it that made you stop.
I like simplicity in forex, that's why I started reading but now it is a sort of deception to see that there is no follow up.
Even if the project failed, it is good to know why.
Regards, Ben
Feliks
Quoting campco
 Disliked
Hi Felix,
I was reading this interesting thread, but unfortunately it stopped. What is it that made you stop.
I like simplicity in forex, that's why I started reading but now it is a sort of deception to see that there is
no follow up. Even if the project failed, it is good to know why.
Regards, Ben
Cause of everybody wants to know, but nobody wants to tell or improve. Thanks some guys for their expert
advisors, but that time i didn't know even a little about coding like now. So system works. The basic idea for this
system came from "The outsider method" article. You can just google it and see the results.
System needs filters for range markets..
ramyalexis
let this thread be continued.
It would be interesting to know about filter rules on ranging markets.
Ty for help and such an interesting simple.
Prodi
i have a system lik this, that works with one sma , a mtf macd and an rsi filter.. that runs on 5 currency pairs. it
profits daily but im on the look out for when it starts to fail so far so good
Feliks
I tested this system and found some improvements. First of all I changed 9 EMA to default 14 SMA.
Then For Buy condition
Close > 14 SMA (H4)
Close > 14 SMA (H1)
Then check M15 time frame. If on this TF Close price already > 14 SMA. Just wait for correction. Close < 14 SMA
and Close > 14 SMA (+ pips between SMA and Close must be)
Then we buy. I usualy use 40 SL and 120 TP. at 40 pip profit breakeven, at 80 pip profit close half of position and
rest another part by trailing stop (40 pip).
===== PAGE 14/14 =====
S.3
For Sell Condition vise versa.
gonso
Hi Feliks and All,
Interesting and simple. I am a simple man, so I like simple things.
My contribution: I have done some backtesting this past days with EMA9 in 1m TF. I prefer 1m (I do not have much
time) and I am quite an impatient man. Ok, my opinion is:
In the 1m TF, in EUR/USD, it seems to work fine from 0800 to 1000 (CET) (I have not tried around New York open
times). In addition, in this time frame, it seems that we do not need to stick to the gap between the candle and the
EMA. We just need the candle to open and close above (or below) the EMA except:
- if the candle is an inverted hammer (or a hammer), in which case we do nothing but wait for the next opportunity
- if it is a pure doji (i.e. just a cross), then I do not know (any idea?) but prefer to keep aside.
- the candle is too large ('large' still to be defined, sorry, I have just started with this strategy)
In addition, if the candle crosses the EMA (i.e. opens and closes above ema, but minimum is below, reverese for
sells), then I do not know yet. I think that if the EMA is somehow flat, better do not enter. If it has a good slope, then
no problem in entering. Maybe a filter needed here. I have tried 25 EMA, and if 9EMA>25EMA then buy, but still not
sure. Any ideas?
As soon as I get home I'll post some pictures.
(note: I have not live traded yet with this strategy, only made some studies)
Next step: try the 14SMA and other values for EMA and SMA.
Happy Pips to all
gonso```
