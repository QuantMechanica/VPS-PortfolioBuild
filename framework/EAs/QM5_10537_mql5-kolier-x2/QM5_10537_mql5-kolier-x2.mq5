#property strict
#property version   "5.0"
#property description "QM5_10537 MQL5 Kolier SuperTrend X2"
// rework v2 2026-06-16 — fast-flip read from ONE reconstruction (dir@1 vs dir@2);
// the old double independent-window reconstruction almost never produced a
// fast_prev!=fast_now flip on M30 (both windows converge on shared history),
// collapsing entries to ~1/yr. Single-pass capture restores card 30-70/yr intent.

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
input int    qm_ea_id                   = 10537;
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
input ENUM_TIMEFRAMES strategy_fast_timeframe = PERIOD_M30;
input ENUM_TIMEFRAMES strategy_slow_timeframe = PERIOD_H6;
input int    strategy_atr_period       = 10;
input double strategy_atr_multiplier   = 3.0;
input double strategy_take_profit_rr   = 2.0;
input int    strategy_supertrend_bars  = 120;

bool g_kolier_exit_signal = false;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Reconstruct the Kolier-style SuperTrend over a single bounded warmup window
// and report the direction at TWO target shifts (newer `shift_a`, older
// `shift_b`) from the SAME pass. Reading both directions from one reconstruction
// is what makes a one-bar color change detectable: dir@1 vs dir@2 differ exactly
// when the newest closed bar crossed the active band. Two independent
// reconstructions (the v1 bug) converge on their shared history and almost never
// disagree, so flips were effectively never seen.
//
//   shift_a < shift_b ; both >= 1.
// Returns false if history/ATR is not yet available (caller treats as no-signal).
bool Strategy_SuperTrendDirections(const ENUM_TIMEFRAMES tf,
                                   const int atr_period,
                                   const double atr_mult,
                                   const int shift_a,
                                   const int shift_b,
                                   int &dir_a,
                                   int &dir_b)
  {
   dir_a = 0;
   dir_b = 0;
   if(atr_period <= 0 || atr_mult <= 0.0 || shift_a < 1 || shift_b <= shift_a)
      return false;

   const int bars = MathMax(strategy_supertrend_bars, atr_period + 20);
   double final_upper = 0.0;
   double final_lower = 0.0;
   int trend = 0;

   for(int s = shift_a + bars; s >= shift_a; --s)
     {
      const double high = iHigh(_Symbol, tf, s);
      const double low = iLow(_Symbol, tf, s);
      const double close = iClose(_Symbol, tf, s);
      const double prev_close = iClose(_Symbol, tf, s + 1);
      const double atr = QM_ATR(_Symbol, tf, atr_period, s);
      if(high <= 0.0 || low <= 0.0 || close <= 0.0 || prev_close <= 0.0 || atr <= 0.0)
         return false;

      const double mid = (high + low) * 0.5;
      const double basic_upper = mid + atr_mult * atr;
      const double basic_lower = mid - atr_mult * atr;

      if(s == shift_a + bars)
        {
         final_upper = basic_upper;
         final_lower = basic_lower;
         trend = (close >= mid) ? 1 : -1;
        }
      else
        {
         final_upper = (basic_upper < final_upper || prev_close > final_upper) ? basic_upper : final_upper;
         final_lower = (basic_lower > final_lower || prev_close < final_lower) ? basic_lower : final_lower;

         if(trend < 0 && close > final_upper)
            trend = 1;
         else if(trend > 0 && close < final_lower)
            trend = -1;
        }

      // Capture the direction as the same forward pass reaches each target bar.
      if(s == shift_b)
         dir_b = trend;
      if(s == shift_a)
         dir_a = trend;
     }

   return (dir_a != 0 && dir_b != 0);
  }

// Single-shift convenience: direction of the slow-trend filter at `shift`.
int Strategy_SuperTrendDirection(const ENUM_TIMEFRAMES tf,
                                 const int atr_period,
                                 const double atr_mult,
                                 const int shift)
  {
   int dir_a = 0;
   int dir_b = 0;
   // Read shift and shift+1 in one pass; we only need shift here.
   if(!Strategy_SuperTrendDirections(tf, atr_period, atr_mult, shift, shift + 1, dir_a, dir_b))
      return 0;
   return dir_a;
  }

bool Strategy_FindOurPosition(ENUM_POSITION_TYPE &position_type)
  {
   position_type = POSITION_TYPE_BUY;
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
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

   ENUM_POSITION_TYPE position_type;
   const bool has_position = Strategy_FindOurPosition(position_type);

   int fast_now = 0;
   int fast_prev = 0;
   if(!Strategy_SuperTrendDirections(strategy_fast_timeframe,
                                     strategy_atr_period,
                                     strategy_atr_multiplier,
                                     1, 2, fast_now, fast_prev))
      return false;
   const int slow_now = Strategy_SuperTrendDirection(strategy_slow_timeframe,
                                                     strategy_atr_period,
                                                     strategy_atr_multiplier,
                                                     1);
   if(fast_now == 0 || fast_prev == 0 || slow_now == 0)
      return false;

   if(has_position)
     {
      g_kolier_exit_signal =
         (position_type == POSITION_TYPE_BUY && (fast_now < 0 || slow_now < 0)) ||
         (position_type == POSITION_TYPE_SELL && (fast_now > 0 || slow_now > 0));
      return false;
     }

   g_kolier_exit_signal = false;

   const bool bullish_flip = (slow_now > 0 && fast_now > 0 && fast_prev < 0);
   const bool bearish_flip = (slow_now < 0 && fast_now < 0 && fast_prev > 0);
   if(!bullish_flip && !bearish_flip)
      return false;

   req.type = bullish_flip ? QM_BUY : QM_SELL;
   const double entry = bullish_flip ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                     : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_multiplier);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
   req.reason = bullish_flip ? "KOLIER_X2_LONG" : "KOLIER_X2_SHORT";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_FindOurPosition(position_type))
     {
      g_kolier_exit_signal = false;
      return false;
     }

   return g_kolier_exit_signal;
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
