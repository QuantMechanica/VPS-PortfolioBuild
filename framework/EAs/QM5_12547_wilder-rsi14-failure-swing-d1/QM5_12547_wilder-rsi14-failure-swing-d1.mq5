#property strict
#property version   "5.0"
#property description "QuantMechanica V5 EA skeleton template"

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
input int    qm_ea_id                   = 12547;
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
input int    strategy_rsi_period        = 14;
input double strategy_rsi_oversold      = 30.0;
input double strategy_rsi_overbought    = 70.0;
input double strategy_rsi_midline       = 50.0;
input double strategy_tp_rr             = 2.0;
input int    strategy_time_stop_bars    = 5;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_rsi_period <= 1)
      return true;
   if(strategy_rsi_oversold <= 0.0 || strategy_rsi_overbought >= 100.0)
      return true;
   if(strategy_rsi_oversold >= strategy_rsi_midline ||
      strategy_rsi_midline >= strategy_rsi_overbought)
      return true;
   if(strategy_tp_rr <= 0.0 || strategy_time_stop_bars < 0)
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

   static int    state = 0; // 0 neutral, +1/+2/+3 long setup, -1/-2/-3 short setup.
   static double long_bounce_high = 0.0;
   static double long_pullback_low = 0.0;
   static double long_excursion_low = 0.0;
   static double short_bounce_low = 0.0;
   static double short_pullback_high = 0.0;
   static double short_excursion_high = 0.0;

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES tf = PERIOD_D1;
   const double rsi = QM_RSI(_Symbol, tf, strategy_rsi_period, 1);
   if(rsi == EMPTY_VALUE || !MathIsValidNumber(rsi) || rsi <= 0.0)
      return false;

   const double bar_low = iLow(_Symbol, tf, 1);   // perf-allowed: bespoke failure-swing structure stop, closed-bar only.
   const double bar_high = iHigh(_Symbol, tf, 1); // perf-allowed: bespoke failure-swing structure stop, closed-bar only.
   if(bar_low <= 0.0 || bar_high <= 0.0 || bar_high < bar_low)
      return false;

   if(rsi < strategy_rsi_oversold)
     {
      const bool continuing_long_dip = (state == 1 && long_excursion_low > 0.0);
      state = 1;
      long_bounce_high = 0.0;
      long_pullback_low = 0.0;
      long_excursion_low = continuing_long_dip ? MathMin(long_excursion_low, bar_low) : bar_low;
      short_bounce_low = 0.0;
      short_pullback_high = 0.0;
      short_excursion_high = 0.0;
      return false;
     }

   if(rsi > strategy_rsi_overbought)
     {
      const bool continuing_short_spike = (state == -1 && short_excursion_high > 0.0);
      state = -1;
      short_bounce_low = 0.0;
      short_pullback_high = 0.0;
      short_excursion_high = continuing_short_spike ? MathMax(short_excursion_high, bar_high) : bar_high;
      long_bounce_high = 0.0;
      long_pullback_low = 0.0;
      long_excursion_low = 0.0;
      return false;
     }

   if(state > 0)
      long_excursion_low = (long_excursion_low <= 0.0) ? bar_low : MathMin(long_excursion_low, bar_low);
   if(state < 0)
      short_excursion_high = (short_excursion_high <= 0.0) ? bar_high : MathMax(short_excursion_high, bar_high);

   if(state == 1 && rsi > strategy_rsi_oversold)
     {
      state = 2;
      long_bounce_high = rsi;
      long_pullback_low = rsi;
      return false;
     }

   if(state == 2)
     {
      if(rsi >= long_bounce_high)
        {
         long_bounce_high = rsi;
         return false;
        }
      if(rsi > strategy_rsi_oversold && rsi < long_bounce_high)
        {
         state = 3;
         long_pullback_low = rsi;
         return false;
        }
     }

   if(state == 3)
     {
      if(rsi > strategy_rsi_oversold && rsi < long_bounce_high)
        {
         long_pullback_low = MathMin(long_pullback_low, rsi);
         return false;
        }
      if(rsi > long_bounce_high && long_pullback_low > strategy_rsi_oversold)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0 || long_excursion_low <= 0.0 || long_excursion_low >= entry)
            return false;
         req.type = QM_BUY;
         req.sl = QM_StopRulesNormalizePrice(_Symbol, long_excursion_low);
         req.tp = QM_TakeRR(_Symbol, QM_BUY, entry, req.sl, strategy_tp_rr);
         req.reason = "WILDER_RSI_FAILURE_SWING_LONG";
         state = 0;
         long_bounce_high = 0.0;
         long_pullback_low = 0.0;
         long_excursion_low = 0.0;
         return (req.tp > entry);
        }
     }

   if(state == -1 && rsi < strategy_rsi_overbought)
     {
      state = -2;
      short_bounce_low = rsi;
      short_pullback_high = rsi;
      return false;
     }

   if(state == -2)
     {
      if(rsi <= short_bounce_low)
        {
         short_bounce_low = rsi;
         return false;
        }
      if(rsi < strategy_rsi_overbought && rsi > short_bounce_low)
        {
         state = -3;
         short_pullback_high = rsi;
         return false;
        }
     }

   if(state == -3)
     {
      if(rsi < strategy_rsi_overbought && rsi > short_bounce_low)
        {
         short_pullback_high = MathMax(short_pullback_high, rsi);
         return false;
        }
      if(rsi < short_bounce_low && short_pullback_high < strategy_rsi_overbought)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0 || short_excursion_high <= 0.0 || short_excursion_high <= entry)
            return false;
         req.type = QM_SELL;
         req.sl = QM_StopRulesNormalizePrice(_Symbol, short_excursion_high);
         req.tp = QM_TakeRR(_Symbol, QM_SELL, entry, req.sl, strategy_tp_rr);
         req.reason = "WILDER_RSI_FAILURE_SWING_SHORT";
         state = 0;
         short_bounce_low = 0.0;
         short_pullback_high = 0.0;
         short_excursion_high = 0.0;
         return (req.tp > 0.0 && req.tp < entry);
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies hard SL, fixed 2R TP, and a discretionary RSI midline time stop only.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || strategy_time_stop_bars <= 0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 1);
   const double rsi_prev = QM_RSI(_Symbol, PERIOD_D1, strategy_rsi_period, 2);
   if(rsi_now == EMPTY_VALUE || rsi_prev == EMPTY_VALUE ||
      !MathIsValidNumber(rsi_now) || !MathIsValidNumber(rsi_prev))
      return false;

   const int seconds_per_bar = PeriodSeconds(PERIOD_D1);
   if(seconds_per_bar <= 0)
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

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_time <= 0 || TimeCurrent() - open_time < strategy_time_stop_bars * seconds_per_bar)
         continue;

      const ENUM_POSITION_TYPE position_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(position_type == POSITION_TYPE_BUY &&
         rsi_prev >= strategy_rsi_midline && rsi_now < strategy_rsi_midline)
         return true;
      if(position_type == POSITION_TYPE_SELL &&
         rsi_prev <= strategy_rsi_midline && rsi_now > strategy_rsi_midline)
         return true;
     }

   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework"). Used by EAs that need
// custom high-impact-event handling beyond the central filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to the framework news filter
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
