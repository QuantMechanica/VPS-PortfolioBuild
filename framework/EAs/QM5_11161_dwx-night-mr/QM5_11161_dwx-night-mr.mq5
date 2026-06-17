#property strict
#property version   "5.0"
#property description "QM5_11161 dwx-night-mr — Night Mean Reversion (BB/ATR, M15 FX)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11161 dwx-night-mr
// -----------------------------------------------------------------------------
// Source: Darwinex Blog "The Journey of an Automated Trading Expert" (Wim),
//   2024-10-03 — night scalping after the New York session, mean-reversion to
//   exploit post-volatility stability, hard stop on every trade.
// Card: artifacts/cards_approved/QM5_11161_dwx-night-mr.md (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1; one position per symbol/magic):
//   Session STATE  : broker-time night window [start_h .. end_h) (wrap-safe).
//                    DXZ broker time = NY-Close GMT+2/+3 (DST-aware); the card's
//                    22:00-01:00 window is already stated in broker time, so we
//                    key the window off the broker clock (TimeCurrent()) directly.
//   Skip windows   : rollover spread-expansion (23:55-00:10 broker) and
//                    Sunday-night / Friday-night sessions (low edge, gap risk).
//   Vol STATE      : ATR(14) on the last closed bar is BELOW its same-time-of-day
//                    median across the prior `atr_median_days` days (post-vol
//                    stability). Same-time = N*bars_per_day shifts back.
//   Long  EVENT    : previous closed bar closes below the lower Bollinger band.
//   Short EVENT    : previous closed bar closes above the upper Bollinger band.
//   Spread guard   : skip only when spread > spread_pct_of_stop of the planned
//                    1.2*ATR stop distance (fail-open on .DWX zero modeled spread).
//   Stop           : 1.2 * ATR(14) from entry (hard stop every trade).
//   Take profit    : Bollinger middle band (mean reversion target).
//   Managed exits  : (a) time stop after max_holding_bars closed bars;
//                    (b) force-flat at the end of the night window;
//                    (c) emergency exit if the last close runs beyond
//                        band_break_mult * band-width against the position.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11161;
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
input int    strategy_bb_period          = 20;     // Bollinger period
input double strategy_bb_deviation       = 2.0;    // Bollinger deviation (MANDATORY arg)
input int    strategy_atr_period         = 14;     // ATR period (filter / stop)
input double strategy_atr_sl_mult        = 1.2;    // stop distance = mult * ATR(14)
input int    strategy_session_start_h    = 22;     // night window start, BROKER hour
input int    strategy_session_end_h      = 1;      // night window end (exclusive), BROKER hour
input int    strategy_rollover_skip_start_min = 1435; // 23:55 as minutes-of-day (broker)
input int    strategy_rollover_skip_end_min   = 10;   // 00:10 as minutes-of-day (broker)
input int    strategy_max_holding_bars   = 8;      // time stop, in closed M15 bars
input int    strategy_atr_median_days    = 20;     // same-time-of-day ATR median window (days)
input double strategy_band_break_mult    = 1.5;    // emergency exit beyond mult*band-width
input double strategy_spread_pct_of_stop = 8.0;    // skip if spread > this % of stop distance
input bool   strategy_skip_sunday_night  = true;   // skip Sunday-night session
input bool   strategy_skip_friday_night  = true;   // skip Friday-night session

// File-scope: bar index on which the current position was opened (time stop).
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// Helpers (broker-time session logic)
// -----------------------------------------------------------------------------

// Minutes-of-day in broker time for a given broker datetime.
int BrokerMinutesOfDay(const datetime broker_t)
  {
   MqlDateTime dt;
   TimeToStruct(broker_t, dt);
   return dt.hour * 60 + dt.min;
  }

// TRUE if the broker hour falls inside the wrap-safe night window [start..end).
bool InNightWindow(const datetime broker_t)
  {
   MqlDateTime dt;
   TimeToStruct(broker_t, dt);
   const int h = dt.hour;
   const int s = strategy_session_start_h;
   const int e = strategy_session_end_h;
   if(s == e)
      return false;
   if(s < e)
      return (h >= s && h < e);
   // Wrap across midnight (e.g. 22 .. 1): in window if h>=s OR h<e.
   return (h >= s || h < e);
  }

// TRUE inside the rollover skip window (wrap-safe, minute resolution).
bool InRolloverSkip(const datetime broker_t)
  {
   const int m = BrokerMinutesOfDay(broker_t);
   const int s = strategy_rollover_skip_start_min;
   const int e = strategy_rollover_skip_end_min;
   if(s <= e)
      return (m >= s && m < e);
   return (m >= s || m < e);   // wraps midnight
  }

// TRUE if this broker-time session should be skipped by weekday rule.
// Sunday-night session = Sunday (broker DOW 0). Friday-night session = Friday.
bool SkipByWeekday(const datetime broker_t)
  {
   MqlDateTime dt;
   TimeToStruct(broker_t, dt);
   if(strategy_skip_sunday_night && dt.day_of_week == 0)
      return true;
   if(strategy_skip_friday_night && dt.day_of_week == 5)
      return true;
   return false;
  }

// Same-time-of-day ATR median across the prior `days` days. On M15 one day is
// 96 bars; sample ATR at shifts 1, 1+bpd, 1+2*bpd ... once per closed bar.
// Returns false if too few valid samples.
bool SameTimeATRMedian(const int days, double &median_out)
  {
   const int bars_per_day = (PeriodSeconds(PERIOD_D1) / PeriodSeconds(_Period));
   if(bars_per_day <= 0)
      return false;
   double samples[];
   ArrayResize(samples, days);
   int n = 0;
   for(int d = 0; d < days; ++d)
     {
      const int shift = 1 + d * bars_per_day;
      const double a = QM_ATR(_Symbol, _Period, strategy_atr_period, shift);
      if(a > 0.0)
        {
         samples[n] = a;
         ++n;
        }
     }
   if(n < 3)
      return false;
   ArrayResize(samples, n);
   ArraySort(samples);
   if((n % 2) == 1)
      median_out = samples[n / 2];
   else
      median_out = 0.5 * (samples[n / 2 - 1] + samples[n / 2]);
   return (median_out > 0.0);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: outside the night window / skip windows, and the
// spread guard. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();

   if(!InNightWindow(broker_now))
      return true;
   if(InRolloverSkip(broker_now))
      return true;
   if(SkipByWeekday(broker_now))
      return true;

   // Spread guard — only a genuinely wide spread blocks (fail-open on 0 spread).
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_atr_sl_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Mean-reversion entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Volatility STATE: ATR below its same-time-of-day median (quiet) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   double atr_median = 0.0;
   if(!SameTimeATRMedian(strategy_atr_median_days, atr_median))
      return false;
   if(!(atr_value < atr_median))
      return false; // not a post-volatility quiet regime

   // --- Bollinger bands on the last closed bar ---
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || bb_mid <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const bool long_signal  = (close1 < bb_lower); // stretched below lower band -> revert up
   const bool short_signal = (close1 > bb_upper); // stretched above upper band -> revert down
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType dir = long_signal ? QM_BUY : QM_SELL;

   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop: 1.2 * ATR from entry. Take profit: middle band (mean target).
   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_atr_sl_mult);
   const double tp = QM_TM_NormalizePrice(_Symbol, bb_mid);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   // Sanity: TP must be on the profitable side of entry for the chosen direction.
   if(dir == QM_BUY && !(tp > entry))
      return false;
   if(dir == QM_SELL && !(tp < entry))
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_signal ? "night_mr_long" : "night_mr_short";

   // Record entry bar time for the time stop (set on confirmed send below not
   // available here; latch on the last closed bar open which is the trigger bar).
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
   return true;
  }

// No active SL/TP modification beyond the fixed stop/middle-band target.
void Strategy_ManageOpenPosition()
  {
  }

// Managed discretionary exits: time stop, force-flat at window end, and the
// band-break emergency exit. Returns TRUE to close the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const datetime broker_now = TimeCurrent();

   // (b) Force flat at the end of the night window (outside window now).
   if(!InNightWindow(broker_now))
      return true;

   // (a) Time stop after max_holding_bars closed bars since entry.
   if(g_entry_bar_time > 0 && strategy_max_holding_bars > 0)
     {
      const int held = iBarShift(_Symbol, _Period, g_entry_bar_time, false);
      if(held >= strategy_max_holding_bars)
         return true;
     }

   // (c) Emergency exit: last close runs beyond band_break_mult * band-width
   //     against the position direction.
   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(bb_upper <= 0.0 || bb_lower <= 0.0 || bb_mid <= 0.0)
      return false;
   const double half_width = 0.5 * (bb_upper - bb_lower);
   if(half_width <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine current position direction for this magic.
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   const double break_dist = strategy_band_break_mult * half_width;
   if(is_long)
     {
      // Long expects reversion up; bailing if it collapses well below lower band.
      if(close1 < (bb_lower - break_dist))
         return true;
     }
   else
     {
      if(close1 > (bb_upper + break_dist))
         return true;
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

   // Per-tick: discretionary exit (time stop / window end / band break) BEFORE
   // the no-trade filter, so force-flat fires even outside the night window.
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

   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

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
