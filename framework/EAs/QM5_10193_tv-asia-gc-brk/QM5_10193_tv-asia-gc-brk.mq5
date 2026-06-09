#property strict
#property version   "5.0"
#property description "QM5_10193 TradingView Asia Gold Range Breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10193;
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
input int    strategy_broker_to_ny_offset_hours = 7;
input int    strategy_asia_start_hour_ny        = 20;
input int    strategy_asia_end_hour_ny          = 3;
input int    strategy_trade_start_hour_ny       = 3;
input int    strategy_trade_end_hour_ny         = 8;
input int    strategy_ema_period                = 200;
input int    strategy_atr_period                = 14;
input double strategy_sl_atr_mult               = 1.0;
input double strategy_tp_atr_mult               = 2.0;
input int    strategy_breakout_buffer_points    = 20;
input double strategy_max_spread_atr_ratio      = 0.15;
input double strategy_min_range_atr_mult        = 0.5;
input double strategy_max_range_atr_mult        = 3.0;
input bool   strategy_enable_trailing           = false;
input double strategy_trail_atr_mult            = 1.0;

double g_asia_high = 0.0;
double g_asia_low = 0.0;
double g_cached_atr = 0.0;
int    g_range_key = 0;
int    g_trade_day_key = 0;
bool   g_long_taken_today = false;
bool   g_short_taken_today = false;

datetime Strategy_ToNewYorkTime(const datetime broker_time)
  {
   return broker_time - (datetime)(strategy_broker_to_ny_offset_hours * 3600);
  }

int Strategy_DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_HourOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

bool Strategy_HourInWindow(const int hour, const int start_hour, const int end_hour)
  {
   if(start_hour == end_hour)
      return true;
   if(start_hour < end_hour)
      return (hour >= start_hour && hour < end_hour);
   return (hour >= start_hour || hour < end_hour);
  }

int Strategy_AsiaRangeKey(const datetime ny_time)
  {
   const int hour = Strategy_HourOf(ny_time);
   if(strategy_asia_start_hour_ny <= strategy_asia_end_hour_ny)
      return Strategy_DateKey(ny_time);
   if(hour >= strategy_asia_start_hour_ny)
      return Strategy_DateKey(ny_time + 86400);
   return Strategy_DateKey(ny_time);
  }

void Strategy_ResetTradeDay(const int trade_day_key)
  {
   if(trade_day_key == g_trade_day_key)
      return;

   g_trade_day_key = trade_day_key;
   g_long_taken_today = false;
   g_short_taken_today = false;
  }

bool Strategy_HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

void Strategy_MarkOpenDirection()
  {
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
         g_long_taken_today = true;
      if(type == POSITION_TYPE_SELL)
         g_short_taken_today = true;
     }
  }

void Strategy_AdvanceAsiaRangeFromClosedBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: one closed-bar timestamp for session range state.
   if(bar_time <= 0)
      return;

   const datetime ny_time = Strategy_ToNewYorkTime(bar_time);
   const int trade_day_key = Strategy_DateKey(ny_time);
   Strategy_ResetTradeDay(trade_day_key);

   g_cached_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   const int ny_hour = Strategy_HourOf(ny_time);
   if(!Strategy_HourInWindow(ny_hour, strategy_asia_start_hour_ny, strategy_asia_end_hour_ny))
      return;

   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: bespoke Asia range high, gated by QM_IsNewBar caller.
   const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: bespoke Asia range low, gated by QM_IsNewBar caller.
   if(bar_high <= 0.0 || bar_low <= 0.0 || bar_high <= bar_low)
      return;

   const int range_key = Strategy_AsiaRangeKey(ny_time);
   if(range_key != g_range_key)
     {
      g_range_key = range_key;
      g_asia_high = bar_high;
      g_asia_low = bar_low;
      return;
     }

   if(g_asia_high <= 0.0 || bar_high > g_asia_high)
      g_asia_high = bar_high;
   if(g_asia_low <= 0.0 || bar_low < g_asia_low)
      g_asia_low = bar_low;
  }

bool Strategy_SpreadWithinATR()
  {
   if(strategy_max_spread_atr_ratio <= 0.0 || strategy_sl_atr_mult <= 0.0)
      return true;
   if(g_cached_atr <= 0.0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double spread_points = (ask - bid) / point;
   const double stop_points = (g_cached_atr * strategy_sl_atr_mult) / point;
   return (stop_points > 0.0 && spread_points <= stop_points * strategy_max_spread_atr_ratio);
  }

bool Strategy_RangeHeightWithinATR()
  {
   if(g_asia_high <= g_asia_low || g_cached_atr <= 0.0)
      return false;

   const double range_height = g_asia_high - g_asia_low;
   return (range_height >= g_cached_atr * strategy_min_range_atr_mult &&
           range_height <= g_cached_atr * strategy_max_range_atr_mult);
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   if(Strategy_HasOurPosition())
      return false;

   const datetime ny_time = Strategy_ToNewYorkTime(TimeCurrent());
   if(!Strategy_HourInWindow(Strategy_HourOf(ny_time),
                             strategy_trade_start_hour_ny,
                             strategy_trade_end_hour_ny))
      return false;

   return !Strategy_SpreadWithinATR();
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

   Strategy_AdvanceAsiaRangeFromClosedBar();
   Strategy_MarkOpenDirection();

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar session key, gated by framework QM_IsNewBar.
   if(bar_time <= 0)
      return false;

   const datetime ny_time = Strategy_ToNewYorkTime(bar_time);
   const int trade_day_key = Strategy_DateKey(ny_time);
   Strategy_ResetTradeDay(trade_day_key);

   if(g_range_key != trade_day_key)
      return false;
   if(!Strategy_HourInWindow(Strategy_HourOf(ny_time),
                             strategy_trade_start_hour_ny,
                             strategy_trade_end_hour_ny))
      return false;
   if(!Strategy_RangeHeightWithinATR() || !Strategy_SpreadWithinATR())
      return false;

   const double bar_high = iHigh(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout high.
   const double bar_low = iLow(_Symbol, _Period, 1); // perf-allowed: closed-bar breakout low.
   const double close_last = iClose(_Symbol, _Period, 1); // perf-allowed: EMA filter uses last closed-bar close.
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bar_high <= 0.0 || bar_low <= 0.0 || close_last <= 0.0 ||
      ema <= 0.0 || point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double buffer = strategy_breakout_buffer_points * point;
   if(!g_long_taken_today && bar_high > g_asia_high + buffer && close_last > ema)
     {
      req.type = QM_BUY;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, ask, g_cached_atr, strategy_sl_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, ask, g_cached_atr, strategy_tp_atr_mult);
      req.reason = "ASIA_RANGE_BREAK_LONG";
      if(req.sl > 0.0 && req.tp > 0.0)
        {
         g_long_taken_today = true;
         return true;
        }
     }

   if(!g_short_taken_today && bar_low < g_asia_low - buffer && close_last < ema)
     {
      req.type = QM_SELL;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, bid, g_cached_atr, strategy_sl_atr_mult);
      req.tp = QM_TakeATRFromValue(_Symbol, req.type, bid, g_cached_atr, strategy_tp_atr_mult);
      req.reason = "ASIA_RANGE_BREAK_SHORT";
      if(req.sl > 0.0 && req.tp > 0.0)
        {
         g_short_taken_today = true;
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   if(!strategy_enable_trailing)
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

      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOurPosition())
      return false;

   const datetime ny_time = Strategy_ToNewYorkTime(TimeCurrent());
   return !Strategy_HourInWindow(Strategy_HourOf(ny_time),
                                 strategy_trade_start_hour_ny,
                                 strategy_trade_end_hour_ny);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10193\",\"strategy\":\"tv-asia-gc-brk\"}");
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
