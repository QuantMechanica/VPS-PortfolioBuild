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
input int    qm_ea_id                   = 9938;
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
input int    strategy_ema_fast_period      = 3;
input int    strategy_ema_confirm_period   = 5;
input int    strategy_ema_slow_period      = 13;
input int    strategy_stoch_k_period       = 14;
input int    strategy_stoch_d_period       = 3;
input int    strategy_stoch_slowing        = 3;
input double strategy_stoch_midline        = 50.0;
input int    strategy_ignition_fresh_bars  = 5;
input int    strategy_slope_lookback_bars  = 3;
input int    strategy_stoch_sync_bars      = 2;
input int    strategy_fixed_sl_pips        = 20;
input int    strategy_fixed_tp_pips        = 40;
input double strategy_max_spread_sl_frac   = 0.15;
input int    strategy_time_stop_bars       = 12;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return true;

   const double mid = (ask + bid) * 0.5;
   const double stop = QM_StopFixedPips(_Symbol, QM_BUY, mid, strategy_fixed_sl_pips);
   const double stop_dist = MathAbs(mid - stop);
   if(stop_dist <= 0.0)
      return true;

   return ((ask - bid) > stop_dist * strategy_max_spread_sl_frac);
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

   if(strategy_ema_fast_period <= 0 ||
      strategy_ema_confirm_period <= 0 ||
      strategy_ema_slow_period <= 0 ||
      strategy_stoch_k_period <= 0 ||
      strategy_stoch_d_period <= 0 ||
      strategy_stoch_slowing <= 0 ||
      strategy_ignition_fresh_bars <= 0 ||
      strategy_slope_lookback_bars <= 0 ||
      strategy_stoch_sync_bars < 0 ||
      strategy_fixed_sl_pips <= 0 ||
      strategy_fixed_tp_pips <= 0)
      return false;

   int fast_long_cross = 0;
   int confirm_long_cross = 0;
   int fast_short_cross = 0;
   int confirm_short_cross = 0;
   for(int shift = 1; shift <= strategy_ignition_fresh_bars; ++shift)
     {
      const double fast_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, shift);
      const double fast_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, shift + 1);
      const double confirm_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_confirm_period, shift);
      const double confirm_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_confirm_period, shift + 1);
      const double slow_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, shift);
      const double slow_prev = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, shift + 1);
      if(fast_now <= 0.0 || fast_prev <= 0.0 || confirm_now <= 0.0 || confirm_prev <= 0.0 || slow_now <= 0.0 || slow_prev <= 0.0)
         return false;

      if(fast_long_cross == 0 && fast_now > slow_now && fast_prev <= slow_prev)
         fast_long_cross = shift;
      if(confirm_long_cross == 0 && confirm_now > slow_now && confirm_prev <= slow_prev)
         confirm_long_cross = shift;
      if(fast_short_cross == 0 && fast_now < slow_now && fast_prev >= slow_prev)
         fast_short_cross = shift;
      if(confirm_short_cross == 0 && confirm_now < slow_now && confirm_prev >= slow_prev)
         confirm_short_cross = shift;
     }

   int stoch_long_cross = 0;
   int stoch_short_cross = 0;
   const int stoch_scan_bars = strategy_ignition_fresh_bars + strategy_stoch_sync_bars;
   for(int shift = 1; shift <= stoch_scan_bars; ++shift)
     {
      const double k_now = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift);
      const double k_prev = QM_Stoch_K(_Symbol, PERIOD_H1, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, shift + 1);
      if(k_now <= 0.0 || k_prev <= 0.0)
         return false;

      if(stoch_long_cross == 0 && k_now > strategy_stoch_midline && k_prev <= strategy_stoch_midline)
         stoch_long_cross = shift;
      if(stoch_short_cross == 0 && k_now < strategy_stoch_midline && k_prev >= strategy_stoch_midline)
         stoch_short_cross = shift;
     }

   const double fast_slope_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 1);
   const double fast_slope_then = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 1 + strategy_slope_lookback_bars);
   const double confirm_slope_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_confirm_period, 1);
   const double confirm_slope_then = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_confirm_period, 1 + strategy_slope_lookback_bars);
   if(fast_slope_now <= 0.0 || fast_slope_then <= 0.0 || confirm_slope_now <= 0.0 || confirm_slope_then <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(fast_long_cross > 0 && confirm_long_cross > 0 && stoch_long_cross > 0)
     {
      const int ignition_shift = (fast_long_cross < confirm_long_cross) ? fast_long_cross : confirm_long_cross;
      if(MathAbs(stoch_long_cross - ignition_shift) <= strategy_stoch_sync_bars &&
         fast_slope_now > fast_slope_then &&
         confirm_slope_now > confirm_slope_then &&
         QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 0.0, 1) > 0)
        {
         req.type = QM_BUY;
         req.sl = QM_StopFixedPips(_Symbol, req.type, ask, strategy_fixed_sl_pips);
         req.tp = QM_TakeFixedPips(_Symbol, req.type, ask, strategy_fixed_tp_pips);
         req.reason = "FF_STOCH_MA_IGNITION_LONG";
         return (req.sl > 0.0 && req.tp > 0.0);
        }
     }

   if(fast_short_cross > 0 && confirm_short_cross > 0 && stoch_short_cross > 0)
     {
      const int ignition_shift = (fast_short_cross < confirm_short_cross) ? fast_short_cross : confirm_short_cross;
      if(MathAbs(stoch_short_cross - ignition_shift) <= strategy_stoch_sync_bars &&
         fast_slope_now < fast_slope_then &&
         confirm_slope_now < confirm_slope_then &&
         QM_Sig_Price_Above_MA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 0.0, 1) < 0)
        {
         req.type = QM_SELL;
         req.sl = QM_StopFixedPips(_Symbol, req.type, bid, strategy_fixed_sl_pips);
         req.tp = QM_TakeFixedPips(_Symbol, req.type, bid, strategy_fixed_tp_pips);
         req.reason = "FF_STOCH_MA_IGNITION_SHORT";
         return (req.sl > 0.0 && req.tp > 0.0);
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed SL/TP plus early strategy exit only; no trailing or partial management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const double fast_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_fast_period, 1);
   const double confirm_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_confirm_period, 1);
   const double slow_now = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_slow_period, 1);
   if(fast_now <= 0.0 || confirm_now <= 0.0 || slow_now <= 0.0)
      return false;

   const int hold_seconds = strategy_time_stop_bars * PeriodSeconds(PERIOD_H1);
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(hold_seconds > 0 && (TimeCurrent() - (datetime)PositionGetInteger(POSITION_TIME)) >= hold_seconds)
         return true;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && fast_now < slow_now && confirm_now < slow_now)
         return true;
      if(pos_type == POSITION_TYPE_SELL && fast_now > slow_now && confirm_now > slow_now)
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
