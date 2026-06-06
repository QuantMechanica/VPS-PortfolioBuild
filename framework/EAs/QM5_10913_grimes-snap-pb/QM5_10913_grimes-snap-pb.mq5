#property strict
#property version   "5.0"
#property description "QM5_10913 Grimes Snap Pullback Anti"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10913;
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
input int    strategy_ema_trend_period          = 50;
input int    strategy_ema_snap_period           = 20;
input int    strategy_atr_period                = 14;
input int    strategy_trend_count_bars          = 15;
input int    strategy_trend_min_closes          = 10;
input int    strategy_extreme_lookback_bars     = 20;
input int    strategy_failure_window_bars       = 5;
input int    strategy_min_pullback_bars         = 2;
input int    strategy_max_pullback_bars         = 8;
input double strategy_snap_body_atr_mult        = 1.20;
input double strategy_pullback_max_retrace      = 0.50;
input double strategy_stop_buffer_atr_mult      = 0.20;
input double strategy_max_stop_atr_mult         = 2.50;
input int    strategy_time_exit_bars            = 12;

double StrategyNormalizePrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = _Digits;
   return NormalizeDouble(price, digits);
  }

void StrategyInitRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool StrategyHasOpenPosition()
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

double StrategyHighestHigh(const MqlRates &rates[], const int from_shift, const int to_shift)
  {
   double highest = -DBL_MAX;
   for(int s = from_shift; s <= to_shift; ++s)
      highest = MathMax(highest, rates[s].high);
   return highest;
  }

double StrategyLowestLow(const MqlRates &rates[], const int from_shift, const int to_shift)
  {
   double lowest = DBL_MAX;
   for(int s = from_shift; s <= to_shift; ++s)
      lowest = MathMin(lowest, rates[s].low);
   return lowest;
  }

bool StrategyOldDowntrend(const MqlRates &rates[], const int anchor_shift)
  {
   const double ema_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, anchor_shift);
   const double ema_prev = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, anchor_shift + 1);
   if(ema_now <= 0.0 || ema_prev <= 0.0 || ema_now >= ema_prev)
      return false;

   int below_count = 0;
   for(int s = anchor_shift; s < anchor_shift + strategy_trend_count_bars; ++s)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, s);
      if(ema > 0.0 && rates[s].close < ema)
         below_count++;
     }
   return (below_count >= strategy_trend_min_closes);
  }

bool StrategyOldUptrend(const MqlRates &rates[], const int anchor_shift)
  {
   const double ema_now = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, anchor_shift);
   const double ema_prev = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, anchor_shift + 1);
   if(ema_now <= 0.0 || ema_prev <= 0.0 || ema_now <= ema_prev)
      return false;

   int above_count = 0;
   for(int s = anchor_shift; s < anchor_shift + strategy_trend_count_bars; ++s)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, s);
      if(ema > 0.0 && rates[s].close > ema)
         above_count++;
     }
   return (above_count >= strategy_trend_min_closes);
  }

bool StrategyLongTerminationBeforeSnap(const MqlRates &rates[], const int snap_shift)
  {
   for(int low_shift = snap_shift + 1; low_shift <= snap_shift + strategy_failure_window_bars; ++low_shift)
     {
      if(rates[low_shift].low > StrategyLowestLow(rates, low_shift + 1, low_shift + strategy_extreme_lookback_bars))
         continue;
      if(!StrategyOldDowntrend(rates, low_shift))
         continue;

      bool failed_new_low_close = true;
      for(int s = low_shift - 1; s >= snap_shift; --s)
        {
         if(rates[s].close < rates[low_shift].low)
           {
            failed_new_low_close = false;
            break;
           }
        }
      if(failed_new_low_close)
         return true;
     }

   return false;
  }

bool StrategyShortTerminationBeforeSnap(const MqlRates &rates[], const int snap_shift)
  {
   for(int high_shift = snap_shift + 1; high_shift <= snap_shift + strategy_failure_window_bars; ++high_shift)
     {
      if(rates[high_shift].high < StrategyHighestHigh(rates, high_shift + 1, high_shift + strategy_extreme_lookback_bars))
         continue;
      if(!StrategyOldUptrend(rates, high_shift))
         continue;

      bool failed_new_high_close = true;
      for(int s = high_shift - 1; s >= snap_shift; --s)
        {
         if(rates[s].close > rates[high_shift].high)
           {
            failed_new_high_close = false;
            break;
           }
        }
      if(failed_new_high_close)
         return true;
     }

   return false;
  }

bool StrategyLongSnapBar(const MqlRates &rates[], const int snap_shift)
  {
   const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_snap_period, snap_shift);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, snap_shift);
   if(ema20 <= 0.0 || atr <= 0.0)
      return false;
   const double body = MathAbs(rates[snap_shift].close - rates[snap_shift].open);
   return (rates[snap_shift].close > rates[snap_shift].open &&
           rates[snap_shift].close > ema20 &&
           body >= strategy_snap_body_atr_mult * atr);
  }

bool StrategyShortSnapBar(const MqlRates &rates[], const int snap_shift)
  {
   const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_snap_period, snap_shift);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, snap_shift);
   if(ema20 <= 0.0 || atr <= 0.0)
      return false;
   const double body = MathAbs(rates[snap_shift].close - rates[snap_shift].open);
   return (rates[snap_shift].close < rates[snap_shift].open &&
           rates[snap_shift].close < ema20 &&
           body >= strategy_snap_body_atr_mult * atr);
  }

bool StrategyLongPullbackAndTrigger(const MqlRates &rates[],
                                    const int snap_shift,
                                    double &pullback_low,
                                    double &pullback_high)
  {
   pullback_low = DBL_MAX;
   pullback_high = -DBL_MAX;
   const double snap_range = rates[snap_shift].high - rates[snap_shift].low;
   if(snap_range <= 0.0)
      return false;

   const double max_retrace_low = rates[snap_shift].high - strategy_pullback_max_retrace * snap_range;
   for(int s = snap_shift - 1; s >= 2; --s)
     {
      pullback_low = MathMin(pullback_low, rates[s].low);
      pullback_high = MathMax(pullback_high, rates[s].high);
      if(rates[s].close < rates[snap_shift].low)
         return false;
     }

   if(pullback_low < max_retrace_low)
      return false;
   return (rates[1].close > pullback_high);
  }

bool StrategyShortPullbackAndTrigger(const MqlRates &rates[],
                                     const int snap_shift,
                                     double &pullback_high,
                                     double &pullback_low)
  {
   pullback_high = -DBL_MAX;
   pullback_low = DBL_MAX;
   const double snap_range = rates[snap_shift].high - rates[snap_shift].low;
   if(snap_range <= 0.0)
      return false;

   const double max_retrace_high = rates[snap_shift].low + strategy_pullback_max_retrace * snap_range;
   for(int s = snap_shift - 1; s >= 2; --s)
     {
      pullback_high = MathMax(pullback_high, rates[s].high);
      pullback_low = MathMin(pullback_low, rates[s].low);
      if(rates[s].close > rates[snap_shift].high)
         return false;
     }

   if(pullback_high > max_retrace_high)
      return false;
   return (rates[1].close < pullback_low);
  }

bool StrategyBuildLongRequest(const MqlRates &rates[],
                              const int snap_shift,
                              const double pullback_low,
                              QM_EntryRequest &req)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(entry <= 0.0 || atr1 <= 0.0)
      return false;

   const double sl = StrategyNormalizePrice(pullback_low - strategy_stop_buffer_atr_mult * atr1);
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double risk = entry - sl;
   if(risk <= 0.0 || risk > strategy_max_stop_atr_mult * atr1)
      return false;

   const double snap_range = rates[snap_shift].high - rates[snap_shift].low;
   const double target_dist = MathMax(snap_range, risk);
   const double tp = StrategyNormalizePrice(entry + target_dist);
   if(tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "GRIMES_SNAP_PB_LONG";
   return true;
  }

bool StrategyBuildShortRequest(const MqlRates &rates[],
                               const int snap_shift,
                               const double pullback_high,
                               QM_EntryRequest &req)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(entry <= 0.0 || atr1 <= 0.0)
      return false;

   const double sl = StrategyNormalizePrice(pullback_high + strategy_stop_buffer_atr_mult * atr1);
   if(sl <= 0.0 || sl <= entry)
      return false;

   const double risk = sl - entry;
   if(risk <= 0.0 || risk > strategy_max_stop_atr_mult * atr1)
      return false;

   const double snap_range = rates[snap_shift].high - rates[snap_shift].low;
   const double target_dist = MathMax(snap_range, risk);
   const double tp = StrategyNormalizePrice(entry - target_dist);
   if(tp <= 0.0 || tp >= entry)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "GRIMES_SNAP_PB_SHORT";
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (ask <= 0.0 || bid <= 0.0 || ask <= bid);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyInitRequest(req);

   if(StrategyHasOpenPosition())
      return false;
   if(strategy_ema_trend_period < 2 || strategy_ema_snap_period < 2 ||
      strategy_atr_period < 2 || strategy_trend_count_bars < 1 ||
      strategy_trend_min_closes < 1 || strategy_extreme_lookback_bars < 2 ||
      strategy_failure_window_bars < 1 || strategy_min_pullback_bars < 1 ||
      strategy_max_pullback_bars < strategy_min_pullback_bars ||
      strategy_snap_body_atr_mult <= 0.0 || strategy_pullback_max_retrace <= 0.0 ||
      strategy_pullback_max_retrace >= 1.0 || strategy_max_stop_atr_mult <= 0.0)
      return false;

   const int max_snap_shift = strategy_max_pullback_bars + 2;
   const int need_bars = max_snap_shift + strategy_failure_window_bars +
                         strategy_extreme_lookback_bars + strategy_trend_count_bars + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for the card's snap-pullback sequence.
   if(copied < need_bars)
      return false;

   for(int snap_shift = strategy_min_pullback_bars + 2; snap_shift <= max_snap_shift; ++snap_shift)
     {
      if(StrategyLongSnapBar(rates, snap_shift) &&
         StrategyLongTerminationBeforeSnap(rates, snap_shift))
        {
         double pullback_low = 0.0;
         double pullback_high = 0.0;
         if(StrategyLongPullbackAndTrigger(rates, snap_shift, pullback_low, pullback_high) &&
            StrategyBuildLongRequest(rates, snap_shift, pullback_low, req))
            return true;
        }

      if(StrategyShortSnapBar(rates, snap_shift) &&
         StrategyShortTerminationBeforeSnap(rates, snap_shift))
        {
         double pullback_high = 0.0;
         double pullback_low = 0.0;
         if(StrategyShortPullbackAndTrigger(rates, snap_shift, pullback_high, pullback_low) &&
            StrategyBuildShortRequest(rates, snap_shift, pullback_high, req))
            return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP only; no trailing, partial, or breakeven rule.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_exit_bars <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(period_seconds <= 0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_time_exit_bars * period_seconds)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10913_grimes_snap_pb\"}");
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
