#property strict
#property version   "5.0"
#property description "QM5_12428 EA31337 Bollinger Band Reentry"

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
input int    qm_ea_id                   = 12428;
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
input int    strategy_bb_period             = 24;    // EA31337 Bands default period.
input double strategy_bb_deviation          = 1.0;   // EA31337 Bands default deviation.
input double strategy_signal_open_level     = 0.0;   // Minimum middle-band change in price units.
input int    strategy_signal_open_method    = 4;     // Source default method 4.
input int    strategy_sl_pips               = 80;    // Source close-loss default.
input int    strategy_tp_pips               = 80;    // Source close-profit default.
input int    strategy_time_exit_bars        = 30;    // Source close-time absolute bars.
input int    strategy_atr_period            = 14;    // Fallback only if band/fixed stop is invalid.
input double strategy_atr_fallback_mult     = 2.0;   // ATR fallback stop multiple.
input int    strategy_band_stop_buffer_pips = 2;     // Buffer beyond excursion high/low.
input double strategy_spread_max_pips       = 4.0;   // Source max spread guard.

int g_last_closed_signal = 0;

double Strategy_PipsToDistance(const double pips)
  {
   if(pips <= 0.0)
      return 0.0;
   return QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(pips));
  }

int Strategy_DetectBandReentrySignal()
  {
   if(strategy_bb_period < 2 || strategy_bb_deviation <= 0.0)
      return 0;

   const double mid1 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_OPEN);
   const double mid2 = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_OPEN);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_OPEN);
   const double lower2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_OPEN);
   const double lower3 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 3, PRICE_OPEN);
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_OPEN);
   const double upper2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_OPEN);
   const double upper3 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 3, PRICE_OPEN);
   if(mid1 <= 0.0 || mid2 <= 0.0 || lower1 <= 0.0 || lower2 <= 0.0 ||
      lower3 <= 0.0 || upper1 <= 0.0 || upper2 <= 0.0 || upper3 <= 0.0)
      return 0;

   const double low1 = iLow(_Symbol, _Period, 1);     // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double low2 = iLow(_Symbol, _Period, 2);     // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double low3 = iLow(_Symbol, _Period, 3);     // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double high1 = iHigh(_Symbol, _Period, 1);   // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double high2 = iHigh(_Symbol, _Period, 2);   // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double high3 = iHigh(_Symbol, _Period, 3);   // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   if(low1 <= 0.0 || low2 <= 0.0 || low3 <= 0.0 || high1 <= 0.0 ||
      high2 <= 0.0 || high3 <= 0.0 || close1 <= 0.0)
      return 0;

   const double lookback_low = MathMin(low1, MathMin(low2, low3));
   const double lookback_high = MathMax(high1, MathMax(high2, high3));
   const double lower_ref = MathMin(lower1, MathMin(lower2, lower3));
   const double upper_ref = MathMax(upper1, MathMax(upper2, upper3));
   const double middle_change = mid1 - mid2;

   const bool method4_long_ok = (strategy_signal_open_method != 4 || lookback_low < mid1);
   const bool method4_short_ok = (strategy_signal_open_method != 4 || lookback_high > mid1);

   const bool long_signal = (lookback_low < lower_ref &&
                             close1 > lower1 &&
                             middle_change > strategy_signal_open_level &&
                             method4_long_ok);
   const bool short_signal = (lookback_high > upper_ref &&
                              close1 < upper1 &&
                              middle_change < -strategy_signal_open_level &&
                              method4_short_ok);

   if(long_signal && !short_signal)
      return 1;
   if(short_signal && !long_signal)
      return -1;
   return 0;
  }

double Strategy_BuildStop(const QM_OrderType side, const double entry)
  {
   const double buffer = Strategy_PipsToDistance((double)strategy_band_stop_buffer_pips);
   const double fixed_sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);

   if(QM_OrderTypeIsBuy(side))
     {
      const double low1 = iLow(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
      const double low2 = iLow(_Symbol, _Period, 2); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
      const double low3 = iLow(_Symbol, _Period, 3); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
      const double excursion_low = MathMin(low1, MathMin(low2, low3));
      if(fixed_sl > 0.0 && excursion_low > 0.0 && fixed_sl < excursion_low && fixed_sl < entry)
         return fixed_sl;
      const double band_sl = excursion_low - buffer;
      if(band_sl > 0.0 && band_sl < entry)
         return QM_StopRulesNormalizePrice(_Symbol, band_sl);
      return QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_fallback_mult);
     }

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double high2 = iHigh(_Symbol, _Period, 2); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double high3 = iHigh(_Symbol, _Period, 3); // perf-allowed: fixed closed-bar OHLC inside Strategy_EntrySignal's framework new-bar gate.
   const double excursion_high = MathMax(high1, MathMax(high2, high3));
   if(fixed_sl > 0.0 && excursion_high > 0.0 && fixed_sl > excursion_high && fixed_sl > entry)
      return fixed_sl;
   const double band_sl = excursion_high + buffer;
   if(band_sl > entry)
      return QM_StopRulesNormalizePrice(_Symbol, band_sl);
   return QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_fallback_mult);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double spread_cap = Strategy_PipsToDistance(strategy_spread_max_pips);
   const double spread = ask - bid;
   if(spread_cap > 0.0 && ask > bid && spread > spread_cap)
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

   g_last_closed_signal = Strategy_DetectBandReentrySignal();
   if(g_last_closed_signal == 0)
      return false;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const QM_OrderType side = (g_last_closed_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = Strategy_BuildStop(side, entry);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   if(QM_OrderTypeIsBuy(side) && (sl >= entry || tp <= entry))
      return false;
   if(!QM_OrderTypeIsBuy(side) && (sl <= entry || tp >= entry))
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = (g_last_closed_signal > 0) ? "bb_reentry_long" : "bb_reentry_short";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card defines fixed SL/TP and time/opposite-signal exits, no trailing.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int period_seconds = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   const datetime now_time = TimeCurrent();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_last_closed_signal < 0)
         return true;
      if(type == POSITION_TYPE_SELL && g_last_closed_signal > 0)
         return true;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_time_exit_bars > 0 && period_seconds > 0 &&
         open_time > 0 && now_time - open_time >= strategy_time_exit_bars * period_seconds)
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
