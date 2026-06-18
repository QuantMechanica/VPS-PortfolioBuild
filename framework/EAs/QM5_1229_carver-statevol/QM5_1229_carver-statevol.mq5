#property strict
#property version   "5.0"
#property description "QM5_1229 Carver State Of Vol Rule"

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
input int    qm_ea_id                   = 1229;
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
input int    strategy_vol_lookback       = 25;
input int    strategy_long_vol_baseline  = 2500;
input int    strategy_smooth_period      = 10;
input double strategy_entry_threshold    = 5.0;
input double strategy_exit_threshold     = 0.0;
input int    strategy_min_prior_bars     = 500;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_spread_lookback    = 20;

double g_statevol_forecast = 0.0;
bool   g_statevol_ready = false;
bool   g_statevol_spread_allows = true;

double ClampForecast(const double value)
  {
   if(value > 20.0)
      return 20.0;
   if(value < -20.0)
      return -20.0;
   return value;
  }

double ReturnStdDev(const double &closes[], const int end_idx, const int period)
  {
   if(period <= 1 || end_idx < period)
      return 0.0;

   double sum = 0.0;
   int count = 0;
   for(int i = end_idx - period + 1; i <= end_idx; ++i)
     {
      if(closes[i - 1] <= 0.0 || closes[i] <= 0.0)
         return 0.0;
      sum += (closes[i] / closes[i - 1]) - 1.0;
      count++;
     }

   if(count != period)
      return 0.0;

   const double mean = sum / (double)count;
   double var_sum = 0.0;
   for(int i = end_idx - period + 1; i <= end_idx; ++i)
     {
      const double r = (closes[i] / closes[i - 1]) - 1.0;
      const double d = r - mean;
      var_sum += d * d;
     }

   return MathSqrt(var_sum / (double)count);
  }

bool RawForecastAt(const double &normalised_vol[], const int idx, double &out_raw)
  {
   out_raw = 0.0;
   if(idx <= 0 || normalised_vol[idx] <= 0.0)
      return false;

   int count = 0;
   int less = 0;
   int equal = 0;
   const double cur = normalised_vol[idx];
   for(int i = 0; i < idx; ++i)
     {
      const double v = normalised_vol[i];
      if(v <= 0.0)
         continue;
      count++;
      if(v < cur)
         less++;
      else if(MathAbs(v - cur) <= 0.0000000001)
         equal++;
     }

   if(count < strategy_min_prior_bars)
      return false;

   const double q = ((double)less + 0.5 * (double)equal) / (double)count;
   out_raw = (q - 0.5) * 40.0;
   return true;
  }

bool SpreadAllowsEntry(const int &spreads[], const int n)
  {
   g_statevol_spread_allows = true;
   if(strategy_spread_lookback <= 0 || n < strategy_spread_lookback + 1)
      return true;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0.0 && point > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(ask > 0.0 && bid > 0.0 && ask > bid)
         current_spread = (ask - bid) / point;
     }

   if(current_spread <= 0.0)
      return true;

   double sample[];
   ArrayResize(sample, strategy_spread_lookback);
   int got = 0;
   for(int i = n - strategy_spread_lookback; i < n; ++i)
     {
      if(spreads[i] > 0)
        {
         sample[got] = (double)spreads[i];
         got++;
        }
     }

   if(got <= 0)
      return true;

   ArrayResize(sample, got);
   ArraySort(sample);
   double median = sample[got / 2];
   if((got % 2) == 0)
      median = 0.5 * (sample[(got / 2) - 1] + sample[got / 2]);

   if(median <= 0.0)
      return true;

   g_statevol_spread_allows = (current_spread <= 2.0 * median);
   return g_statevol_spread_allows;
  }

bool ComputeStateVolForecast(double &out_forecast)
  {
   out_forecast = 0.0;
   g_statevol_spread_allows = true;

   if(strategy_vol_lookback < 2 ||
      strategy_long_vol_baseline < 1 ||
      strategy_smooth_period < 1 ||
      strategy_min_prior_bars < 20 ||
      strategy_atr_period < 1 ||
      strategy_atr_sl_mult <= 0.0)
      return false;

   const int smooth_warmup = MathMax(strategy_smooth_period * 12, 60);
   const int requested_bars = strategy_long_vol_baseline +
                              strategy_vol_lookback +
                              strategy_min_prior_bars +
                              smooth_warmup + 10;

   MqlRates rates[];
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, requested_bars, rates); // perf-allowed: D1 closed-bar volatility percentile calculation, called only from Strategy_EntrySignal after QM_IsNewBar().
   if(copied < strategy_min_prior_bars + strategy_vol_lookback + smooth_warmup)
      return false;

   double closes[];
   int spreads[];
   ArrayResize(closes, copied);
   ArrayResize(spreads, copied);

   const bool newest_first = (rates[0].time > rates[copied - 1].time);
   for(int i = 0; i < copied; ++i)
     {
      const int src = newest_first ? (copied - 1 - i) : i;
      closes[i] = rates[src].close;
      spreads[i] = rates[src].spread;
     }

   SpreadAllowsEntry(spreads, copied);

   double daily_vol[];
   double prefix[];
   double normalised_vol[];
   ArrayResize(daily_vol, copied);
   ArrayResize(prefix, copied + 1);
   ArrayResize(normalised_vol, copied);

   prefix[0] = 0.0;
   for(int i = 0; i < copied; ++i)
     {
      daily_vol[i] = 0.0;
      normalised_vol[i] = 0.0;
      if(i >= strategy_vol_lookback)
         daily_vol[i] = ReturnStdDev(closes, i, strategy_vol_lookback);
      prefix[i + 1] = prefix[i] + daily_vol[i];
     }

   for(int i = strategy_vol_lookback; i < copied; ++i)
     {
      if(daily_vol[i] <= 0.0)
         continue;

      const int available_vols = i - strategy_vol_lookback + 1;
      const int baseline_count = (available_vols < strategy_long_vol_baseline) ? available_vols : strategy_long_vol_baseline;
      if(baseline_count < strategy_min_prior_bars)
         continue;

      const int start = i - baseline_count + 1;
      const double avg_vol = (prefix[i + 1] - prefix[start]) / (double)baseline_count;
      if(avg_vol > 0.0)
         normalised_vol[i] = daily_vol[i] / avg_vol;
     }

   const int current_idx = copied - 1;
   int start_idx = current_idx - smooth_warmup + 1;
   if(start_idx < strategy_vol_lookback)
      start_idx = strategy_vol_lookback;

   const double alpha = 2.0 / ((double)strategy_smooth_period + 1.0);
   double ema = 0.0;
   bool seeded = false;
   for(int i = start_idx; i <= current_idx; ++i)
     {
      double raw = 0.0;
      if(!RawForecastAt(normalised_vol, i, raw))
         continue;
      if(!seeded)
        {
         ema = raw;
         seeded = true;
        }
      else
         ema = alpha * raw + (1.0 - alpha) * ema;
     }

   if(!seeded)
      return false;

   out_forecast = ClampForecast(ema);
   return true;
  }

bool HasOpenPositionForMagic()
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

   double forecast = 0.0;
   g_statevol_ready = ComputeStateVolForecast(forecast);
   if(!g_statevol_ready)
      return false;

   g_statevol_forecast = forecast;
   if(!g_statevol_spread_allows)
      return false;
   if(HasOpenPositionForMagic())
      return false;

   QM_OrderType side = QM_BUY;
   if(forecast > strategy_entry_threshold)
      side = QM_BUY;
   else if(forecast < -strategy_entry_threshold)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_OrderTypeIsBuy(side) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = (side == QM_BUY) ? "CARVER_STATEVOL_LONG" : "CARVER_STATEVOL_SHORT";
   return true;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no break-even, trailing, partial close, or scale-in logic.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   if(!g_statevol_ready)
      return false;

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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && g_statevol_forecast <= strategy_exit_threshold)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_statevol_forecast >= strategy_exit_threshold)
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
