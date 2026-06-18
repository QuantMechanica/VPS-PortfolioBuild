#property strict
#property version   "5.0"
#property description "QM5_11891 Unger Daily-Factor Indecision Pattern"

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
input int    qm_ea_id                   = 11891;
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
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
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
input double strategy_body_range_threshold = 0.50;
input int    strategy_signal_shift         = 1;
input int    strategy_trigger_offset_pips  = 1;
input int    strategy_stop_atr_period      = 14;
input double strategy_stop_atr_mult        = 1.50;
input double strategy_target_atr_mult      = 3.00;
input int    strategy_holding_max_d1_bars  = 5;
input int    strategy_order_expiration_hours = 24;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if((ENUM_TIMEFRAMES)_Period != PERIOD_D1)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

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

      for(int j = OrdersTotal() - 1; j >= 0; --j)
        {
         const ulong order_ticket = OrderGetTicket(j);
         if(order_ticket == 0 || !OrderSelect(order_ticket))
            continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol)
            continue;
         if((int)OrderGetInteger(ORDER_MAGIC) != magic)
            continue;
         const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if(order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
            QM_TM_RemovePendingOrder(order_ticket, "oco_sibling_after_fill");
        }
      return false;
     }

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
         QM_TM_RemovePendingOrder(order_ticket, "new_d1_pattern_replaces_unfilled_order");
     }

   if(strategy_signal_shift < 1 || strategy_trigger_offset_pips < 1 ||
      strategy_stop_atr_period < 1 || strategy_stop_atr_mult <= 0.0 ||
      strategy_target_atr_mult <= 0.0 || strategy_order_expiration_hours < 1)
      return false;

   const double open_t = iOpen(_Symbol, PERIOD_D1, strategy_signal_shift);   // perf-allowed: closed D1 structural candle read
   const double high_t = iHigh(_Symbol, PERIOD_D1, strategy_signal_shift);   // perf-allowed: closed D1 structural candle read
   const double low_t = iLow(_Symbol, PERIOD_D1, strategy_signal_shift);     // perf-allowed: closed D1 structural candle read
   const double close_t = iClose(_Symbol, PERIOD_D1, strategy_signal_shift); // perf-allowed: closed D1 structural candle read
   if(open_t <= 0.0 || high_t <= 0.0 || low_t <= 0.0 || close_t <= 0.0 || high_t <= low_t)
      return false;

   const double body_ratio = MathAbs(close_t - open_t) / (high_t - low_t);
   if(body_ratio >= strategy_body_range_threshold)
      return false;

   const double pip_offset = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_trigger_offset_pips);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_stop_atr_period, strategy_signal_shift);
   if(pip_offset <= 0.0 || atr <= 0.0)
      return false;

   QM_EntryRequest buy_req;
   buy_req.type = QM_BUY_STOP;
   buy_req.price = QM_StopRulesNormalizePrice(_Symbol, high_t + pip_offset);
   buy_req.sl = QM_StopATRFromValue(_Symbol, buy_req.type, buy_req.price, atr, strategy_stop_atr_mult);
   buy_req.tp = QM_TakeATRFromValue(_Symbol, buy_req.type, buy_req.price, atr, strategy_target_atr_mult);
   buy_req.reason = "unger_indecision_buy_stop";
   buy_req.symbol_slot = qm_magic_slot_offset;
   buy_req.expiration_seconds = strategy_order_expiration_hours * 3600;

   QM_EntryRequest sell_req;
   sell_req.type = QM_SELL_STOP;
   sell_req.price = QM_StopRulesNormalizePrice(_Symbol, low_t - pip_offset);
   sell_req.sl = QM_StopATRFromValue(_Symbol, sell_req.type, sell_req.price, atr, strategy_stop_atr_mult);
   sell_req.tp = QM_TakeATRFromValue(_Symbol, sell_req.type, sell_req.price, atr, strategy_target_atr_mult);
   sell_req.reason = "unger_indecision_sell_stop";
   sell_req.symbol_slot = qm_magic_slot_offset;
   sell_req.expiration_seconds = strategy_order_expiration_hours * 3600;

   if(buy_req.price <= 0.0 || buy_req.sl <= 0.0 || buy_req.tp <= 0.0 ||
      sell_req.price <= 0.0 || sell_req.sl <= 0.0 || sell_req.tp <= 0.0)
      return false;

   ulong buy_ticket = 0;
   ulong sell_ticket = 0;
   const bool buy_ok = QM_TM_OpenPosition(buy_req, buy_ticket);
   const bool sell_ok = QM_TM_OpenPosition(sell_req, sell_ticket);
   if(!buy_ok || !sell_ok)
     {
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
            QM_TM_RemovePendingOrder(order_ticket, "incomplete_oco_pair");
        }
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

   bool has_position = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      has_position = true;
      break;
     }

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
      if(order_type != ORDER_TYPE_BUY_STOP && order_type != ORDER_TYPE_SELL_STOP)
         continue;

      const datetime expiration = (datetime)OrderGetInteger(ORDER_TIME_EXPIRATION);
      if(has_position)
         QM_TM_RemovePendingOrder(order_ticket, "oco_sibling_after_fill");
      else if(expiration > 0 && TimeCurrent() >= expiration)
         QM_TM_RemovePendingOrder(order_ticket, "expired_next_d1_session");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(strategy_holding_max_d1_bars < 1)
      return false;

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

      const datetime entry_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_entry = iBarShift(_Symbol, PERIOD_D1, entry_time, false); // perf-allowed: D1 time-stop bar count
      if(bars_since_entry >= strategy_holding_max_d1_bars)
         return true;
     }

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
