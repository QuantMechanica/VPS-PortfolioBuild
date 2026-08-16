#property strict
#property version   "5.0"
#property description "QM5_20140 roundnum-sma50-h1 (V5)"

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
input int    strategy_sma_period             = 50;
input double strategy_grid_pips              = 25.0;
input double strategy_entry_offset_pips      = 3.0;
input double strategy_sl_pips                = 30.0;
input double strategy_tp_pips                = 50.0;
input double strategy_ma_proximity_pips      = 10.0;
input double strategy_be_trigger_pips        = 10.0;
input double strategy_be_plus_pips           = 1.0;

int      g_str087_sma_handle = INVALID_HANDLE;
datetime g_str087_last_state_bar = 0;
datetime g_str087_last_place_attempt_bar = 0;
datetime g_str087_last_cancel_attempt_bar = 0;
datetime g_str087_last_be_attempt_bar = 0;
datetime g_str087_last_data_log_bar = 0;
ulong    g_str087_managed_position_id = 0;
bool     g_str087_be_done = false;

bool Strategy087_ConfigValid()
  {
   return (strategy_sma_period > 1 &&
           MathIsValidNumber(strategy_grid_pips) &&
           strategy_grid_pips > 0.0 &&
           MathIsValidNumber(strategy_entry_offset_pips) &&
           strategy_entry_offset_pips > 0.0 &&
           MathIsValidNumber(strategy_sl_pips) &&
           strategy_sl_pips > 0.0 &&
           MathIsValidNumber(strategy_tp_pips) &&
           strategy_tp_pips > 0.0 &&
           MathIsValidNumber(strategy_ma_proximity_pips) &&
           strategy_ma_proximity_pips >= 0.0 &&
           MathIsValidNumber(strategy_be_trigger_pips) &&
           strategy_be_trigger_pips > 0.0 &&
           MathIsValidNumber(strategy_be_plus_pips) &&
           strategy_be_plus_pips >= 0.0);
  }

bool Strategy087_EnsureHandle()
  {
   if(g_str087_sma_handle == INVALID_HANDLE)
      g_str087_sma_handle =
         QM_IndMA(_Symbol,
                  PERIOD_H1,
                  strategy_sma_period,
                  MODE_SMA,
                  PRICE_CLOSE);
   return (g_str087_sma_handle != INVALID_HANDLE);
  }

bool Strategy087_HandleReady()
  {
   if(!Strategy087_EnsureHandle())
      return false;
   int required = 60;
   if(strategy_sma_period + 5 > required)
      required = strategy_sma_period + 5;
   return (BarsCalculated(g_str087_sma_handle) >= required);
  }

bool Strategy087_CurrentBar(datetime &bar_time)
  {
   bar_time =
      (datetime)SeriesInfoInteger(
         _Symbol,
         PERIOD_H1,
         SERIES_LASTBAR_DATE); // perf-allowed: O(1) immutable forming-H1 clock for pending state and retry guards
   return (bar_time > 0);
  }

void Strategy087_LogDataMissing(const string component,
                                const datetime bar_time)
  {
   if(bar_time > 0 &&
      bar_time == g_str087_last_data_log_bar)
      return;
   g_str087_last_data_log_bar = bar_time;
   QM_LogEvent(
      QM_WARN,
      SETUP_DATA_MISSING,
      StringFormat(
         "{\"strategy\":\"STR-087\",\"component\":\"%s\",\"bar_time\":%I64d,\"slot\":%d}",
         QM_LoggerEscapeJson(component),
         (long)bar_time,
         qm_magic_slot_offset));
  }

double Strategy087_PipSize()
  {
   // QM_StopRules uses 10*_Point for both five-digit FX and three-digit JPY.
   return QM_StopRulesPipsToPriceDistance(_Symbol, 1);
  }

double Strategy087_TradeTick()
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

double Strategy087_AlignPrice(const double raw_price,
                              const int direction)
  {
   const double tick = Strategy087_TradeTick();
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

double Strategy087_NextGridAbove(
   const double threshold,
   const double step)
  {
   if(threshold <= 0.0 || step <= 0.0)
      return 0.0;
   const double units =
      MathFloor(threshold / step + 1e-10) + 1.0;
   return Strategy087_AlignPrice(units * step, 1);
  }

double Strategy087_NextGridBelow(
   const double threshold,
   const double step)
  {
   if(threshold <= 0.0 || step <= 0.0)
      return 0.0;
   const double units =
      MathCeil(threshold / step - 1e-10) - 1.0;
   return Strategy087_AlignPrice(units * step, -1);
  }

bool Strategy087_FindOwnPosition(
   ulong &ticket,
   ENUM_POSITION_TYPE &position_type,
   double &open_price,
   double &current_sl,
   ulong &position_id)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_price = 0.0;
   current_sl = 0.0;
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
      position_id =
         (ulong)PositionGetInteger(
            POSITION_IDENTIFIER);
      return true;
     }
   return false;
  }

int Strategy087_OwnPendingCount()
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

bool Strategy087_FindOwnPending(
   ulong &ticket,
   ENUM_ORDER_TYPE &order_type,
   double &entry,
   double &sl,
   double &tp)
  {
   ticket = 0;
   order_type = ORDER_TYPE_BUY_STOP;
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = OrderGetTicket(i);
      if(candidate == 0 || !OrderSelect(candidate) ||
         (int)OrderGetInteger(ORDER_MAGIC) != magic ||
         OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE candidate_type =
         (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(candidate_type != ORDER_TYPE_BUY_STOP &&
         candidate_type != ORDER_TYPE_SELL_STOP)
         continue;
      ticket = candidate;
      order_type = candidate_type;
      entry = OrderGetDouble(ORDER_PRICE_OPEN);
      sl = OrderGetDouble(ORDER_SL);
      tp = OrderGetDouble(ORDER_TP);
      return true;
     }
   return false;
  }

bool Strategy087_CancelOwnPending(
   const string reason,
   const datetime retry_bar,
   const bool pace_per_bar)
  {
   if(pace_per_bar &&
      retry_bar > 0 &&
      retry_bar == g_str087_last_cancel_attempt_bar)
      return false;
   if(pace_per_bar)
      g_str087_last_cancel_attempt_bar = retry_bar;

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
   if(all_ok)
      g_str087_last_cancel_attempt_bar = 0;
   return all_ok;
  }

bool Strategy087_PendingLegal(
   const bool buy_side,
   const double entry,
   const double sl,
   const double tp,
   const double bid,
   const double ask)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy087_TradeTick();
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
      MathMax(tick,
              (double)broker_level * point);
   if(buy_side)
      return (entry > ask &&
              sl < entry &&
              tp > entry &&
              entry - ask + tick * 0.1 >= minimum &&
              entry - sl + tick * 0.1 >= minimum &&
              tp - entry + tick * 0.1 >= minimum);
   return (entry < bid &&
           sl > entry &&
           tp < entry &&
           bid - entry + tick * 0.1 >= minimum &&
           sl - entry + tick * 0.1 >= minimum &&
           entry - tp + tick * 0.1 >= minimum);
  }

bool Strategy087_PositionStopLegal(
   const ENUM_POSITION_TYPE position_type,
   const double candidate)
  {
   const double point =
      SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tick = Strategy087_TradeTick();
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

bool Strategy087_BuildCandidate(
   const datetime forming_time,
   bool &buy_side,
   double &level,
   double &entry,
   double &sl,
   double &tp)
  {
   buy_side = false;
   level = 0.0;
   entry = 0.0;
   sl = 0.0;
   tp = 0.0;
   if(!Strategy087_ConfigValid() ||
      !Strategy087_HandleReady())
      return false;

   MqlRates closed_bar;
   if(!QM_ReadBar(_Symbol,
                  PERIOD_H1,
                  1,
                  closed_bar)) // perf-allowed: one closed-H1 CopyRates record for regime close
     {
      Strategy087_LogDataMissing("closed_h1_bar",
                                 forming_time);
      return false;
     }
   const double sma =
      QM_IndicatorReadBuffer(g_str087_sma_handle,
                             0,
                             1); // perf-allowed: pooled one-value CopyBuffer, closed H1 shift 1
   const double pip = Strategy087_PipSize();
   const double bid =
      SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask =
      SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(!MathIsValidNumber(sma) ||
      sma == EMPTY_VALUE || sma <= 0.0 ||
      closed_bar.close <= 0.0 ||
      pip <= 0.0 ||
      bid <= 0.0 || ask <= 0.0 || ask < bid ||
      closed_bar.close == sma)
      return false;

   const double grid_step =
      strategy_grid_pips * pip;
   const double offset =
      strategy_entry_offset_pips * pip;
   const double proximity =
      strategy_ma_proximity_pips * pip;
   const double sl_distance =
      strategy_sl_pips * pip;
   const double tp_distance =
      strategy_tp_pips * pip;
   if(grid_step <= 0.0 || offset <= 0.0 ||
      sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   buy_side = (closed_bar.close > sma);
   if(buy_side)
     {
      // Strict thresholds implement L > SMA and L+offset > Ask.
      const double threshold =
         MathMax(sma, ask - offset);
      level =
         Strategy087_NextGridAbove(threshold,
                                   grid_step);
      entry =
         Strategy087_AlignPrice(level + offset, 1);
      sl =
         Strategy087_AlignPrice(entry - sl_distance,
                                -1);
      tp =
         Strategy087_AlignPrice(entry + tp_distance,
                                1);
     }
   else
     {
      // Strict thresholds implement L < SMA and L-offset < Bid.
      const double threshold =
         MathMin(sma, bid + offset);
      level =
         Strategy087_NextGridBelow(threshold,
                                   grid_step);
      entry =
         Strategy087_AlignPrice(level - offset, -1);
      sl =
         Strategy087_AlignPrice(entry + sl_distance,
                                1);
      tp =
         Strategy087_AlignPrice(entry - tp_distance,
                                -1);
     }

   if(level <= 0.0 ||
      MathAbs(level - sma) + Strategy087_TradeTick() * 0.1 <
         proximity ||
      !Strategy087_PendingLegal(buy_side,
                                entry,
                                sl,
                                tp,
                                bid,
                                ask))
      return false;
   return true;
  }

bool Strategy087_PendingMatches(
   const ENUM_ORDER_TYPE actual_type,
   const double actual_entry,
   const double actual_sl,
   const double actual_tp,
   const bool buy_side,
   const double entry,
   const double sl,
   const double tp)
  {
   const double tick = Strategy087_TradeTick();
   if(tick <= 0.0)
      return false;
   const ENUM_ORDER_TYPE expected_type =
      buy_side
      ? ORDER_TYPE_BUY_STOP
      : ORDER_TYPE_SELL_STOP;
   return (actual_type == expected_type &&
           MathAbs(actual_entry - entry) <= tick * 0.5 &&
           MathAbs(actual_sl - sl) <= tick * 0.5 &&
           MathAbs(actual_tp - tp) <= tick * 0.5);
  }

bool Strategy087_PlaceCandidate(
   const datetime forming_time,
   const bool buy_side,
   const double entry,
   const double sl,
   const double tp)
  {
   if(forming_time <= 0 ||
      forming_time == g_str087_last_place_attempt_bar)
      return false;
   g_str087_last_place_attempt_bar = forming_time;

   QM_EntryRequest request;
   ZeroMemory(request);
   request.type =
      buy_side ? QM_BUY_STOP : QM_SELL_STOP;
   request.price = entry;
   request.sl = sl;
   request.tp = tp;
   request.reason =
      StringFormat(buy_side
                   ? "STR087_GRID_BUY_%I64d"
                   : "STR087_GRID_SELL_%I64d",
                   (long)forming_time);
   request.symbol_slot = qm_magic_slot_offset;
   request.expiration_seconds = 0; // GTC; final authority forbids bar expiry

   ulong out_ticket = 0;
   return QM_TM_OpenPosition(request, out_ticket);
  }

void Strategy087_ManagePendingState(
   const datetime forming_time)
  {
   ulong position_ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   ulong position_id = 0;
   const bool has_position =
      Strategy087_FindOwnPosition(position_ticket,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  position_id);
   const int pending_count =
      Strategy087_OwnPendingCount();

   if(has_position)
     {
      if(pending_count > 0)
         Strategy087_CancelOwnPending("position_open",
                                      forming_time,
                                      true);
      return;
     }

   if(_Period != PERIOD_H1 ||
      !Strategy087_ConfigValid() ||
      !Strategy087_HandleReady())
     {
      if(pending_count > 0)
         Strategy087_CancelOwnPending("invalid_or_unready",
                                      forming_time,
                                      true);
      return;
     }

   bool buy_side = false;
   double level = 0.0;
   double entry = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   const bool candidate_valid =
      Strategy087_BuildCandidate(forming_time,
                                 buy_side,
                                 level,
                                 entry,
                                 sl,
                                 tp);

   ulong pending_ticket = 0;
   ENUM_ORDER_TYPE pending_type =
      ORDER_TYPE_BUY_STOP;
   double pending_entry = 0.0;
   double pending_sl = 0.0;
   double pending_tp = 0.0;
   const bool has_pending =
      Strategy087_FindOwnPending(pending_ticket,
                                 pending_type,
                                 pending_entry,
                                 pending_sl,
                                 pending_tp);
   const bool exact_single_match =
      (pending_count == 1 &&
       has_pending &&
       candidate_valid &&
       Strategy087_PendingMatches(pending_type,
                                  pending_entry,
                                  pending_sl,
                                  pending_tp,
                                  buy_side,
                                  entry,
                                  sl,
                                  tp));
   if(exact_single_match)
      return;

   if(pending_count > 0 &&
      !Strategy087_CancelOwnPending(
         candidate_valid
         ? "nearest_line_replacement"
         : "regime_or_geometry_loss",
         forming_time,
         true))
      return;

   if(!candidate_valid ||
      Strategy087_OwnPendingCount() > 0)
      return;
   Strategy087_PlaceCandidate(forming_time,
                              buy_side,
                              entry,
                              sl,
                              tp);
  }

void Strategy087_ManageBreakEven(
   const datetime forming_time)
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   ulong position_id = 0;
   if(!Strategy087_FindOwnPosition(ticket,
                                   position_type,
                                   open_price,
                                   current_sl,
                                   position_id))
     {
      g_str087_managed_position_id = 0;
      g_str087_be_done = false;
      g_str087_last_be_attempt_bar = 0;
      return;
     }
   if(position_id != g_str087_managed_position_id)
     {
      g_str087_managed_position_id = position_id;
      g_str087_be_done = false;
      g_str087_last_be_attempt_bar = 0;
     }
   if(g_str087_be_done ||
      open_price <= 0.0)
      return;

   const double pip = Strategy087_PipSize();
   const double tick = Strategy087_TradeTick();
   if(pip <= 0.0 || tick <= 0.0)
      return;
   const bool buy_side =
      (position_type == POSITION_TYPE_BUY);
   const double target =QM_TM_NormalizePrice(_Symbol, Strategy087_AlignPrice(
         buy_side
         ? open_price + strategy_be_plus_pips * pip
         : open_price - strategy_be_plus_pips * pip,
         buy_side ? 1 : -1));
   const bool already_done =
      (target > 0.0) &&
      (buy_side
       ? current_sl >= target - tick * 0.5
       : (current_sl > 0.0 &&
          current_sl <= target + tick * 0.5));
   if(already_done)
     {
      g_str087_be_done = true;
      return;
     }

   const double market =
      buy_side
      ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved =
      buy_side
      ? market - open_price
      : open_price - market;
   if(market <= 0.0 ||
      moved + tick * 0.1 <
         strategy_be_trigger_pips * pip ||
      forming_time == g_str087_last_be_attempt_bar ||
      !Strategy087_PositionStopLegal(position_type,
                                     target))
      return;

   // Success latches once; rejection is paced to the next forming H1 bar.
   g_str087_last_be_attempt_bar = forming_time;
   if(QM_TM_MoveSL(ticket,
                   target,
                   "STR087_BE_PLUS_1_AT_10"))
      g_str087_be_done = true;
  }

bool Strategy_NoTradeFilter()
  {
   const bool live_intent =
      (Strategy087_OwnPendingCount() > 0);
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type =
      POSITION_TYPE_BUY;
   double open_price = 0.0;
   double current_sl = 0.0;
   ulong position_id = 0;
   const bool live_position =
      Strategy087_FindOwnPosition(ticket,
                                  position_type,
                                  open_price,
                                  current_sl,
                                  position_id);
   if(live_intent || live_position)
      return false;
   if(_Period != PERIOD_H1 ||
      !Strategy087_ConfigValid())
      return true;
   if((ENUM_SYMBOL_TRADE_MODE)SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_MODE) ==
      SYMBOL_TRADE_MODE_DISABLED)
      return true;
   const long bars_available =
      SeriesInfoInteger(_Symbol,
                        PERIOD_H1,
                        SERIES_BARS_COUNT); // perf-allowed: O(1) warmup gate
   if(bars_available < 60)
      return true;
   return !Strategy087_HandleReady();
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
   if(!Strategy087_CurrentBar(forming_time))
     {
      Strategy087_LogDataMissing("forming_h1_bar", 0);
      return;
     }

   // OCO is not used here, but a fill and stale GTC order must never coexist.
   Strategy087_ManageBreakEven(forming_time);
   if(forming_time == g_str087_last_state_bar)
      return;
   g_str087_last_state_bar = forming_time;
   Strategy087_ManagePendingState(forming_time);
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

   // Pending stop intent must not remain triggerable through a blackout.
   Strategy087_CancelOwnPending("news_blackout",
                                0,
                                false);
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
