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
input int    qm_ea_id                   = 9999;
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
input ENUM_TIMEFRAMES strategy_direction_tf       = PERIOD_H4;
input ENUM_TIMEFRAMES strategy_confirmation_tf    = PERIOD_H1;
input int             strategy_structure_lookback = 48;
input int             strategy_swing_strength     = 2;
input int             strategy_ob_lookback        = 24;
input int             strategy_fvg_lookback       = 24;
input int             strategy_sweep_memory_bars  = 12;
input double          strategy_sl_buffer_pct      = 0.3;
input double          strategy_rr                 = 2.0;
input bool            strategy_selective_mode     = false;
input int             strategy_max_spread_points  = 0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread_points = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread_points > strategy_max_spread_points)
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

   const int swing = MathMax(1, strategy_swing_strength);
   const int structure_bars = MathMax(strategy_structure_lookback, swing * 2 + 8);
   const int h4_need = structure_bars + swing + 4;
   const int h1_need = MathMax(structure_bars, MathMax(strategy_ob_lookback, strategy_fvg_lookback) + 8);
   MqlRates htf[];
   MqlRates ctf[];
   ArraySetAsSeries(htf, true);
   ArraySetAsSeries(ctf, true);
   const int htf_count = CopyRates(_Symbol, strategy_direction_tf, 1, h4_need, htf); // perf-allowed: bounded SMC structure snapshot on closed-bar entry path
   const int ctf_count = CopyRates(_Symbol, strategy_confirmation_tf, 1, h1_need, ctf); // perf-allowed: bounded SMC structure snapshot on closed-bar entry path
   if(htf_count < swing * 2 + 6 || ctf_count < swing * 2 + 8)
      return false;

   double htf_swing_high = 0.0;
   double htf_swing_low = 0.0;
   double htf_range_high = -DBL_MAX;
   double htf_range_low = DBL_MAX;
   for(int i = 0; i < MathMin(structure_bars, htf_count); ++i)
     {
      htf_range_high = MathMax(htf_range_high, htf[i].high);
      htf_range_low = MathMin(htf_range_low, htf[i].low);
     }

   for(int i = swing; i < MathMin(structure_bars, htf_count - swing); ++i)
     {
      bool is_high = true;
      bool is_low = true;
      for(int j = 1; j <= swing; ++j)
        {
         if(htf[i].high <= htf[i - j].high || htf[i].high <= htf[i + j].high)
            is_high = false;
         if(htf[i].low >= htf[i - j].low || htf[i].low >= htf[i + j].low)
            is_low = false;
        }
      if(is_high && htf_swing_high <= 0.0)
         htf_swing_high = htf[i].high;
      if(is_low && htf_swing_low <= 0.0)
         htf_swing_low = htf[i].low;
      if(htf_swing_high > 0.0 && htf_swing_low > 0.0)
         break;
     }

   double ctf_swing_high = 0.0;
   double ctf_swing_low = 0.0;
   for(int i = swing; i < MathMin(structure_bars, ctf_count - swing); ++i)
     {
      bool is_high = true;
      bool is_low = true;
      for(int j = 1; j <= swing; ++j)
        {
         if(ctf[i].high <= ctf[i - j].high || ctf[i].high <= ctf[i + j].high)
            is_high = false;
         if(ctf[i].low >= ctf[i - j].low || ctf[i].low >= ctf[i + j].low)
            is_low = false;
        }
      if(is_high && ctf_swing_high <= 0.0)
         ctf_swing_high = ctf[i].high;
      if(is_low && ctf_swing_low <= 0.0)
         ctf_swing_low = ctf[i].low;
      if(ctf_swing_high > 0.0 && ctf_swing_low > 0.0)
         break;
     }

   const bool htf_bull = (htf_swing_high > 0.0 && htf[0].close > htf_swing_high);
   const bool htf_bear = (htf_swing_low > 0.0 && htf[0].close < htf_swing_low);
   const bool ctf_bull = (ctf_swing_high > 0.0 && ctf[0].close > ctf_swing_high);
   const bool ctf_bear = (ctf_swing_low > 0.0 && ctf[0].close < ctf_swing_low);

   bool long_sweep = false;
   bool short_sweep = false;
   const int sweep_limit = MathMin(strategy_sweep_memory_bars, ctf_count - swing - 3);
   for(int j = 0; j < sweep_limit; ++j)
     {
      double prior_low = DBL_MAX;
      double prior_high = -DBL_MAX;
      const int prior_end = MathMin(ctf_count, j + structure_bars);
      for(int k = j + swing + 1; k < prior_end; ++k)
        {
         prior_low = MathMin(prior_low, ctf[k].low);
         prior_high = MathMax(prior_high, ctf[k].high);
        }
      if(prior_low < DBL_MAX && ctf[j].low < prior_low && ctf[j].close > prior_low)
         long_sweep = true;
      if(prior_high > 0.0 && ctf[j].high > prior_high && ctf[j].close < prior_high)
         short_sweep = true;
     }

   double long_ob_low = 0.0;
   double long_ob_high = 0.0;
   for(int i = 1; i < MathMin(strategy_ob_lookback, ctf_count - 2); ++i)
     {
      if(ctf[i].close < ctf[i].open && ctf[0].close > ctf[i].high)
        {
         long_ob_low = ctf[i].low;
         long_ob_high = ctf[i].high;
         break;
        }
     }

   double short_ob_low = 0.0;
   double short_ob_high = 0.0;
   for(int i = 1; i < MathMin(strategy_ob_lookback, ctf_count - 2); ++i)
     {
      if(ctf[i].close > ctf[i].open && ctf[0].close < ctf[i].low)
        {
         short_ob_low = ctf[i].low;
         short_ob_high = ctf[i].high;
         break;
        }
     }

   bool long_fvg_overlap = false;
   bool short_fvg_overlap = false;
   for(int i = 0; i < MathMin(strategy_fvg_lookback, ctf_count - 3); ++i)
     {
      if(long_ob_low > 0.0 && ctf[i].low > ctf[i + 2].high)
        {
         const double fvg_low = ctf[i + 2].high;
         const double fvg_high = ctf[i].low;
         if(MathMax(fvg_low, long_ob_low) <= MathMin(fvg_high, long_ob_high))
            long_fvg_overlap = true;
        }
      if(short_ob_high > 0.0 && ctf[i].high < ctf[i + 2].low)
        {
         const double fvg_low = ctf[i].high;
         const double fvg_high = ctf[i + 2].low;
         if(MathMax(fvg_low, short_ob_low) <= MathMin(fvg_high, short_ob_high))
            short_fvg_overlap = true;
        }
     }

   const double mid_range = (htf_range_high + htf_range_low) * 0.5;
   const bool long_location_ok = (!strategy_selective_mode || ctf[0].close <= mid_range);
   const bool short_location_ok = (!strategy_selective_mode || ctf[0].close >= mid_range);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0 || strategy_rr <= 0.0)
      return false;

   const double buffer_mult = MathMax(strategy_sl_buffer_pct, 0.0) / 100.0;
   if(htf_bull && ctf_bull && long_ob_low > 0.0 && long_fvg_overlap && long_sweep && long_location_ok)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(long_ob_low * (1.0 - buffer_mult), _Digits);
      if(req.sl <= 0.0 || req.sl >= ask)
         return false;
      req.tp = NormalizeDouble(ask + (ask - req.sl) * strategy_rr, _Digits);
      req.reason = "SMC_LONG_BOS_CHOCH_OB_FVG_SWEEP";
      return true;
     }

   if(htf_bear && ctf_bear && short_ob_high > 0.0 && short_fvg_overlap && short_sweep && short_location_ok)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(short_ob_high * (1.0 + buffer_mult), _Digits);
      if(req.sl <= bid)
         return false;
      req.tp = NormalizeDouble(bid - (req.sl - bid) * strategy_rr, _Digits);
      req.reason = "SMC_SHORT_BOS_CHOCH_OB_FVG_SWEEP";
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Source card specifies one fixed SL beyond the OB and fixed RR target.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Opposite-structure close is a P3 axis; baseline exits by SL/TP and Friday close.
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
