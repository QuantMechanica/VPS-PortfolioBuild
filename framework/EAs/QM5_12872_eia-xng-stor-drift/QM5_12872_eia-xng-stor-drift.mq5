#property strict
#property version   "5.0"
#property description "QM5_12872 EIA XNG Storage Drift"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12872 - EIA XNG Storage Drift
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - uses EIA storage-report cadence and storage-season structure as lineage
//   - follows confirmed withdrawal/injection-shoulder report-window drift
//   - max one entry per broker-calendar month
// Runtime uses MT5 OHLC/broker calendar only; no EIA feed, weather feed,
// futures curve, CSV, API, analyst forecast, or discretionary input.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12872;
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
input int    strategy_atr_period             = 20;
input int    strategy_trend_period           = 50;
input int    strategy_drift_lookback         = 3;
input double strategy_min_drift_atr          = 0.95;
input double strategy_min_body_ratio         = 0.25;
input double strategy_min_trend_stretch_atr  = 0.25;
input double strategy_high_close_location    = 0.62;
input double strategy_low_close_location     = 0.38;
input double strategy_atr_sl_mult            = 3.10;
input int    strategy_max_hold_days          = 6;
input int    strategy_max_spread_points      = 2500;

int g_last_signal_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_Month(const datetime t)
  {
   if(t <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

int Strategy_DayOfWeek(const datetime t)
  {
   if(t <= 0)
      return -1;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool Strategy_ReportWindowDay(const datetime bar_time)
  {
   const int dow = Strategy_DayOfWeek(bar_time);
   return (dow == 3 || dow == 4 || dow == 5);
  }

int Strategy_SeasonalDirection(const int month)
  {
   if(month == 11 || month == 12 || month == 1 || month == 2 || month == 3)
      return 1;
   if(month == 4 || month == 5 || month == 9 || month == 10)
      return -1;
   return 0;
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

bool Strategy_LoadDriftState(int &direction,
                             double &atr_last,
                             double &sma_last,
                             int &signal_month_key)
  {
   direction = 0;
   atr_last = 0.0;
   sma_last = 0.0;
   signal_month_key = 0;

   const datetime signal_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 storage-report window.
   if(signal_time <= 0 || !Strategy_ReportWindowDay(signal_time))
      return false;

   const int seasonal_direction = Strategy_SeasonalDirection(Strategy_Month(signal_time));
   if(seasonal_direction == 0)
      return false;

   const double signal_open = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: completed D1 signal bar.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: completed D1 signal bar.
   const double signal_close = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: completed D1 signal bar.
   const int start_shift = 1 + MathMax(1, strategy_drift_lookback);
   const double drift_start_close = iClose(_Symbol, PERIOD_D1, start_shift); // perf-allowed: compact D1 drift window.
   if(signal_open <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(drift_start_close <= 0.0 || signal_high <= signal_low)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0)
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = signal_close - signal_open;
   const double body_ratio = MathAbs(signal_body) / signal_range;
   const double close_location = (signal_close - signal_low) / signal_range;
   const double drift = signal_close - drift_start_close;
   const double trend_stretch = MathAbs(signal_close - sma_last) / atr_last;
   if(body_ratio < strategy_min_body_ratio)
      return false;
   if(trend_stretch < strategy_min_trend_stretch_atr)
      return false;

   const bool withdrawal_long =
      seasonal_direction > 0 &&
      signal_body > 0.0 &&
      close_location >= strategy_high_close_location &&
      drift >= strategy_min_drift_atr * atr_last &&
      signal_close > sma_last;

   const bool injection_short =
      seasonal_direction < 0 &&
      signal_body < 0.0 &&
      close_location <= strategy_low_close_location &&
      drift <= -strategy_min_drift_atr * atr_last &&
      signal_close < sma_last;

   if(withdrawal_long)
      direction = 1;
   else if(injection_short)
      direction = -1;
   else
      return false;

   signal_month_key = Strategy_MonthKey(signal_time);
   return (signal_month_key > 0);
  }

void Strategy_CloseExpiredOrTrendFailedPositions()
  {
   const int magic = QM_FrameworkMagic();
   const datetime now = TimeCurrent();
   const int hold_seconds = MathMax(1, strategy_max_hold_days) * 86400;
   const double close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 trend-exit, new-bar gated by caller.
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
   if(strategy_atr_period <= 1 || strategy_trend_period <= 1)
      return true;
   if(strategy_drift_lookback <= 0 || strategy_min_drift_atr <= 0.0)
      return true;
   if(strategy_min_body_ratio <= 0.0 || strategy_min_body_ratio > 1.0)
      return true;
   if(strategy_min_trend_stretch_atr < 0.0)
      return true;
   if(strategy_high_close_location <= 0.5 || strategy_high_close_location >= 1.0)
      return true;
   if(strategy_low_close_location <= 0.0 || strategy_low_close_location >= 0.5)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12872_EIA_XNG_STOR_DRIFT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   int direction = 0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   int signal_month_key = 0;
   if(!Strategy_LoadDriftState(direction, atr_last, sma_last, signal_month_key))
      return false;
   if(signal_month_key <= 0 || signal_month_key == g_last_signal_month_key)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry_price)
      return false;
   if(req.type == QM_SELL && req.sl <= entry_price)
      return false;

   req.reason = (direction > 0) ? "EIA_XNG_STOR_DRIFT_LONG" : "EIA_XNG_STOR_DRIFT_SHORT";
   g_last_signal_month_key = signal_month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12872\",\"ea\":\"eia-xng-stor-drift\"}");
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();
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
