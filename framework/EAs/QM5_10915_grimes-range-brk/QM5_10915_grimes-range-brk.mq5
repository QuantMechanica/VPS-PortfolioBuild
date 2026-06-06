#property strict
#property version   "5.0"
#property description "QM5_10915 Grimes Range Pressure Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10915;
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
input int    strategy_atr_period              = 14;
input int    strategy_thrust_lookback_bars    = 24;
input double strategy_min_thrust_atr_mult     = 1.80;
input int    strategy_min_range_bars          = 6;
input int    strategy_max_range_bars          = 18;
input double strategy_max_range_atr_mult      = 0.90;
input double strategy_pressure_fraction       = 0.35;
input double strategy_breakout_atr_mult       = 0.10;
input double strategy_stop_buffer_atr_mult    = 0.20;
input double strategy_min_stop_atr_mult       = 0.50;
input double strategy_max_stop_atr_mult       = 2.00;
input double strategy_trail_atr_mult          = 1.50;
input int    strategy_ema_slope_period        = 50;
input int    strategy_time_exit_bars          = 24;

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

bool StrategyEMASlopeAllows(const bool want_long)
  {
   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double ema_now = QM_EMA(_Symbol, tf, strategy_ema_slope_period, 1);
   const double ema_prev = QM_EMA(_Symbol, tf, strategy_ema_slope_period, 2);
   if(ema_now <= 0.0 || ema_prev <= 0.0)
      return false;
   if(want_long)
      return (ema_now >= ema_prev);
   return (ema_now <= ema_prev);
  }

bool StrategyFindLongThrust(const MqlRates &rates[],
                            const int first_shift,
                            const int last_shift,
                            const double atr,
                            const double range_mid,
                            double &thrust_len)
  {
   thrust_len = 0.0;
   const double min_thrust = strategy_min_thrust_atr_mult * atr;
   const double pressure_floor = 1.0 - strategy_pressure_fraction;

   for(int low_shift = first_shift + 1; low_shift <= last_shift; ++low_shift)
     {
      const double swing_low = rates[low_shift].low;
      for(int high_shift = first_shift; high_shift < low_shift; ++high_shift)
        {
         const double swing_high = rates[high_shift].high;
         const double candidate = swing_high - swing_low;
         if(candidate < min_thrust)
            continue;
         if(range_mid < swing_low + pressure_floor * candidate)
            continue;
         thrust_len = candidate;
         return true;
        }
     }

   return false;
  }

bool StrategyFindShortThrust(const MqlRates &rates[],
                             const int first_shift,
                             const int last_shift,
                             const double atr,
                             const double range_mid,
                             double &thrust_len)
  {
   thrust_len = 0.0;
   const double min_thrust = strategy_min_thrust_atr_mult * atr;
   const double pressure_ceiling = strategy_pressure_fraction;

   for(int high_shift = first_shift + 1; high_shift <= last_shift; ++high_shift)
     {
      const double swing_high = rates[high_shift].high;
      for(int low_shift = first_shift; low_shift < high_shift; ++low_shift)
        {
         const double swing_low = rates[low_shift].low;
         const double candidate = swing_high - swing_low;
         if(candidate < min_thrust)
            continue;
         if(range_mid > swing_low + pressure_ceiling * candidate)
            continue;
         thrust_len = candidate;
         return true;
        }
     }

   return false;
  }

bool StrategyBuildLongRequest(const double range_high,
                              const double range_low,
                              const double thrust_len,
                              const double atr,
                              QM_EntryRequest &req)
  {
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || bid <= 0.0 || entry <= bid || atr <= 0.0)
      return false;

   const double sl = StrategyNormalizePrice(range_low - strategy_stop_buffer_atr_mult * atr);
   if(sl <= 0.0 || sl >= entry)
      return false;

   const double stop_dist = entry - sl;
   if(stop_dist < strategy_min_stop_atr_mult * atr || stop_dist > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = entry - bid;
   if(spread > 0.10 * stop_dist)
      return false;

   const double target_dist = MathMin(thrust_len, 2.0 * stop_dist);
   const double tp = StrategyNormalizePrice(entry + target_dist);
   if(tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "GRIMES_RANGE_BRK_LONG";
   return true;
  }

bool StrategyBuildShortRequest(const double range_high,
                               const double range_low,
                               const double thrust_len,
                               const double atr,
                               QM_EntryRequest &req)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask <= bid || atr <= 0.0)
      return false;

   const double sl = StrategyNormalizePrice(range_high + strategy_stop_buffer_atr_mult * atr);
   if(sl <= 0.0 || sl <= bid)
      return false;

   const double stop_dist = sl - bid;
   if(stop_dist < strategy_min_stop_atr_mult * atr || stop_dist > strategy_max_stop_atr_mult * atr)
      return false;

   const double spread = ask - bid;
   if(spread > 0.10 * stop_dist)
      return false;

   const double target_dist = MathMin(thrust_len, 2.0 * stop_dist);
   const double tp = StrategyNormalizePrice(bid - target_dist);
   if(tp <= 0.0 || tp >= bid)
      return false;

   req.type = QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = "GRIMES_RANGE_BRK_SHORT";
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
   if(strategy_atr_period < 2 || strategy_thrust_lookback_bars < 2 ||
      strategy_min_thrust_atr_mult <= 0.0 || strategy_min_range_bars < 1 ||
      strategy_max_range_bars < strategy_min_range_bars ||
      strategy_max_range_atr_mult <= 0.0 || strategy_pressure_fraction <= 0.0 ||
      strategy_pressure_fraction >= 1.0 || strategy_breakout_atr_mult < 0.0 ||
      strategy_stop_buffer_atr_mult < 0.0 || strategy_min_stop_atr_mult <= 0.0 ||
      strategy_max_stop_atr_mult < strategy_min_stop_atr_mult ||
      strategy_ema_slope_period < 2)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const double atr = QM_ATR(_Symbol, tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const int need_bars = strategy_max_range_bars + strategy_thrust_lookback_bars + 4;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, tf, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for the card's thrust/range breakout.
   if(copied < need_bars)
      return false;

   const double close1 = rates[1].close;
   if(close1 <= 0.0)
      return false;

   for(int range_bars = strategy_min_range_bars; range_bars <= strategy_max_range_bars; ++range_bars)
     {
      const int range_first = 2;
      const int range_last = range_bars + 1;
      const double range_high = StrategyHighestHigh(rates, range_first, range_last);
      const double range_low = StrategyLowestLow(rates, range_first, range_last);
      const double range_width = range_high - range_low;
      if(range_high <= 0.0 || range_low <= 0.0 || range_width <= 0.0)
         continue;
      if(range_width > strategy_max_range_atr_mult * atr)
         continue;

      const double range_mid = 0.5 * (range_high + range_low);
      const int thrust_first = range_last + 1;
      const int thrust_last = MathMin(thrust_first + strategy_thrust_lookback_bars - 1, copied - 1);
      if(thrust_last <= thrust_first)
         continue;

      if(close1 > range_high + strategy_breakout_atr_mult * atr && StrategyEMASlopeAllows(true))
        {
         double thrust_len = 0.0;
         if(StrategyFindLongThrust(rates, thrust_first, thrust_last, atr, range_mid, thrust_len) &&
            StrategyBuildLongRequest(range_high, range_low, thrust_len, atr, req))
            return true;
        }

      if(close1 < range_low - strategy_breakout_atr_mult * atr && StrategyEMASlopeAllows(false))
        {
         double thrust_len = 0.0;
         if(StrategyFindShortThrust(rates, thrust_first, thrust_last, atr, range_mid, thrust_len) &&
            StrategyBuildShortRequest(range_high, range_low, thrust_len, atr, req))
            return true;
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      if(open_price <= 0.0 || current_sl <= 0.0)
         continue;

      const bool is_buy = (pos_type == POSITION_TYPE_BUY);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(market <= 0.0 || point <= 0.0)
         continue;

      const bool already_be = is_buy ? (current_sl >= open_price - point * 0.5)
                                     : (current_sl <= open_price + point * 0.5);
      if(!already_be)
        {
         const double initial_risk = MathAbs(open_price - current_sl);
         const double moved = is_buy ? (market - open_price) : (open_price - market);
         if(initial_risk > 0.0 && moved >= initial_risk)
           {
            const double be_sl = StrategyNormalizePrice(open_price);
            QM_TM_MoveSL(ticket, be_sl, "grimes_range_brk_1r_breakeven");
           }
        }

      if(strategy_trail_atr_mult > 0.0)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10915_grimes_range_brk\"}");
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

