#property strict
#property version   "5.0"
#property description "QM5_41303 WTI Pre-Holiday Sentiment Sleeve - opt"

#define QM_PATTERN_PERMISSION_EA_MANAGED
#include <QM/QM_Common.mqh>
#include <QM/QM_PatternPermission.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 41303;
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
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_max_hold_days       = 4;
input int    strategy_max_spread_points   = 1200;


// DL-089 pattern measurement surface. Zero disables a slot.
input group "Optimization Pattern Profile"
input int opt_pp_buy1  = 0;
input int opt_pp_buy2  = 0;
input int opt_pp_buy3  = 0;
input int opt_pp_sell1 = 0;
input int opt_pp_sell2 = 0;
input int opt_pp_sell3 = 0;

const ENUM_TIMEFRAMES QM_PPC_REFERENCE_TF = PERIOD_D1;
const int             QM_PPC_CLOSED_SHIFT = 1;
QM_PatternProfile     g_pp_profile;
bool                  g_pp_active = false;
long                  g_pp_days_evaluated = 0;
long                  g_pp_fire_count = 0;
long                  g_pp_legs_suppressed = 0;
long                  g_pp_invalid_days = 0;
datetime              g_pp_reference_bar_time = 0;

QM_PermissionResult Pattern_Permission()
  {
   QM_PermissionResult perm;
   if(!g_pp_active)
     {
      perm.allow_buy = true;
      perm.allow_sell = true;
      perm.valid = true;
      perm.reference_bar_time = g_pp_reference_bar_time;
      perm.reason = "census_control";
      return perm;
     }
   return QM_PatternPermissionEvaluate(_Symbol, QM_PPC_REFERENCE_TF,
                                       QM_PPC_CLOSED_SHIFT, g_pp_profile);
  }

bool Opt_AddPattern(const int predicate_id, const bool buy_side, const string input_name)
  {
   if(predicate_id == 0)
      return true;
   if(predicate_id < 0)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"input\":\"%s\",\"predicate_id\":%d}", input_name, predicate_id));
      return false;
     }
   const QM_PatternId pid = (QM_PatternId)predicate_id;
   const bool added = buy_side ? QM_PP_ProfileAddBuy(g_pp_profile, pid)
                               : QM_PP_ProfileAddSell(g_pp_profile, pid);
   if(!added)
     {
      QM_LogEvent(QM_ERROR, "PP_CENSUS_CONFIG_INVALID",
                  StringFormat("{\"input\":\"%s\",\"predicate_id\":%d}", input_name, predicate_id));
      return false;
     }
   g_pp_active = true;
   return true;
  }

bool Pattern_AllowsRequest(const QM_EntryRequest &req)
  {
   const QM_PermissionResult perm = Pattern_Permission();
   g_pp_days_evaluated++;
   if(!perm.valid)
     {
      g_pp_invalid_days++;
      QM_LogEvent(QM_WARN, "PP_CENSUS_BLOCK", "{\"reason\":\"permission_invalid\"}");
      return false;
     }
   const bool buy_side = QM_OrderTypeIsBuy(req.type);
   const bool allowed = buy_side ? perm.allow_buy : perm.allow_sell;
   if(!allowed)
     {
      g_pp_fire_count++;
      g_pp_legs_suppressed++;
      QM_LogEvent(QM_INFO, "PP_CENSUS_BLOCK",
                  StringFormat("{\"side\":\"%s\",\"bar\":\"%s\",\"reason\":\"%s\"}",
                               (buy_side ? "BUY" : "SELL"),
                               TimeToString(perm.reference_bar_time), perm.reason));
     }
   return allowed;
  }

int g_last_holiday_key = 0;

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime d; TimeToStruct(t,d);
   return d.year*10000+d.mon*100+d.day;
  }

datetime Strategy_Date(const int y,const int m,const int d)
  {
   MqlDateTime x; ZeroMemory(x); x.year=y; x.mon=m; x.day=d;
   return StructToTime(x);
  }

int Strategy_Dow(const datetime t)
  {
   MqlDateTime d; TimeToStruct(t,d); return d.day_of_week;
  }

datetime Strategy_ObservedFixed(const int y,const int m,const int day)
  {
   datetime h=Strategy_Date(y,m,day);
   const int dow=Strategy_Dow(h);
   if(dow==6) return h-86400;
   if(dow==0) return h+86400;
   return h;
  }

datetime Strategy_NthWeekday(const int y,const int m,const int dow,const int nth)
  {
   datetime first=Strategy_Date(y,m,1);
   int delta=(dow-Strategy_Dow(first)+7)%7;
   return first+(delta+7*(nth-1))*86400;
  }

datetime Strategy_LastWeekday(const int y,const int m,const int dow)
  {
   int nm=m+1,ny=y; if(nm==13){nm=1;ny++;}
   datetime last=Strategy_Date(ny,nm,1)-86400;
   return last-((Strategy_Dow(last)-dow+7)%7)*86400;
  }

int Strategy_EasterDayKey(const int y)
  {
   int a=y%19,b=y/100,c=y%100,d=b/4,e=b%4,f=(b+8)/25,g=(b-f+1)/3;
   int h=(19*a+b-d-g+15)%30,i=c/4,k=c%4,l=(32+2*e+2*i-h-k)%7;
   int m=(a+11*h+22*l)/451,mon=(h+l-7*m+114)/31,day=((h+l-7*m+114)%31)+1;
   return y*10000+mon*100+day;
  }

bool Strategy_IsHoliday(const datetime t)
  {
   MqlDateTime d; TimeToStruct(t,d); const int key=Strategy_DateKey(t);
   if(key==Strategy_DateKey(Strategy_ObservedFixed(d.year,1,1))) return true;
   if(key==Strategy_DateKey(Strategy_NthWeekday(d.year,2,1,3))) return true;
   datetime easter=Strategy_Date(d.year,(Strategy_EasterDayKey(d.year)/100)%100,Strategy_EasterDayKey(d.year)%100);
   if(key==Strategy_DateKey(easter-2*86400)) return true;
   if(key==Strategy_DateKey(Strategy_LastWeekday(d.year,5,1))) return true;
   if(key==Strategy_DateKey(Strategy_ObservedFixed(d.year,7,4))) return true;
   if(key==Strategy_DateKey(Strategy_NthWeekday(d.year,9,1,1))) return true;
   if(key==Strategy_DateKey(Strategy_NthWeekday(d.year,11,4,4))) return true;
   if(key==Strategy_DateKey(Strategy_ObservedFixed(d.year,12,25))) return true;
   return false;
  }

int Strategy_UpcomingHolidayKey(const datetime session)
  {
   for(int n=1;n<=4;n++)
     {
      datetime candidate=session+n*86400;
      if(Strategy_IsHoliday(candidate)) return Strategy_DateKey(candidate);
      const int dow=Strategy_Dow(candidate);
      if(dow>=1 && dow<=5) return 0;
     }
   return 0;
  }

bool Strategy_HasPosition()
  {
   const int magic=QM_FrameworkMagic();
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0 && PositionSelectByTicket(ticket) &&
         PositionGetString(POSITION_SYMBOL)==_Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC)==magic) return true;
     }
   return false;
  }

void Strategy_CloseExpired()
  {
   const int magic=QM_FrameworkMagic(); const datetime now=TimeCurrent();
   const datetime bar=iTime(_Symbol,PERIOD_D1,0); // perf-allowed: O(1) D1 position-expiry check, called behind the framework new-bar gate.
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || !PositionSelectByTicket(ticket)) continue;
      if((int)PositionGetInteger(POSITION_MAGIC)!=magic) continue;
      datetime opened=(datetime)PositionGetInteger(POSITION_TIME);
      if((bar>0 && Strategy_DateKey(bar)!=Strategy_DateKey(opened)) ||
         now-opened>=MathMax(1,strategy_max_hold_days)*86400)
         QM_TM_ClosePosition(ticket,QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   return (_Symbol!="XTIUSD.DWX" || _Period!=PERIOD_D1 || qm_magic_slot_offset!=0 ||
           strategy_atr_period<=0 || strategy_atr_sl_mult<=0.0 || strategy_max_hold_days<=0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type=QM_BUY; req.price=0.0; req.sl=0.0; req.tp=0.0;
   req.reason="WTI_PREHOLIDAY_LONG"; req.symbol_slot=0; req.expiration_seconds=0;
   if(Strategy_HasPosition()) return false;
   if(strategy_max_spread_points>0 && SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)>strategy_max_spread_points) return false;
   datetime bar=iTime(_Symbol,PERIOD_D1,0); // perf-allowed: O(1) D1 holiday-calendar lookup, called behind the framework new-bar gate.
   if(bar<=0) return false;
   int holiday_key=Strategy_UpcomingHolidayKey(bar);
   if(holiday_key<=0 || holiday_key==g_last_holiday_key) return false;
   double atr=QM_ATR(_Symbol,PERIOD_D1,strategy_atr_period,1); if(atr<=0.0) return false;
   double px=QM_EntryMarketPrice(req.type); if(px<=0.0) return false;
   req.sl=QM_StopATR(_Symbol,req.type,px,strategy_atr_period,strategy_atr_sl_mult);
   if(req.sl<=0.0) return false;
   g_last_holiday_key=holiday_key; return true;
  }

void Strategy_ManageOpenPosition(){ Strategy_CloseExpired(); }
bool Strategy_ExitSignal(){ return false; }
bool Strategy_NewsFilterHook(const datetime broker_time){ return false; }

int OnInit()
  {
   g_pp_active = false;
   QM_PP_ProfileInit(g_pp_profile, "DL089_OPT", QM_PPC_REFERENCE_TF, QM_PPC_CLOSED_SHIFT);
   if(!Opt_AddPattern(opt_pp_buy1, true, "opt_pp_buy1") ||
      !Opt_AddPattern(opt_pp_buy2, true, "opt_pp_buy2") ||
      !Opt_AddPattern(opt_pp_buy3, true, "opt_pp_buy3") ||
      !Opt_AddPattern(opt_pp_sell1, false, "opt_pp_sell1") ||
      !Opt_AddPattern(opt_pp_sell2, false, "opt_pp_sell2") ||
      !Opt_AddPattern(opt_pp_sell3, false, "opt_pp_sell3"))
      return INIT_FAILED;
   if(!QM_FrameworkInit(qm_ea_id,qm_magic_slot_offset,RISK_PERCENT,RISK_FIXED,PORTFOLIO_WEIGHT,
      qm_news_mode_legacy,qm_friday_close_enabled,qm_friday_close_hour_broker,30,30,
      qm_news_stale_max_hours,qm_news_min_impact,qm_rng_seed,qm_stress_reject_probability,
      qm_news_temporal,qm_news_compliance)) return INIT_FAILED;
   QM_LogEvent(QM_INFO,"INIT_OK","{\"card\":\"QM5_41303\",\"ea\":\"wti-preholiday-opt\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "PP_CENSUS_SUMMARY",
               StringFormat("{\"profile_key\":\"%s\",\"enabled\":%s,\"days_evaluated\":%I64d,\"fire_count\":%I64d,\"legs_suppressed\":%I64d,\"invalid_days\":%I64d}",
                            QM_PP_ProfileKey(g_pp_profile), (g_pp_active ? "true" : "false"),
                            g_pp_days_evaluated, g_pp_fire_count, g_pp_legs_suppressed, g_pp_invalid_days));
   QM_LogEvent(QM_INFO,"DEINIT",StringFormat("{\"reason\":%d}",reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck()) return;
   // Keep safety/close handling tick-responsive, but bound D1 strategy and
   // news evaluation to one pass per bar.  This prevents an every-tick log
   // path from producing another tester-journal bomb.
   if(QM_FrameworkHandleFridayClose() || Strategy_NoTradeFilter()) return;
   if(!QM_IsNewBar()) return;
   g_pp_reference_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: cached closed-bar census reference, once per D1 transition.
   datetime now=TimeCurrent(); if(Strategy_NewsFilterHook(now)) return;
   bool news_allows=(qm_news_temporal!=QM_NEWS_TEMPORAL_OFF || qm_news_compliance!=QM_NEWS_COMPLIANCE_NONE)
      ? QM_NewsAllowsTrade2(_Symbol,now,qm_news_temporal,qm_news_compliance)
      : QM_NewsAllowsTrade(_Symbol,now,qm_news_mode_legacy);
   if(!news_allows) return;
   QM_EquityStreamOnNewBar(); Strategy_ManageOpenPosition();
   QM_EntryRequest req; if(Strategy_EntrySignal(req) && Pattern_AllowsRequest(req)){ ulong ticket=0; QM_TM_OpenPosition(req,ticket); }
  }

void OnTimer(){ QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result){ QM_FrameworkOnTradeTransaction(trans,request,result); }
double OnTester(){ QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
