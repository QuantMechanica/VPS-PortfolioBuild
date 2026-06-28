#property strict
#property version   "5.0"
#property description "QM5_12746 EIA WTI Driving-Season Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12746 - EIA WTI Driving-Season Pullback
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - long only during the gasoline driving-season window
//   - pullback entry above a slow trend filter, rebound/date/time exits
// Runtime uses MT5 OHLC only; no EIA, inventory, product-spread, or futures feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12746;
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
input int    strategy_start_month         = 4;
input int    strategy_start_day           = 15;
input int    strategy_end_month           = 8;
input int    strategy_end_day             = 31;
input int    strategy_pullback_lookback   = 5;
input double strategy_min_down_return_pct = 0.75;
input int    strategy_trend_period        = 50;
input int    strategy_rebound_period      = 5;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_max_hold_days       = 7;
input int    strategy_max_spread_points   = 1000;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DateKey(const MqlDateTime &dt)
  {
   return dt.mon * 100 + dt.day;
  }

bool Strategy_InDrivingWindow(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);

   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;
   const int current_key = Strategy_DateKey(dt);

   if(start_key <= end_key)
      return (current_key >= start_key && current_key <= end_key);
   return (current_key >= start_key || current_key <= end_key);
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

bool Strategy_SMA(const int period, double &sma)
  {
   if(period <= 0)
      return false;

   double sum = 0.0;
   for(int shift = 1; shift <= period; ++shift)
     {
      const double close = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 SMA math on closed bars.
      if(close <= 0.0)
         return false;
      sum += close;
     }

   sma = sum / (double)period;
   return (sma > 0.0);
  }

bool Strategy_PullbackLow(const int lookback, double &lowest_low)
  {
   if(lookback <= 0)
      return false;

   lowest_low = DBL_MAX;
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double low = iLow(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 pullback low math on closed bars.
      if(low <= 0.0)
         return false;
      lowest_low = MathMin(lowest_low, low);
     }

   return (lowest_low < DBL_MAX && lowest_low > 0.0);
  }

bool Strategy_LoadClosedState(double &close_last,
                              double &close_prev,
                              double &pullback_low,
                              double &trend_sma,
                              double &rebound_sma,
                              datetime &closed_time)
  {
   closed_time = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: D1 calendar window gate.
   close_last = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: D1 pullback close on closed bars.
   close_prev = iClose(_Symbol, PERIOD_D1, 2);  // perf-allowed: D1 one-bar return on closed bars.
   if(closed_time <= 0 || close_last <= 0.0 || close_prev <= 0.0)
      return false;

   if(!Strategy_PullbackLow(strategy_pullback_lookback, pullback_low))
      return false;
   if(!Strategy_SMA(strategy_trend_period, trend_sma))
      return false;
   if(!Strategy_SMA(strategy_rebound_period, rebound_sma))
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double close_prev = 0.0;
   double pullback_low = 0.0;
   double trend_sma = 0.0;
   double rebound_sma = 0.0;
   datetime closed_time = 0;
   if(!Strategy_LoadClosedState(close_last, close_prev, pullback_low, trend_sma, rebound_sma, closed_time))
      return;

   const bool in_window = Strategy_InDrivingWindow(closed_time);
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      bool should_close = (!in_window || close_last < trend_sma || close_last >= rebound_sma);
      if(opened > 0 && now - opened >= hold_seconds)
         should_close = true;

      if(should_close)
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsXtiD1())
      return true;
   if(qm_magic_slot_offset != 0)
      return true;
   if(strategy_start_month < 1 || strategy_start_month > 12)
      return true;
   if(strategy_end_month < 1 || strategy_end_month > 12)
      return true;
   if(strategy_start_day < 1 || strategy_start_day > 31)
      return true;
   if(strategy_end_day < 1 || strategy_end_day > 31)
      return true;
   if(strategy_pullback_lookback <= 1 || strategy_trend_period <= 1 || strategy_rebound_period <= 1)
      return true;
   if(strategy_min_down_return_pct < 0.0)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12746_EIA_WTI_DRIVE_PB";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   Strategy_CloseOpenPositionsIfNeeded();

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_max_spread_points > 0)
     {
      const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
         return false;
     }

   double close_last = 0.0;
   double close_prev = 0.0;
   double pullback_low = 0.0;
   double trend_sma = 0.0;
   double rebound_sma = 0.0;
   datetime closed_time = 0;
   if(!Strategy_LoadClosedState(close_last, close_prev, pullback_low, trend_sma, rebound_sma, closed_time))
      return false;
   if(!Strategy_InDrivingWindow(closed_time))
      return false;
   if(close_last > pullback_low)
      return false;
   if(close_last <= trend_sma)
      return false;
   if(close_last >= rebound_sma)
      return false;

   const double down_return_pct = ((close_last / close_prev) - 1.0) * 100.0;
   if(down_return_pct > -strategy_min_down_return_pct)
      return false;

   req.type = QM_BUY;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "EIA_WTI_DRIVING_SEASON_PULLBACK_LONG";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12746\",\"ea\":\"eia-wti-drive-pb\"}");
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
