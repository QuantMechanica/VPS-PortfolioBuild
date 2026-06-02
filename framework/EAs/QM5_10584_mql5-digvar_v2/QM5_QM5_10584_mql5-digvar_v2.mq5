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
input int    strategy_vortex_period       = 14;
input int    strategy_atr_period          = 14;
input double strategy_atr_sl_mult         = 1.5;
input double strategy_atr_sl_cap_mult     = 2.5;
input double strategy_tp_rr               = 1.5;
input int    strategy_breakout_exp_bars   = 6;

int      g_pending_dir = 0;
double   g_pending_break_price = 0.0;
double   g_pending_stop_ref = 0.0;
int      g_pending_age = 0;
int      g_cached_opposite_exit_dir = 0;

bool ReadVortex(const int period,
                const int shift,
                double &out_plus,
                double &out_minus,
                MqlRates &rates[])
  {
   out_plus = 0.0;
   out_minus = 0.0;
   if(period <= 1 || shift < 1)
      return false;

   double vm_plus = 0.0;
   double vm_minus = 0.0;
   double true_range = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double high_now = rates[i].high;
      const double low_now = rates[i].low;
      const double high_prev = rates[i + 1].high;
      const double low_prev = rates[i + 1].low;
      const double close_prev = rates[i + 1].close;

      vm_plus += MathAbs(high_now - low_prev);
      vm_minus += MathAbs(low_now - high_prev);

      const double range_hl = high_now - low_now;
      const double range_hc = MathAbs(high_now - close_prev);
      const double range_lc = MathAbs(low_now - close_prev);
      true_range += MathMax(range_hl, MathMax(range_hc, range_lc));
     }

   if(true_range <= 0.0)
      return false;

   out_plus = vm_plus / true_range;
   out_minus = vm_minus / true_range;
   return true;
  }

bool LoadVortexWindow(MqlRates &rates[])
  {
   const int period = MathMax(2, strategy_vortex_period);
   const int need = period + 4;
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 0, need, rates);
   return (copied >= need);
  }

int VortexCrossOnLastClosedBar(MqlRates &rates[])
  {
   double plus_1 = 0.0;
   double minus_1 = 0.0;
   double plus_2 = 0.0;
   double minus_2 = 0.0;
   if(!ReadVortex(strategy_vortex_period, 1, plus_1, minus_1, rates) ||
      !ReadVortex(strategy_vortex_period, 2, plus_2, minus_2, rates))
      return 0;

   if(plus_1 > minus_1 && plus_2 <= minus_2)
      return 1;
   if(minus_1 > plus_1 && minus_2 <= plus_2)
      return -1;
   return 0;
  }

double CappedVortexStop(const QM_OrderType side,
                        const double entry,
                        const double crossover_opposite,
                        const double atr_value)
  {
   if(entry <= 0.0 || crossover_opposite <= 0.0 || atr_value <= 0.0)
      return 0.0;

   const double atr_distance = atr_value * strategy_atr_sl_mult;
   const double structure_distance = MathAbs(entry - crossover_opposite);
   const double raw_distance = MathMax(atr_distance, structure_distance);
   const double capped_distance = MathMin(raw_distance, atr_value * strategy_atr_sl_cap_mult);
   return QM_StopRulesStopFromDistance(_Symbol, side, entry, capped_distance);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   MqlRates rates[];
   if(!LoadVortexWindow(rates))
      return false;

   g_cached_opposite_exit_dir = VortexCrossOnLastClosedBar(rates);

   bool fire = false;
   int fire_dir = 0;
   double fire_stop_ref = 0.0;
   if(g_pending_dir > 0)
     {
      g_pending_age++;
      if(rates[1].high > g_pending_break_price)
        {
         fire = true;
         fire_dir = 1;
         fire_stop_ref = g_pending_stop_ref;
        }
     }
   else if(g_pending_dir < 0)
     {
      g_pending_age++;
      if(rates[1].low < g_pending_break_price)
        {
         fire = true;
         fire_dir = -1;
         fire_stop_ref = g_pending_stop_ref;
        }
     }

   const int new_cross = g_cached_opposite_exit_dir;
   if(new_cross > 0)
     {
      g_pending_dir = 1;
      g_pending_break_price = rates[1].high;
      g_pending_stop_ref = rates[1].low;
      g_pending_age = 0;
     }
   else if(new_cross < 0)
     {
      g_pending_dir = -1;
      g_pending_break_price = rates[1].low;
      g_pending_stop_ref = rates[1].high;
      g_pending_age = 0;
     }
   else if(g_pending_dir != 0 && g_pending_age > strategy_breakout_exp_bars)
     {
      g_pending_dir = 0;
      g_pending_break_price = 0.0;
      g_pending_stop_ref = 0.0;
      g_pending_age = 0;
     }

   if(!fire || QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const QM_OrderType side = (fire_dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (fire_dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double sl = CappedVortexStop(side, entry, fire_stop_ref, atr);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(entry <= 0.0 || sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.tp = tp;
   req.reason = (fire_dir > 0) ? "vortex_long_breakout" : "vortex_short_breakout";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_pending_dir = 0;
   g_pending_break_price = 0.0;
   g_pending_stop_ref = 0.0;
   g_pending_age = 0;
   g_cached_opposite_exit_dir = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(g_cached_opposite_exit_dir == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_cached_opposite_exit_dir < 0)
        {
         g_cached_opposite_exit_dir = 0;
         return true;
        }
      if(pos_type == POSITION_TYPE_SELL && g_cached_opposite_exit_dir > 0)
        {
         g_cached_opposite_exit_dir = 0;
         return true;
        }
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

