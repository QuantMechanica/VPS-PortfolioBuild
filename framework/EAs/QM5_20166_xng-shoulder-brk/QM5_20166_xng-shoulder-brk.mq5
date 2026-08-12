#property strict
#property version "5.0"
#property description "QM5_20166 XNG Shoulder Transition Breakout"
#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int qm_ea_id=20166;
input int qm_magic_slot_offset=0;
input uint qm_rng_seed=42;
input group "Risk"
input double RISK_PERCENT=0.0;
input double RISK_FIXED=1000.0;
input double PORTFOLIO_WEIGHT=1.0;
input group "News"
input QM_NewsTemporalMode qm_news_temporal=QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance=QM_NEWS_COMPLIANCE_NONE;
input int qm_news_stale_max_hours=336;
input string qm_news_min_impact="high";
input QM_NewsMode qm_news_mode_legacy=QM_NEWS_OFF;
input group "Friday Close"
input bool qm_friday_close_enabled=true;
input int qm_friday_close_hour_broker=21;
input group "Stress"
input double qm_stress_reject_probability=0.0;
input group "Strategy"
input int strategy_channel_days=20;
input int strategy_atr_period=20;
input double strategy_compression_mult=0.80;
input double strategy_atr_sl_mult=3.0;
input int strategy_max_hold_days=15;
input int strategy_max_spread_points=2500;

bool IsShoulder(const datetime t)
  {
   MqlDateTime d; TimeToStruct(t,d);
   return(d.mon==3 || d.mon==4 || d.mon==9 || d.mon==10);
  }
bool Owned()
  {
   for(int i=PositionsTotal()-1;i>=0;--i)
     {
      ulong t=PositionGetTicket(i);
      if(t>0 && PositionSelectByTicket(t) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC)==QM_FrameworkMagic()) return true;
     }
   return false;
  }
bool Channel(const int start,double &hi,double &lo,double &avg)
  {
   hi=-DBL_MAX; lo=DBL_MAX; avg=0.0;
   for(int i=start;i<start+strategy_channel_days;++i)
     {
      double h=iHigh(_Symbol,PERIOD_D1,i),l=iLow(_Symbol,PERIOD_D1,i); // perf-allowed: once per D1 new-bar signal evaluation.
      if(h<=l || l<=0.0) return false;
      hi=MathMax(hi,h); lo=MathMin(lo,l); avg+=(h-l);
     }
   avg/=strategy_channel_days;
   return hi>lo;
  }
void CloseExpired()
  {
   datetime now=TimeCurrent();
   for(int i=PositionsTotal()-1;i>=0;--i)
     {
      ulong t=PositionGetTicket(i);
      if(t==0 || !PositionSelectByTicket(t) ||
         PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC)!=QM_FrameworkMagic()) continue;
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      if(!IsShoulder(now) || (opened>0 && now-opened>=strategy_max_hold_days*86400))
         QM_TM_ClosePosition(t,QM_EXIT_STRATEGY);
     }
  }
bool Strategy_NoTradeFilter()
  {
   return _Symbol!="XNGUSD.DWX" || _Period!=PERIOD_D1 || qm_ea_id!=20166 ||
          qm_magic_slot_offset!=0 || strategy_channel_days<10 ||
          strategy_atr_period<5 || strategy_compression_mult<=0.0 ||
          strategy_atr_sl_mult<=0.0 || strategy_max_hold_days<1;
  }
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   CloseExpired();
   if(Owned() || !IsShoulder(iTime(_Symbol,PERIOD_D1,1))) return false; // perf-allowed: one completed-bar timestamp per D1 signal.
   long spread=SymbolInfoInteger(_Symbol,SYMBOL_SPREAD);
   if(spread<0 || spread>strategy_max_spread_points) return false;
   double hi,lo,avg,atr=QM_ATR(_Symbol,PERIOD_D1,strategy_atr_period,1);
   if(atr<=0.0 || !Channel(2,hi,lo,avg) || avg>atr*strategy_compression_mult) return false;
   double c=iClose(_Symbol,PERIOD_D1,1); // perf-allowed: one completed close per D1 signal.
   if(c>hi) req.type=QM_BUY;
   else if(c<lo) req.type=QM_SELL;
   else return false;
   double px=QM_EntryMarketPrice(req.type);
   if(px<=0.0) return false;
   req.price=0.0; req.tp=0.0;
   req.sl=QM_StopATR(_Symbol,req.type,px,strategy_atr_period,strategy_atr_sl_mult);
   req.reason="XNG_SHOULDER_COMPRESSION_BREAKOUT";
   req.symbol_slot=0; req.expiration_seconds=0;
   return req.sl>0.0;
  }
void Strategy_ManageOpenPosition(){ CloseExpired(); }
bool Strategy_ExitSignal(){ return false; }
bool Strategy_NewsFilterHook(const datetime broker_time){ return false; }
int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED,
      PORTFOLIO_WEIGHT,qm_news_mode_legacy,qm_friday_close_enabled,
      qm_friday_close_hour_broker,30,30,qm_news_stale_max_hours,
      qm_news_min_impact,qm_rng_seed,qm_stress_reject_probability,
      qm_news_temporal,qm_news_compliance)) return INIT_FAILED;
   return INIT_SUCCEEDED;
  }
void OnDeinit(const int reason){ QM_FrameworkShutdown(); }
void OnTick()
  {
   if(!QM_KillSwitchCheck()) return;
   datetime now=TimeCurrent();
   if(Strategy_NewsFilterHook(now) || QM_FrameworkHandleFridayClose() ||
      Strategy_NoTradeFilter()) return;
   Strategy_ManageOpenPosition();
   if(!QM_IsNewBar()) return;
   QM_EquityStreamOnNewBar();
   QM_EntryRequest req;
   if(Strategy_EntrySignal(req)){ ulong ticket=0; QM_TM_OpenPosition(req,ticket); }
  }
void OnTimer(){ QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  { QM_FrameworkOnTradeTransaction(trans,request,result); }
double OnTester(){ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
