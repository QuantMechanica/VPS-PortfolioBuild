#property strict
#property version   "5.0"
#property description "QM5_12407 Oil-Predicted Equity Timing"

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
input int    qm_ea_id                   = 12407;
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
input string strategy_oil_symbol                  = "XTIUSD.DWX";
input int    strategy_regression_lookback_months  = 60;
input int    strategy_min_paired_observations     = 60;
input double strategy_monthly_threshold           = 0.0;
input int    strategy_atr_period                  = 20;
input double strategy_atr_sl_mult                 = 2.5;
input int    strategy_spread_median_days          = 60;

bool   g_qm12407_signal_valid       = false;
bool   g_qm12407_signal_long        = false;
bool   g_qm12407_month_evaluated    = false;
double g_qm12407_expected_return    = 0.0;

bool QM12407_IsTargetSymbol()
  {
   return (_Symbol == "SP500.DWX" || _Symbol == "NDX.DWX" || _Symbol == "WS30.DWX");
  }

bool QM12407_IsFirstTradableDayOfMonth()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int got = CopyRates(_Symbol, PERIOD_D1, 0, 2, rates); // perf-allowed: closed-bar monthly cadence check from Strategy_EntrySignal only.
   if(got < 2)
      return false;

   MqlDateTime current_dt;
   MqlDateTime prior_dt;
   TimeToStruct(rates[0].time, current_dt);
   TimeToStruct(rates[1].time, prior_dt);
   return (current_dt.mon != prior_dt.mon || current_dt.year != prior_dt.year);
  }

bool QM12407_ReadMonthEndCloses(const string symbol,
                                const int max_months,
                                double &month_closes[])
  {
   ArrayResize(month_closes, 0);
   if(max_months < 3)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int bars_to_copy = (max_months + 4) * 23;
   const int got = CopyRates(symbol, PERIOD_D1, 1, bars_to_copy, rates); // perf-allowed: bounded D1 history read for monthly regression, called after QM_IsNewBar().
   if(got < 80)
      return false;

   int current_year = -1;
   int current_month = -1;
   double last_close = 0.0;
   int out_count = 0;

   for(int i = got - 1; i >= 0; --i)
     {
      if(rates[i].close <= 0.0)
         continue;

      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);
      if(current_year < 0)
        {
         current_year = dt.year;
         current_month = dt.mon;
         last_close = rates[i].close;
         continue;
        }

      if(dt.year == current_year && dt.mon == current_month)
        {
         last_close = rates[i].close;
         continue;
        }

      ArrayResize(month_closes, out_count + 1);
      month_closes[out_count] = last_close;
      out_count++;

      current_year = dt.year;
      current_month = dt.mon;
      last_close = rates[i].close;
     }

   if(last_close > 0.0)
     {
      ArrayResize(month_closes, out_count + 1);
      month_closes[out_count] = last_close;
      out_count++;
     }

   return (out_count >= strategy_min_paired_observations + 2);
  }

bool QM12407_UpdateMonthlySignal()
  {
   g_qm12407_signal_valid = false;
   g_qm12407_signal_long = false;
   g_qm12407_expected_return = 0.0;
   g_qm12407_month_evaluated = true;

   double equity_closes[];
   double oil_closes[];
   const int requested_months = strategy_regression_lookback_months + 4;
   if(!QM12407_ReadMonthEndCloses(_Symbol, requested_months, equity_closes))
      return false;
   if(!QM12407_ReadMonthEndCloses(strategy_oil_symbol, requested_months, oil_closes))
      return false;

   const int equity_count = ArraySize(equity_closes);
   const int oil_count = ArraySize(oil_closes);
   const int n = MathMin(equity_count, oil_count);
   if(n < strategy_min_paired_observations + 2)
      return false;

   const int equity_start = equity_count - n;
   const int oil_start = oil_count - n;
   const int samples = MathMin(strategy_regression_lookback_months, n - 2);
   if(samples < strategy_min_paired_observations)
      return false;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xx = 0.0;
   double sum_xy = 0.0;
   int used = 0;

   for(int k = n - samples; k < n; ++k)
     {
      const double oil_prev = oil_closes[oil_start + k - 2];
      const double oil_now = oil_closes[oil_start + k - 1];
      const double eq_prev = equity_closes[equity_start + k - 1];
      const double eq_now = equity_closes[equity_start + k];
      if(oil_prev <= 0.0 || oil_now <= 0.0 || eq_prev <= 0.0 || eq_now <= 0.0)
         continue;

      const double x = (oil_now / oil_prev) - 1.0;
      const double y = (eq_now / eq_prev) - 1.0;
      sum_x += x;
      sum_y += y;
      sum_xx += x * x;
      sum_xy += x * y;
      used++;
     }

   if(used < strategy_min_paired_observations)
      return false;

   const double denom = (used * sum_xx) - (sum_x * sum_x);
   if(MathAbs(denom) <= 1.0e-12)
      return false;

   const double slope = ((used * sum_xy) - (sum_x * sum_y)) / denom;
   const double intercept = (sum_y - slope * sum_x) / used;
   const double latest_oil_prev = oil_closes[oil_start + n - 2];
   const double latest_oil_now = oil_closes[oil_start + n - 1];
   if(latest_oil_prev <= 0.0 || latest_oil_now <= 0.0)
      return false;

   const double latest_oil_return = (latest_oil_now / latest_oil_prev) - 1.0;
   g_qm12407_expected_return = intercept + slope * latest_oil_return;
   g_qm12407_signal_valid = true;
   g_qm12407_signal_long = (g_qm12407_expected_return > strategy_monthly_threshold);
   return true;
  }

bool QM12407_SpreadBlocked()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;
   if(!(ask > bid))
      return false;

   const double current_spread = ask - bid;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(current_spread <= 0.0 || point <= 0.0 || strategy_spread_median_days <= 0)
      return false;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int got = CopyRates(_Symbol, PERIOD_D1, 1, strategy_spread_median_days, rates); // perf-allowed: bounded spread sample for card filter, called after QM_IsNewBar().
   if(got <= 0)
      return false;

   double spreads[];
   int samples = 0;
   for(int i = 0; i < got; ++i)
     {
      if(rates[i].spread <= 0)
         continue;
      ArrayResize(spreads, samples + 1);
      spreads[samples] = rates[i].spread * point;
      samples++;
     }

   if(samples < 5)
      return false;

   ArraySort(spreads);
   const double median_spread = spreads[samples / 2];
   if(median_spread <= 0.0)
      return false;

   return (current_spread > (2.0 * median_spread));
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   if(!QM12407_IsTargetSymbol())
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

   if(!QM12407_IsTargetSymbol())
      return false;
   if(!QM12407_IsFirstTradableDayOfMonth())
      return false;

   if(!QM12407_UpdateMonthlySignal())
      return false;
   if(!g_qm12407_signal_long)
      return false;
   if(QM12407_SpreadBlocked())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (ask > 0.0) ? ask : bid;
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = StringFormat("oil_reg_expected=%.6f_threshold=%.6f",
                             g_qm12407_expected_return,
                             strategy_monthly_threshold);
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
   if(!QM12407_IsTargetSymbol())
      return false;
   if(g_qm12407_month_evaluated && (!g_qm12407_signal_valid || !g_qm12407_signal_long))
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

   string allowed_symbols[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "XTIUSD.DWX"};
   QM_SymbolGuardInit(allowed_symbols);
   QM_BasketWarmupHistory(allowed_symbols,
                          PERIOD_D1,
                          (strategy_regression_lookback_months + 4) * 23);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12407_oil_pred_eq\"}");
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
