#property strict
#property version   "5.0"
#property description "QM5_11077 QQE 50-Level Cross"

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
input int    qm_ea_id                   = 11077;
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
input int    strategy_rsi_period        = 14;
input int    strategy_smoothing_factor  = 5;
input double strategy_alert_level       = 50.0;
input double strategy_qqe_factor        = 4.236;
input int    strategy_atr_period        = 14;
input double strategy_atr_sl_mult       = 2.5;
input int    strategy_qqe_lookback      = 240;

bool g_qqe_wait_long = false;
bool g_qqe_wait_short = false;
bool g_qqe_exit_long = false;
bool g_qqe_exit_short = false;

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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_qqe_exit_long = false;
   g_qqe_exit_short = false;

   if(strategy_rsi_period < 2 ||
      strategy_smoothing_factor < 1 ||
      strategy_alert_level <= 0.0 ||
      strategy_qqe_factor <= 0.0 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   const int warmup_min = strategy_rsi_period * 8 + strategy_smoothing_factor * 6 + 20;
   const int bars = MathMax(strategy_qqe_lookback, warmup_min);
   if(bars < 40)
      return false;

   double rsi[];
   double rsi_ma[];
   double atr_rsi[];
   double ma_atr_rsi[];
   double mama_atr_rsi[];
   double tr_slow[];
   ArrayResize(rsi, bars + 2);
   ArrayResize(rsi_ma, bars + 2);
   ArrayResize(atr_rsi, bars + 2);
   ArrayResize(ma_atr_rsi, bars + 2);
   ArrayResize(mama_atr_rsi, bars + 2);
   ArrayResize(tr_slow, bars + 2);
   ArrayInitialize(rsi, 0.0);
   ArrayInitialize(rsi_ma, 0.0);
   ArrayInitialize(atr_rsi, 0.0);
   ArrayInitialize(ma_atr_rsi, 0.0);
   ArrayInitialize(mama_atr_rsi, 0.0);
   ArrayInitialize(tr_slow, 0.0);

   for(int shift = bars + 1; shift >= 1; --shift)
     {
      rsi[shift] = QM_RSI(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_rsi_period, shift, PRICE_CLOSE);
      if(rsi[shift] <= 0.0)
         return false;
     }

   const double rsi_smooth = 2.0 / (1.0 + (double)strategy_smoothing_factor);
   rsi_ma[bars + 1] = rsi[bars + 1];
   for(int shift = bars; shift >= 1; --shift)
      rsi_ma[shift] = rsi[shift] * rsi_smooth + rsi_ma[shift + 1] * (1.0 - rsi_smooth);

   for(int shift = bars; shift >= 1; --shift)
      atr_rsi[shift] = MathAbs(rsi_ma[shift + 1] - rsi_ma[shift]);

   const int wilders_period = strategy_rsi_period * 2 - 1;
   const double wilders_smooth = 2.0 / (1.0 + (double)wilders_period);
   ma_atr_rsi[bars] = atr_rsi[bars];
   for(int shift = bars - 1; shift >= 1; --shift)
      ma_atr_rsi[shift] = atr_rsi[shift] * wilders_smooth + ma_atr_rsi[shift + 1] * (1.0 - wilders_smooth);

   mama_atr_rsi[bars] = ma_atr_rsi[bars];
   for(int shift = bars - 1; shift >= 1; --shift)
      mama_atr_rsi[shift] = ma_atr_rsi[shift] * wilders_smooth + mama_atr_rsi[shift + 1] * (1.0 - wilders_smooth);

   double tr = rsi_ma[bars];
   for(int shift = bars; shift >= 1; --shift)
     {
      const double rsi0 = rsi_ma[shift];
      const double rsi1 = rsi_ma[shift + 1];
      const double dar = mama_atr_rsi[shift] * strategy_qqe_factor;
      const double previous_tr = tr;

      if(rsi0 < previous_tr)
        {
         tr = rsi0 + dar;
         if(rsi1 < previous_tr && tr > previous_tr)
            tr = previous_tr;
        }
      else if(rsi0 > previous_tr)
        {
         tr = rsi0 - dar;
         if(rsi1 > previous_tr && tr < previous_tr)
            tr = previous_tr;
        }

      tr_slow[shift] = tr;
     }

   const double rsi_now = rsi_ma[1];
   const double rsi_prev = rsi_ma[2];
   const double tr_now = tr_slow[1];
   const double tr_prev = tr_slow[2];

   const bool cross_slow_up = (rsi_prev <= tr_prev && rsi_now > tr_now);
   const bool cross_slow_down = (rsi_prev >= tr_prev && rsi_now < tr_now);
   const bool cross_level_up = (rsi_prev <= strategy_alert_level && rsi_now > strategy_alert_level);
   const bool cross_level_down = (rsi_prev >= strategy_alert_level && rsi_now < strategy_alert_level);

   g_qqe_exit_long = cross_slow_down || cross_level_down;
   g_qqe_exit_short = cross_slow_up || cross_level_up;

   if(cross_slow_up)
     {
      g_qqe_wait_long = true;
      g_qqe_wait_short = false;
     }
   else if(cross_slow_down)
     {
      g_qqe_wait_short = true;
      g_qqe_wait_long = false;
     }

   bool has_position = false;
   const int magic = QM_FrameworkMagic();
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
   if(has_position)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(g_qqe_wait_long && cross_level_up)
     {
      side = QM_BUY;
      reason = "QQE_50_CROSS_LONG";
      g_qqe_wait_long = false;
     }
   else if(g_qqe_wait_short && cross_level_down)
     {
      side = QM_SELL;
      reason = "QQE_50_CROSS_SHORT";
      g_qqe_wait_short = false;
     }
   else
      return false;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card defines no trailing, break-even, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_qqe_exit_long && !g_qqe_exit_short)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_qqe_exit_long)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_qqe_exit_short)
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
