#property strict
#property version   "5.0"
#property description "QM5_13084 XNG LNG export-demand pullback continuation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_13084 - XNG LNG Export-Demand Pullback Continuation
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - long only during fixed LNG-demand months
//   - requires a recent close-confirmed upside channel breakout
//   - waits for a controlled SMA/ATR pullback and bullish reclaim bar
//   - ATR stop/target, SMA/channel/time exits, no external runtime data
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 13084;
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
input int    strategy_trend_period           = 63;
input int    strategy_sma_slope_shift        = 8;
input int    strategy_breakout_lookback      = 42;
input int    strategy_breakout_memory        = 10;
input int    strategy_exit_channel           = 13;
input int    strategy_break_buffer_points    = 20;
input int    strategy_reclaim_buffer_points  = 10;
input double strategy_pullback_band_atr      = 0.45;
input double strategy_min_signal_range_atr   = 0.45;
input double strategy_max_signal_range_atr   = 2.20;
input double strategy_min_body_atr           = 0.12;
input double strategy_atr_sl_mult            = 3.00;
input double strategy_atr_tp_mult            = 3.50;
input int    strategy_max_hold_days          = 16;
input int    strategy_max_spread_points      = 2500;

int g_last_entry_month_key = 0;

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

bool Strategy_IsLngDemandMonth(const datetime t)
  {
   if(t <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.mon == 1 || dt.mon == 2 || dt.mon == 3 || dt.mon == 4 ||
           dt.mon == 7 || dt.mon == 8 || dt.mon == 9 ||
           dt.mon == 11 || dt.mon == 12);
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

bool Strategy_ChannelRange(const int lookback,
                           const int start_shift,
                           double &highest_high,
                           double &lowest_low)
  {
   if(lookback <= 1 || start_shift < 1)
      return false;

   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   for(int shift = start_shift; shift < start_shift + lookback; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 channel read behind single new-bar gate.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: bounded D1 channel read behind single new-bar gate.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_RecentBreakoutExists()
  {
   const double buffer = MathMax(0, strategy_break_buffer_points) * _Point;
   const int memory = MathMax(1, strategy_breakout_memory);

   for(int shift = 2; shift < 2 + memory; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 LNG month gate on closed bars.
      if(!Strategy_IsLngDemandMonth(bar_time))
         continue;

      double channel_high = 0.0;
      double channel_low = 0.0;
      if(!Strategy_ChannelRange(strategy_breakout_lookback, shift + 1, channel_high, channel_low))
         continue;

      const double close_value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 breakout close on closed bars.
      const double sma_value = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, shift, PRICE_CLOSE);
      const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period,
                                      shift + strategy_sma_slope_shift, PRICE_CLOSE);
      if(close_value <= 0.0 || sma_value <= 0.0 || sma_prior <= 0.0)
         continue;
      if(close_value > channel_high + buffer && close_value > sma_value && sma_value > sma_prior)
         return true;
     }

   return false;
  }

bool Strategy_LoadSignalState(double &signal_open,
                              double &signal_high,
                              double &signal_low,
                              double &signal_close,
                              double &atr_last,
                              double &sma_last,
                              double &sma_prior,
                              datetime &signal_time)
  {
   signal_time = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: completed D1 signal calendar state.
   signal_open = iOpen(_Symbol, PERIOD_D1, 1);  // perf-allowed: completed D1 signal bar.
   signal_high = iHigh(_Symbol, PERIOD_D1, 1);  // perf-allowed: completed D1 signal bar.
   signal_low = iLow(_Symbol, PERIOD_D1, 1);    // perf-allowed: completed D1 signal bar.
   signal_close = iClose(_Symbol, PERIOD_D1, 1);// perf-allowed: completed D1 signal bar.
   if(signal_time <= 0 || signal_open <= 0.0 || signal_high <= 0.0 ||
      signal_low <= 0.0 || signal_close <= 0.0)
      return false;
   if(signal_high <= signal_low)
      return false;

   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   sma_last = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period,
                      1 + strategy_sma_slope_shift, PRICE_CLOSE);
   if(atr_last <= 0.0 || sma_last <= 0.0 || sma_prior <= 0.0)
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double signal_open = 0.0;
   double signal_high = 0.0;
   double signal_low = 0.0;
   double signal_close = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double sma_prior = 0.0;
   datetime signal_time = 0;
   if(!Strategy_LoadSignalState(signal_open, signal_high, signal_low, signal_close,
                                atr_last, sma_last, sma_prior, signal_time))
      return;

   double exit_high = 0.0;
   double exit_low = 0.0;
   const bool has_exit_channel = Strategy_ChannelRange(strategy_exit_channel, 2, exit_high, exit_low);
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

      bool should_close = (signal_close < sma_last);
      if(has_exit_channel && signal_close < exit_low)
         should_close = true;

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
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
   if(strategy_atr_period <= 0 || strategy_trend_period <= 1)
      return true;
   if(strategy_sma_slope_shift <= 0)
      return true;
   if(strategy_breakout_lookback <= 1 || strategy_breakout_memory <= 0)
      return true;
   if(strategy_exit_channel <= 1)
      return true;
   if(strategy_break_buffer_points < 0 || strategy_reclaim_buffer_points < 0)
      return true;
   if(strategy_pullback_band_atr < 0.0)
      return true;
   if(strategy_min_signal_range_atr <= 0.0 || strategy_max_signal_range_atr <= 0.0)
      return true;
   if(strategy_min_signal_range_atr > strategy_max_signal_range_atr)
      return true;
   if(strategy_min_body_atr <= 0.0)
      return true;
   if(strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
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
   req.reason = "QM5_13084_XNG_LNG_PB";
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

   double signal_open = 0.0;
   double signal_high = 0.0;
   double signal_low = 0.0;
   double signal_close = 0.0;
   double atr_last = 0.0;
   double sma_last = 0.0;
   double sma_prior = 0.0;
   datetime signal_time = 0;
   if(!Strategy_LoadSignalState(signal_open, signal_high, signal_low, signal_close,
                                atr_last, sma_last, sma_prior, signal_time))
      return false;

   const int month_key = Strategy_MonthKey(signal_time);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(!Strategy_IsLngDemandMonth(signal_time))
      return false;
   if(!Strategy_RecentBreakoutExists())
      return false;
   if(sma_last <= sma_prior)
      return false;

   const double signal_range = signal_high - signal_low;
   const double signal_body = signal_close - signal_open;
   if(signal_range < strategy_min_signal_range_atr * atr_last)
      return false;
   if(signal_range > strategy_max_signal_range_atr * atr_last)
      return false;
   if(signal_body < strategy_min_body_atr * atr_last)
      return false;

   const double reclaim_buffer = MathMax(0, strategy_reclaim_buffer_points) * _Point;
   if(signal_low > sma_last + strategy_pullback_band_atr * atr_last)
      return false;
   if(signal_close <= sma_last + reclaim_buffer)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATRFromValue(_Symbol, req.type, entry_price, atr_last, strategy_atr_sl_mult);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || req.sl >= entry_price)
      return false;

   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   req.tp = NormalizeDouble(entry_price + strategy_atr_tp_mult * atr_last, digits);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= entry_price)
      return false;

   req.reason = "XNG_LNG_PULLBACK_CONTINUATION_LONG";
   g_last_entry_month_key = month_key;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_13084\",\"ea\":\"xng-lng-pb\"}");
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
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
     {
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
     }

   if(Strategy_NewsFilterHook(broker_now))
      return;

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
   ZeroMemory(req);
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
