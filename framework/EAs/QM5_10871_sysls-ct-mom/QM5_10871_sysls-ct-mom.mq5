#property strict
#property version   "5.0"
#property description "QM5_10871 SystematicLS Crypto Trend Median Ensemble"

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
input int    qm_ea_id                   = 10871;
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
input int    strategy_roc_1             = 5;
input int    strategy_roc_2             = 10;
input int    strategy_roc_3             = 15;
input int    strategy_roc_4             = 20;
input int    strategy_zscore_window     = 252;
input double strategy_entry_threshold   = 0.35;
input int    strategy_atr_period        = 20;
input double strategy_atr_sl_mult       = 2.5;
input double strategy_trail_atr_mult    = 3.0;
input double strategy_trail_trigger_r   = 1.5;
input int    strategy_time_stop_days    = 20;
input double strategy_atr_percentile_pct = 20.0;
input double strategy_spread_stop_frac  = 0.08;

double g_last_trend_score = 0.0;
bool   g_trend_score_valid = false;

double Strategy_CloseD1(const int shift)
  {
   return iClose(_Symbol, PERIOD_D1, shift); // perf-allowed: bounded D1 ROC/z-score source read, called from closed-bar hooks only.
  }

double Strategy_Clip(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

double Strategy_MapZScore(const double z)
  {
   const double clipped = Strategy_Clip(z, -3.0, 3.0);
   return (2.0 / (1.0 + MathExp(-2.0 * clipped))) - 1.0;
  }

void Strategy_Sort4(double &a, double &b, double &c, double &d)
  {
   for(int pass = 0; pass < 4; ++pass)
     {
      if(a > b) { const double t = a; a = b; b = t; }
      if(b > c) { const double t = b; b = c; c = t; }
      if(c > d) { const double t = c; c = d; d = t; }
     }
  }

bool Strategy_ROC(const int lookback, const int shift, double &out_roc)
  {
   out_roc = 0.0;
   if(lookback <= 0 || shift <= 0)
      return false;

   const double c_now = Strategy_CloseD1(shift);
   const double c_then = Strategy_CloseD1(shift + lookback);
   if(c_now <= 0.0 || c_then <= 0.0)
      return false;

   out_roc = (c_now / c_then) - 1.0;
   return true;
  }

bool Strategy_ROCStats(const int lookback, const int window, double &out_mean, double &out_std)
  {
   out_mean = 0.0;
   out_std = 0.0;
   if(lookback <= 0 || window < 20)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   int samples = 0;
   for(int shift = 1; shift <= window; ++shift)
     {
      double roc = 0.0;
      if(!Strategy_ROC(lookback, shift, roc))
         continue;
      sum += roc;
      sum_sq += roc * roc;
      samples++;
     }

   if(samples < MathMax(20, window / 2))
      return false;

   out_mean = sum / samples;
   const double variance = (sum_sq / samples) - (out_mean * out_mean);
   if(variance <= 0.0)
      return false;

   out_std = MathSqrt(variance);
   return (out_std > 0.0);
  }

bool Strategy_MappedEstimator(const int lookback, double &out_value)
  {
   out_value = 0.0;
   double roc = 0.0;
   double mean = 0.0;
   double stdev = 0.0;
   if(!Strategy_ROC(lookback, 1, roc))
      return false;
   if(!Strategy_ROCStats(lookback, strategy_zscore_window, mean, stdev))
      return false;

   out_value = Strategy_MapZScore((roc - mean) / stdev);
   return true;
  }

bool Strategy_TrendScore(double &out_score)
  {
   out_score = 0.0;
   double a = 0.0, b = 0.0, c = 0.0, d = 0.0;
   if(!Strategy_MappedEstimator(strategy_roc_1, a))
      return false;
   if(!Strategy_MappedEstimator(strategy_roc_2, b))
      return false;
   if(!Strategy_MappedEstimator(strategy_roc_3, c))
      return false;
   if(!Strategy_MappedEstimator(strategy_roc_4, d))
      return false;

   Strategy_Sort4(a, b, c, d);
   out_score = 0.5 * (b + c);
   return true;
  }

bool Strategy_LowVolBlocked()
  {
   if(strategy_zscore_window < 20 || strategy_atr_percentile_pct <= 0.0)
      return false;

   double ratios[];
   ArrayResize(ratios, strategy_zscore_window);
   int samples = 0;
   for(int shift = 1; shift <= strategy_zscore_window; ++shift)
     {
      const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, shift);
      const double close = Strategy_CloseD1(shift);
      if(atr <= 0.0 || close <= 0.0)
         continue;
      ratios[samples] = atr / close;
      samples++;
     }

   if(samples < MathMax(20, strategy_zscore_window / 2))
      return false;

   ArrayResize(ratios, samples);
   ArraySort(ratios);
   int idx = (int)MathFloor((samples - 1) * Strategy_Clip(strategy_atr_percentile_pct, 0.0, 100.0) / 100.0);
   if(idx < 0)
      idx = 0;
   if(idx >= samples)
      idx = samples - 1;

   const double current_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   const double current_close = Strategy_CloseD1(1);
   if(current_atr <= 0.0 || current_close <= 0.0)
      return true;

   return ((current_atr / current_close) < ratios[idx]);
  }

bool Strategy_SelectOurPosition(ENUM_POSITION_TYPE &ptype,
                                datetime &open_time,
                                double &open_price,
                                double &sl,
                                ulong &ticket)
  {
   ptype = POSITION_TYPE_BUY;
   open_time = 0;
   open_price = 0.0;
   sl = 0.0;
   ticket = 0;

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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      ticket = t;
      return true;
     }

   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
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

   double score = 0.0;
   if(!Strategy_TrendScore(score))
      return false;
   g_last_trend_score = score;
   g_trend_score_valid = true;

   if(Strategy_LowVolBlocked())
      return false;

   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   double open_price;
   double current_sl;
   ulong ticket;
   if(Strategy_SelectOurPosition(ptype, open_time, open_price, current_sl, ticket))
      return false;

   QM_OrderType side = QM_BUY;
   if(score > strategy_entry_threshold)
      side = QM_BUY;
   else if(score < -strategy_entry_threshold)
      side = QM_SELL;
   else
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (side == QM_BUY) ? ask : bid;
   if(entry <= 0.0 || ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   const double stop_distance = MathAbs(entry - sl);
   const double spread = ask - bid;
   if(stop_distance <= 0.0 || spread > stop_distance * strategy_spread_stop_frac)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "SYSLS_CT_MOM_LONG" : "SYSLS_CT_MOM_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   double open_price;
   double current_sl;
   ulong ticket;
   if(!Strategy_SelectOurPosition(ptype, open_time, open_price, current_sl, ticket))
      return;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_sl_mult <= 0.0)
      return;

   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double market_price = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                      : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(market_price <= 0.0 || open_price <= 0.0)
      return;

   const double profit_distance = is_buy ? (market_price - open_price)
                                         : (open_price - market_price);
   const double trigger_distance = strategy_trail_trigger_r * strategy_atr_sl_mult * atr;
   if(profit_distance >= trigger_distance)
      QM_TM_TrailATR(ticket, strategy_atr_period, strategy_trail_atr_mult);
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   datetime open_time;
   double open_price;
   double current_sl;
   ulong ticket;
   if(!Strategy_SelectOurPosition(ptype, open_time, open_price, current_sl, ticket))
      return false;

   if(strategy_time_stop_days > 0 && open_time > 0)
     {
      const long held_seconds = (long)(TimeCurrent() - open_time);
      if(held_seconds >= (long)strategy_time_stop_days * 86400L)
         return true;
     }

   if(!g_trend_score_valid)
      return false;

   if(ptype == POSITION_TYPE_BUY && g_last_trend_score < 0.0)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_last_trend_score > 0.0)
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
