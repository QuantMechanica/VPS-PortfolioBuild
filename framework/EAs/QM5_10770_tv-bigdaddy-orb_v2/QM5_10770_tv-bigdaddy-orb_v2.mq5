#property strict
#property version   "5.0"
#property description "QM5_10770_v2 TradingView Big Daddy Max ORB"

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
input int    qm_ea_id                   = 10770;
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
enum StrategyORBMode
  {
   STRATEGY_ORB_CONTINUATION = 0,
   STRATEGY_ORB_REVERSAL     = 1,
   STRATEGY_ORB_BOTH         = 2
  };

enum StrategyORBStopMode
  {
   STRATEGY_STOP_MIDPOINT      = 0,
   STRATEGY_STOP_OPPOSITE_SIDE = 1,
   STRATEGY_STOP_FAILED_WICK   = 2
  };

input int                 strategy_session_start_hhmm       = 930;
input int                 strategy_trading_window_minutes   = 120;
input int                 strategy_full_session_end_hhmm    = 1600;
input bool                strategy_use_full_session         = false;
input int                 strategy_orb_window_minutes       = 15;
input StrategyORBMode     strategy_mode                     = STRATEGY_ORB_CONTINUATION;
input StrategyORBStopMode strategy_stop_mode                = STRATEGY_STOP_MIDPOINT;
input double              strategy_rr_target                = 2.0;
input bool                strategy_close_at_session_end     = true;
input double              strategy_max_spread_points        = 0.0;

int      g_strategy_session_key       = 0;
bool     g_strategy_or_has_range      = false;
bool     g_strategy_or_ready          = false;
bool     g_strategy_broke_above       = false;
bool     g_strategy_broke_below       = false;
double   g_strategy_or_high           = 0.0;
double   g_strategy_or_low            = 0.0;
double   g_strategy_failed_high_wick  = 0.0;
double   g_strategy_failed_low_wick   = 0.0;
datetime g_strategy_or_locked_at      = 0;

int Strategy_HhmmToMinutes(const int hhmm)
  {
   const int hh = hhmm / 100;
   const int mm = hhmm % 100;
   if(hh < 0 || hh > 23 || mm < 0 || mm > 59)
      return -1;
   return hh * 60 + mm;
  }

int Strategy_HhmmFromTime(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
  }

int Strategy_DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_TimeInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(start_hhmm);
   const int end_m = Strategy_HhmmToMinutes(end_hhmm);
   if(now_m < 0 || start_m < 0 || end_m < 0 || start_m == end_m)
      return false;
   if(start_m < end_m)
      return (now_m >= start_m && now_m < end_m);
   return (now_m >= start_m || now_m < end_m);
  }

int Strategy_TradingEndHhmm()
  {
   if(strategy_use_full_session)
      return strategy_full_session_end_hhmm;

   const int start_m = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   if(start_m < 0)
      return strategy_full_session_end_hhmm;

   const int window = MathMax(5, MathMin(1440, strategy_trading_window_minutes));
   const int end_m = (start_m + window) % 1440;
   return (end_m / 60) * 100 + (end_m % 60);
  }

int Strategy_MinutesFromSessionStart(const int hhmm)
  {
   const int now_m = Strategy_HhmmToMinutes(hhmm);
   const int start_m = Strategy_HhmmToMinutes(strategy_session_start_hhmm);
   if(now_m < 0 || start_m < 0)
      return -1;
   int delta = now_m - start_m;
   if(delta < 0)
      delta += 1440;
   return delta;
  }

void Strategy_ResetSession(const int day_key)
  {
   g_strategy_session_key = day_key;
   g_strategy_or_has_range = false;
   g_strategy_or_ready = false;
   g_strategy_broke_above = false;
   g_strategy_broke_below = false;
   g_strategy_or_high = 0.0;
   g_strategy_or_low = 0.0;
   g_strategy_failed_high_wick = 0.0;
   g_strategy_failed_low_wick = 0.0;
   g_strategy_or_locked_at = 0;
  }

void Strategy_ResetSessionIfNeeded(const datetime t)
  {
   const int day_key = Strategy_DayKey(t);
   if(day_key != g_strategy_session_key)
      Strategy_ResetSession(day_key);
  }

bool Strategy_ReadClosedBars(MqlRates &bar1, MqlRates &bar2)
  {
   MqlRates bars[2];
   if(CopyRates(_Symbol, (ENUM_TIMEFRAMES)_Period, 1, 2, bars) != 2) // perf-allowed: two closed bars for ORB state and close-confirmed breakout, called after QM_IsNewBar().
      return false;
   bar1 = bars[0];
   bar2 = bars[1];
   return true;
  }

bool Strategy_HasOurOpenPosition()
  {
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
      return true;
     }
   return false;
  }

bool Strategy_SpreadAllowed()
  {
   if(strategy_max_spread_points <= 0.0)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(point <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask < bid)
      return false;

   return ((ask - bid) / point) <= strategy_max_spread_points;
  }

void Strategy_AdvanceOpeningRange(const MqlRates &bar)
  {
   Strategy_ResetSessionIfNeeded(bar.time);

   const int hhmm = Strategy_HhmmFromTime(bar.time);
   if(!Strategy_TimeInWindow(hhmm, strategy_session_start_hhmm, Strategy_TradingEndHhmm()))
      return;

   const int elapsed = Strategy_MinutesFromSessionStart(hhmm);
   if(elapsed < 0)
      return;

   const int orb_minutes = MathMax(5, MathMin(60, strategy_orb_window_minutes));
   const int bar_minutes = MathMax(1, PeriodSeconds((ENUM_TIMEFRAMES)_Period) / 60);

   if(elapsed < orb_minutes)
     {
      if(!g_strategy_or_has_range)
        {
         g_strategy_or_high = bar.high;
         g_strategy_or_low = bar.low;
         g_strategy_or_has_range = true;
        }
      else
        {
         g_strategy_or_high = MathMax(g_strategy_or_high, bar.high);
         g_strategy_or_low = MathMin(g_strategy_or_low, bar.low);
        }

      if(elapsed + bar_minutes >= orb_minutes)
        {
         g_strategy_or_ready = true;
         g_strategy_or_locked_at = bar.time + bar_minutes * 60;
        }
      return;
     }

   if(g_strategy_or_has_range && !g_strategy_or_ready)
     {
      g_strategy_or_ready = true;
      g_strategy_or_locked_at = bar.time;
     }
  }

void Strategy_UpdateBreakoutFlags(const MqlRates &bar)
  {
   if(!g_strategy_or_ready || !g_strategy_or_has_range)
      return;

   if(bar.high > g_strategy_or_high)
     {
      g_strategy_broke_above = true;
      g_strategy_failed_high_wick = MathMax(g_strategy_failed_high_wick, bar.high);
     }
   if(bar.low < g_strategy_or_low)
     {
      g_strategy_broke_below = true;
      if(g_strategy_failed_low_wick <= 0.0)
         g_strategy_failed_low_wick = bar.low;
      else
         g_strategy_failed_low_wick = MathMin(g_strategy_failed_low_wick, bar.low);
     }
  }

bool Strategy_BuildRequest(const bool want_long,
                           const bool reversal_signal,
                           const MqlRates &bar,
                           QM_EntryRequest &req)
  {
   const double entry = want_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || strategy_rr_target <= 0.0 || g_strategy_or_high <= g_strategy_or_low)
      return false;

   const double midpoint = (g_strategy_or_high + g_strategy_or_low) * 0.5;
   double sl = 0.0;
   if(strategy_stop_mode == STRATEGY_STOP_FAILED_WICK && reversal_signal)
      sl = want_long ? g_strategy_failed_low_wick : g_strategy_failed_high_wick;
   else if(strategy_stop_mode == STRATEGY_STOP_OPPOSITE_SIDE)
      sl = want_long ? g_strategy_or_low : g_strategy_or_high;
   else
      sl = midpoint;

   if(sl <= 0.0)
      return false;
   if(want_long && sl >= entry)
      return false;
   if(!want_long && sl <= entry)
      return false;

   const double tp = QM_TakeRR(_Symbol, want_long ? QM_BUY : QM_SELL, entry, sl, strategy_rr_target);
   if(tp <= 0.0)
      return false;
   if(want_long && tp <= entry)
      return false;
   if(!want_long && tp >= entry)
      return false;

   req.type = want_long ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = reversal_signal
                ? (want_long ? "TV_BIGDADDY_ORB_REVERSAL_LONG" : "TV_BIGDADDY_ORB_REVERSAL_SHORT")
                : (want_long ? "TV_BIGDADDY_ORB_CONTINUATION_LONG" : "TV_BIGDADDY_ORB_CONTINUATION_SHORT");
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   Strategy_ResetSessionIfNeeded(TimeCurrent());

   if(Strategy_HasOurOpenPosition())
      return false;

   if(!Strategy_SpreadAllowed())
      return true;

   const int hhmm = Strategy_HhmmFromTime(TimeCurrent());
   if(!Strategy_TimeInWindow(hhmm, strategy_session_start_hhmm, Strategy_TradingEndHhmm()))
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

   MqlRates bar1, bar2;
   if(!Strategy_ReadClosedBars(bar1, bar2))
      return false;

   Strategy_AdvanceOpeningRange(bar1);

   if(Strategy_HasOurOpenPosition())
      return false;
   if(!g_strategy_or_has_range || !g_strategy_or_ready || g_strategy_or_high <= g_strategy_or_low)
      return false;
   if(bar1.time < g_strategy_or_locked_at)
      return false;

   const int hhmm = Strategy_HhmmFromTime(bar1.time);
   if(!Strategy_TimeInWindow(hhmm, strategy_session_start_hhmm, Strategy_TradingEndHhmm()))
      return false;

   const bool continuation_enabled = (strategy_mode == STRATEGY_ORB_CONTINUATION || strategy_mode == STRATEGY_ORB_BOTH);
   const bool reversal_enabled = (strategy_mode == STRATEGY_ORB_REVERSAL || strategy_mode == STRATEGY_ORB_BOTH);

   if(continuation_enabled)
     {
      const bool long_cont = (bar2.close <= g_strategy_or_high && bar1.close > g_strategy_or_high);
      const bool short_cont = (bar2.close >= g_strategy_or_low && bar1.close < g_strategy_or_low);
      if(long_cont && Strategy_BuildRequest(true, false, bar1, req))
         return true;
      if(short_cont && Strategy_BuildRequest(false, false, bar1, req))
         return true;
     }

   Strategy_UpdateBreakoutFlags(bar1);

   if(reversal_enabled)
     {
      const bool long_rev = (g_strategy_broke_below && bar1.close > g_strategy_or_low && bar1.close < g_strategy_or_high);
      const bool short_rev = (g_strategy_broke_above && bar1.close < g_strategy_or_high && bar1.close > g_strategy_or_low);
      if(long_rev && Strategy_BuildRequest(true, true, bar1, req))
        {
         g_strategy_broke_below = false;
         return true;
        }
      if(short_rev && Strategy_BuildRequest(false, true, bar1, req))
        {
         g_strategy_broke_above = false;
         return true;
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, break-even, partial-close, or pyramiding.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!strategy_close_at_session_end)
      return false;
   if(!Strategy_HasOurOpenPosition())
      return false;

   const int hhmm = Strategy_HhmmFromTime(TimeCurrent());
   return !Strategy_TimeInWindow(hhmm, strategy_session_start_hhmm, Strategy_TradingEndHhmm());
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
