#property strict
#property version   "5.0"
#property description "QM5_10842 TradingView KALKI liquidity sweep"

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
input int    qm_ea_id                   = 10842;
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
input int    strategy_swing_lookback     = 5;
input int    strategy_ema_period         = 200;
input int    strategy_atr_period         = 14;
input double strategy_atr_buffer_mult    = 0.25;
input double strategy_target_r           = 3.0;
input bool   strategy_allow_next_reclaim = true;
input int    strategy_max_swing_scan     = 80;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): card adds no strategy-specific block.
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: M5/M15 liquidity sweep and reclaim with EMA trend guard.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int lookback = MathMax(1, strategy_swing_lookback);
   const int max_scan = MathMax(strategy_max_swing_scan, lookback * 4 + 4);
   if(strategy_ema_period <= 0 || strategy_atr_period <= 0 ||
      strategy_atr_buffer_mult <= 0.0 || strategy_target_r <= 0.0)
      return false;

   // Read the just-closed sweep/reclaim bars (perf-allowed structural reads, QM_IsNewBar-gated).
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: bespoke sweep/reclaim bar read, framework-gated by QM_IsNewBar().
   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: bespoke sweep/reclaim bar read, framework-gated by QM_IsNewBar().
   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed: bespoke sweep/reclaim bar read, framework-gated by QM_IsNewBar().
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: next-candle reclaim check, framework-gated by QM_IsNewBar().
   const double high2 = iHigh(_Symbol, _Period, 2);   // perf-allowed: next-candle reclaim check, framework-gated by QM_IsNewBar().
   const double low2 = iLow(_Symbol, _Period, 2);     // perf-allowed: next-candle reclaim check, framework-gated by QM_IsNewBar().
   if(close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(ema <= 0.0 || atr <= 0.0)
      return false;

   double swing_low_same = 0.0;
   double swing_high_same = 0.0;
   double swing_low_next = 0.0;
   double swing_high_next = 0.0;

   for(int pass = 0; pass < 2; ++pass)
     {
      const int sweep_shift = (pass == 0) ? 1 : 2;
      double found_low = 0.0;
      double found_high = 0.0;

      // Pivot window must sit entirely OLDER than the sweep bar: with the
      // center at `shift`, the newest neighbour is shift-lookback, so we need
      // shift-lookback >= sweep_shift+1 -> shift starts at sweep_shift+lookback+1.
      // Starting at sweep_shift+lookback would pull the sweep bar into the
      // pivot window, forcing center_low < sweep_low and making the pierce
      // (sweep_low < swing_low) unsatisfiable -> zero trades.
      for(int shift = sweep_shift + lookback + 1; shift <= max_scan && (found_low <= 0.0 || found_high <= 0.0); ++shift)
        {
         const double center_low = iLow(_Symbol, _Period, shift);    // perf-allowed: bounded internal-swing structural scan.
         const double center_high = iHigh(_Symbol, _Period, shift);  // perf-allowed: bounded internal-swing structural scan.
         if(center_low <= 0.0 || center_high <= 0.0)
            continue;

         bool is_swing_low = true;
         bool is_swing_high = true;
         for(int j = 1; j <= lookback; ++j)
           {
            const double newer_low = iLow(_Symbol, _Period, shift - j);    // perf-allowed: bounded internal-swing structural scan.
            const double older_low = iLow(_Symbol, _Period, shift + j);    // perf-allowed: bounded internal-swing structural scan.
            const double newer_high = iHigh(_Symbol, _Period, shift - j);  // perf-allowed: bounded internal-swing structural scan.
            const double older_high = iHigh(_Symbol, _Period, shift + j);  // perf-allowed: bounded internal-swing structural scan.
            if(newer_low <= 0.0 || older_low <= 0.0 || newer_high <= 0.0 || older_high <= 0.0)
              {
               is_swing_low = false;
               is_swing_high = false;
               break;
              }
            if(center_low >= newer_low || center_low >= older_low)
               is_swing_low = false;
            if(center_high <= newer_high || center_high <= older_high)
               is_swing_high = false;
           }

         if(is_swing_low && found_low <= 0.0)
            found_low = center_low;
         if(is_swing_high && found_high <= 0.0)
            found_high = center_high;
        }

      if(pass == 0)
        {
         swing_low_same = found_low;
         swing_high_same = found_high;
        }
      else
        {
         swing_low_next = found_low;
         swing_high_next = found_high;
        }
     }

   const bool same_bar_long = (swing_low_same > 0.0 && low1 < swing_low_same && close1 > swing_low_same);
   const bool next_bar_long = (strategy_allow_next_reclaim && swing_low_next > 0.0 &&
                               low2 < swing_low_next && close2 <= swing_low_next && close1 > swing_low_next);
   if(close1 > ema && (same_bar_long || next_bar_long))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sweep_low = same_bar_long ? low1 : low2;
      const double sl = sweep_low - strategy_atr_buffer_mult * atr;
      const double risk = entry - sl;
      if(entry <= 0.0 || risk < 0.25 * atr || risk > 3.0 * atr)
         return false;

      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = entry + strategy_target_r * risk;
      req.reason = same_bar_long ? "kalki_same_bar_long" : "kalki_next_bar_long";
      return true;
     }

   const bool same_bar_short = (swing_high_same > 0.0 && high1 > swing_high_same && close1 < swing_high_same);
   const bool next_bar_short = (strategy_allow_next_reclaim && swing_high_next > 0.0 &&
                                high2 > swing_high_next && close2 >= swing_high_next && close1 < swing_high_next);
   if(close1 < ema && (same_bar_short || next_bar_short))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sweep_high = same_bar_short ? high1 : high2;
      const double sl = sweep_high + strategy_atr_buffer_mult * atr;
      const double risk = sl - entry;
      if(entry <= 0.0 || risk < 0.25 * atr || risk > 3.0 * atr)
         return false;

      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = entry - strategy_target_r * risk;
      req.reason = same_bar_short ? "kalki_same_bar_short" : "kalki_next_bar_short";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Trade Management: baseline uses fixed initial SL/TP only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Trade Close: optional opposite-sweep early exit is disabled for baseline.
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: callable for P8; no strategy-specific override.
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
