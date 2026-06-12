#property strict
#property version   "5.0"
#property description "QM5_10330 Illiq Rev"

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
input int    qm_ea_id                   = 10330;
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
input int    strategy_atr_period                = 14;
input double strategy_return_atr_mult           = 0.75;
input double strategy_stop_atr_mult             = 1.00;
input int    strategy_percentile_days           = 60;
input int    strategy_bars_per_day              = 24;
input double strategy_spread_percentile_min     = 70.0;
input double strategy_volume_percentile_min     = 70.0;
input int    strategy_session_start_hour        = 8;
input int    strategy_session_end_hour          = 22;
input int    strategy_max_hold_bars             = 2;
input int    strategy_min_stop_spreads          = 4;
input int    strategy_spread_session_count      = 20;
input int    strategy_spread_year_sessions      = 252;
input bool   strategy_skip_monday_first_session = true;

int  g_last_signal_session_key = 0;
bool g_signal_taken_this_session = false;

int DateKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

int HourOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour;
  }

int DayOfWeekOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.day_of_week;
  }

bool InStrategySession(const datetime t)
  {
   const int hour = HourOf(t);
   int start_h = strategy_session_start_hour;
   int end_h = strategy_session_end_hour;
   if(start_h < 0)
      start_h = 0;
   if(start_h > 23)
      start_h = 23;
   if(end_h < 0)
      end_h = 0;
   if(end_h > 24)
      end_h = 24;
   if(start_h == end_h)
      return true;
   if(start_h < end_h)
      return (hour >= start_h && hour < end_h);
   return (hour >= start_h || hour < end_h);
  }

void RefreshSessionState(const datetime t)
  {
   const int session_key = DateKey(t);
   if(session_key != g_last_signal_session_key)
     {
      g_last_signal_session_key = session_key;
      g_signal_taken_this_session = false;
     }
  }

bool IsFirstSessionBarAfterWeekend(const datetime t)
  {
   return (strategy_skip_monday_first_session &&
           DayOfWeekOf(t) == 1 &&
           HourOf(t) == strategy_session_start_hour);
  }

double CurrentSpreadPrice()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
      return ask - bid;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(point > 0.0 && spread_points > 0)
      return (double)spread_points * point;
   return 0.0;
  }

double MedianValue(const double &source[], const int count)
  {
   if(count <= 0)
      return 0.0;

   double tmp[];
   ArrayResize(tmp, count);
   for(int i = 0; i < count; ++i)
      tmp[i] = source[i];
   ArraySort(tmp);

   const int mid = count / 2;
   if((count % 2) == 1)
      return tmp[mid];
   return (tmp[mid - 1] + tmp[mid]) * 0.5;
  }

double PercentileValue(const double &source[], const int count, const double pct)
  {
   if(count <= 0)
      return 0.0;

   double tmp[];
   ArrayResize(tmp, count);
   for(int i = 0; i < count; ++i)
      tmp[i] = source[i];
   ArraySort(tmp);

   double clipped = pct;
   if(clipped < 0.0)
      clipped = 0.0;
   if(clipped > 100.0)
      clipped = 100.0;

   int idx = (int)MathFloor((clipped / 100.0) * (double)(count - 1) + 0.5);
   if(idx < 0)
      idx = 0;
   if(idx >= count)
      idx = count - 1;
   return tmp[idx];
  }

void AppendDouble(double &values[], int &count, const double value)
  {
   if(count >= ArraySize(values))
      ArrayResize(values, count + 32);
   values[count] = value;
   count++;
  }

double PercentileRank(const double value, const double &history[], const int count)
  {
   if(count <= 0)
      return 0.0;

   int at_or_below = 0;
   for(int i = 0; i < count; ++i)
      if(history[i] <= value)
         at_or_below++;
   return 100.0 * (double)at_or_below / (double)count;
  }

bool LoadClosedH1Rates(MqlRates &rates[])
  {
   const int pct_bars = MathMax(2, strategy_percentile_days * strategy_bars_per_day + 2);
   const int spread_bars = MathMax(2, strategy_spread_year_sessions * strategy_bars_per_day + strategy_bars_per_day);
   const int bars_needed = MathMax(pct_bars, spread_bars);
   ArrayResize(rates, bars_needed);
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_H1, 1, bars_needed, rates); // perf-allowed: closed-bar liquidity distribution
   if(copied > 0)
      ArrayResize(rates, copied);
   return (copied >= MathMax(3, pct_bars / 4));
  }

bool LiquidityPressurePasses(const MqlRates &rates[], const int copied)
  {
   const int lookback = MathMin(copied - 1, strategy_percentile_days * strategy_bars_per_day);
   if(lookback < 30)
      return false;

   double spread_history[];
   double volume_history[];
   int spread_count = 0;
   int volume_count = 0;
   ArrayResize(spread_history, lookback);
   ArrayResize(volume_history, lookback);

   for(int i = 1; i <= lookback; ++i)
     {
      if(rates[i].spread > 0)
        {
         spread_history[spread_count] = (double)rates[i].spread;
         spread_count++;
        }
      if(rates[i].tick_volume > 0)
        {
         volume_history[volume_count] = (double)rates[i].tick_volume;
         volume_count++;
        }
     }

   if(spread_count < 30 || volume_count < 30)
      return false;

   double current_spread_points = (double)rates[0].spread;
   if(current_spread_points <= 0.0)
     {
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      const double spread_price = CurrentSpreadPrice();
      if(point <= 0.0 || spread_price <= 0.0)
         return false;
      current_spread_points = spread_price / point;
     }

   const double spread_pct = PercentileRank(current_spread_points, spread_history, spread_count);
   const double volume_pct = PercentileRank((double)rates[0].tick_volume, volume_history, volume_count);
   return (spread_pct >= strategy_spread_percentile_min &&
           volume_pct >= strategy_volume_percentile_min);
  }

bool HighSpreadRegime(const MqlRates &rates[], const int copied, const int current_session_key)
  {
   double session_medians[];
   double day_spreads[];
   int med_count = 0;
   int day_count = 0;
   int active_key = 0;
   ArrayResize(session_medians, strategy_spread_year_sessions + 8);
   ArrayResize(day_spreads, 32);

   for(int i = 0; i < copied; ++i)
     {
      if(!InStrategySession(rates[i].time) || rates[i].spread <= 0)
         continue;

      const int key = DateKey(rates[i].time);
      if(key == current_session_key)
         continue;

      if(active_key != 0 && key != active_key && day_count > 0)
        {
         AppendDouble(session_medians, med_count, MedianValue(day_spreads, day_count));
         day_count = 0;
         if(med_count >= strategy_spread_year_sessions)
            break;
        }

      active_key = key;
      AppendDouble(day_spreads, day_count, (double)rates[i].spread);
     }

   if(day_count > 0 && med_count < strategy_spread_year_sessions)
      AppendDouble(session_medians, med_count, MedianValue(day_spreads, day_count));

   if(med_count < MathMax(30, strategy_spread_session_count))
      return false;

   const int recent_count = MathMin(strategy_spread_session_count, med_count);
   double recent_medians[];
   ArrayResize(recent_medians, recent_count);
   for(int i = 0; i < recent_count; ++i)
      recent_medians[i] = session_medians[i];

   const double prior_20_median = MedianValue(recent_medians, recent_count);
   const double year_p80 = PercentileValue(session_medians, med_count, 80.0);
   return (year_p80 > 0.0 && prior_20_median > year_p80);
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(!InStrategySession(broker_now))
      return true;
   if(CurrentSpreadPrice() <= 0.0)
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

   MqlRates rates[];
   if(!LoadClosedH1Rates(rates))
      return false;

   const datetime signal_bar_time = rates[0].time;
   RefreshSessionState(signal_bar_time);
   if(!InStrategySession(signal_bar_time))
      return false;
   if(g_signal_taken_this_session)
      return false;
   if(IsFirstSessionBarAfterWeekend(signal_bar_time))
      return false;
   if(HighSpreadRegime(rates, ArraySize(rates), DateKey(signal_bar_time)))
      return false;
   if(!LiquidityPressurePasses(rates, ArraySize(rates)))
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double one_bar_return = rates[0].close - rates[1].close;
   const double shock = strategy_return_atr_mult * atr;
   const double stop_distance = strategy_stop_atr_mult * atr;
   const double spread_price = CurrentSpreadPrice();
   if(stop_distance <= 0.0 || spread_price <= 0.0)
      return false;
   if(stop_distance < (double)strategy_min_stop_spreads * spread_price)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(one_bar_return <= -shock)
     {
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = NormalizeDouble(ask - stop_distance, _Digits);
      req.tp = 0.0;
      req.reason = "ILLIQ_REV_LONG";
      g_signal_taken_this_session = true;
      return true;
     }

   if(one_bar_return >= shock)
     {
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = NormalizeDouble(bid + stop_distance, _Digits);
      req.tp = 0.0;
      req.reason = "ILLIQ_REV_SHORT";
      g_signal_taken_this_session = true;
      return true;
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// Typical work: break-even shift, ATR trail, partial close at +1R, etc.
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, pyramiding, or partial close.
  }

// Return TRUE to close the open position now (e.g. opposite-signal exit,
// max-hold-time exceeded, session end).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const bool session_closed = !InStrategySession(TimeCurrent());
   const int max_hold_seconds = MathMax(1, strategy_max_hold_bars) * PeriodSeconds(PERIOD_H1);

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
      if(session_closed)
         return true;
      if(open_time > 0 && (TimeCurrent() - open_time) >= max_hold_seconds)
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
