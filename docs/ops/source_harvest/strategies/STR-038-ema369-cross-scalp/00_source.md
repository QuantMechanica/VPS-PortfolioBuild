# STR-038-ema369-cross-scalp — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/5 =====
S.1
S.1
S.1
3,6,9 EMA system
ForexFactory Thread 252779 — 17 Beiträge, KOMPLETT (1 Seite(n))
jaws810
OK, everybody around here likes to use PA to predict market movement but they use methods that are so dang
complicated I feel like I'm looking at a game of pick up sticks when I see their charts. So I have been attempting to
build a simple system that could be used on a lower TFs and that anyone could understand. I like to apply the
K.I.S.S(Keep It Simple Stupid) method to everything I do so I developed a EMA crossover system that is accurate
and simple. Now since I am using a short 5M TF I will be looking for only 10 pips per trade which is about 2.5%
profit on each trade using 50:1 leverage. This system will work on any TF except 1m and any currency pair but I
have no need to do long term trades so I'm concentrating on short term scalping on 5mTF at the moment.
OK, if you haven't figured out what I'm doing it's really simple just set up 3 EMAs one at 3 one at 6 and one at 9
then the EMA3 is the signal when it crosses to the top of both the EMA6&9 it's a buy signal, when it crosses to the
bottom of both it's a sell signal. I plan on using a 20 pip SL in case of technical issues but I'll use the EMA3 cross to
close most losing trades and a TP set to 2.5% of my balance to close the profitable trades. All trades are made after
the close of the candle where the cross occurred. OANDA is my broker and TP could be set in %of balance, %of
price or in pips which is a nice feature.
So what do the experts thing of this idea. (not tested yet but it looks nice on the charts)
Live Testing begins tomorrow, I have a very small account not much risk involved.
finally
Quoting jaws810
 Disliked
OK, everybody around here likes to use PA to predict market movement but they use methods that
are so dang complicated I feel like I'm looking at a game of pick up sticks when I see their charts. So I
have been attempting to build a simple system that could be used on a lower TFs and that anyone
could understand. I like to apply the K.I.S.S(Keep It Simple Stupid) method to everything I do so I
developed a EMA crossover system that is accurate and simple. Now since I am using a short 5M TF
I will be looking for only 10 pips per trade which is about...
It's an interesting idea but you'll get destroyed in ranging markets.
Perhaps there is a way to filter out these ranging periods.
jaws810
Here is a screen shot of the last 12 hrs all but 2 were winners. The 1st and the 5th entries are the only losers, all the
rest would have reached the TP.
It might have issues with a ranging market depending on how tight the range is, I could trade a 50 pip range all day
maybe as low as 30 but any lower than that I would definitely have problems unless I let the trades run till they hit
the SL or TP then it would depend on ratio of wins to losses.
Attached Image (click to enlarge)
===== PAGE 2/5 =====
S.1
S.1
S.1
finally
Quoting jaws810
 Disliked
Here is a screen shot of the last 12 hrs all but 2 were winners. The 1st and the 5th entries are the only
losers, all the rest would have reached the TP.
It might have issues with a ranging market depending on how tight the range is, I could trade a 50 pip
range all day maybe as low as 30 but any lower than that I would definitely have problems unless I let
the trades run till they hit the SL or TP then it would depend on ratio of wins to losses.
Are you using a 10 TP and a 20 Pip SL- or do you let the 3 ema cross both the 6 and the 9 to take you out of
losers?
jaws810
Quoting finally
 Disliked
Are you using a 10 TP and a 20 Pip SL- or do you let the 3 ema cross both the 6 and the 9 to take you
out of losers?
I set a 20 sl in case of internet, power or computer failure but most of the losers are taken out when the EMA
crosses both the 6 and 9 in the opposite direction of the trade. The TP is approximately 10pips but the actual TP is
2.5% of my account balance.
ramyalexis
To clarify a little bit...
You are lokking for a cross of 3 and 6 ema, when it happens up from 9 ema you go long(of course 3x6 cross should
===== PAGE 3/5 =====
S.1
S.1
S.1
S.1
S.1
be BULL cross) and opposite for short.
Right ?
eagle4x
Unless you have filter for whipsaws, you will eventually blow your account using 5m with only EMA crossovers. Also
better to use higher time frames to get your 10p, as the higher the time frame, the less whipsaws there are.
Bobcat2
Quoting eagle4x
 Disliked
Unless you have filter for whipsaws, you will eventually blow your account using 5m with only EMA
crossovers. Also better to use higher time frames to get your 10p, as the higher the time frame, the
less whipsaws there are.
A very simple but effective filter is to simply not take any trade signals where the 3,6,9 ema's are all bunched
together. Wait for some separation between the ema's before you hit that trade button.
Andy B
Quoting Bobcat2
 Disliked
A very simple but effective filter is to simply not take any trade signals where the 3,6,9 ema's are all
bunched together. Wait for some separation between the ema's before you hit that trade button.
Agreed.
Or look at the 15M or 30M timeframe before drilling down to the 5M. If there is good separation of the ema's on the
higher timeframe then waiting for a retrace on the lower timeframe and a re-cross would remove a good many
whipsaws.
Of course it would remove some profitable trades too, detailed backtesting would be needed to determine whether
this kind of filter was effective in the long-run.
golden1
Use ADX/ATR and I use this simple indicator...first best trades
ie highest prob higher time frame has same direction
separation and second current tf ie 5 has ma's nicely spread...
but then if this indicator shows you what you should see anyway
that price action is too anemic to be trading, it will eliminate
a ton of bad trades to not take those signals.
Brian
Attached File(s)
xADR_0.2_v.CL.mq4   4 KB | 1,044 downloads
golden1
Sorry but just one more..you can either use macd or rsi divergence
indicator and if you are going long, is the macd signal line above the
===== PAGE 4/5 =====
S.1
S.1
S.1
ma line and also the histogram higher than previous swing high level?
or if rsi divergence indicator then same is rsi green higher than previous
rsi divergence on swing high??
All the best
Brian
goldsurfer
Quoting golden1
 Disliked
Use ADX/ATR and I use this simple indicator...first best trades
ie highest prob higher time frame has same direction
separation and second current tf ie 5 has ma's nicely spread...
but then if this indicator shows you what you should see anyway
that price action is too anemic to be trading, it will eliminate
a ton of bad trades to not take those signals.
Brian
Hey Brian
How do you like to set your two periods?
Cheers
golden1
Hey man, how are things going G?
Usually on the M5 I use 6/36
and I do pay attention to the room to move
setting as well, ie room up/room down
that really can be helpful at times too. FYI
Brian
PS: For those who want to check the macd I
prefer 8/17/9 on m5 for confirmation
Quoting goldsurfer
 Disliked
Hey Brian
How do you like to set your two periods?
Cheers
goldsurfer
===== PAGE 5/5 =====
S.1
S.1
S.1
Quoting golden1
 Disliked
Hey man, how are things going G?
Usually on the M5 I use 6/36
and I do pay attention to the room to move
setting as well, ie room up/room down
that really can be helpful at times too. FYI
Brian
Shoot me an e and we'll compare our current setups if you like
cheers all
TheGreatMilenko
Quoting jaws810
 Disliked
OK, everybody around here likes to use PA to predict market movement but they use methods that
are so dang complicated I feel like I'm looking at a game of pick up sticks when I see their charts. So I
have been attempting to build a simple system that could be used on a lower TFs and that anyone
could understand. I like to apply the K.I.S.S(Keep It Simple Stupid) method to everything I do so I
developed a EMA crossover system that is accurate and simple. Now since I am using a short 5M TF
I will be looking for only 10 pips per trade which is about...
Why do you need the 6ema?
thisrussell
so i randomly put in 3, 6, and 9 emas based of an idea i had reff to Nikolia Tesla theory and connecting it with the
energy / expansion/ crossing of the EMA and just let it run while i did my normal trading, as i dont know shit about
ema's. went back and notice correlations but not sure how excatly these are suppose to work. can any one help
thanks
goodways100
Have you ever come across a Triple ema ea that trades exactly at the cross. Thanks and
Regards```
