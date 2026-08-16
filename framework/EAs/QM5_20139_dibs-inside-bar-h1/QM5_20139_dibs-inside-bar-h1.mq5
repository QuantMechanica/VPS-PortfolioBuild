#property strict
#property version   "5.0"
#property description "QM5_20139 dibs-inside-bar-h1 (V5)"

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
input int    qm_ea_id                   = 9999;
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
input int    strategy_open_utc_hour       = 6;
input int    strategy_window_hours        = 9;
input double strategy_break_buffer_pips   = 1.0;
input double strategy_partial_r           = 1.0;
input double strategy_partial_fraction    = 0.50;
input int    strategy_runner_ma_period    = 20;

int      g_str086_ma_handle = INVALID_HANDLE;
datetime g_str086_day_anchor_utc = 0;
double   g_str086_day_open = 0.0;
datetime g_str086_last_state_bar = 0;
datetime g_str086_last_place_attempt_bar = 0;
datetime g_str086_last_partial_attempt_bar = 0;
datetime g_str086_last_runner_attempt_bar = 0;
datetime g_str086_last_data_log_bar = 0;
datetime g_str086_last_oco_race_log_bar = 0;

ulong    g_str086_campaign_position_id = 0;
double   g_str086_original_volume = 0.0;
double   g_str086_initial_sl = 0.0;
bool     g_str086_campaign_facts_valid = false;
bool     g_str086_partial_resolved = false;
bool     g_str086_partial_executed = false;

bool Strategy086_ConfigValid()
  {
   return (strategy_open_utc_hour >= 0 &&
           strategy_open_utc_hour <= 23 &&
           strategy_window_hours > 0 &&
           strategy_window_hours <= 23 &&
           MathIsValidNumber(strategy_break_buffer_pips) &&
           strategy_break_buffer_pips > 0.0 &&
           MathIsValidNumber(strategy_partial_r) &&
           strategy_partial_r > 0.0 &&
           MathIsValidNumber(strategy_partial_fraction) &&
           strategy_partial_fraction > 0.0 &&
           strategy_partial_fraction < 1.0 &&
           strategy_runner_ma_period > 1);
  }

bool Strategy086_EnsureHandle()
  {
   if(g_str086_ma_handle == INVALID_HANDLE)
      g_str086_ma_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H1,
                  strategy_runner_ma_period,
                  MODE_SMA,
                  PRICE_CLOSE);
   return (g_str086_ma_handle != INVALID_HANDLE);
  }

int Strategy086_WarmupBars()
  {
   int required = 48;
   if(strategy_runner_ma_period + 5 > required)
      required = strategy_runner_ma_period + 5;
   return required;
  }

bool Strategy086_HandleReady()
  {
   if(!Strategy086_EnsureHandle())
      return false;
   return (BarsCalculated(g_str086_ma_handle) >=
           Strategy086_WarmupBars());
  }

bool Strategy086_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-H1 clock for day/setup/partial/runner retry guards
   return (bar_time > 0);
  }

void Strategy086_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str086_last_data_log_bar)
      return;
   g_str086_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-086\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

double Strategy086_PipSize()
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy086_TradeTick()
  {
   double tick =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_TRADE_TICK_SIZE);
   if(tick <= 0.0)
      tick =
         SymbolInfoDouble(_Symbol,
                          SYMBOL_POINT);
   return tick;
  }

double Strategy086_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy086_TradeTick();
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

datetime Strategy086_AnchorForUTC(
   const datetime utc_time)
  {
   if(utc_time <= 0)
      return 0;
   MqlDateTime parts;
   TimeToStruct(utc_time, parts);
   parts.hour = strategy_open_utc_hour;
   parts.min = 0;
   parts.sec = 0;
   datetime anchor = StructToTime(parts);
   if(utc_time < anchor)
      anchor -= 24 * 60 * 60;
   return anchor;
  }

bool Strategy086_LoadDayOpen(
   const datetime anchor_utc,
   double &day_open)
  {
   day_open = 0.0;
   if(anchor_utc <= 0)
      return false;
   MqlRates history[];
   ArraySetAsSeries(history, true);
   const int copied =
      CopyRates(_Symbol, PERIOD_H1, 1, 72, history); // perf-allowed: bounded closed-H1 recovery scan, once per UTC day/restart
   if(copied <= 0)
      return false;

   datetime first_utc = 0;
   for(int i = 0; i < copied; ++i)
     {
      const datetime utc_open =
         QM_BrokerToUTC(history[i].time);
      if(utc_open < anchor_utc ||
         utc_open >= anchor_utc + 24 * 60 * 60)
         continue;
      if(first_utc == 0 || utc_open < first_utc)
        {
         first_utc = utc_open;
         day_open = history[i].open;
        }
     }
   return (first_utc > 0 && day_open > 0.0);
  }

bool Strategy086_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   double &current_volume,
   datetime &position_time,
   ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
   current_volume = 0.0;
   position_time = 0;
   position_id = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ticket = candidate;
      position_type =
         (ENUM_POSITION_TYPE)PositionGetInteger(
            POSITION_TYPE);
      open_price =
         PositionGetDouble(POSITION_PRICE_OPEN);
      current_sl =
         PositionGetDouble(POSITION_SL);
      current_volume =
         PositionGetDouble(POSITION_VOLUME);
      position_time =
         (datetime)PositionGetInteger(POSITION_TIME);
      position_id =
         (ulong)PositionGetInteger(
            POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

int Strategy086_OwnPositionCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 ||
         !PositionSelectByTicket(ticket) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ++count;
     }
   return count;
  }

int Strategy086_OwnPendingCount()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE order_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(order_type == ORDER_TYPE_BUY_STOP ||
         order_type == ORDER_TYPE_SELL_STOP)
         ++count;
     }
   return count;
  }

bool Strategy086_CancelOwnPending(
   const string reason)
  {
   bool all_ok = true;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
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

bool Strategy086_EnforceSingleOwnPosition(
   const datetime forming_time)
  {
   const int magic = QM_FrameworkMagic();
   int own_count = 0;
   ulong keep_ticket = 0;
   long keep_time_msc = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long opened_msc =
         PositionGetInteger(POSITION_TIME_MSC);
      ++own_count;
      if(keep_ticket == 0 ||
         opened_msc < keep_time_msc ||
         (opened_msc == keep_time_msc &&
          candidate < keep_ticket))
        {
         keep_ticket = candidate;
         keep_time_msc = opened_msc;
        }
     }
   if(own_count <= 1)
      return true;

   // A hedging account can fill both OCO stops between management ticks.
   // Preserve the first fill and close every newer own position.
   Strategy086_CancelOwnPending("oco_double_fill");
   if(forming_time != g_str086_last_oco_race_log_bar)
     {
      g_str086_last_oco_race_log_bar = forming_time;
      QM_LogEvent(
         QM_WARN,
         "STRATEGY_EXIT",
         StringFormat(
            "{\"strategy\":\"STR-086\",\"reason\":\"oco_double_fill_cleanup\",\"bar_time\":%I64d,\"position_count\":%d,\"keep_ticket\":%I64u}",
            (long)forming_time,
            own_count,
            keep_ticket));
     }
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 ||
         candidate == keep_ticket ||
         !PositionSelectByTicket(candidate) ||
         (int)PositionGetInteger(POSITION_MAGIC) != magic ||
         PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      QM_TM_ClosePosition(candidate,
                          QM_EXIT_STRATEGY);
     }
   return false;
  }

bool Strategy086_PendingLegal(
   const bool buy_side,
   const double entry,
   const double sl,
   const double bid,
   const double ask)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy086_TradeTick();
   if(point <= 0.0 || tick <= 0.0 ||
      entry <= 0.0 || sl <= 0.0 ||
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
      MathMax(tick,
              (double)broker_level * point);
   if(buy_side)
      return (entry > ask &&
              sl < entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum);
   return (entry < bid &&
           sl > entry &&
           bid - entry + tick * 0.1 >= minimum &&
           sl - entry + tick * 0.1 >= minimum);
  }

bool Strategy086_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy086_TradeTick();
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
      MathMax(tick,
              (double)broker_level * point);
   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid =
         SymbolInfoDouble(_Symbol, SYMBOL_BID);
      return (bid > 0.0 &&
              candidate < bid &&
              bid - candidate + tick * 0.1 >= minimum);
     }
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return (ask > 0.0 &&
           candidate > ask &&
           candidate - ask + tick * 0.1 >= minimum);
  }

bool Strategy086_BuildRequest(
   const bool buy_side,
   const datetime source_bar,
   const int expiration_seconds,
   const double entry,
   const double sl,
   QM_EntryRequest &request)
  {
   if(source_bar <= 0 ||
      expiration_seconds <= 0 ||
      entry <= 0.0 || sl <= 0.0)
      return false;
   ZeroMemory(request);
   request.type =
      buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   request.price = entry;
   request.sl = sl;
   request.tp = 0.0;
   request.reason =
      StringFormat(buy_side
                   ? "STR086_DIBS_BUY_%I64d"
                   : "STR086_DIBS_SELL_%I64d",
                   (long)source_bar);
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds =
      expiration_seconds;
   return true;
  }

bool Strategy086_PlaceSetup(
   const datetime forming_time,
   const datetime source_bar,
   const datetime window_end_utc,
   const bool buy_enabled,
   const double buy_entry,
   const double buy_sl,
   const bool sell_enabled,
   const double sell_entry,
   const double sell_sl)
  {
   if(forming_time <= 0 ||
      forming_time == g_str086_last_place_attempt_bar)
      return false;
   g_str086_last_place_attempt_bar = forming_time;

   const datetime now_utc =
      QM_BrokerToUTC(TimeCurrent());
   const int expiration_seconds =
      (int)(window_end_utc - now_utc);
   if(expiration_seconds <= 0)
      return false;

   QM_EntryRequest buy_request;
   QM_EntryRequest sell_request;
   ZeroMemory(buy_request);
   ZeroMemory(sell_request);
   if((buy_enabled &&
       !Strategy086_BuildRequest(true,
                                 source_bar,
                                 expiration_seconds,
                                 buy_entry,
                                 buy_sl,
                                 buy_request)) ||
      (sell_enabled &&
       !Strategy086_BuildRequest(false,
                                 source_bar,
                                 expiration_seconds,
                                 sell_entry,
                                 sell_sl,
                                 sell_request)))
      return false;

   ulong opened_tickets[2];
   opened_tickets[0] = 0;
   opened_tickets[1] = 0;
   int opened_count = 0;

   if(buy_enabled)
     {
      if(!QM_TM_OpenPosition(buy_request,
                             opened_tickets[opened_count]))
        {
         Strategy086_CancelOwnPending("setup_rollback");
         return false;
        }
      ++opened_count;
     }
   if(sell_enabled)
     {
      if(!QM_TM_OpenPosition(sell_request,
                             opened_tickets[opened_count]))
        {
         for(int i = opened_count - 1; i >= 0; --i)
            if(opened_tickets[i] > 0)
               QM_TM_RemovePendingOrder(
                  opened_tickets[i],
                  "setup_rollback");
         Strategy086_CancelOwnPending("setup_rollback");
         return false;
        }
      ++opened_count;
     }
   return (opened_count > 0);
  }

bool Strategy086_IsInside(
   const MqlRates &inner_bar,
   const MqlRates &outer_bar)
  {
   return (inner_bar.high > 0.0 &&
           outer_bar.high > 0.0 &&
           inner_bar.high <= outer_bar.high &&
           inner_bar.low >= outer_bar.low);
  }

bool Strategy086_UpdateDayState(
   const datetime anchor_utc,
   const datetime forming_time)
  {
   if(anchor_utc <= 0)
      return false;
   if(anchor_utc == g_str086_day_anchor_utc &&
      g_str086_day_open > 0.0)
      return true;

   if(Strategy086_OwnPendingCount() > 0 &&
      !Strategy086_CancelOwnPending("utc_day_roll"))
      return false;
   double day_open = 0.0;
   if(!Strategy086_LoadDayOpen(anchor_utc,
                               day_open))
     {
      Strategy086_LogDataMissing("utc_day_open",
                                 forming_time);
      return false;
     }
   g_str086_day_anchor_utc = anchor_utc;
   g_str086_day_open = day_open;
   g_str086_last_place_attempt_bar = 0;
   return true;
  }

void Strategy086_ProcessClosedBar(
   const datetime forming_time)
  {
   if(!Strategy086_ConfigValid() ||
      !Strategy086_HandleReady())
      return;

   MqlRates bars[];
   ArraySetAsSeries(bars, true);
   const int copied =
      CopyRates(_Symbol, PERIOD_H1, 1, 3, bars); // perf-allowed: exactly three closed H1 records for current/previous inside-run classification
   if(copied != 3)
     {
      Strategy086_LogDataMissing("closed_h1_triplet",
                                 forming_time);
      return;
     }
   const datetime bar_utc =
      QM_BrokerToUTC(bars[0].time);
   const datetime anchor_utc =
      Strategy086_AnchorForUTC(bar_utc);
   if(!Strategy086_UpdateDayState(anchor_utc,
                                  forming_time))
      return;

   const datetime window_end_utc =
      anchor_utc +
      strategy_window_hours * 60 * 60;
   const datetime bar_close_utc =
      bar_utc + PeriodSeconds(PERIOD_H1);
   const datetime now_utc =
      QM_BrokerToUTC(TimeCurrent());
   if(now_utc >= window_end_utc)
     {
      Strategy086_CancelOwnPending("setup_window_end");
      return;
     }
   if(bar_close_utc > window_end_utc)
      return;

   const bool inside_now =
      Strategy086_IsInside(bars[0], bars[1]);
   if(!inside_now)
      return;
   const datetime previous_bar_utc =
      QM_BrokerToUTC(bars[1].time);
   const bool previous_same_day =
      (Strategy086_AnchorForUTC(previous_bar_utc) ==
       anchor_utc);
   const bool previous_inside =
      previous_same_day &&
      Strategy086_IsInside(bars[1], bars[2]);
   if(previous_inside)
      return; // only the first/largest bar of a consecutive-IB run

   const double pip = Strategy086_PipSize();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double setup_spread = ask - bid;
   if(pip <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      setup_spread < 0.0 ||
      bars[0].low <= 0.0 ||
      bars[0].high <= bars[0].low ||
      g_str086_day_open <= 0.0)
      return;

   const double buffer =
      strategy_break_buffer_pips * pip;
   const double buy_entry =
      Strategy086_AlignPrice(
         bars[0].high + buffer + setup_spread,
         1);
   const double buy_sl =
      Strategy086_AlignPrice(
         bars[0].low - buffer,
         -1);
   const double sell_entry =
      Strategy086_AlignPrice(
         bars[0].low - buffer,
         -1);
   const double sell_sl =
      Strategy086_AlignPrice(
         bars[0].high + buffer + setup_spread,
         1);

   bool buy_enabled =
      (buy_entry > g_str086_day_open) &&
      Strategy086_PendingLegal(true,
                               buy_entry,
                               buy_sl,
                               bid,
                               ask);
   bool sell_enabled =
      (sell_entry < g_str086_day_open) &&
      Strategy086_PendingLegal(false,
                               sell_entry,
                               sell_sl,
                               bid,
                               ask);
   if(!buy_enabled && !sell_enabled)
      return;

   // A newer valid first-IB replaces the prior setup atomically.
   if(Strategy086_OwnPendingCount() > 0 &&
      !Strategy086_CancelOwnPending(
         "new_first_inside_bar"))
      return;
   if(Strategy086_OwnPositionCount() > 0 ||
      Strategy086_OwnPendingCount() > 0)
      return;
   Strategy086_PlaceSetup(forming_time,
                          bars[0].time,
                          window_end_utc,
                          buy_enabled,
                          buy_entry,
                          buy_sl,
                          sell_enabled,
                          sell_entry,
                          sell_sl);
  }

void Strategy086_ResetCampaign()
  {
   g_str086_campaign_position_id = 0;
   g_str086_original_volume = 0.0;
   g_str086_initial_sl = 0.0;
   g_str086_campaign_facts_valid = false;
   g_str086_partial_resolved = false;
   g_str086_partial_executed = false;
   g_str086_last_partial_attempt_bar = 0;
   g_str086_last_runner_attempt_bar = 0;
  }

bool Strategy086_RecoverEntryFacts(
   const ulong position_id,
   const datetime position_time,
   double &original_volume,
   double &initial_sl)
  {
   original_volume = 0.0;
   initial_sl = 0.0;
   if(position_id == 0 || position_time <= 0)
      return false;
   datetime history_start =
      position_time - 24 * 60 * 60;
   if(history_start < 0)
      history_start = 0;
   if(!HistorySelect(history_start,
                     TimeCurrent()))
      return false;

   const int magic = QM_FrameworkMagic();
   const int deals_total = HistoryDealsTotal();
   for(int i = 0; i < deals_total; ++i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0 ||
         (ulong)HistoryDealGetInteger(
            deal,
            DEAL_POSITION_ID) != position_id ||
         (int)HistoryDealGetInteger(
            deal,
            DEAL_MAGIC) != magic ||
         HistoryDealGetString(
            deal,
            DEAL_SYMBOL) != _Symbol)
         continue;
      const ENUM_DEAL_ENTRY entry_kind =
         (ENUM_DEAL_ENTRY)HistoryDealGetInteger(
            deal,
            DEAL_ENTRY);
      if(entry_kind != DEAL_ENTRY_IN &&
         entry_kind != DEAL_ENTRY_INOUT)
         continue;
      const double deal_volume =
         HistoryDealGetDouble(deal,
                              DEAL_VOLUME);
      if(deal_volume > 0.0)
         original_volume += deal_volume;

      if(initial_sl <= 0.0)
        {
         const ulong order_ticket =
            (ulong)HistoryDealGetInteger(
               deal,
               DEAL_ORDER);
         if(order_ticket > 0)
            initial_sl =
               HistoryOrderGetDouble(order_ticket,
                                     ORDER_SL);
        }
     }
   return (original_volume > 0.0 &&
           initial_sl > 0.0);
  }

void Strategy086_SyncCampaign(
   const ulong position_id,
   const datetime position_time,
   const double current_volume)
  {
   if(position_id == 0 ||
      position_id == g_str086_campaign_position_id)
      return;
   Strategy086_ResetCampaign();
   g_str086_campaign_position_id = position_id;
   g_str086_campaign_facts_valid =
      Strategy086_RecoverEntryFacts(
         position_id,
         position_time,
         g_str086_original_volume,
         g_str086_initial_sl);
   if(!g_str086_campaign_facts_valid)
     {
      QM_LogEvent(
         QM_WARN,
         SETUP_DATA_MISSING,
         StringFormat(
            "{\"strategy\":\"STR-086\",\"component\":\"entry_order_facts\",\"position_id\":%I64u}",
            position_id));
      return;
     }

   const double volume_step =
      SymbolInfoDouble(_Symbol,
                       SYMBOL_VOLUME_STEP);
   const double tolerance =
      (volume_step > 0.0)
      ? volume_step * 0.5
      : 1e-8;
   if(current_volume + tolerance <
      g_str086_original_volume)
     {
      // Restart-safe once latch: reduced volume proves an exit tranche ran.
      g_str086_partial_resolved = true;
      g_str086_partial_executed = true;
     }
  }

void Strategy086_ResolveInvalidPartial(
   const ulong ticket,
   const double current_volume,
   const double requested_close,
   const string reason)
  {
   g_str086_partial_resolved = true;
   g_str086_partial_executed = false;
   QM_LogEvent(
      QM_WARN,
      "SETUP_CONFIG_INVALID",
      StringFormat(
         "{\"strategy\":\"STR-086\",\"reason\":\"%s\",\"ticket\":%I64u,\"original_volume\":%.8f,\"current_volume\":%.8f,\"requested_close\":%.8f}",
         QM_LoggerEscapeJson(reason),
         ticket,
         g_str086_original_volume,
         current_volume,
         requested_close));
  }

void Strategy086_ManagePosition(
   const datetime forming_time)
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   double current_volume = 0.0;
   datetime position_time = 0;
   ulong position_id = 0;
   if(!Strategy086_FindOwnPosition(ticket,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   current_volume,
                                   position_time,
                                   position_id))
     {
      Strategy086_ResetCampaign();
      return;
     }

   Strategy086_SyncCampaign(position_id,
                            position_time,
                            current_volume);
   if(!g_str086_campaign_facts_valid ||
      open_price <= 0.0 ||
      current_volume <= 0.0)
      return;

   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double market =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double initial_r =
      MathAbs(open_price - g_str086_initial_sl);
   const double tick = Strategy086_TradeTick();
   if(market <= 0.0 || initial_r <= 0.0 ||
      tick <= 0.0)
      return;

   if(!g_str086_partial_resolved)
     {
      const double favorable =
         buy_side
         ? market - open_price
         : open_price - market;
      const bool at_partial =
         favorable + tick * 0.1 >=
         strategy_partial_r * initial_r;
      if(at_partial &&
         forming_time !=
            g_str086_last_partial_attempt_bar)
        {
         g_str086_last_partial_attempt_bar =
            forming_time;
         const double requested =
            g_str086_original_volume *
            strategy_partial_fraction;
         const double close_volume =
            QM_TM_NormalizeVolume(_Symbol,
                                  requested);
         const double minimum =
            SymbolInfoDouble(_Symbol,
                             SYMBOL_VOLUME_MIN);
         if(close_volume <= 0.0)
           {
            Strategy086_ResolveInvalidPartial(
               ticket,
               current_volume,
               requested,
               "partial_normalizes_below_min");
           }
         else if(close_volume >= current_volume ||
                 current_volume - close_volume +
                    1e-10 < minimum)
           {
            Strategy086_ResolveInvalidPartial(
               ticket,
               current_volume,
               requested,
               "partial_would_close_or_leave_dust");
           }
         else if(QM_TM_PartialClose(
                    ticket,
                    close_volume,
                    QM_EXIT_PARTIAL))
           {
            g_str086_partial_resolved = true;
            g_str086_partial_executed = true;
            // Preserve the initial SL on the event; runner starts next H1 bar.
            g_str086_last_runner_attempt_bar =
               forming_time;
            QM_LogEvent(
               QM_INFO,
               "STRATEGY_EXIT",
               StringFormat(
                  "{\"strategy\":\"STR-086\",\"ticket\":%I64u,\"reason\":\"partial_1r\",\"exit_reason\":\"QM_EXIT_PARTIAL\",\"closed_volume\":%.8f,\"original_volume\":%.8f}",
                  ticket,
                  close_volume,
                  g_str086_original_volume));
           }
         else
           {
            QM_LogEvent(
               QM_WARN,
               "TM_PARTIAL_RETRY_DEFERRED",
               StringFormat(
                  "{\"strategy\":\"STR-086\",\"ticket\":%I64u,\"retry_after_bar\":%I64d}",
                  ticket,
                  (long)forming_time));
           }
        }
      if(!g_str086_partial_resolved)
         return;
     }

   // The runner evaluates one immutable closed MA value per forming H1 bar.
   if(forming_time ==
      g_str086_last_runner_attempt_bar)
      return;
   g_str086_last_runner_attempt_bar =
      forming_time;
   if(!Strategy086_HandleReady())
     {
      Strategy086_LogDataMissing("runner_ma_warmup",
                                 forming_time);
      return;
     }
   const double ma_1 =
      QM_IndicatorReadBuffer(g_str086_ma_handle,
                             0,
                             1); // perf-allowed: pooled one-value CopyBuffer, closed H1 shift 1
   if(!MathIsValidNumber(ma_1) ||
      ma_1 == EMPTY_VALUE || ma_1 <= 0.0)
     {
      Strategy086_LogDataMissing("runner_ma_value",
                                 forming_time);
      return;
     }
   const double candidate =QM_TM_NormalizePrice(_Symbol, Strategy086_AlignPrice(ma_1,
                             buy_side ? -1 : 1));
   const bool tightens =
      (candidate > 0.0) &&
      (buy_side
       ? candidate > current_sl + tick * 0.5
       : (current_sl <= 0.0 ||
          candidate < current_sl - tick * 0.5));
   if(!tightens ||
      !Strategy086_PositionStopLegal(position_type,
                                     candidate))
      return;

   // Any rejected modify is retried no earlier than the next forming H1 bar.
   QM_TM_MoveSL(ticket,
                candidate,
                "STR086_MA20_RUNNER");
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy086_OwnPositionCount() > 0 ||
      Strategy086_OwnPendingCount() > 0)
      return false;
   if(_Period != PERIOD_H1 ||
      !Strategy086_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) two-day/MA warmup gate
   if(bars_available < Strategy086_WarmupBars())
      return true;
   return !Strategy086_HandleReady();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   ZeroMemory(req);
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return false; // Manage owns every pending-order transition
  }

void Strategy_ManageOpenPosition()
  {
   datetime forming_time = 0;
   if(!Strategy086_CurrentBar(forming_time))
     {
      Strategy086_LogDataMissing("forming_h1_bar", 0);
      return;
     }
   if(!Strategy086_EnforceSingleOwnPosition(
         forming_time))
      return;

   if(Strategy086_OwnPositionCount() > 0)
     {
      // OCO peer or a partially filled residual must disappear on any fill.
      Strategy086_CancelOwnPending("oco_peer_after_fill");
      Strategy086_ManagePosition(forming_time);
      return;
     }
   Strategy086_ResetCampaign();

   // Window expiry is lifecycle state, so enforce it every tick, not only on
   // a new-bar signal evaluation.
   if(g_str086_day_anchor_utc > 0)
     {
      const datetime now_utc =
         QM_BrokerToUTC(TimeCurrent());
      const datetime window_end_utc =
         g_str086_day_anchor_utc +
         strategy_window_hours * 60 * 60;
      if(now_utc >= window_end_utc)
        {
         Strategy086_CancelOwnPending(
            "setup_window_end");
         // Do not return here: the next closed bar may be the new 06:00-UTC
         // anchor and must be allowed to roll day state.
        }
     }

   if(forming_time == g_str086_last_state_bar)
      return;
   g_str086_last_state_bar = forming_time;
   Strategy086_ProcessClosedBar(forming_time);
  }

bool Strategy_ExitSignal()
  {
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_time, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy);
   if(news_allows)
      return false;

   // No stop order may remain triggerable while the central gate is closed.
   Strategy086_CancelOwnPending("news_blackout");
   return true;
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
