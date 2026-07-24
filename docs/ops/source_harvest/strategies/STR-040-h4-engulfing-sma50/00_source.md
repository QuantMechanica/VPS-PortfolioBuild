# STR-040-h4-engulfing-sma50 — Source extract (verbatim pypdf text, 2026-07-24)

PDF: G:\My Drive\QuantMechanica - VPS Portfolio Build\Web-Sources$2.pdf

```

===== PAGE 1/11 =====
S.1
S.1
S.1
Trading EA shell by SteveHopwood
ForexFactory Thread 282290 — 39 Beiträge, KOMPLETT (2 Seite(n))
SteveHopwood
Attached is the EA shell I use to create the trading robots I code.
Instructions for use are included early on in the code. You strip out what you do not want and add any extras that you do want.
I am not claiming to be some sort of coding genius. Far from it; there are professional coders at FF whose work makes me look silly. I am a pianist who
has learned to code in pursuit of some wealth to make up for the wealth I do not derive from the job I love so much. En route, I have picked up a fewcoding skills that I offer to anyone who can make use of them.
Advice I offer to beginner coders is:
 
comment everything. A chunk of code whose purpose seems so screamingly obvious that it cannot possibly justify the time commenting, will takeyou an hour to decipher in two months time. Guess how I know.
learn the basics then start a project. Start with something simple, such as the trigger being the cross of a slower ma by a quicker one. Perhapsmake this the setup, and the trigger is x candles heading in the right direction. Involve some management features and perhaps some sutomatic
lot-sizing for money management. My code is open source so anyone can pinch it freely, but better for you if you work out your own salvationbecause you will understand better what is going on.
Develop your own methods of presenting on-screen information that tell you what is going on inside the code as well as providing valuablefeedback.
As you master each individual step, try to make it into a universal function that you can add to your own shell ea, from which you can code a newbot in minutes - no point in re-inventing the wheel every time you have an idea and want an ea to try it out, This is how my shell ea evolved and I
am still adding to it.Once you have the basics, delve into drawing trend lines etc on the charts via your code. To get started, type ObjectCreate into the mql4 editor,
highlight it and press F1 for help; this will present the list of commands used to create and manipulate shapes on your charts, confusingly knownas 'objects'.
Remember Google. When stuck, google the problem. If it is solvable, then someone out their has both solved it and posted the solution.
Feel free to use the code here in any way that suits you, so long as you distribute your code free of charge to the users. Charge for using it, and I will sue
the socks off you.
Shell user guideThis is a user guide template that you can use to quickly create a user guide if you want to release your EA here at FF. It contains a brief description of
most of the EA functions, so you remove those you do not want and add in anything new. Inside the zip is the Open Office document that you can edit toproduce your own pdf.
OpenOffice is freeware and every bit as good as any of its paid-for rivals. Download it from http://www.openoffice.org/
Private EA coding
I receive may requests to code EA's. I will do so free of charge so long as I am able to share the EA and trading system here at FF. Most of what I havelearned to do as a coder, I have learned from contributors here. Sharing my work with them is my way of giving back in return for what I have gained. I
need to have some interest in the project to take it on; a period of successful live trading with the system guarantees my interest.
I will also code EA's for traders who want their EA kept private. For this, I charge a fee of $100 payable into my Paypal account. I charge so littlebecause I am not a professional programmer. EA's I code for you will have bugs that we will have to hunt down and eradicate. I may easily
misunderstand the brief that you send me. I shall need your patience as I work towards the difference between what I think you have asked for, and whatyou have actually asked for.
Should you need a more professional programmer, then contact hanover. He will charge a lot more (I seem to recall him quoting a development fee $70
per hour somewhere) but will send you code that is an accurate and bug-free representation of your brief.
Attached File(s)AllAverages_v2.1 cc.mq4   15 KB | 1,656 downloads | Uploaded Oct 15, 2011 6:56pm
Shell user guide.zip   142 KB | 2,112 downloads | Uploaded Oct 27, 2011 1:26amGeneric auto trading robot by Steve Hopwood.mq4   138 KB | 2,310 downloads | Uploaded Nov 14, 2011 12:42pm
newark18
Steve, again this is a great contribution. Now I have no reason to experiment. Thanks again.
SteveHopwood
Quoting newark18
 DislikedSteve, again this is a great contribution. Now I have no reason to experiment. Thanks again.
===== PAGE 2/11 =====
S.1
S.1
S.1
Have fun. When you come up with improvements, I can include them within the shell.
newark18
This is a question to those who might be familiar with Steve's shell. I am not directly asking Steve for fear of my life.
The EA is supposed to take all bullish engulfing candles above 50 SMA and all bearish engulfing candles below 50 SMA. Ideally, I would like to set SL at
the low of the bullish engulfing candle for a buy and at the the high of the bearish engulfing candle for a sell. All I would like to close all buys when an H4candle closes below SMA and all sells when H4 candle closes above SMA. The EA does not seem to like the way I am programming these rules.
And currently, the EA only opens one trade at a time. I would like it to open multiple ones. I know that there are comments that refer to this but I can't
figure out how to change it to make it do what I want.
I'm trying but looks like I need some help. Anyone want to help a crappy coder out?Attached File(s)
James SMA v2.mq4   64 KB | 741 downloads
newark18
Here is the pertinent entry code. For some reason, the EA cannot modify the order to add SL and TP (getting Error 130). My TP code (the one
commented out) is definitely off as I haven't figured out how to correctly equate my exit criteria into a price. I also cannot get more than one entry at thesame time.
//Long
if(iClose(NULL, PERIOD_H4,2) < iOpen(NULL, PERIOD_H4,2) && //bearish close
iClose(NULL, PERIOD_H4,1) > iOpen(NULL, PERIOD_H4,2) && //engulfingiClose(NULL, PERIOD_H4,1) > iOpen(NULL, PERIOD_H4,1) && //bullish (don't think this is needed)
iClose(NULL, PERIOD_H4,1) > iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) //above SMA50)
{//take = iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1);
stop = iLow(NULL, PERIOD_H4,1); //Low ofif (TakeProfit > 0) take = NormalizeDouble(Ask + (TakeProfit * Point), Digits);
//if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);type = OP_BUYSTOP;
//price = Ask;price = iHigh(NULL, PERIOD_H4,1);
SendTrade = true;}//if (Ask > 1000000)
//Short
if(iClose(NULL, PERIOD_H4,2) > iOpen(NULL, PERIOD_H4,2) && //bullish closeiClose(NULL, PERIOD_H4,1) < iOpen(NULL, PERIOD_H4,2) && //engulfing
iClose(NULL, PERIOD_H4,1) < iOpen(NULL, PERIOD_H4,1) && //Bearish close (dont' think this is needed)iClose(NULL, PERIOD_H4,1) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) //below the SMA 50
){
//take = iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1);stop = iHigh(NULL, PERIOD_H4,1);
if (TakeProfit > 0) take = NormalizeDouble(Ask + (TakeProfit * Point), Digits);//if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
type = OP_SELLSTOP;//price = Bid;
price = iLow(NULL, PERIOD_H4,1);SendTrade = true;
}//if (Ask < 0)
SteveHopwood
Quoting newark18
 DislikedHere is the pertinent entry code....
Fantastic to see you doing this for yourself. Those of us who are not professional coders have only recourse to 'doing it' in order to learn.
Here is a tip. When posting code, wrap it in code tags (the # icon) so that the formatting is preserved and people can read it more easily.
Comparebool DoesTradeExist()
{
TicketNo = -1;
===== PAGE 3/11 =====
if (OrdersTotal() == 0) return(false);
for (int cc = OrdersTotal() - 1; cc >= 0 ; cc--){
if (!OrderSelect(cc,SELECT_BY_POS)) continue;
if (OrderMagicNumber()==MagicNumber && OrderSymbol() == Symbol() ){
TicketNo = OrderTicket();return(true);
}//if (OrderMagicNumber()==MagicNumber && OrderSymbol() == Symbol() )}//for (int cc = OrdersTotal() - 1; cc >= 0 ; cc--)
return(false);
}//End bool DoesTradeExist()
with
Inserted Code
bool DoesTradeExist(){
      TicketNo = -1;
      if (OrdersTotal() == 0) return(false);
      for (int cc = OrdersTotal() - 1; cc >= 0 ; cc--)
   {      if (!OrderSelect(cc,SELECT_BY_POS)) continue;
            if (OrderMagicNumber()==MagicNumber && OrderSymbol() == Symbol() )      
      {         TicketNo = OrderTicket();
         return(true);               }//if (OrderMagicNumber()==MagicNumber && OrderSymbol() == Symbol() )      
   }//for (int cc = OrdersTotal() - 1; cc >= 0 ; cc--)
   return(false);
}//End bool DoesTradeExist()
to get an idea of how much more readable it becomes.
Now, to take the easiest bit of your query first: if you want a bot to take multiple trades, you have to tell it to do so. As coded, the shell will send one trade
only, so either:
 
1. copy/paste the order sending trade code for each trade you want to send, OR2. put the order-sending code into a loop that increments whatever you want incrementing
As to the problem you have with the take, what you are trying to send is nonsense. In English,//take = iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1);
would be: "take = the close of the current H4 candle less than then SMA (list of criteria) at the last candle"
Another tip, referring to the above: before building complex expressions, learn to write simple ones.
I have a script that I call Experiments. I use this whenever I have something tricky to work out. If I were struggling with the take stuff above, I would use
Experiments and start like this:
I would first code
Inserted Code
   if( iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) )   {
      }//if( iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) )
to check that my comparison logic is correct and will compile. Then I would add the "double take = ......" code to check that my logic is correct, like this:Inserted Code
   if( iClose(NULL, PERIOD_H4,0) < iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) )   {
      double take = iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1);      
===== PAGE 4/11 =====
S.1
S.1
S.1
   }//if( iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) )
   Alert(take);
If the alert shows what you expect it to show, then fine. If not, time to think again.
I spend a lot of time playing with my Experiments script.
Have fun. Keep going. Being able to think up a strategy and quickly code an ea to trade it is the huge advantage that leads me to assert repeatedly that
all traders should also be coders. The bright ones see what I mean. Most of the rest are doomed.
I have replied in detail because I have time tonight. I will not always be able to do so; thanks for understanding this.
Up an' at 'em, Tiger.
newark18
Steve, your response is much appreciated.
newark18
Steve/Anyone,
Do you have any EAs that permitted multiple entries that I can use to figure it out? I looked at Beastie but those entries are not typical.
Order modify error - Seems to be related to TP. I used the standard one that came with the shell. But once I add a TP in terms of pips, I get this error.
Otherwise, the SL is modified correctly. Seems odd.
newark18
ARRRRRGGGGGHHHH!!!! Ok, I needed to get that out. I think I found the loop function. But I am unsure where to put it. When I put it in here
(commented out), the EA will give me the same order modify errors.
Inserted Code
void LookForTradingOpportunities()
{
   RefreshRates();
  // for(int i=0; i < MaxTrades; i++)   double take, stop, price;
   int type;   bool SendTrade;
   double MinStopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;   if (!SpreadCheck() ) return;
      //Long 
      if(iClose(NULL, PERIOD_H4,2) < iOpen(NULL, PERIOD_H4,2) && //bearish close
      iClose(NULL, PERIOD_H4,1) > iOpen(NULL, PERIOD_H4,2) && //engulfing      iClose(NULL, PERIOD_H4,1) > iOpen(NULL, PERIOD_H4,1) && //bullish (don't think this is needed)
      iClose(NULL, PERIOD_H4,1) > iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) //above SMA50     ) 
   {      stop = NormalizeDouble(iLow(NULL, PERIOD_H4,1), Digits); //Low of H4 Engulfing Candle
      /*if( iClose(NULL, PERIOD_H4,0) < iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0) )       {
         take = NoramlizeDouble(iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0), Digits);          }*/
      if (TakeProfit > 0) take = NormalizeDouble(Ask + (TakeProfit * Point), Digits);      //if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
      type = OP_BUYSTOP;      price = iHigh(NULL, PERIOD_H4,1);
      SendTrade = true;   }//if (Ask > 1000000)
   
   //Short
   if(iClose(NULL, PERIOD_H4,2) > iOpen(NULL, PERIOD_H4,2) && //bullish close      iClose(NULL, PERIOD_H4,1) < iOpen(NULL, PERIOD_H4,2) && //engulfing
      iClose(NULL, PERIOD_H4,1) < iOpen(NULL, PERIOD_H4,1) && //Bearish close (dont' think this is needed)      iClose(NULL, PERIOD_H4,1) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1) //below the SMA 50
     )    {
===== PAGE 5/11 =====
S.1
S.1
      stop = NormalizeDouble(iHigh(NULL, PERIOD_H4,1),Digits); //High of H4 Engulfing Candle
      /*if( iClose(NULL, PERIOD_H4,0) > iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0) )       {
         take = NormalizeDouble(iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0), Digits);          }*/
      type = OP_SELLSTOP;      price = iLow(NULL, PERIOD_H4,1);
      SendTrade = true;            //take = iClose(NULL, PERIOD_H4,0) < iMA (NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 1);
      if (TakeProfit > 0) take = NormalizeDouble(Ask + (TakeProfit * Point), Digits);      //if (StopLoss > 0) stop = NormalizeDouble(Ask - (StopLoss * Point), Digits);
   }   
   if (SendTrade)
   {      bool result = SendSingleTrade(type, TradeComment, Lot, price, stop, take);
         }//if (SendTrade)
      
   //Actions when trade send succeeds   if (SendTrade && result)
   {   return(true);
   }//if (result)   
   //Actions when trade send fails   if (SendTrade && !result)
   {   
   }//if (!result)   
   
}//void LookForTradingOpportunities()
Attached File(s)
James SMA v2.mq4   64 KB | 729 downloads
SteveHopwood
Here is how I would set up an alert to show me what is going on. From there, I can usually work out what I am doing wrong.
Inserted Code
if( iClose(NULL, PERIOD_H4,0) > iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0) )    {
      take = NormalizeDouble(iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0), Digits);       }
   type = OP_SELLSTOP;   price = iLow(NULL, PERIOD_H4,1);
   [color=Red]Alert("take: ", take, "price: ", price, "  ", take - price);   return;[/color]
newark18
Quoting SteveHopwood Disliked
Here is how I would set up an alert to show me what is going on. From there, I can usually work out what I am doing wrong.
Inserted Code
if( iClose(NULL, PERIOD_H4,0) > iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0) ) 
   {      take = NormalizeDouble(iMA(NULL, 0, 50, 0, MODE_SMA, PRICE_CLOSE, 0), Digits);    
   }   type = OP_SELLSTOP;
   price = iLow(NULL, PERIOD_H4,1);   [color=Red]Alert("take: ", take, "price: ", price, "  ", take - price);
   return;[/color]
===== PAGE 6/11 =====
S.1
S.1
S.1
S.1
Thanks I will try that.
qooyend
Hello Steve,
since this is my first post I feel I should say that I admire your work here. It also struck me that you are a pianist in RL - just listening to you playingChopin: bravo! I am a newbie at forex as well as piano - I have started to learn playing piano a month ago.
Anyway, I think I have found a bug in your code, but it might be as well that I do not get the logic.
start function:
Inserted Code
   //Find open trades
   if (OrdersTotal() > 0)   {
      CountOpenTrades();      TradeExists = DoesTradeExist();
      if (TradeExists )      {
         if (OrderProfit() > 0) TradeManagementModule();         LookForTradeClosure();
      }//if (TradeExists)   }//if (OrdersTotal() > 0)
If a trade is a loser, TradeManagementModule will not be triggered, and hidden SLs will not fire as well.
I do not know what a jumping loss is so I just inserted something like this into code above
if (OrderProfit() < 0 && HideStopLossEnabled) HiddenStopLoss();
and removed it from TradeManagementModule function.
Regards
qooyend
Just another one, as I am onto it:
function DisplayUserFeedback
Inserted Code
   if (HideTakeProfitEnabled)
   {      ScreenMessage = StringConcatenate(ScreenMessage,Gap, "Hidden take profit enabled at ", HideTakeProfitEnabled, PipDescription, NL
   }//if (HideTakeProfitEnabled)
It should display HiddenTakeProfitPips.
SteveHopwood
Quoting qooyend
 DislikedJust another one, as I am onto it:
function DisplayUserFeedback
Inserted Code
   if (HideTakeProfitEnabled)
   {      ScreenMessage = StringConcatenate(ScreenMessage,Gap, "Hidden take profit enabled at ", HideTakeProfitEnabled, PipDescriptio
   }//if (HideTakeProfitEnabled)
It should display HiddenTakeProfitPips.
Thanks for spotting that.
Re the hidden stop thingy, it is intended to kick in only when the trade is in profit. Coders can adapt this to suit themselves.
SteveHopwood
Since posting the shell, I have developed a number of techniques to avoid over-trading etc. Those of you familiar with my work already know about this.
===== PAGE 7/11 =====
S.1
S.1
S.1
S.1
S.1
S.2
S.2
I have added these features to the shell. Updated version in post 1.
qooyend
Thanks, Steve.
alex4xes
Hi Steve,
Let me introduce myself, Im alex an office clerk by fate...but want to make it big with forex trading, but having said that Im very new to forex trading. Thisall started couple of months before when I accidently entered some forex trading site, since then I have read so many forex stratergies which proved no
use to me & lost some handsome money in the same. But now I m demo trading few stratergy but as I mentioned before due to my full time job I havelost few trades which would have been a winner. So I planned to ask help of some talented coder who can help me building trade management ea or
indicator. I have seen few of your works & Im largely impressed with all your works & your responses to each & every fellow forum members. And aboveall your generosity to help the forum members. So I made up my mind to take your help in building a trade management EA. I have seen some trade
management EA in forum already but they are way too much complex in themselve...I want very basic & simple Trade management EA. I want you tobuild me EA in such a way that it can easily managed so that I can build confident in forex trading & build some fund from it & then start thinking about
quiting job & go & be a full time trader. Hope you wont mind helping me in this regards. I want you to code something like this.
Eg...If I enter buy trade manually at price 1.40000, I want EA or indicator to do manage that trade like like thereafter.
TP1 - 1.40500 - (we can enter price instead of pips.)SL1 - 1.39500 - (we have to enter SL price in setting not pips)
Once TP1 is achieved EA should manage trade thereafter for next levelTP2 - 1.41000 - (Again this parameter should be entered by us in price)
SL2 - 1.40000 - (SL1 should be moved to this price after TP1 is achieved)Once TP2 is achieved EA should manage trade thereafter for next level
TP3 - 1.41500 - (Again this parameter should be entered by us in price)SL3 - 1.40500 - (SL2 should be moved to this price after TP2 is achieved)
%Close1 - 50% (At TP1 this much trade should be exited)%Close2 - 30% (At TP2 this much trade should be exited)
%Close3 - 20% (At TP3 this much trade should be exited)
Thanks in advance steve..... Looking forward to hear from you. Please please help me in this. This can turn my fortune.
P.S. This EA or indicator must work in the 0.0000 or 0.00000 that four or five digit broker.
Love you steve. Tk care bye....
SteveHopwood
I have updated the post 1 shell. It turned out that I had omitted some of the functions needed by some of the new inputs. I am always doing things like
that.
SteveHopwood
Latest update to my shell in post 1. Explanation at http://www.forexfactory.com/showthre...31#post4845431
SteveHopwood
Latest update in post 1:
 
Added Aurora-style hidden tp/sl based on chart lines.Added Caterpillar scaling in - this might need tweaking as I have not tested it yet.
jmw1970
Hi Steve
just a suggestion but you might want to put in the variable lot sizing code as an option
john
SteveHopwood
Quoting jmw1970
 DislikedHi Steve
===== PAGE 8/11 =====
S.2
S.2
S.2
S.2
S.2
just a suggestion but you might want to put in the variable lot sizing code as an option
john
I thought about it but hardly ever use variable lot sizing. If I start using it more, I shall include it.
Cheers
lhDT
HI Steve,
It's maybe a stupid question but how to trigger a trade when all (custom) conditions are met ?I saw in the Spider EA you use "trend=up" to BUY and "trend=down" to SELL.
Example : I have 4 indicators in separate functions, when they all goes in the same direction I change trend to "up" or "down".
if(isxx==blue && stm==blue && tl==blue && emt==blue) { trend = up;}
if(isxx==red && stm==red && tl==red && emt==red) { trend = down;}
It doesn't seems to work with the shell EA (OOTB) on page 1.
Thanks for your help,Lh
SteveHopwood
Quoting lhDT Disliked
HI Steve,
It's maybe a stupid question but how to trigger a trade when all (custom) conditions are met ?I saw in the Spider EA you use "trend=up" to BUY and "trend=down" to SELL.
Example : I have 4 indicators in separate functions, when they all goes in the same direction I change trend to "up" or "down".
if(isxx==blue && stm==blue && tl==blue && emt==blue) { trend = up;}
if(isxx==red && stm==red && tl==red && emt==red) { trend = down;}
It doesn't seems to work with the shell EA (OOTB) on page 1.
Thanks for your help,Lh
You have to change the trade trigger conditions in void LookForTradingOpportunities().
lhDT
Quoting SteveHopwood Disliked
You have to change the trade trigger conditions in void LookForTradingOpportunities().
Oh yes, humm I'm a bit confused nowThx for the fast reply !
SteveHopwood
Quoting lhDT Disliked
Oh yes, humm I'm a bit confused nowThx for the fast reply !
I have this effect on people. Ask the kids I teach.
The shell is not an ea generator. It is a shell for coders to use to save themselves a lot of copy/pasting when creating their own ea's. To use it, you firsthave to be a proficient coder.
lhDT
Quoting SteveHopwood
 Disliked
===== PAGE 9/11 =====
S.2
S.2
S.2
S.2
I have this effect on people. Ask the kids I teach.
The shell is not an ea generator. It is a shell for coders to use to save themselves a lot of copy/pasting when creating their own ea's. To
use it, you first have to be a proficient coder.
Yes indeed, my EA is done and working (10 minutes) ... Wonderful shell !Made just slight changes for taking trade at the next candles.
Thx again.
btw : you're more than welcome to test it
SteveHopwood
Quoting lhDT Disliked
Yes indeed, my EA is done and working (10 minutes) ... Wonderful shell !Made just slight changes for taking trade at the next candles.
Thx again.
btw : you're more than welcome to test it
Damn. The trouble with this is that people will come to recognise how I can produce EA's so quickly and easily. I will lose all my mystique.
When producing an ea, it usually takes me longer to delete all the stuff I do not need than it takes to add the few extra bits and bats the individual systemcalls for.
All traders should be able to code mql4. To be able to have an idea, quickly code it and get it up on demo for testing within minutes is a huge boon. If my
shell helps you to do this more easily, then brilliant. One day, you will design your own shell.
In the meantime, I look forward to testing the results of your efforts.
SteveHopwood
Latest update in post 1.
I have added Stealth Technology. Read the opening comments in the code.
I have moved all the variables that apply to the various functions so that the externs and the variables are together, to make deleting them easier.
Basically, delete a group of externs and their associated variables from the code and recompile. The errors thrown up will guide you to the functions thatneed deleting from your source code.
MarcinB
Hi Steve.
I'm new in the FF community. 2 weeks ago started to read all your post associated with EAs development and could'n believe that one man cando so much. I asked myself who's that guy? Visited your web page and could'n even more believe that you're a pianist. My first though was that
i typed wrong web page address but now I know that's true. Wow, what an unmet combination !Well, returning to EAs im not so much familiar with trading forex, started serious learning month ago and now I know that the only way to trade
and have a fun together is EAs development. I have some coding experience in C/C# and switching to MQL4 should't be a problem. Still have tolearn forex trading however.
I planned to review many of your EAs and extract some repetitive functions which could be useful but I came across this thread and "shell EA"which in fact saves a lot of hours for me. Many thanks for such a hughe help. I really appreciate that !!! Now still few months of learning and I
believe to become active member of FF, addidng to your shell some more functions and improving/creating new EAs.
CockeyedCowboy
Steve
I have done something similar with the .mqt files supplyed with MT. Its just a shell with very little code if any, the base code your showing in your shell
can be hidden in a library. as I have done with the line; #include <Implement/MetaQuote v4.00/MQ4 RunTime Module v1.70>. Where this differs fromyours is that I place it in the expert templates directory and call it by the name that MT uses and when I use the MT wizard to create a new EA it brings
up my copy of the template not MTs, one warning though make a copy of your template as when you update MT it will delete your copy and replace itwith their copy again.
I created one for each different template that is supplied with MT. The attached is the Expert file. If you copy it into the expert template folder (after
renaming MTs copy to something else) and create a new ea using the wizard you will see what I mean, of coarse it will have my name and informationon it, you will have to change it to yours. all the codeing that is in your current code can be moved to a library and called into your template. I use an
include file to call all the functions but they can be placed in side your shell.
The attached file has some things remove as it would make it to complicated to understand.
===== PAGE 10/11 =====
S.2
S.2
S.2
S.2
S.2
S.2
S.2
Keit
edit the file was placed in a zip file because FF will not accept .mqt extentions.
edit 2 by the way what is OCCD is it something you need to see a doctor about??Attached File(s)
Expert.zip   2 KB | 596 downloads
stevegee58
Cockeyed Cowboy you old Cobol programmer you. I haven't seen stuff like that in 40 years.
CockeyedCowboy
Quoting stevegee58 Disliked
Cockeyed Cowboy you old Cobol programmer you. I haven't seen stuff like that in 40 years.
..... 40 years?? May be a little time has passed... My best friend in high school will tell you that I spent more time with his father at the university then withhim. His dad was head of the computer science department of the state university. And your right Cobol is were I started. Its still a good sturcture to
follow even today.
by the way theres more I didn't show be cause it would of confused the hell of some.
Keit
SteveHopwood
Latest update in post 1. I have replaced the single moving average trend-detection function with calls to AllAverages instead. You will see the advantageof doing this as soon as you load up the indi.
I have written a shell user guide that you can edit and distribute should you wish to release your EA here at FF. Use it freely.
SteveHopwood
Latest updates in post 1. I have added the Hanover module to the code and some info about it to the user guides.
SteveHopwood
Latest update in post 1.
I have added George's alternative to spotting a CBI, also fixed a few bloops in the code. The bloop fixes alone make this an essential download if you
use CBI.
SteveHopwood
Latest update in post 1.
The CBI module means that robots using it are multi-traders even if the original strategy was a single-trader. This necessitates changes toCountOpenTrades() and start(), so that management functions are called from within CountOpenTrades(). I have made some additions to
CloseAllTrades() as well.
2face
Quoting SteveHopwood Disliked
Latest update in post 1. I have replaced the single moving average trend-detection function with calls to AllAverages instead. You will seethe advantage of doing this as soon as you load up the indi.
I have written a shell user guide that you can edit and distribute should you wish to release your EA here at FF. Use it freely.
Hi Steve,
I would like to know if you can code this on MT4.
===== PAGE 11/11 =====
S.2
Atlas Line Indicator
from http://daytradetowin.com/software.php
mntiwana
Quoting SteveHopwood
 DislikedLatest update in post 1. The CBI module means that robots using it are multi-traders even if the original strategy was a single-trader. This
necessitates changes to CountOpenTrades() and start(), so that management functions are called from within CountOpenTrades(). I havemade some additions to CloseAllTrades() as well.
Hi steve or some kind expert coderWould you like manage time removing Errors/Warnings from Generic auto trading robot by Steve Hopwood.mq4
of post 1.regards```
