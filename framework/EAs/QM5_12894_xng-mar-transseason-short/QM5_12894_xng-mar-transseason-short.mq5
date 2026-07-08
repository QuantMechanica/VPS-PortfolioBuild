#property strict
#property version   "5.0"
#property description "QM5_12894 XNG March Transseason Short"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12894 - XNG March Transseason Short
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - trades only during the March-to-mid-April shoulder transition
//   - enters at most once per broker week
//   - shorts a failed transition rebound only after downside drift below a
//     medium SMA confirms the seasonal-demand lull
// Runtime uses MT5 OHLC/broker calendar only; no EIA, storage, weather, API,
// CSV, forecast, power-load, or futures-curve feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12894;
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
input int    strategy_start_month          = 3;
input int    strategy_start_day            = 1;
input int    strategy_end_month            = 4;
input int    strategy_end_day              = 15;
input int    strategy_sma_period           = 34;
input int    strategy_rebound_lookback     = 4;
input int    strategy_drift_lookback       = 3;
input double strategy_min_rebound_atr      = 0.35;
input double strategy_min_down_drift_atr   = 0.55;
input double strategy_min_sma_stretch_atr  = 0.10;
input double strategy_max_close_location   = 0.42;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_hold_days        = 7;
input int    strategy_max_spread_points    = 2500;

int g_last_entry_week_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DateKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon * 100 + dt.day;
  }

int Strategy_WeekKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + (dt.day_of_year / 7);
  }

bool Strategy_ValidSeasonParams()
  {
   if(strategy_start_month < 1 || strategy_start_month > 12)
      return false;
   if(strategy_end_month < 1 || strategy_end_month > 12)
      return false;
   if(strategy_start_day < 1 || strategy_start_day > 31)
      return false;
   if(strategy_end_day < 1 || strategy_end_day > 31)
      return false;

   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;
   return (start_key <= end_key);
  }

bool Strategy_InTransseasonWindow(const datetime t)
  {
   const int date_key = Strategy_DateKey(t);
   if(date_key <= 0 || !Strategy_ValidSeasonParams())
      return false;

   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;
   return (date_key >= start_key && date_key <= end_key);
  }

bool Strategy_IsFirstTradingBarOfWeek()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: weekly calendar gate.
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: weekly calendar gate.
   if(current_bar <= 0 || closed_bar <= 0)
      return false;
   return (Strategy_WeekKey(current_bar) != Strategy_WeekKey(closed_bar));
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

bool Strategy_LoadTransseasonState(double &close_last,
                                   double &sma_last,
                                   double &atr_last,
                                   double &rebound_atr,
                                   double &down_drift_atr,
                                   double &sma_stretch_atr,
                                   double &close_location,
                                   datetime &current_bar_time,
                                   datetime &closed_bar_time)
  {
   current_bar_time = iTime(_Symbol, PERIOD_D1, 0); // perf-allowed: D1 calendar gate.
   closed_bar_time = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: prior closed D1 signal bar.
   close_last = iClose(_Symbol, PERIOD_D1, 1);      // perf-allowed: prior closed D1 signal bar.
   const double open_last = iOpen(_Symbol, PERIOD_D1, 1); // perf-allowed: prior closed D1 signal bar.
   const double high_last = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: prior closed D1 signal bar.
   const double low_last = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: prior closed D1 signal bar.
   if(current_bar_time <= 0 || closed_bar_time <= 0 || close_last <= 0.0 ||
      open_last <= 0.0 || high_last <= 0.0 || low_last <= 0.0 || high_last <= low_last)
      return false;

   const int sma_period = MathMax(2, strategy_sma_period);
   const int rebound_lookback = MathMax(2, strategy_rebound_lookback);
   const int drift_lookback = MathMax(1, strategy_drift_lookback);

   sma_last = QM_SMA(_Symbol, PERIOD_D1, sma_period, 1, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(sma_last <= 0.0 || atr_last <= 0.0)
      return false;

   double recent_high = 0.0;
   double drift_start_close = iClose(_Symbol, PERIOD_D1, 1 + drift_lookback);        // perf-allowed: bounded D1 drift lookback.
   double rebound_base_close = iClose(_Symbol, PERIOD_D1, 1 + rebound_lookback);     // perf-allowed: bounded D1 transition-rebound lookback.
   if(drift_start_close <= 0.0 || rebound_base_close <= 0.0)
      return false;

   for(int shift = 1; shift <= rebound_lookback; ++shift)
     {
      const double bar_high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 transition-rebound lookback.
      if(bar_high <= 0.0)
         return false;
      if(bar_high > recent_high)
         recent_high = bar_high;
     }
   if(recent_high <= 0.0)
      return false;

   close_location = (close_last - low_last) / (high_last - low_last);
   rebound_atr = (recent_high - rebound_base_close) / atr_last;
   down_drift_atr = (drift_start_close - close_last) / atr_last;
   sma_stretch_atr = (sma_last - close_last) / atr_last;

   return (MathIsValidNumber(close_location) &&
           MathIsValidNumber(rebound_atr) &&
           MathIsValidNumber(down_drift_atr) &&
           MathIsValidNumber(sma_stretch_atr));
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double rebound_atr = 0.0;
   double down_drift_atr = 0.0;
   double sma_stretch_atr = 0.0;
   double close_location = 0.0;
   datetime current_bar_time = 0;
   datetime closed_bar_time = 0;
   if(!Strategy_LoadTransseasonState(close_last,
                                     sma_last,
                                     atr_last,
                                     rebound_atr,
                                     down_drift_atr,
                                     sma_stretch_atr,
                                     close_location,
                                     current_bar_time,
                                     closed_bar_time))
      return;

   const bool in_window = Strategy_InTransseasonWindow(current_bar_time);
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = false;

      if(pos_type != POSITION_TYPE_SELL)
         should_close = true;
      if(!in_window)
         should_close = true;
      if(close_last > sma_last)
         should_close = true;
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

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
   if(!Strategy_ValidSeasonParams())
      return true;
   if(strategy_sma_period <= 1)
      return true;
   if(strategy_rebound_lookback <= 1 || strategy_drift_lookback <= 0)
      return true;
   if(strategy_min_rebound_atr <= 0.0 || strategy_min_down_drift_atr <= 0.0)
      return true;
   if(strategy_min_sma_stretch_atr < 0.0)
      return true;
   if(strategy_max_close_location <= 0.0 || strategy_max_close_location >= 1.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12894_XNG_MAR_TRANSSEASON";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsFirstTradingBarOfWeek())
      return false;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double sma_last = 0.0;
   double atr_last = 0.0;
   double rebound_atr = 0.0;
   double down_drift_atr = 0.0;
   double sma_stretch_atr = 0.0;
   double close_location = 0.0;
   datetime current_bar_time = 0;
   datetime closed_bar_time = 0;
   if(!Strategy_LoadTransseasonState(close_last,
                                     sma_last,
                                     atr_last,
                                     rebound_atr,
                                     down_drift_atr,
                                     sma_stretch_atr,
                                     close_location,
                                     current_bar_time,
                                     closed_bar_time))
      return false;

   const int current_week_key = Strategy_WeekKey(current_bar_time);
   if(current_week_key <= 0 || current_week_key == g_last_entry_week_key)
      return false;
   if(!Strategy_InTransseasonWindow(current_bar_time) || !Strategy_InTransseasonWindow(closed_bar_time))
      return false;
   if(close_last >= sma_last)
      return false;
   if(sma_stretch_atr < strategy_min_sma_stretch_atr)
      return false;
   if(rebound_atr < strategy_min_rebound_atr)
      return false;
   if(down_drift_atr < strategy_min_down_drift_atr)
      return false;
   if(close_location > strategy_max_close_location)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_MAR_TRANSSEASON_SHORT";
   g_last_entry_week_key = current_week_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_CloseOpenPositionsIfNeeded();
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12894\",\"ea\":\"xng-mar-transseason-short\"}");
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

   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();

   if(is_new_bar)
     {
      QM_EquityStreamOnNewBar();
      Strategy_ManageOpenPosition();
     }

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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!is_new_bar)
      return;

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
