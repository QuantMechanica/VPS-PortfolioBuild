#property strict
#property version   "5.0"
#property description "QM5_9237 MQL5 Geometric Mean Band Cross"

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
input int    qm_ea_id                   = 9237;
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
input int    strategy_gm_period              = 20;
input double strategy_band_deviation_mult    = 2.0;
input int    strategy_atr_period             = 14;
input double strategy_atr_sl_mult            = 1.6;
input double strategy_min_band_atr_mult      = 1.0;
input double strategy_midline_min_rr         = 0.8;
input double strategy_fallback_rr            = 1.8;
input int    strategy_max_hold_bars          = 24;
input double strategy_max_spread_atr_mult    = 0.25;

double g_cached_gm_midline = 0.0;
double g_cached_upper_band = 0.0;
double g_cached_lower_band = 0.0;
double g_cached_close_1    = 0.0;

bool Strategy_GMBands(const int shift,
                      double &gm_midline,
                      double &inverse_gm,
                      double &upper_band,
                      double &lower_band)
  {
   gm_midline = 0.0;
   inverse_gm = 0.0;
   upper_band = 0.0;
   lower_band = 0.0;

   const int period = strategy_gm_period;
   if(period < 2 || period > 500 || strategy_band_deviation_mult <= 0.0)
      return false;

   double sum_log = 0.0;
   double close_values[];
   ArrayResize(close_values, period);

   for(int i = 0; i < period; ++i)
     {
      const double c = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, shift + i); // perf-allowed: bounded GM close window; EntrySignal is called only after the framework QM_IsNewBar gate.
      if(c <= 0.0 || !MathIsValidNumber(c))
         return false;
      close_values[i] = c;
      sum_log += MathLog(c);
     }

   gm_midline = MathExp(sum_log / period);
   if(gm_midline <= 0.0 || !MathIsValidNumber(gm_midline))
      return false;

   inverse_gm = 1.0 / gm_midline;
   if(inverse_gm <= 0.0 || !MathIsValidNumber(inverse_gm))
      return false;

   double variance_sum = 0.0;
   for(int i = 0; i < period; ++i)
     {
      const double d = close_values[i] - gm_midline;
      variance_sum += d * d;
     }

   const double stdev = MathSqrt(variance_sum / MathMax(1, period - 1));
   if(stdev <= 0.0 || !MathIsValidNumber(stdev))
      return false;

   upper_band = QM_StopRulesNormalizePrice(_Symbol, gm_midline + strategy_band_deviation_mult * stdev);
   lower_band = QM_StopRulesNormalizePrice(_Symbol, gm_midline - strategy_band_deviation_mult * stdev);
   gm_midline = QM_StopRulesNormalizePrice(_Symbol, gm_midline);

   return (upper_band > gm_midline && gm_midline > lower_band && lower_band > 0.0);
  }

bool Strategy_FindOurPosition(ulong &ticket,
                              ENUM_POSITION_TYPE &position_type,
                              datetime &open_time)
  {
   ticket = 0;
   position_type = POSITION_TYPE_BUY;
   open_time = 0;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

double Strategy_EntryPriceEstimate(const QM_OrderType type)
  {
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(type == QM_BUY)
     {
      if(ask > 0.0)
         return ask;
      return bid;
     }

   if(bid > 0.0)
      return bid;
   return ask;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_atr_mult <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(bid <= 0.0 || ask <= 0.0)
      return true;

   if(ask > bid)
     {
      const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > atr * strategy_max_spread_atr_mult)
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

   double gm1 = 0.0, inverse1 = 0.0, upper1 = 0.0, lower1 = 0.0;
   double gm2 = 0.0, inverse2 = 0.0, upper2 = 0.0, lower2 = 0.0;
   if(!Strategy_GMBands(1, gm1, inverse1, upper1, lower1))
      return false;
   if(!Strategy_GMBands(2, gm2, inverse2, upper2, lower2))
      return false;
   if(inverse1 <= 0.0 || inverse2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 1); // perf-allowed: single closed-bar cross close inside framework QM_IsNewBar-gated hook.
   const double close2 = iClose(_Symbol, (ENUM_TIMEFRAMES)_Period, 2); // perf-allowed: single closed-bar cross close inside framework QM_IsNewBar-gated hook.
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   g_cached_gm_midline = gm1;
   g_cached_upper_band = upper1;
   g_cached_lower_band = lower1;
   g_cached_close_1 = close1;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   if((upper1 - lower1) < atr * strategy_min_band_atr_mult)
      return false;

   QM_OrderType side = QM_BUY;
   bool has_signal = false;
   if(close2 < lower2 && close1 > lower1)
     {
      side = QM_BUY;
      has_signal = true;
     }
   else if(close2 > upper2 && close1 < upper1)
     {
      side = QM_SELL;
      has_signal = true;
     }

   if(!has_signal)
      return false;

   const double entry = Strategy_EntryPriceEstimate(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double risk = MathAbs(entry - sl);
   if(risk <= 0.0)
      return false;

   double tp = 0.0;
   if(side == QM_BUY && gm1 > entry + risk * strategy_midline_min_rr)
      tp = gm1;
   else if(side == QM_SELL && gm1 < entry - risk * strategy_midline_min_rr)
      tp = gm1;
   else
      tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_fallback_rr);

   if(tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = (side == QM_BUY) ? "GM_BAND_RECROSS_LONG" : "GM_BAND_RECROSS_SHORT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, scale-in, or partial close logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   datetime open_time = 0;
   if(!Strategy_FindOurPosition(ticket, position_type, open_time))
      return false;
   if(ticket == 0)
      return false;

   const int seconds_per_bar = PeriodSeconds((ENUM_TIMEFRAMES)_Period);
   if(strategy_max_hold_bars > 0 && seconds_per_bar > 0 && open_time > 0)
     {
      if((TimeCurrent() - open_time) >= (long)strategy_max_hold_bars * seconds_per_bar)
         return true;
     }

   if(g_cached_gm_midline <= 0.0 || g_cached_upper_band <= 0.0 || g_cached_lower_band <= 0.0)
      return false;

   if(position_type == POSITION_TYPE_BUY)
     {
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > 0.0 && bid >= g_cached_gm_midline)
         return true;
      if(g_cached_close_1 > 0.0 && g_cached_close_1 < g_cached_lower_band)
         return true;
     }
   else if(position_type == POSITION_TYPE_SELL)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(ask > 0.0 && ask <= g_cached_gm_midline)
         return true;
      if(g_cached_close_1 > 0.0 && g_cached_close_1 > g_cached_upper_band)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return true;
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
