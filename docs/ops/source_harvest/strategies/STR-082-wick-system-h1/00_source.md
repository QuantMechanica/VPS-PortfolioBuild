# STR-082-wick-system-h1 — Source extract (verbatim pypdf text, 2026-07-25)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/28 =====
S.1
S.1
S.1
Statistics combined with system. Profitable? What do you think
ForexFactory Thread 771822 — 72 Beiträge, KOMPLETT (4 Seite(n))
michaellobry
Trading system: wick system 1.00
Type: trend and ranged
Timeframe: M1 - D1. In this example we take the H1 chart.
Entry:
- when: in the H1 chart buy or sell on every candle (this means, every hour you will open an order at exactly close of previous candle).
- buy: if lower wick of previous candle is bigger than the upper wick.
- sell: if lower wick of previous candle is smaller than the upper wick.
- TP/SL: 50 pips
Statistics:
If statistics say that wicks determine direction, this trading system should be profitable. I ask the readers of this thread to test this theory.
What do you think: will this system be profitable?
______________________
Discuss test case:
______________________
1. (stated by Tzamo) Find out if the wicks and candles are relative in the different timeframes of a particular symbol. (For example (Random
numbers) in the H1, the candle bodies range from 100 to 200 units and the wicks are 40 to 80 units. While in the 15 min, the candle bodies are 25
to 50 units and the wicks are 10 to 20 units. If that is true, then the candle bodies are relative to the wicks and to run the EA on the other time
frame just need to adjust the bodies/ wick limits.)
-- test case: select several different situations withing the symbol, like: 10 events of steep up trends, 10 events of steep down trends, 20 events of
ranging, events with lots of spikes... and so on and then run the EA on each of those and see if it passes.
2.
3.
4.
5. [let's discuss and add more ideas]
Fauzaan
Interesting! Here is a simple EA coded to just do that.
I've run couple tests and optimizations and i dont think going for 50 SL and 50 TP is working out very well
But... lets see...
Attached File(s)
wicksys.ex4   8 KB | 582 downloads
michaellobry
Quoting Fauzaan
 Disliked
Interesting! Here is a simple EA coded to just do that. I've run couple tests and optimizations and i dont think going for 50 SL and 50
TP is working out very well But... lets see... {file}
Thank you for the EA. I've done some testing with it. 72% seem to be short positions and 27% are long positions (h1 chart). Right now I'm
optimizing the best tp/sl ratio and timeframe in strategy tester.
Could you update it with the following rules:
- add parameter: anti-trading (opposite) on/off: on means: selling (with the buy rules) instead of buying (argument: see results in image: 72% of the
losses were sell)
- add parameter: trade on swing: [on/off]. On means:
(add parameter)*only trade [5] candles after previous higher high [on/off]
*only trade [5] candles after previous lower high [on/off]
===== PAGE 2/28 =====
*only trade [5] candles after previous lower low [on/off]
*only trade [5] candles after previous higher low [on/off]
- add parameter: [5] candles (argument: market phases have different effects on candle wicks)
- add parameter: duration: for [8] following candles
- add parameter: [on/off]only if previous candle is >150 times bigger than previous [4] candles
- add parameter: [4] candles
- add parameter: [on/off]only if previous candle is >[10] pips
- add parameter: [10] pips
- add parameter: [on/off]only if previous candle lower wick >3 pips
- add parameter: [3] pips
- add parameter: [on/off]only if previous candle lower wick is >150% bigger than upper wick
- add parameter: [150] percentage
Attached Image(s) (click to enlarge)
===== PAGE 3/28 =====
S.1
S.1
llxx77dd
michaellobry
Quoting llxx77dd
 Disliked
you will have a good chance to be the first man or woman who touch the sun than finding a holy grail for this game a holly grail
simply mean a system that work on fx, doesn't mean its a system with 0 loss so you will just lose in this world as far as i know till this
day, but ofc me and you will always hope that i was wrong ! cheers
Thank you for your insight. Did you test it and what were your results? What can you add to the system?
===== PAGE 4/28 =====
S.1
S.1
S.1
michaellobry
Quoting Fauzaan
 Disliked
Interesting! Here is a simple EA coded to just do that. I've run couple tests and optimizations and i dont think going for 50 SL and 50
TP is working out very well But... lets see... {file}
In Daily chart the results are: see image. (last 4yrs, TP/SL 500, every tick, EURUSD, 1% DD)
Attached Image (click to enlarge)
handy148
Some would say - body in direction of profit and wick in direction of loss.
abusaad412
9 pairs 1M TF TP 20 SL 5000 lets see for another hour
Attached Image (click to enlarge)

===== PAGE 5/28 =====
S.1
S.1
S.1
llxx77dd
Fauzaan
Quote
 Disliked
- add parameter: anti-trading (opposite) on/off: on means: selling (with the buy rules) instead of buying (argument: see results in
image: 72% of the losses were sell)
Done
Quote
 Disliked
- add parameter: trade on swing: [on/off]. On means:
(add parameter)*only trade [5] candles after previous higher high [on/off]
*only trade [5] candles after previous lower high [on/off]
*only trade [5] candles after previous lower low [on/off]
*only trade [5] candles after previous higher low [on/off]
Done
Quote
 Disliked
- add parameter: [5] candles (argument: market phases have different effects on candle wicks)
Done
Quote
 Disliked
- add parameter: [on/off]only if previous candle is >[10] pips
- add parameter: [10] pips
Done
Quote
 Disliked
- add parameter: duration: for [8] following candles
Is this a new parameter? Is it the duration of the trade? or ...?
Quote
 Disliked
- add parameter: [on/off]only if previous candle is >150 times bigger than previous [4] candles
- add parameter: [4] candles
- add parameter: [on/off]only if previous candle lower wick >3 pips
- add parameter: [3] pips
- add parameter: [on/off]only if previous candle lower wick is >150% bigger than upper wick
- add parameter: [150] percentage
These three i havnt included yet
Im hoping there are some other people who can code in here as well who can add into this, and so im posting the mq4 file
Attached File(s)
wicksys.mq4   7 KB | 625 downloads
michaellobry
I am testing the updated ea now.
===== PAGE 6/28 =====
S.1
Below parameters are not related to the duration. Below parameters are conditions for the entry.
- add parameter: [on/off]only if previous candle is >200 percentage bigger than previous [4] candles
- add parameter: [200] percentage
- add parameter: [4] candles
- add parameter: [on/off]only if previous candle lower wick >3 pips
- add parameter: [3] pips
- add parameter: [on/off]only if previous candle lower wick is >150% bigger than upper wick
- add parameter: [150] percentage
Conclusion:
So it means: if this parameter is turned on "only if previous candle lower wick >3 pips"
then the EA only opens a trade at candle close if previous candle wick is bigger than 3 pips. Every trade entry must be bigger
than 3 pips wick, otherwise EA will not open the trade and waits for a new 'candle close' until there is a candle wick bigger than
3 pips. So the EA does not open orders every hour, because not all wicks are bigger than 3 pips.
The EA will only open an order if:
- the candle wick is bigger than 3 pips.
Same with 150 percentage and 200 times bigger.
The EA will only open an order if:
- previous candle is >200% bigger than previous [4] candles
The EA will only open an order if:
- if previous candle lower wick is >150% bigger than upper wick
____________________________________
The inheritance hierarchy (child/parent) is:
____________________________________
1. reverse logic
2. trade on swing: [on/off]
2a1. only trade [5] candles after previous higher high [on/off]
2a2. only trade [5] candles after previous lower high [on/off]
2a3. *only trade [5] candles after previous lower low [on/off]
2a4. *only trade [5] candles after previous higher low [on/off]
2b. [5] candles (start trading from 5 candles after swing)
2c. duration: for [8] following candles (so 'duration' (child) belongs to 'trade swing' (parent)) (stop trading 8 candles after [5] candles after swing)
-------------- general entry conditions ---------------------
3. [on/off]only if previous candle is >200% bigger than previous [4] candles
3a.[4] candles
3b. [200]%
4. [on/off]only if previous candle is >[10] pips
4a. [10] pips
5. [on/off]only if previous candle lower wick >3 pips
5a. [3] pips
6. [on/off]only if previous candle lower wick is >150% bigger than upper wick
6a. [150] percentage
tzamo
Hi, what an interesting concept. Just by looking at wicks, so simple
Could you please confirm that you didn't take into account of the close of the bars proximity to the wicks? ie. a bearish bar with a larger lower wick
vs a bullish bar with larger wick. I will play around and see if it makes a difference
I just worry about a large rejection wick from things like moving averages/ significant levels. Which would cause a buy entry according to standard
rules.
===== PAGE 7/28 =====
S.1
S.1
S.1
S.1
S.1
Thank you for sharing the strategy and to those that contribute to coding the EA. I will try to suggest and add some functions as this looks really
interesting.
Kind Regards,
Tzamo
michaellobry
Quoting handy148
 Disliked
Some would say - body in direction of profit and wick in direction of loss.
Very good suggestion. This will be added to the EA in the form of: "only if previous candle is >200 times bigger than previous [4] candles"
michaellobry
Quoting tzamo
 Disliked
Hi, what an interesting concept. Just by looking at wicks, so simple Could you please confirm that you didn't take into account of the
close of the bars proximity to the wicks? ie. a bearish bar with a larger lower wick vs a bullish bar with larger wick. I will play around
and see if it makes a difference I just worry about a large rejection wick from things like moving averages/ significant levels. Which
would cause a buy entry according to standard rules. Thank you for sharing the strategy and to those that contribute to coding...
Thank you for your great suggestion! I really appreciate it! Thank you, yes the more input the better it is.
Yes, you can test it with the EA (settings: reverse logic on and off)(will be added: settings: only if previous candle upper wick is at least 150%
bigger than its lower wick). Is that what you mean?
michaellobry
Quoting abusaad412
 Disliked
9 pairs 1M TF TP 20 SL 5000 lets see for another hour {image}
Thank you! I appreciate it. Is that 5000 pips or 500 pips? (the EA uses fractals/points so settings: 5000 is 500 pips in the EA)
goodways100
Subs. Thanks and
Regards
michaellobry
Quoting Fauzaan
 Disliked
{quote} Done {quote} Done {quote} Done {quote} Done {quote} Is this a new parameter? Is it the duration of the trade? or ...? {quote}
These three i havnt included yet Im hoping there are some other people who can code in here as well who can add into this, and so
im posting the mq4 file {file}
Could you fix this:
Inserted Code
bool swingCheck(Modes value,int candles)
{
if (value == HH)
{
if (High[candles+1] > High[candles+2])
{
return(true);
}
 
}
if (value == LL)
{
if (Low[candles+1] < Low[candles+2])
{
===== PAGE 8/28 =====
return(true);
}
 
}
 
if (value == HL)
{
if (Low[candles+1] > Low[candles+2])
{
return(true);
}
 
}
 
if (value == LH)
{
if (High[candles+1] < High[candles+2])
{
return(true);
}
 
}
return(false);
}
As I understand, above code is comparing the (5+1) 6th candle (from the right side (index bar)) with the 7th candle. Am I correct? It is comparing
two candles, and not a 'swing'. Correct?
I tried to improve on it, but I failed (see below). Can you use the standard ZigZag indicator to get the LL, HL, HH and LH from?
My failed attempt:
Inserted Code
EA should not compare two bars, but instead compare 3 swings (for example: comparing LowestLow and HighestHigh).
double LowestLow = Low[iLowest(NULL, 0, MODE_LOW, 10, 1)]; //from the first bar to the 10th bar
 
double LowestLow2 = Low[iLowest(NULL, 0, MODE_LOW, 10, 10)]; //from the 10th to the 19th bar
 
double HighestHigh = High[iHighest( NULL, 0, MODE_HIGH, 10, 1 )];
//and now check if LowestLow occurs after HighestHigh
int checkSwingType()
{
if(LowestLow3 > LowestLow2 > LowestLow1){ return 1; //1 means: LL (lower low)
if(LowestLow3 > LowestLow2 < LowestLow1){ return 2; //2 means: HL (higher low)
if(HighestHigh3 < HighestHigh2 < HighestHigh1){ return 3; //3 means: HH (a new higher high occured)
if(HighestHigh3 < HighestHigh2 > HighestHigh1){ return 4; //4 means: LH (a new lower high occured)
}; // but the zigzag indicator still does a much better job to identify LL, HL, HH and LH (see last screenshot of zigzag).
Quoting Fauzaan
 Disliked
{quote} Done {quote} Done {quote} Done {quote} Done {quote} Is this a new parameter? Is it the duration of the trade? or ...? {quote}
These three i havnt included yet Im hoping there are some other people who can code in here as well who can add into this, and so
im posting the mq4 file {file}
Attached Image (click to enlarge)
===== PAGE 9/28 =====
S.1
S.1
Attached Image
Fauzaan
Quoting michaellobry
 Disliked
{quote} Could you fix this: bool swingCheck(Modes value,int candles) { if (value == HH) { if (High[candles+1] > High[candles+2]) {
return(true); } } if (value == LL) { if (Low[candles+1] < Low[candles+2]) { return(true); } } if (value == HL) { if (Low[candles+1] >
Low[candles+2]) { return(true); } } if (value == LH) { if (High[candles+1] < High[candles+2]) { return(true); } } return(false); } As I
understand, above code is comparing the (5+1) 6th candle (from the right side (index bar)) with the 7th candle. Am I correct? It is
comparing two candles,...
Since u didnt mention about zigzag i assumed HH and LL based on Candles.
Ill see what i can do using the Zigzag
tzamo
Quoting michaellobry
 Disliked
{quote} In Daily chart the results are: see image. (last 4yrs, TP/SL 500, every tick, EURUSD, 1% DD) {image}
Dear michaellobry,
Lets not get too carried away with trying to optimize your EA. If we do, we will just end up 'curve fitting' into the historical data. We can approach
this more statistically as you have started by observing the wicks
What we need to find out is if the wicks and candle bodies are relative in the different timeframes of a particular symbol (eg EUR/USD) For
example (Random numbers) in the H1, the candle bodies range from 100 to 200 units and the wicks are 40 to 80 units. While in the 15 min, the
candle bodies are 25 to 50 units and the wicks are 10 to 20 units. If that is true, then the candle bodies are relative to the wicks and to run the EA
on the other time frame just need to adjust the bodies/ wick limits.
Now to approach the testing: My idea is to select several different situations withing the symbol, like: 10 events of steep up trends, 10 events of
steep down trends, 20 events of ranging, events with lots of spikes... and so on and then run the EA on each of those and see if it passes.
Anyways, just an idea, if it helps, great and if not I will not be offended
ZigZag is an amazing indicator, will wait for latest wicksys before adding any suggestions
===== PAGE 10/28 =====
S.1
S.2
S.2
S.2
Kind Regards,
Tzamo
michaellobry
Quote
 Disliked
Lets not get too carried away with trying to optimize your EA. If we do, we will just end up 'curve fitting' into the historical data. We
can approach this more statistically as you have started by observing the wicks
I agree.
Quote
 Disliked
What we need to find out is if the wicks and candle bodies are relative in the different timeframes of a particular symbol (eg
EUR/USD) For example (Random numbers) in the H1, the candle bodies range from 100 to 200 units and the wicks are 40 to 80
units. While in the 15 min, the candle bodies are 25 to 50 units and the wicks are 10 to 20 units. If that is true, then the candle bodies
are relative to the wicks and to run the EA on the other time frame just need to adjust the bodies/ wick limits.
I'm pondering on the different ways to find out if there is a relation between the size of wick-candle ratio in different timeframes:
- the EA could calculate the average candle size and wicks for each timeframe, and check if the 'ratio of candle and wick size' is the same in
other timeframes in the same currency pair.
- the EA could categorize the results into: timezones (for example, London Open has a different candle/wick average than Asia Open)
Quote
 Disliked
Now to approach the testing: My idea is to select several different situations withing the symbol, like: 10 events of steep up trends,
10 events of steep down trends, 20 events of ranging, events with lots of spikes... and so on and then run the EA on each of those
and see if it passes. Anyways, just an idea, if it helps, great and if not I will not be offended
"10 events of steep down trends". I take it you mean checking 10 'upswings/downswings' on the chart with a sharp slope. It's a very good
suggestion, I agree.
michaellobry
Quoting Fauzaan
 Disliked
{quote} Since u didnt mention about zigzag i assumed HH and LL based on Candles. Ill see what i can do using the Zigzag
Thank you so much!
lassame
I test for EU 01.01.2017 - 25.04.2018 tf H1 / Wicksys (2) default set
Ooop! what i Missed
Attached Image (click to enlarge)
michaellobry
Lassame. Thanks for your reply. I appreciate your message! What is your suggestion to improve this system? How do you think we could tweak to
use statistical information in trading?
Regarding your reply, the main reasons:
===== PAGE 11/28 =====
S.2
S.2
S.2
S.2
S.2
S.2
0. the parameters are not yet correct.
1. the EA is in progress so we need your ideas
2. you are backtesting in Open Prices mode which means you are disregarding wicks. This system uses wicks to determine direction.
3. you are testing in 90% data feed. Type in google: download MT4 99% tick data feed
4. use the best data feed (not manipulated from a broker):
* https://www.reddit.com/r/Forex/comme...rex_data_feed/
* https://www.forextester.com/forex-data-feed
* https://www.liteforex.com/trading/best-data-feed-forex/
michaellobry
How to make a system scientific based?
Test case:
By demonstrating a 50 -50 ratio just by calculating red and green candles on M1 for the past 20 years and you can see that it will be much more
candles in 1 type than on the other, way past a reasonable distribution, so in either way its biased. But to say random, i agree. BTW the gold and
silver is upward biased more than 35% than the equilibrium, thats not a coincidence, but the seed of candlesticks is probably a true random
sequence.
Question:
- how do we define:
1. a biased market
2. a coincidence in the market
3. a random price direction?
What is your opinion?
michaellobry
For your information about market predictability and randomness: https://www.forexfactory.com/showthr...le#post7157404.
What is your own opinion to what extent the market is random?
michaellobry
https://www.reddit.com/r/Forex/comme...eurusd_thesis/
What is your opinion about this scientist's EUR/USD thesis?
billytt
[quote=michaellobry;11119623]Trading system: wick system 1.00 Type: trend and ranged Timeframe: M1 - D1. In this example we take the H1
chart. Entry: - when: in the H1 chart buy or sell on every candle (this means, every hour you will open an order at exactly close of previous candle).
- buy: if lower wick of previous candle is bigger than the upper wick. - sell: if lower wick of previous candle is smaller than the upper wick. - TP/SL:
50 pips Stati
Hi, i trade using statistics and to be precise Frequency Distribution...
i am not here to be negative and you may have something with the wicks?
But the only way to trade is follow the market makers and especially after the uk & us open. volatility is king.
Keeping stats opens your eyes as to what the market movers are up to OR playing.
billytt
Quoting michaellobry
 Disliked
https://www.reddit.com/r/Forex/comme...eurusd_thesis/ What is your opinion about this scientist's EUR/USD thesis?
negative opinion, anything can happen between now and then.
For every forecaster who is correct we will have losers.
michaellobry
Here you will find an mq4 file for candle wicks. Can anyone upload more indicators that are similar or interesting for scientific or wick purposes?
Attached File(s)
CandleWicksDisplay_mod3.mq4   8 KB | 358 downloads
===== PAGE 12/28 =====
S.2
S.2
S.2
S.2
michaellobry
Quoting billytt
 Disliked
{quote} negative opinion, anything can happen between now and then. For every forecaster who is correct we will have losers.
Thank you for your reply. I appreciate it a lot.
"i trade using statistics and to be precise Frequency Distribution..."
For the readers out here, could you go more in depth regarding your trading using statistics (FD)?
michaellobry
https://www.oanda.com/forex-trading/...ers-statistics
Top 100 Forex Traders Statistics. These statistics are calculated from the forex trading activities over the past 24 hours of two groups of OANDA
traders: the top 100 "most profitable" and (optionally) the top 100 "least profitable" traders.
For the readers of this thread, please state your opinion.
VEEFX
Quoting billytt
 Disliked
Quoting michaellobry
 Disliked
Trading system: wick system 1.00 Type: trend and ranged Timeframe: M1 - D1. In this example we take the H1 chart.
Entry: - when: in the H1 chart buy or sell on every candle (this means, every hour you will open an order at exactly
close of previous candle). - buy: if lower wick of previous candle is bigger than the upper wick. - sell: if lower wick of
previous candle is smaller than the upper wick. - TP/SL: 50 pips Stati Hi, i trade using statistics and to be precise
Frequency Distribution... i am not here to be negative
...
"the only way to trade is follow the market makers and especially after the uk & us open. volatility is king. Keeping stats opens your
eyes as to what the market movers are up to OR playing"
Fantastic Billy. 100% in agreement with what you said in bold.
Please share a little bit more on "Frequency Distribution". These two are my 2nd and 3rd favorite words too (after "Time").
EDIT - Currently I trade round the clock but my stats tell me trading Asian volatility is not consistent with my understanding of what happens at
London and US open. Is that also your experience? especially with AUDXXX and JPY crosses. The Asian MMs use some different techniques or
influences making it hard to follow the flow in what I am seeing.
michaellobry
Quoting billytt
 Disliked
Quoting michaellobry
 Disliked
Trading system: wick system 1.00 Type: trend and ranged Timeframe: M1 - D1. In this example we take the H1 chart.
Entry: - when: in the H1 chart buy or sell on every candle (this means, every hour you will open an order at exactly
close of previous candle). - buy: if lower wick of previous candle is bigger than the upper wick. - sell: if lower wick of
previous candle is smaller than the upper wick. - TP/SL: 50 pips Stati Hi, i trade using statistics and to be precise
Frequency Distribution... i am not here to be negative
...
@Billy:
I agree with VEEFX. Billy, could you explain in more detail regarding FD?
What is FD:
- Frequency Distribution is well explained here:
Inserted Video
===== PAGE 13/28 =====
S.2
. More links are welcome.
- more and more python traders integrate FD in their system and make use of Taylor's (or Rela's) perspective (https://books.google.nl/books?
id=l7WJTcbxcmQC&pg=PA173&lpg=PA173&dq=taylor+vs+rela+"frequency+distribution"&source=bl&ots=1Uu_p45jyR&sig=qVTqwwm_nTdYt2J2R
zIXzY093zc&hl=nl&sa=X&ved=0ahUKEwjm_4SS-
fbbAhXPGuwKHSWeAbsQ6AEISjAI#v=onepage&q=taylor%20vs%20rela%20"frequency%20distribution"&f=false)
- Frequency distributions are typically used within a statistical context.
- "The frequency chart is referred to as a point-and-figure chart and was created out of a need for floor traders to take note of price action and to
identify trends. The y-axis is the variable measured, and the x-axis is the frequency count. Each change in price action is denoted in X's and O's.
Traders interpret it as an uptrend when three X's emerge; in this case, demand has overcome supply. In the reverse situation, when the chart
shows three O's, it indicates that supply has overcome demand." (https://www.investopedia.com/terms/f...stribution.asp and
https://www.investopedia.com/terms/p...igurechart.asp)
How to trade FD:
Regarding how you trade FD, I presume you are using FD tools and indicators:
- like attached below
- order block (tools) (like
Inserted Video
)
- CoT (to replace volume distribution):
Inserted Video
- trading SB waves instead of Barros Swings
- FD trading in other ways:
*1) to find the wick sizes in pips
2) categorise them into the different sizes:
- 0-1 pips
- 1-5 pips
- 5-10 pips
- 10-20 pips
- 20-100 pips
- the tool counts all the wicks of the previous 240 h4 candles (2 months of data). Then the average of the 240 candles. And count the body of the
h4 candles and average it out.
michaellobry
Frequency distribution indicator.
It will give the stats on how many candles close green & red 1 , 2, 3, 4, 5, 6, etc times in a row in the last x amount of candles.
Example:
100 (will use much bigger sample size in practice) candles Sample
100% Close Green or Red 1 Day in a row
50% Close Greeen or Red 2 days in a row
20% Close Green or Red 3 Days in a Row.
15% close green or red 4 days in a row.
10% close green or red 5 days in a row.
5% close green or red 6 days in a row.
Attached Image
Attached File(s)
===== PAGE 14/28 =====
S.2
S.2
S.2
S.2
MT7_FreqDistIN.ex4   39 KB | 292 downloads
michaellobry
Frequency distribution indicator:
https://www.kreslik.com/forums/theru...n-trade-t12931
Attached Image (click to enlarge)
Attached File(s)
Templates and indicators for HOLO 160804.rar   33 KB | 364 downloads
michaellobry
PDF files about Frequency Distribution (HOLO and cycles in particular).
Attached File(s)
HighestLowestOpenTrade.pdf   162 KB | 348 downloads
HoLo.pdf   623 KB | 359 downloads
market-cycle-times.pdf   108 KB | 368 downloads
HOLO THE RULES.doc   1.7 MB | 359 downloads
TO SLOOW STRATEGY.doc   1.7 MB | 341 downloads
michaellobry
Frequency Distribution indicators
Attached File(s)
TradeBuddy_HOLO_1.ex4   39 KB | 313 downloads
TRS.ex4   3 KB | 243 downloads
HOLO.mq4   4 KB | 371 downloads
fvoe 1.6.3.mq4   18 KB | 327 downloads
JF_TradingTimes.mq4   10 KB | 247 downloads
HO LO Alert.mq4   10 KB | 325 downloads
sqConsecutiveCandlesStatistics.mq4   4 KB | 266 downloads
q-Opn_Line.mq4   2 KB | 262 downloads
smHiLoOpen Lines_v1.2.mq4   11 KB | 295 downloads
michaellobry
FD indicators.
Attached File(s)
Highest Open_Lowest Open_SELL_v1.00.mq4   206 KB | 393 downloads
Highest Open_Lowest Open_BUY_v1.00.mq4   206 KB | 393 downloads
===== PAGE 15/28 =====
S.2
S.2
S.3
S.3
S.3
S.3
VEEFX
Quoting michaellobry
 Disliked
Frequency distribution indicator. It will give the stats on how many candles close green & red 1 , 2, 3, 4, 5, 6, etc times in a row in the
last x amount of candles. Example: 100 (will use much bigger sample size in practice) candles Sample 100% Close Green or Red 1
Day in a row 50% Close Greeen or Red 2 days in a row 20% Close Green or Red 3 Days in a Row. 15% close green or red 4 days in
a row. 10% close green or red 5 days in a row. 5% close green or red 6 days in a row. {image} {file}
Do you have the source code to share for this indicator?
michaellobry
Quoting VEEFX
 Disliked
{quote} Do you have the source code to share for this indicator?
No sorry, I got it from this thread. They only uploaded the ex4 file.
https://www.forexfactory.com/showthread.php?t=526335
michaellobry
Quoting billytt
 Disliked
{quote} FD
Thank you for your reply, Billy. Could you please tell me if this indicator is for (or based on) Frequency Distribution? Or is it just a simple oscillator
that indicates overbought/oversold levels?
https://www.mql5.com/en/market/produ...64#description
michaellobry
FD screenshots.
Attached File(s)
FD charts.rar   1.7 MB | 561 downloads
billytt
Quoting michaellobry
 Disliked
{quote} Thank you for your reply, Billy. Could you please tell me if this indicator is for (or based on) Frequency Distribution? Or is it
just a simple oscillator that indicates overbought/oversold levels? https://www.mql5.com/en/market/produ...64#description
Hi, i do not open any attachments so i cannot answer.
This sort of information is rarely given away as it so useful to trade with and even then their is no need to sell it.
billytt
Quoting VEEFX
 Disliked
{quote}{quote} "the only way to trade is follow the market makers and especially after the uk & us open. volatility is king. Keeping
stats opens your eyes as to what the market movers are up to OR playing" Fantastic Billy. 100% in agreement with what you said in
bold. Please share a little bit more on "Frequency Distribution". These two are my 2nd and 3rd favorite words too (after "Time"). EDIT
- Currently I trade round the clock but my stats tell me trading Asian volatility is not consistent with my understanding of what
happens at London and US...
Time definitely comes into it.
Asian session, i normally use as a bench mark for breakout.
Frequency Distribution...
i cannot post a chart at the moment.
At its simplest.
Example, we trade breakout.
we have 100 candles of the desired time range 1 hour, 2 hour, 4 hour etc.
We have a break and then it either carries on or RETRACES.
===== PAGE 16/28 =====
S.3
S.3
S.3
S.3
S.3
S.3
If it retraces we see the range of the candle wick example 6--6-8-2-6-8-1-6-8 -6-7-etc x 100
in the above case we have 9 wicks which are 9 pips or more and 2 wicks which are 2 or less.
without going into odds,percentages we can see that we have a good chance of entering a trade and making 6 pips or more.
Lets set out target to 4 pips .and voila.
that is method at its simplest, i have stats on stats.
lemercenaire
Quoting michaellobry
 Disliked
{quote}{quote} @Billy: I agree with VEEFX. Billy, could you explain in more detail regarding FD? What is FD: - Frequency Distribution
is well explained here: https://www.youtube.com/watch?v=0YlT...ature=youtu.be. More links are welcome. - more and more python
traders integrate FD in their system and make use of Taylor's (or Rela's) perspective (https://books.google.nl/books?
id=l7WJTcbxcmQC&pg=PA173&lpg=PA173&dq=taylor+vs+rela+"frequency+distribution"&source=bl&ots=1Uu_p45jyR&sig=qVTqww
m_nTdYt2J2RzIXzY093zc&hl=nl&sa=X&ved=0ahUKEwjm_4SS-
fbbAhXPGuwKHSWeAbsQ6AEISjAI#v=onepage&q=taylor%20vs%20rela%20"frequency%20distribution"&f=false)...
Wow - has Hell frozen over? A TRO video allowed on FF!
lemercenaire
Quoting handy148
 Disliked
Some would say - body in direction of profit and wick in direction of loss.
That's awfully Mighty of you
billytt
Quoting handy148
 Disliked
Some would say - body in direction of profit and wick in direction of loss.
i can prove you wrong with that statement,
i made a lot of money with those wicks.
many traders are totally misguided by the lure of hundreds of pips.
its all bolloxs. give me an almost guaranteed 5 points and that is easier than going to an atm machine to withdraw money.
trade well.
lemercenaire
Quoting billytt
 Disliked
{quote} i can prove you wrong with that statement, i made a lot of money with those wicks. many traders are totally misguided by
the lure of hundreds of pips. its all bolloxs. give me an almost guaranteed 5 points and that is easier than going to an atm machine to
withdraw money. trade well.
This quote makes sense to those who know where it comes from, Billy.
It actually refers to a very specific situation and not a general one.
In that situation, it is 100% true (OK Sis.yphus, not 100% lol).
michaellobry
Statistical indicators:
More info: https://www.forexfactory.com/showthread.php?t=189511
Attached File(s)
Market_Statistics_jack1.ex4   34 KB | 300 downloads
TM_MarketStatisticsV2.ex4   133 KB | 320 downloads
Akif_Market_Statistics_Drag_v1.ex4   42 KB | 314 downloads
Akif_Rectangle_Market_Statistics_v2.ex4   32 KB | 327 downloads
michaellobry
===== PAGE 17/28 =====
S.3
Wick indicators.
Attached File(s)
Wick-O-Gram.mq4   3 KB | 332 downloads
WickPercentage.mq4   2 KB | 340 downloads
WickPercentage_arrows .mq4   2 KB | 332 downloads
WickPercentage_arrow_options.mq4   4 KB | 379 downloads
wick0.3.mq4   3 KB | 298 downloads
Net Wick Size.mq4   3 KB | 360 downloads
+++ WickPercentage_adjusted.mq4   2 KB | 320 downloads
michaellobry
Below article discusses combining statistics with trading. What is your opinion? Is this stochastic process a promising approach for statistical
trading?
______________________________
https://www.forexfactory.com/showthread.php?t=562689
Autoregressive Model
Autoregressive (AR) Model is a stochastic process representation for time series. In this model, the next variable of interest (e.g., next price) is
modeled with linear combination of previous value(s) in a stochastic manner,
Attached Image
https://www.forexfactory.com/attachm...1&d=1445294734
where c is a constant, y_t is the variable of interest at time t and e_t is white noise. This stochastic process is usually referred to as an AR(p)
model.
You can find more information about this stochastic process here.
Trading Algorithm
The trading algorithm is summarized below:
0. At the beginning of everyday's candle (i.e., the open price of the day) the algorithm performs the following steps:
1. Compute the trend (e.g., the average) of the past N days' close price, which is called P[] array.
2. Remove the trend from P[], store the result in D[] array.
3. Estimate the parameters of an AR(1) model.
4. Using D[] and the estimated model, perform Dickey-Fuller test. If D[] is stationary, go to (5) else go to (0)
5. Predict the next value of D[] (which is D[N+1]) using the estimated AR(1) model.
6. decision <- empty
6. If D[N+1]>D[N], then decision <- Buy, Close Sell else if D[N+1]<D[N], then decision <- Sell, Close Buy
7. Execute the decision.
8. Go to (0)
Expert Advisor
I developed an EA for testing this trading idea based on AR(1) model. Here is a backtest result from 2000 to 2015 on EURUSD:
Attached Image (click to enlarge)
https://www.forexfactory.com/attachm...1&d=1445296994
Discussion
This trading idea arises a set of questions such as:
 
1. Is this stochastic process (i.e., autoregressive model) a promising approach for statistical trading?
2. How can we improve the trade logic?
3. Does SL/TP settings for trades improve the results?
4. What if we increase p in AR(p) model?
5. Would it be more profitable if we use ARMA(p,q), ARIMA(p,d,q) and ARFIMA(p,d,q) models?
6. What about non-linear autoregressive models?
7. ...
===== PAGE 18/28 =====
S.3
S.3
S.3
S.3
I am attaching the EA here. Hopefully any further improvement in the strategy would result in a newer version of the EA to test, and who knows,
trading live!
Attached File(s)
MathTrader7_AR1_EA.ex4   128 KB | 389 downloads
zigSto.mq4   3 KB | 363 downloads
VEEFX
Quoting michaellobry
 Disliked
Below article discusses combining statistics with trading. What is your opinion? Is this stochastic process a promising approach for
statistical trading? ______________________________ https://www.forexfactory.com/showthread.php?t=562689 Autoregressive
Model Autoregressive (AR) Model is a stochastic process representation for time series. In this model, the next variable of interest
(e.g., next price) is modeled with linear combination of previous value(s) in a stochastic manner, Attached Image
https://www.forexfactory.com/attachm...1&d=1445294734...
I am not a major in Statistics so most of this mumbo jumbo is above my knowledge. All I can add is what I mentioned here... trade outcome and the
stats around what affects the trade outcome is the only thing required to statistically analyze and apply filters...in a recursive/iterative manner.
michaellobry
Quoting VEEFX
 Disliked
{quote} I am not a major in Statistics so most of this mumbo jumbo is above my knowledge. All I can add is what I mentioned here...
trade outcome and the stats around what affects the trade outcome is the only thing required to statistically analyze and apply
filters...in a recursive/iterative manner.
Thank you for your reply.
michaellobry
Is there any research done about pattern recognition regarding scaling?
Introduction:
I mean, look at any EUR/USD chart. If you look at the bigger M-patterns (the ones that are wide in range), then you will recognize this constantly
as it repeats.
I'm specifically interested in:
- aggressive trends
- trends
- ranged markets
My question:
Assume, we are in a ranged market. Are the 3 legs of the M pattern comparable to another M pattern which is also in a ranged market? What can
we conclude from the degree between the legs in the same market condition? Statistically, shouldn't the third leg of the M pattern be the most
profitable to trade since you are trading in the direction of the trend?
michaellobry
Regarding forex science, here is something everyone probably heard of:
Mark Boucher: 70% of a market's moves occurs 20% of the time
Does anyone have more details of this research?
Attached Image (click to enlarge)
===== PAGE 19/28 =====
S.3
S.3
S.3
michaellobry
Forex researches and results:
https://forex-station.com/viewtopic....8271&t=8472309
Part 1
Attached File(s)
Wavelet Decomposition of the Financial Cycle - An Early Warning System for Financial Tsunamis.pdf   1.7 MB | 334 downloads
Comovement of Exchange Rates - A Wavelet Analysis.pdf   293 KB | 375 downloads
Price Lead-Lags in Indian Stock and Futures Market - A Wavelet Based Study.pdf   408 KB | 354 downloads
Adaptive Expectations, Time-Series Models, and Analyst Forecast Revision.pdf   640 KB | 576 downloads
Automated Trading with Genetic-Algorithm Neural-Network Risk Cybernetics - An Application on FX .pdf   648 KB | 559 downloads
Methods for Estimating the Hurst Exponent of Stock Returns.pdf   454 KB | 255 downloads
Predicting Break-Points in Trading Strategies with Twitter.pdf   924 KB | 372 downloads
Forecasting Short Term Interest Rates Using ARMA, ARMA-GARCH and ARMA-EGARCH Models.pdf   79 KB | 464 downloads
Is Arch Useful in High Frequency Foreign Exchange Applications.pdf   317 KB | 299 downloads
GARCH 101 - An Introduction to the Use of Arch & Garch Models in Applied Econometrics.pdf   156 KB | 373 downloads
michaellobry
Forex researches and results:
https://forex-station.com/viewtopic....8271&t=8472309
Part 2
Attached File(s)
A Model for the Federal Funds Rate Target.pdf   519 KB | 570 downloads
MS_Regress - The MATLAB Package for Markov Regime Switching Models.pdf   454 KB | 466 downloads
Forecasting Time Series Subject to Multiple Structural Breaks.pdf   462 KB | 366 downloads
The Three-Pass Regression Filter - A New Approach to Forecasting Using Many Predictors.pdf   584 KB | 444 downloads
Exploring Irregular Time Series Through Non-Uniform Fast Fourier Transform.pdf   844 KB | 498 downloads
A Simple Approximation of Intraday Spreads Using Daily Data.pdf   741 KB | 476 downloads
Non-Linear Forecasting Methods - Some Applications to the Analysis of Financial Series.pdf   295 KB | 398 downloads
Analysis of Financial Time-Series Using Fourier and Wavelet Methods.pdf   400 KB | 466 downloads
Forecasting Volatility.pdf   542 KB | 437 downloads
michaellobry
Quoting Fauzaan
 Disliked
Interesting! Here is a simple EA coded to just do that. I've run couple tests and optimizations and i dont think going for 50 SL and 50
TP is working out very well But... lets see... {file}
I've found some useful information regarding the mq4 EA on page 1.
Source: https://forex-station.com/viewtopic....8271&t=8472666
If you are interested, we could update the EA as per the thread (in the link) suggests:
- only look for candles with bearish wicks when the candle is in a down trend (argument: since it's already going down, there will be first a swing
low (point) (instead of that the market will form a high swing). Vice versa for bullish wicks.
- only look for entries, if the wick appears at S/R:
*after close above upperBB band
*after close above 200 EMA
===== PAGE 20/28 =====
S.3
*double/triple top/bottom breakout
*after [12] bullish candles
*trendline breakout of channel using the indicator: market profile.ex4
I would really appreciate it, if you are able to update the EA.
Attached Image (click to enlarge)
michaellobry
Quoting handy148
 Disliked
Some would say - body in direction of profit and wick in direction of loss.
This screenshot shows the importance of candle wicks in combination with real volume tick data (not the default MT4 volume indicator). You can
download this volume indicator here:
1. https://forex-station.com/viewtopic....8480&t=8430755
2. click on 'volume indicators'
Attached Image (click to enlarge)
===== PAGE 21/28 =====
S.3
S.4
vladi1979
Quoting michaellobry
 Disliked
Is there any research done about pattern recognition regarding scaling?
I am currently studying possible use of Neural Networks using MACD indicator to find a dominant pattern automatically. I found one simple way to
do data scaling of that indicator. Basically I tried to divide indicator values coming from JPY by 100 to get the right scale compared to other pairs
michaellobry
Quoting vladi1979
 Disliked
{quote} I am currently studying possible use of Neural Networks using MACD indicator to find a dominant pattern automatically. I
found one simple way to do data scaling of that indicator. Basically I tried to divide indicator values coming from JPY by 100 to get
the right scale compared to other pairs
Thank you for your wisdom. I see you have really thought about finding a dominant pattern in the MacD.
- One may suggest that all patterns are Waves (1-2-3-4-5-A-B-C) or harmonic patterns. But I advocate differently, I say they are simply all M
patterns in different fonts which makes it only logical that a 'font recognition robot' (not a trading robot, but a program that reads handwritten input
from academic thesis papers by using Average-Pooling or similar Deep Learning techniques) adds as much value to it as, what you use to
calculate (dividing 100). Have you ever used a font recognition program? If yes, do you see the effectiveness if used on the GBP/JPY or EUR/USD
chart?
- Regarding your reply on dividing by 100. Okay, are you comparing all (major) currencies with the JPY? You mention 'dividing' in your formula,
where I can only assume you would add a multiplication to your calculation as well. What do you multiply? Could you explain more about your
formula as to recognize a pattern (in the MacD)?
- Neural networks, a concept where you add lotsize to probability aspects, am I summing it up correctly? Are you willing to list the different values
(probability vectors and dropouts to avoid overfitting) in your concept (HWL) of pattern recognition with neural networks?
===== PAGE 22/28 =====
S.4
S.4
S.4
S.4
vladi1979
I was just thinking to answer your question about scaling.. My message was that sometimes it's enough just to divide by the number...
regarding my use case I am training neural network to use pattern of indicator to predict price change directly. Because of the fact that I wanted to
use data from major 28 pairs I had to use JPY as well. To align my data I had to divide price and macd indicator by 100...
I believe that my system just mimics traditional algotrading when optimization is used to find the best indicator parameters... I can't say it's a holy
grail system more over even a blackbox however it's allowing to fully automate the trading process
I am still testing the system however honestly I have never got so good results with fully mechanical systems yet. In 3 weeks it has made 148
trades on demo account and still positive PnL
michaellobry
ah yes I see now.
Great that you have a fully automated expert.
Which neural network training or tutorial do you watch? On youtube? I'm interested. I want to learn how you 'weigh' additional probabilities for your
entries/exits.
vladi1979
Quoting michaellobry
 Disliked
Which neural network training or tutorial do you watch.
In general I am using R to interact with MT4 and use h2o framework for deep learning capabilities... I have developed it by teaching 'Computer and
data science using algorithmic trading' feel free to check the entire story on my website
lassame
I use this EA to earn rebate
Some Broker rebate 10$/lot
Balance: 100$
Use M1 Candle,
USDCHF
Tp: 75,
SL 75,
Lot:0.1,
Leverage 1:3000
it will open every 1minute, open very much order
Example:
it open 278 order
0.1lot x 278 = 20.78x 10$=278$
i need to put some fuction to EA
- Time Sesson
- Time to Close all Opened order
Attached Image (click to enlarge)
Attached File(s)
===== PAGE 23/28 =====
S.4
S.4
S.4
S.4
S.4
S.4
wicksys.ex4   8 KB | 551 downloads
NPSystems
Quoting lassame
 Disliked
I use this EA to earn rebate Some Broker rebate 10$/lot Balance: 100$ Use M1 Candle, USDCHF Tp: 75, SL 75, Lot:0.1, Leverage
1:3000 it will open every 1minute, open very much order Example: it open 278 order 0.1lot x 278 = 20.78x 10$=278$ i need to put
some fuction to EA - Time Sesson - Time to Close all Opened order {file} {image}
Do you have the source code?
Your rebate program is probably a monthly cash back. Because if you register two broker accounts under your name and refer yourself to get full
cash-back, once the broker finds out, they'll probably remove all your rebates and probably close your account. That's basically the same as taking
money out of their pockets without any added value.
Even if the rebate program is legit, they call this "churning" since it's not really trading and it's not accepted by brokers so those rebates will
probably get voided.
lassame
Quoting NPSystems
 Disliked
{quote} Do you have the source code? Your rebate program is probably a monthly cash back. Because if you register two broker
accounts under your name and refer yourself to get full cash-back, once the broker finds out, they'll probably remove all your rebates
and probably close your account. That's basically the same as taking money out of their pockets without any added value. Even if the
rebate program is legit, they call this "churning" since it's not really trading and it's not accepted by brokers so those rebates will
probably get voided.
this idea for IB Program
I run EA on my client's Account to make commission
Here is Source Code
Attached File(s)
wicksys.mq4   7 KB | 665 downloads
NPSystems
Quoting lassame
 Disliked
{quote} this idea for IB Program I run EA on my client's Account to make commission Here is Source Code {file}
What modifications are you looking to do for the EA? Because there are utilities for closing all in different situations.
coyoten1
Thanks for bringing out this discussion. Do you think to build an EA is more effective to for large volume data collection and analysis?
gian97
As long as you do the tests on qualitative data with written n / a or less than 90%
you will never understand if it works or not.
Results with qualitative data can change drastically, just download the alpari demo and you will have them.
ntk
Quoting lassame
 Disliked
I use this EA to earn rebate Some Broker rebate 10$/lot Balance: 100$ Use M1 Candle, USDCHF Tp: 75, SL 75, Lot:0.1, Leverage
1:3000 it will open every 1minute, open very much order Example: it open 278 order 0.1lot x 278 = 20.78x 10$=278$ i need to put
some fuction to EA - Time Sesson - Time to Close all Opened order {file} {image}
Does your word mean, your client's accounts would go bust, and you as IB can still collect the commission and lot rebates? is it much better than
profit sharing if you trade your client account successfully?
===== PAGE 24/28 =====
S.4GotyMetal
I made a pinescript indicator (tradingview) and MOST of times, bull trends have more UPPER wicks and bear trens have more LOWER wicks, no
matter the timeframe.
Green are bottom wicks, red are upper wicks.
Pics are from EURUSD in 15M, 1H, 4H and daily.
Attached Image(s) (click to enlarge)
===== PAGE 25/28 =====

===== PAGE 26/28 =====

===== PAGE 27/28 =====

===== PAGE 28/28 =====
```
