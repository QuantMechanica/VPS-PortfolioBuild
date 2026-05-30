#property strict
#property version   "5.0"
#property description "QM5_10368 Elite Trader EMA Stop Entry"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10368;
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
input int    strategy_ema_period          = 200;
input int    strategy_atr_period          = 14;
input double strategy_trigger_ticks       = 6.0;
input double strategy_stop_atr_mult       = 1.0;
input double strategy_target_atr_mult     = 1.5;
input int    strategy_session_start_hhmm  = 800;
input int    strategy_session_end_hhmm    = 1600;
input int    strategy_spread_lookback     = 64;
input double strategy_spread_median_mult  = 2.5;

double g_spread_samples[64];
int    g_spread_count = 0;
int    g_spread_head = 0;
int    g_trade_day_key = 0;
bool   g_trade_taken_today = false;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

void RefreshTradeDay()
  {
   const int today = DateKey(TimeCurrent());
   if(today != g_trade_day_key)
     {
      g_trade_day_key = today;
      g_trade_taken_today = false;
     }
  }

bool InSession(const datetime t)
  {
   const int now_hhmm = Hhmm(t);
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      return (now_hhmm >= strategy_session_start_hhmm &&
              now_hhmm < strategy_session_end_hhmm);
   return (now_hhmm >= strategy_session_start_hhmm ||
           now_hhmm < strategy_session_end_hhmm);
  }

bool SessionEnded(const datetime t)
  {
   const int now_hhmm = Hhmm(t);
   if(strategy_session_start_hhmm <= strategy_session_end_hhmm)
      return (now_hhmm >= strategy_session_end_hhmm);
   return (now_hhmm >= strategy_session_end_hhmm &&
           now_hhmm < strategy_session_start_hhmm);
  }

void PushSpreadSample()
  {
   const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return;

   g_spread_samples[g_spread_head] = (double)spread;
   g_spread_head = (g_spread_head + 1) % 64;
   if(g_spread_count < 64)
      g_spread_count++;
  }

double MedianSpread()
  {
   const int requested = MathMax(1, MathMin(strategy_spread_lookback, 64));
   const int count = MathMin(g_spread_count, requested);
   if(count <= 0)
      return 0.0;

   double work[];
   ArrayResize(work, count);
   for(int i = 0; i < count; ++i)
     {
      int idx = g_spread_head - 1 - i;
      while(idx < 0)
         idx += 64;
      work[i] = g_spread_samples[idx % 64];
     }

   ArraySort(work);
   const int mid = count / 2;
   if((count % 2) == 1)
      return work[mid];
   return (work[mid - 1] + work[mid]) * 0.5;
  }

bool SpreadAllowed()
  {
   const double median = MedianSpread();
   if(median <= 0.0)
      return true;

   const double current = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current <= 0.0)
      return false;
   return (current <= strategy_spread_median_mult * median);
  }

bool HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_STOP || type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

int SecondsUntilSessionEnd()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int end_hour = strategy_session_end_hhmm / 100;
   const int end_min = strategy_session_end_hhmm % 100;
   dt.hour = end_hour;
   dt.min = end_min;
   dt.sec = 0;

   datetime end_time = StructToTime(dt);
   if(end_time <= TimeCurrent())
      end_time += 86400;

   const int seconds = (int)(end_time - TimeCurrent());
   return MathMax(60, seconds);
  }

bool Strategy_NoTradeFilter()
  {
   RefreshTradeDay();
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshTradeDay();
   PushSpreadSample();

   if(g_trade_taken_today || HasOurPendingOrder())
      return false;
   if(!InSession(TimeCurrent()))
      return false;
   if(strategy_ema_period < 2 || strategy_atr_period < 1)
      return false;
   if(!SpreadAllowed())
      return false;

   const double close_1 = iClose(_Symbol, _Period, 1);
   const double close_2 = iClose(_Symbol, _Period, 2);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double low_1 = iLow(_Symbol, _Period, 1);
   const double ema_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 1);
   const double ema_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_period, 2);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(close_1 <= 0.0 || close_2 <= 0.0 || high_1 <= 0.0 || low_1 <= 0.0 ||
      ema_1 <= 0.0 || ema_2 <= 0.0 || atr <= 0.0 || tick_size <= 0.0 ||
      point <= 0.0)
      return false;

   const double trigger_offset = strategy_trigger_ticks * tick_size;
   const double stop_distance = strategy_stop_atr_mult * atr;
   const double target_distance = strategy_target_atr_mult * atr;
   if(trigger_offset <= 0.0 || stop_distance <= 0.0 || target_distance <= 0.0)
      return false;
   if((stop_distance / point) < 4.0 * (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD))
      return false;

   const bool crossed_up = (close_2 <= ema_2 && close_1 > ema_1);
   const bool crossed_down = (close_2 >= ema_2 && close_1 < ema_1);

   if(crossed_up)
     {
      const double entry = high_1 + trigger_offset;
      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = entry - stop_distance;
      req.tp = entry + target_distance;
      req.expiration_seconds = SecondsUntilSessionEnd();
      req.reason = "ET_EMA_STOP_LONG";
      g_trade_taken_today = true;
      return true;
     }

   if(crossed_down)
     {
      const double entry = low_1 - trigger_offset;
      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = entry + stop_distance;
      req.tp = entry - target_distance;
      req.expiration_seconds = SecondsUntilSessionEnd();
      req.reason = "ET_EMA_STOP_SHORT";
      g_trade_taken_today = true;
      return true;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card baseline uses fixed ATR SL/TP. No trailing, BE, or partial close.
  }

bool Strategy_ExitSignal()
  {
   return SessionEnded(TimeCurrent());
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return !QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
