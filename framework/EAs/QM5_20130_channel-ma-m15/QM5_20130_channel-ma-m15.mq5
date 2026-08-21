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
input int    qm_ea_id                   = 20130;
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
input int    strategy_ch_period  = 55;
input int    strategy_sig_period = 33;
input double strategy_delay_pips = 40.0;
input double strategy_sl_pips    = 40.0; // source range 40-50

int      g_str079_upper_handle = INVALID_HANDLE;
int      g_str079_lower_handle = INVALID_HANDLE;
int      g_str079_signal_handle = INVALID_HANDLE;
datetime g_str079_state_eval_bar = 0;
datetime g_str079_signal_source_bar = 0;
datetime g_str079_last_entry_eval_bar = 0;
datetime g_str079_last_refresh_bar = 0;
datetime g_str079_last_cancel_attempt_bar = 0;
datetime g_str079_last_place_attempt_bar = 0;
datetime g_str079_last_exit_attempt_bar = 0;
datetime g_str079_last_data_log_bar = 0;
int      g_str079_signal_direction = 0;
int      g_str079_fresh_direction = 0;
double   g_str079_close_1 = 0.0;
double   g_str079_upper_1 = 0.0;
double   g_str079_lower_1 = 0.0;
double   g_str079_signal_1 = 0.0;
double   g_str079_signal_2 = 0.0;
double   g_str079_upper_2 = 0.0;
double   g_str079_lower_2 = 0.0;

bool     g_str079_workflow_ready = false;
bool     g_str079_workflow_delayed = false;
bool     g_str079_workflow_consumed = false;
int      g_str079_workflow_direction = 0;
datetime g_str079_workflow_eval_bar = 0;
datetime g_str079_workflow_source_bar = 0;
double   g_str079_workflow_distance_pips = 0.0;
bool     g_str079_pending_observed = false;
ulong    g_str079_pending_ticket = 0;

bool     g_str079_exit_latched = false;
ulong    g_str079_exit_position_id = 0;

bool Strategy079_ConfigValid()
  {
   return (strategy_ch_period > 1 &&
           strategy_sig_period > 1 &&
           strategy_ch_period >
              strategy_sig_period &&
           MathIsValidNumber(strategy_delay_pips) &&
           strategy_delay_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips >= 40.0 &&
           strategy_sl_pips <= 50.0);
  }

bool Strategy079_EnsureHandles()
  {
   if(g_str079_upper_handle == INVALID_HANDLE)
      g_str079_upper_handle =
         QM_IndMA(_Symbol,
                  PERIOD_M15,
                  strategy_ch_period,
                  MODE_EMA,
                  PRICE_HIGH);
   if(g_str079_lower_handle == INVALID_HANDLE)
      g_str079_lower_handle =
         QM_IndMA(_Symbol,
                  PERIOD_M15,
                  strategy_ch_period,
                  MODE_EMA,
                  PRICE_LOW);
   if(g_str079_signal_handle == INVALID_HANDLE)
      g_str079_signal_handle =
         QM_IndMA(_Symbol,
                  PERIOD_M15,
                  strategy_sig_period,
                  MODE_EMA,
                  PRICE_CLOSE);
   return (g_str079_upper_handle != INVALID_HANDLE &&
           g_str079_lower_handle != INVALID_HANDLE &&
           g_str079_signal_handle != INVALID_HANDLE);
  }

int Strategy079_WarmupBars()
  {
   int required = 60;
   if(strategy_ch_period + 5 > required)
      required = strategy_ch_period + 5;
   if(strategy_sig_period + 5 > required)
      required = strategy_sig_period + 5;
   return required;
  }

bool Strategy079_HandlesReady()
  {
   if(!Strategy079_EnsureHandles())
      return false;
   const int required = Strategy079_WarmupBars();
   return (QM_IndicatorWarmupReady(g_str079_upper_handle,
                                   0, 1, required, "STR-079_upper") &&
           QM_IndicatorWarmupReady(g_str079_lower_handle,
                                   0, 1, required, "STR-079_lower") &&
           QM_IndicatorWarmupReady(g_str079_signal_handle,
                                   0, 1, required, "STR-079_signal"));
  }

bool Strategy079_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_M15,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-M15 clock for signal, pending refresh, entry, exit, and retry guards
   return (bar_time > 0);
  }

void Strategy079_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str079_last_data_log_bar)
      return;
   g_str079_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-079\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

bool Strategy079_IndicatorValid(const double value)
  {
   return (MathIsValidNumber(value) &&
           value != EMPTY_VALUE &&
           value > 0.0);
  }

bool Strategy079_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      position_id =
         (ulong)PositionGetInteger(
            POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

bool Strategy079_FindOwnPending(
   ulong &ticket,
   ENUM_ORDER_TYPE &order_type,
   double &order_price,
   double &order_sl)
  {
   ticket = 0;
   order_type = ORDER_TYPE_BUY_LIMIT;
   order_price = 0.0;
   order_sl = 0.0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = OrderGetTicket(i);
      if(candidate == 0)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE candidate_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(
            ORDER_TYPE);
      if(candidate_type != ORDER_TYPE_BUY_LIMIT &&
         candidate_type != ORDER_TYPE_SELL_LIMIT)
         continue;
      ticket = candidate;
      order_type = candidate_type;
      order_price =
         OrderGetDouble(ORDER_PRICE_OPEN);
      order_sl = OrderGetDouble(ORDER_SL);
      return true;
     }
   return false;
  }

int Strategy079_PositionDirection(
   const ENUM_POSITION_TYPE position_type)
  {
   return (position_type == POSITION_TYPE_BUY)
          ? 1
          : -1;
  }

int Strategy079_PendingDirection(
   const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT)
          ? 1
          : -1;
  }

double Strategy079_PipSize()
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits =
      (int)SymbolInfoInteger(_Symbol,
                             SYMBOL_DIGITS);
   if(point <= 0.0)
      return 0.0;
   return ((digits == 3 || digits == 5)
           ? 10.0 * point
           : point);
  }

double Strategy079_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol,
                              SYMBOL_POINT);
   return tick;
  }

double Strategy079_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy079_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol,
                               units * tick);
  }

double Strategy079_BrokerMinimumDistance()
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy079_TradeTick();
   if(point <= 0.0 || tick <= 0.0)
      return 0.0;
   const long stops_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol,
                        SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level)
      ? stops_level
      : freeze_level;
   return MathMax(tick,
                  (double)broker_level * point);
  }

bool Strategy079_MarketStopLegal(
   const QM_OrderType side,
   const double sl)
  {
   const double tick = Strategy079_TradeTick();
   const double minimum =
      Strategy079_BrokerMinimumDistance();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(tick <= 0.0 || minimum <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      sl <= 0.0)
      return false;
   if(side == QM_BUY)
      return (sl < bid &&
              bid - sl + tick * 0.1 >= minimum);
   if(side == QM_SELL)
      return (sl > ask &&
              sl - ask + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy079_PendingGeometryLegal(
   const QM_OrderType side,
   const double entry,
   const double sl)
  {
   const double tick = Strategy079_TradeTick();
   const double minimum =
      Strategy079_BrokerMinimumDistance();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(tick <= 0.0 || minimum <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY_LIMIT)
      return (entry < ask &&
              ask - entry + tick * 0.1 >= minimum &&
              sl < entry &&
              entry - sl + tick * 0.1 >= minimum);
   if(side == QM_SELL_LIMIT)
      return (entry > bid &&
              entry - bid + tick * 0.1 >= minimum &&
              sl > entry &&
              sl - entry + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy079_OpenedSince(const datetime since_time)
  {
   if(since_time <= 0)
      return true;
   if(!HistorySelect(since_time, TimeCurrent()))
     {
      Strategy079_LogDataMissing(
         "same_bar_entry_history",
         since_time);
      return true;
     }
   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (int)HistoryDealGetInteger(deal,
                                    DEAL_MAGIC) != magic ||
         HistoryDealGetString(deal,
                              DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            deal,
            DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN ||
         entry_kind == DEAL_ENTRY_INOUT)
         return true;
     }
   return false;
  }

void Strategy079_StartWorkflow(
   const int direction,
   const datetime eval_bar,
   const datetime source_bar,
   const double distance_pips)
  {
   g_str079_workflow_ready = true;
   g_str079_workflow_delayed =
      (distance_pips > strategy_delay_pips);
   g_str079_workflow_consumed = false;
   g_str079_workflow_direction = direction;
   g_str079_workflow_eval_bar = eval_bar;
   g_str079_workflow_source_bar = source_bar;
   g_str079_workflow_distance_pips =
      distance_pips;
   g_str079_pending_observed = false;
   g_str079_pending_ticket = 0;
  }

void Strategy079_ConsumeWorkflow()
  {
   g_str079_workflow_ready = false;
   g_str079_workflow_consumed = true;
   g_str079_pending_observed = false;
   g_str079_pending_ticket = 0;
  }

bool Strategy079_UpdateSignalState(
   datetime &forming_time)
  {
   if(!Strategy079_CurrentBar(forming_time))
      return false;
   if(g_str079_state_eval_bar == forming_time)
      return true;
   if(!Strategy079_HandlesReady())
     {
      Strategy079_LogDataMissing(
         "signal_indicator_warmup",
         forming_time);
      return false;
     }

   MqlRates bar1;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_M15,
                  1,
                  bar1)) // perf-allowed: one closed-M15 close/time read behind the owned signal-state bar guard
     {
      Strategy079_LogDataMissing(
         "signal_closed_m15_bar",
         forming_time);
      return false;
     }
   g_str079_upper_1 =
      QM_IndicatorReadBuffer(g_str079_upper_handle,
                             0,
                             1);
   g_str079_lower_1 =
      QM_IndicatorReadBuffer(g_str079_lower_handle,
                             0,
                             1);
   g_str079_signal_1 =
      QM_IndicatorReadBuffer(g_str079_signal_handle,
                             0,
                             1);
   g_str079_upper_2 =
      QM_IndicatorReadBuffer(g_str079_upper_handle,
                             0,
                             2);
   g_str079_lower_2 =
      QM_IndicatorReadBuffer(g_str079_lower_handle,
                             0,
                             2);
   g_str079_signal_2 =
      QM_IndicatorReadBuffer(g_str079_signal_handle,
                             0,
                             2);
   if(bar1.time <= 0 ||
      !MathIsValidNumber(bar1.close) ||
      bar1.close <= 0.0 ||
      !Strategy079_IndicatorValid(g_str079_upper_1) ||
      !Strategy079_IndicatorValid(g_str079_lower_1) ||
      !Strategy079_IndicatorValid(g_str079_signal_1) ||
      !Strategy079_IndicatorValid(g_str079_upper_2) ||
      !Strategy079_IndicatorValid(g_str079_lower_2) ||
      !Strategy079_IndicatorValid(g_str079_signal_2) ||
      g_str079_upper_1 < g_str079_lower_1 ||
      g_str079_upper_2 < g_str079_lower_2)
     {
      Strategy079_LogDataMissing(
         "signal_closed_indicators",
         forming_time);
      return false;
     }
   g_str079_close_1 = bar1.close;
   g_str079_signal_source_bar = bar1.time;

   // Restore the active direction from durable terminal exposure before
   // interpreting a first post-restart cross. This never creates an entry.
   if(g_str079_signal_direction == 0)
     {
      ulong position_ticket = 0;
      ENUM_POSITION_TYPE position_type =
         POSITION_TYPE_BUY;
      ulong position_id = 0;
      if(Strategy079_FindOwnPosition(
            position_ticket,
            position_type,
            position_id))
         g_str079_signal_direction =
            Strategy079_PositionDirection(
               position_type);
      else
        {
         ulong pending_ticket = 0;
         ENUM_ORDER_TYPE pending_type =
            ORDER_TYPE_BUY_LIMIT;
         double pending_price = 0.0;
         double pending_sl = 0.0;
         if(Strategy079_FindOwnPending(
               pending_ticket,
               pending_type,
               pending_price,
               pending_sl))
            g_str079_signal_direction =
               Strategy079_PendingDirection(
                  pending_type);
        }
     }

   const bool long_cross =
      (g_str079_signal_1 > g_str079_upper_1 &&
       g_str079_signal_2 <= g_str079_upper_2);
   const bool short_cross =
      (g_str079_signal_1 < g_str079_lower_1 &&
       g_str079_signal_2 >= g_str079_lower_2);
   g_str079_fresh_direction = 0;
   int cross_direction = 0;
   if(long_cross)
      cross_direction = 1;
   else if(short_cross)
      cross_direction = -1;

   // The source's first-signal mode keeps a direction active until an
   // opposite cross. Same-kind reconfirmations neither stack nor replace an
   // in-flight delayed workflow.
   if(cross_direction != 0 &&
      cross_direction != g_str079_signal_direction)
     {
      const double pip = Strategy079_PipSize();
      if(pip <= 0.0)
        {
         Strategy079_LogDataMissing(
            "signal_pip_size",
            forming_time);
         return false;
        }
      const double channel_line =
         (cross_direction > 0)
         ? g_str079_upper_1
         : g_str079_lower_1;
      const double distance_pips =
         MathAbs(g_str079_close_1 -
                 channel_line) / pip;
      g_str079_signal_direction =
         cross_direction;
      g_str079_fresh_direction =
         cross_direction;
      Strategy079_StartWorkflow(
         cross_direction,
         forming_time,
         bar1.time,
         distance_pips);
     }
   else if(cross_direction != 0)
      g_str079_signal_direction =
         cross_direction;

   g_str079_state_eval_bar = forming_time;
   return true;
  }

bool Strategy079_BuildRequest(
   const int direction,
   const bool delayed,
   const double delayed_target,
   const datetime tag_bar,
   QM_EntryRequest &req,
   bool &gap_through)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   gap_through = false;

   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double pip = Strategy079_PipSize();
   const double tick = Strategy079_TradeTick();
   if((direction != 1 && direction != -1) ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      pip <= 0.0 || tick <= 0.0)
      return false;

   const bool long_signal = (direction > 0);
   double entry = long_signal ? ask : bid;
   if(delayed)
     {
      const double target =
         Strategy079_AlignPrice(
            delayed_target,
            long_signal ? -1 : 1);
      if(target <= 0.0)
         return false;
      gap_through =
         long_signal
         ? (ask <= target + tick * 0.1)
         : (bid >= target - tick * 0.1);
      if(!gap_through)
        {
         req.type =
            long_signal
            ? QM_BUY_LIMIT
            : QM_SELL_LIMIT;
         req.price = target;
         entry = target;
        }
      else
        {
         // A quote already through the refreshed EMA cannot be represented
         // by a valid limit. Execute at the available market price; never
         // assume a fill at the obsolete/gapped line.
         req.type =
            long_signal ? QM_BUY : QM_SELL;
         req.price = 0.0;
        }
     }
   else
     {
      req.type =
         long_signal ? QM_BUY : QM_SELL;
      req.price = 0.0;
     }

   req.sl =
      Strategy079_AlignPrice(
         long_signal
         ? entry - strategy_sl_pips * pip
         : entry + strategy_sl_pips * pip,
         long_signal ? -1 : 1);
   req.tp = 0.0;
   const bool geometry_ok =
      (req.type == QM_BUY_LIMIT ||
       req.type == QM_SELL_LIMIT)
      ? Strategy079_PendingGeometryLegal(
           req.type,
           req.price,
           req.sl)
      : Strategy079_MarketStopLegal(
           req.type,
           req.sl);
   if(!geometry_ok)
      return false;

   const string mode =
      delayed
      ? (gap_through ? "DG" : "DL")
      : "NM";
   req.reason =
      StringFormat(direction > 0
                   ? "STR079_L_%s_S%d_%I64d"
                   : "STR079_S_%s_S%d_%I64d",
                   mode,
                   qm_magic_slot_offset,
                   (long)tag_bar);
   return true;
  }

void Strategy079_LogRequestGeometry(
   const string phase,
   const int direction,
   const bool delayed,
   const double target,
   const datetime bar_time)
  {
   QM_LogEvent(
      QM_WARN,
       "SETUP_CONFIG_INVALID",
      StringFormat(
         "{\"strategy\":\"STR-079\",\"reason\":\"entry_or_pending_geometry\",\"phase\":\"%s\",\"dir\":\"%s\",\"mode\":\"%s\",\"bar_time\":%I64d,\"target\":%.8f,\"sl_pips\":%.2f}",
         QM_LoggerEscapeJson(phase),
         QM_LoggerEscapeJson(
            direction > 0 ? "LONG" : "SHORT"),
         QM_LoggerEscapeJson(
            delayed ? "DELAYED" : "NORMAL"),
         (long)bar_time,
         target,
         strategy_sl_pips));
  }

bool Strategy079_CancelPending(
   const ulong ticket,
   const string reason,
   const datetime forming_time)
  {
   if(ticket == 0 ||
      forming_time ==
      g_str079_last_cancel_attempt_bar)
      return false;
   g_str079_last_cancel_attempt_bar =
      forming_time;
   const bool ok =
      QM_TM_RemovePendingOrder(ticket,
                               reason);
   QM_LogEvent(
      ok ? QM_INFO : QM_WARN,
      ok ? "PENDING_CANCEL" : "PENDING_CANCEL_FAIL",
      StringFormat(
         "{\"strategy\":\"STR-079\",\"ticket\":%I64u,\"slot\":%d,\"reason\":\"%s\",\"bar_time\":%I64d}",
         ticket,
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(reason),
         (long)forming_time));
   if(ok)
     {
      g_str079_pending_observed = false;
      g_str079_pending_ticket = 0;
     }
   return ok;
  }

bool Strategy079_PlaceDelayedFromManage(
   const datetime forming_time,
   const double target,
   const string phase)
  {
   if(!g_str079_workflow_ready ||
      !g_str079_workflow_delayed ||
      g_str079_workflow_consumed ||
      g_str079_workflow_direction !=
         g_str079_signal_direction ||
      forming_time ==
         g_str079_last_place_attempt_bar)
      return false;
   g_str079_last_place_attempt_bar =
      forming_time;

   QM_EntryRequest req;
   bool gap_through = false;
   if(!Strategy079_BuildRequest(
         g_str079_workflow_direction,
         true,
         target,
         forming_time,
         req,
         gap_through))
     {
      Strategy079_LogRequestGeometry(
         phase,
         g_str079_workflow_direction,
         true,
         target,
         forming_time);
      return false;
     }

   ulong out_ticket = 0;
   const bool ok =
      QM_TM_OpenPosition(req, out_ticket);
   if(!ok)
      return false;

   if(gap_through)
     {
      Strategy079_ConsumeWorkflow();
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_ENTRY",
         StringFormat(
            "{\"strategy\":\"STR-079\",\"phase\":\"%s\",\"dir\":\"%s\",\"mode\":\"DELAYED_GAP_MARKET\",\"slot\":%d,\"bar_time\":%I64d,\"ema33\":%.8f,\"ticket\":%I64u,\"sl\":%.8f}",
            QM_LoggerEscapeJson(phase),
            QM_LoggerEscapeJson(
               g_str079_signal_direction > 0
               ? "LONG"
               : "SHORT"),
            qm_magic_slot_offset,
            (long)forming_time,
            target,
            out_ticket,
            req.sl));
     }
   else
     {
      g_str079_pending_observed = true;
      g_str079_pending_ticket = out_ticket;
      QM_LogEvent(
         QM_INFO,
         "PENDING_STATE_RESTORED",
         StringFormat(
            "{\"strategy\":\"STR-079\",\"phase\":\"%s\",\"dir\":\"%s\",\"slot\":%d,\"bar_time\":%I64d,\"ticket\":%I64u,\"ema33\":%.8f,\"sl\":%.8f}",
            QM_LoggerEscapeJson(phase),
            QM_LoggerEscapeJson(
               g_str079_signal_direction > 0
               ? "LONG"
               : "SHORT"),
            qm_magic_slot_offset,
            (long)forming_time,
            out_ticket,
            req.price,
            req.sl));
     }
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 ||
      !Strategy079_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M15,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) closed-M15 warmup gate shared by both registered slots
   if(bars_available < Strategy079_WarmupBars())
      return true;
   return !Strategy079_HandlesReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   datetime forming_time = 0;
   if(!Strategy079_UpdateSignalState(
         forming_time))
      return false;
   if(forming_time ==
      g_str079_last_entry_eval_bar)
      return false;
   g_str079_last_entry_eval_bar =
      forming_time;

   if(!g_str079_workflow_ready ||
      g_str079_workflow_consumed ||
      g_str079_workflow_direction == 0 ||
      g_str079_workflow_direction !=
         g_str079_signal_direction)
      return false;

   // Normal signals are next-bar market decisions and are never backfilled.
   // Delayed workflows remain eligible while their signal direction persists.
   if(!g_str079_workflow_delayed &&
      g_str079_workflow_eval_bar !=
         forming_time)
     {
      Strategy079_ConsumeWorkflow();
      return false;
     }

   ulong position_ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   if(Strategy079_FindOwnPosition(
         position_ticket,
         position_type,
         position_id))
      return false;
   ulong pending_ticket = 0;
   ENUM_ORDER_TYPE pending_type =
      ORDER_TYPE_BUY_LIMIT;
   double pending_price = 0.0;
   double pending_sl = 0.0;
   if(Strategy079_FindOwnPending(
         pending_ticket,
         pending_type,
         pending_price,
         pending_sl))
      return false;
   if(Strategy079_OpenedSince(forming_time))
     {
      Strategy079_ConsumeWorkflow();
      return false;
     }

   bool gap_through = false;
   const double target =
      g_str079_workflow_delayed
      ? g_str079_signal_1
      : 0.0;
   if(!Strategy079_BuildRequest(
         g_str079_workflow_direction,
         g_str079_workflow_delayed,
         target,
         g_str079_workflow_source_bar,
         req,
         gap_through))
     {
      Strategy079_LogRequestGeometry(
         "fresh_workflow",
         g_str079_workflow_direction,
         g_str079_workflow_delayed,
         target,
         forming_time);
      return false;
     }
   g_str079_last_place_attempt_bar =
      forming_time;

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-079\",\"dir\":\"%s\",\"mode\":\"%s\",\"slot\":%d,\"symbol\":\"%s\",\"source_bar\":%I64d,\"eval_bar\":%I64d,\"close\":%.8f,\"upper\":%.8f,\"lower\":%.8f,\"ema33\":%.8f,\"distance_pips\":%.4f,\"threshold_pips\":%.4f,\"request_type\":\"%s\",\"request_price\":%.8f,\"sl\":%.8f,\"gap_through\":%s}",
         QM_LoggerEscapeJson(
            g_str079_workflow_direction > 0
            ? "LONG"
            : "SHORT"),
         QM_LoggerEscapeJson(
            g_str079_workflow_delayed
            ? "DELAYED"
            : "NORMAL"),
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(_Symbol),
         (long)g_str079_workflow_source_bar,
         (long)forming_time,
         g_str079_close_1,
         g_str079_upper_1,
         g_str079_lower_1,
         g_str079_signal_1,
         g_str079_workflow_distance_pips,
         strategy_delay_pips,
         QM_LoggerEscapeJson(
            QM_OrderTypeToString(req.type)),
         req.price,
         req.sl,
         gap_through ? "true" : "false"));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy079_UpdateSignalState(
         forming_time))
     {
      Strategy079_LogDataMissing(
         "manage_signal_state",
         forming_time);
      return;
     }

   ulong position_ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   const bool has_position =
      Strategy079_FindOwnPosition(
         position_ticket,
         position_type,
         position_id);

   ulong pending_ticket = 0;
   ENUM_ORDER_TYPE pending_type =
      ORDER_TYPE_BUY_LIMIT;
   double pending_price = 0.0;
   double pending_sl = 0.0;
   const bool has_pending =
      Strategy079_FindOwnPending(
         pending_ticket,
         pending_type,
         pending_price,
         pending_sl);

   if(has_position)
     {
      // A fill consumes its first-signal workflow. Any surviving own limit is
      // incompatible with the one-position state machine and is cancelled.
      if(has_pending)
         Strategy079_CancelPending(
            pending_ticket,
            "position_fill_oco",
            forming_time);
      if(g_str079_workflow_ready &&
         Strategy079_PositionDirection(
            position_type) ==
         g_str079_workflow_direction)
         Strategy079_ConsumeWorkflow();
      return;
     }

   if(has_pending)
     {
      const int pending_direction =
         Strategy079_PendingDirection(
            pending_type);
      g_str079_pending_observed = true;
      g_str079_pending_ticket =
         pending_ticket;

      // Restart recovery adopts durable terminal state but does not create a
      // fresh trade. Its next closed-bar action is validation/refresh only.
      if(!g_str079_workflow_ready)
        {
         g_str079_workflow_ready = true;
         g_str079_workflow_delayed = true;
         g_str079_workflow_consumed = false;
         g_str079_workflow_direction =
            pending_direction;
         g_str079_workflow_eval_bar =
            forming_time;
         g_str079_workflow_source_bar = 0;
         g_str079_workflow_distance_pips =
            0.0;
        }

      // An opposite first signal invalidates the old delayed state. Cancel
      // before EntrySignal is allowed to process the new direction.
      if(pending_direction !=
            g_str079_signal_direction ||
         pending_direction !=
            g_str079_workflow_direction)
        {
         Strategy079_CancelPending(
            pending_ticket,
            "signal_invalidation",
            forming_time);
         return;
        }

      if(forming_time ==
         g_str079_last_refresh_bar)
         return;
      g_str079_last_refresh_bar =
         forming_time;

      const double refreshed_target =
         Strategy079_AlignPrice(
            g_str079_signal_1,
            pending_direction > 0
            ? -1
            : 1);
      const double tick =
         Strategy079_TradeTick();
      const double pip =
         Strategy079_PipSize();
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask =
         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(refreshed_target <= 0.0 ||
         tick <= 0.0 || pip <= 0.0 ||
         bid <= 0.0 || ask <= 0.0 ||
         ask < bid)
        {
         Strategy079_LogDataMissing(
            "pending_refresh_price",
            forming_time);
         return;
        }
      const double refreshed_sl =
         Strategy079_AlignPrice(
            pending_direction > 0
            ? refreshed_target -
               strategy_sl_pips * pip
            : refreshed_target +
               strategy_sl_pips * pip,
            pending_direction > 0
             ? -1
             : 1);

      // Re-check executable quotes even when the projected EMA price did not
      // move. A still-visible limit whose market has crossed the line is
      // removed first; only a confirmed removal may become a market request.
      const bool gap_through =
         (pending_direction > 0)
         ? (ask <= refreshed_target +
            tick * 0.1)
         : (bid >= refreshed_target -
            tick * 0.1);
      if(gap_through)
        {
         if(!Strategy079_CancelPending(
               pending_ticket,
               "ema33_gap_through",
               forming_time))
            return;
         Strategy079_PlaceDelayedFromManage(
            forming_time,
            refreshed_target,
            "closed_bar_gap");
         return;
        }

      // No broker churn when the per-bar projection is already exact.
      if(MathAbs(pending_price -
                 refreshed_target) <=
            tick * 0.5 &&
         MathAbs(pending_sl -
                 refreshed_sl) <=
            tick * 0.5)
         return;

      if(!Strategy079_CancelPending(
            pending_ticket,
            "closed_bar_ema33_refresh",
            forming_time))
         return;
      Strategy079_PlaceDelayedFromManage(
         forming_time,
         refreshed_target,
         "closed_bar_refresh");
      return;
     }

   if(g_str079_pending_observed)
     {
      // A previously observed order has left the order pool. Whether it
      // filled and then closed or was removed externally, the first-signal
      // workflow is consumed and must not be silently recreated.
      Strategy079_ConsumeWorkflow();
      return;
     }

   if(!g_str079_workflow_ready ||
      g_str079_workflow_consumed)
      return;

   if(!g_str079_workflow_delayed)
     {
      if(g_str079_workflow_eval_bar !=
         forming_time)
         Strategy079_ConsumeWorkflow();
      return;
     }

   // A fresh delayed workflow is returned through EntrySignal later in the
   // same canonical OnTick. A prior-bar placement rejection is retried once
   // on the next closed bar while the direction remains valid.
   if(g_str079_workflow_eval_bar ==
      forming_time)
      return;
   if(Strategy079_OpenedSince(
         g_str079_workflow_eval_bar))
     {
      Strategy079_ConsumeWorkflow();
      return;
     }
   Strategy079_PlaceDelayedFromManage(
      forming_time,
      g_str079_signal_1,
      "signal_valid_retry");
  }

bool Strategy_ExitSignal()
  {
   datetime forming_time = 0;
   if(!Strategy079_UpdateSignalState(
         forming_time))
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   ulong position_id = 0;
   if(!Strategy079_FindOwnPosition(
         ticket,
         position_type,
         position_id))
     {
      if(forming_time !=
         g_str079_last_exit_attempt_bar)
        {
         g_str079_exit_latched = false;
         g_str079_exit_position_id = 0;
         g_str079_last_exit_attempt_bar = 0;
        }
      return false;
     }

   if(position_id !=
      g_str079_exit_position_id)
     {
      g_str079_exit_position_id =
         position_id;
      g_str079_exit_latched = false;
      g_str079_last_exit_attempt_bar = 0;
     }

   const int held_direction =
      Strategy079_PositionDirection(
         position_type);
   const bool opposite_signal_active =
      (g_str079_signal_direction != 0 &&
       g_str079_signal_direction !=
          held_direction);
   if(!g_str079_exit_latched &&
      !opposite_signal_active)
      return false;

   if(g_str079_exit_latched &&
      forming_time ==
      g_str079_last_exit_attempt_bar)
      return false;

   const bool retry = g_str079_exit_latched;
   g_str079_exit_latched = true;
   g_str079_last_exit_attempt_bar =
      forming_time;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_EXIT",
      StringFormat(
         "{\"strategy\":\"STR-079\",\"ticket\":%I64u,\"slot\":%d,\"symbol\":\"%s\",\"reason\":\"%s\",\"held_dir\":\"%s\",\"signal_dir\":\"%s\",\"source_bar\":%I64d,\"eval_bar\":%I64d,\"workflow_mode\":\"%s\",\"distance_pips\":%.4f}",
         ticket,
         qm_magic_slot_offset,
         QM_LoggerEscapeJson(_Symbol),
         QM_LoggerEscapeJson(
            retry
            ? "opposite_signal_retry"
            : "opposite_signal"),
         QM_LoggerEscapeJson(
            held_direction > 0
            ? "LONG"
            : "SHORT"),
         QM_LoggerEscapeJson(
            g_str079_signal_direction > 0
            ? "LONG"
            : "SHORT"),
         (long)g_str079_signal_source_bar,
         (long)forming_time,
         QM_LoggerEscapeJson(
            g_str079_workflow_delayed
            ? "DELAYED"
            : "NORMAL"),
         g_str079_workflow_distance_pips));
   return true;
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
