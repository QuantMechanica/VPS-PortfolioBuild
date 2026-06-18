#property strict
#property version   "5.0"
#property description "QM5_11039 Prior Day Min Max Daily Pattern Scalp"

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
input int    qm_ea_id                   = 11039;
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
input int    strategy_pattern_window_days        = 10;
input int    strategy_range_lookback_days        = 60;
input double strategy_analog_top_percent         = 20.0;
input double strategy_return_threshold_atr_mult  = 0.10;
input double strategy_tp_atr_mult                = 0.35;
input double strategy_sl_tp_multiple             = 2.0;
input double strategy_sl_atr_mult                = 1.0;
input int    strategy_atr_period                 = 14;
input int    strategy_min_tp_pips                = 6;
input int    strategy_max_tp_pips                = 10;
input double strategy_min_d1_range_atr_mult      = 0.75;
input int    strategy_time_exit_hour_broker      = 22;
input int    strategy_max_spread_points          = 30;
input bool   strategy_body_confirm_enabled       = false;

double Strategy_ClampDouble(const double value, const double lo, const double hi)
  {
   if(value < lo)
      return lo;
   if(value > hi)
      return hi;
   return value;
  }

int Strategy_MaxInt(const int a, const int b)
  {
   return (a > b) ? a : b;
  }

int Strategy_MinInt(const int a, const int b)
  {
   return (a < b) ? a : b;
  }

int Strategy_AbsInt(const int value)
  {
   return (value < 0) ? -value : value;
  }

int Strategy_BodyDirection(const MqlRates &bar)
  {
   if(bar.close > bar.open)
      return 1;
   if(bar.close < bar.open)
      return -1;
   return 0;
  }

bool Strategy_RangePercentile(MqlRates &rates[], const int index, const int lookback, double &out_pct)
  {
   out_pct = 0.0;
   if(index < 0 || lookback <= 0)
      return false;

   const double target_range = rates[index].high - rates[index].low;
   if(target_range <= 0.0)
      return false;

   int samples = 0;
   int below_or_equal = 0;
   const int total = ArraySize(rates);
   for(int i = index + 1; i < total && i <= index + lookback; ++i)
     {
      const double range_i = rates[i].high - rates[i].low;
      if(range_i <= 0.0)
         continue;
      samples++;
      if(range_i <= target_range)
         below_or_equal++;
     }

   if(samples <= 0)
      return false;

   out_pct = (double)below_or_equal / (double)samples;
   return true;
  }

double Strategy_VectorDistance(const MqlRates &a,
                               const double a_range_pct,
                               const MqlRates &b,
                               const double b_range_pct)
  {
   const double a_range = a.high - a.low;
   const double b_range = b.high - b.low;
   if(a_range <= 0.0 || b_range <= 0.0)
      return DBL_MAX;

   const double a_pos = (a.close - a.low) / a_range;
   const double b_pos = (b.close - b.low) / b_range;
   const double body_delta = MathAbs((double)Strategy_BodyDirection(a) -
                                     (double)Strategy_BodyDirection(b));

   return MathAbs(a_pos - b_pos) +
          MathAbs(a_range_pct - b_range_pct) +
          0.35 * body_delta;
  }

void Strategy_SortPairs(double &scores[], double &returns[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const double key_score = scores[i];
      const double key_return = returns[i];
      int j = i - 1;
      while(j >= 0 && scores[j] > key_score)
        {
         scores[j + 1] = scores[j];
         returns[j + 1] = returns[j];
         j--;
        }
      scores[j + 1] = key_score;
      returns[j + 1] = key_return;
     }
  }

void Strategy_SortValues(double &values[], const int count)
  {
   for(int i = 1; i < count; ++i)
     {
      const double key = values[i];
      int j = i - 1;
      while(j >= 0 && values[j] > key)
        {
         values[j + 1] = values[j];
         j--;
        }
      values[j + 1] = key;
     }
  }

bool Strategy_MedianPreviousYearReturn(double &out_median_return)
  {
   out_median_return = 0.0;

   const int window_days = Strategy_MaxInt(1, strategy_pattern_window_days);
   const int lookback_days = Strategy_MaxInt(5, strategy_range_lookback_days);
   const int required_bars = 370 + window_days + lookback_days + 5;

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, required_bars, rates); // perf-allowed: D1 closed-bar analog scan; Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied < required_bars / 2)
      return false;

   if(rates[0].high <= rates[0].low)
      return false;

   double current_range_pct = 0.0;
   if(!Strategy_RangePercentile(rates, 0, lookback_days, current_range_pct))
      return false;

   MqlDateTime current_dt;
   TimeToStruct(rates[0].time, current_dt);
   const int target_year = current_dt.year - 1;

   double scores[128];
   double next_returns[128];
   int candidates = 0;

   for(int i = 1; i < copied - lookback_days - 1 && candidates < 128; ++i)
     {
      MqlDateTime analog_dt;
      TimeToStruct(rates[i].time, analog_dt);
      if(analog_dt.year != target_year)
         continue;
      if(Strategy_AbsInt(analog_dt.day_of_year - current_dt.day_of_year) > window_days)
         continue;

      double analog_range_pct = 0.0;
      if(!Strategy_RangePercentile(rates, i, lookback_days, analog_range_pct))
         continue;

      const double score = Strategy_VectorDistance(rates[0], current_range_pct,
                                                   rates[i], analog_range_pct);
      if(score == DBL_MAX)
         continue;

      scores[candidates] = score;
      next_returns[candidates] = rates[i - 1].close - rates[i].close;
      candidates++;
     }

   if(candidates <= 0)
      return false;

   Strategy_SortPairs(scores, next_returns, candidates);

   int top_count = (int)MathCeil((double)candidates * Strategy_ClampDouble(strategy_analog_top_percent, 1.0, 100.0) / 100.0);
   top_count = Strategy_MaxInt(1, Strategy_MinInt(top_count, candidates));

   double selected[128];
   for(int i = 0; i < top_count; ++i)
      selected[i] = next_returns[i];

   Strategy_SortValues(selected, top_count);
   if((top_count % 2) == 1)
      out_median_return = selected[top_count / 2];
   else
      out_median_return = 0.5 * (selected[top_count / 2 - 1] + selected[top_count / 2]);

   return true;
  }

bool Strategy_SpreadTooWide()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(strategy_max_spread_points <= 0)
      return false;
   if(ask > bid && (ask - bid) > (double)strategy_max_spread_points * point)
      return true;
   return false;
  }

bool Strategy_PriorDayRangeAdequate()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, rates); // perf-allowed: one closed D1 bar read for card range filter.
   if(copied != 1 || rates[0].high <= rates[0].low)
      return false;

   const double d1_atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(d1_atr <= 0.0)
      return false;

   return ((rates[0].high - rates[0].low) >= strategy_min_d1_range_atr_mult * d1_atr);
  }

int Strategy_CurrentPriorBodyDirection()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, 1, rates); // perf-allowed: one closed D1 bar read for optional card body confirmation.
   if(copied != 1)
      return 0;
   return Strategy_BodyDirection(rates[0]);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return Strategy_SpreadTooWide();
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

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!Strategy_PriorDayRangeAdequate())
      return false;

   double median_return = 0.0;
   if(!Strategy_MedianPreviousYearReturn(median_return))
      return false;

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;

   const double threshold = strategy_return_threshold_atr_mult * atr_h1;
   QM_OrderType side = QM_BUY;
   if(median_return > threshold)
      side = QM_BUY;
   else if(median_return < -threshold)
      side = QM_SELL;
   else
      return false;

   if(strategy_body_confirm_enabled)
     {
      const int body_dir = Strategy_CurrentPriorBodyDirection();
      if(side == QM_BUY && body_dir < 0)
         return false;
      if(side == QM_SELL && body_dir > 0)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const double entry = (side == QM_BUY) ? ask : bid;
   const double min_tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_min_tp_pips);
   const double max_tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_max_tp_pips);
   if(min_tp_dist <= 0.0 || max_tp_dist <= 0.0 || max_tp_dist < min_tp_dist)
      return false;

   const double tp_dist = Strategy_ClampDouble(strategy_tp_atr_mult * atr_h1,
                                               min_tp_dist,
                                               max_tp_dist);
   const double sl_dist = MathMax(strategy_sl_tp_multiple * tp_dist,
                                  strategy_sl_atr_mult * atr_h1);
   if(tp_dist <= 0.0 || sl_dist <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_dist);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_dist);
   req.reason = (side == QM_BUY) ? "ATC_AZXY_DAILY_LONG" : "ATC_AZXY_DAILY_SHORT";
   return (req.sl > 0.0 && req.tp > 0.0);
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed TP/SL plus time exit only; no trailing, BE, scale-in, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= strategy_time_exit_hour_broker);
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
