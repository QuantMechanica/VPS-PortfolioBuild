#property strict
#property version   "5.0"
#property description "QM5_10911 Grimes Complex Pullback Second-Leg Continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10911;
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
input int    strategy_ema_exit_period           = 20;
input int    strategy_atr_period                = 14;
input int    strategy_thrust_lookback_bars      = 20;
input int    strategy_thrust_prior_high_bars    = 20;
input double strategy_thrust_range_atr_mult     = 1.00;
input double strategy_pullback_atr_mult         = 0.80;
input int    strategy_failure_window_bars       = 5;
input int    strategy_min_thrust_to_entry_bars  = 8;
input double strategy_stop_buffer_atr_mult      = 0.20;
input double strategy_target_r_mult             = 1.50;
input int    strategy_max_hold_bars             = 30;

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

bool StrategyLongTrendIntegrity(const MqlRates &rates[], const int newest_shift, const int oldest_shift)
  {
   for(int s = newest_shift; s <= oldest_shift; ++s)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, s);
      if(ema <= 0.0 || rates[s].close <= ema)
         return false;
     }
   return true;
  }

bool StrategyShortTrendIntegrity(const MqlRates &rates[], const int newest_shift, const int oldest_shift)
  {
   for(int s = newest_shift; s <= oldest_shift; ++s)
     {
      const double ema = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, s);
      if(ema <= 0.0 || rates[s].close >= ema)
         return false;
     }
   return true;
  }

bool StrategyFindLongPattern(const MqlRates &rates[], const int copied, double &swing_low, double &trigger_high)
  {
   swing_low = 0.0;
   trigger_high = 0.0;

   int max_thrust_shift = strategy_thrust_lookback_bars;
   const int max_shift_by_history = copied - strategy_thrust_prior_high_bars - 2;
   if(max_shift_by_history < max_thrust_shift)
      max_thrust_shift = max_shift_by_history;
   int min_thrust_shift = strategy_min_thrust_to_entry_bars;
   if(min_thrust_shift < 3)
      min_thrust_shift = 3;
   for(int thrust_shift = min_thrust_shift; thrust_shift <= max_thrust_shift; ++thrust_shift)
     {
      const double atr_thrust = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, thrust_shift);
      if(atr_thrust <= 0.0)
         continue;
      if((rates[thrust_shift].high - rates[thrust_shift].low) < strategy_thrust_range_atr_mult * atr_thrust)
         continue;
      if(rates[thrust_shift].high < StrategyHighestHigh(rates, thrust_shift + 1, thrust_shift + strategy_thrust_prior_high_bars))
         continue;

      if(!StrategyLongTrendIntegrity(rates, 1, thrust_shift))
         continue;

      for(int pullback_shift = thrust_shift - 1; pullback_shift >= 4; --pullback_shift)
        {
         const double atr_pullback = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, pullback_shift);
         const double ema_pullback = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, pullback_shift);
         if(atr_pullback <= 0.0 || ema_pullback <= 0.0)
            continue;
         if(rates[pullback_shift].close > rates[thrust_shift].high - strategy_pullback_atr_mult * atr_pullback)
            continue;
         if(rates[pullback_shift].close <= ema_pullback)
            continue;

         for(int resumption_shift = pullback_shift - 1; resumption_shift >= 3; --resumption_shift)
           {
            if(rates[resumption_shift].close <= rates[resumption_shift + 1].high)
               continue;

            const int min_failure_shift = MathMax(2, resumption_shift - strategy_failure_window_bars);
            for(int failure_shift = resumption_shift - 1; failure_shift >= min_failure_shift; --failure_shift)
              {
               if(rates[failure_shift].close >= rates[resumption_shift].low)
                  continue;

               const double failed_leg_high = StrategyHighestHigh(rates, failure_shift, resumption_shift);
               if(rates[1].close <= failed_leg_high)
                  continue;
               if(!StrategyLongTrendIntegrity(rates, 1, failure_shift))
                  continue;

               swing_low = StrategyLowestLow(rates, 1, failure_shift);
               trigger_high = failed_leg_high;
               return (swing_low > 0.0 && trigger_high > 0.0);
              }
           }
        }
     }

   return false;
  }

bool StrategyFindShortPattern(const MqlRates &rates[], const int copied, double &swing_high, double &trigger_low)
  {
   swing_high = 0.0;
   trigger_low = 0.0;

   int max_thrust_shift = strategy_thrust_lookback_bars;
   const int max_shift_by_history = copied - strategy_thrust_prior_high_bars - 2;
   if(max_shift_by_history < max_thrust_shift)
      max_thrust_shift = max_shift_by_history;
   int min_thrust_shift = strategy_min_thrust_to_entry_bars;
   if(min_thrust_shift < 3)
      min_thrust_shift = 3;
   for(int thrust_shift = min_thrust_shift; thrust_shift <= max_thrust_shift; ++thrust_shift)
     {
      const double atr_thrust = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, thrust_shift);
      if(atr_thrust <= 0.0)
         continue;
      if((rates[thrust_shift].high - rates[thrust_shift].low) < strategy_thrust_range_atr_mult * atr_thrust)
         continue;
      if(rates[thrust_shift].low > StrategyLowestLow(rates, thrust_shift + 1, thrust_shift + strategy_thrust_prior_high_bars))
         continue;

      if(!StrategyShortTrendIntegrity(rates, 1, thrust_shift))
         continue;

      for(int pullback_shift = thrust_shift - 1; pullback_shift >= 4; --pullback_shift)
        {
         const double atr_pullback = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, pullback_shift);
         const double ema_pullback = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, pullback_shift);
         if(atr_pullback <= 0.0 || ema_pullback <= 0.0)
            continue;
         if(rates[pullback_shift].close < rates[thrust_shift].low + strategy_pullback_atr_mult * atr_pullback)
            continue;
         if(rates[pullback_shift].close >= ema_pullback)
            continue;

         for(int resumption_shift = pullback_shift - 1; resumption_shift >= 3; --resumption_shift)
           {
            if(rates[resumption_shift].close >= rates[resumption_shift + 1].low)
               continue;

            const int min_failure_shift = MathMax(2, resumption_shift - strategy_failure_window_bars);
            for(int failure_shift = resumption_shift - 1; failure_shift >= min_failure_shift; --failure_shift)
              {
               if(rates[failure_shift].close <= rates[resumption_shift].high)
                  continue;

               const double failed_leg_low = StrategyLowestLow(rates, failure_shift, resumption_shift);
               if(rates[1].close >= failed_leg_low)
                  continue;
               if(!StrategyShortTrendIntegrity(rates, 1, failure_shift))
                  continue;

               swing_high = StrategyHighestHigh(rates, 1, failure_shift);
               trigger_low = failed_leg_low;
               return (swing_high > 0.0 && trigger_low > 0.0);
              }
           }
        }
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   StrategyInitRequest(req);

   if(StrategyHasOpenPosition())
      return false;
   if(strategy_ema_trend_period < 2 || strategy_ema_exit_period < 2 ||
      strategy_atr_period < 2 || strategy_thrust_lookback_bars < 8 ||
      strategy_thrust_prior_high_bars < 2 || strategy_failure_window_bars < 1 ||
      strategy_target_r_mult <= 0.0)
      return false;

   const int need_bars = strategy_thrust_lookback_bars + strategy_thrust_prior_high_bars + 6;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for the card's thrust/pullback/failure sequence.
   if(copied < need_bars)
      return false;

   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double ema50_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, 1);
   const double ema50_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, 2);
   if(atr1 <= 0.0 || ema50_1 <= 0.0 || ema50_2 <= 0.0)
      return false;

   const bool long_trend = (ema50_1 > ema50_2 && rates[1].close > ema50_1);
   const bool short_trend = (ema50_1 < ema50_2 && rates[1].close < ema50_1);

   if(long_trend)
     {
      double swing_low = 0.0;
      double trigger_high = 0.0;
      if(StrategyFindLongPattern(rates, copied, swing_low, trigger_high))
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double sl = StrategyNormalizePrice(swing_low - strategy_stop_buffer_atr_mult * atr1);
         if(entry <= 0.0 || sl <= 0.0 || sl >= entry)
            return false;
         const double tp = StrategyNormalizePrice(entry + strategy_target_r_mult * (entry - sl));
         if(tp <= entry)
            return false;

         req.type = QM_BUY;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "GRIMES_COMPLEX_PB_LONG";
         return true;
        }
     }

   if(short_trend)
     {
      double swing_high = 0.0;
      double trigger_low = 0.0;
      if(StrategyFindShortPattern(rates, copied, swing_high, trigger_low))
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double sl = StrategyNormalizePrice(swing_high + strategy_stop_buffer_atr_mult * atr1);
         if(entry <= 0.0 || sl <= 0.0 || sl <= entry)
            return false;
         const double tp = StrategyNormalizePrice(entry - strategy_target_r_mult * (sl - entry));
         if(tp >= entry || tp <= 0.0)
            return false;

         req.type = QM_SELL;
         req.price = 0.0;
         req.sl = sl;
         req.tp = tp;
         req.reason = "GRIMES_COMPLEX_PB_SHORT";
         return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   MqlRates last_closed[];
   ArraySetAsSeries(last_closed, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 1, last_closed); // perf-allowed: one closed bar for EMA20 close-through exit.
   const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_exit_period, 1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(strategy_max_hold_bars > 0 && period_seconds > 0)
        {
         const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
         if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_max_hold_bars * period_seconds)
            return true;
        }

      if(copied == 1 && ema20 > 0.0)
        {
         const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(ptype == POSITION_TYPE_BUY && last_closed[0].close < ema20)
            return true;
         if(ptype == POSITION_TYPE_SELL && last_closed[0].close > ema20)
            return true;
        }
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10911_grimes_complex_pb\"}");
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
