#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20098;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input bool   strategy_vol_confirm_enabled = false;
input double strategy_vol_mult            = 2.0;
input int    strategy_vol_lookback        = 96;
input double strategy_rr_ratio            = 2.0;

enum Strategy021_SideState
  {
   STR021_IDLE = 0,
   STR021_SWEPT,
   STR021_CONFIRMED_PENDING
  };

struct Strategy021_SideCtx
  {
   Strategy021_SideState st;
   double                ob_high;
   double                ob_low;
   datetime              ob_time;
   ulong                 ticket;
  };

Strategy021_SideCtx g_str021_long;
Strategy021_SideCtx g_str021_short;
double              g_str021_weekly_open            = 0.0;
datetime            g_str021_week_start             = 0;
double              g_str021_prev_d1_low            = 0.0;
double              g_str021_prev_d1_high           = 0.0;
datetime            g_str021_long_sweep_time        = 0;
datetime            g_str021_short_sweep_time       = 0;
datetime            g_str021_last_processed_bar     = 0;
datetime            g_str021_last_data_log_bar      = 0;
datetime            g_str021_last_dual_log_bar      = 0;
bool                g_str021_initialized            = false;

void Strategy021_ResetSide(Strategy021_SideCtx &ctx,
                           datetime &sweep_time,
                           const Strategy021_SideState next_state)
  {
   ctx.st = next_state;
   ctx.ob_high = 0.0;
   ctx.ob_low = 0.0;
   ctx.ob_time = 0;
   ctx.ticket = 0;
   if(next_state == STR021_IDLE)
      sweep_time = 0;
  }

void Strategy021_ResetWeekState()
  {
   Strategy021_ResetSide(g_str021_long,
                         g_str021_long_sweep_time,
                         STR021_IDLE);
   Strategy021_ResetSide(g_str021_short,
                         g_str021_short_sweep_time,
                         STR021_IDLE);
   g_str021_last_processed_bar = 0;
  }

void Strategy021_LogDataMissing(const string component)
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   if(bar_time > 0 && bar_time == g_str021_last_data_log_bar)
      return;
   g_str021_last_data_log_bar = bar_time;
   QM_LogEvent(QM_WARN,
               SETUP_DATA_MISSING,
               StringFormat("{\"strategy\":\"STR-021\",\"component\":\"%s\",\"bar_time\":%I64d}",
                            QM_LoggerEscapeJson(component),
                            (long)bar_time));
  }

double Strategy021_TickSize()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy021_NormalizeTick(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   const double tick = Strategy021_TickSize();
   if(tick <= 0.0)
      return 0.0;
   const double aligned = MathRound(price / tick) * tick;
   return NormalizeDouble(aligned,
                          (int)SymbolInfoInteger(_Symbol,
                                                SYMBOL_DIGITS));
  }

bool Strategy021_PreviousDayExtremes(const datetime bar_time,
                                     double &previous_low,
                                     double &previous_high)
  {
   previous_low = 0.0;
   previous_high = 0.0;
   if(bar_time <= 0)
      return false;
   const int containing_shift =
      iBarShift(_Symbol, PERIOD_D1, bar_time, false);
   if(containing_shift < 0)
      return false;
   const int previous_shift = containing_shift + 1;
   previous_low = iLow(_Symbol, PERIOD_D1, previous_shift); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   previous_high = iHigh(_Symbol, PERIOD_D1, previous_shift); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   return (previous_low > 0.0 &&
           previous_high > previous_low);
  }

bool Strategy021_CurrentWeek(double &weekly_open,
                             datetime &week_start)
  {
   week_start = iTime(_Symbol, PERIOD_W1, 0); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   weekly_open = iOpen(_Symbol, PERIOD_W1, 0); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   return (week_start > 0 && weekly_open > 0.0);
  }

bool Strategy021_VolumePassReplay(const MqlRates &rates[],
                                  const int index)
  {
   if(!strategy_vol_confirm_enabled)
      return true;
   if(strategy_vol_lookback <= 0 ||
      strategy_vol_mult <= 0.0 ||
      index < strategy_vol_lookback)
      return false;

   double sum = 0.0;
   for(int i = index - strategy_vol_lookback; i < index; ++i)
     {
      if(rates[i].tick_volume <= 0)
         return false;
      sum += (double)rates[i].tick_volume;
     }
   const double average =
      sum / (double)strategy_vol_lookback;
   return (average > 0.0 &&
           (double)rates[index].tick_volume >=
              strategy_vol_mult * average);
  }

bool Strategy021_VolumePassLive(const MqlRates &candidate)
  {
   if(!strategy_vol_confirm_enabled)
      return true;
   if(strategy_vol_lookback <= 0 ||
      strategy_vol_mult <= 0.0 ||
      candidate.tick_volume <= 0)
      return false;

   MqlRates history[];
   ArraySetAsSeries(history, true);
   // perf-allowed: optional closed-M15 tick-volume confirmation, called only
   // from the skeleton's closed-bar EntrySignal path.
   const int copied = CopyRates(_Symbol,
                                PERIOD_M15,
                                2,
                                strategy_vol_lookback,
                                history);
   if(copied < strategy_vol_lookback)
      return false;
   double sum = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      if(history[i].tick_volume <= 0)
         return false;
      sum += (double)history[i].tick_volume;
     }
   const double average = sum / (double)copied;
   return (average > 0.0 &&
           (double)candidate.tick_volume >=
              strategy_vol_mult * average);
  }

bool Strategy021_RemovePendingSide(const bool long_side,
                                   bool &found)
  {
   found = false;
   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   const ENUM_ORDER_TYPE wanted =
      long_side ? ORDER_TYPE_BUY_LIMIT : ORDER_TYPE_SELL_LIMIT;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != wanted)
         continue;
      found = true;
      if(!QM_TM_RemovePendingOrder(
            ticket,
            long_side
            ? "STR021_LONG_OB_INVALIDATED"
            : "STR021_SHORT_OB_INVALIDATED"))
         all_ok = false;
     }
   return all_ok;
  }

bool Strategy021_CancelAllOwnPending(const string reason)
  {
   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type != ORDER_TYPE_BUY_LIMIT &&
         type != ORDER_TYPE_SELL_LIMIT)
         continue;
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok;
  }

bool Strategy021_ProcessSide(Strategy021_SideCtx &ctx,
                             datetime &sweep_time,
                             const bool long_side,
                             const MqlRates &bar,
                             const double previous_low,
                             const double previous_high,
                             const bool volume_pass,
                             const bool replay,
                             const bool side_has_position)
  {
   if(ctx.st == STR021_CONFIRMED_PENDING)
     {
      const bool invalidated =
         long_side
         ? (bar.close < ctx.ob_low)
         : (bar.close > ctx.ob_high);
      if(invalidated && !side_has_position)
        {
         if(!replay)
           {
            bool found = false;
            if(!Strategy021_RemovePendingSide(long_side, found))
               return false;
            if(!found)
               QM_LogEvent(
                  QM_INFO,
                  "TM_REMOVE_PENDING",
                  StringFormat(
                     "{\"strategy\":\"STR-021\",\"side\":\"%s\",\"reason\":\"ob_invalidated_before_submit\",\"ok\":true}",
                     long_side ? "LONG" : "SHORT"));
           }
         Strategy021_ResetSide(ctx,
                               sweep_time,
                               STR021_SWEPT);
        }
      return true;
     }

   if(ctx.st == STR021_IDLE)
     {
      const bool swept =
         long_side
         ? (bar.low < g_str021_weekly_open &&
            bar.low < previous_low)
         : (bar.high > g_str021_weekly_open &&
            bar.high > previous_high);
      if(swept)
        {
         ctx.st = STR021_SWEPT;
         sweep_time = bar.time;
        }
     }

   if(ctx.st != STR021_SWEPT)
      return true;

   const bool zero_range = (bar.high <= bar.low);
   const bool candidate =
      !zero_range &&
      volume_pass &&
      (long_side
       ? (bar.close < bar.open &&
          bar.high < g_str021_weekly_open)
       : (bar.close > bar.open &&
          bar.low > g_str021_weekly_open));
   if(candidate)
     {
      ctx.ob_high = bar.high;
      ctx.ob_low = bar.low;
      ctx.ob_time = bar.time;
      ctx.ticket = 0;
     }

   if(ctx.ob_time <= 0)
      return true;
   const bool confirmed =
      long_side
      ? (bar.close > ctx.ob_high)
      : (bar.close < ctx.ob_low);
   if(confirmed)
     {
      ctx.st = STR021_CONFIRMED_PENDING;
      ctx.ticket = 0;
     }
   return true;
  }

bool Strategy021_ReplayCurrentWeek()
  {
   double weekly_open = 0.0;
   datetime week_start = 0;
   if(!Strategy021_CurrentWeek(weekly_open, week_start))
      return false;

   g_str021_weekly_open = weekly_open;
   g_str021_week_start = week_start;
   Strategy021_ResetWeekState();

   MqlRates rates[];
   ArraySetAsSeries(rates, false);
   // perf-allowed: one bounded restart replay of the current broker week.
   const int copied = CopyRates(_Symbol,
                                PERIOD_M15,
                                g_str021_week_start,
                                TimeCurrent(),
                                rates);
   if(copied <= 0)
      return false;

   const datetime forming_bar = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time < g_str021_week_start ||
         rates[i].time >= forming_bar)
         continue;
      double previous_low = 0.0;
      double previous_high = 0.0;
      if(!Strategy021_PreviousDayExtremes(rates[i].time,
                                          previous_low,
                                          previous_high))
         continue;
      const bool volume_pass =
         Strategy021_VolumePassReplay(rates, i);
      if(!Strategy021_ProcessSide(g_str021_long,
                                  g_str021_long_sweep_time,
                                  true,
                                  rates[i],
                                  previous_low,
                                  previous_high,
                                  volume_pass,
                                  true,
                                  false))
         return false;
      if(!Strategy021_ProcessSide(g_str021_short,
                                  g_str021_short_sweep_time,
                                  false,
                                  rates[i],
                                  previous_low,
                                  previous_high,
                                  volume_pass,
                                  true,
                                  false))
         return false;
      g_str021_last_processed_bar = rates[i].time;
     }

   if(!Strategy021_PreviousDayExtremes(TimeCurrent(),
                                       g_str021_prev_d1_low,
                                       g_str021_prev_d1_high))
      return false;
   g_str021_initialized = true;
   return true;
  }

void Strategy021_ReconcileExposure(bool &long_position,
                                   bool &short_position,
                                   bool &any_exposure)
  {
   long_position = false;
   short_position = false;
   any_exposure = false;
   ulong live_long_order = 0;
   ulong live_short_order = 0;
   ulong live_long_position = 0;
   ulong live_short_position = 0;
   const int magic = QM_FrameworkMagic();
   const double tick = Strategy021_TickSize();

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(type == ORDER_TYPE_BUY_LIMIT)
        {
         live_long_order = ticket;
         g_str021_long.ob_high =
            OrderGetDouble(ORDER_PRICE_OPEN);
         g_str021_long.ob_low =
            OrderGetDouble(ORDER_SL) + tick;
        }
      else if(type == ORDER_TYPE_SELL_LIMIT)
        {
         live_short_order = ticket;
         g_str021_short.ob_low =
            OrderGetDouble(ORDER_PRICE_OPEN);
         g_str021_short.ob_high =
            OrderGetDouble(ORDER_SL) - tick;
        }
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY)
        {
         live_long_position = ticket;
         long_position = true;
        }
      else
        {
         live_short_position = ticket;
         short_position = true;
        }
     }

   if(live_long_order > 0)
     {
      g_str021_long.st = STR021_CONFIRMED_PENDING;
      g_str021_long.ticket = live_long_order;
     }
   else if(live_long_position > 0)
     {
      g_str021_long.st = STR021_CONFIRMED_PENDING;
      g_str021_long.ticket = live_long_position;
     }
   else if(g_str021_long.st == STR021_CONFIRMED_PENDING &&
           g_str021_long.ticket > 0)
     {
      Strategy021_ResetSide(g_str021_long,
                            g_str021_long_sweep_time,
                            STR021_SWEPT);
     }

   if(live_short_order > 0)
     {
      g_str021_short.st = STR021_CONFIRMED_PENDING;
      g_str021_short.ticket = live_short_order;
     }
   else if(live_short_position > 0)
     {
      g_str021_short.st = STR021_CONFIRMED_PENDING;
      g_str021_short.ticket = live_short_position;
     }
   else if(g_str021_short.st == STR021_CONFIRMED_PENDING &&
           g_str021_short.ticket > 0)
     {
      Strategy021_ResetSide(g_str021_short,
                            g_str021_short_sweep_time,
                            STR021_SWEPT);
     }

   any_exposure =
      (live_long_order > 0 ||
       live_short_order > 0 ||
       live_long_position > 0 ||
       live_short_position > 0);
  }

bool Strategy021_HandleWeek()
  {
   double weekly_open = 0.0;
   datetime week_start = 0;
   if(!Strategy021_CurrentWeek(weekly_open, week_start))
      return false;

   if(!g_str021_initialized)
      return Strategy021_ReplayCurrentWeek();
   if(week_start == g_str021_week_start)
      return true;

   if(!Strategy021_CancelAllOwnPending(
         "STR021_WEEK_ROLLOVER"))
     {
      QM_LogEvent(QM_WARN,
                  "STRATEGY_REBALANCE_FAILED",
                  "{\"strategy\":\"STR-021\",\"reason\":\"week_rollover_pending_cancel\"}");
      return false;
     }

   if(!Strategy021_ReplayCurrentWeek())
      return false;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_REBALANCE_DONE",
      StringFormat(
         "{\"strategy\":\"STR-021\",\"reason\":\"week_rollover\",\"week_start\":%I64d,\"weekly_open\":%.8f}",
         (long)g_str021_week_start,
         g_str021_weekly_open));
   return true;
  }

bool Strategy021_PendingGeometryLegal(const bool long_side,
                                      const double entry,
                                      const double stop)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy021_TickSize();
   if(point <= 0.0 ||
      tick <= 0.0 ||
      entry <= 0.0 ||
      stop <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double minimum =
      (stops_level > 0) ? (double)stops_level * point : tick;
   if(MathAbs(entry - stop) < minimum)
      return false;

   if(long_side)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      return (stop < entry &&
              ask > entry &&
              ask - entry >= minimum);
     }
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   return (stop > entry &&
           bid < entry &&
           entry - bid >= minimum);
  }

bool Strategy021_BuildPendingRequest(const bool long_side,
                                     QM_EntryRequest &req)
  {
   Strategy021_SideCtx ctx;
   if(long_side)
      ctx = g_str021_long;
   else
      ctx = g_str021_short;
   const double tick = Strategy021_TickSize();
   if(tick <= 0.0 ||
      ctx.ob_high <= ctx.ob_low ||
      ctx.ob_time <= 0)
      return false;

   const double entry =
      Strategy021_NormalizeTick(
         long_side ? ctx.ob_high : ctx.ob_low);
   const double stop =
      Strategy021_NormalizeTick(
         long_side
         ? ctx.ob_low - tick
         : ctx.ob_high + tick);
   if(!Strategy021_PendingGeometryLegal(long_side,
                                        entry,
                                        stop))
      return false;

   const datetime week_end =
      g_str021_week_start + 7 * 24 * 60 * 60;
   const long seconds_left =
      (long)(week_end - TimeCurrent());
   if(seconds_left <= 0)
      return false;

   ZeroMemory(req);
   req.type = long_side ? QM_BUY_LIMIT : QM_SELL_LIMIT;
   req.price = entry;
   req.sl = stop;
   req.tp = 0.0;
   req.reason =
      long_side
      ? "STR021_LONG_OB_RETRACE"
      : "STR021_SHORT_OB_RETRACE";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = (int)seconds_left;

   const datetime sweep_time =
      long_side
      ? g_str021_long_sweep_time
      : g_str021_short_sweep_time;
   const double previous_extreme =
      long_side
      ? g_str021_prev_d1_low
      : g_str021_prev_d1_high;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-021\",\"side\":\"%s\",\"weekly_open\":%.8f,\"prev_d1_extreme\":%.8f,\"ob_high\":%.8f,\"ob_low\":%.8f,\"sweep_time\":%I64d,\"ob_time\":%I64d,\"limit\":%.8f,\"sl\":%.8f}",
         long_side ? "LONG" : "SHORT",
         g_str021_weekly_open,
         previous_extreme,
         ctx.ob_high,
         ctx.ob_low,
         (long)sweep_time,
         (long)ctx.ob_time,
         req.price,
         req.sl));
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 ||
      strategy_vol_lookback <= 0 ||
      strategy_rr_ratio <= 0.0 ||
      (strategy_vol_confirm_enabled &&
       strategy_vol_mult <= 0.0))
      return true;

   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   if(Bars(_Symbol, PERIOD_W1) < 2 || // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
      Bars(_Symbol, PERIOD_D1) < 2 || // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
      Bars(_Symbol, PERIOD_M15) < // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
         strategy_vol_lookback + 5)
      return true;

   double weekly_open = 0.0;
   datetime week_start = 0;
   if(!Strategy021_CurrentWeek(weekly_open, week_start))
      return true;
   const double previous_low = iLow(_Symbol, PERIOD_D1, 1); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   const double previous_high = iHigh(_Symbol, PERIOD_D1, 1); // perf-allowed: O(1) closed-bar structural read, reviewer-approved (cross-review 2026-07-24)
   return (previous_low <= 0.0 ||
           previous_high <= previous_low);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy021_HandleWeek())
     {
      Strategy021_LogDataMissing("week_replay");
      return false;
     }

   bool long_position = false;
   bool short_position = false;
   bool any_exposure = false;
   Strategy021_ReconcileExposure(long_position,
                                 short_position,
                                 any_exposure);

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 1, closed_bar))
     {
      Strategy021_LogDataMissing("m15_signal_bar");
      return false;
     }
   if(closed_bar.time < g_str021_week_start)
      return false;

   if(closed_bar.time != g_str021_last_processed_bar)
     {
      if(!Strategy021_PreviousDayExtremes(
            closed_bar.time,
            g_str021_prev_d1_low,
            g_str021_prev_d1_high))
        {
         Strategy021_LogDataMissing("previous_d1_extremes");
         return false;
        }
      const bool volume_pass =
         Strategy021_VolumePassLive(closed_bar);
      if(strategy_vol_confirm_enabled && !volume_pass)
        {
         // A low-volume bar simply cannot become a new OB candidate. Existing
         // state still progresses through sweep/confirmation/invalidation.
        }
      if(!Strategy021_ProcessSide(g_str021_long,
                                  g_str021_long_sweep_time,
                                  true,
                                  closed_bar,
                                  g_str021_prev_d1_low,
                                  g_str021_prev_d1_high,
                                  volume_pass,
                                  false,
                                  long_position))
         return false;
      if(!Strategy021_ProcessSide(g_str021_short,
                                  g_str021_short_sweep_time,
                                  false,
                                  closed_bar,
                                  g_str021_prev_d1_low,
                                  g_str021_prev_d1_high,
                                  volume_pass,
                                  false,
                                  short_position))
         return false;
      g_str021_last_processed_bar = closed_bar.time;
     }

   Strategy021_ReconcileExposure(long_position,
                                 short_position,
                                 any_exposure);
   if(any_exposure)
      return false;

   const bool long_ready =
      (g_str021_long.st == STR021_CONFIRMED_PENDING &&
       g_str021_long.ticket == 0);
   const bool short_ready =
      (g_str021_short.st == STR021_CONFIRMED_PENDING &&
       g_str021_short.ticket == 0);
   if(long_ready && short_ready)
     {
      if(g_str021_last_dual_log_bar != closed_bar.time)
        {
         g_str021_last_dual_log_bar = closed_bar.time;
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-021\",\"reason\":\"simultaneous_sides_no_source_precedence\",\"bar_time\":%I64d}",
               (long)closed_bar.time));
        }
      return false;
     }
   if(!long_ready && !short_ready)
      return false;

   const bool long_side = long_ready;
   if(!Strategy021_BuildPendingRequest(long_side, req))
     {
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-021\",\"side\":\"%s\",\"reason\":\"stops_level_or_pending_geometry\"}",
            long_side ? "LONG" : "SHORT"));
      if(long_side)
         Strategy021_ResetSide(g_str021_long,
                               g_str021_long_sweep_time,
                               STR021_SWEPT);
      else
         Strategy021_ResetSide(g_str021_short,
                               g_str021_short_sweep_time,
                               STR021_SWEPT);
      return false;
     }
   return true;
  }

// Retry pacing for the deferred-TP attach: a broker-rejected TP modify is
// retried at most once per M15 bar instead of every tick (653,089 rejected
// wrong-side requests in the 2024 XAUUSD smoke 20260724_123426 before this fix).
datetime g_str021_tp_retry_wait_bar = 0;

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   const datetime cur_bar = iTime(_Symbol, PERIOD_M15, 0); // perf-allowed: O(1) retry-pacing key (TP-storm fix 2026-07-24)
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetDouble(POSITION_TP) > 0.0)
         continue;

      const double fill =
         PositionGetDouble(POSITION_PRICE_OPEN);
      const double stop =
         PositionGetDouble(POSITION_SL);
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(fill <= 0.0 || stop <= 0.0)
        {
         Strategy021_LogDataMissing("filled_position_sl");
         continue;
        }
      const QM_OrderType side =
         (position_type == POSITION_TYPE_BUY)
         ? QM_BUY
         : QM_SELL;
      const double target =
         QM_TakeRR(_Symbol,
                   side,
                   fill,
                   stop,
                   strategy_rr_ratio);
      if(target <= 0.0)
        {
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-021\",\"ticket\":%I64u,\"reason\":\"fill_rr_target\",\"fill\":%.8f,\"sl\":%.8f}",
               ticket,
               fill,
               stop));
         continue;
        }
      QM_TM_MoveTP(ticket,
                   target,
                   "STR021_ACTUAL_FILL_2R");
     }
  }

bool Strategy_ExitSignal()
  {
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
                        qm_news_mode_legacy,           // legacy back-compat
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,                            // pause-before (legacy hint)
                        30,                            // pause-after (legacy hint)
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,              // FW1 Axis A
                        qm_news_compliance))           // FW1 Axis B
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
