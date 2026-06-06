#property strict
#property version   "5.0"
#property description "QM5_10910 Grimes Simple Pullback Continuation"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10910;
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
input int    strategy_ema_trend_period       = 50;
input int    strategy_ema_pullback_period    = 20;
input int    strategy_atr_period             = 14;
input int    strategy_thrust_lookback_bars   = 12;
input int    strategy_breakout_lookback_bars = 20;
input double strategy_thrust_body_atr_mult   = 1.0;
input double strategy_pullback_atr_band      = 0.25;
input double strategy_stop_buffer_atr_mult   = 0.20;
input double strategy_min_stop_atr_mult      = 0.60;
input double strategy_max_stop_atr_mult      = 2.50;
input double strategy_target_r_mult          = 1.50;
input double strategy_breakeven_r_mult       = 1.00;
input double strategy_trail_atr_mult         = 2.00;
input double strategy_spread_stop_frac       = 0.10;
input int    strategy_max_hold_bars          = 16;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   if(digits < 0)
      digits = _Digits;
   return NormalizeDouble(price, digits);
  }

void InitEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool PositionIsOurs()
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

bool TouchesPullbackBand(const MqlRates &bar, const double ema, const double atr)
  {
   if(ema <= 0.0 || atr <= 0.0)
      return false;
   const double band = strategy_pullback_atr_band * atr;
   return (bar.low <= ema + band && bar.high >= ema - band);
  }

double PriorHigh(const MqlRates &rates[], const int thrust_shift)
  {
   double highest = -DBL_MAX;
   for(int i = thrust_shift + 1; i <= thrust_shift + strategy_breakout_lookback_bars; ++i)
      highest = MathMax(highest, rates[i].high);
   return highest;
  }

double PriorLow(const MqlRates &rates[], const int thrust_shift)
  {
   double lowest = DBL_MAX;
   for(int i = thrust_shift + 1; i <= thrust_shift + strategy_breakout_lookback_bars; ++i)
      lowest = MathMin(lowest, rates[i].low);
   return lowest;
  }

bool FindLongPullback(const MqlRates &rates[], const int copied, double &swing_low)
  {
   swing_low = DBL_MAX;
   const int max_thrust_shift = 2 + strategy_thrust_lookback_bars;

   for(int thrust_shift = 3; thrust_shift <= max_thrust_shift; ++thrust_shift)
     {
      if(thrust_shift + strategy_breakout_lookback_bars >= copied)
         break;

      const double atr_thrust = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, thrust_shift);
      if(atr_thrust <= 0.0)
         continue;

      const double body = MathAbs(rates[thrust_shift].close - rates[thrust_shift].open);
      if(rates[thrust_shift].close <= PriorHigh(rates, thrust_shift))
         continue;
      if(body < strategy_thrust_body_atr_mult * atr_thrust)
         continue;

      bool has_pullback = false;
      double local_swing = DBL_MAX;
      bool invalid_close = false;

      for(int s = thrust_shift - 1; s >= 2; --s)
        {
         const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_pullback_period, s);
         const double ema50 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, s);
         const double atr_s = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, s);
         if(ema20 <= 0.0 || ema50 <= 0.0 || atr_s <= 0.0)
           {
            invalid_close = true;
            break;
           }
         if(rates[s].close < ema50)
           {
            invalid_close = true;
            break;
           }
         if(TouchesPullbackBand(rates[s], ema20, atr_s))
            has_pullback = true;
         local_swing = MathMin(local_swing, rates[s].low);
        }

      if(!invalid_close && has_pullback && local_swing < DBL_MAX)
        {
         swing_low = local_swing;
         return true;
        }
     }

   return false;
  }

bool FindShortPullback(const MqlRates &rates[], const int copied, double &swing_high)
  {
   swing_high = -DBL_MAX;
   const int max_thrust_shift = 2 + strategy_thrust_lookback_bars;

   for(int thrust_shift = 3; thrust_shift <= max_thrust_shift; ++thrust_shift)
     {
      if(thrust_shift + strategy_breakout_lookback_bars >= copied)
         break;

      const double atr_thrust = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, thrust_shift);
      if(atr_thrust <= 0.0)
         continue;

      const double body = MathAbs(rates[thrust_shift].close - rates[thrust_shift].open);
      if(rates[thrust_shift].close >= PriorLow(rates, thrust_shift))
         continue;
      if(body < strategy_thrust_body_atr_mult * atr_thrust)
         continue;

      bool has_pullback = false;
      double local_swing = -DBL_MAX;
      bool invalid_close = false;

      for(int s = thrust_shift - 1; s >= 2; --s)
        {
         const double ema20 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_pullback_period, s);
         const double ema50 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, s);
         const double atr_s = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, s);
         if(ema20 <= 0.0 || ema50 <= 0.0 || atr_s <= 0.0)
           {
            invalid_close = true;
            break;
           }
         if(rates[s].close > ema50)
           {
            invalid_close = true;
            break;
           }
         if(TouchesPullbackBand(rates[s], ema20, atr_s))
            has_pullback = true;
         local_swing = MathMax(local_swing, rates[s].high);
        }

      if(!invalid_close && has_pullback && local_swing > -DBL_MAX)
        {
         swing_high = local_swing;
         return true;
        }
     }

   return false;
  }

bool StopAndSpreadAllowed(const double entry_price, const double sl_price, const double atr)
  {
   if(entry_price <= 0.0 || sl_price <= 0.0 || atr <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry_price - sl_price);
   if(stop_distance < strategy_min_stop_atr_mult * atr)
      return false;
   if(stop_distance > strategy_max_stop_atr_mult * atr)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;
   return ((ask - bid) <= strategy_spread_stop_frac * stop_distance);
  }

// Return TRUE to BLOCK trading this tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.day_of_week == 5 && dt.hour >= MathMax(0, qm_friday_close_hour_broker - 1))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   InitEntryRequest(req);

   if(PositionIsOurs())
      return false;

   if(strategy_ema_trend_period < 2 || strategy_ema_pullback_period < 2 ||
      strategy_atr_period < 2 || strategy_thrust_lookback_bars < 1 ||
      strategy_breakout_lookback_bars < 2 || strategy_target_r_mult <= 0.0)
      return false;

   const int need_bars = strategy_breakout_lookback_bars + strategy_thrust_lookback_bars + 8;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need_bars, rates); // perf-allowed: bounded closed-bar structural scan for thrust/pullback highs and lows.
   if(copied < need_bars)
      return false;

   const double atr1 = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double ema50_1 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, 1);
   const double ema50_2 = QM_EMA(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_ema_trend_period, 2);
   if(atr1 <= 0.0 || ema50_1 <= 0.0 || ema50_2 <= 0.0)
      return false;

   const bool long_trend = (ema50_1 > ema50_2 && rates[1].close > ema50_1);
   const bool short_trend = (ema50_1 < ema50_2 && rates[1].close < ema50_1);
   const bool long_trigger = (rates[1].close > rates[2].high);
   const bool short_trigger = (rates[1].close < rates[2].low);

   if(long_trend && long_trigger)
     {
      double swing_low = 0.0;
      if(!FindLongPullback(rates, copied, swing_low))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = NormalizeStrategyPrice(swing_low - strategy_stop_buffer_atr_mult * atr1);
      if(!StopAndSpreadAllowed(entry, sl, atr1))
         return false;

      const double risk = entry - sl;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = NormalizeStrategyPrice(entry + strategy_target_r_mult * risk);
      req.reason = "GRIMES_PULLBACK_LONG";
      return true;
     }

   if(short_trend && short_trigger)
     {
      double swing_high = 0.0;
      if(!FindShortPullback(rates, copied, swing_high))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = NormalizeStrategyPrice(swing_high + strategy_stop_buffer_atr_mult * atr1);
      if(!StopAndSpreadAllowed(entry, sl, atr1))
         return false;

      const double risk = sl - entry;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = NormalizeStrategyPrice(entry - strategy_target_r_mult * risk);
      req.reason = "GRIMES_PULLBACK_SHORT";
      return true;
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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                   : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(open_price <= 0.0 || market <= 0.0)
         continue;

      double initial_r = 0.0;
      if(current_tp > 0.0 && strategy_target_r_mult > 0.0)
         initial_r = MathAbs(current_tp - open_price) / strategy_target_r_mult;
      else if(current_sl > 0.0)
         initial_r = MathAbs(open_price - current_sl);
      if(initial_r <= 0.0)
         continue;

      const double moved = is_buy ? (market - open_price) : (open_price - market);
      if(moved < strategy_breakeven_r_mult * initial_r)
         continue;

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         continue;

      const bool needs_be = (current_sl <= 0.0) ||
                            (is_buy ? (current_sl < open_price - point * 0.5)
                                    : (current_sl > open_price + point * 0.5));
      if(needs_be)
         QM_TM_MoveSL(ticket, NormalizeStrategyPrice(open_price), "grimes_1r_breakeven");

      // Card Exit: once price has reached +1R, trail by 2.0*ATR(14). The
      // framework helper ratchets the stop from the current market price by
      // atr_mult*ATR (only ever tightening in the trade's favour), which tracks
      // the card's "trail from highest close / lowest close since entry" intent
      // without a per-tick CopyRates scan. SPEC.md §1 documents this mapping.
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_max_hold_bars <= 0)
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
      if(open_time > 0 && (TimeCurrent() - open_time) >= strategy_max_hold_bars * period_seconds)
         return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10910_grimes_pullback\"}");
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
