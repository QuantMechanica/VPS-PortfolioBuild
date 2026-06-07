#property strict
#property version   "5.0"
#property description "QM5_11025 ATC Local High Low Fibonacci Levels"

#include <QM/QM_Common.mqh>

enum StrategyFibMode
  {
   FIB_MODE_BREAKTHROUGH = 0,
   FIB_MODE_REJECTION    = 1,
   FIB_MODE_BOTH         = 2
  };

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
input int    qm_ea_id                   = 11025;
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
input int             strategy_swing_lookback      = 24;
input int             strategy_swing_confirmation  = 3;
input int             strategy_atr_period          = 14;
input double          strategy_break_buffer_atr    = 0.10;
input double          strategy_min_range_atr       = 1.50;
input double          strategy_sl_atr_mult         = 1.00;
input double          strategy_tp_rr               = 1.50;
input StrategyFibMode strategy_mode                = FIB_MODE_BOTH;

int    g_last_fib_signal = 0;
string g_last_fib_reason = "";

bool Strategy_HasOpenPosition(ENUM_POSITION_TYPE &position_type)
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

bool Strategy_ReadBars(MqlRates &rates[])
  {
   const int lookback = MathMax(1, strategy_swing_lookback);
   const int conf = MathMax(1, strategy_swing_confirmation);
   const int need = lookback + (2 * conf) + 4;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_CURRENT, 1, need, rates); // perf-allowed: fixed swing-structure window, called only from framework new-bar entry hook.
   return (copied >= need);
  }

bool Strategy_FindActiveSwings(const MqlRates &rates[],
                               const int copied,
                               double &swing_high,
                               double &swing_low)
  {
   swing_high = 0.0;
   swing_low = 0.0;

   const int lookback = MathMax(1, strategy_swing_lookback);
   const int conf = MathMax(1, strategy_swing_confirmation);
   const int last_center = MathMin(copied - conf - 1, conf + lookback - 1);

   for(int center = conf; center <= last_center; ++center)
     {
      bool is_high = true;
      bool is_low = true;

      for(int j = 1; j <= conf; ++j)
        {
         if(rates[center].high <= rates[center - j].high || rates[center].high <= rates[center + j].high)
            is_high = false;
         if(rates[center].low >= rates[center - j].low || rates[center].low >= rates[center + j].low)
            is_low = false;
        }

      if(is_high && swing_high <= 0.0)
         swing_high = rates[center].high;
      if(is_low && swing_low <= 0.0)
         swing_low = rates[center].low;
      if(swing_high > 0.0 && swing_low > 0.0)
         return true;
     }

   return (swing_high > 0.0 && swing_low > 0.0);
  }

void Strategy_BuildFibLevels(const double swing_low,
                             const double swing_high,
                             double &levels[])
  {
   ArrayResize(levels, 5);
   const double range = swing_high - swing_low;
   levels[0] = swing_low + (range * 0.382);
   levels[1] = swing_low + (range * 0.500);
   levels[2] = swing_low + (range * 0.618);
   levels[3] = swing_low + (range * 1.000);
   levels[4] = swing_low + (range * 1.618);
  }

double Strategy_NextFibLevel(const double &levels[],
                             const int direction,
                             const double entry_level)
  {
   double best = 0.0;
   for(int i = 0; i < ArraySize(levels); ++i)
     {
      if(direction > 0 && levels[i] > entry_level)
        {
         if(best <= 0.0 || levels[i] < best)
            best = levels[i];
        }
      if(direction < 0 && levels[i] < entry_level)
        {
         if(best <= 0.0 || levels[i] > best)
            best = levels[i];
        }
     }
   return best;
  }

bool Strategy_DetectFibSignal(const MqlRates &rates[],
                              const double &levels[],
                              const double atr,
                              int &direction,
                              double &signal_level,
                              string &reason)
  {
   direction = 0;
   signal_level = 0.0;
   reason = "";

   const double close_last = rates[0].close;
   const double close_prev = rates[1].close;
   const double high_last = rates[0].high;
   const double low_last = rates[0].low;
   const double break_buffer = MathMax(0.0, strategy_break_buffer_atr) * atr;
   double best_distance = DBL_MAX;

   for(int i = 0; i < ArraySize(levels); ++i)
     {
      const double level = levels[i];
      if(level <= 0.0)
         continue;

      if(strategy_mode == FIB_MODE_BREAKTHROUGH || strategy_mode == FIB_MODE_BOTH)
        {
         if(close_prev <= level && close_last > level + break_buffer)
           {
            const double d = MathAbs(close_last - level);
            if(d < best_distance)
              {
               best_distance = d;
               direction = 1;
               signal_level = level;
               reason = "FIB_BREAK_LONG";
              }
           }
         if(close_prev >= level && close_last < level - break_buffer)
           {
            const double d = MathAbs(close_last - level);
            if(d < best_distance)
              {
               best_distance = d;
               direction = -1;
               signal_level = level;
               reason = "FIB_BREAK_SHORT";
              }
           }
        }

      if(strategy_mode == FIB_MODE_REJECTION || strategy_mode == FIB_MODE_BOTH)
        {
         if(high_last >= level && close_last < level)
           {
            const double d = MathAbs(close_last - level);
            if(d < best_distance)
              {
               best_distance = d;
               direction = -1;
               signal_level = level;
               reason = "FIB_REJECT_SHORT";
              }
           }
         if(low_last <= level && close_last > level)
           {
            const double d = MathAbs(close_last - level);
            if(d < best_distance)
              {
               best_distance = d;
               direction = 1;
               signal_level = level;
               reason = "FIB_REJECT_LONG";
              }
           }
        }
     }

   return (direction != 0 && signal_level > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   // Card defines no extra time or spread filter. Framework news and Friday
   // gates run before this hook; swing-range filtering is part of entry.
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

   g_last_fib_signal = 0;
   g_last_fib_reason = "";

   if(strategy_swing_lookback < 2 || strategy_swing_confirmation < 1 ||
      strategy_atr_period < 1 || strategy_min_range_atr <= 0.0 ||
      strategy_sl_atr_mult <= 0.0 || strategy_tp_rr <= 0.0)
      return false;

   MqlRates rates[];
   if(!Strategy_ReadBars(rates))
      return false;

   const int copied = ArraySize(rates);
   double swing_high = 0.0;
   double swing_low = 0.0;
   if(!Strategy_FindActiveSwings(rates, copied, swing_high, swing_low))
      return false;
   if(swing_high <= swing_low)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_CURRENT, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double swing_range = swing_high - swing_low;
   if(swing_range < strategy_min_range_atr * atr)
      return false;

   double levels[];
   Strategy_BuildFibLevels(swing_low, swing_high, levels);

   int direction = 0;
   double signal_level = 0.0;
   string reason = "";
   if(!Strategy_DetectFibSignal(rates, levels, atr, direction, signal_level, reason))
      return false;

   g_last_fib_signal = direction;
   g_last_fib_reason = reason;

   ENUM_POSITION_TYPE position_type;
   if(Strategy_HasOpenPosition(position_type))
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                       : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_distance = strategy_sl_atr_mult * atr;
   req.sl = (direction > 0) ? signal_level - sl_distance
                            : signal_level + sl_distance;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, req.sl);
   if(req.sl <= 0.0 || (direction > 0 && req.sl >= entry) || (direction < 0 && req.sl <= entry))
      req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(req.sl <= 0.0)
      return false;

   const double rr_tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_tp_rr);
   const double next_level = Strategy_NextFibLevel(levels, direction, signal_level);
   req.tp = rr_tp;
   if(next_level > 0.0)
     {
      if(direction > 0 && next_level > entry && next_level < rr_tp)
         req.tp = next_level;
      if(direction < 0 && next_level < entry && next_level > rr_tp)
         req.tp = next_level;
     }
   req.tp = QM_StopRulesNormalizePrice(_Symbol, req.tp);
   if(req.tp <= 0.0 || (direction > 0 && req.tp <= entry) || (direction < 0 && req.tp >= entry))
      return false;

   req.reason = reason;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   if(!Strategy_HasOpenPosition(position_type))
      return false;

   if(position_type == POSITION_TYPE_BUY && g_last_fib_signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && g_last_fib_signal > 0)
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
