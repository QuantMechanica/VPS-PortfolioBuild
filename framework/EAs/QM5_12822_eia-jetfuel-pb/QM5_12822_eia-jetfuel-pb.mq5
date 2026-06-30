#property strict
#property version   "5.0"
#property description "QM5_12822 EIA Jet Fuel Summer Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12822 - EIA Jet Fuel Summer Pullback
// -----------------------------------------------------------------------------
// D1 structural WTI sleeve:
//   - long-only XTIUSD controlled pullbacks during the summer jet-fuel window
//   - requires rising D1 trend so runtime stays price-only and low-frequency
// Runtime uses MT5 OHLC/calendar only; no EIA, airline, refinery, or crack data.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12822;
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
input int    strategy_start_month             = 5;
input int    strategy_start_day               = 15;
input int    strategy_end_month               = 8;
input int    strategy_end_day                 = 31;
input int    strategy_trend_period            = 100;
input int    strategy_fast_sma_period         = 20;
input int    strategy_sma_slope_shift         = 10;
input int    strategy_pullback_lookback       = 3;
input double strategy_max_pullback_close_atr  = 1.25;
input double strategy_min_pullback_depth_atr  = 0.45;
input double strategy_max_pullback_depth_atr  = 2.75;
input double strategy_min_close_location      = 0.55;
input int    strategy_exit_channel            = 8;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 3.0;
input int    strategy_max_hold_days           = 21;
input int    strategy_max_spread_points       = 1000;

int g_last_signal_day_key = 0;

bool Strategy_IsXtiD1()
  {
   return (_Symbol == "XTIUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int Strategy_MonthDayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon * 100 + dt.day;
  }

bool Strategy_InJetFuelWindow(const datetime t)
  {
   const int key = Strategy_MonthDayKey(t);
   const int start_key = strategy_start_month * 100 + strategy_start_day;
   const int end_key = strategy_end_month * 100 + strategy_end_day;
   if(start_key <= end_key)
      return (key >= start_key && key <= end_key);
   return (key >= start_key || key <= end_key);
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

bool Strategy_Range(const int start_shift,
                    const int lookback,
                    double &highest_high,
                    double &lowest_low)
  {
   if(start_shift < 0 || lookback <= 0)
      return false;

   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   for(int shift = start_shift; shift < start_shift + lookback; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 pullback state on closed bars.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 pullback state on closed bars.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_LoadClosedState(double &open_last,
                              double &high_last,
                              double &low_last,
                              double &close_last,
                              double &trend_sma,
                              double &trend_sma_prev,
                              double &fast_sma,
                              double &atr,
                              double &recent_high,
                              double &exit_low,
                              bool &in_window,
                              int &day_key)
  {
   const datetime closed_bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 seasonal calendar key.
   if(closed_bar_time <= 0)
      return false;

   open_last = iOpen(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 pullback candle geometry.
   high_last = iHigh(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 pullback candle geometry.
   low_last = iLow(_Symbol, PERIOD_D1, 1);     // perf-allowed: D1 pullback candle geometry.
   close_last = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 pullback candle geometry.
   if(open_last <= 0.0 || high_last <= 0.0 || low_last <= 0.0 || close_last <= 0.0 || high_last < low_last)
      return false;

   trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   if(trend_sma <= 0.0)
      return false;

   int slope_shift = strategy_sma_slope_shift;
   if(slope_shift < 1)
      slope_shift = 1;
   trend_sma_prev = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1 + slope_shift, PRICE_CLOSE);
   if(trend_sma_prev <= 0.0)
      return false;

   fast_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_fast_sma_period, 1, PRICE_CLOSE);
   if(fast_sma <= 0.0)
      return false;

   atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double recent_low = 0.0;
   if(!Strategy_Range(2, strategy_pullback_lookback, recent_high, recent_low))
      return false;

   double exit_high = 0.0;
   if(!Strategy_Range(2, strategy_exit_channel, exit_high, exit_low))
      return false;

   in_window = Strategy_InJetFuelWindow(closed_bar_time);
   day_key = Strategy_DayKey(closed_bar_time);
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double open_last = 0.0;
   double high_last = 0.0;
   double low_last = 0.0;
   double close_last = 0.0;
   double trend_sma = 0.0;
   double trend_sma_prev = 0.0;
   double fast_sma = 0.0;
   double atr = 0.0;
   double recent_high = 0.0;
   double exit_low = 0.0;
   bool in_window = false;
   int day_key = 0;
   if(!Strategy_LoadClosedState(open_last, high_last, low_last, close_last, trend_sma,
                                trend_sma_prev, fast_sma, atr, recent_high, exit_low,
                                in_window, day_key))
      return;

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
      bool should_close = (!in_window || close_last < trend_sma || close_last < exit_low);
      should_close = should_close || (opened > 0 && now - opened >= hold_seconds);

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
   if(strategy_trend_period <= 1 || strategy_fast_sma_period <= 1)
      return true;
   if(strategy_sma_slope_shift <= 0 || strategy_pullback_lookback <= 0)
      return true;
   if(strategy_exit_channel <= 1)
      return true;
   if(strategy_atr_period <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_max_hold_days <= 0)
      return true;
   if(strategy_max_pullback_close_atr <= 0.0)
      return true;
   if(strategy_min_pullback_depth_atr < 0.0 || strategy_max_pullback_depth_atr <= strategy_min_pullback_depth_atr)
      return true;
   if(strategy_min_close_location < 0.0 || strategy_min_close_location > 1.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_12822_EIA_JETFUEL_PB";
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

   double open_last = 0.0;
   double high_last = 0.0;
   double low_last = 0.0;
   double close_last = 0.0;
   double trend_sma = 0.0;
   double trend_sma_prev = 0.0;
   double fast_sma = 0.0;
   double atr = 0.0;
   double recent_high = 0.0;
   double exit_low = 0.0;
   bool in_window = false;
   int day_key = 0;
   if(!Strategy_LoadClosedState(open_last, high_last, low_last, close_last, trend_sma,
                                trend_sma_prev, fast_sma, atr, recent_high, exit_low,
                                in_window, day_key))
      return false;
   if(day_key <= 0 || day_key == g_last_signal_day_key)
      return false;

   if(!in_window)
      return false;
   if(close_last <= trend_sma || trend_sma <= trend_sma_prev)
      return false;

   const double bar_range = high_last - low_last;
   if(bar_range <= 0.0)
      return false;
   const double close_location = (close_last - low_last) / bar_range;
   if(close_location < strategy_min_close_location)
      return false;
   if(close_last <= open_last)
      return false;

   const double pullback_depth_atr = (recent_high - low_last) / atr;
   if(pullback_depth_atr < strategy_min_pullback_depth_atr ||
      pullback_depth_atr > strategy_max_pullback_depth_atr)
      return false;

   const double close_stretch_atr = (close_last - trend_sma) / atr;
   if(close_stretch_atr > strategy_max_pullback_close_atr)
      return false;

   const bool touched_fast_sma = (low_last <= fast_sma && close_last >= fast_sma);
   const bool pulled_toward_trend = (low_last <= trend_sma + strategy_min_pullback_depth_atr * atr);
   if(!touched_fast_sma && !pulled_toward_trend)
      return false;

   const double entry_price = QM_EntryMarketPrice(QM_BUY);
   if(entry_price <= 0.0)
      return false;

   req.type = QM_BUY;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "EIA_JETFUEL_SUMMER_PULLBACK";
   g_last_signal_day_key = day_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12822\",\"ea\":\"eia-jetfuel-pb\"}");
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
