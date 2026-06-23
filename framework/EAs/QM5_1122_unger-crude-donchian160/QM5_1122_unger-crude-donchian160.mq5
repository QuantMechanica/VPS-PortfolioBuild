#property strict
#property version   "5.0"
#property description "QM5_1122 Unger Crude Donchian 160"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1122;
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
input int    strategy_donchian_period          = 160;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 3.0;
input bool   strategy_trailing_enabled         = false;
input double strategy_trailing_atr_mult        = 2.5;
input int    strategy_max_sessions             = 10;
input int    strategy_session_start_hour       = 1;
input int    strategy_session_start_minute     = 0;
input int    strategy_session_end_hour         = 24;
input int    strategy_session_end_minute       = 0;
input int    strategy_session_skip_minutes     = 30;
input double strategy_max_spread_points        = 0.0;
input bool   strategy_d1_vol_gate_enabled      = true;
input int    strategy_d1_atr_period            = 14;
input int    strategy_d1_atr_lookback          = 120;
input double strategy_d1_atr_min_percentile    = 25.0;
input bool   strategy_allow_same_bar_reversal  = false;

double   g_channel_high = 0.0;
double   g_channel_low = 0.0;
double   g_last_closed_close = 0.0;
datetime g_opposite_exit_bar_time = 0;

int Strategy_MinutesOfDay(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 60 + dt.min;
  }

int Strategy_ClampedSessionMinute(const int hour_value, const int minute_value)
  {
   int hour = hour_value;
   if(hour < 0)
      hour = 0;
   if(hour > 24)
      hour = 24;

   int minute = minute_value;
   if(minute < 0)
      minute = 0;
   if(minute > 59)
      minute = 59;

   if(hour == 24)
      return 1440;
   return hour * 60 + minute;
  }

bool Strategy_IsInsideSession(const datetime broker_time)
  {
   const int now_min = Strategy_MinutesOfDay(broker_time);
   const int start_min = Strategy_ClampedSessionMinute(strategy_session_start_hour, strategy_session_start_minute) + strategy_session_skip_minutes;
   const int end_min = Strategy_ClampedSessionMinute(strategy_session_end_hour, strategy_session_end_minute) - strategy_session_skip_minutes;

   if(strategy_session_skip_minutes < 0 || start_min == end_min)
      return true;

   if(start_min < end_min)
      return (now_min >= start_min && now_min < end_min);

   return (now_min >= start_min || now_min < end_min);
  }

bool Strategy_SpreadBlocked()
  {
   if(strategy_max_spread_points <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;

   if(ask > bid && ((ask - bid) / point) > strategy_max_spread_points)
      return true;

   return false;
  }

bool Strategy_LoadDonchian(const int first_shift, double &channel_high, double &channel_low)
  {
   if(strategy_donchian_period < 2 || first_shift < 1)
      return false;

   double hi = -DBL_MAX;
   double lo = DBL_MAX;
   for(int shift = first_shift; shift < first_shift + strategy_donchian_period; ++shift)
     {
      const double h = iHigh(_Symbol, _Period, shift); // perf-allowed: bounded Donchian structural scan, called only from the framework closed-bar entry hook.
      const double l = iLow(_Symbol, _Period, shift);  // perf-allowed: bounded Donchian structural scan, called only from the framework closed-bar entry hook.
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > hi)
         hi = h;
      if(l < lo)
         lo = l;
     }

   if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
      return false;

   channel_high = hi;
   channel_low = lo;
   return true;
  }

bool Strategy_D1VolatilityAllows()
  {
   if(!strategy_d1_vol_gate_enabled)
      return true;
   if(strategy_d1_atr_period < 1 || strategy_d1_atr_lookback < 20)
      return false;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, 1);
   if(current_atr <= 0.0)
      return false;

   double samples[];
   ArrayResize(samples, strategy_d1_atr_lookback);
   int valid = 0;
   for(int shift = 1; shift <= strategy_d1_atr_lookback; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, shift);
      if(atr <= 0.0)
         continue;
      samples[valid] = atr;
      valid++;
     }

   if(valid < 20)
      return false;

   ArrayResize(samples, valid);
   ArraySort(samples);

   double pct = strategy_d1_atr_min_percentile;
   if(pct < 0.0)
      pct = 0.0;
   if(pct > 100.0)
      pct = 100.0;

   int idx = (int)MathFloor((valid - 1) * pct / 100.0);
   if(idx < 0)
      idx = 0;
   if(idx >= valid)
      idx = valid - 1;

   return (current_atr >= samples[idx]);
  }

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &ptype, ulong &ticket, datetime &opened_at)
  {
   ptype = POSITION_TYPE_BUY;
   ticket = 0;
   opened_at = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      ticket = t;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsInsideSession(TimeCurrent()))
      return true;

   if(Strategy_SpreadBlocked())
      return true;

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

   double channel_high = 0.0;
   double channel_low = 0.0;
   if(!Strategy_LoadDonchian(2, channel_high, channel_low))
      return false;

   g_channel_high = channel_high;
   g_channel_low = channel_low;
   g_last_closed_close = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar breakout close inside the framework closed-bar entry hook.
   if(g_last_closed_close <= 0.0)
      return false;

   if(!strategy_allow_same_bar_reversal)
     {
      const datetime closed_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: same-bar reversal suppression inside the framework closed-bar entry hook.
      if(closed_bar_time > 0 && closed_bar_time == g_opposite_exit_bar_time)
         return false;
     }

   if(!Strategy_D1VolatilityAllows())
      return false;

   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   datetime opened_at;
   if(Strategy_FindOurPosition(ptype, ticket, opened_at))
      return false;

   QM_OrderType side = QM_BUY;
   if(g_last_closed_close > channel_high)
      side = QM_BUY;
   else if(g_last_closed_close < channel_low)
      side = QM_SELL;
   else
      return false;

   const double entry_price = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_price <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "DONCHIAN160_LONG_BREAKOUT" : "DONCHIAN160_SHORT_BREAKOUT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_trailing_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trailing_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   ulong ticket;
   datetime opened_at;
   if(!Strategy_FindOurPosition(ptype, ticket, opened_at))
      return false;

   if(strategy_max_sessions > 0 && opened_at > 0)
     {
      const int seconds_cap = strategy_max_sessions * 86400;
      if((TimeCurrent() - opened_at) >= seconds_cap)
         return true;
     }

   if(g_channel_high <= 0.0 || g_channel_low <= 0.0 || g_last_closed_close <= 0.0)
      return false;

   const datetime closed_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: one timestamp read for opposite-signal reversal suppression.
   if(ptype == POSITION_TYPE_BUY && g_last_closed_close < g_channel_low)
     {
      if(closed_bar_time > 0)
         g_opposite_exit_bar_time = closed_bar_time;
      return true;
     }

   if(ptype == POSITION_TYPE_SELL && g_last_closed_close > g_channel_high)
     {
      if(closed_bar_time > 0)
         g_opposite_exit_bar_time = closed_bar_time;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1122_unger-crude-donchian160\"}");
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
