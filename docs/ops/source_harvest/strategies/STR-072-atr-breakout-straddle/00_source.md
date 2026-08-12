# STR-072-atr-breakout-straddle — Source extract (verbatim pypdf text, 2026-07-25)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/20 =====
S.1
ATR Break Out
ForexFactory Thread 562470 — 60 Beiträge, Eröffnung: erste 3 Seiten
abokwaik
Attached Image (click to enlarge)
RISK WARNING
All Expert Advisors (Robots), Indicators, Trading Systems posted by me
 are Trading Tools developed for Experimental purposes.
Using any of these tools on a real account carries a high degree of risk.
I will not be held responsible for any losses incurred by any one uses these tools.
ATR Break Out (ABO) Trading System is an automated trading system (aka EA, bot, robot), that uses Average True
Range (ATR) break out as an entry signal in the direction of the break out.
ABO is using Pending Stop Orders which are calculated based on ATR parameters at the start of new bar.
Un-triggered orders are deleted before placing new orders.
ABO robot was born at the Robot Lab Project and moved to this dedicated thread to grow on its own.
The system uses ATR multipliers (same concept implemented in Big Candle) for Break Out, Stop Loss, Take Profit
and Trailing Stop.
Position Size can be fixed or automatically calculated based on Risk Percentage and Stop Loss for each trade.
MACD and RSI filters (suggested by auvergnat78) can be optionally applied.
System Inputs :
Attached Image (click to enlarge)
===== PAGE 2/20 =====
Note : Default ATR period 50
Sample Test Screen Shot :
Attached Image (click to enlarge)
===== PAGE 3/20 =====
Sample Test EUR/USD H1 2015 with default settings.
Attached Image (click to enlarge)
===== PAGE 4/20 =====
S.1
VERSION CONTROL :
Version 4: Post # 1.
Version 5 (final): Post # 70.
Version 6 (filters) : Post # 104
Attached File(s)
ABO_04.ex4   16 KB | 4,103 downloads
sbenichou1
Nice work Abokwaik!!
How can i fix the mismatched chart error?
===== PAGE 5/20 =====
S.1
S.1
S.1
S.1
S.1
tx
S
abokwaik
Quick Answer : By Loading better historical data.
OK. Few words about back testing.
 
Back Testing is not a proof of profitability
It is the first tool I use to validate a new trading idea, and make sure the robot is working as per the rules.
A good ROI% vs DD% percentage (i.e 2 and above) is an initial indication that the robot may survive market
changing conditions, specially when applied to long period and generated good number of trades (min. 30).
The purpose of using Filters is to minimize false signals (loosing trades), it will reduce the number of trades
taken.
Back Testing Data Quality importance increases for lower time frames and decreases for higher time frames
Back Testing can be used to reach settings sets that can be used later on in forward testing or live trading
So don't mind the mismatched chart errors.
The second testing phase of a robot will be by forward testing it on a demo account.
If it performs well for at least 30 trades, only then you may try it on a real account.
Central4
Hi Abokwaik
Thank you for your development of this nice Tool.
Can i use it for other pairs? or only EURUSD.
Regards
abokwaik
Demo Trade Explorer Added using a crazy set on EUR/USD H1
Attached File(s)
abo_crazy_set.rar   < 1 KB | 1,813 downloads
sbenichou1
Tx Abokwaik but i already downloaded all history available.
broker is FXCM.
Still mismatch error
S
wswi
trading time is based on broker's time or local time computer?
===== PAGE 6/20 =====
S.1
S.1
S.1
S.1
S.1
abokwaik
Quoting wswi
 Disliked
trading time is based on broker's time or local time computer?
Broker time.My settings for EURUSD is for European session.
Reamasesa
Nice one just like all of your work.
Subscribed.
damonl
It looks very promising for you. I wish you the best in your forward testing, and hopeful for you that you have created
a winner
abokwaik
Quoting Central4
 Disliked
Hi Abokwaik Thank you for your development of this nice Tool. Can i use it for other pairs? or only
EURUSD. Regards
Hi Central,
Of course you can use it on other instruments.
Its a momentum-based strategy, so it better be used with good-trending instruments.
I think it should do will with Gold.
abokwaik
Quoting sbenichou1
 Disliked
Tx Abokwaik but i already downloaded all history available. broker is FXCM. Still mismatch error S
If you are interested in back testing data quality you can gooogle it and you'll find many resources about the issue.
However spending too much time back testing is not recommended.
The system idea is very simple (leaving the filters aside), actually the first version was with no filters.
And the settings I am using for forward testing are also with no filters (except trading time).
So the system idea is to follow the market in the direction of a Sizable break out based on multiples of average
candle size (ATR).
Take a look at the current GBP/USD H1 chart, where ATR(50) = 20, and using 2 x ATR for Break Out, 2 x ATR for
Stop Loss, and 4 x ATR for Take Profit.
===== PAGE 7/20 =====
S.1
Does it make sense ?, if yes, start Forward Testing it on a demo account.
Attached Image (click to enlarge)
abokwaik
As the trade explorer dosn't show current orders (because no trades closed yet).
Here are the pending orders placed at EUR/USD H1 as per "crazy_set".
Attached Image (click to enlarge)

===== PAGE 8/20 =====
S.1
S.1
S.1
S.1
S.1
If no order is not triggered within the hour, the robot will delete the pending orders, and open new ones on the new
hour based on the then ATR values. And so on until a pending order is triggered.
EDIT: to make it clearer
pakpac
Quote
 Disliked
If the order is not triggered within the hour, the robot will delete it, and open a new one on the new
hour based on the then ATR values. And so on until a pending order is triggered.
I cant see any open pending trades.
abokwaik
Quoting pakpac
 Disliked
{quote} I cant see any open pending trades.
a Terminology issue maybe ?
When I say order I mean Pending Order.
When I say trade I mean Market Order.
This system is only using Pending Orders.
I the Market comes to us and triggered the Pending Order then it will become a Trade.
pakpac
Yes, sorry for my english, i understood it.
Backtesting is working, i can see pending orders, but forward doesn't open any pending orders. Startting hour(0-24)
is ok, risk pct is ok. Should i atach atr to screen? I dont think so.
abokwaik
I just opened a dummy trade on GPB/USD and closed it with 0 profit, Just to enable the Trade Explorer.
abokwaik
Quoting pakpac
 Disliked
Yes, sorry for my english, i understood it. Backtesting is working, i can see pending orders, but
forward doesn't open any pending orders. Startting hour(0-24) is ok, risk pct is ok. Should i atach atr
to screen? I dont think so.
Make sure you had enabled "Allow Live Trading".
Can you see a Smiley Face beside the EA name on the chart ?
===== PAGE 9/20 =====
S.1
S.1
S.2
S.2
S.2
S.2
pakpac
Yes, thats fine. I will wait to see if anyone else having same problem. And i attached EA to several pairs. Will see...
Thank you.
abokwaik
I've noticed that one of the old pending orders was not deleted.
I will check that and update.
abokwaik
This an update with :
Fixed Bug of Pending Order Deletion
Position size is calculated based on Free Margin instead of Account Balance.
Attached File(s)
ABO_05.ex4   16 KB | 1,021 downloads
imifx
Subscribed
EA attached to 5 charts on my vps TF H1, GA, EA, AU, GU, EU
Current Order
http://prntscr.com/8sv3ho
abokwaik
In order to catch more trades, I have attached the robot to GBP/USD M30 and GOLD M15 with the same "crazy
settings" used for EUR/USD H1.
Kubiasty
Is it correct?
I have oppened 6 pairs and only 1 waiting order
Is it looks ok?
Attached Image (click to enlarge)
===== PAGE 10/20 =====
S.2
S.2
S.2
or i should change timeframe?
abokwaik
Quoting Kubiasty
 Disliked
Is it correct? I have oppened 6 pairs and only 1 waiting order Is it looks ok? {image} or i should
change timeframe?
Did you enable any FILTERS ?
Yazd
A great work!
How many trades on average one can expect from this EA to open per day?
Kubiasty
Quoting abokwaik
 Disliked
{quote} Did you enable any FILTERS ?
After 1h waiting, there are 6 waiting orders
Attached Image (click to enlarge)
===== PAGE 11/20 =====
S.2
S.2
S.2
abokwaik
Quoting Kubiasty
 Disliked
{quote} After 1h waiting, there are 6 waiting orders {image}
No, it is not related to 1h waiting, it depends on which filters (MACD, RSI) you have enabled.
If you use the default inputs that came with the ABO then RSI is already enabled, which is OK.
For this reason you have ONLY one pending order per pair (not 2 as in my Trade explorer, because I disabled
(ignored) all filter in my crazy settings).
Enjoy the ride.
Kubiasty
Quoting abokwaik
 Disliked
{quote} No, it is not related to 1h waiting, it depends on which filters (MACD, RSI) you have enabled. If
you use the default inputs that came with the ABO then RSI is already enabled, which is OK. For this
reason you have ONLY one pending order per pair (not 2 as in my Trade explorer, because I disabled
(ignored) all filter in my crazy settings). Enjoy the ride.
I put settings normal, i didnt change anything, i just drag and put into chart your strategy robot.
Cheers,
Thanks.
abokwaik
Quoting Yazd
===== PAGE 12/20 =====
S.2
S.2
S.2
S.2
 Disliked
A great work! How many trades on average one can expect from this EA to open per day?
It depends on pair volatility for the day. AND the Time Frame used. AND the ATR multiplier used.
So for example if you are using H4 and set ATR multiplier to 3 you can hardly get one trade per week.
While if yor use M5 and set ATR multiplier to 3 you'll probably get 5 trades a day.
As you can see from the attached Trade Explorer Gold - M15 triggered 2 orders (as I am using multiple orders per
pair).
While EUR H1 and GBP M30 didn't trigger any order yet.
Atokys
Think clearly Abok, your backtest covers only a short period where the EUR/USD demonstrated excellent conditions
for momentum strategies.
For a more rigorous test, consider testing over a longer period of time and over a wider range of instruments.
abokwaik
Quoting Atokys
 Disliked
Think clearly Abok, your backtest covers only a short period where the EUR/USD demonstrated
excellent conditions for momentum strategies. For a more rigorous test, consider testing over a longer
period of time and over a wider range of instruments.
Thanks for your input.
This why I use ATR and not Fixed Number of Pips. :nerd:
Atokys
Quote
 Disliked
Gold - M15 triggered 2 orders (as I am using multiple orders per pair).
While EUR H1 and GBP M30 didn't trigger any order yet.
Whats the point of altering the strategy to fit different instruments?
Why not fix your granularity?
abokwaik
Quoting Atokys
 Disliked
{quote} Whats the point of altering the strategy to fit different instruments? Why not fix your
granularity?
All instruments are using the same settings (check post # 23). i.e. with Multiple Orders set to 99 (abo_crazy_set
attached to post # 5)
I just used different time frames for different pairs as we are Forward Testing the system.
===== PAGE 13/20 =====
S.2
S.2
S.2
Atokys
Quoting abokwaik
 Disliked
{quote} All instruments are using the same settings (check post # 23). I just used different time frames
for different pairs
Yes, my point is that its essentially a different strategy when you do that. So, why use a different 'time frame' for
different pairs?
Quote
 Disliked
as we are Forward Testing the system.
Hmm, why forward test? Its just like backtesting except that you're forcing yourself to wait for the data.
Quote
 Disliked
i.e. with Multiple Orders set to 99 (abo_crazy_set attached to post # 5)
Forgive my questioning, but what does this mean?
abokwaik
Quoting Atokys
 Disliked
{quote} Yes, my point is that its essentially a different strategy when you do that. So, why use a
different 'time frame' for different pairs?
For Fun
Quoting Atokys
 Disliked
{quote} Hmm, why forward test? Its just like backtesting except that you're forcing yourself to wait for
the data.
I have so much free time I don't know what to do ....
Quoting Atokys
 Disliked
{quote} Forgive my questioning, but what does this mean?
It means
I think this clearly answers all your questions
Atokys
Quoting abokwaik
 Disliked
answers all your questions
===== PAGE 14/20 =====
S.2
S.2
Yup, it all makes sense now.
diamonddbw
Quoting abokwaik
 Disliked
{quote} For Fun {quote} I have so much free time I don't know what to do .... {quote} It means I think
this clearly answers all your questions
+++++++++++++++++++++++++++++++++++++++++++++++++++
I'm IN! If I can't have fun with life, I'm not awake.
abokwaik
Quoting Atokys
 Disliked
{quote} Yes, my point is that its essentially a different strategy when you do that. So, why use a
different 'time frame' for different pairs? {quote} Hmm, why forward test? Its just like backtesting
except that you're forcing yourself to wait for the data. {quote} Forgive my questioning, but what does
this mean?
Quoting Atokys
 Disliked
{quote} Yup, it all makes sense now.
OK Atkoys.
Reading your last post, I assume you were serious.
If so, I am sorry for my impatience.
Your Question : Yes, my point is that its essentially a different strategy when you do that. So, why use a different
'time frame' for different pairs?
Market is of fractal nature. So in principle if a system works on a certain time frame, it should work on
others, provided that transaction cost doesn't become an issue.
Your Question : Hmm, why forward test? Its just like backtesting except that you're forcing yourself to wait for the
data.
Forward Testing a New System (Specially an EA) on Demo is ESSENTIAL in my opinion before going Real:
It will reveal any bugs not discovered in back testing.
It will give you a feel how the system will work on a real account, specially the WAITING issue
Accuracy will be much better than back testing
Your question about (Multiple Orders set to 99 (abo_crazy_set attached to post # 5)
If your're inquiring about 99 orders: The EA has in input for Maximum Allowed Orders, so I set it to the
Maximum which is 99 trades active at one time.
If your're asking about the set file it self: It is a setting file that is used with the EA Linked to the explorer,
so that everyone knows my settings. The "crazy" name, is just a name. I used "crazy" as it will open
multiple orders simultaneously.
===== PAGE 15/20 =====
S.2
S.3
S.3
 Regards
Atokys
Quoting abokwaik
 Disliked
Market is of fractal nature. So in principle if a system works on a certain time frame, it should work on
others, provided that transaction cost doesn't become an issue.
That is obvious and an easy conclusion to arrive at but few people realise that the higher fractal dimensions lead the
lower ones.
When you scale your system down a 'time frame' you are simply reducing the amount of data required for a trigger
while increasing the granularity.
Quote
 Disliked
Forward Testing a New System (Specially an EA) on Demo is ESSENTIAL in my opinion before going
Real: ....
It will give you a feel how the system will work on a real account, specially the WAITING issue
Accuracy will be much better than back testing
Actually no. Thats only a myth.
The only kind of 'forward testing' that is notably different from plain old backtesting is walk-forward analysis. The
kind of forward testing that you allude to is simply akin to performing a backtest limited to only recent data. This
defeats the purpose of testing a system for robustness.
Quote
 Disliked
The EA has in input for Maximum Allowed Orders, so I set it to the Maximum which is 99 trades active
at one time.
Thats quite disconcerting.
imifx
For last 11 hr, Robot has opened a lot Order but deleted all, no order trigger so far and below is SS for cancelled
orders.
http://prntscr.com/8t22ui
imifx
[quote=Atokys;8547826]{quote}
{quote} Actually no. Thats only a myth.
how ??
 
1. It will reveal any bugs not discovered in back testing.
2. It will give you a feel how the system will work on a real account, specially the WAITING issue
===== PAGE 16/20 =====
S.3
S.3
S.3
S.3
3. Accuracy will be much better than back testing
abokwaik
Quoting imifx
 Disliked
For last 11 hr, Robot has opened a lot Order but deleted all, no order trigger so far and below is SS for
cancelled orders. http://prntscr.com/8t22ui
Can you post your settings and time frame used ?
imifx
Quoting abokwaik
 Disliked
{quote} Can you post your settings and time frame used ?
I am using default setting and H1 tf.
abokwaik
Quoting imifx
 Disliked
{quote} I am using default setting and H1 tf.
In default settings the Break Out ATR Multiplier = 3 and RSI Filter = 1 (yes)
So you will not get signals very often.
I even use Break Out ATR Multiplier = 2 and RSI Filter = 0 (ignore) on EUR/USD H1 and I didn't get any signal
yet.
Default settings could fire most probably at Red News time.
So my suggestion is to loosen the settings a little bit if you want to get more signals.
However, look at my explorer where I used ABO on Gold M15 ---> many false signals in a range market.
imifx
Quoting abokwaik
 Disliked
{quote} In default settings the Break Out ATR Multiplier = 3 and RSI Filter = 1 (yes) So you will not get
signals very often. I even use Break Out ATR Multiplier = 2 and RSI Filter = 0 (ignore) on EUR/USD
H1 and I didn't get any signal yet. Default settings could fire most probably at Red News time. So my
suggestion is to loosen the settings a little bit if you want to get more signals. However, look at my
explorer where I used ABO on Gold M15 ---> many false signals in a range market.
OK, thank you,
I got a SL hit on gbpusd buy
===== PAGE 17/20 =====
S.3
S.3
S.3
abokwaik
ABR (with my settings i.e : SL@4 , TS@6 , TP@20 with multiple orders) is a compounding trend following system, it
will suffer many small losses before catching a trend, and when it does, few winners should be able to recover from
previous losses and add to equity.
imifx
Quoting abokwaik
 Disliked
ABR (with my settings i.e : SL@4 , TS@6 , TP@20 with multiple orders) is a compounding trend
following system, it will suffer many small losses before catching a trend, and when it does, few
winners should be able to recover from previous losses and add to equity.
you must post a screen shot for your setting both aggressive and normal
abokwaik
Normal Settings (used in back tests)
Attached Image (click to enlarge)

===== PAGE 18/20 =====
S.3
S.3
S.3
Aggressive Settings (used in forward test)
Attached Image (click to enlarge)
Kubiasty
Result from yesterday:
-50 pips USDCAD
-50 pips GBPUSD
Kubiasty
I do not recommend this strategy. It takes only looses after couple of days.. noone was on profit. sorry
imifx
Great day today with ATR-Breakout Aggressive mode
$600 close profit
$870 floating profit
===== PAGE 19/20 =====
S.3
S.3
S.3
S.3
S.3
Update - If trade management features may added to EA.
Keep up the good work !!!
Attached Image(s) (click to enlarge)
abokwaik
Closed all positions "manually" for end of week. 15% return in 1st week with 7% max dd. More analysis of robot
performance tomorrow. Have a nice weekend.
keziahpie
Hi abokwaik,
how many pairs are you testing with the aggressive mode?
Thanks
abokwaik
Quoting keziahpie
 Disliked
Hi abokwaik, how many pairs are you testing with the aggressive mode? Thanks
EUR/USD, GBP/USD, USD/JPY, USD/CAD, Gold. I removed GBP/JPY after one trade.
I am gonna do some changes on the pairs traded for next week.
Reamasesa
Hi,
Are there any settings that are somewhere in between the aggressive and default settings? Something that will
trade moderately but without waiting long between trades?
Thanks.
abokwaik
===== PAGE 20/20 =====
S.3
S.3
S.3
Quoting Reamasesa
 Disliked
Hi, Are there any settings that are somewhere in between the aggressive and default settings?
Something that will trade moderately but without waiting long between trades? Thanks.
Hi Reamasesa,
My problem is that I don't have much time to do all types of testing, this is why I share my ideas and EAs here at FF
so that the people who have some free time and resources do the testing and share their findings.
Reamasesa
Quoting abokwaik
 Disliked
{quote} Hi Reamasesa, My problem is that I don't have much time to do all types of testing, this is why
I share my ideas and EAs here at FF so that the people who have some free time and resources do
the testing and share their findings.
Hi,
Thanks for replying.
I know but I'm pretty new to ATR so I'm not sure where to begin or should I just play with the ATR values and hope
for the best.
Thanks again.
abokwaik
Quoting Reamasesa
 Disliked
{quote} Hi, Thanks for replying. I know but I'm pretty new to ATR so I'm not sure where to begin or
should I just play with the ATR values and hope for the best. Thanks again.
ATR Multipliers, Follow Last Bar Direction, MACD and RSI filter will affect the results.
In addition to Trading Time and Max Orders.
So you can try out different settings for these parameters of different pairs and time frames.
redrose
Hi .I have been reading your few ea's all looks good .Could you please add external parameters to have Minimum
Lock profit = X Pips and once profit pips are locks so that we should not have some pips in profit better then loss.
trailing should activate too say example I would say when in profit 20 Pips Minimum lock profit should be 2 pips and
when we cross like 30 pips trailing should activate in step after minimum is lock . Just and idea to save your profit
when in possitive .Thanks```
