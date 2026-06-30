#property strict
#property version   "5.0"
#property description "QM5_12815 Statistical Mean Reversion + Confidence Intervals"

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
input int    qm_ea_id                   = 12815;
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
input int    strategy_lookback_bars     = 50;    // Rolling close/return window N.
input double strategy_band_sigma_mult   = 2.0;   // Entry band: mean +/- k*sigma.
input double strategy_stop_sigma_mult   = 3.0;   // Hard stop distance: k_sl*sigma.
input double strategy_skew_max          = 0.5;   // Normality gate: abs(skewness) below this value.
input double strategy_excess_kurt_max   = 1.0;   // Normality gate: abs(excess kurtosis) below this value.

double g_stat_mean = 0.0;
double g_stat_sigma = 0.0;
double g_stat_upper = 0.0;
double g_stat_lower = 0.0;
double g_stat_skew = 0.0;
double g_stat_excess_kurtosis = 0.0;
double g_stat_close = 0.0;
bool   g_stat_ready = false;

void Strategy_ResetEntryRequest(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
  }

bool Strategy_RefreshClosedBarStats()
  {
   g_stat_ready = false;

   const int n = strategy_lookback_bars;
   if(n < 10 || strategy_band_sigma_mult <= 0.0 || strategy_stop_sigma_mult <= 0.0 ||
      strategy_skew_max <= 0.0 || strategy_excess_kurt_max <= 0.0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int needed = n + 1;
   const int copied = CopyRates(_Symbol, _Period, 1, needed, rates); // perf-allowed: closed-bar rolling sigma/skew/kurtosis window required by card.
   if(copied < needed)
      return false;

   double close_sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      if(rates[i].close <= 0.0)
         return false;
      close_sum += rates[i].close;
     }

   const double close_mean = close_sum / (double)n;
   double close_var_sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double d = rates[i].close - close_mean;
      close_var_sum += d * d;
     }

   const double close_sigma = MathSqrt(close_var_sum / (double)n);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || close_sigma <= point)
      return false;

   double return_sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      if(rates[i + 1].close <= 0.0)
         return false;
      return_sum += (rates[i].close / rates[i + 1].close) - 1.0;
     }

   const double return_mean = return_sum / (double)n;
   double return_var_sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double r = (rates[i].close / rates[i + 1].close) - 1.0;
      const double d = r - return_mean;
      return_var_sum += d * d;
     }

   const double return_sigma = MathSqrt(return_var_sum / (double)n);
   if(return_sigma <= 1e-12)
      return false;

   double skew_sum = 0.0;
   double kurt_sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double r = (rates[i].close / rates[i + 1].close) - 1.0;
      const double z = (r - return_mean) / return_sigma;
      const double z2 = z * z;
      skew_sum += z2 * z;
      kurt_sum += z2 * z2;
     }

   g_stat_mean = close_mean;
   g_stat_sigma = close_sigma;
   g_stat_upper = close_mean + strategy_band_sigma_mult * close_sigma;
   g_stat_lower = close_mean - strategy_band_sigma_mult * close_sigma;
   g_stat_skew = skew_sum / (double)n;
   g_stat_excess_kurtosis = (kurt_sum / (double)n) - 3.0;
   g_stat_close = rates[0].close;
   g_stat_ready = true;
   return true;
  }

bool Strategy_NormalityAllowsTrade()
  {
   if(!g_stat_ready)
      return false;
   if(MathAbs(g_stat_skew) >= strategy_skew_max)
      return false;
   if(MathAbs(g_stat_excess_kurtosis) >= strategy_excess_kurt_max)
      return false;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(strategy_lookback_bars < 10)
      return true;
   if(strategy_band_sigma_mult <= 0.0 || strategy_stop_sigma_mult <= 0.0)
      return true;
   if(strategy_skew_max <= 0.0 || strategy_excess_kurt_max <= 0.0)
      return true;
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
// Use QM_LotsForRisk + QM_Stop* helpers; do NOT compute lots inline.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   Strategy_ResetEntryRequest(req);

   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   if(!Strategy_RefreshClosedBarStats())
      return false;
   if(!Strategy_NormalityAllowsTrade())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_stat_close < g_stat_lower)
     {
      const double entry_price = ask;
      const double stop_distance = strategy_stop_sigma_mult * g_stat_sigma;
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_price - stop_distance);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, g_stat_mean);
      req.reason = "STAT_MR_CONFINT_BUY";
      return (req.sl > 0.0 && req.tp > entry_price);
     }

   if(g_stat_close > g_stat_upper)
     {
      const double entry_price = bid;
      const double stop_distance = strategy_stop_sigma_mult * g_stat_sigma;
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopRulesNormalizePrice(_Symbol, entry_price + stop_distance);
      req.tp = QM_StopRulesNormalizePrice(_Symbol, g_stat_mean);
      req.reason = "STAT_MR_CONFINT_SELL";
      return (req.sl > 0.0 && req.tp > 0.0 && req.tp < entry_price);
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies single hard SL and TP at rolling mean; no trailing, partial, or BE management.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   // Exits are handled by broker SL/TP and the framework Friday close.
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
