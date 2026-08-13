#property strict
#property version   "5.1"
#property description "QM5_11468 Naked Forex Last Kiss D1 box-breakout retouch"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11468 nekritin-peters-last-kiss-d1h4
// -----------------------------------------------------------------------------
// Source: Alex Nekritin and Walter Peters, Naked Forex, chapter 5
//         (Wiley Trading, 2012).
// Card: D:/QM/strategy_farm/artifacts/cards_approved/
//       QM5_11468_nekritin-peters-last-kiss-d1h4.md (OWNER-approved).
//
// Mechanical baseline, evaluated only after a completed D1 bar:
//   1. Form a bounded consolidation box from the bars immediately before a
//      confirmed close outside that box.
//   2. Require price to remain outside until its first retouch of the broken
//      edge, then require a rejection candle that closes back outside.
//   3. Place a one-D1-bar stop order one pip beyond the rejection candle.
//   4. Stop at the box midpoint. Target the prior structural extreme beyond
//      entry, falling back to 1.5 box heights when no such extreme exists.
//   5. Exit on a completed close back through the broken box edge, or after
//      20 D1 bars. Fixed SL/TP and the framework Friday close remain active.
//
// This is structural OHLC logic: no strategy indicator, ML, grid, martingale,
// adaptive threshold, or per-tick window scan is used.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 11468;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact            = "high";
input QM_NewsMode qm_news_mode_legacy      = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Stress"
input double qm_stress_reject_probability  = 0.0;

input group "Strategy"
input int    strategy_box_bars             = 10;
input int    strategy_box_min_pips         = 30;
input int    strategy_box_max_pips         = 120;
input int    strategy_zone_buffer_pips     = 10;
input int    strategy_retouch_window       = 10;
input int    strategy_entry_offset_pips    = 1;
input int    strategy_pending_expiry_bars  = 1;
input int    strategy_sl_cap_pips          = 120;
input int    strategy_tp_swing_lookback    = 30;
input double strategy_tp_box_mult          = 1.5;
input int    strategy_time_stop_bars       = 20;
input int    strategy_spread_cap_pips      = 25;

bool   g_exit_requested = false;
double g_active_box_high = 0.0;
double g_active_box_low  = 0.0;

double LK_PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

bool LK_IsPendingType(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_STOP ||
           order_type == ORDER_TYPE_SELL_STOP);
  }

bool LK_HasExposure()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
         (int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(LK_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }
   return false;
  }

void LK_RemoveExpiredSignalOrders()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(!LK_IsPendingType((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         continue;
      QM_TM_RemovePendingOrder(ticket, "last_kiss_one_bar_expiry");
     }
  }

// Detect a complete Last Kiss whose rejection candle is trigger_shift.
// Returns +1 for a bullish breakout/retouch, -1 for bearish, or 0 for none.
int LK_DetectSetupAt(const int trigger_shift,
                     double &out_box_high,
                     double &out_box_low,
                     int &out_history_start)
  {
   out_box_high = 0.0;
   out_box_low = 0.0;
   out_history_start = 0;

   const int bars_available = Bars(_Symbol, PERIOD_D1); // perf-allowed: one D1 history-availability query behind the framework new-bar gate.
   const int maximum_shift = trigger_shift + strategy_retouch_window +
                             strategy_box_bars +
                             strategy_tp_swing_lookback + 3;
   if(trigger_shift < 1 || bars_available <= maximum_shift)
      return 0;

   const double zone = LK_PipDistance(strategy_zone_buffer_pips);
   const double min_width = LK_PipDistance(strategy_box_min_pips);
   const double max_width = LK_PipDistance(strategy_box_max_pips);
   if(zone < 0.0 || min_width <= 0.0 || max_width < min_width)
      return 0;

   const double reject_open = iOpen(_Symbol, PERIOD_D1, trigger_shift);   // perf-allowed: structural D1 OHLC, called only behind the framework new-bar gate.
   const double reject_high = iHigh(_Symbol, PERIOD_D1, trigger_shift);   // perf-allowed: structural D1 OHLC, called only behind the framework new-bar gate.
   const double reject_low = iLow(_Symbol, PERIOD_D1, trigger_shift);     // perf-allowed: structural D1 OHLC, called only behind the framework new-bar gate.
   const double reject_close = iClose(_Symbol, PERIOD_D1, trigger_shift); // perf-allowed: structural D1 OHLC, called only behind the framework new-bar gate.
   if(reject_open <= 0.0 || reject_high <= 0.0 ||
      reject_low <= 0.0 || reject_close <= 0.0)
      return 0;

   const int oldest_breakout = trigger_shift + strategy_retouch_window;
   for(int breakout_shift = trigger_shift + 1;
       breakout_shift <= oldest_breakout;
       ++breakout_shift)
     {
      const int box_first = breakout_shift + 1;
      const int box_last = breakout_shift + strategy_box_bars;
      double box_high = -1.0;
      double box_low = DBL_MAX;

      for(int shift = box_first; shift <= box_last; ++shift)
        {
         const double high_value = iHigh(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded structural D1 box scan, called only behind the framework new-bar gate.
         const double low_value = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed: bounded structural D1 box scan, called only behind the framework new-bar gate.
         if(high_value <= 0.0 || low_value <= 0.0)
           {
            box_high = -1.0;
            break;
           }
         box_high = MathMax(box_high, high_value);
         box_low = MathMin(box_low, low_value);
        }
      if(box_high <= 0.0 || box_low == DBL_MAX || box_high <= box_low)
         continue;

      const double width = box_high - box_low;
      if(width < min_width || width > max_width)
         continue;

      const double breakout_close = iClose(_Symbol, PERIOD_D1, breakout_shift); // perf-allowed: structural D1 breakout close, called only behind the framework new-bar gate.
      if(breakout_close <= 0.0)
         continue;

      if(breakout_close > box_high)
        {
         bool first_retouch = true;
         for(int shift = breakout_shift - 1; shift > trigger_shift; --shift)
           {
            const double close_value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded post-breakout D1 scan, called only behind the framework new-bar gate.
            const double low_value = iLow(_Symbol, PERIOD_D1, shift);     // perf-allowed: bounded post-breakout D1 scan, called only behind the framework new-bar gate.
            if(close_value <= box_high || low_value <= box_high + zone)
              {
               first_retouch = false;
               break;
              }
           }

         if(first_retouch && reject_low <= box_high + zone &&
            reject_close > reject_open && reject_close > box_high)
           {
            out_box_high = box_high;
            out_box_low = box_low;
            out_history_start = box_last + 1;
            return +1;
           }
        }

      if(breakout_close < box_low)
        {
         bool first_retouch = true;
         for(int shift = breakout_shift - 1; shift > trigger_shift; --shift)
           {
            const double close_value = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded post-breakout D1 scan, called only behind the framework new-bar gate.
            const double high_value = iHigh(_Symbol, PERIOD_D1, shift);   // perf-allowed: bounded post-breakout D1 scan, called only behind the framework new-bar gate.
            if(close_value >= box_low || high_value >= box_low - zone)
              {
               first_retouch = false;
               break;
              }
           }

         if(first_retouch && reject_high >= box_low - zone &&
            reject_close < reject_open && reject_close < box_low)
           {
            out_box_high = box_high;
            out_box_low = box_low;
            out_history_start = box_last + 1;
            return -1;
           }
        }
     }
   return 0;
  }

double LK_TargetForEntry(const int direction,
                         const double entry_price,
                         const double box_height,
                         const int history_start)
  {
   double target = 0.0;
   if(direction > 0)
     {
      const int high_shift = iHighest(_Symbol,
                                      PERIOD_D1,
                                      MODE_HIGH,
                                      strategy_tp_swing_lookback,
                                      history_start); // perf-allowed: single bounded structural lookup behind the framework new-bar gate.
      if(high_shift >= 0)
        {
         const double prior_high = iHigh(_Symbol, PERIOD_D1, high_shift); // perf-allowed: one structural D1 target read behind the framework new-bar gate.
         if(prior_high > entry_price)
            target = prior_high;
        }
      if(target <= entry_price)
         target = entry_price + box_height * strategy_tp_box_mult;
     }
   else
     {
      const int low_shift = iLowest(_Symbol,
                                    PERIOD_D1,
                                    MODE_LOW,
                                    strategy_tp_swing_lookback,
                                    history_start); // perf-allowed: single bounded structural lookup behind the framework new-bar gate.
      if(low_shift >= 0)
        {
         const double prior_low = iLow(_Symbol, PERIOD_D1, low_shift); // perf-allowed: one structural D1 target read behind the framework new-bar gate.
         if(prior_low > 0.0 && prior_low < entry_price)
            target = prior_low;
        }
      if(target <= 0.0 || target >= entry_price)
         target = entry_price - box_height * strategy_tp_box_mult;
     }
   return QM_StopRulesNormalizePrice(_Symbol, target);
  }

bool LK_RecoverPositionBox(const datetime position_time,
                           const bool is_long,
                           const double position_sl,
                           double &out_box_high,
                           double &out_box_low)
  {
   if(g_active_box_high > g_active_box_low && g_active_box_low > 0.0)
     {
      out_box_high = g_active_box_high;
      out_box_low = g_active_box_low;
      return true;
     }

   const int position_shift = iBarShift(_Symbol, PERIOD_D1, position_time, false);
   if(position_shift < 0)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tolerance = MathMax(point * 2.0, 0.0000001);
   for(int lag = 1; lag <= 2; ++lag)
     {
      double box_high = 0.0;
      double box_low = 0.0;
      int history_start = 0;
      const int direction = LK_DetectSetupAt(position_shift + lag,
                                             box_high,
                                             box_low,
                                             history_start);
      if(direction == 0 || ((direction > 0) != is_long))
         continue;
      const double midpoint = (box_high + box_low) / 2.0;
      if(position_sl > 0.0 && MathAbs(midpoint - position_sl) > tolerance)
         continue;
      out_box_high = box_high;
      out_box_low = box_low;
      return true;
     }
   return false;
  }

void LK_AdvanceExitStateOnNewBar()
  {
   g_exit_requested = false;
   LK_RemoveExpiredSignalOrders();

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const bool is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) ==
                            POSITION_TYPE_BUY);
      const datetime position_time = (datetime)PositionGetInteger(POSITION_TIME);
      const double position_sl = PositionGetDouble(POSITION_SL);
      const double close_one = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: one completed D1 invalidation read behind the framework new-bar gate.
      if(close_one <= 0.0)
         return;

      double box_high = 0.0;
      double box_low = 0.0;
      if(LK_RecoverPositionBox(position_time,
                               is_long,
                               position_sl,
                               box_high,
                               box_low))
        {
         if((is_long && close_one < box_high) ||
            (!is_long && close_one > box_low))
           {
            g_exit_requested = true;
            return;
           }
        }

      const int bars_held = iBarShift(_Symbol,
                                      PERIOD_D1,
                                      position_time,
                                      false);
      if(strategy_time_stop_bars > 0 && bars_held >= strategy_time_stop_bars)
         g_exit_requested = true;
      return;
     }
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return true;

   const double cap = LK_PipDistance(strategy_spread_cap_pips);
   const double spread = ask - bid;
   return (cap > 0.0 && spread > 0.0 && spread > cap);
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

   if(LK_HasExposure())
      return false;

   double box_high = 0.0;
   double box_low = 0.0;
   int history_start = 0;
   const int direction = LK_DetectSetupAt(1,
                                          box_high,
                                          box_low,
                                          history_start);
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double offset = LK_PipDistance(strategy_entry_offset_pips);
   const double box_midpoint = (box_high + box_low) / 2.0;
   const double box_height = box_high - box_low;
   if(ask <= 0.0 || bid <= 0.0 || offset <= 0.0 || box_height <= 0.0)
      return false;

   const int period_seconds = PeriodSeconds(PERIOD_D1);
   const int expiry_seconds = MathMax(1, strategy_pending_expiry_bars) *
                              MathMax(1, period_seconds);

   if(direction > 0)
     {
      const double rejection_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: one completed D1 stop-entry reference behind the framework new-bar gate.
      const double trigger = QM_StopRulesNormalizePrice(_Symbol,
                                                        rejection_high + offset);
      req.type = (ask >= trigger) ? QM_BUY : QM_BUY_STOP;
      req.price = (req.type == QM_BUY_STOP) ? trigger : 0.0;
      const double entry_price = (req.type == QM_BUY_STOP) ? trigger : ask;
      if(trigger <= 0.0 || box_midpoint >= entry_price ||
         entry_price - box_midpoint > LK_PipDistance(strategy_sl_cap_pips))
         return false;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, box_midpoint);
      req.tp = LK_TargetForEntry(direction,
                                 entry_price,
                                 box_height,
                                 history_start);
      if(req.tp <= entry_price)
         return false;
      req.reason = "LAST_KISS_D1_LONG";
      req.expiration_seconds = (req.type == QM_BUY_STOP) ? expiry_seconds : 0;
     }
   else
     {
      const double rejection_low = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: one completed D1 stop-entry reference behind the framework new-bar gate.
      const double trigger = QM_StopRulesNormalizePrice(_Symbol,
                                                        rejection_low - offset);
      req.type = (bid <= trigger) ? QM_SELL : QM_SELL_STOP;
      req.price = (req.type == QM_SELL_STOP) ? trigger : 0.0;
      const double entry_price = (req.type == QM_SELL_STOP) ? trigger : bid;
      if(trigger <= 0.0 || box_midpoint <= entry_price ||
         box_midpoint - entry_price > LK_PipDistance(strategy_sl_cap_pips))
         return false;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, box_midpoint);
      req.tp = LK_TargetForEntry(direction,
                                 entry_price,
                                 box_height,
                                 history_start);
      if(req.tp <= 0.0 || req.tp >= entry_price)
         return false;
      req.reason = "LAST_KISS_D1_SHORT";
      req.expiration_seconds = (req.type == QM_SELL_STOP) ? expiry_seconds : 0;
     }

   g_active_box_high = box_high;
   g_active_box_low = box_low;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The approved card specifies fixed SL/TP plus structural and time exits.
  }

bool Strategy_ExitSignal()
  {
   return g_exit_requested;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

bool LK_InputsValid()
  {
   return (qm_ea_id == 11468 &&
           qm_magic_slot_offset >= 0 && qm_magic_slot_offset <= 4 &&
           strategy_box_bars >= 5 && strategy_box_bars <= 30 &&
           strategy_box_min_pips > 0 &&
           strategy_box_max_pips >= strategy_box_min_pips &&
           strategy_zone_buffer_pips >= 0 &&
           strategy_retouch_window >= 1 && strategy_retouch_window <= 10 &&
           strategy_entry_offset_pips > 0 &&
           strategy_pending_expiry_bars == 1 &&
           strategy_sl_cap_pips > 0 &&
           strategy_tp_swing_lookback >= 3 &&
           strategy_tp_box_mult > 0.0 &&
           strategy_time_stop_bars > 0 &&
           strategy_spread_cap_pips > 0.0);
  }

int OnInit()
  {
   if(_Period != PERIOD_D1 || !LK_InputsValid())
      return INIT_PARAMETERS_INCORRECT;

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
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(QM_FrameworkHandleFridayClose())
      return;

   const bool is_new_bar = QM_IsNewBar();
   if(is_new_bar)
      LK_AdvanceExitStateOnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      bool close_succeeded = false;
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol ||
            (int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         if(QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY))
            close_succeeded = true;
        }
      if(close_succeeded)
        {
         g_exit_requested = false;
         g_active_box_high = 0.0;
         g_active_box_low = 0.0;
        }
     }

   if(!is_new_bar)
      return;

   QM_EquityStreamOnNewBar();

   // News and spread constraints gate new entries only. They never suppress
   // fixed-risk management, structural exits, or the Friday close above.
   if(Strategy_NewsFilterHook(broker_now))
      return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF ||
      qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol,
                                        broker_now,
                                        qm_news_temporal,
                                        qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol,
                                       broker_now,
                                       qm_news_mode_legacy);
   if(!news_allows || Strategy_NoTradeFilter())
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
