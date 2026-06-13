#property strict
#property version   "5.0"
#property description "QM5_10629 Elite Trader Order Block BOS Imbalance Retest"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10629;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fractal_width       = 3;
input int    strategy_atr_period          = 14;
input double strategy_sweep_atr_mult      = 0.25;
input int    strategy_bos_max_bars        = 12;
input double strategy_bos_body_atr_mult   = 0.75;
input double strategy_ob_entry_fraction   = 0.50;
input double strategy_ob_max_atr_mult     = 1.50;
input double strategy_sl_atr_buffer_mult  = 0.20;
input double strategy_rr_target           = 2.00;
input int    strategy_pending_bars        = 10;
input int    strategy_time_exit_bars      = 36;
input int    strategy_structure_lookback  = 80;

struct Strategy_SweepState
  {
   bool     active;
   int      age_bars;
   datetime sweep_stamp;
   double   sweep_extreme;
   double   break_level;
  };

Strategy_SweepState g_long_sweep;
Strategy_SweepState g_short_sweep;
datetime            g_consumed_long_setup_stamp = 0;
datetime            g_consumed_short_setup_stamp = 0;
double              g_cached_swing_high = 0.0;
double              g_cached_swing_low = 0.0;

// perf-allowed: bespoke 3-left/3-right structure logic, called only from the
// framework-gated Strategy_EntrySignal() path once per completed H1 bar.
double BarOpen(const int shift)  { return iOpen(_Symbol, PERIOD_H1, shift); }   // perf-allowed
double BarHigh(const int shift)  { return iHigh(_Symbol, PERIOD_H1, shift); }   // perf-allowed
double BarLow(const int shift)   { return iLow(_Symbol, PERIOD_H1, shift); }    // perf-allowed
double BarClose(const int shift) { return iClose(_Symbol, PERIOD_H1, shift); }  // perf-allowed
datetime BarStamp(const int shift) { return iTime(_Symbol, PERIOD_H1, shift); } // perf-allowed

void Strategy_ResetSweep(Strategy_SweepState &state)
  {
   state.active = false;
   state.age_bars = 0;
   state.sweep_stamp = 0;
   state.sweep_extreme = 0.0;
   state.break_level = 0.0;
  }

bool Strategy_IsSwingHigh(const int shift, const int width)
  {
   const double center = BarHigh(shift);
   if(center <= 0.0)
      return false;

   for(int offset = 1; offset <= width; ++offset)
     {
      if(BarHigh(shift - offset) >= center)
         return false;
      if(BarHigh(shift + offset) >= center)
         return false;
     }
   return true;
  }

bool Strategy_IsSwingLow(const int shift, const int width)
  {
   const double center = BarLow(shift);
   if(center <= 0.0)
      return false;

   for(int offset = 1; offset <= width; ++offset)
     {
      if(BarLow(shift - offset) <= center)
         return false;
      if(BarLow(shift + offset) <= center)
         return false;
     }
   return true;
  }

bool Strategy_FindRecentSwing(const bool want_high,
                              const int start_shift,
                              const int max_shift,
                              double &price,
                              datetime &stamp)
  {
   price = 0.0;
   stamp = 0;
   const int width = MathMax(1, strategy_fractal_width);
   for(int shift = start_shift; shift <= max_shift; ++shift)
     {
      const bool ok = want_high ? Strategy_IsSwingHigh(shift, width)
                                : Strategy_IsSwingLow(shift, width);
      if(!ok)
         continue;
      price = want_high ? BarHigh(shift) : BarLow(shift);
      stamp = BarStamp(shift);
      return (price > 0.0 && stamp > 0);
     }
   return false;
  }

double Strategy_NearestOpposingSwing(const bool for_long,
                                     const double entry_price,
                                     const int start_shift,
                                     const int max_shift)
  {
   double best = 0.0;
   const int width = MathMax(1, strategy_fractal_width);
   for(int shift = start_shift; shift <= max_shift; ++shift)
     {
      if(for_long)
        {
         if(!Strategy_IsSwingHigh(shift, width))
            continue;
         const double level = BarHigh(shift);
         if(level > entry_price && (best <= 0.0 || level < best))
            best = level;
        }
      else
        {
         if(!Strategy_IsSwingLow(shift, width))
            continue;
         const double level = BarLow(shift);
         if(level > 0.0 && level < entry_price && (best <= 0.0 || level > best))
            best = level;
        }
     }
   return best;
  }

bool Strategy_FindOrderBlock(const bool for_long,
                             const int max_scan_shift,
                             double &ob_low,
                             double &ob_high)
  {
   ob_low = 0.0;
   ob_high = 0.0;
   for(int shift = 2; shift <= max_scan_shift; ++shift)
     {
      const double open = BarOpen(shift);
      const double close = BarClose(shift);
      if(open <= 0.0 || close <= 0.0)
         continue;

      const bool candle_matches = for_long ? (close < open) : (close > open);
      if(!candle_matches)
         continue;

      ob_low = BarLow(shift);
      ob_high = BarHigh(shift);
      return (ob_low > 0.0 && ob_high > ob_low);
     }
   return false;
  }

bool Strategy_HasOurPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_HasOurPendingOrder()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT || type == ORDER_TYPE_SELL_LIMIT)
         return true;
     }
   return false;
  }

void Strategy_ExpireInvalidPendingOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      const double price = OrderGetDouble(ORDER_PRICE_OPEN);
      if(type == ORDER_TYPE_BUY_LIMIT && g_cached_swing_low > 0.0 && bid < g_cached_swing_low)
         QM_TM_RemovePendingOrder(ticket, "opposite_bos_invalidated_buy_ob");
      if(type == ORDER_TYPE_SELL_LIMIT && g_cached_swing_high > 0.0 && ask > g_cached_swing_high)
         QM_TM_RemovePendingOrder(ticket, "opposite_bos_invalidated_sell_ob");
      if((type == ORDER_TYPE_BUY_LIMIT && ask <= price) ||
         (type == ORDER_TYPE_SELL_LIMIT && bid >= price))
         QM_TM_RemovePendingOrder(ticket, "order_block_mitigated_before_fill");
     }
  }

bool Strategy_BuildRetestOrder(const bool for_long,
                               const datetime bos_stamp,
                               const double atr,
                               const Strategy_SweepState &state,
                               QM_EntryRequest &req)
  {
   double ob_low = 0.0;
   double ob_high = 0.0;
   if(!Strategy_FindOrderBlock(for_long, MathMax(2, strategy_bos_max_bars + 2), ob_low, ob_high))
      return false;

   const double ob_height = ob_high - ob_low;
   if(ob_height <= 0.0 || ob_height > (strategy_ob_max_atr_mult * atr))
      return false;

   const double frac = MathMax(0.0, MathMin(1.0, strategy_ob_entry_fraction));
   const double entry = ob_low + ob_height * frac;
   const double buffer = atr * strategy_sl_atr_buffer_mult;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(entry <= 0.0 || buffer <= 0.0 || point <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = MathMax(1, strategy_pending_bars) * PeriodSeconds(PERIOD_H1);

   if(for_long)
     {
      if(ask <= entry)
         return false;
      const double sl = MathMin(ob_low, state.sweep_extreme) - buffer;
      const double risk = entry - sl;
      if(risk <= point)
         return false;
      const double rr_tp = entry + risk * strategy_rr_target;
      const double swing_tp = Strategy_NearestOpposingSwing(true, entry,
                                                            strategy_fractal_width + 1,
                                                            strategy_structure_lookback);
      req.type = QM_BUY_LIMIT;
      req.price = entry;
      req.sl = sl;
      req.tp = (swing_tp > entry) ? MathMin(rr_tp, swing_tp) : rr_tp;
      req.reason = StringFormat("ET_OB_BOS_IMB_LONG_%I64d", (long)bos_stamp);
      return (req.tp > req.price);
     }

   if(bid >= entry)
      return false;
   const double sl = MathMax(ob_high, state.sweep_extreme) + buffer;
   const double risk = sl - entry;
   if(risk <= point)
      return false;
   const double rr_tp = entry - risk * strategy_rr_target;
   const double swing_tp = Strategy_NearestOpposingSwing(false, entry,
                                                         strategy_fractal_width + 1,
                                                         strategy_structure_lookback);
   req.type = QM_SELL_LIMIT;
   req.price = entry;
   req.sl = sl;
   req.tp = (swing_tp > 0.0 && swing_tp < entry) ? MathMax(rr_tp, swing_tp) : rr_tp;
   req.reason = StringFormat("ET_OB_BOS_IMB_SHORT_%I64d", (long)bos_stamp);
   return (req.tp > 0.0 && req.tp < req.price);
  }

bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_H1)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_fractal_width < 1 || strategy_atr_period < 1 || strategy_bos_max_bars < 1)
      return false;

   if(g_long_sweep.active)
      g_long_sweep.age_bars++;
   if(g_short_sweep.active)
      g_short_sweep.age_bars++;
   if(g_long_sweep.age_bars > strategy_bos_max_bars)
      Strategy_ResetSweep(g_long_sweep);
   if(g_short_sweep.age_bars > strategy_bos_max_bars)
      Strategy_ResetSweep(g_short_sweep);

   const int first_confirmed = strategy_fractal_width + 1;
   const int max_shift = MathMax(strategy_structure_lookback, first_confirmed + strategy_bos_max_bars + 4);
   double recent_high = 0.0;
   double recent_low = 0.0;
   datetime high_stamp = 0;
   datetime low_stamp = 0;
   const bool have_high = Strategy_FindRecentSwing(true, first_confirmed, max_shift, recent_high, high_stamp);
   const bool have_low = Strategy_FindRecentSwing(false, first_confirmed, max_shift, recent_low, low_stamp);
   if(have_high)
      g_cached_swing_high = recent_high;
   if(have_low)
      g_cached_swing_low = recent_low;
   if(!have_high || !have_low)
      return false;

   Strategy_ExpireInvalidPendingOrders();
   if(Strategy_HasOurPosition() || Strategy_HasOurPendingOrder())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   const double open1 = BarOpen(1);
   const double high1 = BarHigh(1);
   const double low1 = BarLow(1);
   const double close1 = BarClose(1);
   const datetime stamp1 = BarStamp(1);
   if(atr <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 || stamp1 <= 0)
      return false;

   const double sweep_depth = atr * strategy_sweep_atr_mult;
   if(low1 <= recent_low - sweep_depth && close1 > recent_low)
     {
      g_long_sweep.active = true;
      g_long_sweep.age_bars = 0;
      g_long_sweep.sweep_stamp = stamp1;
      g_long_sweep.sweep_extreme = low1;
      g_long_sweep.break_level = recent_high;
     }

   if(high1 >= recent_high + sweep_depth && close1 < recent_high)
     {
      g_short_sweep.active = true;
      g_short_sweep.age_bars = 0;
      g_short_sweep.sweep_stamp = stamp1;
      g_short_sweep.sweep_extreme = high1;
      g_short_sweep.break_level = recent_low;
     }

   const double body = MathAbs(close1 - open1);
   if(body < atr * strategy_bos_body_atr_mult)
      return false;

   const bool bullish_fvg = (BarLow(1) > BarHigh(3));
   const bool bearish_fvg = (BarHigh(1) < BarLow(3));

   if(g_long_sweep.active &&
      g_long_sweep.age_bars <= strategy_bos_max_bars &&
      close1 > g_long_sweep.break_level &&
      bullish_fvg &&
      stamp1 != g_consumed_long_setup_stamp)
     {
      g_consumed_long_setup_stamp = stamp1;
      const bool built = Strategy_BuildRetestOrder(true, stamp1, atr, g_long_sweep, req);
      Strategy_ResetSweep(g_long_sweep);
      return built;
     }

   if(g_short_sweep.active &&
      g_short_sweep.age_bars <= strategy_bos_max_bars &&
      close1 < g_short_sweep.break_level &&
      bearish_fvg &&
      stamp1 != g_consumed_short_setup_stamp)
     {
      g_consumed_short_setup_stamp = stamp1;
      const bool built = Strategy_BuildRetestOrder(false, stamp1, atr, g_short_sweep, req);
      Strategy_ResetSweep(g_short_sweep);
      return built;
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int max_hold_seconds = MathMax(1, strategy_time_exit_bars) * PeriodSeconds(PERIOD_H1);
   const datetime now = TimeCurrent();
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      if(opened_at > 0 && (now - opened_at) >= max_hold_seconds)
         return true;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_cached_swing_low > 0.0 && bid < g_cached_swing_low)
         return true;
      if(type == POSITION_TYPE_SELL && g_cached_swing_high > 0.0 && ask > g_cached_swing_high)
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
   Strategy_ResetSweep(g_long_sweep);
   Strategy_ResetSweep(g_short_sweep);

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10629_et-ob-bos-imb\"}");
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
