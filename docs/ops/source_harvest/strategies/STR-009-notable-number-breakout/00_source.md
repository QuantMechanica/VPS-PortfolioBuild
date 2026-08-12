# STR-009-notable-number-breakout — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/27 =====
S.1
Notable numbers strategy
ForexFactory Thread 1182304 — 60 Beiträge, Eröffnung: erste 3 Seiten
joyny
We all know about "round numbers" psychological levels. Based on that created an EA to test some similar idea.
But this strategy can be traded manually. EA used for analysis purposes to ensure that this approach can work.
EA analyzed not only round numbers like 1.2300, 1.2200 or 1.2000 but in place of "0" can be any number like
1.2355, 1.2255, 1.2555 - why only "0" consider..?
Therefore developed a universal approach when can be set what number will be used as a "notable number" and
how many digits (from 2 to 4).
Then took EURUSD. Backtested years 2013 till 2020. And then forward tested 2020 till now - to exclude over
optimizations.
What I get is that "0" is not the best option for EURUSD but "6" is the winner.. a lot of entries with "666" if 5 digits...
see here:
Attached Image (click to enlarge)
OK, for this strategy entry rules.
Symbol: EURUSD
For example, our notable special price is 1.3766
BUY when the previous 2 days high/low prices are above our notable price level with "66" so the price reaches "66"
from above:
===== PAGE 2/27 =====
Attached Image
SEll when the previous 2 days high/low prices are below our notable price level with "66" so the price reaches "66"
from below:
Attached Image
You can set SL 70 pips and TP 110 pips. I prefer to use % of TP/SL targets but that's only with EA possible. I used
SL 0.5% and TP 0.8% in this testing.
Here is how equity looks in backtest/forward test:
Attached Image (click to enlarge)
Here attached backtest for 2013 to 2020:
Attached File(s)
backtest_2013_2020_eurusd_66.xlsx   62 KB | 477 downloads
And here attached forward test 2020 - 2022. EA didn't know anything about the future - therefore this is not
overoptimized:
Attached File(s)
===== PAGE 3/27 =====
S.1
forwardtest_2020_2022_eurusd_66.xlsx   39 KB | 453 downloads
You can trade this at this time span: starting from 1 hour after London opening till 1 hour after New York opening.
Or better do not trade this.. just wrote what I found. For me was interesting to research.
Edited 2023-06-23:
This strategy entries must be checked on M5 bars openings only. Please see this post where explained my error in
previous entries description.
Edited 2023-09-15:
This strategy free signals page is here.
Edited: 2024-06-05:
As MT4 stoped to work for signals EA for now signals no more available. Redesigned signals web page for different
purpose. BTW.. strategy keeps working. See latest results in this post.
joyny
GBPUSD
Notable number is "00". This is according to "round numbers" psychology. BUT... this works when there were
enough strong trend to reach that notable number level.
Not very much signals.. But they are highly profitable.
For example, our notable special price is 1.3700
BUY when the previous 22 days high/low prices are above our notable price level with "00" so the price reaches
"00" from above.
SEll when the previous 22 days high/low prices are below our notable price level with "00" so the price reaches "00"
from below.
TP 0.4%, SL 0.4%
You can trade this at this time span: starting from Sydney opening till Sydney closing.
Attached File(s)
backtest_2013_2020_gbpusd_00.xlsx   24 KB | 327 downloads
Attached File(s)
forwardtest_2020_2022_gbpusd_00.xlsx   23 KB | 327 downloads
Here one entry setup example for BUY at 1.2700 - to see what means "22 days strong trend":
Attached Image (click to enlarge)
===== PAGE 4/27 =====
Here sell example:
Attached Image (click to enlarge)
This "00" GBPUSD signal works quite well only within the Sydney sessions when markets are calm. Seems UK
traders have a psychological mood... they push price from those "00" levels away.
===== PAGE 5/27 =====
S.1
S.1
S.1
Homamiadana
very intresting, subscribed
joyny
USDJPY
Very few (15 deals in 11 years) but highly profitable (75% win rate with risk/reward 1:1) signals... when combined
with other symbols then it is still good to include in the portfolio.
Notable number is "444", for example, the valid price level to monitor is 134.44
BUY when the previous 20 days high/low prices are above our notable price level with "444" so the price reaches
"444" from above.
SELL when the previous 20 days high/low prices are below our notable price level with "444" so the price reaches
"444" from below.
TP 0.25%, SL 0.25%
Entries can be made any time.
Attached File(s)
backtest_2013_2020_usdjpy_444.xlsx   22 KB | 354 downloads
Attached File(s)
forwardtest_2020_2022_usdjpy_444.xlsx   23 KB | 304 downloads
joyny
EURGBP
Notable number is "66", for example, the valid price level to monitor is 0.8466
BUY when the previous 13 days high/low prices are above our notable price level with "66" so the price reaches
"66" from above.
SELL when the previous 13 days high/low prices are below our notable price level with "66" so the price reaches
"66" from below.
TP 0.35%, SL 0.9% (here we have risk/reward 3:1)
Entries time from Tokyo opening till Sydney close - again, enter in calm markets and then wait when UK traders
push back from that level.
Attached Image (click to enlarge)
===== PAGE 6/27 =====
S.1
S.1
Attached File(s)
backtest_2013_2020_eurgbp_66.xlsx   65 KB | 294 downloads
Attached File(s)
forwardtest_2020_2022_eurgbp_66.xlsx   35 KB | 295 downloads
joyny
AUDUSD
Notable number is "33", for example, the valid price level to monitor is 0.7633
BUY when the previous 42 days high/low prices are above our notable price level with "33" so the price reaches
"33" from above.
SELL when the previous 42 days high/low prices are below our notable price level with "33" so the price reaches
"33" from below.
TP 0.85%, SL 0.55%
Entries time from Tokyo open till London close.
Attached File(s)
backtest_2013_2020_audusd_33.xlsx   50 KB | 279 downloads
Attached File(s)
forwardtest_2020_2022_audusd_33.xlsx   33 KB | 272 downloads
joyny
Made analysis of all signals portfolio: EURUSD, GBPUSD, USDJPY, AUDUSD, EURGBP
Total 450 deals. On average 45 deals per year.
Here profits by years:
Attached Image (click to enlarge)
===== PAGE 7/27 =====
Here periods of drawdowns:
Attached Image (click to enlarge)
Here overall stats:
Attached Image (click to enlarge)
So far max drawdown with 0.01 lots is 40$. If acceptable DD is lets say 20% then to trade with 0.01 lots this strategy
we need start capital 200 usd. And average yearly profits then is ~50%.
Years 2020, 2021 and 2022 here are forward testing. EA used to analyze data didn't know anything about those
years.
In year 2014 we would expierence 8 months in DD... not exciting.. but who said trading is easy
===== PAGE 8/27 =====
S.1
S.1
Will continue to analyze other symbols to enlarge portfolio.
joyny
USDCAD
Notable number is "88", for example, the valid price level to monitor is 1.2988
BUY when the previous 9 days high/low prices are above our notable price level with "88" so the price reaches "88"
from above.
SELL when the previous 9 days high/low prices are below our notable price level with "88" so the price reaches "88"
from below.
TP 0.15%, SL 0.75% (risk/reward 5:1). With that risk/reward ratio is no wonder we have here 100% profitable deals
(in forwarding testing too).
Attached Image (click to enlarge)
The entry time window is 2 hours from 1h before London open.
Attached File(s)
backtest_2013_2020_usdcad_88.xlsx   30 KB | 289 downloads
Attached File(s)
forwardtest_2020_2022_usdcad_88.xlsx   23 KB | 269 downloads
It is ok to include in portfollio some high risk signals. Risk/reward 5:1 usually gives more than 90% profitable deals.
This minimizes DD for signals where r/r is close to 1:1 or 1:2. Let's see how this will impact our 2014 year 8 months
DD. Before that will analyze some more 3-5 symbols to make solid portfolio.
joyny
AUDNZD
Notable number is "333", for example, the valid price level to monitor is 1.0333
BUY when the previous 1 day high/low prices are above our notable price level with "333" so the price reaches
"333" from above.
SELL when the previous 1 day high/low prices are below our notable price level with "333" so the price reaches
"333" from below.
===== PAGE 9/27 =====
S.1
S.1
TP 0.35%, SL 0.8% (risk/reward ~2:1), we have here 100% profitable deals (in forwarding testing too).
Attached File(s)
backtest_2013_2020_audnzd_333.xlsx   27 KB | 255 downloads
Attached File(s)
forwardtest_2020_2022_audnzd_333.xlsx   21 KB | 299 downloads
joyny
CADJPY
Here is the reverse setup - price beats notable number level and continues trend direction.
Notable number is "88", for example, the valid price level to monitor is 104.88
BUY when the previous 41 days high/low prices are below our notable price level with "88" so the price reaches
"88" from below.
SELL when the previous 41 days high/low prices are above our notable price level with "88" so the price reaches
"88" from above.
TP 1%, SL 0.75%
Entry time: 14:00 - 22:00 (London +2h)
Attached Image (click to enlarge)
Attached File(s)
backtest_2013_2020_cadjpy_88.xlsx   48 KB | 279 downloads
Attached File(s)
forwardtest_2020_2022_cadjpy_88.xlsx   30 KB | 294 downloads
joyny
AUDCAD
Notable number is "55", for example, the valid price level to monitor is 0.9255
BUY when the previous 43 day high/low prices are above our notable price level with "55" so the price reaches "55"
from above.
SELL when the previous 43 day high/low prices are below our notable price level with "55" so the price reaches "55"
from below.
===== PAGE 10/27 =====
S.1
S.1
TP 0.4%, SL 0.6%
Entry time: 15:00 - 18:00 (London +2h)
Attached Image (click to enlarge)
Attached File(s)
backtest_2013_2020_audcad_55.xlsx   29 KB | 271 downloads
Attached File(s)
forwardtest_2020_2022_audcad_55.xlsx   26 KB | 274 downloads
joyny
EURCAD
Notable number is "44", for example, the valid price level to monitor is 1.4644
BUY when the previous 23 day high/low prices are above our notable price level with "44" so the price reaches "44"
from above.
SELL when the previous 23 day high/low prices are below our notable price level with "44" so the price reaches "44"
from below.
TP 0.65%, SL 0.55%
Entry time: 17:00 - 20:00 (London +2h)
Attached Image (click to enlarge)
Attached File(s)
backtest_2013_2020_eurcad_44.xlsx   41 KB | 310 downloads
Attached File(s)
forwardtest_2020_2022_eurcad_44.xlsx   25 KB | 299 downloads
joyny
===== PAGE 11/27 =====
Updated analysis of all signals portfolio: EURUSD, GBPUSD, USDJPY, AUDUSD, EURGBP, USDCAD, AUDNZD,
CADJPY, AUDCAD, EURCAD
Total 720 deals. On average 70 deals per year.
Here profits by years:
Attached Image (click to enlarge)
Here periods of drawdowns:
Attached Image (click to enlarge)
Here overall stats:
Attached Image (click to enlarge)
===== PAGE 12/27 =====
S.1
S.1
S.1
Max drawdown with 0.01 lots is 37$. If acceptable DD is lets say 20% then to trade with 0.01 lots this strategy we
need start capital 200 usd. And average yearly profits then is ~75%.
Years 2020, 2021 and 2022 here are forward testing. EA used to analyze data didn't know anything about those
years.
And now by adding more signals year 2014 DD is good - max 3 months in drawdown.
720 deals can be considered good for statistic validation.
For me seems this strategy is tradable. Will go on live account.
joyny
Quoting joyny
 Disliked
AUDUSD Notable number is "33", for example, the valid price level to monitor is 0.7633 BUY when
the previous 42 days high/low prices are above our notable price level with "33" so the price reaches
"33" from above. SELL when the previous 42 days high/low prices are below our notable price level
with "33" so the price reaches "33" from below. TP 0.85%, SL 0.55% Entries time from Tokyo open till
London close. {file}{file}
One deal made, opened on 10.10.2022 07:55 - hit SL 40 pips.
joyny
Quoting joyny
 Disliked
USDCAD Notable number is "88", for example, the valid price level to monitor is 1.2988 BUY when
the previous 9 days high/low prices are above our notable price level with "88" so the price reaches
"88" from above. SELL when the previous 9 days high/low prices are below our notable price level
with "88" so the price reaches "88" from below. TP 0.15%, SL 0.75% (risk/reward 5:1). With that
risk/reward ratio is no wonder we have here 100% profitable deals (in forwarding testing too). {image}
The entry time window is 2 hours from 1h before London open....
The deal opened on 10.26.2022 09:15 - TP 46 pips.
joyny
Quoting joyny
 Disliked
===== PAGE 13/27 =====
S.1
S.1
S.1
S.1
S.2
We all know about "round numbers" psychological levels. Based on that created an EA to test some
similar idea. But this strategy can be traded manually. EA used for analysis purposes to ensure that
this approach can work. EA analyzed not only round numbers like 1.2300, 1.2200 or 1.2000 but in
place of "0" can be any number like 1.2355, 1.2255, 1.2555 - why only "0" consider..? Therefore
developed a universal approach when can be set what number will be used as a "notable number"
and how many digits (from 2 to 4). Then took EURUSD. Backtested years...
EURUSD opened on 03.11.2022 11:40 - TP 80 pips
SilentFixer
Interesting approach to the markets I'm excited to see your results for gold subscribed
joyny
EURUSD opened on 10.11.2022 11:50 BUY at 0.9966, TP 120 pips.
joyny
Quoting joyny
 Disliked
USDCAD Notable number is "88", for example, the valid price level to monitor is 1.2988 BUY when
the previous 9 days high/low prices are above our notable price level with "88" so the price reaches
"88" from above. SELL when the previous 9 days high/low prices are below our notable price level
with "88" so the price reaches "88" from below. TP 0.15%, SL 0.75% (risk/reward 5:1). With that
risk/reward ratio is no wonder we have here 100% profitable deals (in forwarding testing too). {image}
The entry time window is 2 hours from 1h before London open....
USDCAD opened on 11.11.2022 11:00 BUY at 1.3288, TP 20 pips
joyny
Quoting SilentFixer
 Disliked
Interesting approach to the markets I'm excited to see your results for gold subscribed
for Gold didn't find good notable numbers.. seems this strategy better works with currencies.
joyny
Results for 1st month trading on a real account with 100 USD initial capital:
Attached Image (click to enlarge)
===== PAGE 14/27 =====
S.2
S.2
Attached Image (click to enlarge)
joyny
Quoting joyny
 Disliked
EURCAD Notable number is "44", for example, the valid price level to monitor is 1.4644 BUY when
the previous 23 day high/low prices are above our notable price level with "44" so the price reaches
"44" from above. SELL when the previous 23 day high/low prices are below our notable price level
with "44" so the price reaches "44" from below. TP 0.65%, SL 0.55% Entry time: 17:00 - 20:00
(London +2h) {image} {file}{file}
EURCAD opened on 14.11.2022 20:00 SELL at 1.3744, SL 80 pips
joyny
4 more deals were done:
Attached Image (click to enlarge)

===== PAGE 15/27 =====
S.2
S.2
S.2
S.2
S.2
S.2
Yesterdays CADJPY SELL at 101.886 still opened.
js497
Congratulation for your approach and details Joyny :-)
Question...
how do you find the optimizations sets from number of bars and digits ?
story to make it on our own side :-)
joyny
Quoting joyny
 Disliked
4 more deals were done: {image} Yesterdays CADJPY SELL at 101.886 still opened.
CADJPY hit SL 80 pips
joyny
Quoting js497
 Disliked
Congratulation for your approach and details Joyny :-) Question... how do you find the optimizations
sets from number of bars and digits ? story to make it on our own side :-)
used MT5 Strategy tester optimizations (optimized bars count and notable numbers). Pick up those setups which
performed well in backtests (years 2013 - 2019) and in forward tests (years 2020 - 2022).
js497
Quoting joyny
 Disliked
{quote} used MT5 Strategy tester optimizations (optimized bars count and notable numbers). Pick up
those setups which performed well in backtests (years 2013 - 2019) and in forward tests (years 2020 -
2022).
Ok, i will try something with ninjatrader,
Thx Joyny,
Lazar83
Good approach Joyny.
Here is a similar strategy which could be interesting with round numbers, i use it from time to time, but thinking to
jump into ea for this one, since its hard to track all opportunities. Disregard the idiotic headline in youtube video....
Inserted Video
joyny
Quoting Lazar83
===== PAGE 16/27 =====
S.2
S.2
S.2
S.2
S.2
S.2
 Disliked
Good approach Joyny. Here is a similar strategy which could be interesting with round numbers, i use
it from time to time, but thinking to jump into ea for this one, since its hard to track all opportunities.
Disregard the idiotic headline in youtube video.... https://www.youtube.com/watch?v=ZyodZB1kA10
Thank you!
Checked from year 2013 "00" works fine for GBPUSD with fixed SL/TP - posted results here.
"50" seems an interesting candidate to check with an EA
Lazar83
One thing i like about this strategy is that its completely brain dead, so no heavy computing, simply targeting levels.
I think 50 gives more entries and flexibility on daily level.
since80808
Hi Lazar!
Quoting Lazar83
 Disliked
i use it
Answering commentaries, author says: "I leave MM to you". In the video he says "...target around next level". + My
vision of this kind of strategies is to set SL to the pullback (current swing) high or low.
What could you recommend as a SL/TP based on your experience with this strategy?
Lazar83
Tbh, different people, different risk appetites. Since this is not my main strategy i either use some previous high/low
or % of the account, based on my mood or fear factor. Ideally you would need to provide some breathing space. I
am afraid i am not much of a help here. On the positive side, is simplicity beats everything i compere it with.
joyny
Did profitable 3 deals in a row - notable numbers you can see were "66", "55" and "88":
Attached Image (click to enlarge)
Now account +27% in profits.
Lazar83
Strategy is simple and effective, keep going man. it's hard to get all on 50+ instruments, but there are plenty of
opportunity with level 50.
joyny
===== PAGE 17/27 =====
S.2
3 deals. Notable numbers 44, 66 and 88:
Attached Image (click to enlarge)
Attached Image (click to enlarge)
Here is how the portfolio compensates.. 2 losers EURCAD and GBPUSD. All the rest are positive:
Attached Image (click to enlarge)
So far all according to analysis.
Lazar83
It looks good. Hope that now its the same situation.
Do you have any indicator that can give an alarm if the candle crosses the price level of 50 or 100? It looks better to
put it on 30 instruments and wait.
===== PAGE 18/27 =====
S.2
S.2
S.2
S.2
S.3
joyny
Quoting Lazar83
 Disliked
It looks good. Hope that now its the same situation. Do you have any indicator that can give an alarm
if the candle crosses the price level of 50 or 100? It looks better to put it on 30 instruments and wait.
No indi.. i might push alerts to an telegram account if that suits..? For example if price is 20pips till entry? Will it be
ok for people? Any interested?
rosalieone
Yes Sir. but in my opinion better stay here
Lazar83
Quoting joyny
 Disliked
{quote} No indi.. i might push alerts to an telegram account if that suits..? For example if price is
20pips till entry? Will it be ok for people? Any interested?
I was getting headaches from telegram, and i deleted that rabbitholle app.
I am thinking how to automate the whole strategy since on surface it looks easy for manual trading, but to automate
it on IF this then That rules its not so easy.
Manually its profitable.
Arcana
Quoting joyny
 Disliked
We all know about "round numbers" psychological levels. Based on that created an EA to test some
similar idea. But this strategy can be traded manually. EA used for analysis purposes to ensure that
this approach can work. EA analyzed not only round numbers like 1.2300, 1.2200 or 1.2000 but in
place of "0" can be any number like 1.2355, 1.2255, 1.2555 - why only "0" consider..? Therefore
developed a universal approach when can be set what number will be used as a "notable number"
and how many digits (from 2 to 4). Then took EURUSD. Backtested years...
Oh man, thanks for this! I am checking it out now on Tradingview and it looks interesting!
joyny
The new year started - back to trading!
Ok, actually EAs worked on Xmas week as well.. Thin liquidity.. therefore 1 deal closed with huge slippage. All the
rest 2 deals closed fine. At this moment +47% in profits in 3 months.
Attached Image (click to enlarge)

===== PAGE 19/27 =====
S.3
S.3
S.3
All last 3 entries were with the notable number "66".
Meanwhile started working on the signals website.. using push notifications in the browser.. here so far how it could
look:
Attached Image (click to enlarge)
continue with push notifications logic implementation..
joyny
Push notifications now working at www.blometech.com
Audited results are available at MyFxBook.
joyny
Attached Image (click to enlarge)
joyny
===== PAGE 20/27 =====
S.3
S.3
S.3
S.3
One more signal for notable numbers strategy:
Attached Image (click to enlarge)
As I can post them here it seems blometech.com signals can be used for manual trading.
joyny
Quoting joyny
 Disliked
One more signal for notable numbers strategy: {image} As I can post them here it seems
blometech.com signals can be used for manual trading.
TP 20 pips for usdcad
killervsr
Quoting joyny
 Disliked
The new year started - back to trading! Ok, actually EAs worked on Xmas week as well.. Thin
liquidity.. therefore 1 deal closed with huge slippage. All the rest 2 deals closed fine. At this moment
+47% in profits in 3 months. {image} All last 3 entries were with the notable number "66". Meanwhile
started working on the signals website.. using push notifications in the browser.. here so far how it
could look: {image} continue with push notifications logic implementation..
can the EA be shared?
Thank you for your attention
joyny
Quoting killervsr
 Disliked
{quote} can the EA be shared? Thank you for your attention
I do not share any EAs anymore
Explained strategy in detail in this thread - anybody can develop their own EA or order some freelancer to develop it
according to the rules explained.
joyny
Quoting joyny
 Disliked
{image}
AUDUSD sell closed with TP 59 pips.
===== PAGE 21/27 =====
S.3
S.3
S.3
S.3
S.3
Tiestobob
How do you get number of days to enter?
joyny
Quoting tiestobob
 Disliked
How do you get number of days to enter?
Here:
Quoting joyny
 Disliked
{quote} used MT5 Strategy tester optimizations (optimized bars count and notable numbers). Pick up
those setups which performed well in backtests (years 2013 - 2019) and in forward tests (years 2020 -
2022).
cmh1995
Hi, I think your strategy is really good.
Your time to make entry is exactly like your post, is'nt it??
joyny
Quoting cmh1995
 Disliked
Hi, I think your strategy is really good. Your time to make entry is exactly like your post, is'nt it??
Yes. My signal webpage alerted and it was possible to make entries as I posted.
One more entry for AUDUSD recently made TP 60 pips.
joyny
Strategy keeps working:
Attached Image (click to enlarge)
===== PAGE 22/27 =====
S.3
S.3
Pandatronix
Following closely, busy writing an EA, just a little slow
joyny
Nice run-up for notable numbers strategy:
Attached Image (click to enlarge)
74% profitable deals:
Attached Image (click to enlarge)
===== PAGE 23/27 =====
S.3
in 6 months 85% in profits:
Attached Image (click to enlarge)
Is anyone of the subscribers making deals with signals?
Maybe someone built an EA and get similar results?
Keep in mind.. according to the analysis made here might be some losing series too.. but for now, we can enjoy a
winning period.
joyny
And here breakdown how each asset performed from our portfolio of 10 assets:
Attached Image (click to enlarge)
===== PAGE 24/27 =====
S.3
S.3
S.3
The biggest loser is EURCAD.. according to the analysis here, it is ok to have 3 losing deals in a row. This trades
with risk/reward 55/65 therefore no wonder of such a losing serie.
EURUSD - massive gainer - see analysis in post nr1. with risk/reward, 5/8 proportion of profitable deals looks very
good. 5 in a row profits, then 2 losing and then again 3 in profits.
Pandatronix
Quoting joyny
 Disliked
Nice run-up for notable numbers strategy: {image} 74% profitable deals: {image} in 6 months 85% in
profits: {image} Is anyone of the subscribers making deals with signals? Maybe someone built an EA
and get similar results? Keep in mind.. according to the analysis made here might be some losing
series too.. but for now, we can enjoy a winning period.
I'm just struggling to get my EA to run like yours, seems to be my biggest battle at the moment haha
acetrader
Quoting joyny
 Disliked
We all know about "round numbers" psychological levels. Based on that created an EA to test some
similar idea. But this strategy can be traded manually. EA used for analysis purposes to ensure that
this approach can work. EA analyzed not only round numbers like 1.2300, 1.2200 or 1.2000 but in
place of "0" can be any number like 1.2355, 1.2255, 1.2555 - why only "0" consider..? Therefore
developed a universal approach when can be set what number will be used as a "notable number"
and how many digits (from 2 to 4). Then took EURUSD. Backtested years...
Hi Joyny,
Took a look & what you are sharing here. Most interesting. Have you tried putting horizontal lines at the levels you
are describing? I have seen some interesting moves @ the numbers you describe as well as the (50) & the (00)
levels. You are thinking outside of the box my friend. Just my views.
clemmo17
Quoting joyny
 Disliked
===== PAGE 25/27 =====
S.3
Nice run-up for notable numbers strategy: {image} 74% profitable deals: {image} in 6 months 85% in
profits: {image} Is anyone of the subscribers making deals with signals? Maybe someone built an EA
and get similar results? Keep in mind.. according to the analysis made here might be some losing
series too.. but for now, we can enjoy a winning period.
I haven't seen any evidence of these levels so I'm both wary and interested in this system.
I don't see that your EA is trading at round numbers at all, so I don't really understand how it is making entries. Is
this just because of spread/slippage?
update: Ok, I re-read the description and I see you are using some customized levels. I am interested to see how
this progresses. Maybe it is finding actual support/resistance levels? If so, I expect those to change in the future. In
your backtests, there is a big falloff in profits after some time - how do you plan to avoid that?
joyny
Quoting clemmo17
 Disliked
{quote} I haven't seen any evidence of these levels so I'm both wary and interested in this system. I
don't see that your EA is trading at round numbers at all, so I don't really understand how it is making
entries. Is this just because of spread/slippage? update: Ok, I re-read the description and I see you
are using some customized levels. I am interested to see how this progresses. Maybe it is finding
actual support/resistance levels? If so, I expect those to change in the future. In your backtests, there
is a big falloff in profits after some...
EA opens correct on round numbers as you can see in myfxbook:
Attached Image (click to enlarge)
===== PAGE 26/27 =====

===== PAGE 27/27 =====
But there are some seconds till published in website and pushed signals to subscribers. Therefore might be 1 or 2
pips difference. Anyway each broker can have different quotes..```
