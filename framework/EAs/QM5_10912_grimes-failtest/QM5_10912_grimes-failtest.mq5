#property strict
#property version   "5.0"
#property description "QM5_10912 Grimes Failure Test"

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
input int    qm_ea_id                   = 10912;
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
input int    strategy_lookback_bars       = 20;
input int    strategy_atr_period          = 14;
input double strategy_break_buffer_atr    = 0.10;
input double strategy_stop_buffer_atr     = 0.20;
input double strategy_max_stop_atr        = 2.00;
input double strategy_min_range_atr       = 1.50;
input double strategy_max_range_atr       = 6.00;
input int    strategy_no_progress_bars    = 6;
input double strategy_no_progress_r       = 0.50;
input int    strategy_time_exit_bars      = 16;
input double strategy_max_target_r        = 2.00;
input double strategy_outer_close_fraction = 0.20;

bool Strategy_RangeLevels(const int start_shift,
                          const int bars,
                          double &resistance,
                          double &support)
  {
   if(start_shift < 1 || bars < 1)
      return false;

   resistance = -DBL_MAX;
   support = DBL_MAX;

   // perf-allowed: bounded bespoke structure scan over the card's 20-bar range,
   // called from the framework closed-bar entry path.
   for(int shift = start_shift; shift < start_shift + bars; ++shift)
     {
      const double high = iHigh(_Symbol, _Period, shift); // perf-allowed
      const double low = iLow(_Symbol, _Period, shift); // perf-allowed
      if(high <= 0.0 || low <= 0.0)
         return false;
      resistance = MathMax(resistance, high);
      support = MathMin(support, low);
     }

   return (resistance > support && support < DBL_MAX && resistance > 0.0);
  }

double Strategy_ATR(const int shift)
  {
   return QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, shift);
  }

bool Strategy_RangeContextOK(const double resistance,
                             const double support,
                             const double atr)
  {
   if(atr <= 0.0 || resistance <= support)
      return false;

   const double width = resistance - support;
   return (width >= strategy_min_range_atr * atr &&
           width <= strategy_max_range_atr * atr);
  }

bool Strategy_CloseOuterBreakoutSide(const bool short_signal,
                                     const int signal_shift)
  {
   // perf-allowed: single closed-bar OHLC read for the card's candle-location filter.
   const double high = iHigh(_Symbol, _Period, signal_shift); // perf-allowed
   const double low = iLow(_Symbol, _Period, signal_shift); // perf-allowed
   const double close = iClose(_Symbol, _Period, signal_shift); // perf-allowed
   const double range = high - low;
   if(high <= 0.0 || low <= 0.0 || close <= 0.0 || range <= 0.0)
      return true;

   const double f = MathMax(0.0, MathMin(strategy_outer_close_fraction, 0.49));
   if(short_signal)
      return (close >= low + (1.0 - f) * range);
   return (close <= low + f * range);
  }

bool Strategy_BuildRequest(const bool long_signal,
                           const double failed_extreme,
                           const double resistance,
                           const double support,
                           const double atr,
                           const string reason,
                           QM_EntryRequest &req)
  {
   const double entry = long_signal ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double raw_sl = long_signal ? failed_extreme - strategy_stop_buffer_atr * atr
                                     : failed_extreme + strategy_stop_buffer_atr * atr;
   const double sl = NormalizeDouble(raw_sl, _Digits);
   const double r = MathAbs(entry - sl);
   if(r <= 0.0 || r > strategy_max_stop_atr * atr)
      return false;

   const double natural_target = long_signal ? resistance : support;
   double target_dist = long_signal ? (natural_target - entry) : (entry - natural_target);
   if(target_dist <= 0.0)
      return false;
   const double max_target_dist = strategy_max_target_r * r;
   if(target_dist > max_target_dist)
      target_dist = max_target_dist;

   const double tp = NormalizeDouble(long_signal ? entry + target_dist
                                                 : entry - target_dist, _Digits);
   if(long_signal && tp <= entry)
      return false;
   if(!long_signal && tp >= entry)
      return false;

   req.type = long_signal ? QM_BUY : QM_SELL;
   req.price = 0.0;
   req.sl = sl;
   req.tp = tp;
   req.reason = reason;
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &position_type,
                                double &open_price,
                                double &sl,
                                datetime &open_time)
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

      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_MaxHighSinceEntry(const int closed_bars)
  {
   double highest = -DBL_MAX;
   const int bars = MathMax(0, MathMin(closed_bars, strategy_no_progress_bars));
   // perf-allowed: bounded six-bar progress check for the card's time-stop.
   for(int shift = 1; shift <= bars; ++shift)
      highest = MathMax(highest, iHigh(_Symbol, _Period, shift)); // perf-allowed
   return highest;
  }

double Strategy_MinLowSinceEntry(const int closed_bars)
  {
   double lowest = DBL_MAX;
   const int bars = MathMax(0, MathMin(closed_bars, strategy_no_progress_bars));
   // perf-allowed: bounded six-bar progress check for the card's time-stop.
   for(int shift = 1; shift <= bars; ++shift)
      lowest = MathMin(lowest, iLow(_Symbol, _Period, shift)); // perf-allowed
   return lowest;
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
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_lookback_bars < 2 || strategy_atr_period < 2)
      return false;

   double resistance = 0.0;
   double support = 0.0;
   if(!Strategy_RangeLevels(2, strategy_lookback_bars, resistance, support))
      return false;

   const double atr = Strategy_ATR(1);
   if(!Strategy_RangeContextOK(resistance, support, atr))
      return false;

   // perf-allowed: single closed-bar OHLC read for the failure-test trigger.
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed
   const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0)
      return false;

   const double break_buffer = strategy_break_buffer_atr * atr;

   if(high1 >= resistance + break_buffer &&
      close1 < resistance &&
      !Strategy_CloseOuterBreakoutSide(true, 1))
     {
      if(Strategy_BuildRequest(false, high1, resistance, support, atr,
                               "GRIMES_FAILTEST_SHORT_SAME_BAR", req))
         return true;
     }

   if(low1 <= support - break_buffer &&
      close1 > support &&
      !Strategy_CloseOuterBreakoutSide(false, 1))
     {
      if(Strategy_BuildRequest(true, low1, resistance, support, atr,
                               "GRIMES_FAILTEST_LONG_SAME_BAR", req))
         return true;
     }

   double prev_resistance = 0.0;
   double prev_support = 0.0;
   if(!Strategy_RangeLevels(3, strategy_lookback_bars, prev_resistance, prev_support))
      return false;

   const double atr2 = Strategy_ATR(2);
   if(atr2 <= 0.0)
      return false;

   // perf-allowed: previous closed bar OHLC read for the one-bar failed-break variant.
   const double high2 = iHigh(_Symbol, _Period, 2); // perf-allowed
   const double low2 = iLow(_Symbol, _Period, 2); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   if(high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0)
      return false;

   const double break_buffer2 = strategy_break_buffer_atr * atr2;
   if(high2 >= prev_resistance + break_buffer2 &&
      close2 > prev_resistance &&
      close1 < prev_resistance &&
      !Strategy_CloseOuterBreakoutSide(true, 1))
     {
      const double failed_high = MathMax(high1, high2);
      if(Strategy_BuildRequest(false, failed_high, resistance, support, atr,
                               "GRIMES_FAILTEST_SHORT_NEXT_BAR", req))
         return true;
     }

   if(low2 <= prev_support - break_buffer2 &&
      close2 < prev_support &&
      close1 > prev_support &&
      !Strategy_CloseOuterBreakoutSide(false, 1))
     {
      const double failed_low = MathMin(low1, low2);
      if(Strategy_BuildRequest(true, failed_low, resistance, support, atr,
                               "GRIMES_FAILTEST_LONG_NEXT_BAR", req))
         return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial, or break-even management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type;
   double open_price = 0.0;
   double sl = 0.0;
   datetime open_time = 0;
   if(!Strategy_SelectOurPosition(position_type, open_price, sl, open_time))
      return false;

   const int entry_shift = iBarShift(_Symbol, _Period, open_time, false);
   if(entry_shift < 0)
      return false;

   if(entry_shift >= strategy_time_exit_bars)
      return true;

   const double r = MathAbs(open_price - sl);
   if(r <= 0.0)
      return false;

   if(entry_shift >= strategy_no_progress_bars)
     {
      const bool is_long = (position_type == POSITION_TYPE_BUY);
      const double favorable = is_long ? (Strategy_MaxHighSinceEntry(entry_shift) - open_price)
                                       : (open_price - Strategy_MinLowSinceEntry(entry_shift));
      if(favorable < strategy_no_progress_r * r)
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
