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
input int    qm_ea_id                   = 20107;
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
input int strategy_range_start_hhmm = 100;
input int strategy_range_end_hhmm   = 600;
input int strategy_cancel_hhmm      = 1300;
input int strategy_flat_hhmm        = 2000;

enum Strategy016_Phase
  {
   STR016_UNARMED = 0,
   STR016_BUY_SUBMITTED = 1,
   STR016_SELL_READY = 2,
   STR016_SELL_SUBMITTED = 3,
   STR016_DONE = 4,
   STR016_BLOCKED = 5
  };

Strategy016_Phase g_str016_phase = STR016_UNARMED;
datetime g_str016_day_start = 0;
datetime g_str016_last_entry_bar = 0;
datetime g_str016_last_trail_bar = 0;
datetime g_str016_last_data_log_bar = 0;
double   g_str016_range_high = 0.0;
double   g_str016_range_low = 0.0;
datetime g_str016_range_day = 0;
bool     g_str016_day_reconciled = false;

bool Strategy016_HHMMToMinutes(const int hhmm,
                               int &minutes)
  {
   minutes = -1;
   if(hhmm < 0 || hhmm >= 2400)
      return false;
   const int hour = hhmm / 100;
   const int minute = hhmm % 100;
   if(hour < 0 || hour > 23 ||
      minute < 0 || minute > 59)
      return false;
   minutes = hour * 60 + minute;
   return true;
  }

bool Strategy016_ConfigMinutes(int &range_start,
                               int &range_end,
                               int &cancel_at,
                               int &flat_at)
  {
   if(!Strategy016_HHMMToMinutes(strategy_range_start_hhmm,
                                 range_start) ||
      !Strategy016_HHMMToMinutes(strategy_range_end_hhmm,
                                 range_end) ||
      !Strategy016_HHMMToMinutes(strategy_cancel_hhmm,
                                 cancel_at) ||
      !Strategy016_HHMMToMinutes(strategy_flat_hhmm,
                                 flat_at))
      return false;
   return (range_start < range_end &&
           range_end < cancel_at &&
           cancel_at < flat_at);
  }

datetime Strategy016_DayStart(const datetime broker_time)
  {
   if(broker_time <= 0)
      return 0;
   MqlDateTime parts;
   if(!TimeToStruct(broker_time, parts))
      return 0;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   return StructToTime(parts);
  }

int Strategy016_MinuteOfDay(const datetime broker_time)
  {
   MqlDateTime parts;
   if(broker_time <= 0 ||
      !TimeToStruct(broker_time, parts))
      return -1;
   return parts.hour * 60 + parts.min;
  }

void Strategy016_SyncDay(const datetime broker_time)
  {
   const datetime day_start = Strategy016_DayStart(broker_time);
   if(day_start <= 0 || day_start == g_str016_day_start)
      return;
   g_str016_day_start = day_start;
   g_str016_phase = STR016_UNARMED;
   g_str016_last_entry_bar = 0;
   g_str016_last_trail_bar = 0;
   g_str016_last_data_log_bar = 0;
   g_str016_range_high = 0.0;
   g_str016_range_low = 0.0;
   g_str016_range_day = 0;
   g_str016_day_reconciled = false;
  }

void Strategy016_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str016_last_data_log_bar)
      return;
   g_str016_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-016\",\"component\":\"%s\",\"bar_time\":%I64d,\"day\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         (long)g_str016_day_start));
  }

double Strategy016_TradeTick()
  {
   double tick = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy016_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy016_TradeTick();
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

bool Strategy016_CancelOwnPending(const string reason)
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
      if(!QM_TM_RemovePendingOrder(ticket, reason))
         all_ok = false;
     }
   return all_ok;
  }

void Strategy016_BlockDate(const string detail)
  {
   if(g_str016_phase == STR016_BLOCKED)
      return;
   g_str016_phase = STR016_BLOCKED;
   g_str016_day_reconciled = true;
   QM_LogEvent(
      QM_WARN,
      "SETUP_CONFIG_INVALID",
      StringFormat(
         "{\"strategy\":\"STR-016\",\"reason\":\"straddle_invalid\",\"detail\":\"%s\",\"day\":%I64d}",
         QM_LoggerEscapeJson(detail),
         (long)g_str016_day_start));
  }

void Strategy016_MarkOrderSide(const ENUM_ORDER_TYPE order_type,
                               bool &buy_seen,
                               bool &sell_seen)
  {
   if(order_type == ORDER_TYPE_BUY_STOP)
      buy_seen = true;
   else if(order_type == ORDER_TYPE_SELL_STOP)
      sell_seen = true;
  }

void Strategy016_MarkPositionSide(
   const ENUM_POSITION_TYPE position_type,
   bool &buy_seen,
   bool &sell_seen)
  {
   if(position_type == POSITION_TYPE_BUY)
      buy_seen = true;
   else if(position_type == POSITION_TYPE_SELL)
      sell_seen = true;
  }

void Strategy016_MarkDealSide(const ENUM_DEAL_TYPE deal_type,
                              bool &buy_seen,
                              bool &sell_seen)
  {
   if(deal_type == DEAL_TYPE_BUY)
      buy_seen = true;
   else if(deal_type == DEAL_TYPE_SELL)
      sell_seen = true;
  }

bool Strategy016_ScanDaySides(bool &buy_seen,
                              bool &sell_seen)
  {
   buy_seen = false;
   sell_seen = false;
   if(g_str016_day_start <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const datetime setup_time =
         (datetime)OrderGetInteger(ORDER_TIME_SETUP);
      if(setup_time < g_str016_day_start)
         continue;
      Strategy016_MarkOrderSide(
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE),
         buy_seen,
         sell_seen);
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      if(position_time < g_str016_day_start)
         continue;
      Strategy016_MarkPositionSide(
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE),
         buy_seen,
         sell_seen);
     }

   if(!HistorySelect(g_str016_day_start, TimeCurrent()))
      return false;

   const int history_orders = HistoryOrdersTotal();
   for(int i = 0; i < history_orders; ++i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryOrderGetInteger(ticket, ORDER_MAGIC) != magic ||
         HistoryOrderGetString(ticket, ORDER_SYMBOL) != _Symbol)
         continue;
      const datetime setup_time =
         (datetime)HistoryOrderGetInteger(ticket, ORDER_TIME_SETUP);
      if(setup_time < g_str016_day_start)
         continue;
      Strategy016_MarkOrderSide(
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(ticket, ORDER_TYPE),
         buy_seen,
         sell_seen);
     }

   const int history_deals = HistoryDealsTotal();
   for(int i = 0; i < history_deals; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryDealGetInteger(ticket, DEAL_MAGIC) != magic ||
         HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;
      const datetime deal_time =
         (datetime)HistoryDealGetInteger(ticket, DEAL_TIME);
      if(deal_time < g_str016_day_start)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      Strategy016_MarkDealSide(
         (ENUM_DEAL_TYPE)HistoryDealGetInteger(ticket, DEAL_TYPE),
         buy_seen,
         sell_seen);
     }
   return true;
  }

bool Strategy016_ReconcileDayState()
  {
   const Strategy016_Phase prior_phase = g_str016_phase;
   bool buy_seen = false;
   bool sell_seen = false;
   if(!Strategy016_ScanDaySides(buy_seen, sell_seen))
     {
      Strategy016_LogDataMissing("day_order_history",
                                 g_str016_last_entry_bar);
      return false;
     }

   if(buy_seen && sell_seen)
      g_str016_phase = STR016_DONE;
   else if(buy_seen)
     {
      if(prior_phase == STR016_SELL_SUBMITTED)
        {
         Strategy016_BlockDate("sell_submission_not_observed");
         Strategy016_CancelOwnPending("straddle_invalid");
        }
      else
         g_str016_phase = STR016_SELL_READY;
     }
   else if(sell_seen)
     {
      Strategy016_BlockDate("sell_side_without_buy_side");
      Strategy016_CancelOwnPending("straddle_invalid");
     }
   else if(prior_phase == STR016_BUY_SUBMITTED)
      Strategy016_BlockDate("buy_submission_not_observed");
   else if(prior_phase == STR016_SELL_SUBMITTED)
      Strategy016_BlockDate("both_submissions_not_observed");
   else
      g_str016_phase = STR016_UNARMED;

   g_str016_day_reconciled = true;
   return true;
  }

bool Strategy016_LoadRange(const datetime day_start,
                           double &range_high,
                           double &range_low)
  {
   range_high = 0.0;
   range_low = 0.0;
   int range_start = 0;
   int range_end = 0;
   int cancel_at = 0;
   int flat_at = 0;
   if(day_start <= 0 ||
      !Strategy016_ConfigMinutes(range_start,
                                 range_end,
                                 cancel_at,
                                 flat_at))
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied =
      CopyRates(_Symbol, PERIOD_M15, 1, 96, rates); // perf-allowed: bounded once-per-arm broker-day range reconstruction
   if(copied <= 0)
      return false;

   const datetime range_from =
      day_start + range_start * 60;
   const datetime range_to =
      day_start + range_end * 60;
   int included = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(rates[i].time < range_from ||
         rates[i].time >= range_to)
         continue;
      if(rates[i].high <= 0.0 ||
         rates[i].low <= 0.0 ||
         rates[i].high < rates[i].low)
         return false;
      if(included == 0)
        {
         range_high = rates[i].high;
         range_low = rates[i].low;
        }
      else
        {
         range_high = MathMax(range_high, rates[i].high);
         range_low = MathMin(range_low, rates[i].low);
        }
      included++;
     }

   const int window_minutes = range_end - range_start;
   if(window_minutes > 0 && window_minutes % 15 == 0)
     {
      const int expected = window_minutes / 15;
      if(included != expected)
         return false;
     }
   if(included <= 0 || range_high <= range_low)
      return false;

   range_high = Strategy016_AlignPrice(range_high, 0);
   range_low = Strategy016_AlignPrice(range_low, 0);
   return (range_high > range_low && range_low > 0.0);
  }

bool Strategy016_EnsureRange(const datetime bar_time)
  {
   if(g_str016_range_day == g_str016_day_start &&
      g_str016_range_high > g_str016_range_low &&
      g_str016_range_low > 0.0)
      return true;
   if(!Strategy016_LoadRange(g_str016_day_start,
                             g_str016_range_high,
                             g_str016_range_low))
     {
      Strategy016_LogDataMissing("complete_m15_range",
                                 bar_time);
      g_str016_phase = STR016_BLOCKED;
      g_str016_day_reconciled = true;
      return false;
     }
   g_str016_range_day = g_str016_day_start;
   return true;
  }

bool Strategy016_PendingLegal(const QM_OrderType side,
                              const double entry,
                              const double sl,
                              const double bid,
                              const double ask)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy016_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;

   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level) ? stops_level : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);

   if(side == QM_BUY_STOP)
      return (entry > ask &&
              sl < entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum);
   if(side == QM_SELL_STOP)
      return (entry < bid &&
              sl > entry &&
              bid - entry + tick * 0.1 >= minimum &&
              sl - entry + tick * 0.1 >= minimum);
   return false;
  }

bool Strategy016_StraddleLegal()
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
   // Equality is already a boundary touch: never arm only the surviving leg.
   if(ask >= g_str016_range_high ||
      bid <= g_str016_range_low)
      return false;
   return (Strategy016_PendingLegal(QM_BUY_STOP,
                                    g_str016_range_high,
                                    g_str016_range_low,
                                    bid,
                                    ask) &&
           Strategy016_PendingLegal(QM_SELL_STOP,
                                    g_str016_range_low,
                                    g_str016_range_high,
                                    bid,
                                    ask));
  }

bool Strategy016_BuildRequest(const bool buy_side,
                              const int expiration_seconds,
                              QM_EntryRequest &req)
  {
   if(expiration_seconds <= 0)
      return false;
   ZeroMemory(req);
   req.type = buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   req.price =
      buy_side ? g_str016_range_high : g_str016_range_low;
   req.sl =
      buy_side ? g_str016_range_low : g_str016_range_high;
   req.tp = 0.0;
   req.reason =
      StringFormat(buy_side
                   ? "STR016_B_%I64d"
                   : "STR016_S_%I64d",
                   (long)g_str016_day_start);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   return true;
  }

bool Strategy016_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy016_TradeTick();
   if(point <= 0.0 || tick <= 0.0 || candidate <= 0.0)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const long broker_level =
      (stops_level > freeze_level) ? stops_level : freeze_level;
   const double minimum =
      MathMax(tick, (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy_NoTradeFilter()
  {
   int range_start = 0;
   int range_end = 0;
   int cancel_at = 0;
   int flat_at = 0;
   if(_Period != PERIOD_M15 ||
      !Strategy016_ConfigMinutes(range_start,
                                 range_end,
                                 cancel_at,
                                 flat_at))
      return true;

   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(_Symbol,
                                                SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol, PERIOD_M15, SERIES_BARS_COUNT);
   return (bars_available < 97);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime forming_time =
      (datetime)SeriesInfoInteger(_Symbol,
                                  PERIOD_M15,
                                  SERIES_LASTBAR_DATE);
   if(forming_time <= 0)
     {
      Strategy016_LogDataMissing("forming_m15_time", 0);
      return false;
     }
   Strategy016_SyncDay(forming_time);
   if(forming_time == g_str016_last_entry_bar)
      return false;
   g_str016_last_entry_bar = forming_time;

   int range_start = 0;
   int range_end = 0;
   int cancel_at = 0;
   int flat_at = 0;
   if(!Strategy016_ConfigMinutes(range_start,
                                 range_end,
                                 cancel_at,
                                 flat_at))
      return false;
   const int now_minute = Strategy016_MinuteOfDay(forming_time);
   if(now_minute < 0)
      return false;

   if(!g_str016_day_reconciled &&
      !Strategy016_ReconcileDayState())
      return false;
   if(g_str016_phase == STR016_DONE ||
      g_str016_phase == STR016_BLOCKED ||
      g_str016_phase == STR016_BUY_SUBMITTED ||
      g_str016_phase == STR016_SELL_SUBMITTED)
      return false;
   if(now_minute < range_end || now_minute >= cancel_at)
      return false;
   if(!Strategy016_EnsureRange(forming_time))
      return false;

   const datetime cancel_time =
      g_str016_day_start + cancel_at * 60;
   const int expiration_seconds =
      (int)(cancel_time - TimeCurrent());
   if(expiration_seconds <= 0)
      return false;

   bool buy_side = false;
   if(g_str016_phase == STR016_UNARMED)
     {
      if(!Strategy016_StraddleLegal())
        {
         Strategy016_BlockDate("initial_quotes_or_pending_geometry");
         return false;
        }
      buy_side = true;
     }
   else if(g_str016_phase == STR016_SELL_READY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(bid <= g_str016_range_low ||
         !Strategy016_PendingLegal(QM_SELL_STOP,
                                   g_str016_range_low,
                                   g_str016_range_high,
                                   bid,
                                   ask))
        {
         Strategy016_BlockDate("second_leg_quotes_or_geometry");
         Strategy016_CancelOwnPending("straddle_invalid");
         return false;
        }
      buy_side = false;
     }
   else
      return false;

   if(!Strategy016_BuildRequest(buy_side,
                                expiration_seconds,
                                req))
      return false;
   g_str016_phase =
      buy_side ? STR016_BUY_SUBMITTED
               : STR016_SELL_SUBMITTED;
   g_str016_day_reconciled = false;

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-016\",\"phase\":\"%s\",\"day\":%I64d,\"range_high\":%.8f,\"range_low\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"expiry_seconds\":%d}",
         QM_LoggerEscapeJson(buy_side ? "BUYSTOP" : "SELLSTOP"),
         (long)g_str016_day_start,
         g_str016_range_high,
         g_str016_range_low,
         req.price,
         req.sl,
         req.expiration_seconds));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime now = TimeCurrent();
   Strategy016_SyncDay(now);
   if(g_str016_day_start <= 0)
      return;

   int range_start = 0;
   int range_end = 0;
   int cancel_at = 0;
   int flat_at = 0;
   if(!Strategy016_ConfigMinutes(range_start,
                                 range_end,
                                 cancel_at,
                                 flat_at))
      return;
   const int now_minute = Strategy016_MinuteOfDay(now);
   if(now_minute < 0)
      return;

   if(!g_str016_day_reconciled &&
      (g_str016_phase == STR016_BUY_SUBMITTED ||
       g_str016_phase == STR016_SELL_SUBMITTED))
      Strategy016_ReconcileDayState();

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
      if(setup_time < g_str016_day_start)
         QM_TM_RemovePendingOrder(ticket, "day_roll");
      else if(now_minute >= cancel_at)
         QM_TM_RemovePendingOrder(ticket, "cancel_window");
     }

   if(now_minute >= flat_at)
     {
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
            PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         QM_LogEvent(
            QM_INFO,
            "STRATEGY_EXIT",
            StringFormat(
               "{\"strategy\":\"STR-016\",\"ticket\":%I64u,\"reason\":\"session_flat\",\"day\":%I64d}",
               ticket,
               (long)g_str016_day_start));
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   const datetime forming_time =
      (datetime)SeriesInfoInteger(_Symbol,
                                  PERIOD_M15,
                                  SERIES_LASTBAR_DATE);
   if(forming_time <= 0 ||
      forming_time == g_str016_last_trail_bar)
      return;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol, PERIOD_M15, 1, closed_bar))
     {
      Strategy016_LogDataMissing("trail_m15_bar",
                                 forming_time);
      return;
     }
   g_str016_last_trail_bar = forming_time;

   const double tick = Strategy016_TradeTick();
   if(tick <= 0.0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const ENUM_POSITION_TYPE position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double current_sl =
         PositionGetDouble(POSITION_SL);
      const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy016_AlignPrice(
            (position_type == POSITION_TYPE_BUY)
            ? closed_bar.low
            : closed_bar.high,
            (position_type == POSITION_TYPE_BUY) ? -1 : 1));
      if(candidate <= 0.0)
         continue;
      if(position_type == POSITION_TYPE_BUY &&
         current_sl > 0.0 &&
         candidate <= current_sl + tick * 0.1)
         continue;
      if(position_type == POSITION_TYPE_SELL &&
         current_sl > 0.0 &&
         candidate >= current_sl - tick * 0.1)
         continue;
      if(!Strategy016_PositionStopLegal(position_type,
                                        candidate))
         continue;
      QM_TM_MoveSL(ticket,
                   candidate,
                   "STR016_M15_EXTREME");
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
