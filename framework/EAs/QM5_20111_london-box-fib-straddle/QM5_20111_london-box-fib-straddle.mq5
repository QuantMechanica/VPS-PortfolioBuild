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
input int    qm_ea_id                   = 20111;
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
input int    strategy_box_start_utc_hour = 3;
input int    strategy_box_end_utc_hour   = 6;
input double strategy_entry_ext_pct      = 32.6;
input double strategy_max_box_pips       = 40.0;

enum Strategy035_Phase
  {
   STR035_UNARMED = 0,
   STR035_BUY_SUBMITTED = 1,
   STR035_SELL_READY = 2,
   STR035_SELL_SUBMITTED = 3,
   STR035_DONE = 4,
   STR035_BLOCKED = 5
  };

Strategy035_Phase g_str035_phase = STR035_UNARMED;
datetime g_str035_cycle_start_utc = 0;
datetime g_str035_last_entry_bar = 0;
datetime g_str035_last_manage_bar = 0;
datetime g_str035_last_data_log_bar = 0;
double   g_str035_box_high = 0.0;
double   g_str035_box_low = 0.0;
double   g_str035_box_range = 0.0;
double   g_str035_buy_entry = 0.0;
double   g_str035_sell_entry = 0.0;
double   g_str035_buy_sl = 0.0;
double   g_str035_sell_sl = 0.0;
double   g_str035_buy_tp = 0.0;
double   g_str035_sell_tp = 0.0;
datetime g_str035_levels_cycle = 0;
bool     g_str035_cycle_reconciled = false;
bool     g_str035_fill_seen = false;

bool Strategy035_ConfigValid()
  {
   return (strategy_box_start_utc_hour >= 0 &&
           strategy_box_start_utc_hour < 24 &&
           strategy_box_end_utc_hour > strategy_box_start_utc_hour &&
           strategy_box_end_utc_hour < 24 &&
           MathIsValidNumber(strategy_entry_ext_pct) &&
           strategy_entry_ext_pct > 0.0 &&
           MathIsValidNumber(strategy_max_box_pips) &&
           strategy_max_box_pips > 0.0);
  }

datetime Strategy035_UTCMidnight(const datetime utc_time)
  {
   if(utc_time <= 0)
      return 0;
   MqlDateTime parts;
   if(!TimeToStruct(utc_time, parts))
      return 0;
   parts.hour = 0;
   parts.min = 0;
   parts.sec = 0;
   return StructToTime(parts);
  }

datetime Strategy035_CycleStartUTC(const datetime utc_time)
  {
   const datetime midnight = Strategy035_UTCMidnight(utc_time);
   if(midnight <= 0)
      return 0;
   datetime cycle =
      midnight + strategy_box_start_utc_hour * 3600;
   if(utc_time < cycle)
      cycle -= 86400;
   return cycle;
  }

datetime Strategy035_CycleEndUTC()
  {
   if(g_str035_cycle_start_utc <= 0)
      return 0;
   return g_str035_cycle_start_utc +
          (strategy_box_end_utc_hour -
           strategy_box_start_utc_hour) * 3600;
  }

datetime Strategy035_NextCycleUTC()
  {
   return (g_str035_cycle_start_utc > 0)
          ? g_str035_cycle_start_utc + 86400
          : 0;
  }

void Strategy035_ClearCycleState()
  {
   g_str035_phase = STR035_UNARMED;
   g_str035_last_entry_bar = 0;
   g_str035_last_manage_bar = 0;
   g_str035_last_data_log_bar = 0;
   g_str035_box_high = 0.0;
   g_str035_box_low = 0.0;
   g_str035_box_range = 0.0;
   g_str035_buy_entry = 0.0;
   g_str035_sell_entry = 0.0;
   g_str035_buy_sl = 0.0;
   g_str035_sell_sl = 0.0;
   g_str035_buy_tp = 0.0;
   g_str035_sell_tp = 0.0;
   g_str035_levels_cycle = 0;
   g_str035_cycle_reconciled = false;
   g_str035_fill_seen = false;
  }

void Strategy035_SyncCycle(const datetime utc_time)
  {
   const datetime cycle_start =
      Strategy035_CycleStartUTC(utc_time);
   if(cycle_start <= 0 ||
      cycle_start == g_str035_cycle_start_utc)
      return;
   g_str035_cycle_start_utc = cycle_start;
   Strategy035_ClearCycleState();
  }

datetime Strategy035_CurrentM15Bar()
  {
   return (datetime)SeriesInfoInteger(_Symbol,
                                      PERIOD_M15,
                                      SERIES_LASTBAR_DATE);
  }

void Strategy035_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str035_last_data_log_bar)
      return;
   g_str035_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-035\",\"component\":\"%s\",\"bar_time\":%I64d,\"cycle_utc\":%I64d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         (long)g_str035_cycle_start_utc));
  }

void Strategy035_BlockCycle(const string reason,
                            const string detail)
  {
   if(g_str035_phase == STR035_BLOCKED)
      return;
   g_str035_phase = STR035_BLOCKED;
   g_str035_cycle_reconciled = true;
   QM_LogEvent(
      QM_WARN,
      "SETUP_CONFIG_INVALID",
      StringFormat(
         "{\"strategy\":\"STR-035\",\"reason\":\"%s\",\"detail\":\"%s\",\"cycle_utc\":%I64d}",
         QM_LoggerEscapeJson(reason),
         QM_LoggerEscapeJson(detail),
         (long)g_str035_cycle_start_utc));
  }

double Strategy035_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   return tick;
  }

double Strategy035_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy035_TradeTick();
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

double Strategy035_PipDistance()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

bool Strategy035_CancelOwnPending(const string reason)
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

bool Strategy035_HasOwnPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
         return true;
     }
   return false;
  }

void Strategy035_ApplyBoxReset(const datetime utc_now)
  {
   if(g_str035_cycle_start_utc <= 0)
      return;
   const datetime cycle_end = Strategy035_CycleEndUTC();
   const bool box_building =
      (utc_now >= g_str035_cycle_start_utc &&
       utc_now < cycle_end);
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
      const datetime setup_utc =
         QM_BrokerToUTC(
            (datetime)OrderGetInteger(ORDER_TIME_SETUP));
      if(box_building ||
         setup_utc < g_str035_cycle_start_utc)
         QM_TM_RemovePendingOrder(ticket, "box_reset");
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const datetime opened_utc =
         QM_BrokerToUTC(
            (datetime)PositionGetInteger(POSITION_TIME));
      if(!box_building &&
         opened_utc >= g_str035_cycle_start_utc)
         continue;
      QM_LogEvent(
         QM_INFO,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-035\",\"ticket\":%I64u,\"reason\":\"box_reset\",\"cycle_utc\":%I64d}",
            ticket,
            (long)g_str035_cycle_start_utc));
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy035_LoadBox()
  {
   g_str035_box_high = 0.0;
   g_str035_box_low = 0.0;
   g_str035_box_range = 0.0;
   if(g_str035_cycle_start_utc <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied =
      CopyRates(_Symbol, // perf-allowed: bounded once-per-cycle UTC box reconstruction (integration review 2026-07-24)
                PERIOD_M15,
                1,
                128,
                rates);
   if(copied <= 0)
      return false;

   bool seen[12];
   ArrayInitialize(seen, false);
   int included = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime bar_utc =
         QM_BrokerToUTC(rates[i].time);
      const long elapsed =
         (long)(bar_utc - g_str035_cycle_start_utc);
      if(elapsed < 0 || elapsed >= 3 * 3600)
         continue;
      if(elapsed % 900 != 0)
         return false;
      const int slot = (int)(elapsed / 900);
      if(slot < 0 || slot >= 12 || seen[slot])
         return false;
      if(rates[i].high <= 0.0 ||
         rates[i].low <= 0.0 ||
         rates[i].high < rates[i].low)
         return false;
      seen[slot] = true;
      if(included == 0)
        {
         g_str035_box_high = rates[i].high;
         g_str035_box_low = rates[i].low;
        }
      else
        {
         g_str035_box_high =
            MathMax(g_str035_box_high, rates[i].high);
         g_str035_box_low =
            MathMin(g_str035_box_low, rates[i].low);
        }
      included++;
     }

   if(included != 12)
      return false;
   for(int i = 0; i < 12; ++i)
      if(!seen[i])
         return false;

   g_str035_box_range =
      g_str035_box_high - g_str035_box_low;
   return (g_str035_box_low > 0.0 &&
           g_str035_box_range > 0.0);
  }

bool Strategy035_EnsureLevels(const datetime bar_time)
  {
   if(g_str035_levels_cycle == g_str035_cycle_start_utc &&
      g_str035_buy_entry > g_str035_sell_entry &&
      g_str035_box_range > 0.0)
      return true;

   if(!Strategy035_LoadBox())
     {
      Strategy035_LogDataMissing("complete_utc_m15_box",
                                 bar_time);
      Strategy035_BlockCycle("box_data_missing",
                             "expected_12_closed_m15_bars");
      return false;
     }

   const double pip = Strategy035_PipDistance();
   if(pip <= 0.0)
     {
      Strategy035_LogDataMissing("pip_metadata",
                                 bar_time);
      Strategy035_BlockCycle("symbol_metadata",
                             "pip_distance_unavailable");
      return false;
     }
   const double box_pips = g_str035_box_range / pip;
   if(box_pips > strategy_max_box_pips + 1e-9)
     {
      Strategy035_BlockCycle(
         "box_too_big",
         StringFormat("box_pips=%.4f cap=%.4f",
                      box_pips,
                      strategy_max_box_pips));
      return false;
     }

   const double offset =
      (strategy_entry_ext_pct / 100.0) *
      g_str035_box_range;
   g_str035_buy_entry =
      Strategy035_AlignPrice(g_str035_box_high + offset,
                             1);
   g_str035_sell_entry =
      Strategy035_AlignPrice(g_str035_box_low - offset,
                             -1);
   g_str035_buy_sl =
      Strategy035_AlignPrice(g_str035_box_low, -1);
   g_str035_sell_sl =
      Strategy035_AlignPrice(g_str035_box_high, 1);
   g_str035_buy_tp =
      Strategy035_AlignPrice(
         g_str035_buy_entry + g_str035_box_range,
         1);
   g_str035_sell_tp =
      Strategy035_AlignPrice(
         g_str035_sell_entry - g_str035_box_range,
         -1);

   if(g_str035_buy_entry <= g_str035_box_high ||
      g_str035_sell_entry >= g_str035_box_low ||
      g_str035_buy_sl >= g_str035_buy_entry ||
      g_str035_sell_sl <= g_str035_sell_entry ||
      g_str035_buy_tp <= g_str035_buy_entry ||
      g_str035_sell_tp >= g_str035_sell_entry)
     {
      Strategy035_BlockCycle("level_geometry",
                             "normalized_levels_invalid");
      return false;
     }

   g_str035_levels_cycle = g_str035_cycle_start_utc;
   return true;
  }

bool Strategy035_PendingLegal(const QM_OrderType side,
                              const double entry,
                              const double sl,
                              const double tp,
                              const double bid,
                              const double ask)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy035_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 || tp <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid)
      return false;
   const long stops_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freeze_level =
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
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

bool Strategy035_StraddleLegal()
  {
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask >= g_str035_buy_entry ||
      bid <= g_str035_sell_entry)
      return false;
   return (Strategy035_PendingLegal(
              QM_BUY_STOP,
              g_str035_buy_entry,
              g_str035_buy_sl,
              g_str035_buy_tp,
              bid,
              ask) &&
           Strategy035_PendingLegal(
              QM_SELL_STOP,
              g_str035_sell_entry,
              g_str035_sell_sl,
              g_str035_sell_tp,
              bid,
              ask));
  }

bool Strategy035_TimeInCycle(const datetime broker_time)
  {
   const datetime order_utc =
      QM_BrokerToUTC(broker_time);
   return (order_utc >= Strategy035_CycleEndUTC() &&
           order_utc < Strategy035_NextCycleUTC());
  }

bool Strategy035_ScanCycle(bool &buy_submitted,
                           bool &sell_submitted,
                           bool &buy_pending,
                           bool &fill_seen)
  {
   buy_submitted = false;
   sell_submitted = false;
   buy_pending = false;
   fill_seen = false;
   if(g_str035_cycle_start_utc <= 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol ||
         !Strategy035_TimeInCycle(
            (datetime)OrderGetInteger(ORDER_TIME_SETUP)))
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP)
        {
         buy_submitted = true;
         buy_pending = true;
        }
      else if(order_type == ORDER_TYPE_SELL_STOP)
         sell_submitted = true;
     }

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic &&
         PositionGetString(POSITION_SYMBOL) == _Symbol &&
         Strategy035_TimeInCycle(
            (datetime)PositionGetInteger(POSITION_TIME)))
         fill_seen = true;
     }

   const datetime history_from =
      QM_UTCToBroker(g_str035_cycle_start_utc);
   if(!HistorySelect(history_from, TimeCurrent()))
      return false;

   const int history_orders = HistoryOrdersTotal();
   for(int i = 0; i < history_orders; ++i)
     {
      const ulong ticket = HistoryOrderGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryOrderGetInteger(ticket,
                                     ORDER_MAGIC) != magic ||
         HistoryOrderGetString(ticket,
                               ORDER_SYMBOL) != _Symbol ||
         !Strategy035_TimeInCycle(
            (datetime)HistoryOrderGetInteger(
               ticket,
               ORDER_TIME_SETUP)))
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)HistoryOrderGetInteger(
            ticket,
            ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP)
         buy_submitted = true;
      else if(order_type == ORDER_TYPE_SELL_STOP)
         sell_submitted = true;
     }

   const int history_deals = HistoryDealsTotal();
   for(int i = 0; i < history_deals; ++i)
     {
      const ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0 ||
         (int)HistoryDealGetInteger(ticket,
                                    DEAL_MAGIC) != magic ||
         HistoryDealGetString(ticket,
                              DEAL_SYMBOL) != _Symbol ||
         !Strategy035_TimeInCycle(
            (datetime)HistoryDealGetInteger(
               ticket,
               DEAL_TIME)))
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            ticket,
            DEAL_ENTRY);
      if(entry_kind == DEAL_ENTRY_IN ||
         entry_kind == DEAL_ENTRY_INOUT)
        {
         fill_seen = true;
         break;
        }
     }
   return true;
  }

bool Strategy035_ReconcileCycle()
  {
   const Strategy035_Phase prior_phase =
      g_str035_phase;
   bool buy_submitted = false;
   bool sell_submitted = false;
   bool buy_pending = false;
   bool fill_seen = false;
   if(!Strategy035_ScanCycle(buy_submitted,
                             sell_submitted,
                             buy_pending,
                             fill_seen))
     {
      Strategy035_LogDataMissing("cycle_order_history",
                                 g_str035_last_entry_bar);
      return false;
     }

   g_str035_fill_seen = fill_seen;
   if(fill_seen)
      g_str035_phase = STR035_DONE;
   else if(buy_submitted && sell_submitted)
      g_str035_phase = STR035_DONE;
   else if(buy_submitted)
     {
      if(buy_pending)
         g_str035_phase = STR035_SELL_READY;
      else
         Strategy035_BlockCycle(
            "straddle_invalid",
            "buy_leg_not_pending_before_sell_leg");
     }
   else if(sell_submitted)
      Strategy035_BlockCycle(
         "straddle_invalid",
         "sell_leg_without_buy_leg");
   else if(prior_phase == STR035_BUY_SUBMITTED ||
           prior_phase == STR035_SELL_SUBMITTED)
      Strategy035_BlockCycle(
         "straddle_invalid",
         "submitted_leg_not_observed");
   else
      g_str035_phase = STR035_UNARMED;

   g_str035_cycle_reconciled = true;
   return true;
  }

bool Strategy035_BuildRequest(const bool buy_side,
                              const int expiration_seconds,
                              QM_EntryRequest &req)
  {
   if(expiration_seconds <= 0)
      return false;
   ZeroMemory(req);
   req.type =
      buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   req.price =
      buy_side ? g_str035_buy_entry
               : g_str035_sell_entry;
   req.sl =
      buy_side ? g_str035_buy_sl
               : g_str035_sell_sl;
   req.tp =
      buy_side ? g_str035_buy_tp
               : g_str035_sell_tp;
   req.reason =
      StringFormat(buy_side
                   ? "STR035_B_%I64d"
                   : "STR035_S_%I64d",
                   (long)g_str035_cycle_start_utc);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = expiration_seconds;
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_M15 ||
      !Strategy035_ConfigValid())
      return true;
   const ENUM_SYMBOL_TRADE_MODE trade_mode =
      (ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_M15,
                        SERIES_BARS_COUNT);
   return (bars_available < 128);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime forming_broker =
      Strategy035_CurrentM15Bar();
   if(forming_broker <= 0)
     {
      Strategy035_LogDataMissing("forming_m15_time", 0);
      return false;
     }
   const datetime forming_utc =
      QM_BrokerToUTC(forming_broker);
   Strategy035_SyncCycle(forming_utc);
   if(forming_broker == g_str035_last_entry_bar)
      return false;
   g_str035_last_entry_bar = forming_broker;

   const datetime cycle_end =
      Strategy035_CycleEndUTC();
   const datetime next_cycle =
      Strategy035_NextCycleUTC();
   if(forming_utc < cycle_end ||
      forming_utc >= next_cycle)
      return false;
   if(Strategy035_HasOwnPosition())
      return false;

   if(!g_str035_cycle_reconciled &&
      !Strategy035_ReconcileCycle())
      return false;
   if(g_str035_fill_seen)
     {
      Strategy035_CancelOwnPending("opposite_fill");
      return false;
     }
   if(g_str035_phase == STR035_DONE ||
      g_str035_phase == STR035_BLOCKED ||
      g_str035_phase == STR035_BUY_SUBMITTED ||
      g_str035_phase == STR035_SELL_SUBMITTED)
      return false;
   if(!Strategy035_EnsureLevels(forming_broker))
      return false;

   const datetime utc_now =
      QM_BrokerToUTC(TimeCurrent());
   const int expiration_seconds =
      (int)(next_cycle - utc_now);
   if(expiration_seconds <= 0)
      return false;

   bool buy_side = false;
   if(g_str035_phase == STR035_UNARMED)
     {
      if(!Strategy035_StraddleLegal())
        {
         Strategy035_BlockCycle(
            "straddle_invalid",
            "initial_quotes_or_pending_geometry");
         return false;
        }
      buy_side = true;
     }
   else if(g_str035_phase == STR035_SELL_READY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask =
         SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(!Strategy035_PendingLegal(
            QM_SELL_STOP,
            g_str035_sell_entry,
            g_str035_sell_sl,
            g_str035_sell_tp,
            bid,
            ask))
        {
         Strategy035_BlockCycle(
            "straddle_invalid",
            "second_leg_quotes_or_geometry");
         Strategy035_CancelOwnPending("straddle_invalid");
         return false;
        }
      buy_side = false;
     }
   else
      return false;

   if(!Strategy035_BuildRequest(buy_side,
                                expiration_seconds,
                                req))
      return false;
   g_str035_phase =
      buy_side ? STR035_BUY_SUBMITTED
               : STR035_SELL_SUBMITTED;
   g_str035_cycle_reconciled = false;

   QM_LogEvent(
      QM_INFO,
      "STRATEGY_ENTRY",
      StringFormat(
         "{\"strategy\":\"STR-035\",\"phase\":\"%s\",\"cycle_utc\":%I64d,\"box_high\":%.8f,\"box_low\":%.8f,\"entry\":%.8f,\"sl\":%.8f,\"tp\":%.8f,\"expiry_seconds\":%d}",
         QM_LoggerEscapeJson(
            buy_side ? "BUYSTOP" : "SELLSTOP"),
         (long)g_str035_cycle_start_utc,
         g_str035_box_high,
         g_str035_box_low,
         req.price,
         req.sl,
         req.tp,
         req.expiration_seconds));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const datetime broker_now = TimeCurrent();
   const datetime utc_now =
      QM_BrokerToUTC(broker_now);
   Strategy035_SyncCycle(utc_now);
   if(g_str035_cycle_start_utc <= 0)
      return;

   Strategy035_ApplyBoxReset(utc_now);

   if(Strategy035_HasOwnPosition())
     {
      g_str035_fill_seen = true;
      g_str035_phase = STR035_DONE;
      Strategy035_CancelOwnPending("opposite_fill");
     }

   const datetime forming_bar =
      Strategy035_CurrentM15Bar();
   if(forming_bar <= 0 ||
      forming_bar == g_str035_last_manage_bar)
      return;
   g_str035_last_manage_bar = forming_bar;

   if(utc_now >= Strategy035_CycleEndUTC() &&
      utc_now < Strategy035_NextCycleUTC() &&
      Strategy035_ReconcileCycle() &&
      g_str035_fill_seen)
      Strategy035_CancelOwnPending("opposite_fill");
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
