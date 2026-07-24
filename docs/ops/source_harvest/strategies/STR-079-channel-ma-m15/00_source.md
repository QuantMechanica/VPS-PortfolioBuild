# STR-079-channel-ma-m15 — Source extract (verbatim pypdf text, 2026-07-25)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/24 =====
S.1
Channel MA Short-Term System
ForexFactory Thread 707474 — 60 Beiträge, Eröffnung: erste 3 Seiten
MickeyMar
About Me
I have been trading for 12 years now, and for most of this time I've made my living from the market, or from market-
related business. I have traded many systems, of mine and of others, with various levels of success. For about 4
years I have settled on this system, which fits my financial objectives, my trading style and my psychological profile.
I have consistently been successful trading it, and for years I felt no need to try any other on my live accounts.
I have decided to make the step towards sharing and discussing it, for 2 reasons: one is to give back to this
community, where I've been lurking for many years, and from where I took many ideas and learned a lot. The
second is more selfish: I'm looking for help in coding an EA for the system, since the technical work is probably not
too difficult and the benefit for us all would certainly be worth it. And also, I'm looking to share what I know so far in
successfully trading it manually, in order for us all to make it a success in automated trading as well. My schedule
lately is more and more busy, I want to keep trading but at the same time I feel like manual trading is starting to be a
burden for me, and because I have extensive experience with this simple system and already took almost
everything I could from trading it manually, i feel this step is the logical one at this time.
The System – General Stuff
I started trading as an Elliott Wave guy (a method I still value a lot and prefer for market analysis, for its detailed
insights into all kinds of scenarios), but at the same time I have always been fascinated by MA crossover systems,
for their extreme simplicity. I always thought I could find the "perfect" MA crossover combination that would work
universally, and spent years trying and testing such crossovers. As you can probably guess, I found there is no such
thing I have started to be successful with MAs when using the Rainbow template (which I still consider very good for
identifying levels and diagnosing trends), but it needed "analysis", and I wanted something even more simple,
faster, easier to trade on the go.
Then, about 4 years ago, a simple idea crossed my mind: the MA crossover systems are all perfect in trending
conditions, but their main (and major!) problem was their repeated small losses in sideways markets. What if I could
find a way to avoid that noise, and filter most of it out? That's how the idea of channel trading the MAs was born.
I tested, and immediately found it to be a huge improvement, even at a first glance. Without much concern for the
"perfect" MAs, I chose a channel defined by MAs I had used before (55), and I made a few days' testing to find a
signal line. I applied it retrospectively on some pairs, and it seemed to work. Then I introduced a few more rigid
rules, and it worked like that as well. I started trading it live (taking into account the rainbow levels, too) and within a
few weeks I was consistently profitable. Then I started to trade this system exclusively, and since then I only traded
this strategy, with a few minor variations (money management, stops, scaling in, choice of pairs).
The system is extremely simple.
Chart Settings
M15 Chart (but the principle works on larger charts as well)
55 EMA, applied to low + 55 EMA, applied to high = the channel.
33 EMA applied to close = signal line.
System Rules:
===== PAGE 2/24 =====
Long signal: signal line crosses above channel (33EMA applied to close crosses ABOVE 55EMA applied to high)
Short signal: signal line crosses below channel (33EMA applied to close crosses BELOW 55EMA applied to low).
STOPS:
Hard stop: 40-50pips (depending on pair and situation)
No stop: close & reverse at opposite signal.
TARGETS:
Fixed tp: 40pips, with SL moved to break even when price reaches 20-25pips profit. (needs a lot of management,
and only works if you handle few pairs)
Flexible tp: set at 210 pips, and trade closed at the end of the session (I do this many times, and it seems the best
option).
No tp: trade is closed at opposite signal in profit.
There are 2 entries:
Normal Entry: the crossover happens within regular volatility conditions, with price close to the channel (a SL
placed at 40-50pips distance from entry would be placed on the other side of the channel, so the channel becomes
a "barrier" between current price and SL). The trade is executed immediately according to the rules.
Delayed Entry: the crossover happens as a result of extreme volatility, with price far from the channel (more than
40pips), so an attempt to put a hard SL would result in the SL being placed inside the channel, or on the same side
of it as the entry. In this case, the trade is not immediately executed, and instead a pending order is placed at the
level of the signal MA (the order should fill when price touches again the signal 33EMA). The order remains valid for
as long as the signal is valid, and usually is filled.
The delayed entry is meant to ensure that there is enough room and power for a move in favor of a signal, and that
we do not enter at the end of a push. I have found the channel to be a pretty strong obstacle, especially in such
situations, and so I always aim to have my stop protected by the channel.
System Advantages:
Simplicity: quite obvious, no need for further explanations.
All trading is done in the direction of the short-term trend. Absolutely no top or bottom picking: very good for
traders who struggle with discipline.
Controlled risk, but high profit potential (if used without fixed 40pips tp)
MA noise and false signals filtered up to 80%, while still receiving early M15 signals to ride the big moves.
Possibility to use as an entry system only, with analysis done on larger timeframes (for those already fond of
other analysis methods, longer-term).
Even if there are many failed signals, the losses are small and the losing trades get closed out quickly, while
the correct signals (more in number) can make profits of 100-200pips easily, every week.
Possibility to trade a basket of currencies, with focus on overall equity and not the individual signals (the
option I'd like to explore with you guys here).
I want to use the system on a larger basket of pairs, but was unable so far because it's difficult to take all signals
and manage them if trading is done manually.
I read and appreciated a thread here in FF, something like "set and forget basket trading". Those guys do exactly
what I plan to do here, with the only difference that their signals are given by other indicators, and are the same for
the whole week. I liked their work, and I admired their system, which in spite of its rigid setup seems to work pretty
good.
The channel system could be more versatile when traded as a basket, and we could enjoy the benefits of basket
trading while still being very quick in adapting to market conditions, because no matter what the market does, we
are NEVER against the trend for more than 40-50pips. If the market makes large moves in favor of a certain
currency, all the pairs involved will bank in hundreds of pips (over 4-5 correlated pairs more than 1000pips can be
reached within the week). In choppy market conditions the system does ok, breaks even or can even make small
===== PAGE 3/24 =====
losses, but in strong trends (on any currency) the system makes huge profits. Considering that each currency has
its own time of rally which may not coincide with the others, with a good EA we can be there EVERY TIME the
market moves rapidly and never miss any large swing, because the small chart it works on (M15) will push us in
very early.
The EA would have to take the rules into account (especially the delayed entry), have an option for taking all
signals/crossovers or just the first one (the one that changes the bias from long to short and viceversa), and have
the option of hard SL/TP or flexible (close at next signal). We can discuss all that here, I hope.
I would love to offer any kind of feedback to those of you trying it out, and also to work together towards making it
an automated system generating a minimum of 500pips monthly (in manual trading I usually got more than that).
Please share your testing and let's make some pips together!
Attached Image (click to enlarge)
Attached Image (click to enlarge)
Attached Image (click to enlarge)
===== PAGE 4/24 =====
Attached Image (click to enlarge)
Attached Image (click to enlarge)
===== PAGE 5/24 =====
S.1
Indicators:
Attached File(s)
b-clock.ex4   2 KB | 1,906 downloads
Attached File(s)
ChMaCross (1).ex4   9 KB | 2,012 downloads | Uploaded Oct 23, 2017 5:32pm
Template:
Attached File(s)
#MA-channel-system.tpl   3 KB | 1,773 downloads | Uploaded Oct 23, 2017 5:31pm
Expert Advisor (thanks to Damiend):
Attached File(s)
DD-channel-MA-1.2.ex4   53 KB | 1,095 downloads | Uploaded Nov 3, 2017 9:55am
Attached File(s)
DD-channel-MA-1.3.ex4   59 KB | 1,365 downloads | Uploaded Nov 3, 2017 9:54am
aaven
Quoting MickeyMar
 Disliked
About Me I have been trading for 12 years now, and for most of this time I've made my living from the
market, or from market-related business. I have traded many systems, of mine and of others, with
various levels of success. For about 4 years I have settled on this system, which fits my financial
objectives, my trading style and my psychological profile. I have consistently been successful trading
it, and for years I felt no need to try any other on my live accounts. I have decided to make the step
towards sharing and discussing it, for 2 reasons:...
Thanks MickeyMar for sharing your system and experience...
===== PAGE 6/24 =====
S.1
S.1
S.1
S.1
S.1
S.1
S.1
S.1
Cix79
Hi .... does it work on the day?
Joseph95
Very interesting, thank you Mickey! Subscribed :-)
coolheat320
Thank you for posting Mickey.
pet3250
Thanks Mickey, this looks to a great system and thank you for taking the time and effort to share it with us. I am in
and excited as I really like to use the MA crossovers.
rare
System Rules:
Long signal: signal line crosses below channel (below 55EMA applied to low)
Short signal: signal line crosses above channer (above 55EMA applied to high).
I don't understand the rules sorry, Should I long when the signal line crosses below the channel?
The pictures you posted contradicts this statement.
NPTrader
Nice introduction, waiting for more
hanuraj
Quoting rare
 Disliked
System Rules: Long signal: signal line crosses below channel (below 55EMA applied to low) Short
signal: signal line crosses above channer (above 55EMA applied to high). I don't understand the rules
sorry, Should I long when the signal line crosses below the channel? The pictures you posted
contradicts this statement.
Means to say..
Long :When 33 EMA crosses the upper band (of channel of 55 EMA) from BELOW To UPPER side .... &
Short :When 33 EMA crosses the lower band (of channel of 55 EMA) from UPPER side to BELOW..
Am I right... MickeyMar?
yczzd
===== PAGE 7/24 =====
S.1
S.1
S.1
S.1
S.1
Do you have successful trading exposure? I'm also a fan of the average crossing system, because I've designed a
similar strategy, just a little difference in the parameters of moving averages, but the trading results are not very
ideal.
MickeyMar
Quoting rare
 Disliked
System Rules: Long signal: signal line crosses below channel (below 55EMA applied to low) Short
signal: signal line crosses above channer (above 55EMA applied to high). I don't understand the rules
sorry, Should I long when the signal line crosses below the channel? The pictures you posted
contradicts this statement.
Correct, an error slipped in when I pasted from the word doc. Fixed now. Long is when signal crosses ABOVE the
channel, short when it goes BELOW. Thanks for pointing it out.
Lifestudent3
Looks like a cool system and I want to propose two questions:
1) What if you exit the trade once the opposite signal is generated? This could increase profit potential during strong
trends...
2) What if the 33-MA was rather a 33 period Bollinger Band and once the 33-MA from the BB crosses the channel,
wait for a pullback to the lower band (buy signal) or upper band (sell signal)? This could potentially eliminate early
entries...
MACDave
Hi Mickey, great simple system, what pairs do you trade and what time Europe open to close or UK open to close?
Also, would this EA trade 24 Hours a day?
And when you say Flexible tp: set at 210 pips, and trade closed at the end of the session (I do this many times, and
it seems the best option).
This session is that UK session/US session or the day?
And lastly, what do you do about red news?
goodways100
Subscribed. Thanks and
Regards
forexdaist
Thanks for sharing! It's really interesting, I want to test it.
What is the session do you use to trade it? In case of "Flexible target", when do you mean to close all your trades?
London close, NY close??
===== PAGE 8/24 =====
S.1
S.1
S.1
thanks you
TONI
billbss
Maybe I missed it, but which Time Frame are you trading?
Thanks
forexbandit7
Quoting billbss
 Disliked
Maybe I missed it, but which Time Frame are you trading? Thanks
He mention it as 15M
MickeyMar
First of all guys, thank you all for the positive response. I feel that together we can make the best of this system, and
hopefully manage to start trading it via EA (automated).
I will try answering all questions.
Cix79, Im not sure what you mean by "does it work on the day" - the principle of the channel works everywhere MA
crossovers are used, and it will filter out noise, for sure. But I'm not sure if these precise settings will be any good
other than giving you an orientation on the larger charts. I only used it on M15 (extensively) and H1 (just to see how
it behaves).
The main point why I came up with this system was that I needed a short-term strategy that would ALSO catch 150-
250pips moves, and one that would discipline me in never going against the current market move, in the hope for a
turn. The system is perfect for this, and if you are a mid-term trader you can still catch the new trend right in the
early stage, because of the very small M15 chart the system uses. At the same time, this system manages to keep
your risk very low (it MUST be maximum 50pips, if not the entry will be delayed as per the rules!), so this is an
advantage over systems trading larger timeframes (with larger stops, of course).
The trading results are very good indeed, but I admit to using some discretion sometimes, especially in exiting and
scaling in. The system has clear stops, limited to 50pips - but the targets are not equally clear, because the hourly
trends can be quite long and powerful, and with one such risk a trader can make anywhere between 20pips and
300pips (some signals on some pairs make more than that).
Lifestudent3 - you make a good point, and yes, it's good to wait the trend to follow its course and close when an
opposite signal arises. But this will not necessarily make you THE MOST pips. From my experience, the most pips
are made when the close is done right at the end of a trading session (can be any of them), for me it's usually US,
because I trade London & NY. Also, it depends if I have other trades in the same direction... This is exactly why I
want to explore basket trading this system, as I'm pretty sure the results will be much better if we allow more
opportunities to grow, on more pairs.
The EA would generally trade around the clock, yes - but a filter could be used against opening positions in Asia, for
instance, so we can experiment with timing.
About the news: I make sure I'm aware of them, and tighten the risk right before the announcement. If the SL is hit, I
am usually pushed out quickly, before a much larger move develops (the opposite signal does not come too quickly,
as it will probably be delayed). Usually, since I am ALWAYS trading with the trend, with the move active in the
market at any time, the news tend to CONTINUE that move, rather than go against it. I'd say Im around 60% likely
to have my trades favored by news, in general. Which is good enough for me.
I do NOT close before news, ever - because all my study and testing included these large moves caused by news,
and it's VOLATILITY, and I'm with the trend. I have no reason to refuse volatility, especially since I'm on the right
side of the market. And by definition, I will always be. In case of extremely choppy news, with say 100pips in one
direction, then 150 in the other, the channel will make sure I am not going in and out with many losses... So even if
===== PAGE 9/24 =====
S.1
S.1
S.2
the worst happens, I'm usually out with 1 loss, then I can re-assess the situation and get back on the horse in the
correct move.
Finally: guys, his system has many losing trades, as moving averages are not predictive in nature. There are on
average some 20trades in a month per pair, out of which some 8-9 are losing trades (even if slightly in negative). I
have no problem with all that, as my monthly target is 500pips, and there are many opportunities to make them
across just a few pairs, with minimal discretion (closing at good levels). But even if you make it a rule to take profit
around 40, from my experience you should still be profitable if you trade 3 pairs. My favorite are: USDJPY,
EURUSD, GBPUSD. The very volatile crosses give more losing signals, but since their volatility is much higher
when a good trend is caught it covers easily 3-4 losses in one move.
This is exactly why I am thinking to trade the system as a basket of 15-20 pairs, with calculated correlations, so as
to minimize overall risk and never miss huge short-term moves (there are 2-3 almost every week, across all pairs).
Thanks again for all your feedback, it's much appreciated. Anyone willing to take a look at the rules and try an EA,
that we could all share, improve and use?
Cheers!
forexbandit7
My first trade with this sys, closed partial, today most of the pairs are ranging, will forward test it and post it here.
Attached Image (click to enlarge)
mario777
Very nice of you for sharing!
Mickeymouse, what does it mean delayed entry? How do you enter on the delayed entry?
Marc82Much
Mickey - I am new to this so please excuse my "noobness". I was working on your plan this morning. Put the
indicators on my chart and found this....
Attached Image (click to enlarge)
===== PAGE 10/24 =====
S.2
If there was a SHORT ENTRY and some profit and then a sharp move against me, I would have stopped out and if I
had used a trailer, at say 50 pips, my loss would have been fairly small. The system did not signal to go LONG with
the spike up (good thing) and then it looks like there would have been another SHORT re-entry, which is still running
for great profit. Am I reading this correctly?
MickeyMar
Let me give you guys a sample of how I use the system - taking today as an example.
EURUSD
Attached Image (click to enlarge)
Today we had a very early signal reconfirmation (because the original signal short is from October 12. I don't trade
at those hours, so I found it in the morning at 1.1778, some 12pips lower than the signal. Since a 20pips stop
around 1.18 was at the time on the other side of the channel, there was an opportunity to short intraday. Of course,
if the trade had been taken at the signal reconfirmation, or on Oct.12, we would have done nothing else than watch
the pips grow
GBPUSD
Attached Image (click to enlarge)
===== PAGE 11/24 =====
USDJPY
Attached Image (click to enlarge)
GBPJPY
Attached Image (click to enlarge)
===== PAGE 12/24 =====
S.2
S.2
S.2
MickeyMar
Quoting forexbandit7
 Disliked
My first trade with this sys, closed partial, today most of the pairs are ranging, will forward test it and
post it here. {image}
Well done Bandit. If you had caught the signal when it originally came out, you'd have made twice as much good
job.
Guys, I posted indicators and template in the first post. The arrows are my improvisation, from some indicator I
found here on the factory. Would be nice if we designed another one
MickeyMar
Quoting mario777
 Disliked
Very nice of you for sharing! Mickeymouse, what does it mean delayed entry? How do you enter on
the delayed entry?
See the first post, and the chart examples. The delayed entry is simply an order to sell or buy (according to the
signal which came out too far from the channel), when price reaches the level of the signal MA (33EMA applied to
close). Or you can manually take it, as close to the channel as possible.
forexbandit7
EU trade
Attached Image (click to enlarge)
===== PAGE 13/24 =====
S.2
S.2
S.2
MidnightRun
Quoting forexbandit7
 Disliked
EU trade {image}
Bandit,
Thanks for posting. It seems to me that in both your posted trades you entered late (long after signal MA crossed
the channel MAs). What's the reason? What other considerations delayed entry? Does MickeyMar have any
thoughts on this?
Thanks.
diamonddbw
One suggestion would be to ignore signals prior to either Frankfurt or London open, regarding use of EA. Perhaps
with the exception of Aud, Nzd & Yen pairs. Generally the distance between 55's is 7-10 pips. Adding the 33 cross,
& close, maybe enough of a buffer, even during non major market times.
MM, you, apparently, have been tracking this for a while. What is your opinion on this?
Sorry, I see you already answered this. Did not refresh thread after being open for a few hours.
damiend
Hi MickeyMar,
Thanks for sharing your strategy, it looks very interesting!
Attached is a quick first version EA that follows your rules, with a hard SL an TP for this first version. It looks
profitable on some pairs but I'm sure we can improve it a lot
Please check it and let me know if I understood all your rules correctly.
Attached File(s)
DD-channel-MA-1.0.ex4   26 KB | 696 downloads
===== PAGE 14/24 =====
S.2
S.2
S.2
S.2
S.2
forexbandit7
Quoting MidnightRun
 Disliked
{quote} Bandit, Thanks for posting. It seems to me that in both your posted trades you entered late
(long after signal MA crossed the channel MAs). What's the reason? What other considerations
delayed entry? Does MickeyMar have any thoughts on this? Thanks.
ill wait for a retrenchment of the price on 5M and i dont sell or buy with market order,i always go with pending
sell/buy, this my way of entering the trade , nothing to do with the original method
Gg33
Looks interesting - subscribed - thanks for sharing
MickeyMar
Yes, it's true Bandit entered late but I'm assuming he doesn't sleep on the PC, so probably he saw the signals late
and followed them as he could. I do that too, as I said I have no EA so I can't be that precise, I've always used
discretion. That's what he did, too.
Marc, yes, the signals you point out are correct. You see... if we had used the EA, probably we'd still be in that
original EU short - but in discretionary trading you could have taken some pips first, then be stopped out, and then
re-enter on the reconfirmation (new cross) and go all the way down to where it is now, close it now, or keep it
running. Both approaches are ok. I tend to favor the first approach, because entering with the FIRST signal and
staying in, together with other 15-20 pairs, could take our equity way up, and when we hit say, 10% of the account,
or more, we can close them altogether and then re-enter signals as they re-emerge. We will explore this scenario
with the EA made by Damien, which I'm testing now. Thanks Damiend!
Diamond - yes, would be nice to have an hour filter, that we can use for non-jpy, aud, nzd and usd pairs. I don't
really need to take a signal on EURGBP in the middle of the Asian session...
Another useful filter would be the option to use just "first signal" (the first time market changes direction, and not re-
enter on the reconfirmations after that - new crossovers), or enter a new lot for each crossover, even if it just
reconfirms the original direction. Could we put that on, Damiend?
rare
Hey Mickey do you have to monitor the trades or can you open the trade at start of London session for example and
close at NY close??
MickeyMar
The EA should have one very important feature, without which the results would be a total mess (I don't know if the
current EA has it, because i can't see the code):
the signals should be considered valid only if they are PRINTED on the chart, meaning only AFTER THE M15
CANDLE CLOSE. Many times the indicator i have gives a signal, only to dissapear at the close of the candle
(because price goes back before candle close and the signal MA pulls back as well, invalidating the signal).
Also, an option "no tp, close at opposite signal" (and reverse), and the possibility to combine with a fixed (200pips
fixed TP but close on opposite signal, for example).
What do you think Damien?
===== PAGE 15/24 =====
S.2
S.2
S.2
S.2
S.2
MickeyMar
Quoting rare
 Disliked
Hey Mickey do you have to monitor the trades or can you open the trade at start of London session
for example and close at NY close??
interesting thought!
I have always monitored, because I've used discretion. But with an EA, we won't have to. However, it would be nice
to know what would happen if we traded the system the way you suggest... like: open a trade on the current active
signal and just follow from there all the way until time "x" (end of session), when all would be closed.
The EA could maybe have an option "open trade immediately", which would make the EA take a trade in the
direction of the current active signal, without waiting for a new one or a reconfirmation, as it does now. But probably
i'd still prefer the "entry at signal" option, because a good entry is essential for the system to work well (its money
management depends on an entry close to the channel).
Marc82Much
I reset my balance in my Paper Trade account to $49,653.64. I added three new charts, all 15M...USDJPY,
EURUSD, and GBPUSD. These are the three Mickey mentions as his favorites right now. I have all three charts on
AutoTrading. It is now 11:07 AM EST (Chicago Time). Just like fishing with a tilt up...I'm gonna go to lunch and when
I come back, maybe I caught something!
wifiguy
Hi Mickey,
Great way of escaping ranging market conditions. What is the reason for the EMA? A LWMA gives an earlier entry.
MickeyMar
Quoting wifiguy
 Disliked
Hi Mickey, Great way of escaping ranging market conditions. What is the reason for the EMA? A
LWMA gives an earlier entry.
The reason has to do with what you just mentioned - escaping ranging markets. If we enter too quickly we may be
too early, or not escape a choppy period. My main objective was to keep the system COMPLETELY OUT when the
pair I trade is being choppy
The EA works, but the entries do not wait for the candle close (first fix we need to do) and the EA takes
reconfirmation signals (we need to keep this as an option, but add a filter to only trade FIRST signals, which is the
core strategy).
Can't wait to see a delayed entry in real time, I'm excited
stubish
I just applied the template to a few markets on Global prime M15 charts. Looks GREAT! I like that it's simple. I had
to fight the urge to put a few more confirmations in there and just let the cross speak for itself.
Thanks so much for sharing. I'm subscribed and will add value when I can
===== PAGE 16/24 =====
S.2
S.2
S.3
S.3
MickeyMar
Quoting stubish
 Disliked
I just applied the template to a few markets on Global prime M15 charts. Looks GREAT! I like that it's
simple. I had to fight the urge to put a few more confirmations in there and just let the cross speak for
itself. Thanks so much for sharing. I'm subscribed and will add value when I can
yea, I know what you're saying... I thought of a thousand additional filters myself but in the end, the simplicity is its
advantage. One filter only I found to be worth while and making results more "stable" in the mid-term and long-term:
taking only the signals confirmed by the H1 system as well, which means you would take on M15 ALL there is in the
same direction as the H1 cross, and ignore the rest. But I'd rather not insist on this filter yet, we will have time to
explore it later.
kleybenny
Quoting MickeyMar
 Disliked
About Me I have been trading for 12 years now, and for most of this time I've made my living from the
market, or from market-related business. I have traded many systems, of mine and of others, with
various levels of success. For about 4 years I have settled on this system, which fits my financial
objectives, my trading style and my psychological profile. I have consistently been successful trading
it, and for years I felt no need to try any other on my live accounts. I have decided to make the step
towards sharing and discussing it, for 2 reasons:...
Thank you very much Mickey for this great strategy. I have another strategy which I use every day with good
success, but your strategy I a good addition for me to filter my trades and to find the point, where I have to close my
trade... Thank you for that! Good job!!!
iffikhan
Quoting forexbandit7
 Disliked
{quote} ill wait for a retrenchment of the price on 5M and i dont sell or buy with market order,i always
go with pending sell/buy, this my way of entering the trade , nothing to do with the original method
Hi can you please share your template .Thanks
aaven
Quoting MickeyMar
 Disliked
{quote} yea, I know what you're saying... I thought of a thousand additional filters myself but in the
end, the simplicity is its advantage. One filter only I found to be worth while and making results more
"stable" in the mid-term and long-term: taking only the signals confirmed by the H1 system as well,
which means you would take on M15 ALL there is in the same direction as the H1 cross, and ignore
the rest. But I'd rather not insist on this filter yet, we will have time to explore it later.
Thanks Mickey. Really wonderful on your part to share your work so generously...
On 15 Minutes Time Frame, there are arrows that correspond to the Buy and Sell signals.
===== PAGE 17/24 =====
S.3
S.3
S.3
Could you please incorporate the same/arrows for other time frames like 1HR,4HR etc...
Thanks
kaiser soze
i'm already GU short....would this setup still be a valid "re-entry" off the trend line???
Attached Image (click to enlarge)
Sidric
I like this system for avoiding choppy markets, here is my simple contribution to this thread. An arrow indicator for
any time-frame... no alerts though.. i personally don't like them
Attached Image (click to enlarge)
Attached File(s)
channel MA cross.mq4   3 KB | 703 downloads
srcs76
===== PAGE 18/24 =====
S.3
S.3
S.3
Nice Setup, thank you MickeyMar
Attached Image (click to enlarge)
Torontoman
Thank you, Mickeymar. Subscribed
forexbandit7
Quoting iffikhan
 Disliked
{quote} Hi can you please share your template .Thanks
Here it goes for you buddy.
Attached File(s)
adr1.ex4   27 KB | 600 downloads
adr1.mq4   18 KB | 683 downloads
large display.ex4   7 KB | 635 downloads
large display.mq4   2 KB | 644 downloads
LFL-ATRprojections.ex4   6 KB | 673 downloads
MA Short-Term System.tpl   80 KB | 673 downloads
pipsometer_5_decimal.ex4   15 KB | 620 downloads
pipsometer_5_decimal.mq4   5 KB | 632 downloads
iffikhan
Quoting forexbandit7
 Disliked
===== PAGE 19/24 =====
S.3
S.3
{quote} Here it goes for you buddy. {file} {file} {file} {file} {file} {file} {file} {file}
Thanks alot !
diamonddbw
MM, after staring at your chart set up for hours, I noticed a repeating set up within the set up.
Once the 33 enters the channel, I watch for Price to close on the opposite side of channel. Then I wait for price to
retrace to within 3 pips of 33, and enter there, with a 20-25 pip SL, depending on spread & overall market
conditions.
In my overall observations, price tends to rarely travel less than 20 pips in desired direction. Also, this entry is
usually 15 to 25 pips sooner than following basic entry. Screenshot is of EurAud on April 20, this year.
It's not my intention to highjack this thread. I hope this may simply add to it.
Attached Image (click to enlarge)
MickeyMar
Aaven: on my template (shared in the first post) all you need to do is right click BOTH a red AND a green arrow, and
under "visualization" check all timeframes, and it will appear. I simply didn't want signals on all TF, that's why I
removed them.
Or I think Sedric's posted indicator is already set for all timeframes, so you can use that instead. mine is actually an
improvisation
But guys, make sure you take only signals PRINTED on the chart, where the crossover happened - do not trade
signals on candles not yet closed, cuz you will experience a lot of bad entries.
Kaiser: yea, you got it right. The move on GU was clearly bear, but the system will have you wait for an entry close
to the channel, simply for risk management purposes. If you look at my GU chart from yesterday, you will see that
the original re-entry order would have been higher, but since the MAs traveled lower, the entry was possible lower,
after a few hours passed. It's important I think that the EA take into account the position of the signal MA (33) and
enter once price hits it, anywhere that might be, as opposed to placing an order immediately at the level of the
33EMA at the moment of the delayed signal. Because the order may never get filled that way, or if it does it may be
at a weird, very high level where we would no longer be interested to take it.
===== PAGE 20/24 =====
S.3
S.3
Diamond: thanks for your contribution. I will not alter the setup or enter other filters for now, because it would be the
beginning of a whole new learning curve for me But in time, once we get this system running on EA with optimal
settings and make a minimum of 500pips monthly (same as I usually make trading manually) I'll be more than
willing to try out refinements like the one you proposed.
I am currently trying out the EA on all pairs, and take notes. We need to make adjustments &add some filters, but
it's a very good start. Also, I am yet to see a delayed entry (these are very good, actually, as they happen within
strong moves, in the direction of the move, at a good enough level). I will post all observations in one single post,
once done, so as not to spam the thread.
MickeyMar
since several guys asked, I give one more example of a perfect delayed entry from yesterday (didn't take it myself,
but the EA would have caught it). Of course, not all will work like this:
Attached Image (click to enlarge)
forexbandit7
GA from yesterday and today one more entry
Attached Image (click to enlarge)
===== PAGE 21/24 =====
S.3
S.3
S.3
damiend
Quoting MickeyMar
 Disliked
The EA should have one very important feature, without which the results would be a total mess (I
don't know if the current EA has it, because i can't see the code): the signals should be considered
valid only if they are PRINTED on the chart, meaning only AFTER THE M15 CANDLE CLOSE. Many
times the indicator i have gives a signal, only to dissapear at the close of the candle (because price
goes back before candle close and the signal MA pulls back as well, invalidating the signal). Also, an
option "no tp, close at opposite signal" (and reverse),...
Yes you are right, I used candles 1 and 0 (actual one) for the cross. I will change it to use candles 2 and 1 to ensure
we get the signal when candle 1 is closed.
For the TP, yep we could combine a fixed TP and a close at opposite signal option, and use both together or one
only. That would be interesting to backtest and see which combination has the best performance. I will add that too.
damiend
Quoting MickeyMar
 Disliked
{quote} the EA takes reconfirmation signals (we need to keep this as an option, but add a filter to only
trade FIRST signals, which is the core strategy)
Could you annotate a chart showing that? I'm not sure to understand what you mean by reconfirmation signals and
first signals...
Thanks
forexdaist
Hey Mickey,
Following your system I am overflowed for the amount of signals I see today. Could you post the list of pairs you use
to watch?
===== PAGE 22/24 =====
S.3
S.3
S.3
Another doubt. In case you take a trade and the other side of the channel it's just, let's say, 18pips, do you fix there
the SL or do you still fix a 40 pips SL?
thank you
Toni
diamonddbw
This UsdChf signal happened 15 minutes ago.
Attached Image (click to enlarge)
aaven
Quoting MickeyMar
 Disliked
Aaven: on my template (shared in the first post) all you need to do is right click BOTH a red AND a
green arrow, and under "visualization" check all timeframes, and it will appear. I simply didn't want
signals on all TF, that's why I removed them. Or I think Sedric's posted indicator is already set for all
timeframes, so you can use that instead. mine is actually an improvisation But guys, make sure you
take only signals PRINTED on the chart, where the crossover happened - do not trade signals on
candles not yet closed, cuz you will experience...
Thanks Mickey for taking the time in addressing my need. Much appreciated...
fotolia
Quoting MickeyMar
 Disliked
Please share your testing and let's make some pips together!
There are no words to describe my gratitude Mickey! Your system is another evidence of theory that everything
genial is simple! :-)
I personally can see 4 clear signals to enter on the chart USDJPY. I missed second signal, so entered after third one
===== PAGE 23/24 =====
S.3
S.3
(shown on screenshot).
Decided to close it manually because of possible pull-back movement, resistance level ahead + ADR was about 100% already.. greed is healthy but it
has ability to kill)))
Result for today +50pips (R/R = 1/2.5)
Attached Image (click to enlarge)
Joseph95
Where can we find a good programmer for this? I'm looking the charts and it looks good!
MickeyMar
Quoting forexdaist
 Disliked
Hey Mickey, Following your system I am overflowed for the amount of signals I see today. Could you
post the list of pairs you use to watch? Another doubt. In case you take a trade and the other side of
the channel it's just, let's say, 18pips, do you fix there the SL or do you still fix a 40 pips SL? thank you
Toni
Excellent question. No hard stop is ever perfect... Actually, if you can trade the system manually, it's ideal to reduce
the stop if you can. If you can place a stop of, say, 35pips or 30pips, and still be safe (stop beyond the channel,
maybe even above a swing high/low), then it's fine, you should do it. The most important thing is to never let the
stop exceed 50pips.
Forexdaist - you can use any pair you want, but not all will perform equally well, and it's possible the pair you
choose to have a bad period right when you start. Patience is needed, as always in trading. I like the majors
because i have a smaller spread on them, i usually don't like the CAD pairs because they make frequent sudden
large moves against the trend - but I've seen cad pairs giving hundreds of pips on the system... so you never know,
it's all about personal preference and patience. This is why i want to automate and spread over many pairs, to be
able to compensate losses between pairs and benefit from more rallies.
For starters, I'd choose a pair I know at first, and go from there.
Fotolia: you illustrate very well my approach, of keeping in mind your own criteria when you trade, and take profit
when you have it, if the profits are reasonable and if the charts are showing you signs of trend exhaustion. 50pips
with a risk of 40 is still not bad, and besides you can always go back in at the next pullback to the channel
===== PAGE 24/24 =====
Damiend: thanks for your patience and effort in helping us all with the EA.
First signal: a signal that changes the direction of the trend, the first BUY signal after a SELL or a series of SELL
signals, or the first SELL signal after a BUY or a series of BUY signals.
Reconfirmation: a signal of the same kind as the previous one: BUY when the previous signal was also BUY, or
SELL if the previous signal was a SELL.
Would be great if the EA could have 2 options:
1) to only enter ONE position, on the First signal, and then ignore the next signals of the same kind (so as not to
have a too large exposure in that trend), or
2) enter ALL SIGNALS, as they come, regardless of whether there is an open trade in the same direction or not.
Hope this clarifies this issue. Here's a picture:
Attached Image (click to enlarge)
Here's what I have now on my demo with the EA activated, all pairs except exotics:
Attached Image (click to enlarge)
```
