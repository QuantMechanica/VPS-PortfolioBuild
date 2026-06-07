#property strict
#property version   "5.0"
#property description "QM5_11026 EMA Trend With Williams Percent R"

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
input int    qm_ea_id                   = 11026;
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
input bool   strategy_use_ema_trend            = true;
input int    strategy_ema_period               = 144;
input int    strategy_bars_in_trend            = 1;
input int    strategy_wpr_period               = 46;
input double strategy_wpr_oversold             = -80.0;
input double strategy_wpr_overbought           = -20.0;
input double strategy_wpr_retracement_points   = 30.0;
input int    strategy_sl_points                = 50;
input int    strategy_tp_points                = 200;
input bool   strategy_use_wpr_exit             = true;
input bool   strategy_use_unprofit_exit        = true;
input int    strategy_max_unprofit_bars        = 5;

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

   if(strategy_ema_period <= 1 || strategy_wpr_period <= 1 ||
      strategy_bars_in_trend < 1 || strategy_sl_points <= 0)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int hi_curr_shift = iHighest(_Symbol, tf, MODE_HIGH, strategy_wpr_period, 1);
   const int lo_curr_shift = iLowest(_Symbol, tf, MODE_LOW, strategy_wpr_period, 1);
   const int hi_prev_shift = iHighest(_Symbol, tf, MODE_HIGH, strategy_wpr_period, 2);
   const int lo_prev_shift = iLowest(_Symbol, tf, MODE_LOW, strategy_wpr_period, 2);
   if(hi_curr_shift < 0 || lo_curr_shift < 0 || hi_prev_shift < 0 || lo_prev_shift < 0)
      return false;

   const double high_curr = iHigh(_Symbol, tf, hi_curr_shift); // perf-allowed: bounded WPR reader, no framework helper exists.
   const double low_curr = iLow(_Symbol, tf, lo_curr_shift); // perf-allowed: bounded WPR reader, no framework helper exists.
   const double close_curr = iClose(_Symbol, tf, 1); // perf-allowed: bounded WPR reader, no framework helper exists.
   const double high_prev = iHigh(_Symbol, tf, hi_prev_shift); // perf-allowed: bounded WPR reader, no framework helper exists.
   const double low_prev = iLow(_Symbol, tf, lo_prev_shift); // perf-allowed: bounded WPR reader, no framework helper exists.
   const double close_prev = iClose(_Symbol, tf, 2); // perf-allowed: bounded WPR reader, no framework helper exists.
   if(high_curr <= low_curr || high_prev <= low_prev || close_curr <= 0.0 || close_prev <= 0.0)
      return false;

   const double wpr_curr = -100.0 * (high_curr - close_curr) / (high_curr - low_curr);
   const double wpr_prev = -100.0 * (high_prev - close_prev) / (high_prev - low_prev);

   bool trend_long = true;
   bool trend_short = true;
   if(strategy_use_ema_trend)
     {
      for(int shift = 1; shift <= strategy_bars_in_trend; ++shift)
        {
         const double bar_close = iClose(_Symbol, tf, shift); // perf-allowed: EMA trend compares closed-bar price to pooled QM_EMA.
         const double ema = QM_EMA(_Symbol, tf, strategy_ema_period, shift);
         if(bar_close <= 0.0 || ema <= 0.0)
            return false;
         if(bar_close <= ema)
            trend_long = false;
         if(bar_close >= ema)
            trend_short = false;
        }
     }

   static bool have_long_anchor = false;
   static bool have_short_anchor = false;
   static double last_long_entry_wpr = 0.0;
   static double last_short_entry_wpr = 0.0;
   static double min_wpr_since_long = 0.0;
   static double max_wpr_since_short = 0.0;

   if(have_long_anchor && wpr_curr < min_wpr_since_long)
      min_wpr_since_long = wpr_curr;
   if(have_short_anchor && wpr_curr > max_wpr_since_short)
      max_wpr_since_short = wpr_curr;

   const bool long_retrace_ok = !have_long_anchor ||
                                (last_long_entry_wpr - min_wpr_since_long >= strategy_wpr_retracement_points);
   const bool short_retrace_ok = !have_short_anchor ||
                                 (max_wpr_since_short - last_short_entry_wpr >= strategy_wpr_retracement_points);

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0)
      return false;

   const double sl_distance = strategy_sl_points * point;
   const double tp_distance = strategy_tp_points * point;

   if(trend_long &&
      wpr_prev <= strategy_wpr_oversold &&
      wpr_curr > strategy_wpr_oversold &&
      long_retrace_ok)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = NormalizeDouble(ask - sl_distance, _Digits);
      req.tp = (strategy_tp_points > 0) ? NormalizeDouble(ask + tp_distance, _Digits) : 0.0;
      req.reason = "EMA_WPR_LONG";
      have_long_anchor = true;
      last_long_entry_wpr = wpr_curr;
      min_wpr_since_long = wpr_curr;
      return true;
     }

   if(trend_short &&
      wpr_prev >= strategy_wpr_overbought &&
      wpr_curr < strategy_wpr_overbought &&
      short_retrace_ok)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = NormalizeDouble(bid + sl_distance, _Digits);
      req.tp = (strategy_tp_points > 0) ? NormalizeDouble(bid - tp_distance, _Digits) : 0.0;
      req.reason = "EMA_WPR_SHORT";
      have_short_anchor = true;
      last_short_entry_wpr = wpr_curr;
      max_wpr_since_short = wpr_curr;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline disables trailing stop, break-even, partial close, and pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   double floating_pnl = 0.0;
   datetime open_time = 0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong candidate = PositionGetTicket(i);
      if(candidate == 0 || !PositionSelectByTicket(candidate))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = candidate;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      floating_pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }

   if(ticket == 0)
      return false;

   static ulong tracked_ticket[16];
   static bool tracked_positive[16];
   int tracked_idx = -1;
   for(int i = 0; i < 16; ++i)
     {
      if(tracked_ticket[i] == ticket)
        {
         tracked_idx = i;
         break;
        }
      if(tracked_idx < 0 && tracked_ticket[i] == 0)
         tracked_idx = i;
     }

   if(tracked_idx >= 0)
     {
      if(tracked_ticket[tracked_idx] != ticket)
        {
         tracked_ticket[tracked_idx] = ticket;
         tracked_positive[tracked_idx] = false;
        }
      if(floating_pnl > 0.0)
         tracked_positive[tracked_idx] = true;
     }

   if(strategy_use_unprofit_exit && strategy_max_unprofit_bars > 0 &&
      tracked_idx >= 0 && !tracked_positive[tracked_idx] && floating_pnl <= 0.0)
     {
      const int bars_since_open = iBarShift(_Symbol, (ENUM_TIMEFRAMES)_Period, open_time, false);
      if(bars_since_open >= strategy_max_unprofit_bars)
         return true;
     }

   if(!strategy_use_wpr_exit || strategy_wpr_period <= 1)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int hi_curr_shift = iHighest(_Symbol, tf, MODE_HIGH, strategy_wpr_period, 1);
   const int lo_curr_shift = iLowest(_Symbol, tf, MODE_LOW, strategy_wpr_period, 1);
   const int hi_prev_shift = iHighest(_Symbol, tf, MODE_HIGH, strategy_wpr_period, 2);
   const int lo_prev_shift = iLowest(_Symbol, tf, MODE_LOW, strategy_wpr_period, 2);
   if(hi_curr_shift < 0 || lo_curr_shift < 0 || hi_prev_shift < 0 || lo_prev_shift < 0)
      return false;

   const double high_curr = iHigh(_Symbol, tf, hi_curr_shift); // perf-allowed: bounded WPR exit reader, no framework helper exists.
   const double low_curr = iLow(_Symbol, tf, lo_curr_shift); // perf-allowed: bounded WPR exit reader, no framework helper exists.
   const double close_curr = iClose(_Symbol, tf, 1); // perf-allowed: bounded WPR exit reader, no framework helper exists.
   const double high_prev = iHigh(_Symbol, tf, hi_prev_shift); // perf-allowed: bounded WPR exit reader, no framework helper exists.
   const double low_prev = iLow(_Symbol, tf, lo_prev_shift); // perf-allowed: bounded WPR exit reader, no framework helper exists.
   const double close_prev = iClose(_Symbol, tf, 2); // perf-allowed: bounded WPR exit reader, no framework helper exists.
   if(high_curr <= low_curr || high_prev <= low_prev || close_curr <= 0.0 || close_prev <= 0.0)
      return false;

   const double wpr_curr = -100.0 * (high_curr - close_curr) / (high_curr - low_curr);
   const double wpr_prev = -100.0 * (high_prev - close_prev) / (high_prev - low_prev);

   if(pos_type == POSITION_TYPE_BUY &&
      wpr_prev >= strategy_wpr_overbought &&
      wpr_curr < strategy_wpr_overbought)
      return true;

   if(pos_type == POSITION_TYPE_SELL &&
      wpr_prev <= strategy_wpr_oversold &&
      wpr_curr > strategy_wpr_oversold)
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
