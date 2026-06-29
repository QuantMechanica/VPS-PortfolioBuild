#property strict
#property version   "5.0"
#property description "QM5_12769 EIA XNG LNG Export-Demand Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_12769 - EIA XNG LNG Export-Demand Breakout
// -----------------------------------------------------------------------------
// D1 structural natural-gas sleeve:
//   - long only in fixed LNG-demand months
//   - requires pre-breakout range compression, rising SMA trend, and an upside
//     close-confirmed channel breakout
//   - exits on trend/range failure, max hold, Friday close, or hard ATR stop
// Runtime uses MT5 OHLC only; no EIA, LNG flow, weather, API, CSV, or futures feed.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12769;
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
input int    strategy_sma_slope_shift        = 10;
input int    strategy_breakout_lookback      = 55;
input int    strategy_exit_channel           = 12;
input int    strategy_compression_lookback   = 20;
input double strategy_compression_atr_mult   = 0.90;
input int    strategy_break_buffer_points    = 20;
input double strategy_max_signal_range_atr   = 2.40;
input double strategy_atr_sl_mult            = 3.25;
input int    strategy_max_hold_days          = 18;
input int    strategy_max_spread_points      = 2500;

int g_last_entry_month_key = 0;

bool Strategy_IsXngD1()
  {
   return (_Symbol == "XNGUSD.DWX" && _Period == PERIOD_D1);
  }

int Strategy_MonthKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsLngDemandMonth(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.mon == 1 || dt.mon == 2 || dt.mon == 7 || dt.mon == 8 ||
           dt.mon == 9 || dt.mon == 11 || dt.mon == 12);
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

bool Strategy_Channel(const int lookback, double &highest_high, double &lowest_low)
  {
   if(lookback <= 1)
      return false;

   highest_high = -DBL_MAX;
   lowest_low = DBL_MAX;
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 channel on closed bars.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 channel on closed bars.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      highest_high = MathMax(highest_high, high);
      lowest_low = MathMin(lowest_low, low);
     }

   return (highest_high > 0.0 && lowest_low > 0.0 && highest_high >= lowest_low);
  }

bool Strategy_AvgPriorRange(const int lookback, double &avg_range)
  {
   if(lookback <= 1)
      return false;

   double total = 0.0;
   for(int shift = 2; shift < lookback + 2; ++shift)
     {
      const double high = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: D1 compression range on closed bars.
      const double low = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: D1 compression range on closed bars.
      if(high <= 0.0 || low <= 0.0 || high < low)
         return false;
      total += high - low;
     }

   avg_range = total / (double)lookback;
   return (avg_range > 0.0 && MathIsValidNumber(avg_range));
  }

bool Strategy_LoadClosedState(double &close_last,
                              double &entry_high,
                              double &exit_low,
                              double &trend_sma,
                              double &trend_sma_prior,
                              double &atr_last,
                              double &avg_prior_range,
                              double &signal_range,
                              datetime &closed_time)
  {
   closed_time = iTime(_Symbol, PERIOD_D1, 1);  // perf-allowed: D1 LNG month gate.
   close_last = iClose(_Symbol, PERIOD_D1, 1);  // perf-allowed: D1 breakout close on closed bars.
   const double signal_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: D1 signal range on closed bars.
   const double signal_low = iLow(_Symbol, PERIOD_D1, 1);   // perf-allowed: D1 signal range on closed bars.
   if(closed_time <= 0 || close_last <= 0.0 || signal_high <= 0.0 || signal_low <= 0.0)
      return false;
   if(signal_high < signal_low)
      return false;
   signal_range = signal_high - signal_low;
   if(signal_range <= 0.0)
      return false;

   double entry_low = 0.0;
   double exit_high = 0.0;
   if(!Strategy_Channel(strategy_breakout_lookback, entry_high, entry_low))
      return false;
   if(!Strategy_Channel(strategy_exit_channel, exit_high, exit_low))
      return false;
   if(!Strategy_AvgPriorRange(strategy_compression_lookback, avg_prior_range))
      return false;

   trend_sma = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period, 1, PRICE_CLOSE);
   trend_sma_prior = QM_SMA(_Symbol, PERIOD_D1, strategy_trend_period,
                            1 + strategy_sma_slope_shift, PRICE_CLOSE);
   atr_last = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);

   if(trend_sma <= 0.0 || trend_sma_prior <= 0.0 || atr_last <= 0.0)
      return false;
   return true;
  }

void Strategy_CloseOpenPositionsIfNeeded()
  {
   double close_last = 0.0;
   double entry_high = 0.0;
   double exit_low = 0.0;
   double trend_sma = 0.0;
   double trend_sma_prior = 0.0;
   double atr_last = 0.0;
   double avg_prior_range = 0.0;
   double signal_range = 0.0;
   datetime closed_time = 0;
   if(!Strategy_LoadClosedState(close_last, entry_high, exit_low, trend_sma,
                                trend_sma_prior, atr_last, avg_prior_range,
                                signal_range, closed_time))
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
      bool should_close = (close_last < trend_sma || close_last < exit_low);
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
   if(strategy_breakout_lookback <= 1 || strategy_exit_channel <= 1)
      return true;
   if(strategy_compression_lookback <= 1)
      return true;
   if(strategy_compression_atr_mult <= 0.0)
      return true;
   if(strategy_break_buffer_points < 0)
      return true;
   if(strategy_max_signal_range_atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
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
   req.reason = "QM5_12769_EIA_XNG_LNG_BRK";
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
   double entry_high = 0.0;
   double exit_low = 0.0;
   double trend_sma = 0.0;
   double trend_sma_prior = 0.0;
   double atr_last = 0.0;
   double avg_prior_range = 0.0;
   double signal_range = 0.0;
   datetime closed_time = 0;
   if(!Strategy_LoadClosedState(close_last, entry_high, exit_low, trend_sma,
                                trend_sma_prior, atr_last, avg_prior_range,
                                signal_range, closed_time))
      return false;

   const int month_key = Strategy_MonthKey(closed_time);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(!Strategy_IsLngDemandMonth(closed_time))
      return false;
   if(close_last <= trend_sma || trend_sma <= trend_sma_prior)
      return false;
   if(avg_prior_range > atr_last * strategy_compression_atr_mult)
      return false;
   if(signal_range > atr_last * strategy_max_signal_range_atr)
      return false;

   const double buffer = MathMax(0, strategy_break_buffer_points) * _Point;
   if(close_last <= entry_high + buffer)
      return false;

   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = "XNG_LNG_DEMAND_COMPRESSION_BREAKOUT_LONG";
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12769\",\"ea\":\"eia-xng-lng-brk\"}");
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
