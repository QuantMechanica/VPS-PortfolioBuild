#property strict
#property version   "5.0"
#property description "QM5_10744 TV ICT OTE"

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
input int    qm_ea_id                   = 10744;
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
input int    strategy_left_strength      = 5;
input int    strategy_right_strength     = 5;
input int    strategy_pivot_scan_bars    = 240;
input double strategy_ote_level          = 0.705;
input int    strategy_atr_period         = 14;
input double strategy_sl_atr_buffer_mult = 0.10;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

bool Strategy_IsOurPendingOrder(const ENUM_ORDER_TYPE order_type)
  {
   return (order_type == ORDER_TYPE_BUY_LIMIT || order_type == ORDER_TYPE_SELL_LIMIT);
  }

bool Strategy_HasOpenPositionOrPending()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(Strategy_IsOurPendingOrder((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE)))
         return true;
     }

   return false;
  }

bool Strategy_IsPivotHigh(const int shift)
  {
   if(shift <= strategy_right_strength)
      return false;

   const double pivot = iHigh(_Symbol, _Period, shift); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
   if(pivot <= 0.0)
      return false;

   for(int i = 1; i <= strategy_left_strength; ++i)
     {
      const double older = iHigh(_Symbol, _Period, shift + i); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      if(older <= 0.0 || older >= pivot)
         return false;
     }

   for(int i = 1; i <= strategy_right_strength; ++i)
     {
      const double newer = iHigh(_Symbol, _Period, shift - i); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      if(newer <= 0.0 || newer > pivot)
         return false;
     }

   return true;
  }

bool Strategy_IsPivotLow(const int shift)
  {
   if(shift <= strategy_right_strength)
      return false;

   const double pivot = iLow(_Symbol, _Period, shift); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
   if(pivot <= 0.0)
      return false;

   for(int i = 1; i <= strategy_left_strength; ++i)
     {
      const double older = iLow(_Symbol, _Period, shift + i); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      if(older <= 0.0 || older <= pivot)
         return false;
     }

   for(int i = 1; i <= strategy_right_strength; ++i)
     {
      const double newer = iLow(_Symbol, _Period, shift - i); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      if(newer <= 0.0 || newer < pivot)
         return false;
     }

   return true;
  }

bool Strategy_FindLatestPivotHigh(int &out_shift, double &out_price)
  {
   out_shift = -1;
   out_price = 0.0;
   const int first_shift = strategy_right_strength + 1;
   const int last_shift = MathMax(first_shift, strategy_pivot_scan_bars);
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!Strategy_IsPivotHigh(shift))
         continue;
      out_shift = shift;
      out_price = iHigh(_Symbol, _Period, shift); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      return true;
     }
   return false;
  }

bool Strategy_FindLatestPivotLow(int &out_shift, double &out_price)
  {
   out_shift = -1;
   out_price = 0.0;
   const int first_shift = strategy_right_strength + 1;
   const int last_shift = MathMax(first_shift, strategy_pivot_scan_bars);
   for(int shift = first_shift; shift <= last_shift; ++shift)
     {
      if(!Strategy_IsPivotLow(shift))
         continue;
      out_shift = shift;
      out_price = iLow(_Symbol, _Period, shift); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      return true;
     }
   return false;
  }

bool Strategy_FindPriorPivotLow(const int newer_shift, int &out_shift, double &out_price)
  {
   out_shift = -1;
   out_price = 0.0;
   for(int shift = newer_shift + 1; shift <= strategy_pivot_scan_bars; ++shift)
     {
      if(!Strategy_IsPivotLow(shift))
         continue;
      out_shift = shift;
      out_price = iLow(_Symbol, _Period, shift); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      return true;
     }
   return false;
  }

bool Strategy_FindPriorPivotHigh(const int newer_shift, int &out_shift, double &out_price)
  {
   out_shift = -1;
   out_price = 0.0;
   for(int shift = newer_shift + 1; shift <= strategy_pivot_scan_bars; ++shift)
     {
      if(!Strategy_IsPivotHigh(shift))
         continue;
      out_shift = shift;
      out_price = iHigh(_Symbol, _Period, shift); // perf-allowed: bespoke confirmed-pivot structural logic, called only after framework new-bar gate.
      return true;
     }
   return false;
  }

bool Strategy_BuildRequest(QM_EntryRequest &req,
                           const QM_OrderType type,
                           const double entry,
                           const double sl,
                           const double tp,
                           const string reason)
  {
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = type;
   req.price = QM_StopRulesNormalizePrice(_Symbol, entry);
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(QM_OrderTypeIsBuy(type))
      return (req.sl < req.price && req.price < req.tp);
   return (req.tp < req.price && req.price < req.sl);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_LIMIT;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_left_strength < 1 || strategy_right_strength < 1 ||
      strategy_pivot_scan_bars < strategy_left_strength + strategy_right_strength + 2)
      return false;
   if(strategy_ote_level <= 0.0 || strategy_ote_level >= 1.0 ||
      strategy_atr_period < 1 || strategy_sl_atr_buffer_mult < 0.0)
      return false;
   if(Strategy_HasOpenPositionOrPending())
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   int pivot_high_shift = -1;
   double pivot_high = 0.0;
   if(Strategy_FindLatestPivotHigh(pivot_high_shift, pivot_high))
     {
      int pivot_low_shift = -1;
      double pivot_low = 0.0;
      if(Strategy_FindPriorPivotLow(pivot_high_shift, pivot_low_shift, pivot_low) && pivot_high > pivot_low)
        {
         const double entry = pivot_high - (pivot_high - pivot_low) * strategy_ote_level;
         const double sl = pivot_low - strategy_sl_atr_buffer_mult * atr;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > entry && ask < pivot_high)
            return Strategy_BuildRequest(req, QM_BUY_LIMIT, entry, sl, pivot_high, "ICT_OTE_LONG");
        }
     }

   int pivot_low_shift = -1;
   double pivot_low = 0.0;
   if(Strategy_FindLatestPivotLow(pivot_low_shift, pivot_low))
     {
      int pivot_high_prior_shift = -1;
      double pivot_high_prior = 0.0;
      if(Strategy_FindPriorPivotHigh(pivot_low_shift, pivot_high_prior_shift, pivot_high_prior) && pivot_high_prior > pivot_low)
        {
         const double entry = pivot_low + (pivot_high_prior - pivot_low) * strategy_ote_level;
         const double sl = pivot_high_prior + strategy_sl_atr_buffer_mult * atr;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid < entry && bid > pivot_low)
            return Strategy_BuildRequest(req, QM_SELL_LIMIT, entry, sl, pivot_low, "ICT_OTE_SHORT");
        }
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return;

   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;

      const ENUM_ORDER_TYPE order_type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(!Strategy_IsOurPendingOrder(order_type))
         continue;

      const double sl = OrderGetDouble(ORDER_SL);
      if(sl <= 0.0)
         continue;

      if(order_type == ORDER_TYPE_BUY_LIMIT && bid <= sl)
         QM_TM_RemovePendingOrder(ticket, "ICT_OTE_LONG_INVALIDATED");
      if(order_type == ORDER_TYPE_SELL_LIMIT && ask >= sl)
         QM_TM_RemovePendingOrder(ticket, "ICT_OTE_SHORT_INVALIDATED");
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
