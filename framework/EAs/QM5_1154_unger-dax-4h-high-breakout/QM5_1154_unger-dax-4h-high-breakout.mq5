#property strict
#property version   "5.0"
#property description "QM5_1154 Unger DAX 4H high breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1154;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_entry_start_hhmm    = 900;
input int    strategy_entry_end_hhmm      = 1200;
input int    strategy_session_end_hhmm    = 1725;
input int    strategy_hh_lookback_bars    = 16;
input int    strategy_atr_period_m15      = 14;
input int    strategy_atr_period_d1       = 14;
input double strategy_buffer_atr_mult     = 0.05;
input double strategy_sl_atr_mult         = 2.0;
input double strategy_tp_atr_mult         = 3.0;
input double strategy_min_range_d1_atr    = 0.25;
input double strategy_max_range_d1_atr    = 1.25;
input int    strategy_max_hold_sessions   = 2;
input int    strategy_max_spread_points   = 200;

int CurrentHHMM()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour * 100 + dt.min;
  }

int CurrentDayKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int CurrentDayOfWeek()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day_of_week;
  }

bool HasOurOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool HasEnteredToday()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const datetime day_start = StructToTime(dt) - (dt.hour * 3600 + dt.min * 60 + dt.sec);
   if(!HistorySelect(day_start, TimeCurrent()))
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = HistoryDealsTotal() - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol)
         continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic)
         continue;
      if((ENUM_DEAL_ENTRY)HistoryDealGetInteger(deal, DEAL_ENTRY) == DEAL_ENTRY_IN)
         return true;
     }
   return false;
  }

double HighestCompletedHigh(const ENUM_TIMEFRAMES tf, const int bars)
  {
   if(bars <= 0)
      return 0.0;

   double highest = 0.0;
   for(int shift = 1; shift <= bars; ++shift)
     {
      const double high = iHigh(_Symbol, tf, shift);
      if(high <= 0.0)
         return 0.0;
      if(highest <= 0.0 || high > highest)
         highest = high;
     }
   return highest;
  }

bool RangeFilterAllowsTrade()
  {
   const double high4h = HighestCompletedHigh(PERIOD_M15, strategy_hh_lookback_bars);
   double low4h = 0.0;
   for(int shift = 1; shift <= strategy_hh_lookback_bars; ++shift)
     {
      const double low = iLow(_Symbol, PERIOD_M15, shift);
      if(low <= 0.0)
         return false;
      if(low4h <= 0.0 || low < low4h)
         low4h = low;
     }

   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(high4h <= 0.0 || low4h <= 0.0 || atr_d1 <= 0.0 || high4h <= low4h)
      return false;

   const double range = high4h - low4h;
   if(strategy_min_range_d1_atr > 0.0 && range < atr_d1 * strategy_min_range_d1_atr)
      return false;
   if(strategy_max_range_d1_atr > 0.0 && range > atr_d1 * strategy_max_range_d1_atr)
      return false;

   return true;
  }

int TradingSessionsElapsed(const datetime from_time, const datetime to_time)
  {
   if(to_time <= from_time)
      return 0;

   int sessions = 0;
   datetime cursor = from_time;
   MqlDateTime cur_dt;
   TimeToStruct(cursor, cur_dt);
   cur_dt.hour = 0;
   cur_dt.min = 0;
   cur_dt.sec = 0;
   cursor = StructToTime(cur_dt) + 86400;

   while(cursor <= to_time)
     {
      MqlDateTime dt;
      TimeToStruct(cursor, dt);
      if(dt.day_of_week >= 1 && dt.day_of_week <= 5)
         sessions++;
      cursor += 86400;
     }
   return sessions;
  }

bool Strategy_NoTradeFilter()
  {
   if(HasOurOpenPosition())
      return false;

   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_max_spread_points > 0 && spread > strategy_max_spread_points)
      return true;

   const int dow = CurrentDayOfWeek();
   if(dow < 1 || dow > 3)
      return true;

   const int hhmm = CurrentHHMM();
   if(hhmm < strategy_entry_start_hhmm || hhmm >= strategy_entry_end_hhmm)
      return true;

   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_M15)
      return false;
   if(HasOurOpenPosition() || HasOurPendingOrder() || HasEnteredToday())
      return false;

   static int placed_day_key = 0;
   const int day_key = CurrentDayKey();
   if(day_key == placed_day_key)
      return false;

   if(!RangeFilterAllowsTrade())
      return false;

   const double hh4h = HighestCompletedHigh(PERIOD_M15, strategy_hh_lookback_bars);
   const double atr_m15 = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period_m15, 1);
   if(hh4h <= 0.0 || atr_m15 <= 0.0)
      return false;

   const double entry = NormalizeDouble(hh4h + atr_m15 * strategy_buffer_atr_mult, _Digits);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0 || ask <= 0.0 || ask >= entry)
      return false;

   req.type = QM_BUY_STOP;
   req.price = entry;
   req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr_m15, strategy_sl_atr_mult);
   req.tp = NormalizeDouble(entry + atr_m15 * strategy_tp_atr_mult, _Digits);
   req.reason = "HH4H_BREAKOUT_BUY_STOP";
   req.symbol_slot = qm_magic_slot_offset;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   const int now_min = now.hour * 60 + now.min;
   const int end_min = (strategy_entry_end_hhmm / 100) * 60 + (strategy_entry_end_hhmm % 100);
   req.expiration_seconds = MathMax(300, (end_min - now_min) * 60);

   if(req.sl <= 0.0 || req.tp <= 0.0 || req.expiration_seconds <= 0)
      return false;

   placed_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP plus max-session exit only.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const int hhmm = CurrentHHMM();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(TradingSessionsElapsed(open_time, TimeCurrent()) >= strategy_max_hold_sessions &&
         hhmm >= strategy_session_end_hhmm)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1154\",\"ea\":\"unger-dax-4h-high-breakout\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
     }
  }

void OnTimer()
  {
   QM_FrameworkOnTimer();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
