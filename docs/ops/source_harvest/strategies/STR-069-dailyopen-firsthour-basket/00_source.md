# STR-069-dailyopen-firsthour-basket — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/16 =====
S.1
1 Hour after daily open
ForexFactory Thread 535657 — 53 Beiträge, KOMPLETT (3 Seite(n))
Nik13
If the first 1 hour candle will close above DO line, we go bullish
If the first 1 hour candle will close below DO line, we go bearish
Trading pairs GBP/USD; EUR/USD; (Why? because those two are less volatile at that
time)
Stoploss is 10 pip.
Take profit is 10 pip.
You sought that was it? no.
Here are additional option.
Both trades are opened at the same time.
So we will set Equity Take Profit (which: if both positions will gain 10pip in a row, they'll
be closed).
___________________________________________________________________________
Below -
Daily open line Indicator - guess what is that if you can.
Equity Sentry EA - easiest EA so far, you will see. (PS, I do not claim ownership, I found it on FF) system similar to
this
OpenFirstHour EA - opens positions with the logic above, thanks to ranger_lp
system similar to this >>> http://www.forexfactory.com/showthre...13#post8211413
DO NOT FORGET TO SMILE,
WRITE YOUR OPINION,
===== PAGE 2/16 =====
S.1
S.1
S.1
S.1
S.1
SUGGESTION OR AT LEAST
SAY THANK'S FOR EA
PROVIDER.
Attached File(s)
Daily open line.ex4   8 KB | 969 downloads
Equity Sentry v1.4c.ex4   46 KB | 803 downloads
OpenFirstHour.mq4   4 KB | 992 downloads
Nik13
PS, and I do not want to see 2875683756243423 downloads on files above, without any replays, suggestions or
something. That makes me mad, it looks like nobody wants to help but everyone wants to get a profitable system.
that another EA is needed, so PLEASE provide it if you can.
mahdihasan
Forgot to say thanks for sharing your thinking here.
Have you any backtest or forward test result bro?
kohonez
you could use AmazingEA: http://www.forexfactory.com/showthre...51#post8091951
ranger_lp
Was playing around with an EA that might do what you are looking for......try it out....
Attached File(s)
OpenFirstHour.mq4   4 KB | 605 downloads
imran.78p
daily open open tends to behave as one of the strong support and resistance . This system works wonder if we dont
stop for just 10 pips. instead with some manual blend this is the system which has 60% to 90% profitability with 2:1
or 3:1 R:R ratio
as i dont have programming skills, how could we put stop loss on the other side of daily open price with 10-15 pips
margin
and how buy and sell rule could be modified for number of pips away from open price,
and only one order at one time
===== PAGE 3/16 =====
S.1
S.1
S.1
S.1
Nik13
Quoting mahdihasan
 Disliked
Forgot to say thanks for sharing your thinking here. Have you any backtest or forward test result bro?
Hi, thanks for replay and you are always welcome.
No, I have not yet.
When Sydney starts, there is 1AM in my country (so i have to wait 1 more hour to see the setup). That's why I need
an EA to open it automatically.
Nik13
Quoting ranger_lp
 Disliked
Was playing around with an EA that might do what you are looking for......try it out....{file}
Thanks good sir, I appreciate that.
Perhaps, I will open 3 MT4 for 1 account to make 3EA work at the same time, but it's not a problem.
Thanks!
Nik13
Quoting kohonez
 Disliked
you could use AmazingEA: http://www.forexfactory.com/showthre...51#post8091951
Thanks friend!
Nik13
Quoting imran.78p
 Disliked
daily open open tends to behave as one of the strong support and resistance . This system works
wonder if we dont stop for just 10 pips. instead with some manual blend this is the system which has
60% to 90% profitability with 2:1 or 3:1 R:R ratio as i dont have programming skills, how could we put
stop loss on the other side of daily open price with 10-15 pips margin and how buy and sell rule could
be modified for number of pips away from open price, and only one order at one time
Thanks for replay, I'll do my best to explain my point o view about everything written above.
1. EU & GU are less volatile (as I already mention) before LO. we can set 3:1 / 2:1 ratio for pairs, like NU, GJ, EJ,
..... (Because they're more volatile during Sydney and Tokyo), however we can not set 10SL and 30TP, why?
because SL (once again because of high volatility and spread disadvantage) is more likely to be hit more than 75%
===== PAGE 4/16 =====
S.1
S.1
of the time, so at the end of the month we are lucky if we will close at the BE.
2. DO does not guaranty a trend which will give us 30 pip profit, so I tried to increase our chance on 49-50 (Spread
factor is the biggest disadvantage of the FX trader) and not on 75/25. Positive RRR has nothing to do here, why?
because SL is too tight.
However, we can design a system similar to this, for example : same rules, but SL-50 TP-150 (or something like
that), then we can count on MM.
Edition:
Oh, by the way, S/R in Forex market are LESS important (but important as well) then in Stock markets. simply
because stock market is moved by more by MarketMakers and BSD's, while FX market is moved by economy.
I do not agree that DO can somehow be S/R.
imran.78p
Hi Nik
check this out EJ ... The blue line is daily line.. how it behave yesterday and day before as resistance
Attached Image (click to enlarge)
Nik13
Quoting imran.78p
 Disliked
Hi Nik check this out EJ ... The blue line is daily line.. how it behave yesterday and day before as
resistance {image}
===== PAGE 5/16 =====
S.1
S.1
S.1
Hi imran!
Thanks for replay.
Do you think that we can use it on EJ as well?
I'm trying to collect couple of pairs together, in fact, what I want to do is to close equity profit in a row, not TP from
single positions.
If we can mix EJ, GJ, UJ (for example) or just EJ and UJ, than that'll be great,
imran.78p
hi nik
as i am currently using the DO + 15-20 as start and stop loss at the other side of DO - 15-20 pip and using it on AU,
NU, GU, EU and Japanese pair s , and for day trading not just for 10 pips , so i can recommend it for pairs
mentioned above
GJ has has very high volatility and i usually dont play with this dragon
shiva
Quoting imran.78p
 Disliked
daily open open tends to behave as one of the strong support and resistance . This system works
wonder if we dont stop for just 10 pips. instead with some manual blend this is the system which has
60% to 90% profitability with 2:1 or 3:1 R:R ratio as i dont have programming skills, how could we put
stop loss on the other side of daily open price with 10-15 pips margin and how buy and sell rule could
be modified for number of pips away from open price, and only one order at one time
I agree with this, I just scrolled back on a chart and did a visual insoection, it is possible to get more than 10 pips.
may be 20 pips. RR of 1:2
Nik13
Quoting shiva
 Disliked
{quote} I agree with this, I just scrolled back on a chart and did a visual insoection, it is possible to get
more than 10 pips. may be 20 pips. RR of 1:2
Thanks for replay shiva.
I agree too, MAY BE we will get 20 pip, however it's more likely to get 10 pip, then 20..
Let me explain : scroll back and you will see, that almost every (99%) of daily candles have shadow on the opposite
side of the close (if Daily candle is bullish, it has bearish shadow and vice versa). From my point of view, in most
cases those shadows are more likely to be 10 pip long then 20. . .
what you think?
===== PAGE 6/16 =====
S.1
S.1
S.1
S.1
S.1
Perpheps let's create another bakset of pairs and do a 20 pip target if you want to. No problem, but we will need
somebody else (except of me, because I'm running 5 MT4 at one time and it's horrible) to forward test it.
Nik13
Quoting imran.78p
 Disliked
hi nik as i am currently using the DO + 15-20 as start and stop loss at the other side of DO - 15-20 pip
and using it on AU, NU, GU, EU and Japanese pair s , and for day trading not just for 10 pips , so i
can recommend it for pairs mentioned above GJ has has very high volatility and i usually dont play
with this dragon
Very well, do you think that running AU and NU at the same time is a good idea? (because of the high correlation)
The thing is if AU will go in -8 it's very likely that NU will be in -7/-6 (or nearby) as well. .
Can you write down a basket of pairs (other pairs like EU/GU) with TP and SL levels for each to trade on them as
well please?
shiva
Quoting Nik13
 Disliked
{quote} Thanks for replay shiva. I agree too, MAY BE we will get 20 pip, however it's more likely to get
10 pip, then 20.. Let me explain : scroll back and you will see, that almost every (99%) of daily
candles have shadow on the opposite side of the close (if Daily candle is bullish, it has bearish
shadow and vice versa). From my point of view, in most cases those shadows are more likely to be 10
pip long then 20. . . what you think? Perpheps let's create another bakset of pairs and do a 20 pip
target if you want to. No problem, but we will need...
How about locking in 5 pips and letting it run with stops being moved every 10 pips or so. I will start a demo with tp
20 and SL 10 with tomorrows open.
imran.78p
dear nik
Why the hell are u running 5 Mt4,
if you want forward test on different pair for the same EA, just change the Magic number on each chart .....??
or is any thing else..
Nik13
Quoting shiva
 Disliked
{quote} How about locking in 5 pips and letting it run with stops being moved every 10 pips or so. I will
start a demo with tp 20 and SL 10 with tomorrows open.
OK, let's try it.
Nik13
===== PAGE 7/16 =====
S.2
S.2
Quoting imran.78p
 Disliked
dear nik Why the hell are u running 5 Mt4, if you want forward test on different pair for the same EA,
just change the Magic number on each chart .....?? or is any thing else..
I'm testing another systems as well.
Besides, on our system, I have to use 2 EA's, so as I know, it's impossible to run 2 EA's on 1 mt4 ( isn't it?)
imran.78p
further as i told you i dont have programming skill ,
from some last couple of days and weeks GU tends to be playing on both side of DO. or once the trade it taken
watch it for reversal and and some perfect days on EJ and NU gives you 80% pips for the whole day and this come
usually 2-3 times a week
- based on the average 15-20 pips is my stop loss on the other side of DO for EJ, EU, NU AO, as i trade manually
i watch for MA of 200 and 100 on hourly chart and daily range
see the attached chart 8, 9 , 10th April were one of perfect days for GU
Attached Image (click to enlarge)
Nik13
Quoting imran.78p
 Disliked
further as i told you i dont have programming skill , from some last couple of days and weeks GU
tends to be playing on both side of DO. or once the trade it taken watch it for reversal and and some
perfect days on EJ and NU gives you 80% pips for the whole day and this come usually 2-3 times a
week - based on the average 15-20 pips is my stop loss on the other side of DO for EJ, EU, NU AO,
===== PAGE 8/16 =====
S.2
S.2
S.2
S.2
as i trade manually i watch for MA of 200 and 100 on hourly chart and daily range see the attached
chart 8, 9 , 10th April were one of perfect days for GU {image}...
WOw, agree, great days (especially april of 8) 168 pip possible gain.
but I have no idea definitely, I have no idea how we can catch whole move.
I'll be glad if I can catch 10 pips every day.
If we will risk 1% on each day, our gain will be 1% as well.
In one month, it's more than 20% gain, most of investors will go to war for monthly 20% gain.
imran.78p
we can only wish if forex market is that much simple........
Nik13
This has nothing to do with this thread, but anyway, can somebody do - so EA below will close only market orders,
not pendings?
Please?
Attached File(s)
Equity Sentry v1.4c.ex4   46 KB | 369 downloads
kohonez
I hope you can understand me cause english is not my primary language:
Starting today, I will use a script (Tradehedge.mq4) to open orders manually everyday at the close of the daily
candle, 2 orders at 10 pips TP each and SL 50 pips for each pair (we need room for daily price movement) and a EA
for trade management (Sleep Tight.ex4).
The script open positions for 7 pairs, it can be edited to add more pairs and the MM EA can manage tp,sl,ts,etc of all
pairs at once.
If any coder can make a EA with automatic trading and MM capabilities would be great.
Attached File(s)
Sleep Tight.ex4   10 KB | 709 downloads
TradeHedge.mq4   4 KB | 514 downloads
Nik13
Quoting kohonez
 Disliked
I hope you can understand me cause english is not my primary language: Starting today, I will use a
script (Tradehedge.mq4) to open orders manually everyday at the close of the daily candle, 2 orders
at 10 pips TP each and SL 50 pips for each pair (we need room for daily price movement) and a EA
for trade management (Sleep Tight.ex4). The script open positions for 7 pairs, it can be edited to add
===== PAGE 9/16 =====
S.2
S.2
S.2
more pairs and the MM EA can manage tp,sl,ts,etc of all pairs at once. If any coder can make a EA
with automatic trading and MM capabilities would be great....
Hi, thanks for replay!
It's ok, ENglish is not my native language as well.
I understood everything, however, from my point of view, 1:5 negative RRR is not a good idea, but who knows, let
try, keep us up to date please. and if you can code an ea, can you please check out my last comment above? I have
that one EA which need some update, mazy be you can help?
Nik13
Quoting Nik13
 Disliked
This has nothing to do with this thread, but anyway, can somebody do - so EA below will close only
market orders, not pendings? Please? {file}
Guys, come onnnnn, 6 downloads and no replays?
imran.78p
Attached Image (click to enlarge)
AU after daily open
imran.78p
well IGHR
EITHER recommend some profitable EA ...................
===== PAGE 10/16 =====
S.2
S.2
S.2
S.2
or
Nik13
So, first setups were today, both positions closed in SL ( I will upload screenshots later (and every day)) but I made
a mistake in setting up positions I set equity profit on 10, not 5....
Nik13
Quoting imran.78p
 Disliked
well IGHR EITHER recommend some profitable EA ................... or
Sorry, I do not get it?
Nik13
bad luck. GU was down by 10.7 pip for my broker, 2 more pippet and it was going to hit TP.
two positions lost, -10$ //// -1%.
Attached Image (click to enlarge)
imran.78p
Attached Image (click to enlarge)
===== PAGE 11/16 =====
S.2
S.2
another jump over Daily open price
........................ and it continue
imran.78p
EUR USD Just made another attempt to stay obove DO.............lets see
imran.78p
EU jump over DO................
Attached Image (click to enlarge)

===== PAGE 12/16 =====
S.2
S.2
S.2
Mariodrugs
1 hour after Daily Open:
Historically last two weeks result:
Attached Image (click to enlarge)
not worth strategy sry.
Nik13
Quoting imran.78p
 Disliked
EU jump over DO................ {image}
Hmm, may be we can build another system too. . Will write it down and let you guys know.
Thanks imran, you are doing a great help.
Nik13
Quoting Mariodrugs
 Disliked
1 hour after Daily Open: Historically last two weeks result: {image} not worth strategy sry.
Thanks for replay
in general, I do not like martingale strategys, but, with certain risk, it might be worth of trying for this system.
===== PAGE 13/16 =====
S.2
S.2
S.3
Good idea friend, I will count maximum risk that we can take if we will use martingale and let you know.
Nik13
Here, this is the martingale model for our system.
The 5th day is way too much risk, so I'm suggesting to stop on 3rd day.
(Percentages are count for 5,000 $ )
Ideas?
Attached Image
Nik13
Another similar system.
Entry
Waiting for daily open
After daily open, wait for the first hour close
If first hour will be bearish, than place buy stop on the daily open line
If first hour will be bullish, than place sell stop on the daily open line
TP: 10 (but not sure, may be more)
SL: 10
Can somebody develop EA for that please?
Chantalb
Hi Nick,
You have a good concept going, very close to how I trade.
BUT....
1- Choosing the D1 open is crucial i.e. which one??
2- With the 1H you're already too late and too slow i.e. you have to micromanage your day assuming that you are
day trading and not holding over night.
3- You have to assume that everything you are told about trading is false; for example, not using volume cause it is
irrelevant in FX... I use it every day, hour, and minute.
4- Mark up your chart with important opens, highs and lows e.g. today's open, yesterday's H&L, London Open, NY
& NYSE opens... etc...
5- Study what happens when they all line up and when they don't.
===== PAGE 14/16 =====
S.3
S.3
S.3
S.3
S.3
Let the above marinate in your mind and you will make a very big discovery.
All the best in your trading career,
Cheers,
Nik13
Quoting Chantalb
 Disliked
Hi Nick, You have a good concept going, very close to how I trade. BUT.... 1- Choosing the D1 open is
crucial i.e. which one?? 2- With the 1H you're already too late and too slow i.e. you have to
micromanage your day assuming that you are day trading and not holding over night. 3- You have to
assume that everything you are told about trading is false; for example, not using volume cause it is
irrelevant in FX... I use it every day, hour, and minute. 4- Mark up your chart with important opens,
highs and lows e.g. today's open, yesterday's H&L, London...
thank you so much for replay and advice.
1. Often times, people consider DO as Sydney open (are not they?)
2. I need an entry, not something that will give me a signal about daily trend direction. when trend is down from the
first hour after DO ( and since EU and GU are less volatile before London open), it's more likely that they will keep
going the same way, without changing the direction for the rest of the night.
3. nothing to say about that. Indicators might be useful.
4. of course
5. right.
I'm not arguing, on the other hand, I appreciate your replay and advice. THANKS.
dilkasraj
My net gain are 120 pips each month from the past 3 Years to my real account.
1 day a week i lose and 4 days i pulls the profit.
@ Chantalb is almost right, it is a very big discovery. BUT the one who discovers keeps it hidden.
Keep up your good work.
imran.78p
dear dilkasraj ...... your holy trader do not show what you say
dilkasraj
@ imran its different strategy for demo account.
Nik13
2 losses with doubled lot. (0.1)
-3.1%
Attached Image (click to enlarge)
===== PAGE 15/16 =====
S.3
S.3
S.3
S.3
Nik13
Quoting dilkasraj
 Disliked
My net gain are 120 pips each month from the past 3 Years to my real account. 1 day a week i lose
and 4 days i pulls the profit. @ Chantalb is almost right, it is a very big discovery. BUT the one who
discovers keeps it hidden. Keep up your good work.
Hi, thanks for replay.
You know, from my point of view, holy grail is the system that can win in a long term ( or 3 out of 5 days a week ).
If i'll be able to discover system like that, I do not see any reason not to share it with people here.
They are not my competitors, are they? so it's does not make any sense not to share any working system (except
super EA's, which you can sell).
Nik13
http://www.forexfactory.com/showthre...13#post8211413 new thread for the similar system. < check it out if you
want.
LDFX
Quoting dilkasraj
 Disliked
@ imran its different strategy for demo account.
Always the same story, guys are showing their unprofitable demo account and of course not their real profitable
account that they are trading since years...
Nik13
===== PAGE 16/16 =====
S.3
S.3
S.3
1tp 1sl
Attached Image (click to enlarge)
Berci
http://www.myfxbook.com/strategies/openfirsthour/80494
Nik13
Quoting Berci
 Disliked
http://www.myfxbook.com/strategies/openfirsthour/80494
Interesting, but that dudes RRR is 1:50!
mima
Well that indicator window for openfirsthour indicator is empty : just shows empty window on bottom. Why?
What is Magic Number 10001?```
