#property strict
#property version   "5.0"
#property description "QM5_10401 Elite Trader FRAMA Band Reversal"

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
input int    qm_ea_id                   = 10401;
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
input int    strategy_frama_period      = 16;
input double strategy_num_devs_up       = 2.0;
input double strategy_num_devs_down     = 2.0;
input int    strategy_atr_period        = 20;
input double strategy_trail_atr_mult    = 0.75;
input double strategy_target_trail_mult = 3.0;
input double strategy_min_band_spreads  = 4.0;

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

double Strategy_PriceHL2(const int shift)
  {
   const double high = iHigh(_Symbol, _Period, shift);
   const double low = iLow(_Symbol, _Period, shift);
   if(high <= 0.0 || low <= 0.0 || high < low)
      return 0.0;
   return 0.5 * (high + low);
  }

bool Strategy_RangeHL2(const int shift, const int bars, double &highest, double &lowest)
  {
   if(shift < 0 || bars <= 0)
      return false;

   highest = -DBL_MAX;
   lowest = DBL_MAX;
   for(int i = shift; i < shift + bars; ++i)
     {
      const double price = Strategy_PriceHL2(i);
      if(price <= 0.0)
         return false;
      highest = MathMax(highest, price);
      lowest = MathMin(lowest, price);
     }

   return (highest > -DBL_MAX && lowest < DBL_MAX && highest >= lowest);
  }

double Strategy_FramaAlpha(const int shift, const int period)
  {
   if(period < 4 || (period % 2) != 0)
      return 0.0;

   const int half = period / 2;
   double hi1 = 0.0, lo1 = 0.0, hi2 = 0.0, lo2 = 0.0, hi3 = 0.0, lo3 = 0.0;
   if(!Strategy_RangeHL2(shift, half, hi1, lo1))
      return 0.0;
   if(!Strategy_RangeHL2(shift + half, half, hi2, lo2))
      return 0.0;
   if(!Strategy_RangeHL2(shift, period, hi3, lo3))
      return 0.0;

   const double n1 = (hi1 - lo1) / (double)half;
   const double n2 = (hi2 - lo2) / (double)half;
   const double n3 = (hi3 - lo3) / (double)period;
   if(n1 <= 0.0 || n2 <= 0.0 || n3 <= 0.0)
      return 1.0;

   const double dimension = (MathLog(n1 + n2) - MathLog(n3)) / MathLog(2.0);
   double alpha = MathExp(-4.6 * (dimension - 1.0));
   if(alpha < 0.01)
      alpha = 0.01;
   if(alpha > 1.0)
      alpha = 1.0;
   return alpha;
  }

double Strategy_Frama(const int shift, const int period)
  {
   if(period < 4 || (period % 2) != 0 || shift < 0)
      return 0.0;

   const int warmup = period * 4;
   const int oldest = shift + warmup;
   double frama = Strategy_PriceHL2(oldest);
   if(frama <= 0.0)
      return 0.0;

   for(int s = oldest - 1; s >= shift; --s)
     {
      const double price = Strategy_PriceHL2(s);
      const double alpha = Strategy_FramaAlpha(s, period);
      if(price <= 0.0 || alpha <= 0.0)
         return 0.0;
      frama = alpha * price + (1.0 - alpha) * frama;
     }

   return frama;
  }

double Strategy_FramaStdDev(const int shift, const int period, const double mean)
  {
   if(period <= 1 || mean <= 0.0)
      return 0.0;

   double sum_sq = 0.0;
   for(int i = shift; i < shift + period; ++i)
     {
      const double price = Strategy_PriceHL2(i);
      if(price <= 0.0)
         return 0.0;
      const double diff = price - mean;
      sum_sq += diff * diff;
     }

   return MathSqrt(sum_sq / (double)period);
  }

bool Strategy_Bands(const int shift, double &mean, double &upper, double &lower)
  {
   mean = 0.0;
   upper = 0.0;
   lower = 0.0;

   if(strategy_frama_period < 4 ||
      (strategy_frama_period % 2) != 0 ||
      strategy_num_devs_up <= 0.0 ||
      strategy_num_devs_down <= 0.0)
      return false;

   mean = Strategy_Frama(shift, strategy_frama_period);
   const double stdev = Strategy_FramaStdDev(shift, strategy_frama_period, mean);
   if(mean <= 0.0 || stdev <= 0.0)
      return false;

   upper = mean + strategy_num_devs_up * stdev;
   lower = mean - strategy_num_devs_down * stdev;
   return (upper > lower && lower > 0.0);
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

   if(strategy_atr_period <= 0 ||
      strategy_trail_atr_mult <= 0.0 ||
      strategy_target_trail_mult <= 0.0 ||
      strategy_min_band_spreads <= 0.0)
      return false;

   double mean_1 = 0.0, upper_1 = 0.0, lower_1 = 0.0;
   double mean_2 = 0.0, upper_2 = 0.0, lower_2 = 0.0;
   if(!Strategy_Bands(1, mean_1, upper_1, lower_1))
      return false;
   if(!Strategy_Bands(2, mean_2, upper_2, lower_2))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(ask <= 0.0 || bid <= 0.0 || spread <= 0.0)
      return false;
   if((upper_1 - lower_1) < strategy_min_band_spreads * spread)
      return false;

   const double atr = QM_ATR(_Symbol, (ENUM_TIMEFRAMES)_Period, strategy_atr_period, 1);
   const double trail = atr * strategy_trail_atr_mult;
   const double target = trail * strategy_target_trail_mult;
   if(trail <= 0.0 || target <= 0.0)
      return false;

   const double low_1 = iLow(_Symbol, _Period, 1);
   const double low_2 = iLow(_Symbol, _Period, 2);
   const double high_1 = iHigh(_Symbol, _Period, 1);
   const double high_2 = iHigh(_Symbol, _Period, 2);
   if(low_1 <= 0.0 || low_2 <= 0.0 || high_1 <= 0.0 || high_2 <= 0.0)
      return false;

   if(low_2 <= lower_2 && low_1 > lower_1 && lower_1 > ask)
     {
      req.type = QM_BUY_STOP;
      req.price = lower_1;
      req.sl = lower_1 - trail;
      req.tp = lower_1 + target;
      req.reason = "ET_FRAMA_BAND_LONG_STOP";
      return (req.sl > 0.0 && req.sl < req.price && req.tp > req.price);
     }

   if(high_2 >= upper_2 && high_1 < upper_1 && upper_1 < bid)
     {
      req.type = QM_SELL_STOP;
      req.price = upper_1;
      req.sl = upper_1 + trail;
      req.tp = upper_1 - target;
      req.reason = "ET_FRAMA_BAND_SHORT_STOP";
      return (req.tp > 0.0 && req.sl > req.price && req.tp < req.price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
     }
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
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
