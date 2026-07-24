# STR-066-mtf-rsi50-alignment — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/18 =====
S.1
S.1
MTF RSI Trading System
ForexFactory Thread 504229 — 60 Beiträge, Eröffnung: erste 3 Seiten
txfxtrader
Here's a MTF RSI trading system that I would like to share with you.
1. Indicator: Hitman (manual attached) or Dashboard RSI
2. Setting: 2 or 3 with 50 oversold & overbought
3. Timeframe: D1 (optional), H4, H1, M30, M15, M5, M1
4. TP: 30 or trader discretion
5. SL: 20 or trader discretion
6. MM: Trader discretion
7. Pairs: All with < 4 pip spread & 5 day ADR > 60 pips
8. Long: All RSI bars are blue.
9. Short: All RSI are red.
10. Optional: Close all open trades at the end of the session(s) you are trading and start the new trading day.
Disclaimer: What works today may not work tomorrow so trade at your own risk.
Special thanks to the coders: Groenie & Nonor
Attached Image (click to enlarge)
Attached File(s)
Hitman.ex4   57 KB | 7,396 downloads | Uploaded Sep 23, 2014 11:27pm
Hitman-Dark.tpl   14 KB | 4,439 downloads | Uploaded Sep 23, 2014 11:27pm
Hitman-Light.tpl   14 KB | 3,759 downloads | Uploaded Sep 23, 2014 11:28pm
User Manual.pdf   271 KB | 8,569 downloads | Uploaded Sep 23, 2014 11:28pm
MAM.Trader
it might work or not
but simple & smart approach GL
Quoting txfxtrader
 Disliked
===== PAGE 2/18 =====
S.1
S.1
S.1
S.1
S.1
S.1
I have been trading a MTF RSI trading system that I would like to share on the forum. I mostly trade
the US session. 1. Indicator: RSI MTF previous bar 2. Setting: 55 period with 50 oversold &
overbought (programmed into the indicator) 3. Timeframe: H1, M30, M15, M5, M1 4. TP: 20 - 30
(trader discretion) 5. SL: 20 6. MM: modified progressive with a limit of 5 entries (ex: .1, .1, .2, .4, .8 =
total of 1.6) = ~2% cumulative loss for each pair series. Start a new series if a win or max lot size is a
loss. 7. Pairs: All with < 3 pip spread & 5 day...
txfxtrader
08/07/14 - 08/12/14
p/l: +$839
wqking
Hi, do you have the source code of the indicator MTF RSI? Or can you explain how it works?
Thanks
FerruFx
Quoting wqking
 Disliked
Hi, do you have the source code of the indicator MTF RSI? Or can you explain how it works? Thanks
It is explained in the first post.
Each TF displays its own last closed candle direction.
wqking
Quoting FerruFx
 Disliked
{quote} It is explained in the first post. Each TF displays its own last closed candle direction.
Yeah but I need the exact algorithm so I can code the indicator myself.So I guess, on each time frame, if RSI at bar
1 > bar2, shows green, otherwise, red?
Anusragger
Quoting txfxtrader
 Disliked
1. Indicator: RSI MTF previous bar
Last bar of the indicated timeframe by the indy or last bar of the current timeframe of the open chart?
FerruFx
Quoting wqking
 Disliked
{quote} Yeah but I need the exact algorithm so I can code the indicator myself.So I guess, on each
time frame, if RSI at bar 1 > bar2, shows green, otherwise, red?
===== PAGE 3/18 =====
S.1
S.1
S.1
Why don't you read post #1 ? You have all you need.
BTW your guess is wrong.
txfxtrader
FerruFx is correct. "Each TF displays its own last closed candle direction". Please post your results if you guys
decide to give it try.
laksior
Hi, could someone explain to me point #6 because I don't understand this thing about 5 entries. I'm a little newbie
nonor
Hello
As your system seem interesting, I modify an existing dashboard in order to get a view of the RSI(55) level
for a list of symbol, the list could be extended in the code...
I check for some symbol, it seems to works.
Attached Image (click to enlarge)
Attached File(s)
dashboardRSI55.mq4   5 KB | 4,756 downloads
===== PAGE 4/18 =====
S.1
S.1
S.1
S.1
S.1
txfxtrader
Quoting nonor
 Disliked
Hello As your system seem interesting, I modify an existing dashboard in order to get a view of the
RSI(55) level for a list of symbol, the list could be extended in the code... I check for some symbol, it
seems to works. {file} {image}
Thank you nonor. Does it display the color for the last closed candle for each time frame? Not much trading action
today.
nonor
Hello
Yes, it follow the same logic as your RSI_MTF previous.ex4
it is not the current candle, but the last closed one.
Some improvements could be : add two columns with the ADR and the spread, then sort the currencies from all
green, at top, to all red at bottom....
wiseguytrade
Hi Nonor,
It seems like a great dashboard for this system. My question is, since it takes up so much viewing real estate, how
can I reduce and be able to see all of the pairs on the screen since there is no way to scroll down on MT4. Yes, I
know I can shrink the price structure on the right of the screen, but it appears that there are more pairs that I can't
view. Thanks for whatever you can recommend.
Wiseguy
nonor
Hello
first point : How do you get all pair ?, there is no data structure in mt4 wich contains all the symbols provided by the
broker, we have to test each symbol with
MarketInfo function to get a price for the symbol and then fill an array with valid pair.., as stated in this old but
always valid post :
http://www.forexfactory.com/showthread.php?t=127613
second point : the consequence of the first point is that we don't know at execution level, how many pair we have to
deal with, so for the display,
we don't know the number of line wich will be present...the elegant solution will be a graphical windows, with vertical
scroll bar, I know it exist in mt5 :
http://www.mql5.com/en/articles/751
but don't know in mt4.
the quick solution is to hard code the pair list and reduce the size of the block and font, and try to display the
maximum of lines.....
dumplin_eater
===== PAGE 5/18 =====
S.1
S.1
S.1
S.1
S.2
Hi txfxtrader, Is there anyway to back test your system? Also if you don't mind me asking, what have your results
been like??
txfxtrader
Quoting dumplin_eater
 Disliked
Hi txfxtrader, Is there anyway to back test your system? Also if you don't mind me asking, what have
your results been like??
ROI for the month has been ~10% with less than that for the DD. This was all trend trading without any counter
trend trades. Today is a negative day. Getting ready to close all open positions and hit it tomorrow. I don't have any
experience back testing a MTF system.
txfxtrader
Nonor...can you please add the 4HR to the dashboard? It would help filter days like today. Thank you
nonor
please, find attached below
Attached File(s)
dashboardRSI55.mq4   5 KB | 2,816 downloads
nsn14
Thanks txfxtrader for the idea and sharing.
However, can you share how do you decide the entries?
Which TF are you in when you do entries?
What signal or method use?
Thanks!
nonor
Hi Wiseguytrade
find attached below an extensive version of the dashboard, difficult to read, but could display more then 70 pairs, I
include some metals and oil...
sorted by pair name ascending...
Attached Image (click to enlarge)
===== PAGE 6/18 =====
Attached File(s)
dashboardRSI55_dev.mq4   18 KB | 1,882 downloads
===== PAGE 7/18 =====
S.2
S.2
S.2
S.2
txfxtrader
I added the H4 to the rules & indicator with a new period setting. This should help filter the noise that we saw
yesterday. Thank you to the programmers that are supporting this thread.
txfxtrader
Quoting nsn14
 Disliked
Thanks txfxtrader for the idea and sharing. However, can you share how do you decide the entries?
Which TF are you in when you do entries? What signal or method use? Thanks!
Trading per the rules in the 1st post. Made modifications this morning to help filter the noise.
txfxtrader
.
txfxtrader
Nonor or FerruFx,
Can you please check the MQ4 version of the MTF RSI previous indicator? H4 on the GBPJPY just switched from
red to green with 2 hours to go. This should have stayed red (previous close).
The 1st image is current.
The 2nd image should be what it looks like.
Thanks,
txfxtrader
Attached Image(s) (click to enlarge)
===== PAGE 8/18 =====
S.2
S.2
Attached File(s)
RSI_MTF previous.mq4   4 KB | 2,501 downloads
txfxtrader
Quoting txfxtrader
 Disliked
Nonor or FerruFx, Can you please check the MQ4 version of the MTF RSI previous indicator? H4 on
the GBPJPY just switched from red to green with 2 hours to go. This should have stayed red (previous
close). The 1st image is current. The 2nd image should be what it looks like. Thanks, txfxtrader {file}
{image} {image}
Problem has been corrected by the programmer. Indicator uploaded to the 1st post.
nonor
===== PAGE 9/18 =====
S.2
S.2
S.2
S.2
S.2
S.2
The first release of the two dashboards have refresh problem, find below more usable two,
I continue development of these tools as I need it for my trading, perhaps in plateform tech forum...
The load of the dev version take one minute or more, but after loading, it is usable, the refresh
occur each minute.
Attached File(s)
dashboardRSI55_dev.mq4   17 KB | 1,816 downloads
dashboardRSI55.mq4   5 KB | 1,873 downloads
nonor
Hello txfxtrader
You don't trade your system ?
we will be pleased to see some trade,
I'm working on an improved version of the dashboard, I believe in the RSI indi, my own system is based on this
indicator.
txfxtrader
9/16/14 - 9/19/14
P/L: +$195
The indicator was fixed on the 9/16 so I did not include the previous day.
I am going to include the daily as well and increase the stop & take profit to 30 & 60.
profitmonit
Please - some screenshots
txfxtrader
Quoting profitmonit
 Disliked
Please - some screenshots
See 1st post. New indicator uploaded with alarm & screenshot.
nonor
The indi of Groenie is nice, some remarks :
-what is the mining of SLOPE ?, what are the numbers below each block ?
-it would be nice if we can increase the font size for adr and spread, it is very small...
Very inspiring
Thank yu
Groenie
Quoting nonor
 Disliked
The indi of Groenie is nice, some remarks : -what is the mining of SLOPE ?, what are the numbers
below each block ? -it would be nice if we can increase the font size for adr and spread, it is very
===== PAGE 10/18 =====
S.2
S.2
S.2
small... Very inspiring Thank yu
I'm glad you like it, the font size will be bigger in the next update for the indi soon. I will also release a user manual
with the next update that explains each of the options.
The slope is the arrows underneath the RSI blocks and indicate if the RSI is currently sloping up or down or flat, the
next version will give you the option to choose if you want the current slope or the previous bar slope.
The numbers below each block shows the numerical value of the previous RSI block for you to easily see where a
normal RSI line would lie. It changes slightly in color when the value is below 30 or above 70 indicating
overbought/sold levels
frani60
thanks for your great work tip top
Groenie
Some screenshots of the new indicator on both a light and dark template, one even has an open trade. TxFxTrader
will include everything in the first post soon
Attached Image(s) (click to enlarge)
fguru
===== PAGE 11/18 =====
S.2
Great indicator! I trade a similar RSI (3) system and will add your indicator. Thanks again.
Would it be possible that we choose the time frame ourselves? I would prefer to also see the weekly time frame and
don't need the 1M time frame. Thanks!
fguru
I think there is a problem with some time frames. For example I just checked the H1 chart of GBP/USD and the last
closed candle is bearish but the indicator says it's bullish. Same with EUR/USD D1 chart. The last closed daily
candle is bullish, but indicator says its bearish.
Attached Image (click to enlarge)
Attached Image (click to enlarge)
===== PAGE 12/18 =====
S.2
S.2
S.2
Groenie
Quoting fguru
 Disliked
I think there is a problem with some time frames. For example I just checked the H1 chart of
GBP/USD and the last closed candle is bearish but the indicator says it's bullish. Same with
EUR/USD D1 chart. The last closed daily candle is bullish, but indicator says its bearish. {image}
{image}
fguru, the signal bars only check if RSI is above/below the 50 line. Basically 50+ is the overbought level and -50 is
the oversold level according to txfxtrader's rules.
The little arrow you see on top of the bar shows the current bar's slope and the number next to it is the numerical
value of the previous RSI
fguru
Thanks for clearing that up, Groenie.
Groenie
Quoting fguru
 Disliked
Great indicator! I trade a similar RSI (3) system and will add your indicator. Thanks again. Would it be
possible that we choose the time frame ourselves? I would prefer to also see the weekly time frame
and don't need the 1M time frame. Thanks!
===== PAGE 13/18 =====
S.3
S.3
S.3
fguru, the next version (v1.2) has the option to choose each individual timeframe and RSI period. It seems txfxtrader
may be busy at the moment so I'll upload the new version here and he can upload it to the first post when he has
time
Also you have an interesting indicator there yourself, would it be possible for you to upload it (with or without source
code) for some inspection?
Indicator has been renamed to Hitman, because I can
The user manual explains all the indicator options, if some of the options don't make sense, just view the PDF
2 Templates (as seen in the screenshots above) are also in the zip file
Attached File(s)
Hitmanv1.2.zip   357 KB | 3,094 downloads
Groenie
Quoting fguru
 Disliked
Thanks for clearing that up, Groenie.
fguru
Thanks for uploading the new version of the indicator.
I have one question: Shouldn't there be a difference when I switch between "Show_Bar_Close" false and true?
Because all the colors and numbers remain the same, doesn't matter if I choose false or true. I thought if I choose
false then the indicator would show me the RSI reading of the current candle?
Quoting Groenie
 Disliked
{quote} Also you have an interesting indicator there yourself, would it be possible for you to upload it
(with or without source code) for some inspection?{file}
Since I don't know which indicator you meant, I am attaching both.
The ALL RSI v1.0 indicator is the one at the bottom window of my screen. You can choose your favorite time frames
and it will display them side by side.
The other indicator (CapitoIntraday) is on the right top corner of my screen. The arrows are blue/point up when the
RSI (3) direction of the current candle is up and they point down/turn red when the RSI direction of the current
candle is down. The RSI numbers are also displayed. Unfortunately I do not have the source code.
Attached File(s)
All RSI v1.0.mq4   9 KB | 2,154 downloads
CapitoIntraday.ex4   14 KB | 1,734 downloads
Groenie
Quoting fguru
 Disliked
Thanks for uploading the new version of the indicator. I have one question: Shouldn't there be a
difference when I switch between "Show_Bar_Close" false and true? Because all the colors and
numbers remain the same, doesn't matter if I choose false or true. I thought if I choose false then the
===== PAGE 14/18 =====
S.3
S.3
indicator would show me the RSI reading of the current candle? {quote} Since I don't know which
indicator you meant, I am attaching both. The ALL RSI v1.0 indicator is the one at the bottom window
of my screen. You can choose your favorite time frames...
I should rename that variable... my mistake
Show_Bar_Close enables/disables the counter that shows the time until the current bar closes (check out the user
manual if some of the options are unclear)
The indicator does not give you the option to choose between the current and previous RSI bars because
txfxtrader's strategy works only with the previous bar. I will send you a pm concerning the current bar closes though.
Also, thanks for the indicators, I was meaning the All_RSI one that displays the mini RSI lines in the indicator
window. I'd like to have that display all 7 timeframes if possible so I'm glad you have the source.
Attached Image
fguru
I understand, ok that was me thinking wrong then.
Yes, you can see all time frames you want with the ALL RSI indicator. See attached image.
I will check out your manual now.
Attached Image (click to enlarge)
Groenie
===== PAGE 15/18 =====
S.3
S.3
S.3
S.3
Quoting fguru
 Disliked
I understand, ok that was me thinking wrong then. Yes, you can see all time frames you want with the
ALL RSI indicator. See attached image. I will check out your manual now. {image}
That is perfect, it will give a nice overview of everything, I love it
From your screenshot I also see a visual issue with the little speaker icon, I'll fix that in the next update
Groenie
RSI Mini Charts indicator is now B600 ready, which means it will work on the newer versions of MT4.
Attached Image (click to enlarge)
Attached File(s)
All RSI v1.1.ex4   19 KB | 2,025 downloads
All RSI v1.1.mq4   11 KB | 2,614 downloads
fguru
That's great Groenie.
Good luck with the EU trade, I saw it too. I entered CAD/JPY recently, but I must admit on demo only.
Groenie
Quoting fguru
 Disliked
That's great Groenie. Good luck with the EU trade, I saw it too. I entered CAD/JPY recently, but I must
admit on demo only.
Thanks fguru I try to stay away for the JPY's myself specially with the small SL but the UJ can be so tempting
fguru
Here is the chart. I trade the JPYs mostly in the Asian time.
Attached Image (click to enlarge)
===== PAGE 16/18 =====
S.3
S.3
S.3
S.3
Groenie
Quoting fguru
 Disliked
Here is the chart. I trade the JPYs mostly in the Asian time. {image}
That is looking very nice, I think I will give the asian session a go on the demo
fguru
Your trade is looking good Groenie.
I closed mine with only little profit (almost break even) after I saw that it went against me. But it would have been
good for 27 pips, oh well.
Edit: Actually it went down 43 pips.
Groenie
Quoting fguru
 Disliked
Your trade is looking good Groenie. I closed mine with only little profit (almost break even) after I saw
that it went against me. But it would have been good for 27 pips, oh well.
Thanks fguru, I have opposite trades open on both the USDCHF and USDCAD with both close to TP as well. I
wonder if a trade manager EA with jump stops will help minimizing the losses after breakeven when price turns
against us. I think a 15pip jump stop would be ok.
Groenie
2 Losses: 40pips
3 Wins: 90pips
Small lot sizes still but I'm up 50 pips for today so far
===== PAGE 17/18 =====
S.3
S.3
S.3
S.3
S.3
Attached Image (click to enlarge)
fguru
Quoting Groenie
 Disliked
2 Losses: 40pips 3 Wins: 90pips Small lot sizes still but I'm up 50 pips for today so far {image}
That is awesome Groenie!
I missed the USD/CAD, would have been a very nice trade.
txfxtrader
Quoting Groenie
 Disliked
2 Losses: 40pips 3 Wins: 90pips Small lot sizes still but I'm up 50 pips for today so far {image}
Good job buddy!
nsn14
Quoting txfxtrader
 Disliked
I have been trading a MTF RSI trading system that I would like to share on the forum. Trend trading:
1. Indicator: Hitman (manual attached) or Dashboard RSI 2. Setting: 2 period with 50 oversold &
overbought 3. Timeframe: D1, H4, H1, M30, M15, M5, M1 4. TP: 30 or user discretion 5. SL: 20 or
user discretion 6. MM: modified progressive with a limit of 5 entries (ex: .1, .1, .2, .4, .8 = total of 1.6) =
~2% cumulative loss for each pair series. Start a new series if a win or max lot size is a loss. 7. Pairs:
All with < 4 pip spread & 5 day ADR > 60...
Hi
One question: Will this Hitman indicator slow down our computer?
I just notice that my PC run slow after few hours with this indicator?
Groenie
Quoting nsn14
 Disliked
{quote} Hi One question: Will this Hitman indicator slow down our computer? I just notice that my PC
run slow after few hours with this indicator?
I have not had any problems yet personally, I think it will depend on your computer's processing power and the
amount of charts you have it open on
Groenie
===== PAGE 18/18 =====
S.3
S.3
Quoting Groenie
 Disliked
{quote} I have not had any problems yet personally, I think it will depend on your computer's
processing power and the amount of charts you have it open on
Ok mine started slowing down when I got to 42 pairs so yes it will slow down your computer with a lot of charts
You can try Nonor's dashboard on the second page if you want to monitor a lot of charts:
http://www.forexfactory.com/showthre...19#post7746519
bypasssbo
Hi txfxtrader, Groenie and Nonor and thanks for sharing this great system.
Can you explain with an example (for newbies) the Money Management commented in the first post (point 6 of the
rules)?
Thanks again
txfxtrader
Quoting bypasssbo
 Disliked
Hi txfxtrader, Groenie and Nonor and thanks for sharing this great system. Can you explain with an
example (for newbies) the Money Management commented in the first post (point 6 of the rules)?
Thanks again
I am going to remove it so it doesn't cause confusion.```
