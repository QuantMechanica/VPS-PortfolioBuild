#property strict
#property version   "5.0"
#property description "QM5_9990 ForexFactory Dual Candle BB RSI Breakout"

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
//   - QM_FrameworkHandleFridayClose / QM_KillSwitchCheck / QM_NewsAllowsTrade
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
input int    qm_ea_id                   = 9990;
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
input int    strategy_bb_period          = 20;
input double strategy_bb_deviation       = 2.0;
input int    strategy_rsi_period         = 14;
input double strategy_rsi_midline        = 50.0;
input int    strategy_atr_stop_period    = 14;
input int    strategy_atr_width_period   = 20;
input double strategy_max_stop_atr_mult  = 3.0;
input double strategy_min_width_atr_mult = 0.8;
input double strategy_entry_buffer_pips  = 1.0;
input double strategy_tp_rr              = 3.0;
input int    strategy_pending_expiry_bars = 3;

int g_strategy_last_signal_dir = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_H4)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   g_strategy_last_signal_dir = 0;

   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_bb_period <= 1 ||
      strategy_rsi_period <= 1 ||
      strategy_atr_stop_period <= 1 ||
      strategy_atr_width_period <= 1 ||
      strategy_max_stop_atr_mult <= 0.0 ||
      strategy_min_width_atr_mult <= 0.0 ||
      strategy_entry_buffer_pips <= 0.0 ||
      strategy_tp_rr <= 0.0 ||
      strategy_pending_expiry_bars <= 0)
      return false;

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
      if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
         return false;
     }

   const double open2  = iOpen(_Symbol, PERIOD_H4, 2);   // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   const double high1  = iHigh(_Symbol, PERIOD_H4, 1);   // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   const double high2  = iHigh(_Symbol, PERIOD_H4, 2);   // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   const double low1   = iLow(_Symbol, PERIOD_H4, 1);    // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   const double low2   = iLow(_Symbol, PERIOD_H4, 2);    // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   const double close1 = iClose(_Symbol, PERIOD_H4, 1);  // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   const double close2 = iClose(_Symbol, PERIOD_H4, 2);  // perf-allowed: fixed two-candle structural pattern, called behind skeleton QM_IsNewBar gate.
   if(open2 <= 0.0 || high1 <= 0.0 || high2 <= 0.0 || low1 <= 0.0 || low2 <= 0.0 || close1 <= 0.0 || close2 <= 0.0)
      return false;

   if(!(high1 <= high2 && low1 >= low2))
      return false;

   const double bb_upper1 = QM_BB_Upper(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid1   = QM_BB_Middle(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower1 = QM_BB_Lower(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_upper2 = QM_BB_Upper(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_mid2   = QM_BB_Middle(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 2);
   const double bb_lower2 = QM_BB_Lower(_Symbol, PERIOD_H4, strategy_bb_period, strategy_bb_deviation, 2);
   const double rsi1 = QM_RSI(_Symbol, PERIOD_H4, strategy_rsi_period, 1);
   const double atr_stop = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_stop_period, 1);
   const double atr_width = QM_ATR(_Symbol, PERIOD_H4, strategy_atr_width_period, 1);
   if(bb_upper1 <= 0.0 || bb_mid1 <= 0.0 || bb_lower1 <= 0.0 ||
      bb_upper2 <= 0.0 || bb_mid2 <= 0.0 || bb_lower2 <= 0.0 ||
      rsi1 <= 0.0 || atr_stop <= 0.0 || atr_width <= 0.0)
      return false;

   const double bb_width = bb_upper1 - bb_lower1;
   if(bb_width < strategy_min_width_atr_mult * atr_width)
      return false;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double pip = point * ((digits == 3 || digits == 5) ? 10.0 : 1.0);
   const double entry_buffer = strategy_entry_buffer_pips * pip;
   if(point <= 0.0 || pip <= 0.0 || entry_buffer <= 0.0)
      return false;

   const double min_stop_distance = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const int expiry_seconds = strategy_pending_expiry_bars * PeriodSeconds(PERIOD_H4);

   const bool long_zone = (close1 >= bb_mid1 && close1 <= bb_upper1 &&
                           close2 >= bb_mid2 && close2 <= bb_upper2);
   const bool short_zone = (close1 <= bb_mid1 && close1 >= bb_lower1 &&
                            close2 <= bb_mid2 && close2 >= bb_lower2);

   if(close2 > open2 && long_zone && rsi1 > strategy_rsi_midline)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, high2 + entry_buffer);
      const double sl = QM_TM_NormalizePrice(_Symbol, low2 - entry_buffer);
      const double stop_distance = entry - sl;
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0 || sl <= 0.0 || stop_distance <= 0.0)
         return false;
      if((min_stop_distance > 0.0 && (stop_distance < min_stop_distance || entry <= ask + min_stop_distance)) ||
         stop_distance > strategy_max_stop_atr_mult * atr_stop)
         return false;

      req.type = QM_BUY_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, sl, strategy_tp_rr);
      req.reason = "FF_DUAL_CANDLE_BB_RSI_LONG";
      req.expiration_seconds = expiry_seconds;
      if(req.tp <= 0.0)
         return false;
      g_strategy_last_signal_dir = 1;
      return true;
     }

   if(close2 < open2 && short_zone && rsi1 < strategy_rsi_midline)
     {
      const double entry = QM_TM_NormalizePrice(_Symbol, low2 - entry_buffer);
      const double sl = QM_TM_NormalizePrice(_Symbol, high2 + entry_buffer);
      const double stop_distance = sl - entry;
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0 || sl <= 0.0 || stop_distance <= 0.0)
         return false;
      if((min_stop_distance > 0.0 && (stop_distance < min_stop_distance || entry >= bid - min_stop_distance)) ||
         stop_distance > strategy_max_stop_atr_mult * atr_stop)
         return false;

      req.type = QM_SELL_STOP;
      req.price = entry;
      req.sl = sl;
      req.tp = QM_TakeRR(_Symbol, req.type, entry, sl, strategy_tp_rr);
      req.reason = "FF_DUAL_CANDLE_BB_RSI_SHORT";
      req.expiration_seconds = expiry_seconds;
      if(req.tp <= 0.0)
         return false;
      g_strategy_last_signal_dir = -1;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double current_sl = PositionGetDouble(POSITION_SL);
      const double current_tp = PositionGetDouble(POSITION_TP);
      if(open_price <= 0.0 || current_tp <= 0.0)
         continue;

      const double risk_distance = MathAbs(current_tp - open_price) / strategy_tp_rr;
      if(risk_distance <= point)
         continue;

      if(position_type == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;

         const double moved = bid - open_price;
         if(moved >= risk_distance && (current_sl <= 0.0 || current_sl < open_price - point * 0.5))
           {
            const double be_sl = QM_TM_NormalizePrice(_Symbol, open_price);
            if(QM_TM_MoveSL(ticket, be_sl, "tp1_move_to_breakeven"))
               current_sl = be_sl;
           }

         if(moved >= 2.0 * risk_distance)
           {
            const double trail_sl = QM_TM_NormalizePrice(_Symbol, bid - risk_distance);
            if(trail_sl > current_sl + point * 0.5)
               QM_TM_MoveSL(ticket, trail_sl, "tp2_trail_by_1r");
           }
        }
      else if(position_type == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;

         const double moved = open_price - ask;
         if(moved >= risk_distance && (current_sl <= 0.0 || current_sl > open_price + point * 0.5))
           {
            const double be_sl = QM_TM_NormalizePrice(_Symbol, open_price);
            if(QM_TM_MoveSL(ticket, be_sl, "tp1_move_to_breakeven"))
               current_sl = be_sl;
           }

         if(moved >= 2.0 * risk_distance)
           {
            const double trail_sl = QM_TM_NormalizePrice(_Symbol, ask + risk_distance);
            if(current_sl <= 0.0 || trail_sl < current_sl - point * 0.5)
               QM_TM_MoveSL(ticket, trail_sl, "tp2_trail_by_1r");
           }
        }
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_buy = false;
   bool have_sell = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY)
         have_buy = true;
      else if(position_type == POSITION_TYPE_SELL)
         have_sell = true;
     }

   if(!have_buy && !have_sell)
      return false;

   if(have_buy && g_strategy_last_signal_dir < 0)
      return true;
   if(have_sell && g_strategy_last_signal_dir > 0)
      return true;

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults.
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

   // Per-tick: trade management can adjust SL/TP on open positions.
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
   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
