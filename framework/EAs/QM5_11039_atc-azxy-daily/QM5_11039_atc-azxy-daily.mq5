#property strict
#property version   "5.0"
#property description "QM5_11039 atc-azxy-daily — Prior-Day Min/Max Previous-Year Analog Daily Scalp (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11039 atc-azxy-daily
// -----------------------------------------------------------------------------
// Source: Andrea Zani, Interview with Andrea Zani (ATC 2011), MQL5 Articles,
//         2011-12-20, https://www.mql5.com/en/articles/555 (AZXY).
// Card: artifacts/cards_approved/QM5_11039_atc-azxy-daily.md (g0_status APPROVED).
//
// Mechanics (D1-native, all reads on closed bars at shift >= 1):
//   Once per closed D1 bar build a normalized PRIOR-DAY coordinate vector from
//   the prior bar's own OHLC (gapless-CFD safe — uses the bar's High/Low/Close,
//   never a gap):
//     rangePos  = (Close[1] - Low[1]) / (High[1] - Low[1])      in [0,1]
//     bodyDir   = sign(Close[1] - Open[1])                       in {-1,0,+1}
//     rangePct  = percentile of (High[1]-Low[1]) over the last
//                 range_lookback_days closed daily ranges        in [0,1]
//   Find the matching day in the PREVIOUS YEAR (~252 trading days back) and scan
//   a +/- pattern_window_days window of analog bars. An analog bar qualifies if
//   its own normalized coordinate vector is within analog_similarity of the
//   current vector (Euclidean over the 3 normalized components). For every
//   qualifying analog bar measure its realized NEXT-day return in ATR(H1) units.
//   The MEDIAN of those next-day returns is the directional signal:
//     median >  +pattern_return_threshold  -> go LONG
//     median <  -pattern_return_threshold  -> go SHORT
//   At most ONE market order per day (one open position per symbol/magic).
//
//   Stop / Take (card P2 baseline, expressed via ATR(H1)):
//     atrH1   = ATR(14, H1) at shift 1
//     TP dist = tp_atr_h1_mult * atrH1   (small-target lock)
//     SL dist = max(sl_tp_multiple * TP_dist, sl_atr_h1_floor_mult * atrH1)
//   Time exit: close any open position at/after time_exit_hour_broker (broker
//   server time == tester chart clock; no conversion needed for a wall-clock
//   server-time exit). After TP/SL/time-exit, the one-order-per-day +
//   one-position-per-magic rule prevents re-entry the same day.
//
//   Filters:
//     - Spread guard: skip only a genuinely WIDE spread (fail-open on .DWX zero
//       modeled spread).
//     - Minimum prior-day range >= min_range_atr_d1_mult * ATR(14, D1).
//     - Skip if the previous-year analog window lacks enough qualifying bars.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
//
// NOTE: the previous-year analog scan reads raw daily OHLC at fixed closed-bar
// shifts. It runs ONCE per closed D1 bar (gated by QM_IsNewBar in OnTick before
// Strategy_EntrySignal) with a bounded window loop (<= analog_window_max bars),
// so the per-bar cost is O(range_lookback + 2*pattern_window) — well within the
// smoke budget on D1. // perf-allowed: bespoke seasonality structure.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11039;
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
input int    pattern_window_days        = 10;    // +/- analog window around the previous-year anchor day
input int    range_lookback_days        = 60;    // bars used for the prior-day range percentile
input double analog_similarity          = 0.20;  // max Euclidean distance for an analog match (normalized coords)
input int    analog_min_matches         = 3;     // min qualifying analog bars to trust the median
input double pattern_return_threshold   = 0.10;  // median next-day return (ATR-H1 units) to trigger
input double tp_atr_h1_mult             = 0.35;  // TP distance = mult * ATR(14,H1)
input double sl_tp_multiple             = 2.0;   // SL = sl_tp_multiple * TP distance ...
input double sl_atr_h1_floor_mult       = 1.0;   // ... but never tighter than this * ATR(14,H1)
input int    atr_h1_period              = 14;    // ATR period on H1 (TP/SL sizing + return units)
input int    atr_d1_period              = 14;    // ATR period on D1 (min-range filter)
input double min_range_atr_d1_mult      = 0.75;  // prior-day range must exceed this * ATR(14,D1)
input int    time_exit_hour_broker      = 22;    // close any open position at/after this broker hour
input double spread_pct_of_stop         = 25.0;  // skip if spread > this % of stop distance

// Hard ceiling on the analog window so the per-bar loop is always bounded.
#define QM_ANALOG_WINDOW_MAX 30

// -----------------------------------------------------------------------------
// Helpers (bespoke seasonality math — all read CLOSED bars only)
// -----------------------------------------------------------------------------

// Normalized prior-bar range position at a given closed-bar shift: where the
// bar's CLOSE sits inside its own High-Low range, in [0,1]. Gapless-safe.
double NormRangePos(const int shift)
  {
   const double hi = iHigh(_Symbol, PERIOD_D1, shift);  // perf-allowed: closed-bar read
   const double lo = iLow(_Symbol, PERIOD_D1, shift);   // perf-allowed
   const double cl = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed
   const double rng = hi - lo;
   if(rng <= 0.0)
      return 0.5;
   double p = (cl - lo) / rng;
   if(p < 0.0) p = 0.0;
   if(p > 1.0) p = 1.0;
   return p;
  }

// Body direction sign at a given closed-bar shift: +1 / 0 / -1.
double BodyDir(const int shift)
  {
   const double op = iOpen(_Symbol, PERIOD_D1, shift);  // perf-allowed
   const double cl = iClose(_Symbol, PERIOD_D1, shift); // perf-allowed
   if(cl > op) return  1.0;
   if(cl < op) return -1.0;
   return 0.0;
  }

// Daily true range (High-Low) at a given closed-bar shift.
double DayRange(const int shift)
  {
   return iHigh(_Symbol, PERIOD_D1, shift) - iLow(_Symbol, PERIOD_D1, shift); // perf-allowed
  }

// Range percentile of the bar at `shift` versus the `lookback` daily ranges that
// PRECEDE it (shifts shift+1 .. shift+lookback). Returns fraction in [0,1].
double RangePercentile(const int shift, const int lookback)
  {
   const double r0 = DayRange(shift);
   if(r0 <= 0.0)
      return 0.5;
   int below = 0;
   int total = 0;
   for(int k = 1; k <= lookback; ++k)
     {
      const double rk = DayRange(shift + k);
      if(rk <= 0.0)
         continue;
      ++total;
      if(rk <= r0)
         ++below;
     }
   if(total <= 0)
      return 0.5;
   return (double)below / (double)total;
  }

// Euclidean distance between two normalized coordinate vectors. bodyDir is
// rescaled from {-1,0,+1} to roughly [0,1] span (×0.5) so all three components
// share a comparable magnitude.
double VectorDistance(const double posA, const double dirA, const double pctA,
                      const double posB, const double dirB, const double pctB)
  {
   const double dp = posA - posB;
   const double dd = (dirA - dirB) * 0.5;
   const double dc = pctA - pctB;
   return MathSqrt(dp * dp + dd * dd + dc * dc);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
// All seasonality work lives in Strategy_EntrySignal on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, atr_h1_period, 1);
   if(atr_h1 <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   double tp_dist = tp_atr_h1_mult * atr_h1;
   double sl_dist = MathMax(sl_tp_multiple * tp_dist, sl_atr_h1_floor_mult * atr_h1);
   if(sl_dist <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (spread_pct_of_stop / 100.0) * sl_dist)
      return true;

   return false;
  }

// Once-per-day entry. Caller guarantees QM_IsNewBar() == true (closed D1 bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic == at most one order per day here, since
   // this hook only fires on a new closed D1 bar.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Minimum prior-day range filter ---
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, atr_d1_period, 1);
   if(atr_d1 <= 0.0)
      return false;
   const double prior_range = DayRange(1);
   if(prior_range < min_range_atr_d1_mult * atr_d1)
      return false;

   // --- Current normalized prior-day coordinate vector (prior bar = shift 1) ---
   const double cur_pos = NormRangePos(1);
   const double cur_dir = BodyDir(1);
   const double cur_pct = RangePercentile(1, range_lookback_days);

   // --- ATR(H1) — units for the next-day return measure and for TP/SL sizing ---
   const double atr_h1 = QM_ATR(_Symbol, PERIOD_H1, atr_h1_period, 1);
   if(atr_h1 <= 0.0)
      return false;

   // --- Previous-year analog window: anchor ~252 trading days back, scan a
   //     +/- pattern_window_days window. For each analog bar within the
   //     similarity radius, record its realized next-day return in ATR-H1 units. ---
   int window = pattern_window_days;
   if(window < 1) window = 1;
   if(window > QM_ANALOG_WINDOW_MAX) window = QM_ANALOG_WINDOW_MAX;

   const int anchor = 252;                 // ~1 trading year back (D1-native)
   const int first  = anchor - window;     // nearest analog shift
   const int last   = anchor + window;     // furthest analog shift

   // The percentile lookback and the next-day measure require bars deeper than
   // `last`; bail out gracefully if history is too short (returns 0 -> skip).
   if(iClose(_Symbol, PERIOD_D1, last + range_lookback_days + 1) <= 0.0) // perf-allowed: history probe
      return false;

   double next_returns[QM_ANALOG_WINDOW_MAX * 2 + 1];
   int    n_matches = 0;

   for(int s = first; s <= last; ++s)
     {
      if(s < 2)
         continue; // need a next-day bar at s-1 that is itself a CLOSED bar (>=1)

      const double a_pos = NormRangePos(s);
      const double a_dir = BodyDir(s);
      const double a_pct = RangePercentile(s, range_lookback_days);

      const double dist = VectorDistance(cur_pos, cur_dir, cur_pct,
                                         a_pos, a_dir, a_pct);
      if(dist > analog_similarity)
         continue;

      // Realized NEXT-day return after the analog bar: close[s-1] - close[s],
      // both closed bars, expressed in ATR-H1 units.
      const double c_s   = iClose(_Symbol, PERIOD_D1, s);     // perf-allowed
      const double c_nxt = iClose(_Symbol, PERIOD_D1, s - 1); // perf-allowed (next day)
      if(c_s <= 0.0 || c_nxt <= 0.0)
         continue;

      next_returns[n_matches] = (c_nxt - c_s) / atr_h1;
      ++n_matches;
     }

   if(n_matches < analog_min_matches)
      return false;

   // --- Median of the analog next-day returns (insertion sort, n is small) ---
   for(int i = 1; i < n_matches; ++i)
     {
      const double key = next_returns[i];
      int j = i - 1;
      while(j >= 0 && next_returns[j] > key)
        {
         next_returns[j + 1] = next_returns[j];
         --j;
        }
      next_returns[j + 1] = key;
     }
   double median;
   if((n_matches % 2) == 1)
      median = next_returns[n_matches / 2];
   else
      median = 0.5 * (next_returns[n_matches / 2 - 1] + next_returns[n_matches / 2]);

   // --- Direction decision ---
   QM_OrderType side;
   if(median > pattern_return_threshold)
      side = QM_BUY;
   else if(median < -pattern_return_threshold)
      side = QM_SELL;
   else
      return false;

   // --- Build entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double tp_dist = tp_atr_h1_mult * atr_h1;
   const double sl_dist = MathMax(sl_tp_multiple * tp_dist, sl_atr_h1_floor_mult * atr_h1);
   if(tp_dist <= 0.0 || sl_dist <= 0.0)
      return false;

   // SL/TP as ATR-value-derived prices (mult applied to a 1-unit ATR value).
   const double sl = QM_StopATRFromValue(_Symbol, side, entry, sl_dist, 1.0);
   const double tp = QM_TakeATRFromValue(_Symbol, side, entry, tp_dist, 1.0);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "azxy_analog_long" : "azxy_analog_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target. The time exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Time exit: close any open position at/after the broker-time exit hour. In the
// MT5 tester TimeCurrent() IS broker/server time, so a wall-clock server-time
// exit reads the hour directly (no UTC conversion for a fixed server hour).
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= time_exit_hour_broker);
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
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
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
