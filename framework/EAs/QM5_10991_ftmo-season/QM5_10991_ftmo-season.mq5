#property strict
#property version   "5.0"
#property description "QM5_10991 ftmo-season — Seasonal-bias trend trigger (D1, long/short)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10991 ftmo-season
// -----------------------------------------------------------------------------
// Source: FTMO "How to Apply Seasonality to Your Trading Strategy" (2026-01-23).
// Card: artifacts/cards_approved/QM5_10991_ftmo-season.md (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1; long & short):
//   Seasonal bias STATE (self-contained, NO external CSV/feed):
//     The bias for the CURRENT calendar month is derived purely from the bar
//     clock (TimeToStruct(bar_time).mon) + price history. Once per new calendar
//     month we compute the MEDIAN month-over-month D1-close return for that
//     calendar month across the trailing `strategy_season_years` years.
//       median > +season_thresh_pct  -> BULLISH (longs allowed)
//       median < -season_thresh_pct  -> BEARISH (shorts allowed)
//       otherwise                    -> NEUTRAL (no trade)
//     This is a fixed deterministic lookup recomputed from the bar timestamp,
//     not an online-learned / PnL-adaptive parameter (HR14 clean).
//   Trend STATE  (long): close>EMA(50) AND EMA(50)>EMA(200).
//   Trend STATE  (short): close<EMA(50) AND EMA(50)<EMA(200).
//   Trigger EVENT(long): D1 close above Donchian(20) high (prior-N-bar high).
//   Trigger EVENT(short): D1 close below Donchian(20) low.
//   Stop  : long entry-2*ATR(14); short entry+2*ATR(14).
//   Take  : 3.0R from entry/stop.
//   Exits : (a) D1 close back across EMA(50) against the position,
//           (b) end of current calendar month (last tradable session),
//           (c) time stop after `strategy_time_stop_bars` D1 bars.
//   Month-end skip: do not OPEN within `strategy_month_end_skip` trading days
//                   of month end (signal too close to the calendar exit).
//
// .DWX invariants honoured: spread guard fails OPEN on zero modeled spread;
// no swap gate; Donchian breakout uses the prior-bar high/low (gapless-safe);
// sessions/month read from the bar clock; no external macro feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10991;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_ema_fast_period   = 50;     // trend fast EMA (D1)
input int    strategy_ema_slow_period   = 200;    // trend slow EMA (D1)
input int    strategy_donchian_period   = 20;     // Donchian breakout lookback (bars)
input int    strategy_atr_period        = 14;     // ATR period for stop
input double strategy_sl_atr_mult       = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr             = 3.0;    // take profit = RR multiple of risk
input int    strategy_season_years      = 10;     // trailing years for seasonal median
input double strategy_season_thresh_pct = 0.40;   // |median monthly return| threshold, %
input int    strategy_month_end_skip    = 2;      // skip opens within N trading days of month end
input int    strategy_time_stop_bars    = 20;     // close after N D1 bars held
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached seasonal state (advanced once per new calendar month).
//   g_season_bias: +1 bullish / -1 bearish / 0 neutral for g_season_month.
// -----------------------------------------------------------------------------
int      g_season_month = 0;     // calendar month (1..12) the cached bias is for
int      g_season_year  = 0;     // calendar year the cache was last advanced in
int      g_season_bias  = 0;     // +1 / 0 / -1

// Compute the median month-over-month D1-close return (in %) for a given
// calendar month, across the trailing `years` occurrences, using the bar clock
// and D1 closes only. Returns true on success and writes `median_pct`.
// Heavy-ish but runs at most once per calendar month (≤12×/year), gated by the
// new-month check in Strategy_EntrySignal — well within the smoke budget.
bool ComputeSeasonalMedian(const int target_month, const int years, double &median_pct)
  {
   // Pull enough D1 history to cover `years`+buffer years of closes.
   const int need_bars = (years + 2) * 366;
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   // perf-allowed: bespoke seasonality math, copied ONCE per new calendar month.
   const int got = CopyRates(_Symbol, PERIOD_D1, 1, need_bars, rates);
   if(got < 60)
      return false;

   // Walk chronologically (oldest->newest) building per-(year,month) last close.
   // A "month-over-month return" for calendar month M in year Y is:
   //   (lastClose[Y,M] / lastClose[prev calendar month]) - 1.
   double rets[];
   int    n_ret = 0;
   ArrayResize(rets, years + 4);

   int    prev_month_idx = -1;     // running (year*12+month) of the previous month seen
   double prev_month_close = 0.0;  // last close of that previous month
   int    cur_month_idx = -1;
   double cur_month_close = 0.0;
   datetime cur_month_time = 0;

   for(int i = got - 1; i >= 0; --i)   // oldest first
     {
      MqlDateTime dt;
      TimeToStruct(rates[i].time, dt);
      const int midx = dt.year * 12 + dt.mon;
      if(midx != cur_month_idx)
        {
         // a new month started: finalize the previous month
         if(cur_month_idx >= 0)
           {
            // does the just-finished month equal the target calendar month?
            MqlDateTime fin;
            TimeToStruct(cur_month_time, fin);
            if(fin.mon == target_month && prev_month_idx == cur_month_idx - 1 &&
               prev_month_close > 0.0)
              {
               const double r = (cur_month_close / prev_month_close) - 1.0;
               if(n_ret < ArraySize(rets))
                  rets[n_ret++] = r * 100.0;
              }
            prev_month_idx   = cur_month_idx;
            prev_month_close = cur_month_close;
           }
         cur_month_idx = midx;
        }
      cur_month_close = rates[i].close;
      cur_month_time  = rates[i].time;
     }

   if(n_ret <= 0)
      return false;

   // Keep only the most recent `years` observations.
   int use = n_ret;
   if(use > years)
     {
      // shift the tail (most recent are at the end since we appended chronologically)
      const int start = n_ret - years;
      for(int k = 0; k < years; ++k)
         rets[k] = rets[start + k];
      use = years;
     }

   // Median.
   ArrayResize(rets, use);
   ArraySort(rets);
   if(use % 2 == 1)
      median_pct = rets[use / 2];
   else
      median_pct = 0.5 * (rets[use / 2 - 1] + rets[use / 2]);
   return true;
  }

// Advance the cached seasonal bias if the calendar month rolled. Reads the
// current closed-bar (shift 1) time for the calendar month.
void AdvanceSeasonalBias_OnNewBar()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1); // perf-allowed: closed-bar clock
   if(bar_time <= 0)
      return;
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   if(dt.mon == g_season_month && dt.year == g_season_year)
      return; // same month — cache still valid

   g_season_month = dt.mon;
   g_season_year  = dt.year;

   double median_pct = 0.0;
   if(!ComputeSeasonalMedian(dt.mon, strategy_season_years, median_pct))
     {
      g_season_bias = 0; // insufficient history -> neutral (no trade)
      return;
     }
   if(median_pct > strategy_season_thresh_pct)
      g_season_bias = 1;
   else if(median_pct < -strategy_season_thresh_pct)
      g_season_bias = -1;
   else
      g_season_bias = 0;
  }

// True if the current closed bar is within `skip` trading days of month end.
// Uses the next-calendar-day rollover from the closed-bar time.
bool WithinMonthEndSkip(const datetime bar_time, const int skip_days)
  {
   if(skip_days <= 0)
      return false;
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   const int this_mon = dt.mon;
   // Walk forward up to `skip_days` calendar days; if the month changes within
   // that window, the bar is "near month end". Calendar-day proxy for trading
   // days is conservative (weekends shorten the real distance, never lengthen).
   datetime t = bar_time;
   for(int d = 1; d <= skip_days; ++d)
     {
      t += 86400;
      MqlDateTime fwd;
      TimeToStruct(t, fwd);
      if(fwd.mon != this_mon)
         return true;
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (regime/seasonal work is on the
// closed-bar path). Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread -> block

   return false;
  }

// Long & short entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Advance the seasonal-bias cache if the calendar month rolled.
   AdvanceSeasonalBias_OnNewBar();
   if(g_season_bias == 0)
      return false; // neutral month — skip

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar clock
   if(bar_time <= 0)
      return false;
   // Skip opening too close to the calendar month exit.
   if(WithinMonthEndSkip(bar_time, strategy_month_end_skip))
      return false;

   // --- Trend STATE (closed bar) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // Donchian(period) over the bars PRIOR to the trigger bar (shifts 2..period+1).
   // Comparing the trigger-bar close to the prior-N-bar high/low = breakout EVENT.
   double don_high = -DBL_MAX;
   double don_low  =  DBL_MAX;
   const int first_shift = 2;
   const int last_shift  = strategy_donchian_period + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed: Donchian channel build
      const double l = iLow(_Symbol, _Period, s);  // perf-allowed: Donchian channel build
      if(h > don_high) don_high = h;
      if(l < don_low)  don_low  = l;
     }
   if(don_high <= 0.0 || don_low <= 0.0)
      return false;

   // --- Long setup ---
   if(g_season_bias > 0)
     {
      if(!(close1 > ema_fast))         return false;
      if(!(ema_fast > ema_slow))       return false;
      if(!(close1 > don_high))         return false; // breakout above Donchian high

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ftmo_season_long";
      return true;
     }

   // --- Short setup ---
   if(g_season_bias < 0)
     {
      if(!(close1 < ema_fast))         return false;
      if(!(ema_fast < ema_slow))       return false;
      if(!(close1 < don_low))          return false; // breakout below Donchian low

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ftmo_season_short";
      return true;
     }

   return false;
  }

// Fixed ATR stop + RR take handle the primary risk. No active trail.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits: (a) D1 close back across EMA(50) against the position,
// (b) end of the current calendar month, (c) time stop after N D1 bars held.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's position to read direction + open time.
   bool   is_long = false;
   datetime open_time = 0;
   bool   found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long   = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      found = true;
      break;
     }
   if(!found)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema_fast > 0.0 && close1 > 0.0)
     {
      // (a) close back across EMA(50) against the position.
      if(is_long  && close1 < ema_fast)  return true;
      if(!is_long && close1 > ema_fast)  return true;
     }

   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed-bar clock
   if(bar_time > 0)
     {
      // (b) end of current calendar month — exit on the last tradable session.
      // If the NEXT calendar day is in a different month, this is month end.
      MqlDateTime now_dt, nxt_dt;
      TimeToStruct(bar_time, now_dt);
      TimeToStruct(bar_time + 86400, nxt_dt);
      if(nxt_dt.mon != now_dt.mon)
         return true;

      // (c) time stop after N D1 bars held (calendar-day proxy on D1).
      if(open_time > 0 && strategy_time_stop_bars > 0)
        {
         const long held_days = (long)((bar_time - open_time) / 86400);
         if(held_days >= strategy_time_stop_bars)
            return true;
        }
     }

   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
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

   Strategy_ManageOpenPosition();

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

   if(!QM_IsNewBar())
      return;

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
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
