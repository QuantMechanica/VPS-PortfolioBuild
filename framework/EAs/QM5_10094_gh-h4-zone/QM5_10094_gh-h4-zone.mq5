#property strict
#property version   "5.0"
#property description "QM5_10094 GitHub H4 Zone Breakout Retest"

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
input int    qm_ea_id                   = 10094;
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
input ENUM_TIMEFRAMES strategy_signal_tf       = PERIOD_M5;
input ENUM_TIMEFRAMES strategy_ema_tf          = PERIOD_H1;
input ENUM_TIMEFRAMES strategy_atr_tf          = PERIOD_H1;
input int    strategy_zone_mode                = 0;       // 0 previous D1 high/low; 1 first H4 bars.
input int    strategy_h4_zone_bars             = 1;
input double strategy_min_body_pct             = 50.0;
input double strategy_min_body_points          = 0.0;
input int    strategy_max_wait_seconds         = 86400;
input bool   strategy_use_ema_filter           = true;
input int    strategy_ema_fast_period          = 50;
input int    strategy_ema_slow_period          = 200;
input bool   strategy_use_atr_sizing           = true;
input int    strategy_atr_period               = 14;
input double strategy_atr_sl_mult              = 1.5;
input double strategy_atr_tp_mult              = 3.0;
input double strategy_fixed_rr                 = 1.5;
input int    strategy_session_start_hour       = 7;
input int    strategy_session_end_hour         = 22;
input int    strategy_spread_cap_points        = 50;
input bool   strategy_enable_break_even        = false;
input int    strategy_be_trigger_pips          = 30;
input int    strategy_be_buffer_pips           = 2;
input bool   strategy_enable_atr_trailing      = false;
input double strategy_trail_atr_mult           = 1.5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   const int start_h = MathMax(0, MathMin(23, strategy_session_start_hour));
   const int end_h = MathMax(0, MathMin(24, strategy_session_end_hour));
   bool in_session = true;
   if(start_h != end_h)
     {
      if(start_h < end_h)
         in_session = (dt.hour >= start_h && dt.hour < end_h);
      else
         in_session = (dt.hour >= start_h || dt.hour < end_h);
     }
   if(!in_session)
      return true;

   const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(strategy_spread_cap_points > 0 && spread_points > strategy_spread_cap_points)
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

   static bool waiting_retest = false;
   static double breakout_level = 0.0;
   static double breakout_candle_low = 0.0;
   static datetime wait_started = 0;
   static datetime wait_day_start = 0;

   const datetime day_start = iTime(_Symbol, PERIOD_D1, 0);
   if(waiting_retest)
     {
      if((strategy_max_wait_seconds > 0 && TimeCurrent() - wait_started > strategy_max_wait_seconds) ||
         (wait_day_start > 0 && day_start > 0 && wait_day_start != day_start))
        {
         waiting_retest = false;
         breakout_level = 0.0;
         breakout_candle_low = 0.0;
         wait_started = 0;
         wait_day_start = 0;
        }
     }

   double zone_high = 0.0;
   double zone_low = 0.0;
   if(strategy_zone_mode == 0)
     {
      zone_high = iHigh(_Symbol, PERIOD_D1, 1);
      zone_low = iLow(_Symbol, PERIOD_D1, 1);
     }
   else if(day_start > 0)
     {
      const int need = MathMax(1, strategy_h4_zone_bars);
      int found = 0;
      for(int shift = 12; shift >= 1 && found < need; --shift)
        {
         const datetime h4_time = iTime(_Symbol, PERIOD_H4, shift);
         if(h4_time < day_start || h4_time <= 0)
            continue;

         const double h4_high = iHigh(_Symbol, PERIOD_H4, shift);
         const double h4_low = iLow(_Symbol, PERIOD_H4, shift);
         if(h4_high <= 0.0 || h4_low <= 0.0 || h4_high <= h4_low)
            continue;

         zone_high = (found == 0) ? h4_high : MathMax(zone_high, h4_high);
         zone_low = (found == 0) ? h4_low : MathMin(zone_low, h4_low);
         found++;
        }
     }

   if(zone_high > zone_low && zone_low > 0.0)
     {
      const double open_1 = iOpen(_Symbol, strategy_signal_tf, 1);
      const double close_1 = iClose(_Symbol, strategy_signal_tf, 1);
      const double high_1 = iHigh(_Symbol, strategy_signal_tf, 1);
      const double low_1 = iLow(_Symbol, strategy_signal_tf, 1);
      if(open_1 > 0.0 && close_1 > 0.0 && high_1 > low_1 && low_1 > 0.0 &&
         close_1 > zone_high && open_1 <= zone_high)
        {
         const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         const double body = MathAbs(close_1 - open_1);
         const double range = high_1 - low_1;
         const bool body_pct_ok = (range > 0.0 && (body / range * 100.0) >= strategy_min_body_pct);
         const bool body_points_ok = (point > 0.0 && strategy_min_body_points > 0.0 &&
                                      body / point >= strategy_min_body_points);
         if(body_pct_ok || body_points_ok)
           {
            waiting_retest = true;
            breakout_level = zone_high;
            breakout_candle_low = low_1;
            wait_started = TimeCurrent();
            wait_day_start = day_start;
           }
        }
     }

   if(!waiting_retest || breakout_level <= 0.0)
      return false;

   if(strategy_use_ema_filter)
     {
      const double close_ema_tf = iClose(_Symbol, strategy_ema_tf, 1);
      const double ema_fast = QM_EMA(_Symbol, strategy_ema_tf, strategy_ema_fast_period, 1);
      const double ema_slow = QM_EMA(_Symbol, strategy_ema_tf, strategy_ema_slow_period, 1);
      if(close_ema_tf <= 0.0 || ema_fast <= 0.0 || ema_slow <= 0.0 ||
         close_ema_tf <= ema_fast || close_ema_tf <= ema_slow)
         return false;
     }

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0 || bid > breakout_level)
      return false;

   const double entry = ask;
   double sl = 0.0;
   double tp = 0.0;
   if(strategy_use_atr_sizing)
     {
      const double atr = QM_ATR(_Symbol, strategy_atr_tf, strategy_atr_period, 1);
      if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0 || strategy_atr_tp_mult <= 0.0)
         return false;
      sl = entry - strategy_atr_sl_mult * atr;
      tp = entry + strategy_atr_tp_mult * atr;
     }
   else
     {
      sl = breakout_candle_low;
      if(sl <= 0.0 || sl >= entry || strategy_fixed_rr <= 0.0)
         return false;
      tp = entry + (entry - sl) * strategy_fixed_rr;
     }

   if(sl <= 0.0 || sl >= entry || tp <= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = NormalizeDouble(sl, _Digits);
   req.tp = NormalizeDouble(tp, _Digits);
   req.reason = "GH_H4_ZONE_LONG_RETEST";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   waiting_retest = false;
   breakout_level = 0.0;
   breakout_candle_low = 0.0;
   wait_started = 0;
   wait_day_start = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
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

      if(strategy_enable_break_even)
         QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, strategy_be_buffer_pips);
      if(strategy_enable_atr_trailing)
         QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
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
