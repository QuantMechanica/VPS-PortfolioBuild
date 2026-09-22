#property strict
#property version   "5.0"
#property description "QM5_20078 Volume Profile POC Retest"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_20078
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20078;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int strategy_atr_period = 14;
input int strategy_ema_period = 200;
input int strategy_rsi_period = 14;
input double strategy_rsi_buy_min = 45.0;
input double strategy_rsi_sell_max = 55.0;
input double strategy_va_coverage = 0.70;
input double strategy_stop_atr_mult = 1.0;
input double strategy_poc_stop_atr_mult = 0.5;
input double strategy_tp_atr_mult = 2.0;
input double strategy_va_min_atr_d1 = 0.5;
input double strategy_spread_median_mult = 1.5;
input int strategy_max_hold_bars = 24;
input int strategy_min_session_bars = 4;
input int strategy_min_profile_bars = 60;

#define STRATEGY_PROFILE_BINS 50
bool g_profile_valid=false, g_bar_valid=false, g_buy_event=false, g_sell_event=false;
datetime g_profile_session=0;
double g_poc=0.0, g_val=0.0, g_vah=0.0;
MqlRates g_closed_bar;

bool Strategy_ConfigValid()
{
   return _Period==PERIOD_M15 && strategy_atr_period>=2 && strategy_atr_period<=256 &&
      strategy_ema_period>=2 && strategy_ema_period<=1000 && strategy_rsi_period>=2 && strategy_rsi_period<=256 &&
      strategy_rsi_buy_min>0.0 && strategy_rsi_buy_min<100.0 && strategy_rsi_sell_max>0.0 && strategy_rsi_sell_max<100.0 &&
      strategy_va_coverage>0.0 && strategy_va_coverage<=1.0 && strategy_stop_atr_mult>0.0 &&
      strategy_poc_stop_atr_mult>0.0 && strategy_tp_atr_mult>0.0 && strategy_va_min_atr_d1>0.0 &&
      strategy_spread_median_mult>0.0 && strategy_max_hold_bars>=1 && strategy_max_hold_bars<=96 &&
      strategy_min_session_bars>=1 && strategy_min_session_bars<=60 &&
      strategy_min_profile_bars>=1 && strategy_min_profile_bars<=900;
}

datetime Strategy_SessionStart(const datetime when)
{
   MqlDateTime stamp;
   if(!TimeToStruct(when,stamp)) return 0;
   stamp.hour=6; stamp.min=0; stamp.sec=0;
   return StructToTime(stamp);
}

bool Strategy_ProfileFromRates(MqlRates &rates[], const int count)
{
   g_profile_valid=false;
   if(count<strategy_min_profile_bars || count>900 || ArraySize(rates)<count) return false;
   double lower=DBL_MAX, upper=-DBL_MAX;
   int positive=0;
   for(int i=0;i<count;++i)
   {
      if(rates[i].low<=0.0 || rates[i].high<rates[i].low) return false;
      lower=MathMin(lower,rates[i].low); upper=MathMax(upper,rates[i].high);
      if(rates[i].tick_volume>0) ++positive;
   }
   if(positive<strategy_min_profile_bars || upper<=lower) return false;
   const double width=(upper-lower)/STRATEGY_PROFILE_BINS;
   double volume[STRATEGY_PROFILE_BINS];
   ArrayInitialize(volume,0.0);
   double total=0.0;
   for(int i=0;i<count;++i)
   {
      if(rates[i].tick_volume<=0) continue;
      const double midpoint=(rates[i].high+rates[i].low)*0.5;
      int bin=(int)MathFloor((midpoint-lower)/width);
      bin=MathMax(0,MathMin(STRATEGY_PROFILE_BINS-1,bin));
      volume[bin]+=(double)rates[i].tick_volume;
      total+=(double)rates[i].tick_volume;
   }
   if(total<=0.0) return false;
   int poc_index=0;
   for(int i=1;i<STRATEGY_PROFILE_BINS;++i)
      if(volume[i]>volume[poc_index]) poc_index=i;
   int order[STRATEGY_PROFILE_BINS];
   for(int i=0;i<STRATEGY_PROFILE_BINS;++i) order[i]=i;
   // Descending volume; explicit lower-price tie break (independent of swaps).
   for(int i=0;i<STRATEGY_PROFILE_BINS-1;++i)
   {
      int best=i;
      for(int j=i+1;j<STRATEGY_PROFILE_BINS;++j)
         if(volume[order[j]]>volume[order[best]] ||
            (volume[order[j]]==volume[order[best]] && order[j]<order[best])) best=j;
      const int saved=order[i]; order[i]=order[best]; order[best]=saved;
   }
   int lo=STRATEGY_PROFILE_BINS-1, hi=0;
   double covered=0.0;
   for(int i=0;i<STRATEGY_PROFILE_BINS;++i)
   {
      const int bin=order[i];
      covered+=volume[bin]; lo=MathMin(lo,bin); hi=MathMax(hi,bin);
      if(covered>=strategy_va_coverage*total) break;
   }
   g_poc=lower+(poc_index+0.5)*width;
   g_val=lower+lo*width;
   g_vah=lower+(hi+1)*width;
   g_profile_valid=(g_vah>g_val && g_poc>0.0);
   return g_profile_valid;
}

bool Strategy_LoadProfile(const datetime session_start)
{
   if(session_start==g_profile_session) return g_profile_valid;
   g_profile_valid=false;
   datetime prior=session_start-86400;
   MqlDateTime stamp;
   if(!TimeToStruct(prior,stamp)) return false;
   while(stamp.day_of_week==0 || stamp.day_of_week==6)
   {
      prior-=86400;
      if(!TimeToStruct(prior,stamp)) return false;
   }
   MqlRates rates[];
   const int count=CopyRates(_Symbol,PERIOD_M1,prior,prior+15*3600-1,rates); // perf-allowed: prior complete session only, once per session behind new-bar gate
   if(count<0 || !SeriesInfoInteger(_Symbol,PERIOD_M1,SERIES_SYNCHRONIZED)) return false; // retry incomplete history next closed bar
   g_profile_session=session_start;
   return Strategy_ProfileFromRates(rates,count);
}

bool Strategy_ReplayTouches(MqlRates &bars[], const int count)
{
   g_buy_event=false; g_sell_event=false;
   if(count<1 || count>60 || ArraySize(bars)<count) return false;
   bool buy_consumed=false, sell_consumed=false;
   double previous=bars[0].open;
   for(int i=0;i<count;++i)
   {
      if(bars[i].low<=0.0 || bars[i].high<bars[i].low || bars[i].close<=0.0) return false;
      if(!buy_consumed && previous>g_poc && bars[i].low<=g_poc)
      {
         buy_consumed=true;
         if(i==count-1) g_buy_event=true;
      }
      if(!sell_consumed && previous<g_poc && bars[i].high>=g_poc)
      {
         sell_consumed=true;
         if(i==count-1) g_sell_event=true;
      }
      previous=bars[i].close;
   }
   return true;
}

bool Strategy_AdvanceClosedState()
{
   g_bar_valid=false; g_buy_event=false; g_sell_event=false;
   const datetime now=TimeCurrent(), start=Strategy_SessionStart(now);
   if(start<=0 || now<start || now>=start+15*3600) return false;
   if(!QM_ReadBar(_Symbol,PERIOD_M15,1,g_closed_bar)) return false;
   g_bar_valid=true;
   if(!Strategy_LoadProfile(start)) return false;
   if(g_closed_bar.time<start) return false;
   MqlRates bars[];
   const int count=CopyRates(_Symbol,PERIOD_M15,start,g_closed_bar.time,bars); // perf-allowed: bounded current-session reconstruction behind new-bar gate
   if(count<1 || count>60 || ArraySize(bars)<count ||
      !SeriesInfoInteger(_Symbol,PERIOD_M15,SERIES_SYNCHRONIZED)) return false;
   if(bars[count-1].time!=g_closed_bar.time) return false;
   if(!Strategy_ReplayTouches(bars,count)) return false;
   // Consume touches BEFORE age, risk, news, spread and position filters.
   if(count<strategy_min_session_bars || g_closed_bar.time+900-start<strategy_min_session_bars*900)
   { g_buy_event=false; g_sell_event=false; }
   return true;
}

bool Strategy_SpreadAllowed()
{
   MqlRates bars[20];
   if(CopyRates(_Symbol,PERIOD_M15,1,20,bars)!=20) return false; // perf-allowed: fixed 20 closed spread observations behind new-bar gate
   double values[20];
   for(int i=0;i<20;++i)
   {
      if(bars[i].spread<0) return false;
      values[i]=(double)bars[i].spread;
   }
   ArraySort(values);
   const double median=(values[9]+values[10])*0.5;
   const double point=SymbolInfoDouble(_Symbol,SYMBOL_POINT);
   const double ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK), bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   if(median<=0.0 || point<=0.0 || ask<=0.0 || bid<=0.0 || ask<bid) return false;
   return (ask-bid)/point<=strategy_spread_median_mult*median;
}

bool Strategy_NoTradeFilter()
{
   return !g_profile_valid || !g_bar_valid || QM_TM_OpenPositionCount(QM_FrameworkMagic())>0;
}

// The designated-G0 amendment selects the closer stop PRICE symmetrically.
double Strategy_StopPrice(const int direction,const double entry,const double atr)
{
   if(entry<=0.0 || atr<=0.0) return 0.0;
   if(direction>0)
      return MathMax(entry-strategy_stop_atr_mult*atr,g_poc-strategy_poc_stop_atr_mult*atr);
   return MathMin(entry+strategy_stop_atr_mult*atr,g_poc+strategy_poc_stop_atr_mult*atr);
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   ZeroMemory(req); req.symbol_slot=qm_magic_slot_offset;
   if(QM_FrameworkMagic()<=0 || Strategy_NoTradeFilter() || (!g_buy_event && !g_sell_event)) return false;
   if(!Strategy_SpreadAllowed()) return false;
   if(!QM_IndicatorWarmupReady(QM_IndATR(_Symbol,PERIOD_M15,strategy_atr_period),0,1,strategy_atr_period+2,"poc_atr_m15") ||
      !QM_IndicatorWarmupReady(QM_IndATR(_Symbol,PERIOD_D1,strategy_atr_period),0,1,strategy_atr_period+2,"poc_atr_d1") ||
      !QM_IndicatorWarmupReady(QM_IndMA(_Symbol,PERIOD_H1,strategy_ema_period,MODE_EMA,PRICE_CLOSE),0,1,strategy_ema_period+2,"poc_ema_h1") ||
      !QM_IndicatorWarmupReady(QM_IndRSI(_Symbol,PERIOD_M15,strategy_rsi_period,PRICE_CLOSE),0,1,strategy_rsi_period+2,"poc_rsi_m15")) return false;
   const double atr=QM_ATR(_Symbol,PERIOD_M15,strategy_atr_period,1);
   const double daily_atr=QM_ATR(_Symbol,PERIOD_D1,strategy_atr_period,1);
   const double ema=QM_EMA(_Symbol,PERIOD_H1,strategy_ema_period,1);
   const double rsi=QM_RSI(_Symbol,PERIOD_M15,strategy_rsi_period,1);
   if(!MathIsValidNumber(atr) || !MathIsValidNumber(daily_atr) || !MathIsValidNumber(ema) || !MathIsValidNumber(rsi) ||
      atr==EMPTY_VALUE || daily_atr==EMPTY_VALUE || ema==EMPTY_VALUE || rsi==EMPTY_VALUE ||
      atr<=0.0 || daily_atr<=0.0 || ema<=0.0 || rsi<0.0 || rsi>100.0 ||
      g_vah-g_val<strategy_va_min_atr_d1*daily_atr) return false;
   int direction=0;
   if(g_buy_event && g_closed_bar.close>g_poc && g_closed_bar.close>g_closed_bar.open &&
      g_closed_bar.close>ema && rsi>strategy_rsi_buy_min) direction=1;
   if(g_sell_event && g_closed_bar.close<g_poc && g_closed_bar.close<g_closed_bar.open &&
      g_closed_bar.close<ema && rsi<strategy_rsi_sell_max) direction=-1;
   if(direction==0) return false;
   const double entry=SymbolInfoDouble(_Symbol,direction>0?SYMBOL_ASK:SYMBOL_BID);
   if(entry<=0.0 || (direction>0 && entry<=g_poc) || (direction<0 && entry>=g_poc)) return false;
   req.type=direction>0?QM_BUY:QM_SELL;
   req.sl=QM_TM_NormalizePrice(_Symbol,Strategy_StopPrice(direction,entry,atr));
   req.tp=QM_TM_NormalizePrice(_Symbol,entry+direction*strategy_tp_atr_mult*atr);
   req.reason=direction>0?"poc_first_buy_retest":"poc_first_sell_retest";
   return req.sl>0.0 && req.tp>0.0 && (direction>0?req.sl<entry:req.sl>entry);
}

void Strategy_ManageOpenPosition()
{
   // Session protection is per tick, independent of profile/history/news state.
   const datetime now=TimeCurrent(), start=Strategy_SessionStart(now);
   if(start<=0) return;
   const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC)!=magic ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      if(now<start || now>=start+15*3600 || PositionGetInteger(POSITION_TIME)<start)
         QM_TM_ClosePosition(ticket,QM_EXIT_STRATEGY);
   }
}

bool Strategy_ExitSignal()
{
   const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;--i)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket) || PositionGetInteger(POSITION_MAGIC)!=magic ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol) continue;
      const int age=iBarShift(_Symbol,PERIOD_M15,(datetime)PositionGetInteger(POSITION_TIME),false); // perf-allowed: actual-bar time stop, once per new M15 bar
      if(age>=strategy_max_hold_bars) return true;
      if(!g_profile_valid || !g_bar_valid) continue;
      const bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      if(buy?g_closed_bar.close>=g_vah:g_closed_bar.close<=g_val) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time) { return false; }
int OnInit()
{
   if(!Strategy_ConfigValid()) return INIT_PARAMETERS_INCORRECT;
   if(!QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED,PORTFOLIO_WEIGHT,
      qm_news_mode_legacy,qm_friday_close_enabled,qm_friday_close_hour_broker,30,30,
      qm_news_stale_max_hours,qm_news_min_impact,qm_rng_seed,qm_stress_reject_probability,qm_news_temporal,qm_news_compliance)) return INIT_FAILED;
   QM_IsNewBar(_Symbol,PERIOD_M15);
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) { QM_FrameworkShutdown(); }
void OnTick()
{
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck()) return;
   if(QM_FrameworkHandleFridayClose()) return;
   Strategy_ManageOpenPosition();
   if(!QM_IsNewBar(_Symbol,PERIOD_M15)) return;
   QM_EquityStreamOnNewBar();
   Strategy_AdvanceClosedState();
   if(Strategy_ExitSignal())
   {
      const int magic=QM_FrameworkMagic();
      for(int i=PositionsTotal()-1;i>=0;--i)
      {
         const ulong ticket=PositionGetTicket(i);
         if(ticket!=0 && PositionSelectByTicket(ticket) && PositionGetInteger(POSITION_MAGIC)==magic &&
            PositionGetString(POSITION_SYMBOL)==_Symbol) QM_TM_ClosePosition(ticket,QM_EXIT_STRATEGY);
      }
      return;
   }
   if(Strategy_NoTradeFilter()) return;
   const datetime now=TimeCurrent();
   if(Strategy_NewsFilterHook(now)) return;
   const bool news_allows=(qm_news_temporal!=QM_NEWS_TEMPORAL_OFF || qm_news_compliance!=QM_NEWS_COMPLIANCE_NONE)
      ?QM_NewsAllowsTrade2(_Symbol,now,qm_news_temporal,qm_news_compliance):QM_NewsAllowsTrade(_Symbol,now,qm_news_mode_legacy);
   if(!news_allows) return;
   QM_EntryRequest req; ZeroMemory(req);
   if(Strategy_EntrySignal(req)) { ulong ticket=0; QM_TM_OpenPosition(req,ticket); }
}
void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
{ QM_FrameworkOnTradeTransaction(trans,request,result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
