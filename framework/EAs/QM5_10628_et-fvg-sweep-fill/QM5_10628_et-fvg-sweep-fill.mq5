#property strict
#property version   "5.0"
#property description "QM5_10628 Elite Trader FVG Sweep Fill"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10628;
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
input int    strategy_h4_swing_lookback       = 60;
input int    strategy_d1_swing_lookback       = 15;
input double strategy_sweep_depth_atr         = 0.20;
input int    strategy_sweep_reclaim_bars      = 3;
input int    strategy_displacement_window     = 8;
input double strategy_displacement_body_atr   = 1.20;
input double strategy_displacement_close_pct  = 0.25;
input double strategy_fvg_min_width_atr       = 0.15;
input double strategy_fvg_max_width_atr       = 1.20;
input double strategy_fvg_fill_level          = 0.50;
input double strategy_max_spread_width_frac   = 0.20;
input double strategy_max_fvg_level_atr       = 1.50;
input int    strategy_pending_bars            = 6;
input int    strategy_m15_swing_lookback      = 20;
input int    strategy_time_exit_bars          = 24;
input double strategy_rr_cap                  = 2.00;

static double g_active_fvg_low  = 0.0;
static double g_active_fvg_high = 0.0;
static int    g_active_side     = 0;   // +1 long, -1 short

// Return TRUE to BLOCK trading this tick (No Trade Filter: framework handles
// time/news/Friday; the card's spread filter is FVG-width dependent and lives
// inside Strategy_EntrySignal).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with a pending FVG midpoint order. Caller guarantees this is
// evaluated once per closed bar via the framework QM_IsNewBar gate.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong order_ticket = OrderGetTicket(i);
      if(order_ticket == 0 || !OrderSelect(order_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT)
         return false;
     }

   const int bars_m15 = Bars(_Symbol, PERIOD_M15); // perf-allowed
   const int needed = MathMax(strategy_h4_swing_lookback * 4, strategy_displacement_window + strategy_sweep_reclaim_bars + 10);
   if(bars_m15 < needed)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_M15, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   double low_levels[128];
   double high_levels[128];
   int low_count = 0;
   int high_count = 0;
   ENUM_TIMEFRAMES frames[2] = { PERIOD_H4, PERIOD_D1 };
   int lookbacks[2] = { strategy_h4_swing_lookback, strategy_d1_swing_lookback };

   for(int f = 0; f < 2; ++f)
     {
      const int available = Bars(_Symbol, frames[f]); // perf-allowed
      const int lookback = MathMin(lookbacks[f], available - 2);
      if(lookback < 3)
         continue;

      for(int shift = 2; shift <= lookback; ++shift)
        {
         const double h = iHigh(_Symbol, frames[f], shift); // perf-allowed
         const double hp = iHigh(_Symbol, frames[f], shift + 1); // perf-allowed
         const double hn = iHigh(_Symbol, frames[f], shift - 1); // perf-allowed
         if(h > 0.0 && h > hp && h > hn && high_count < 128)
           {
            bool duplicate_high = false;
            for(int k = 0; k < high_count; ++k)
               if(MathAbs(high_levels[k] - h) <= point * 2.0)
                  duplicate_high = true;
            if(!duplicate_high)
               high_levels[high_count++] = h;
           }

         const double l = iLow(_Symbol, frames[f], shift); // perf-allowed
         const double lp = iLow(_Symbol, frames[f], shift + 1); // perf-allowed
         const double ln = iLow(_Symbol, frames[f], shift - 1); // perf-allowed
         if(l > 0.0 && l < lp && l < ln && low_count < 128)
           {
            bool duplicate_low = false;
            for(int k = 0; k < low_count; ++k)
               if(MathAbs(low_levels[k] - l) <= point * 2.0)
                  duplicate_low = true;
            if(!duplicate_low)
               low_levels[low_count++] = l;
           }
        }
     }

   if(low_count == 0 && high_count == 0)
      return false;

   const double open_b = iOpen(_Symbol, PERIOD_M15, 2); // perf-allowed
   const double high_b = iHigh(_Symbol, PERIOD_M15, 2); // perf-allowed
   const double low_b = iLow(_Symbol, PERIOD_M15, 2); // perf-allowed
   const double close_b = iClose(_Symbol, PERIOD_M15, 2); // perf-allowed
   const double high_a = iHigh(_Symbol, PERIOD_M15, 3); // perf-allowed
   const double low_a = iLow(_Symbol, PERIOD_M15, 3); // perf-allowed
   const double high_c = iHigh(_Symbol, PERIOD_M15, 1); // perf-allowed
   const double low_c = iLow(_Symbol, PERIOD_M15, 1); // perf-allowed
   const double close_c = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed
   if(open_b <= 0.0 || high_b <= low_b || close_b <= 0.0 || high_a <= 0.0 || low_a <= 0.0 || high_c <= 0.0 || low_c <= 0.0 || close_c <= 0.0)
      return false;

   const double body_b = MathAbs(close_b - open_b);
   const double range_b = high_b - low_b;
   const double spread = ask - bid;
   const int bar_seconds = PeriodSeconds(PERIOD_M15);
   const int expiry_seconds = MathMax(bar_seconds, strategy_pending_bars * bar_seconds);

   const bool bullish_displacement = (close_b > open_b &&
                                      body_b >= strategy_displacement_body_atr * atr &&
                                      range_b > 0.0 &&
                                      (high_b - close_b) <= strategy_displacement_close_pct * range_b);
   const bool bearish_displacement = (close_b < open_b &&
                                      body_b >= strategy_displacement_body_atr * atr &&
                                      range_b > 0.0 &&
                                      (close_b - low_b) <= strategy_displacement_close_pct * range_b);

   if(bullish_displacement && low_c > high_a)
     {
      const double fvg_low = high_a;
      const double fvg_high = low_c;
      const double fvg_width = fvg_high - fvg_low;
      if(fvg_width >= strategy_fvg_min_width_atr * atr &&
         fvg_width <= strategy_fvg_max_width_atr * atr &&
         spread <= strategy_max_spread_width_frac * fvg_width)
        {
         double best_level = 0.0;
         double best_sweep_low = 0.0;
         double best_distance = DBL_MAX;
         const double entry = fvg_low + fvg_width * strategy_fvg_fill_level;

         for(int level_idx = 0; level_idx < low_count; ++level_idx)
           {
            const double level = low_levels[level_idx];
            if(MathAbs(entry - level) > strategy_max_fvg_level_atr * atr)
               continue;

            double sweep_low = DBL_MAX;
            bool sweep_ok = false;
            for(int reclaim_shift = 2; reclaim_shift <= strategy_displacement_window + 1 && !sweep_ok; ++reclaim_shift)
              {
               const double close_reclaim = iClose(_Symbol, PERIOD_M15, reclaim_shift); // perf-allowed
               if(close_reclaim <= level)
                  continue;
               double local_low = DBL_MAX;
               for(int j = 0; j < strategy_sweep_reclaim_bars; ++j)
                 {
                  const double probe_low = iLow(_Symbol, PERIOD_M15, reclaim_shift + j); // perf-allowed
                  if(probe_low > 0.0)
                     local_low = MathMin(local_low, probe_low);
                 }
               if(local_low <= level - strategy_sweep_depth_atr * atr)
                 {
                  sweep_low = local_low;
                  sweep_ok = true;
                 }
              }

            const double distance = MathAbs(entry - level);
            if(sweep_ok && distance < best_distance)
              {
               best_distance = distance;
               best_level = level;
               best_sweep_low = sweep_low;
              }
           }

         if(best_level > 0.0 && best_sweep_low > 0.0 && entry < ask - point)
           {
            const double sl = NormalizeDouble(best_sweep_low - strategy_sweep_depth_atr * atr, _Digits);
            if(sl > 0.0 && sl < entry)
              {
               double opposing_high = 0.0;
               for(int s = 2; s <= strategy_m15_swing_lookback; ++s)
                 {
                  const double h = iHigh(_Symbol, PERIOD_M15, s); // perf-allowed
                  const double hp = iHigh(_Symbol, PERIOD_M15, s + 1); // perf-allowed
                  const double hn = iHigh(_Symbol, PERIOD_M15, s - 1); // perf-allowed
                  if(h > entry && h > hp && h > hn)
                    {
                     if(opposing_high <= 0.0 || h < opposing_high)
                        opposing_high = h;
                    }
                 }

               const double rr_tp = entry + (entry - sl) * strategy_rr_cap;
               double tp = (opposing_high > entry) ? MathMin(opposing_high, rr_tp) : rr_tp;
               tp = NormalizeDouble(tp, _Digits);
               if(tp > entry)
                 {
                  req.type = QM_BUY_LIMIT;
                  req.price = NormalizeDouble(entry, _Digits);
                  req.sl = sl;
                  req.tp = tp;
                  req.reason = "et-fvg-sweep-fill-long";
                  req.symbol_slot = qm_magic_slot_offset;
                  req.expiration_seconds = expiry_seconds;
                  g_active_fvg_low = fvg_low;
                  g_active_fvg_high = fvg_high;
                  g_active_side = 1;
                  return true;
                 }
              }
           }
        }
     }

   if(bearish_displacement && high_c < low_a)
     {
      const double fvg_low = high_c;
      const double fvg_high = low_a;
      const double fvg_width = fvg_high - fvg_low;
      if(fvg_width >= strategy_fvg_min_width_atr * atr &&
         fvg_width <= strategy_fvg_max_width_atr * atr &&
         spread <= strategy_max_spread_width_frac * fvg_width)
        {
         double best_level = 0.0;
         double best_sweep_high = 0.0;
         double best_distance = DBL_MAX;
         const double entry = fvg_low + fvg_width * strategy_fvg_fill_level;

         for(int level_idx = 0; level_idx < high_count; ++level_idx)
           {
            const double level = high_levels[level_idx];
            if(MathAbs(entry - level) > strategy_max_fvg_level_atr * atr)
               continue;

            double sweep_high = 0.0;
            bool sweep_ok = false;
            for(int reclaim_shift = 2; reclaim_shift <= strategy_displacement_window + 1 && !sweep_ok; ++reclaim_shift)
              {
               const double close_reclaim = iClose(_Symbol, PERIOD_M15, reclaim_shift); // perf-allowed
               if(close_reclaim >= level)
                  continue;
               double local_high = 0.0;
               for(int j = 0; j < strategy_sweep_reclaim_bars; ++j)
                 {
                  const double probe_high = iHigh(_Symbol, PERIOD_M15, reclaim_shift + j); // perf-allowed
                  if(probe_high > 0.0)
                     local_high = MathMax(local_high, probe_high);
                 }
               if(local_high >= level + strategy_sweep_depth_atr * atr)
                 {
                  sweep_high = local_high;
                  sweep_ok = true;
                 }
              }

            const double distance = MathAbs(entry - level);
            if(sweep_ok && distance < best_distance)
              {
               best_distance = distance;
               best_level = level;
               best_sweep_high = sweep_high;
              }
           }

         if(best_level > 0.0 && best_sweep_high > 0.0 && entry > bid + point)
           {
            const double sl = NormalizeDouble(best_sweep_high + strategy_sweep_depth_atr * atr, _Digits);
            if(sl > entry)
              {
               double opposing_low = 0.0;
               for(int s = 2; s <= strategy_m15_swing_lookback; ++s)
                 {
                  const double l = iLow(_Symbol, PERIOD_M15, s); // perf-allowed
                  const double lp = iLow(_Symbol, PERIOD_M15, s + 1); // perf-allowed
                  const double ln = iLow(_Symbol, PERIOD_M15, s - 1); // perf-allowed
                  if(l < entry && l < lp && l < ln)
                    {
                     if(opposing_low <= 0.0 || l > opposing_low)
                        opposing_low = l;
                    }
                 }

               const double rr_tp = entry - (sl - entry) * strategy_rr_cap;
               double tp = (opposing_low > 0.0 && opposing_low < entry) ? MathMax(opposing_low, rr_tp) : rr_tp;
               tp = NormalizeDouble(tp, _Digits);
               if(tp > 0.0 && tp < entry)
                 {
                  req.type = QM_SELL_LIMIT;
                  req.price = NormalizeDouble(entry, _Digits);
                  req.sl = sl;
                  req.tp = tp;
                  req.reason = "et-fvg-sweep-fill-short";
                  req.symbol_slot = qm_magic_slot_offset;
                  req.expiration_seconds = expiry_seconds;
                  g_active_fvg_low = fvg_low;
                  g_active_fvg_high = fvg_high;
                  g_active_side = -1;
                  return true;
                 }
              }
           }
        }
     }

   return false;
  }

// Card specifies no trailing, break-even, partial close, or pyramiding.
void Strategy_ManageOpenPosition()
  {
  }

// Exit if the cached FVG is fully invalidated against the position or if the
// position has been held for the card's 24 closed M15 bars.
bool Strategy_ExitSignal()
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

      const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
      const int max_hold_seconds = strategy_time_exit_bars * PeriodSeconds(PERIOD_M15);
      if(opened > 0 && max_hold_seconds > 0 && (TimeCurrent() - opened) >= max_hold_seconds)
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double close_last = iClose(_Symbol, PERIOD_M15, 1); // perf-allowed
      if(close_last <= 0.0 || g_active_fvg_low <= 0.0 || g_active_fvg_high <= 0.0)
         continue;

      if(ptype == POSITION_TYPE_BUY && g_active_side == 1 && close_last < g_active_fvg_low)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_active_side == -1 && close_last > g_active_fvg_high)
         return true;
     }

   return false;
  }

// News Filter Hook: no custom overlay beyond the framework's two-axis news
// filter. Returning false defers to QM_NewsAllowsTrade2/QM_NewsAllowsTrade.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
