#property strict
#property version   "5.0"
#property description "QM5_1288 bb-width-regime-breakout — BB-Width Squeeze-Release Breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1288 bb-width-regime-breakout
// -----------------------------------------------------------------------------
// Source: ForexFactory BB-Width-Squeeze community cluster (2012-2021) +
//   John Bollinger "Bollinger on Bollinger Bands" (2001, McGraw-Hill).
// Card: artifacts/cards_approved/QM5_1288_bb-width-regime-breakout.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one position per symbol/magic):
//   BB(20, 2.0) on H1. width = (upper - lower) / middle  (normalised band-width).
//   BB_width_percentile_100 = fraction of last 100 closed bars with width < now.
//   SQUEEZE STATE  : width-percentile <= squeeze_pct (bottom quantile of width).
//   SQUEEZE LATCH  : TRUE once the last `latch_bars` closed bars were ALL in
//                    squeeze. Persists until consumed by an entry OR auto-expires
//                    after `latch_expiry_bars` closed bars with no breakout.
//   ENTRY EVENT    : with latch TRUE, the FIRST closed bar OUT of the band ——
//                    LONG : close[1] > upper[1] AND close[2] <= upper[2]
//                           AND close[1] > EMA(200)[1]  (macro bias agrees)
//                    SHORT: close[1] < lower[1] AND close[2] >= lower[2]
//                           AND close[1] < EMA(200)[1]
//                    The squeeze percentile/latch is the STATE filter; the single
//                    band break is the EVENT trigger (no two-cross-same-bar trap).
//   STOP           : opposite band at the trigger bar (long: lower[1]; short:
//                    upper[1]), with a floor of ATR(14) * atr_floor_mult so a
//                    still-tight band cannot produce a micro-stop.
//   TARGET         : RR = tp_rr (default 2.5) off the entry/stop distance.
//   EXITS (closed bar): mid-band touch (pulse exhausted), opposite-band touch
//                    (full traverse), or time-stop after `time_stop_bars` bars.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1288;
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
input int    strategy_bb_period          = 20;    // Bollinger Band period
input double strategy_bb_deviation       = 2.0;   // Bollinger Band stdev deviation
input int    strategy_pct_window         = 100;   // rolling window for width percentile
input double strategy_squeeze_pct        = 20.0;  // squeeze if width-pctile <= this (%)
input int    strategy_latch_bars         = 5;     // consecutive squeeze bars to arm latch
input int    strategy_latch_expiry_bars  = 50;    // bars before an unconsumed latch expires
input int    strategy_ema_period         = 200;   // macro-bias EMA
input int    strategy_atr_period         = 14;    // ATR for the stop floor
input double strategy_atr_floor_mult     = 1.0;   // min SL distance = mult * ATR
input double strategy_tp_rr              = 2.5;   // take-profit reward:risk multiple
input int    strategy_time_stop_bars     = 24;    // exit after this many closed bars in trade
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached squeeze-latch state (advanced once per closed bar).
// -----------------------------------------------------------------------------
bool     g_latch_armed     = false;   // squeeze latch currently armed
int      g_latch_age       = 0;       // closed bars since the latch armed
datetime g_entry_bar_time  = 0;       // bar-open time of the active entry (time-stop)

// Normalised BB-width at a given closed-bar shift. Returns -1.0 on a bad read.
double BBWidthAtShift(const int shift)
  {
   const double upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double mid   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   if(upper <= 0.0 || lower <= 0.0 || mid <= 0.0)
      return -1.0;
   return (upper - lower) / mid;
  }

// Rolling percentile rank (0..100) of the BB-width at `ref_shift` against the
// `strategy_pct_window` bars that PRECEDE it. Returns -1.0 if data is missing.
double BBWidthPercentile(const int ref_shift)
  {
   const double w_ref = BBWidthAtShift(ref_shift);
   if(w_ref < 0.0)
      return -1.0;

   int counted = 0;
   int smaller = 0;
   for(int k = 1; k <= strategy_pct_window; ++k)
     {
      const double w_k = BBWidthAtShift(ref_shift + k);
      if(w_k < 0.0)
         continue;
      counted++;
      if(w_k < w_ref)
         smaller++;
     }
   if(counted <= 0)
      return -1.0;
   return (100.0 * (double)smaller) / (double)counted;
  }

// TRUE if bar at `shift` is in the squeeze regime (width-pctile <= threshold).
bool IsSqueezeBar(const int shift)
  {
   const double pct = BBWidthPercentile(shift);
   if(pct < 0.0)
      return false;
   return (pct <= strategy_squeeze_pct);
  }

// Advance the squeeze latch by ONE closed bar. Called once per new bar BEFORE
// the entry gate. Latch arms when the last `latch_bars` closed bars are all
// squeeze; ages each bar; auto-expires after `latch_expiry_bars`.
void AdvanceLatch_OnNewBar()
  {
   if(g_latch_armed)
     {
      g_latch_age++;
      if(g_latch_age > strategy_latch_expiry_bars)
        {
         g_latch_armed = false;
         g_latch_age   = 0;
        }
      return; // already armed — keep it until consumed or expired
     }

   // Not armed yet: arm if the last `latch_bars` closed bars are ALL squeeze.
   bool all_squeeze = true;
   for(int s = 1; s <= strategy_latch_bars; ++s)
     {
      if(!IsSqueezeBar(s))
        {
         all_squeeze = false;
         break;
        }
     }
   if(all_squeeze)
     {
      g_latch_armed = true;
      g_latch_age   = 0;
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_atr_floor_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Squeeze-release breakout entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Latch must be armed (squeeze state held for `latch_bars`) to trade.
   if(!g_latch_armed)
      return false;

   // --- Band geometry at the trigger (shift 1) and prior (shift 2) bars ---
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper2 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double lower2 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(upper1 <= 0.0 || lower1 <= 0.0 || upper2 <= 0.0 || lower2 <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- First-bar-out the band = the single trigger EVENT (one per release) ---
   const bool first_out_top = (close1 > upper1 && close2 <= upper2);
   const bool first_out_bot = (close1 < lower1 && close2 >= lower2);

   QM_OrderType dir;
   double sl_band;        // raw opposite-band stop reference
   if(first_out_top && close1 > ema)
     {
      dir     = QM_BUY;
      sl_band = lower1;   // opposite band on a long break-up
     }
   else if(first_out_bot && close1 < ema)
     {
      dir     = QM_SELL;
      sl_band = upper1;   // opposite band on a short break-down
     }
   else
      return false;

   const double entry = SymbolInfoDouble(_Symbol, (dir == QM_BUY) ? SYMBOL_ASK : SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Stop: opposite band, floored to atr_floor_mult * ATR distance ---
   const double floor_dist = strategy_atr_floor_mult * atr_value;
   double sl;
   if(dir == QM_BUY)
     {
      double dist = entry - sl_band;          // band-based distance
      if(dist < floor_dist)
         dist = floor_dist;                    // apply ATR floor
      sl = entry - dist;
     }
   else
     {
      double dist = sl_band - entry;
      if(dist < floor_dist)
         dist = floor_dist;
      sl = entry + dist;
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Target: fixed RR off the (floored) stop distance ---
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   // Consume the latch and record the entry bar for the time-stop.
   g_latch_armed    = false;
   g_latch_age      = 0;
   g_entry_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "bb_squeeze_break_long" : "bb_squeeze_break_short";
   return true;
  }

// No active SL/TP modification in baseline (fixed band-floor stop + RR target).
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: mid-band touch (pulse exhausted), opposite-band touch
// (full traverse), or time-stop after `time_stop_bars` closed bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_entry_bar_time = 0;
      return false;
     }

   // Resolve our open position's direction.
   bool   is_long  = false;
   bool   have_pos = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long  = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      have_pos = true;
      break;
     }
   if(!have_pos)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double mid1   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(close1 <= 0.0 || mid1 <= 0.0 || upper1 <= 0.0 || lower1 <= 0.0)
      return false;

   if(is_long)
     {
      if(close1 <= mid1)   return true;   // mid-band touch — pulse exhausted
      if(close1 <= lower1) return true;   // opposite-band touch — full traverse
     }
   else
     {
      if(close1 >= mid1)   return true;
      if(close1 >= upper1) return true;
     }

   // --- Time-stop: close after `time_stop_bars` closed bars since entry ---
   if(g_entry_bar_time > 0)
     {
      const datetime bar_now = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open time
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const int bars_held = (int)((bar_now - g_entry_bar_time) / secs_per_bar);
         if(bars_held >= strategy_time_stop_bars)
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

   g_latch_armed    = false;
   g_latch_age      = 0;
   g_entry_bar_time = 0;

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
      g_entry_bar_time = 0;
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Advance the squeeze-latch state ONCE per closed bar before the entry gate.
   AdvanceLatch_OnNewBar();

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
