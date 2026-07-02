#property strict
#property version   "5.0"
#property description "QM5_12898 EIA XNG Multiday Drift"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12898 - EIA XNG Post-Storage Multiday Drift
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - identify a likely EIA storage-report event bar from broker day-of-week
//   - require directional close location, body, ATR range, and SMA agreement
//   - enter at market on the next eligible D1 bar for a short continuation drift
// Runtime uses MT5 OHLC/broker calendar only; no EIA feed, storage surprise feed,
// weather feed, futures curve, CSV, API, or discretionary input.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12898;
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
input int    strategy_event_min_dow              = 3;
input int    strategy_event_max_dow              = 5;
input int    strategy_entry_min_dow              = 1;
input int    strategy_entry_max_dow              = 5;
input int    strategy_atr_period                 = 20;
input int    strategy_trend_period               = 50;
input double strategy_min_event_range_atr        = 0.80;
input double strategy_max_event_range_atr        = 3.50;
input double strategy_close_location_threshold   = 0.65;
input double strategy_min_body_ratio             = 0.25;
input double strategy_atr_sl_mult                = 3.00;
input double strategy_atr_tp_mult                = 0.00;
input int    strategy_signal_valid_days          = 1;
input int    strategy_max_hold_days              = 4;
input int    strategy_max_spread_points          = 2500;
input bool   strategy_require_trend              = true;

bool     g_signal_active = false;
int      g_signal_direction = 0;
int      g_signal_event_key = 0;
int      g_last_entry_event_key = 0;
datetime g_signal_event_time = 0;
datetime g_signal_created_at = 0;
double   g_signal_atr = 0.0;
double   g_signal_sma = 0.0;
double   g_signal_event_close = 0.0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool Strategy_DowInRange(const int dow, const int min_dow, const int max_dow)
  {
   if(dow < 0 || min_dow < 0 || min_dow > 6 || max_dow < 0 || max_dow > 6)
      return false;
   if(min_dow <= max_dow)
      return (dow >= min_dow && dow <= max_dow);
   return (dow >= min_dow || dow <= max_dow);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_SpreadOK()
  {
   if(strategy_max_spread_points <= 0)
      return true;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points > strategy_max_spread_points)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask > 0.0 && bid > 0.0);
  }

void Strategy_ClearSignal()
  {
   g_signal_active = false;
   g_signal_direction = 0;
   g_signal_event_key = 0;
   g_signal_event_time = 0;
   g_signal_created_at = 0;
   g_signal_atr = 0.0;
   g_signal_sma = 0.0;
   g_signal_event_close = 0.0;
  }

bool Strategy_LoadDriftSignal(int &direction,
                              double &event_atr,
                              double &event_sma,
                              double &event_close,
                              datetime &event_time,
                              datetime &entry_time,
                              int &event_key)
  {
   direction = 0;
   event_atr = 0.0;
   event_sma = 0.0;
   event_close = 0.0;
   event_time = 0;
   entry_time = 0;
   event_key = 0;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   if(CopyRates(_Symbol, PERIOD_D1, 1, 1, rates) < 1) // perf-allowed: one completed D1 event bar, new-bar gated.
      return false;

   const MqlRates event = rates[0];
   entry_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: current D1 entry-bar timestamp, new-bar gated structural event timing.
   if(entry_time <= 0)
      return false;

   const int event_dow = Strategy_DayOfWeek(event.time);
   const int entry_dow = Strategy_DayOfWeek(entry_time);
   if(!Strategy_DowInRange(event_dow, strategy_event_min_dow, strategy_event_max_dow))
      return false;
   if(!Strategy_DowInRange(entry_dow, strategy_entry_min_dow, strategy_entry_max_dow))
      return false;

   if(event.open <= 0.0 || event.high <= 0.0 || event.low <= 0.0 || event.close <= 0.0)
      return false;
   const double event_range = event.high - event.low;
   if(event_range <= 0.0)
      return false;

   event_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   event_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(event_atr <= 0.0 || event_sma <= 0.0)
      return false;

   const double range_atr = event_range / event_atr;
   if(range_atr < strategy_min_event_range_atr || range_atr > strategy_max_event_range_atr)
      return false;

   const double body_ratio = MathAbs(event.close - event.open) / event_range;
   if(body_ratio < strategy_min_body_ratio)
      return false;

   const double close_location = (event.close - event.low) / event_range;
   if(!MathIsValidNumber(close_location))
      return false;

   event_close = event.close;
   event_time = event.time;
   event_key = Strategy_DayKey(event.time);
   if(event_key <= 0 || event_key == g_last_entry_event_key)
      return false;

   const bool bull = (event.close > event.open);
   const bool bear = (event.close < event.open);
   const bool trend_long = (!strategy_require_trend || event.close > event_sma);
   const bool trend_short = (!strategy_require_trend || event.close < event_sma);

   if(bull && close_location >= strategy_close_location_threshold && trend_long)
      direction = 1;
   else if(bear && close_location <= (1.0 - strategy_close_location_threshold) && trend_short)
      direction = -1;

   return (direction != 0);
  }

void Strategy_UpdateSignalCache()
  {
   Strategy_ClearSignal();

   int direction = 0;
   double event_atr = 0.0;
   double event_sma = 0.0;
   double event_close = 0.0;
   datetime event_time = 0;
   datetime entry_time = 0;
   int event_key = 0;
   if(!Strategy_LoadDriftSignal(direction, event_atr, event_sma, event_close,
                                event_time, entry_time, event_key))
      return;

   g_signal_active = true;
   g_signal_direction = direction;
   g_signal_event_key = event_key;
   g_signal_event_time = event_time;
   g_signal_created_at = entry_time;
   g_signal_atr = event_atr;
   g_signal_sma = event_sma;
   g_signal_event_close = event_close;
  }

bool Strategy_SignalStillValid()
  {
   if(!g_signal_active || g_signal_direction == 0 || g_signal_event_key <= 0)
      return false;
   if(g_signal_event_key == g_last_entry_event_key)
      return false;
   if(g_signal_created_at <= 0)
      return false;

   const int max_age_seconds = MathMax(1, strategy_signal_valid_days) * 86400;
   if(TimeCurrent() - g_signal_created_at > max_age_seconds)
      return false;
   return true;
  }

void Strategy_CloseExpiredOrTrendFailedPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 trend-exit, only when position loop runs.
   const double sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   const bool have_trend = (close_last > 0.0 && sma_last > 0.0);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      bool should_close = (opened > 0 && now - opened >= hold_seconds);
      if(have_trend)
        {
         if(pos_type == POSITION_TYPE_BUY && close_last < sma_last)
            should_close = true;
         if(pos_type == POSITION_TYPE_SELL && close_last > sma_last)
            should_close = true;
        }

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXngD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_event_min_dow < 0 || strategy_event_min_dow > 6 ||
      strategy_event_max_dow < 0 || strategy_event_max_dow > 6 ||
      strategy_entry_min_dow < 0 || strategy_entry_min_dow > 6 ||
      strategy_entry_max_dow < 0 || strategy_entry_max_dow > 6)
      return true;
   if(strategy_atr_period <= 1 || strategy_trend_period <= 1)
      return true;
   if(strategy_min_event_range_atr <= 0.0 || strategy_max_event_range_atr <= strategy_min_event_range_atr)
      return true;
   if(strategy_close_location_threshold <= 0.50 || strategy_close_location_threshold >= 0.95)
      return true;
   if(strategy_min_body_ratio <= 0.0 || strategy_min_body_ratio >= 1.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult < 0.0)
      return true;
   if(strategy_signal_valid_days <= 0 || strategy_max_hold_days <= 0)
      return true;
   if(strategy_max_spread_points < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12898_EIA_XNG_MULTIDAY_DRIFT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_SignalStillValid())
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadOK())
      return false;
   if(g_signal_atr <= 0.0)
      return false;

   req.type = (g_signal_direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, g_signal_atr, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   if(strategy_atr_tp_mult > 0.0)
     {
      req.tp = QM_StopRulesTakeFromDistance(_Symbol,
                                            req.type,
                                            entry_price,
                                            g_signal_atr * strategy_atr_tp_mult);
      if(req.tp <= 0.0)
         return false;
     }

   req.reason = (g_signal_direction > 0) ? "EIA_XNG_STORAGE_DRIFT_LONG" : "EIA_XNG_STORAGE_DRIFT_SHORT";
   g_last_entry_event_key = g_signal_event_key;
   g_signal_active = false;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseExpiredOrTrendFailedPositions();
  }

bool Strategy_ExitSignal()
  {
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12898\",\"ea\":\"xng-eia-multiday-drift\"}");
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

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_UpdateSignalCache();
     }

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
