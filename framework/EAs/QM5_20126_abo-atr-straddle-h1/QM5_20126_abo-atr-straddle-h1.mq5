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
input int    qm_ea_id                   = 20126;
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
input int    strategy_atr_period = 50;
input double strategy_bo_mult    = 3.0;
input double strategy_sl_mult    = 4.0;
input double strategy_tp_mult    = 20.0;
input double strategy_ts_mult    = 6.0;

enum Strategy072_Phase
  {
   STR072_IDLE = 0,
   STR072_BUY_PHASE = 1,
   STR072_SELL_PHASE = 2,
   STR072_DONE = 3,
   STR072_BLOCKED = 4
  };

int      g_str072_atr_handle = INVALID_HANDLE;
datetime g_str072_last_refresh_bar = 0;
datetime g_str072_refresh_ready_bar = 0;
datetime g_str072_last_entry_bar = 0;
datetime g_str072_last_data_log_bar = 0;
Strategy072_Phase g_str072_phase = STR072_IDLE;
bool     g_str072_abort_cleanup_latched = false;

bool Strategy072_ConfigValid()
  {
   return (strategy_atr_period > 1 &&
           MathIsValidNumber(strategy_bo_mult) &&
           strategy_bo_mult > 0.0 &&
           MathIsValidNumber(strategy_sl_mult) &&
           strategy_sl_mult > 0.0 &&
           MathIsValidNumber(strategy_tp_mult) &&
           strategy_tp_mult > 0.0 &&
           MathIsValidNumber(strategy_ts_mult) &&
           strategy_ts_mult > 0.0);
  }

bool Strategy072_EnsureHandle()
  {
   if(g_str072_atr_handle == INVALID_HANDLE)
      g_str072_atr_handle =
         QM_IndATR(_Symbol,
                   PERIOD_H1,
                   strategy_atr_period);
   return (g_str072_atr_handle != INVALID_HANDLE);
  }

bool Strategy072_HandleReady()
  {
   if(!Strategy072_EnsureHandle())
      return false;
   const int required =
      (strategy_atr_period + 2 > 60)
      ? strategy_atr_period + 2
      : 60;
   return QM_IndicatorWarmupReady(g_str072_atr_handle,
                                  0,
                                  1,
                                  required,
                                  "STR-072_atr");
  }

bool Strategy072_CurrentBarTime(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-H1 clock for refresh, entry, and expiry guards
   return (bar_time > 0);
  }

void Strategy072_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str072_last_data_log_bar)
      return;
   g_str072_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-072\",\"component\":\"%s\",\"bar_time\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time));
  }

double Strategy072_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy072_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy072_TradeTick();
   if(raw_price <= 0.0 || tick <= 0.0)
      return 0.0;
   const double scaled = raw_price / tick;
   double units = MathRound(scaled);
   if(direction < 0)
      units = MathFloor(scaled + 1e-9);
   else if(direction > 0)
      units = MathCeil(scaled - 1e-9);
   return QM_TM_NormalizePrice(_Symbol, units * tick);
  }

bool Strategy072_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) ==
            magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

bool Strategy072_HasOwnPending()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP ||
         order_type == ORDER_TYPE_SELL_STOP)
         return true;
     }
   return false;
  }

bool Strategy072_HasStalePending(
   const datetime forming_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      const datetime setup_time =
         (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time < forming_time)
         return true;
     }
   return false;
  }

bool Strategy072_CycleActivitySince(
   const datetime since_time)
  {
   if(since_time <= 0)
      return true;
   if(!HistorySelect(since_time, TimeCurrent()))
     {
      Strategy072_LogDataMissing(
         "same_bar_order_history",
         since_time);
      return true;
     }
   const int magic = QM_FrameworkMagic();
   const int order_total = HistoryOrdersTotal();
   for(int i = 0; i < order_total; ++i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryOrderGetInteger(ticket,
                                     ORDER_MAGIC) != magic ||
         HistoryOrderGetString(ticket,
                               ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(
            ticket,
            ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      const datetime setup_time =
         (datetime)HistoryOrderGetInteger(
            ticket,
            ORDER_TIME_SETUP);
      if(setup_time >= since_time)
         return true;
     }

   const int deal_total = HistoryDealsTotal();
   for(int i = 0; i < deal_total; ++i)
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

bool Strategy072_CancelOwnPending(
   const string reason,
   const bool stale_only,
   const datetime forming_time)
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
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type != ORDER_TYPE_BUY_STOP &&
         order_type != ORDER_TYPE_SELL_STOP)
         continue;
      if(stale_only)
        {
         const datetime setup_time =
            (datetime)OrderGetInteger(ORDER_TIME_SETUP);
         if(setup_time >= forming_time)
            continue;
        }
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok;
  }

bool Strategy072_PendingLegal(
   const QM_OrderType side,
   const double entry,
   const double sl,
   const double tp,
   const double bid,
   const double ask)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy072_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
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
   const double minimum =
      MathMax(tick, (double)broker_level * point);

   if(side == QM_BUY_STOP)
      return (entry > ask &&
              sl < entry &&
              tp > entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   if(side == QM_SELL_STOP)
      return (entry < bid &&
              sl > entry &&
              tp < entry &&
              bid - entry + tick * 0.1 >= minimum &&
              sl - entry + tick * 0.1 >= minimum &&
              entry - tp + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy072_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy072_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      candidate <= 0.0)
      return false;
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
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >=
                 minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >=
              minimum);
  }

bool Strategy072_BuildRequest(
   const bool buy_side,
   const datetime forming_time,
   const int expiration_seconds,
   const double entry,
   const double sl,
   const double tp,
   QM_EntryRequest &request)
  {
   if(forming_time <= 0 ||
      expiration_seconds <= 0 ||
      entry <= 0.0 ||
      sl <= 0.0 ||
      tp <= 0.0)
      return false;
   ZeroMemory(request);
   request.type =
      buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   request.price = entry;
   request.sl = sl;
   request.tp = tp;
   request.reason =
      StringFormat(buy_side
                   ? "STR072_B_%I64d"
                   : "STR072_S_%I64d",
                   (long)forming_time);
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds =
      expiration_seconds;
   return true;
  }

void Strategy072_RollbackPending(
   ulong &opened_tickets[],
   const int opened_count)
  {
   for(int i = opened_count - 1; i >= 0; --i)
      if(opened_tickets[i] > 0)
         QM_TM_RemovePendingOrder(
            opened_tickets[i],
            "straddle_abort");
   Strategy072_CancelOwnPending("straddle_abort",
                                false,
                                0);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H1 ||
      !Strategy072_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;

   // Pending lifecycle/OCO must still run while entry warmup is unavailable.
   if(Strategy072_HasOwnPosition() ||
      Strategy072_HasOwnPending())
      return false;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) warmup gate
   if(bars_available < 60)
      return true;
   return !Strategy072_HandleReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   MqlRates forming_bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_H1,
                  0,
                  forming_bar)) // perf-allowed: one immutable new-H1 open/time snapshot behind the owned entry guard
     {
      Strategy072_LogDataMissing("forming_h1_bar", 0);
      return false;
     }
   if(forming_bar.time <= 0 ||
      forming_bar.time == g_str072_last_entry_bar)
      return false;
   g_str072_last_entry_bar = forming_bar.time;

   // Manage runs earlier in canonical OnTick and must retire the prior cycle.
   if(g_str072_refresh_ready_bar != forming_bar.time ||
      Strategy072_HasOwnPosition() ||
      Strategy072_HasOwnPending() ||
      Strategy072_CycleActivitySince(
         forming_bar.time))
      return false;
   if(!Strategy072_HandleReady())
     {
      Strategy072_LogDataMissing("atr_warmup",
                                 forming_bar.time);
      return false;
     }

   const double atr =
      QM_IndicatorReadBuffer(g_str072_atr_handle,
                             0,
                             1);
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!MathIsValidNumber(atr) ||
      atr == EMPTY_VALUE ||
      atr <= 0.0 ||
      forming_bar.open <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
     {
      Strategy072_LogDataMissing(
         "atr_open_or_quotes",
         forming_bar.time);
      return false;
     }

   const double buy_entry =
      Strategy072_AlignPrice(
         forming_bar.open + strategy_bo_mult * atr,
         1);
   const double sell_entry =
      Strategy072_AlignPrice(
         forming_bar.open - strategy_bo_mult * atr,
         -1);
   const double buy_sl =
      Strategy072_AlignPrice(
         buy_entry - strategy_sl_mult * atr,
         -1);
   const double sell_sl =
      Strategy072_AlignPrice(
         sell_entry + strategy_sl_mult * atr,
         1);
   const double buy_tp =
      Strategy072_AlignPrice(
         buy_entry + strategy_tp_mult * atr,
         1);
   const double sell_tp =
      Strategy072_AlignPrice(
         sell_entry - strategy_tp_mult * atr,
         -1);

   const bool buy_gap =
      (buy_entry <= 0.0 || ask >= buy_entry);
   const bool sell_gap =
      (sell_entry <= 0.0 || bid <= sell_entry);
   const bool buy_enabled = !buy_gap;
   const bool sell_enabled = !sell_gap;
   if(!buy_enabled && !sell_enabled)
      return false;

   if((buy_enabled &&
       !Strategy072_PendingLegal(QM_BUY_STOP,
                                 buy_entry,
                                 buy_sl,
                                 buy_tp,
                                 bid,
                                 ask)) ||
      (sell_enabled &&
       !Strategy072_PendingLegal(QM_SELL_STOP,
                                 sell_entry,
                                 sell_sl,
                                 sell_tp,
                                 bid,
                                 ask)))
     {
      g_str072_phase = STR072_BLOCKED;
      QM_LogEvent(
         QM_WARN,
         "SETUP_CONFIG_INVALID",
         StringFormat(
            "{\"strategy\":\"STR-072\",\"reason\":\"pending_geometry\",\"bar_time\":%I64d,\"bar_open\":%.8f,\"atr\":%.8f,\"bid\":%.8f,\"ask\":%.8f,\"buy_entry\":%.8f,\"sell_entry\":%.8f}",
            (long)forming_bar.time,
            forming_bar.open,
            atr,
            bid,
            ask,
            buy_entry,
            sell_entry));
      return false;
     }

   const datetime next_bar =
      forming_bar.time + PeriodSeconds(PERIOD_H1);
   const int expiration_seconds =
      (int)(next_bar - TimeCurrent());
   if(expiration_seconds <= 0)
      return false;

   QM_EntryRequest buy_request;
   QM_EntryRequest sell_request;
   ZeroMemory(buy_request);
   ZeroMemory(sell_request);
   if((buy_enabled &&
       !Strategy072_BuildRequest(true,
                                 forming_bar.time,
                                 expiration_seconds,
                                 buy_entry,
                                 buy_sl,
                                 buy_tp,
                                 buy_request)) ||
      (sell_enabled &&
       !Strategy072_BuildRequest(false,
                                 forming_bar.time,
                                 expiration_seconds,
                                 sell_entry,
                                 sell_sl,
                                 sell_tp,
                                 sell_request)))
      return false;

   ulong opened_tickets[2] = {0, 0};
   int opened_count = 0;
   int planned_count = 0;
   if(buy_enabled)
      ++planned_count;
   if(sell_enabled)
      ++planned_count;

   if(buy_enabled)
     {
      g_str072_phase = STR072_BUY_PHASE;
      ulong ticket = 0;
      if(!QM_TM_OpenPosition(buy_request, ticket))
        {
         g_str072_phase = STR072_BLOCKED;
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-072\",\"reason\":\"pending_placement_failed\",\"phase\":\"BUY_STOP\",\"bar_time\":%I64d}",
               (long)forming_bar.time));
         return false;
        }
      opened_tickets[opened_count++] = ticket;
     }

   // A first stop may fill before the second request. That is a valid breakout:
   // immediately enforce OCO and do not manufacture another pending leg.
   if(Strategy072_HasOwnPosition())
     {
      Strategy072_CancelOwnPending("oco_fill",
                                   false,
                                   0);
      g_str072_phase = STR072_DONE;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_ENTRY",
         StringFormat(
            "{\"strategy\":\"STR-072\",\"bar_time\":%I64d,\"bar_open\":%.8f,\"atr\":%.8f,\"planned_legs\":%d,\"submitted_legs\":%d,\"fill_during_placement\":true}",
            (long)forming_bar.time,
            forming_bar.open,
            atr,
            planned_count,
            opened_count));
      return false;
     }

   if(sell_enabled)
     {
      g_str072_phase = STR072_SELL_PHASE;
      ulong ticket = 0;
      if(!QM_TM_OpenPosition(sell_request, ticket))
        {
         if(Strategy072_HasOwnPosition())
           {
            Strategy072_CancelOwnPending("oco_fill",
                                         false,
                                         0);
            g_str072_phase = STR072_DONE;
            return false;
           }
         Strategy072_RollbackPending(opened_tickets,
                                     opened_count);
         g_str072_abort_cleanup_latched =
            Strategy072_HasOwnPending();
         g_str072_phase = STR072_BLOCKED;
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-072\",\"reason\":\"straddle_partial_abort\",\"phase\":\"SELL_STOP\",\"bar_time\":%I64d,\"opened_before_failure\":%d}",
               (long)forming_bar.time,
               opened_count));
         return false;
        }
      opened_tickets[opened_count++] = ticket;
     }

   g_str072_phase = STR072_DONE;
   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-072\",\"bar_time\":%I64d,\"bar_open\":%.8f,\"atr\":%.8f,\"planned_legs\":%d,\"submitted_legs\":%d,\"buy_gap_skip\":%s,\"sell_gap_skip\":%s,\"buy_entry\":%.8f,\"sell_entry\":%.8f,\"expiry_seconds\":%d}",
         (long)forming_bar.time,
         forming_bar.open,
         atr,
         planned_count,
         opened_count,
         buy_gap ? "true" : "false",
         sell_gap ? "true" : "false",
         buy_entry,
         sell_entry,
         expiration_seconds));
   return false;
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy072_CurrentBarTime(forming_time))
     {
      Strategy072_LogDataMissing("manage_h1_clock", 0);
      return;
     }

   // A failed two-leg placement must not leave a live one-sided pending.
   // Removal is urgent and therefore retried on later ticks until flat.
   if(g_str072_abort_cleanup_latched)
     {
      if(Strategy072_HasOwnPosition())
        {
         Strategy072_CancelOwnPending("oco_fill",
                                      false,
                                      0);
         g_str072_abort_cleanup_latched = false;
        }
      else
        {
         Strategy072_CancelOwnPending("straddle_abort",
                                      false,
                                      0);
         if(Strategy072_HasOwnPending())
            return;
         g_str072_abort_cleanup_latched = false;
        }
     }

   // OCO is per tick: as soon as either stop becomes a position, remove every
   // surviving own stop before any new entry path can run.
   if(Strategy072_HasOwnPosition() &&
      Strategy072_HasOwnPending())
      Strategy072_CancelOwnPending("oco_fill",
                                   false,
                                   0);

   // The canonical skeleton invokes Manage before EntrySignal. Retire only
   // orders from earlier H1 bars; this preserves a current-cycle pair across
   // an EA restart instead of deleting and re-arming it mid-bar.
   if(forming_time != g_str072_last_refresh_bar)
     {
      g_str072_last_refresh_bar = forming_time;
      g_str072_refresh_ready_bar = 0;
      g_str072_phase = STR072_IDLE;
      Strategy072_CancelOwnPending("bar_refresh",
                                   true,
                                   forming_time);
      if(Strategy072_HasStalePending(forming_time))
        {
         g_str072_phase = STR072_BLOCKED;
         QM_LogEvent(
            QM_WARN,
            "SETUP_CONFIG_INVALID",
            StringFormat(
               "{\"strategy\":\"STR-072\",\"reason\":\"bar_refresh_pending_delete\",\"bar_time\":%I64d}",
               (long)forming_time));
        }
      else if(!Strategy072_HasOwnPosition() &&
              !Strategy072_HasOwnPending())
         g_str072_refresh_ready_bar = forming_time;
     }

   if(!Strategy072_HasOwnPosition() ||
      !Strategy072_HandleReady())
      return;
   const double atr =
      QM_IndicatorReadBuffer(g_str072_atr_handle,
                             0,
                             1);
   if(!MathIsValidNumber(atr) ||
      atr == EMPTY_VALUE ||
      atr <= 0.0)
     {
      Strategy072_LogDataMissing("trail_atr_closed_h1",
                                 forming_time);
      return;
     }

   const int magic = QM_FrameworkMagic();
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy072_TradeTick();
   if(point <= 0.0 || tick <= 0.0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      const double current_sl =
         PositionGetDouble(POSITION_SL);
      const double market =
         (position_type == POSITION_TYPE_BUY)
         ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(market <= 0.0)
         continue;
      const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy072_AlignPrice(
            position_type == POSITION_TYPE_BUY
            ? market - strategy_ts_mult * atr
            : market + strategy_ts_mult * atr,
            position_type == POSITION_TYPE_BUY ? -1 : 1));
      if(candidate <= 0.0)
         continue;

      // Ratchet only, with a literal one-point minimum improvement.
      if(position_type == POSITION_TYPE_BUY &&
         current_sl > 0.0 &&
         candidate < current_sl + point - tick * 0.1)
         continue;
      if(position_type == POSITION_TYPE_SELL &&
         current_sl > 0.0 &&
         candidate > current_sl - point + tick * 0.1)
         continue;
      if(!Strategy072_PositionStopLegal(position_type,
                                        candidate))
         continue;
      QM_TM_MoveSL(ticket,
                   candidate,
                   "STR072_ATR6_TRAIL");
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
