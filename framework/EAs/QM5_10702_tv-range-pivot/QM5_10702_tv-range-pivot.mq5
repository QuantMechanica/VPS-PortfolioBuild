#property strict
#property version   "5.0"
#property description "QM5_10702 TradingView Range Pivot Confirmation"

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
input int    qm_ea_id                   = 10702;
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
input int             strategy_range_mode          = 0;          // 0=HTF inside candle, 1=session range.
input ENUM_TIMEFRAMES strategy_htf_timeframe       = PERIOD_H4;
input int             strategy_range_scan_units    = 40;
input int             strategy_pivot_fresh_bars    = 40;
input double          strategy_rr_target           = 2.0;
input int             strategy_session_start_h     = 0;
input int             strategy_session_end_h       = 8;
input int             strategy_session_scan_bars   = 240;
input int             strategy_trade_start_h       = 0;
input int             strategy_trade_end_h         = 24;
input int             strategy_max_spread_points   = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   if(strategy_trade_start_h < 0 || strategy_trade_start_h > 23 ||
      strategy_trade_end_h < 0 || strategy_trade_end_h > 24)
      return true;

   if(strategy_trade_start_h != strategy_trade_end_h)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int h = dt.hour;
      if(strategy_trade_start_h < strategy_trade_end_h)
        {
         if(h < strategy_trade_start_h || h >= strategy_trade_end_h)
            return true;
        }
      else
        {
         if(h < strategy_trade_start_h && h >= strategy_trade_end_h)
            return true;
        }
     }

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

   if(strategy_range_scan_units < 2 ||
      strategy_pivot_fresh_bars < 3 ||
      strategy_rr_target <= 0.0 ||
      strategy_session_scan_bars < 10)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int bars = Bars(_Symbol, tf);
   if(bars < strategy_pivot_fresh_bars + 5)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   datetime range_from = 0;

   if(strategy_range_mode == 1)
     {
      if(strategy_session_start_h < 0 || strategy_session_start_h > 23 ||
         strategy_session_end_h < 0 || strategy_session_end_h > 24)
         return false;

      double latest_hi = 0.0, latest_low = 0.0, latest_close = 0.0;
      double prior_hi = 0.0, prior_low = 0.0;
      double run_hi = 0.0, run_low = 0.0, run_close = 0.0;
      datetime run_end = 0;
      bool in_run = false;
      int max_shift = strategy_session_scan_bars;
      if(max_shift > bars - 2)
         max_shift = bars - 2;

      for(int shift = max_shift; shift >= 1; --shift)
        {
         const datetime bt = iTime(_Symbol, tf, shift);
         if(bt <= 0)
            continue;
         MqlDateTime dt;
         TimeToStruct(bt, dt);
         const int h = dt.hour;
         bool in_session = true;
         if(strategy_session_start_h != strategy_session_end_h)
           {
            if(strategy_session_start_h < strategy_session_end_h)
               in_session = (h >= strategy_session_start_h && h < strategy_session_end_h);
            else
               in_session = (h >= strategy_session_start_h || h < strategy_session_end_h);
           }

         if(in_session)
           {
            const double hi = iHigh(_Symbol, tf, shift);
            const double lo = iLow(_Symbol, tf, shift);
            const double cl = iClose(_Symbol, tf, shift);
            if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
               continue;
            if(!in_run)
              {
               in_run = true;
               run_hi = hi;
               run_low = lo;
              }
            else
              {
               if(hi > run_hi)
                  run_hi = hi;
               if(lo < run_low)
                  run_low = lo;
              }
            run_close = cl;
            run_end = bt;
           }
         else if(in_run)
           {
            prior_hi = latest_hi;
            prior_low = latest_low;
            latest_hi = run_hi;
            latest_low = run_low;
            latest_close = run_close;
            range_from = run_end;
            in_run = false;
           }
        }

      if(latest_hi > 0.0 && prior_hi > 0.0 &&
         latest_close <= prior_hi && latest_close >= prior_low)
        {
         range_high = prior_hi;
         range_low = prior_low;
        }
     }
   else
     {
      const ENUM_TIMEFRAMES htf = strategy_htf_timeframe;
      for(int shift = 1; shift <= strategy_range_scan_units; ++shift)
        {
         const datetime ht = iTime(_Symbol, htf, shift);
         const double close_htf = iClose(_Symbol, htf, shift);
         const double prev_hi = iHigh(_Symbol, htf, shift + 1);
         const double prev_low = iLow(_Symbol, htf, shift + 1);
         if(ht <= 0 || close_htf <= 0.0 || prev_hi <= 0.0 || prev_low <= 0.0)
            continue;
         if(close_htf <= prev_hi && close_htf >= prev_low)
           {
            range_high = prev_hi;
            range_low = prev_low;
            range_from = ht + PeriodSeconds(htf);
            break;
           }
        }
     }

   if(range_high <= range_low || range_from <= 0)
      return false;

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   bool bullish_pending = false;
   bool bearish_pending = false;
   int max_shift = strategy_pivot_fresh_bars;
   if(max_shift > bars - 3)
      max_shift = bars - 3;

   for(int shift = max_shift; shift >= 1; --shift)
     {
      const datetime bt = iTime(_Symbol, tf, shift);
      if(bt < range_from)
         continue;

      const double open_old = iOpen(_Symbol, tf, shift + 1);
      const double close_old = iClose(_Symbol, tf, shift + 1);
      const double open_new = iOpen(_Symbol, tf, shift);
      const double close_new = iClose(_Symbol, tf, shift);
      const double high_new = iHigh(_Symbol, tf, shift);
      const double low_new = iLow(_Symbol, tf, shift);
      if(open_old <= 0.0 || close_old <= 0.0 || open_new <= 0.0 ||
         close_new <= 0.0 || high_new <= 0.0 || low_new <= 0.0)
         continue;

      const bool old_bull = (close_old > open_old);
      const bool old_bear = (close_old < open_old);
      const bool new_bull = (close_new > open_new);
      const bool new_bear = (close_new < open_new);
      if(old_bull && new_bear)
         pivot_high = MathMax(iHigh(_Symbol, tf, shift + 1), high_new);
      if(old_bear && new_bull)
         pivot_low = MathMin(iLow(_Symbol, tf, shift + 1), low_new);

      if(high_new >= range_high && pivot_low > 0.0)
         bearish_pending = true;
      if(low_new <= range_low && pivot_high > 0.0)
         bullish_pending = true;

      if(shift != 1)
         continue;

      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(point <= 0.0)
         return false;

      if(bullish_pending && pivot_high > 0.0 && pivot_low > 0.0 && close_new > pivot_high)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         const double risk = entry - pivot_low;
         if(entry <= 0.0 || risk <= point)
            return false;
         req.type = QM_BUY;
         req.sl = pivot_low;
         req.tp = entry + risk * strategy_rr_target;
         req.reason = "RANGE_PIVOT_LONG";
         return true;
        }

      if(bearish_pending && pivot_high > 0.0 && pivot_low > 0.0 && close_new < pivot_low)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         const double risk = pivot_high - entry;
         if(entry <= 0.0 || risk <= point)
            return false;
         req.type = QM_SELL;
         req.sl = pivot_high;
         req.tp = entry - risk * strategy_rr_target;
         req.reason = "RANGE_PIVOT_SHORT";
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, or partial-close management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   bool have_position = false;
   bool is_buy = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      have_position = true;
      is_buy = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      break;
     }
   if(!have_position)
      return false;

   if(strategy_range_scan_units < 2 ||
      strategy_pivot_fresh_bars < 3 ||
      strategy_session_scan_bars < 10)
      return false;

   const ENUM_TIMEFRAMES tf = (ENUM_TIMEFRAMES)_Period;
   const int bars = Bars(_Symbol, tf);
   if(bars < strategy_pivot_fresh_bars + 5)
      return false;

   double range_high = 0.0;
   double range_low = 0.0;
   datetime range_from = 0;

   if(strategy_range_mode == 1)
     {
      double latest_hi = 0.0, latest_low = 0.0, latest_close = 0.0;
      double prior_hi = 0.0, prior_low = 0.0;
      double run_hi = 0.0, run_low = 0.0, run_close = 0.0;
      datetime run_end = 0;
      bool in_run = false;
      int max_session_shift = strategy_session_scan_bars;
      if(max_session_shift > bars - 2)
         max_session_shift = bars - 2;

      for(int shift = max_session_shift; shift >= 1; --shift)
        {
         const datetime bt = iTime(_Symbol, tf, shift);
         if(bt <= 0)
            continue;
         MqlDateTime dt;
         TimeToStruct(bt, dt);
         const int h = dt.hour;
         bool in_session = true;
         if(strategy_session_start_h != strategy_session_end_h)
           {
            if(strategy_session_start_h < strategy_session_end_h)
               in_session = (h >= strategy_session_start_h && h < strategy_session_end_h);
            else
               in_session = (h >= strategy_session_start_h || h < strategy_session_end_h);
           }

         if(in_session)
           {
            const double hi = iHigh(_Symbol, tf, shift);
            const double lo = iLow(_Symbol, tf, shift);
            const double cl = iClose(_Symbol, tf, shift);
            if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
               continue;
            if(!in_run)
              {
               in_run = true;
               run_hi = hi;
               run_low = lo;
              }
            else
              {
               if(hi > run_hi)
                  run_hi = hi;
               if(lo < run_low)
                  run_low = lo;
              }
            run_close = cl;
            run_end = bt;
           }
         else if(in_run)
           {
            prior_hi = latest_hi;
            prior_low = latest_low;
            latest_hi = run_hi;
            latest_low = run_low;
            latest_close = run_close;
            range_from = run_end;
            in_run = false;
           }
        }

      if(latest_hi > 0.0 && prior_hi > 0.0 &&
         latest_close <= prior_hi && latest_close >= prior_low)
        {
         range_high = prior_hi;
         range_low = prior_low;
        }
     }
   else
     {
      const ENUM_TIMEFRAMES htf = strategy_htf_timeframe;
      for(int shift = 1; shift <= strategy_range_scan_units; ++shift)
        {
         const datetime ht = iTime(_Symbol, htf, shift);
         const double close_htf = iClose(_Symbol, htf, shift);
         const double prev_hi = iHigh(_Symbol, htf, shift + 1);
         const double prev_low = iLow(_Symbol, htf, shift + 1);
         if(ht <= 0 || close_htf <= 0.0 || prev_hi <= 0.0 || prev_low <= 0.0)
            continue;
         if(close_htf <= prev_hi && close_htf >= prev_low)
           {
            range_high = prev_hi;
            range_low = prev_low;
            range_from = ht + PeriodSeconds(htf);
            break;
           }
        }
     }

   if(range_high <= range_low || range_from <= 0)
      return false;

   double pivot_high = 0.0;
   double pivot_low = 0.0;
   bool bullish_pending = false;
   bool bearish_pending = false;
   int max_shift = strategy_pivot_fresh_bars;
   if(max_shift > bars - 3)
      max_shift = bars - 3;

   for(int shift = max_shift; shift >= 1; --shift)
     {
      const datetime bt = iTime(_Symbol, tf, shift);
      if(bt < range_from)
         continue;

      const double open_old = iOpen(_Symbol, tf, shift + 1);
      const double close_old = iClose(_Symbol, tf, shift + 1);
      const double open_new = iOpen(_Symbol, tf, shift);
      const double close_new = iClose(_Symbol, tf, shift);
      const double high_new = iHigh(_Symbol, tf, shift);
      const double low_new = iLow(_Symbol, tf, shift);
      if(open_old <= 0.0 || close_old <= 0.0 || open_new <= 0.0 ||
         close_new <= 0.0 || high_new <= 0.0 || low_new <= 0.0)
         continue;

      const bool old_bull = (close_old > open_old);
      const bool old_bear = (close_old < open_old);
      const bool new_bull = (close_new > open_new);
      const bool new_bear = (close_new < open_new);
      if(old_bull && new_bear)
         pivot_high = MathMax(iHigh(_Symbol, tf, shift + 1), high_new);
      if(old_bear && new_bull)
         pivot_low = MathMin(iLow(_Symbol, tf, shift + 1), low_new);

      if(high_new >= range_high && pivot_low > 0.0)
         bearish_pending = true;
      if(low_new <= range_low && pivot_high > 0.0)
         bullish_pending = true;

      if(shift == 1)
        {
         if(is_buy && bearish_pending && pivot_low > 0.0 && close_new < pivot_low)
            return true;
         if(!is_buy && bullish_pending && pivot_high > 0.0 && close_new > pivot_high)
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
