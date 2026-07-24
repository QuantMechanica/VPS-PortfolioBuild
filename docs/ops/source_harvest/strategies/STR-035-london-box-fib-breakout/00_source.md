# STR-035-london-box-fib-breakout — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/29 =====
S.1
A Simple London Breakout
ForexFactory Thread 230640 — 60 Beiträge, Eröffnung: erste 3 Seiten
mer071898
Here is a simple London breakout strategy based on a variation of my BoxFibo indicator from my London
Progressive Strategy thread.
I simplified the indicator to place the initial entry points just between what would normally be the 27 and 38.2 fib
extensions on both sides of the box. I didn't want to extend it past the 38.2 extension, although it can be feasibly
accomplished, because the farther away we move our target, the tougher it is to reach the intended targets as it
move in proportion to the box size. I wanted to make sure we had a higher probability of reaching our target.
The Profit Target line was carefully calculated to produce the same amount of pips as the box size. So, if your box
size was 40 pips, your Profit Target lines should be exactly 40 pips from your entry point. Because of the smaller
box size, this is not intended to grab a ton of pips, but to hopefully increase the success rate our trades.
You will need to place the indicator on a 15 minute chart. The start time is placed from 03:00 to 06:00 GMT, which is
the 3 hours leading up to the Frankfurt open (if your broker's GMT time is not GMT +0, you'll need to adjust the
times accordingly depending on your broker's GMT time). My broker is GMT +1 so I will start at 04:00 to 07:00. The
obvious reason we put this before the Frankfurt open is to have the box drawn before the volatility kicks in and
before the breakouts occur.
With regards to the trades that occur, you can handle them various ways. You can
A) take the first trade you get and just make one trade a night, win or lose, or:
B) take all of the trades that present themselves, it is your choice.
If you trade using option B) and still have open trades when the new box forms, you can leave the trade til it hits
either you Profit Target or stops out, or you can close all open trades before the start of the new box around 03:00
GMT whether your trade is in profit or not, which is what I prefer to do so not to overlap the trades. I prefer the latter
mainly because if I decide to incorporate any *Martingale type of approach, I need to know the new lot size I need to
use before the next trade presents itself.
The nice thing is that you really don't see a lot of trades in a row that are losers. The most I've glanced at was 4-5 in
a row, so you could experiment with a *Martingale style approach and increase lots on your losers to make up for
your losses. Take 4-5 low spread pairs (i.e. Eur/Usd, Usd/Jpy, and so on) and play around with it over the next
several days and over the weekend and then starting on Monday, the 12th, I will pick out a few pairs and show
some examples of how the trades would have unfolded. You should see roughly around a 65-75% win ratio overall.
The pairs I will be monitoring are:
Eur/Usd
Gbp/Usd
Usd/Jpy
Eur/Jpy
Usd/Chf
I highly suggest to not take trades if the box size is over 40-50 pips on all pairs. Generally, this is because a larger
price movement has already occurred before the open and will make it more difficult to reach out targets. I'm not
===== PAGE 2/29 =====
saying it's impossible, but use your common sense before you place any trades.
Good luck!
***Martingale strategies are inherently risky and not recommended unless adequate capital is readily
available to protect your account from the possibility of a margin call. Please utilize proper Money
Management at all times.***
*** Bug fixed in both indicators. Thanks to sangmane for the fix. New indicators and templates loaded.***
4/12/2010
***Just a small note, I have updated the two indicators and templates in post #1 with the changes in the
code that nightyhawk has made which included the MaxBoxSize parameter and the ability to change the
level color. The Fibcolor input parameter was removed as I saw no changes when the input was changed. If
you are using a 5 digit broker, please add an extra "0" to get the correct MaxBarSize.*** 4/15/2010
***A big thanks to Steve Hopwood for modifying one of his EA's to fit this strategy. The current version is
from post #292*** 4/19/2010
***Indicator modifications done by sangmane and squalou are now incorporated to include that you can
now change the color of the box if the box is greater than the MaxBoxSizeInPips input. You may also adjust
the SessionEndTime color as well. You can now also change the entry level and profit target levels. The
default levels in the indicators now are carefully configured to have the profit target from your entry match
the box size. There is also a LevelResizeFactor parameter that has been added which allows you to fine-
tune the levels if you want them different from the box size, but keeping the box as the basis? For example,
if you set it to 0.7 (1.0 is the default for normal trading), then all levels will be adjusted as if the box was
actually squeezed by this factor, still centered to the actual box "median Price". Post #357 has some
example pics and a more detailed explanation. Thanks gain everyone for their contributions.*** 4/22/2010
***V7 of the Indicator has the following improvements:
- shows "Profit Zones" in green (can be disabled by input)
- displays the box size in pips below the box, and a "NO TRADE" sign for red boxes;
- puts a chart-Comment on top left corner with the main settings so you instantly know what they are for
that chart;
- sets system-wide Global Variables for use with the treat below...
Squalou has modified Steve Hopwoods's "London Breakout script" (presented on post #138 and attached
here), go read it to get the scripts basic usage.
This new script will take advantage of the improvements added in V7 indicator, so that you do not need
to manually enter entry/TP/SL values anymore!!!
Here is how to use it:
-1- load the "London BreakoutV7.mq4" indicator (or higher version) on the chart;
-2- drag the script to the chart, and just click OK, that's it.
The script will automatically replace input values left to 0 with the corresponding entry/TP/SL levels for the
===== PAGE 3/29 =====
BuyStop and SellStop orders that the Indicator has computed using your indicators inputs, so you don't
need to manually input them. You can use the script on charts open with different pairs each. Use "F3" key
to show the created GlobalVariables. You can change their values directly there, these will be the ones
taken by the script. They will be updated automatically when a new box is formed the next day. *** 4/28/2010
***V8 has the following added inputs***
This version will allow to keep SL/TP levels into "reasonable" min/max limits on days with too-high or too-
low pre-breakout volatility...
It has 2 more inputs acting as box size limiters.
Don't want your TP/SL levels go off the roof ?
Just set the "MaxExtentInPips" to whatever box size you don't want to exceed, and that's it.
And for those days where you think that the box is too small, and you could surely harvest more
pips than what the tiny green strip suggests...
then just set the "MinExtentInPips" !
Of course, as usual, ignoring those values (default 0) won't change the behavior of the previous versions
indicator... just to keep you feel at home...
Thanks to squalou for all the improvements. If you have any technical questions on the indicator or script
parameters, please PM squalou directly, thanks.*** 4/29/2010
***Complete package is now added in a zip file which now includes:
Steve Hopwoods EA (modified by squalou)
Indicators (New V.9.1 Indicator)
Scripts
Any questions, please PM or e-mail squalou for specifics.*** 5/6/2010
***An alternative setting is currently being tested starting in post #647. The alternative settings and rules
can be found in post #506*** 5/11/2010
***V4.0 version of the EA...
New features:
- Added Trailing Stop capability
New inputs:
TrailingStopPips(0)- pips to trail the StopLoss; when 0 no trailing is applied (fixed SL as before).
TrailingStopStep(1)- trailing SL will jump by this amount instead of trailing at every tick; (helps limit the
number of sent orders, and therefore order rejections).
- Added profit lock-in after fixed profit:
===== PAGE 4/29 =====
S.1
S.1
"BreakEvenPips"- when "BreakEvenPips" is >0, SL is moved to BE+"BreakEvenProfitInPips" when price
has reached BE+"BreakEvenPips". Works independently from "AllowHalfClose" option (but uses the same
BreakEvenProfitInPips value); Will also be trailed if TrailingStop is selected; (inspired from Steve's MPTM
EA...)
"MaxRisk"- if >0, then order size is the min of Lot input and calculated max Lot based on MaxRisk and
Stoploss;
- All open/pending trades will be closed when the EA is unloaded;
- replaced order-related functions with "reliable" versions of them... (will retry 10 times at timed intervals if
call fails).
- when MagicNumber is 0, a unique MagicNumber is created by the EA, MagicNumbers will be different for
each pair/timeframes. This helps running the EA on different pairs/timeframes without having to manually
change the MagicNumber.
- added Alerts when the Indicator Settings Global Variables cannot be found. The EA will stop trading in this
case.
- fix: in V3.0, objPrefix default value was not set to "LB-" as it should have been, leading to error 130
"invalid stops". 5/20/2010***
Attached File(s)
London Breakout Full Trading Package.zip   28 KB | 33,667 downloads | Uploaded May 20, 2010 11:42pm
mer071898
Just so you can see the setup in action, we already have a trade completed on the Eur/Usd for a quick 22 pips!
More detailed examples on next Monday. I will be out of town starting tomorrow, but I will answer any questions you
have as I will have my laptop with me. See ya Monday!
Attached Image (click to enlarge)
Wbafan
===== PAGE 5/29 =====
S.1
S.1
S.1
S.1
What TF do you use. This will be important as the box will not be drawn until after the 7:00GMT candle has finished.
If it is on 5 min chart box could be smaller than 1 H chart etc.
mer071898
A quick look at the chart above shows a 15 minute chart. Good catch , I will edit post #1 with that info, thanks.
dbsys
do you use stop loss?
roundrock
i read the initial post several times, downloaded the template but i couldnt get these simple things
1. where is your stoploss ? is it at the other end of box ? its not mentioned in the initail post
2. where will you put your buy order ? at 27 fib extension ? 38.2 fib extension ? if both are ok, why you need the
other one ? cant we fix one number ?
3. if stoploss is at other end, then risk reward is less than 1:1, you mentioned 70-80% win rate, that would traslate to
BE or a slight positive number. is that correct ?
4. in the template , i changed the times to 05:00, 08:00 (my broker is GMT+1), but the entry exit levels didnt change,
but the box is redrawn
5. would you trade only europe pairs since this is london b/o ? do you have similar b/o for US ? which is the best
pair to trade for london ?
6. you mentioned you can enter several times, we need to keep redrawing the box ? if so you take last 3 hours ?
mer071898
Quote
 Disliked
1. where is your stoploss ? is it at the other end of box ? its not mentioned in the initail post
It shows the stops on the indicator for you.
Quote
 Disliked
2. where will you put your buy order ? at 27 fib extension ? 38.2 fib extension ? if both are ok, why you
need the other one ? cant we fix one number ?
Again, look at the indicator. Your entry point is already there for you. The entry points are calculated to be just above
the 27 ext. on the first indicator and just above the 38.2 ext. and the second version of the indicator. The extensions
have nothing to do with the entry, they are just for reference. You are not being forced to use either one, I just added
the second indicator as another option. Use whatever one make you feel comfortable using. Just remember, if you
use the second indicator that your profit Target lines will be spread out more and more difficult to hit.
===== PAGE 6/29 =====
Quote
 Disliked
3. if stoploss is at other end, then risk reward is less than 1:1, you mentioned 70-80% win rate, that
would traslate to BE or a slight positive number. is that correct ?
Yes, the R/R is less than 1:1, but not by much. Hypothetically, if we use the Profit Target and Stoploss ranges from
the chart above and take 10 trades and use a 70% success rate, we would have this:
(7 x 22 pips)---154 pips minus
(3 x 31 pips)----93 pips
-------------------------------
total pips--------61 pips
Now, if you do 10 trades a day x 5 days in a week, you'll end up with 305 pips. I'd say that is a lot better than BE,
wouldn't you? I know a lot of traders who would love to have just 20 pips a day, let alone 61! Yes, there are better
systems out there, but I doubt there are very many as simplistic as this. Remember, there are people out there who
praise the FAP Turbo and Megadroid EA's, and you only make 5-7 pip profit per trade and yet have 100-200 pip
stop losses. I'll take this any day of the week.
Quote
 Disliked
4. in the template , i changed the times to 05:00, 08:00 (my broker is GMT+1), but the entry exit levels
didnt change, but the box is redrawn
I'm not sure what your asking, but the entry and profit target lines should change as the box size changes. Can you
post a pic of what you're trying to explain, that would help.
Quote
 Disliked
5. would you trade only europe pairs since this is london b/o ? do you have similar b/o for US ? which
is the best pair to trade for london ?
The strategy works best with the GBP/USD. Because this pair trades lightly outside of London trading hours, the
surge in trading every morning in the U.K. gives it a “real” market opening, which the strategy looks to exploit.
Gbp/Usd trading is virtually nonexistent during Asian trading hours. When London opens, however, the Gbp/Usd
accounts for nearly one-quarter of all forex trading. Currency rates with more continuous, 24-hour trading will have
less of a distinct open/close as they pass through the different trading sessions. For example, the USD/JPY, which
dominates Forex activity during Asian trading hours (78 percent of volume), still accounts for 17 percent of trading
during European hours. So, as you can see the London trading session can affect every pair you trade, just pull up
any chart and see for yourself. Looking at the diagram, you can see how the 4 majors have the highest activity in
the London session.
Quote
 Disliked
6. you mentioned you can enter several times, we need to keep redrawing the box ? if so you take last
3 hours ?
No, you don't redraw the box. The indicator redraws automatically each day at whatever time is set in the
parameters. Once the box is drawn after the Frankfurt open, all trades are based on these levels until a new box is
drawn the next night. For multiple entries, once the price retraces back below our original entry point or reverses
and hits the opposite entry point, you have the discretion to enter additional trades if you choose. I will show
everyone more examples of this on Monday.
===== PAGE 7/29 =====
S.1
S.1
S.1
Attached Image
mike1349
Also good information here:
http://www.forexfactory.com/showthread.php?t=183582
Regards
Mike
mer071898
Thanks for the info mike1349, as I always tell people, my strategies are not set in stone and are always up for
personal change to fit you own style of trading.
Wbafan
Thanks for posting your system. I like breakout systems, No need to sit in front of the charts all day! Just set our
orders and stoplosses and get on with the day.
These systems do show profit long term and whilst they won't make you rich over night, they could do in the long
run with the right leverage!
This seems to work on EUR/GBP with the 2nd indicator, very well. This is because the box is usually very small.
===== PAGE 8/29 =====
S.1
S.1
S.1
It does have a very good win ratio if the box is less than 30 pips!
I've been thinking about adding further indicators to filter out losing trades but actually I think indicators keep you out
of more winning trades than save you from losing trades, so i'm not going to bother.
I'm going to start trading EUR/GBP on Monday 12th on live account. I'll let you know how it goes.
Might trade GBP/USD too but only if the box is <30.
mer071898
Quote
 Disliked
These systems do show profit long term and whilst they won't make you rich over night, they could do
in the long run with the right leverage!
Great comment, Every newbie out there thinking of starting Forex trading should learn this mindset first along with
learning Money Management. I have built up my accounts over the years after learning the hard way that all these
strategies and EA's that claim you can double or triple your account are a bunch of crap and are just there to drain
your wallet. I've always believed that if your EA or trading strategy was that good, why sell it?
Quote
 Disliked
I'm going to start trading EUR/GBP on Monday 12th on live account. I'll let you know how it goes.
Thanks, keep us posted on your live trades since that is the best way to validate a trading strategy, live forward
testing. The pairs I'm going to work with are the 4 majors pairs (Eur/Usd, Usd/Jpy, Gbp/Usd, and Usd/Chf) and also
Eur/Jpy and Eur/Gbp. Since you can let us know about the latter, Eur/Gbp, I'll just update and analyze the first 5.
Quote
 Disliked
This seems to work on EUR/GBP with the 2nd indicator, very well. This is because the box is usually
very small. It does have a very good win ratio if the box is less than 30 pips!
Again, it's good to see other traders change it up to fit their own style. I was thinking of doing something similar on
the Usd/Chf, using the 2nd indicator and limiting the box size to only 30-40 pips. It does make sense as these two
pairs do not have the range of the others.
Chango
Mer,
Thanks for sharing your system and indicators.
Jose
mer071898
Not a problem, glad to share what I can as long as it can help out fellow traders. By the way, my fiance loves your
avatar, lol.
===== PAGE 9/29 =====
S.1
S.1
S.1
ingmarforex
Hi MEr,
First thanks for sharing this i think it has good potential this strategy, (indicator) really usefull. I came on a idea to
filter out bad trades more sometimes it goes both ways you dont want that so how whe filter this.
-EMA 84 close.
Put a EMA 84 on your chart when the EMA is in the box for a day whe dont trade. It most be in the box when it is
touching just the sides no problem then it is oke. when box is above EMA whe only looking for longs when price is
below only shorts.
Oke Guys hope you got something on this
fxaus
Thanks for sharing your system and indicators.
mason
stringfx
Thanks for the strategy. Sure looks great on GU and GJ. There seems to be nearly no flaws on these two pairs. On
back testing others EU and EJ and EUR/GBP only has 50% to 60% success rate while UJ seems to have 70-80 %
success rate. I have tweaked the strategy to my taste a bit.
Here is my tweak:
The breakout is from 7 to 10 GMT. I take the trade 5 pips below or above the box and set my TP on fib value of
161.8. 0-100 being the low and high of the box. SL being 5 pips below or above the box opposite of my trade.
Here are my charts:
Attached Image(s) (click to enlarge)
===== PAGE 10/29 =====

===== PAGE 11/29 =====
S.1
S.1
S.1
roundrock
Quoting mer071898
 Disliked
It shows the stops on the indicator for you.
Again, look at the indicator. Your entry point is already there for you. The entry points are calculated to
be just above the 27 ext. on the first indicator and just above the 38.2 ext. and the second version of
the indicator. The extensions have nothing to do with the entry, they are just for reference.
[color=blue]You are not being forced to use either one, I just added the second indicator as another
option. Use whatever one make you feel comfortable using....
wow !!! great explanation. thank you so much mer071898. i will do paper trading for a week. will do major 4 pairs
et_phonehome_2
Since US brokers not allow one to hedge, how do you get filter those false breakouts?
mer071898
Quote
 Disliked
Put a EMA 84 on your chart when the EMA is in the box for a day we don't trade. It most be in the box
when it is touching just the sides no problem then it is ok. when box is above EMA when only looking
===== PAGE 12/29 =====
S.1
for longs when price is below only shorts.
ingmarforex, I appreciate the input. One question, is the EMA set to close or something different? Let us know if you
are testing it out and if has helped you out. For those who want to incorporate the 84 EMA on your chart, feel free to
do so. I will be just utilizing the London Breakout indicator only on this thread for now.
Quote
 Disliked
Thanks for sharing your system and indicators.
mason
You are welcome.
Quote
 Disliked
Thanks for the strategy. Sure looks great on GU and GJ. There seems to be nearly no flaws on these
two pairs. On back testing others EU and EJ and EUR/GBP only has 50% to 60% success rate while
UJ seems to have 70-80 % success rate. I have tweaked the strategy to my taste a bit.
Here is my tweak:
The breakout is from 7 to 10 GMT. I take the trade 5 pips below or above the box and set my TP on fib
value of 161.8. 0-100 being the low and high of the box. SL being 5 pips below or above the box
opposite of my trade.
Glad to see it is working for you, I hope you have success with your tweak. I just want to make sure the thread
doesn't get too bombarded with everyone's variation though. If you have a different strategy or variation, please
open a different thread and discuss them there as I do not want to have any confusion from the original strategy,
thanks.
Quote
 Disliked
wow !!! great explanation. thank you so much mer071898. i will do paper trading for a week. will do
major 4 pairs
I try to be as clear as possible but sometimes you just have to re-iterate what you say to make sure people fully
understand everything. Feel free to ask any questions and I'll answer them the best that I can for you. Now keep in
mind, I'm only using the major pairs because most trader's are familiar with them and are traded more frequently.
You can use this on ANY pair, I just prefer to use it on pairs with low spreads to maximize my profit potential.
Quote
 Disliked
Since US brokers not allow one to hedge, how do you get filter those false breakouts?
First off, There is no hedging going on, you are only in one trade on a pair at a time. You are either getting stopped
out or have already hit your Profit Target before any other trades are being taken.
Wbafan
Mer
===== PAGE 13/29 =====
S.2
S.2
Forgot to ask, do you add on the spread to the entry levels? What are your thoughts, not sure it's going to make
much difference.
xmph
Quoting mer071898
 Disliked
It shows the stops on the indicator for you.
Hello, first of all, thanks for sharing your system and having programmed an indicator for it.
I tried your system over the week-end and I realize that sometimes the Buy StopLoss is the upper part of the box,
sometimes it is the lower part of the box. Is this meant to be like that ?
I checked the code and there is no specific reason to me (I thought eventually depending on the size or volatility for
example) but, and correct me if I'm wrong, it might just be the result of the High/Low logic when you draw fibs and
box at this specific step:
if(tlow > thigh) {
pt1 = vLow;
pt2 = vHigh;
}
else {
pt1 = vHigh;
pt2 = vLow;
}
ObjectCreate(objname,OBJ_RECTANGLE,0,dt1,pt1,dt2,pt2);
ObjectSet(objname,OBJPROP_COLOR,BoxColor);
objname = "BF-Fibo-" + dt2;
ObjectCreate(objname,OBJ_FIBO,0,dt1,pt1,Time[ib1-FibLength],pt2);
Should that be corrected ?
mer071898
Quote
 Disliked
Forgot to ask, do you add on the spread to the entry levels? What are your thoughts, not sure it's
going to make much difference.
I do not figure in and add spreads with regards to the entry. I just enter at the proper entry point and close at the
Profit Target. Whatever the spread may be at the time of the trade is just the cost of doing business.
Quote
 Disliked
I tried your system over the week-end and I realize that sometimes the Buy StopLoss is the upper part
of the box, sometimes it is the lower part of the box. Is this meant to be like that ?
I honestly don't have an answer for you as I have never had the indicator do that to me. I have no coding knowledge
as another trader here at FF coded the indicator for me. As long as you remember that the stoploss is always the
opposite side of the box from the entry point, you should be fine. If anyone sees anything odd in the code, you are
free to fix it.
===== PAGE 14/29 =====
S.2xmph
I did backtest with the following settings:
- Entry as soon as price hit the defined level, exit at defined Take Profit
- StopLoss other side of the box
- Only 1trade/day and no entry after 5pm
- USDGBP only.
for 2009:
Results: start with 3000$, end up with 3842$ - 0.1lots for each open trade. (thus a true strategy profitability testing
without money management)
(2010 till now: start 3000, end up with 2700)
As depicted below:
251 trades, an average of 2 consecutives wins and 2 consecutives losses .... suggesting a potential martingales but
with quite some risk, although max consec wins is 8 compared to 4 max consec losses.
For 2009:
Bars in test 30045
Ticks modelled 15680981
Modelling quality 90.00%
Mismatched charts errors 7
Initial deposit 3000.00
Total net profit 920.75
Gross profit 7396.82
Gross loss -6476.07
Profit factor 1.14
Expected payoff 3.67
Absolute drawdown 451.63
Maximal drawdown 670.82 (17.25%)
Relative drawdown 18.10% (563.13)
Total trades 251
Short positions (won %) 119 (59.66%)
Long positions (won %) 132 (60.61%)
Profit trades (% of total) 151 (60.16%)
Loss trades (% of total) 100 (39.84%)
Largest
profit trade 200.00
loss trade -186.53
Average
profit trade 48.99
loss trade -64.76
Maximum
consecutive wins (profit in money) 8 (809.00)
consecutive losses (loss in money) 4 (-482.13)
Maximal
consecutive profit (count of wins) 809.00 (8)
consecutive loss (count of losses) -482.13 (4)
Average
consecutive wins 2
consecutive losses 2
===== PAGE 15/29 =====
S.2
S.2
S.2
S.2
S.2
I will post the problematic days and eventually some ideas to filter big losses (I think it will be necessary) and/or
money management (Hedging, "why cut at profit when riding a trend....") .
Again thanks for sharing.
XmPh.
Four Kids
Does Frankfurt open the same time as London?
shr5
Quoting Four Kids
 Disliked
Does Frankfurt open the same time as London?
Frankfurt opens an hour earlier than London.
Four Kids
Cheers. Just adjusting times for my platform.
mer071898
Quote
 Disliked
I did backtest with the following settings:
- Entry as soon as price hit the defined level, exit at defined Take Profit
- StopLoss other side of the box
- Only 1trade/day and no entry after 5pm
- USDGBP only.
First off xmph, I assume you meant Gbp/Usd. Secondly, is this an EA that you have built for this, because I would
be interested in seeing how you constructed it and to be able to forward test it. Now don't get me wrong, I
appreciate the input and the help, even though I am not a big fan of backtesting. I just personally feel backtests do
not show the true potential of any strategy. Manual forward testing, even only 6 months worth on a demo account,
makes me more optimistic than 10 years of backtests would, no offense. I would highly suggest allowing the EA to
take more than 1 trade a day because a lot of the time price is initially reversing off the fib level in the first trade and
a lot of the time you will catch your Profit Target on the second or third trade of the night.
Quote
 Disliked
Does Frankfurt open the same time as London?
Frankfurt opens 1 hour before the London Session at 07:00 GMT. I started at the Frankfurt open because there is
always some movement during this time and we don't want the box size too large before the breakout occurs.
mer071898
Quote
===== PAGE 16/29 =====
S.2
 Disliked
I tried your system over the week-end and I realize that sometimes the Buy StopLoss is the upper part
of the box, sometimes it is the lower part of the box. Is this meant to be like that ?
There is a bug in the indicator that may reverse the buy and sell stops as xmph has pointed out depending on how
the fib is pulled to form the box. Until I can get this fixed (unless xmph knows a fix), please remember that the top of
the box is always your initial sell stop and the bottom of the box is your initial buy stop. My apologies to everyone if
there is any confusion.
fxaus
Quote:
I tried your system over the week-end and I realize that sometimes the Buy StopLoss is the upper part of the box,
sometimes it is the lower part of the box. Is this meant to be like that ?
I honestly don't have an answer for you as I have never had the indicator do that to me. I have no coding knowledge
as another trader here at FF coded the indicator for me. As long as you remember that the stoploss is always the
opposite side of the box from the entry point, you should be fine. If anyone sees anything odd in the code, you are
free to fix it.
Attached Image(s) (click to enlarge)
===== PAGE 17/29 =====
S.2
nightyhawk
Quoting mer071898
 Disliked
you will catch your Profit Target on the second or third trade of the night
What is meant with the second or third trade???
===== PAGE 18/29 =====
S.2
S.2
S.2
nightyhawk
Quoting fxaus
 Disliked
If anyone sees anything odd in the code, you are free to fix it.
Seems quite easy to me...
Just replace line 61
Inserted Code
if(tlow > thigh) {
with
Inserted Code
if(vLow > vHigh) {
shr5
Quoting nightyhawk
 Disliked
Seems quite easy to me...
Just replace line 61
Inserted Code
if(tlow > thigh) {
with
Inserted Code
if(vLow > vHigh) {
Thanks nightyhawk.....much appreciated
fxtrader2k7
Quoting nightyhawk
 Disliked
Seems quite easy to me...
Just replace line 61
Inserted Code
if(tlow > thigh) {
with
Inserted Code
if(vLow > vHigh) {
I tried that and it's giving the wrong description.
The correct change is:
===== PAGE 19/29 =====
S.2
S.2
S.2
S.2
if(vLow < vHigh).
Thanks nightyhawk for pointing out the line to change.
roundrock
G/J long stopped out !!! entry 144.19, sl 143.87 , tp 144.60
can someone verify these numbers ? i want to make sure my settings are correct
billbss
Quoting mer071898
 Disliked
First off xmph, I assume you meant Gbp/Usd. Secondly, is this an EA that you have built for this,
because I would be interested in seeing how you constructed it and to be able to forward test it.
[color=Blue]Now don't get me wrong, I appreciate the input and the help, even...
Frankfurt opens at 0600 GMT
London opens at 0700 GMT
This is due to Summer Time (DST)
This year, Summertime is from March 28 until October 31.
dbsys
Quoting roundrock
 Disliked
G/J long stopped out !!! entry 144.19, sl 143.87 , tp 144.60
can someone verify these numbers ? i want to make sure my settings are correct
mine G/J also stoped out.. entry 144.29 stop 143.75 alpari uk
sangmane
Quoting fxtrader2k7
 Disliked
I tried that and it's giving the wrong description.
The correct change is:
if(vLow < vHigh).
Thanks nightyhawk for pointing out the line to change.
Hi guys,
Yes, vLow is always less than vHigh... I'm glad to know that some trader use this indicator.
===== PAGE 20/29 =====
S.2
I want to explain the meaning of tlow, thigh.
PHP Code
int thigh = iHighest(NULL,0,MODE_HIGH,(ib1-ib2+1),ib2);
int tlow = iLowest(NULL,0,MODE_LOW,(ib1-ib2+1),ib2); 
from above formula, thigh/tlow shows the position of the highest/lowest price.
if thigh = 2, it means the highest price is 2 bars to the left, start from the last bar. if tlow = 5, means the lowest price
is 5 bars to the left.
so, if tlow > thigh, in this case 5 > 2, it shows that the price reached its lowest earlier than when it reached its
highest during a specified interval, which means we have swing high. i use this info to decide how the fibo should be
drawn by code.
regarding buystop that sometimes printed in the lower box edge and sellstop printed in the upper box edge, it is
caused by the code below:
PHP Code
    ObjectSetFiboDescription(objname,1,"Initial Buy Stop = %$"); 
    ObjectSetFiboDescription(objname,0,"Initial Sell Stop = %$"); 
I missed this one until Mer told me today. The above code assign Fibs description regardless how the fibs is drawn
(swing high/swing low). To correct this issue, you can make the following changes:
PHP Code
    int ibuy, isell; //addition
    if(tlow > thigh) {
      pt1 = vLow;
      pt2 = vHigh;
      ibuy = 0; //addition, for swing high, buystop at first fib level, ie. 0 level
      isell = 1; //addition, for swing high, sellstop at second fib level, ie. 100 level
    }
    else {
      pt1 = vHigh;
      pt2 = vLow;
      ibuy = 1; //addition
      isell = 0; //addition
    } 
and on the objectsetfibodescription:
PHP Code
    ObjectSetFiboDescription(objname,ibuy,"Initial Buy Stop = %$"); 
    ObjectSetFiboDescription(objname,isell,"Initial Sell Stop = %$"); 
hope this help
fxaus
is it possible to attach the right version of indicator and template?
thx
===== PAGE 21/29 =====
S.2
S.2
S.3
S.3
sangmane
attached below the corrected version of previous London Breakout 2 indicator. now buystop is always on the top
edge of the box, sellstop is always on the bottom edge. also this indicator permit you to use StartTime = 22.00 and
EndTime = 03.00. you can use London Breakout 2 template located on the first page
Attached File(s)
London Breakout 2.mq4   4 KB | 2,333 downloads
xmph
Quoting mer071898
 Disliked
Secondly, is this an EA that you have built for this, because I would be interested in seeing how you
constructed it and to be able to forward test it.
Yes a dirty 1hour-coding EA, modding the indicator to use it as an input in the EA. It is quite ugly, simple and stupid.
It does only the simple thing I said.
Backtesting, Forward testing .... what I care about is money in my account .... that is forward. Do you trust
something that has been backtested over 10yrs .... I don't as the market will most probably behave differently in the
future ... however would you have a better feel at the strategy's behaviour ... I do. Make the most out of what you
have ... my line of thinking ... every piece of information is worth gathering.
I will share the EA most probably next week as I believe I will have a little time to make it less dirty next Monday (not
before) - I want it to allow for testing different filter if some amongst us are coders.
Thanks for sharing.
X.
PS: my only concern with such an EA .... I think there have been tons of breakout strategy EA on FF and I don't
know if any are really profitable, or if this would not be re-doing what others did (eventually better). What do you
think?
nightyhawk
Quoting sangmane
 Disliked
Yes, vLow is always less than vHigh... I'm glad to know that some trader use this indicator.
WTF... seems my brain had his funny day
Hmmm... will try that easy workaround...
Inserted Code
ObjectCreate(objname,OBJ_RECTANGLE,0,dt1,vLow,dt2,vHigh);
nightyhawk
Quoting xmph
 Disliked
===== PAGE 22/29 =====
S.3
S.3
PS: my only concern with such an EA .... I think there have been tons of breakout strategy EA on FF
and I don't know if any are really profitable, or if this would not be re-doing what others did (eventually
better). What do you think?
0400-0700 GMT Breakout Strategy 2892
7am-9am Big Dog USD Breakout Strategy 2515
4H Box Breakout 5023
BREAKOUT seem to rule
mer071898
Quote
 Disliked
What is meant with the second or third trade???
Basically, when you are either stopped out or have hit your Profit Target, when the price retraces back to your entry
point you may take another trade if you wish (see pic).Last Thursday, April 8th, was a very good example. We
could've had 7 possible entries that day, 6 winners@ 16 pips each and 1 loser@ 21 pips. Now as I said before, you
do not have to take every trade that presents itself. Some people may only want to take one trade a day and others
may choose to trade more if the are willing to put in the screen time.
Attached Image (click to enlarge)
mer071898
Quote
 Disliked
Frankfurt opens at 0600 GMT
London opens at 0700 GMT
This is due to Summer Time (DST)
This year, Summertime is from March 28 until October 31.
Thanks for the info.
===== PAGE 23/29 =====
Quote
 Disliked
G/J long stopped out !!! entry 144.19, sl 143.87 , tp 144.60
Yes, you may have been stopped out, but you also would have had a winning trade immediately after that. (see pic
below)
Quote
 Disliked
attached below the corrected version of previous London Breakout 2 indicator. now buystop is always
on the top edge of the box, sellstop is always on the bottom edge. also this indicator permit you to use
StartTime = 22.00 and EndTime = 03.00. you can use London Breakout 2 template located on the first
page
I want to thank sangmane for the fix as he did all the work on the original version of my box fibo indicator in my
London Progressive thread, thanks again buddy, I owe you one. I've attached the fixed indicators and new
templates to post #1.
Quote
 Disliked
PS: my only concern with such an EA .... I think there have been tons of breakout strategy EA on FF
and I don't know if any are really profitable, or if this would not be re-doing what others did (eventually
better). What do you think?
Quote
 Disliked
0400-0700 GMT Breakout Strategy 2892
7am-9am Big Dog USD Breakout Strategy 2515
4H Box Breakout 5023
BREAKOUT seem to rule
xmph makes a valid point though, most breakout strategies are inherently simple which is great for anyone to use
but are also known to lack on the performance side. Hopefully this can be addressed eventually.
Attached Image (click to enlarge)

===== PAGE 24/29 =====
S.3
S.3
mer071898
Here is my analysis of last nights trading on;
Eur/Usd
Gbp/Usd
Usd/Jpy
Eur/Jpy
Usd/Chf
All pips totals I mention are before the spread.
First the Eur/Usd. We had one trade entry that just miss our target and is now in a range. I would wait til your near
the start of the box around 04:00 GMT and close the trade whether in profit or not. I was hoping to see the gap filled
by now, but it may still happen.
***Update***
After narrowly missing our target twice, Eur/Usd stay ranging for most of the night and I would've closed out at
04:00 GMT for +36 pips (see new pic)
Attached Image (click to enlarge)
mer071898
Textbook trade on the Gbp/Usd for roughly 55 pips.
Attached Image (click to enlarge)
===== PAGE 25/29 =====
S.3
S.3
mer071898
Usd/Jpy was starting strong and died out just before hitting target. Now don't hesitate if you want to close the trade
in profit, there's nothing wrong with that.
***Update***
Our initial trade was stopped out for -33 pips but we had a successful 2nd entry that just finish several hours ago for
+25 pips. (see new pic)
Attached Image (click to enlarge)
mer071898
Another solid trade on the Eur/Jpy for roughly +36 pips.
Attached Image (click to enlarge)
===== PAGE 26/29 =====
S.3
S.3
S.3
mer071898
Usd/Chf hit the entry quick and then stalled, similar to Usd/Jpy. I'd give it til 03:00-04:00 then close out for a small
loss if you have to.
***Update***
Usd/Chf did not breakout of it's range before 04:00 GMT so I would've closed out the trade at 04:00 GMT with a
small 10 pip loss. (see new pic)
Attached Image (click to enlarge)
Uberscalper
Wouldn't this strategy work perfectly fine without the fibonacci extensions?.Just enter on a breach of the high or the
low of the box.
mer071898
===== PAGE 27/29 =====
S.3
S.3
S.3
S.3
Yes I'm sure it probably could, but that's not what the thread is about. If you want to try it out that way, be my guest.
nightyhawk
Quoting mer071898
 Disliked
Usd/Chf hit the entry quick and then stalled, similar to Usd/Jpy. I'd give it til 03:00-04:00 then close out
for a small loss if you have to.
My backtest showed me, that almost the whole time USD/CHF is doing the opposite of EUR/USD (as we know,
there is a anti-correlation)... so wouldn't it be better to leave out USDCHF?
nightyhawk
Quoting mer071898
 Disliked
Yes I'm sure it probably could, but that's not what the thread is about. If you want to try it out that way,
be my guest.
I think the concept with FIBs looks promising... nevertheless I changed your rules in two simple point...
One change is according to SL... I set my initialStopLoss in the middle of the box... Backtesting showed, that I will
have only a few more losses but therefore smaller ones...
roundrock
lot of times they are retracing after touching our entry levels. would it be prident to wait for a retracement and enter
at a better price instead of blindly placing orders as per system ? we could miss some good trades but overall it
gives better RRR
mer071898
Quote
 Disliked
My backtest showed me, that almost the whole time USD/CHF is doing the opposite of EUR/USD (as
we know, there is a anti-correlation)... so wouldn't it be better to leave out USDCHF?
I'm just showing examples using the major pairs. It is up to the trader to pick which pairs works best for them.
Quote
 Disliked
I think the concept with FIBs looks promising... nevertheless I changed your rules in two simple
point...
One change is according to SL... I set my initialStopLoss in the middle of the box... Backtesting
showed, that I will have only a few more losses but therefore smaller ones...
Good, glad to see your making it work for your trading style, that's exactly what I like to see. Good luck and keep it
up.
===== PAGE 28/29 =====
S.3
S.3
S.3
S.3
mer071898
Quote
 Disliked
lot of times they are retracing after touching our entry levels. would it be prident to wait for a
retracement and enter at a better price instead of blindly placing orders as per system ? we could
miss some good trades but overall it gives better RRR
Okay, I think we really need to understand that this strategy is just a base for you to trade off of and not to be
construed as the perfect way to trade. We can have 100 people come in here and nit pick thing thing apart all day
long if we wanted to, but I hoping it doesn't get that way. Take it and modify it how ever you choose. If you feel the
fib levels are too close, move the entry point farther out, that's why I included two indicators in post #1. That's the
beauty of this, change it to fit how you trade. For me, personally, I have a large enough account to be able to
martingale my lots after a losing trade to recoup my losses. Now I know not everyone is able to do that but the
strategy(as exph tested out and stated earlier in the thread) is strong candidate for it, so I will test it out and hope it
can be profitable. But that is just how I'll choose to trade it.
shr5
Quoting mer071898
 Disliked
[color=Blue]Okay, I think we really need to understand that this strategy is just a base for you to trade
off of and not to be construed as the perfect way to trade. We can have 100 people come in here and
nit pick thing thing apart all day long if we wanted to, but I hoping it doesn't get that way. Take it and
modify it how ever you choose. If you feel the fib levels are too close, move the entry point farther out,
that's why I included two indicators in post #1. That's the beauty of this, change it to fit how you trade.
For me, personally, I have...
I read your thread over the weekend and tried it yesterday on my live account......I normally trade off intraday and
daily fibs and adding this strategy did wonders to my own way of trading....for the time being I tried it on GBPUSD
and EURJPY.....as those are the only pairs I trade normally......I will keep posting my views over the next few days
while I test it out.....but for me this strategy is definitely a keeper thanks
Wbafan
Yesterday we got of to a winning start..JUST!
+16 pips on a sell order for EUR/GBP.
Orders are set for today, will update with results ASAP.
I think we might need to be mindful of S/R and pivot level, if these are close to our orders, might be worth adjusting
orders so these are just inside/outside the order price etc.
mer071898
Total simulated results from Monday:
Eur/Usd= +36 pips
Gbp/Usd= +55 pips
Usd/Jpy= -8 pips (+25-33)
Eur/Jpy= +36 pips
Usd Chf= -10 pips
===== PAGE 29/29 =====
S.3
______________________
Total= +109 pips (6 trades taken- 4 winners, 2 losers)
Again this is just how I see the trades happen. Now If I were to trade the way I really wanted to, I would have
doubled up on the second Usd/Jpy trade (which would have made up for the initial loss) and would double up on the
Usd/Chf trade for today.
Quote
 Disliked
Yesterday we got of to a winning start..JUST!
+16 pips on a sell order for EUR/GBP.
Was this on your live account? If so, good job and keep us updated.
mer071898
Quote
 Disliked
I read your thread over the weekend and tried it yesterday on my live account......I normally trade off
intraday and daily fibs and adding this strategy did wonders to my own way of trading....for the time
being I tried it on GBPUSD and EURJPY.....as those are the only pairs I trade normally......I will keep
posting my views over the next few days while I test it out.....but for me this strategy is definitely a
keeperhttp://cdn.forexfactory.com/images/s.../yim/happy.gif thanks
Please don't take offense, but I'd be extremely cautious of trading immediately on live account until it really has
proven itself. Now I can't tell you not to, but if you are determined to trade live, please use extremely small lots until
you are perfectly comfortable with it.```
