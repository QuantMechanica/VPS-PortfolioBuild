#property strict
#property version   "5.0"
#property description "QM5_10329 Imbalance Rev"

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
input int    qm_ea_id                   = 10329;
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
input int    strategy_atr_period              = 14;
input double strategy_atr_return_mult         = 1.0;
input double strategy_atr_stop_mult           = 1.25;
input int    strategy_imbalance_lookback_days = 252;
input double strategy_imbalance_tail_pct      = 20.0;
input int    strategy_median_range_days       = 20;
input int    strategy_min_m30_bars            = 12;
input int    strategy_spread_percentile       = 80;

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

   const int lookback_days = MathMax(20, strategy_imbalance_lookback_days);
   const int daily_needed = lookback_days + 2;
   MqlRates daily[];
   ArraySetAsSeries(daily, true);
   const int daily_copied = CopyRates(_Symbol, PERIOD_D1, 1, daily_needed, daily); // perf-allowed: D1 closed-bar strategy snapshot only
   if(daily_copied < daily_needed)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double prior_return = daily[0].close - daily[1].close;
   const double prior_range = daily[0].high - daily[0].low;
   if(prior_range <= 0.0)
      return false;

   const int median_days = MathMin(strategy_median_range_days, daily_copied - 1);
   double ranges[];
   ArrayResize(ranges, median_days);
   for(int i = 0; i < median_days; ++i)
      ranges[i] = daily[i].high - daily[i].low;
   ArraySort(ranges);
   const double median_range = ranges[median_days / 2];
   if(median_range <= 0.0 || prior_range < median_range)
      return false;

   const datetime start_time = daily[lookback_days].time;
   const datetime end_time = daily[0].time + PeriodSeconds(PERIOD_D1) - 1;
   MqlRates m30[];
   const int m30_copied = CopyRates(_Symbol, PERIOD_M30, start_time, end_time, m30); // perf-allowed: bounded M30 imbalance proxy under framework new-bar gate
   if(m30_copied <= 0)
      return false;

   double imbalances[];
   int bar_counts[];
   ArrayResize(imbalances, lookback_days + 1);
   ArrayResize(bar_counts, lookback_days + 1);
   ArrayInitialize(imbalances, 0.0);
   ArrayInitialize(bar_counts, 0);

   double spread_samples[];
   int spread_count = 0;
   ArrayResize(spread_samples, m30_copied);

   int day_index = lookback_days;
   for(int i = 0; i < m30_copied; ++i)
     {
      while(day_index > 0 && m30[i].time >= daily[day_index - 1].time)
         --day_index;
      if(day_index < 0 || day_index > lookback_days)
         continue;

      const datetime day_end = (day_index == 0) ? (daily[0].time + PeriodSeconds(PERIOD_D1)) : daily[day_index - 1].time;
      if(m30[i].time < daily[day_index].time || m30[i].time >= day_end)
         continue;

      if(m30[i].tick_volume <= 0)
         continue;

      double signed_volume = 0.0;
      if(m30[i].close > m30[i].open)
         signed_volume = (double)m30[i].tick_volume;
      else if(m30[i].close < m30[i].open)
         signed_volume = -(double)m30[i].tick_volume;

      imbalances[day_index] += signed_volume;
      bar_counts[day_index] += 1;

      if(m30[i].spread > 0)
        {
         spread_samples[spread_count] = (double)m30[i].spread;
         ++spread_count;
        }
     }

   if(bar_counts[0] < strategy_min_m30_bars)
      return false;

   double hist_imb[];
   ArrayResize(hist_imb, lookback_days);
   for(int i = 0; i < lookback_days; ++i)
     {
      if(bar_counts[i + 1] <= 0)
         return false;
      hist_imb[i] = imbalances[i + 1];
     }
   ArraySort(hist_imb);

   int bottom_idx = (int)MathFloor((strategy_imbalance_tail_pct / 100.0) * lookback_days) - 1;
   if(bottom_idx < 0)
      bottom_idx = 0;
   if(bottom_idx >= lookback_days)
      bottom_idx = lookback_days - 1;

   int top_idx = (int)MathCeil(((100.0 - strategy_imbalance_tail_pct) / 100.0) * lookback_days) - 1;
   if(top_idx < 0)
      top_idx = 0;
   if(top_idx >= lookback_days)
      top_idx = lookback_days - 1;

   if(spread_count >= 20)
     {
      ArrayResize(spread_samples, spread_count);
      ArraySort(spread_samples);
      int spread_idx = (int)MathCeil((strategy_spread_percentile / 100.0) * spread_count) - 1;
      if(spread_idx < 0)
         spread_idx = 0;
      if(spread_idx >= spread_count)
         spread_idx = spread_count - 1;
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > spread_samples[spread_idx])
         return false;
     }

   const double entry_buy = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double entry_sell = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_buy <= 0.0 || entry_sell <= 0.0)
      return false;

   if(prior_return < -(strategy_atr_return_mult * atr) && imbalances[0] <= hist_imb[bottom_idx])
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, entry_buy, strategy_atr_period, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "IMBALANCE_REV_LONG";
      return (req.sl > 0.0);
     }

   if(prior_return > (strategy_atr_return_mult * atr) && imbalances[0] >= hist_imb[top_idx])
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = QM_StopATR(_Symbol, req.type, entry_sell, strategy_atr_period, strategy_atr_stop_mult);
      req.tp = 0.0;
      req.reason = "IMBALANCE_REV_SHORT";
      return (req.sl > 0.0);
     }

   return false;
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
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   MqlDateTime now_dt;
   TimeToStruct(TimeCurrent(), now_dt);
   const int now_key = (now_dt.year * 10000) + (now_dt.mon * 100) + now_dt.day;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      MqlDateTime open_dt;
      TimeToStruct((datetime)PositionGetInteger(POSITION_TIME), open_dt);
      const int open_key = (open_dt.year * 10000) + (open_dt.mon * 100) + open_dt.day;
      if(now_key > open_key)
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

