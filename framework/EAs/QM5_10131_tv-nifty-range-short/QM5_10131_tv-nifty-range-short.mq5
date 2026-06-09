#property strict
#property version   "5.0"
#property description "QM5_10131 TradingView Nifty Range Short Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10131;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal     = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance   = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_atr_period           = 14;
input int    strategy_open_range_minutes   = 60;
input double strategy_min_range_atr_mult   = 0.5;
input double strategy_max_range_atr_mult   = 2.5;
input double strategy_range_sl_atr_mult    = 0.5;
input double strategy_entry_sl_atr_mult    = 1.5;
input double strategy_max_spread_stop_frac = 0.10;
input int    strategy_dax_start_hour       = 9;
input int    strategy_dax_start_minute     = 0;
input int    strategy_dax_end_hour         = 17;
input int    strategy_dax_end_minute       = 30;
input int    strategy_us_start_hour        = 15;
input int    strategy_us_start_minute      = 30;
input int    strategy_us_end_hour          = 22;
input int    strategy_us_end_minute        = 0;

int      g_strategy_day_key       = -1;
bool     g_strategy_range_ready   = false;
bool     g_strategy_range_valid   = false;
bool     g_strategy_swept_high    = false;
bool     g_strategy_trade_taken   = false;
double   g_strategy_range_high    = 0.0;
double   g_strategy_range_low     = 0.0;
double   g_strategy_last_high     = 0.0;
double   g_strategy_last_low      = 0.0;
double   g_strategy_last_close    = 0.0;
datetime g_strategy_session_start = 0;
datetime g_strategy_range_end     = 0;
datetime g_strategy_session_end   = 0;
datetime g_strategy_sweep_bar     = 0;

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

datetime Strategy_DayTime(const datetime t, const int hour_value, const int minute_value)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = hour_value;
   dt.min = minute_value;
   dt.sec = 0;
   return StructToTime(dt);
  }

void Strategy_SessionTimes(const datetime t,
                           datetime &session_start,
                           datetime &range_end,
                           datetime &session_end)
  {
   int start_h = strategy_us_start_hour;
   int start_m = strategy_us_start_minute;
   int end_h = strategy_us_end_hour;
   int end_m = strategy_us_end_minute;

   if(StringFind(_Symbol, "GDAXI") >= 0 || StringFind(_Symbol, "DAX") >= 0 || StringFind(_Symbol, "DE30") >= 0)
     {
      start_h = strategy_dax_start_hour;
      start_m = strategy_dax_start_minute;
      end_h = strategy_dax_end_hour;
      end_m = strategy_dax_end_minute;
     }

   session_start = Strategy_DayTime(t, start_h, start_m);
   range_end = session_start + strategy_open_range_minutes * 60;
   session_end = Strategy_DayTime(t, end_h, end_m);
   if(session_end <= session_start)
      session_end += 24 * 60 * 60;
  }

bool Strategy_HasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

void Strategy_ResetSession(const datetime broker_time)
  {
   g_strategy_day_key = Strategy_DayKey(broker_time);
   g_strategy_range_ready = false;
   g_strategy_range_valid = false;
   g_strategy_swept_high = false;
   g_strategy_trade_taken = false;
   g_strategy_range_high = 0.0;
   g_strategy_range_low = 0.0;
   g_strategy_last_high = 0.0;
   g_strategy_last_low = 0.0;
   g_strategy_last_close = 0.0;
   g_strategy_sweep_bar = 0;
   Strategy_SessionTimes(broker_time,
                         g_strategy_session_start,
                         g_strategy_range_end,
                         g_strategy_session_end);
  }

void Strategy_UpdateOpeningRange()
  {
   // perf-allowed: bespoke opening-range structure, called only by Strategy_EntrySignal after the framework QM_IsNewBar gate.
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed
   if(bar_time <= 0)
      return;

   if(g_strategy_day_key != Strategy_DayKey(bar_time))
      Strategy_ResetSession(bar_time);

   if(bar_time < g_strategy_session_start || bar_time >= g_strategy_session_end)
      return;

   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed
   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return;

   g_strategy_last_high = high1;
   g_strategy_last_low = low1;
   g_strategy_last_close = close1;

   if(bar_time < g_strategy_range_end)
     {
      if(g_strategy_range_high <= 0.0 || high1 > g_strategy_range_high)
         g_strategy_range_high = high1;
      if(g_strategy_range_low <= 0.0 || low1 < g_strategy_range_low)
         g_strategy_range_low = low1;
      return;
     }

   if(!g_strategy_range_ready)
     {
      const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
      const double range_height = g_strategy_range_high - g_strategy_range_low;
      g_strategy_range_valid = (atr > 0.0 &&
                                range_height >= strategy_min_range_atr_mult * atr &&
                                range_height <= strategy_max_range_atr_mult * atr);
      g_strategy_range_ready = true;
     }

   if(g_strategy_range_ready && g_strategy_range_valid &&
      !g_strategy_swept_high && high1 > g_strategy_range_high)
     {
      g_strategy_swept_high = true;
      g_strategy_sweep_bar = bar_time;
     }
  }

// =============================================================================
// No Trade Filter (time, spread, news)
// =============================================================================
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(g_strategy_day_key != Strategy_DayKey(broker_now))
      Strategy_ResetSession(broker_now);

   if(Strategy_HasOpenPosition())
      return false;

   return (broker_now < g_strategy_session_start || broker_now >= g_strategy_session_end);
  }

// =============================================================================
// Trade Entry
// =============================================================================
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_10131_OR_SWEEP_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_UpdateOpeningRange();

   if(g_strategy_trade_taken || Strategy_HasOpenPosition())
      return false;
   if(!g_strategy_range_ready || !g_strategy_range_valid || !g_strategy_swept_high)
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed
   if(bar_time <= g_strategy_sweep_bar || bar_time < g_strategy_range_end || bar_time >= g_strategy_session_end)
      return false;

   const double close1 = g_strategy_last_close;
   if(close1 <= 0.0 || close1 >= g_strategy_range_high)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(bid <= 0.0 || ask <= 0.0 || atr <= 0.0)
      return false;

   const double sl_from_range = g_strategy_range_high + strategy_range_sl_atr_mult * atr;
   const double sl_from_entry = bid + strategy_entry_sl_atr_mult * atr;
   const double sl = MathMax(sl_from_range, sl_from_entry);
   const double stop_distance = sl - bid;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > strategy_max_spread_stop_frac * stop_distance)
      return false;

   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(g_strategy_range_low, _Digits);
   if(req.tp <= 0.0 || req.tp >= bid)
      req.tp = 0.0;

   g_strategy_trade_taken = true;
   return true;
  }

// =============================================================================
// Trade Management
// =============================================================================
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing stop, partial close, or add-on logic.
  }

// =============================================================================
// Trade Close
// =============================================================================
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime broker_now = TimeCurrent();
   if(g_strategy_day_key != Strategy_DayKey(broker_now))
      Strategy_ResetSession(broker_now);

   if(broker_now >= g_strategy_session_end)
      return true;

   if(!g_strategy_range_ready || g_strategy_range_high <= 0.0 || g_strategy_range_low <= 0.0)
      return false;

   if(g_strategy_last_close <= g_strategy_range_low)
      return true;
   if(g_strategy_last_close > g_strategy_range_high)
      return true;

   return false;
  }

// =============================================================================
// News Filter Hook
// =============================================================================
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10131_tv_nifty_range_short\"}");
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
