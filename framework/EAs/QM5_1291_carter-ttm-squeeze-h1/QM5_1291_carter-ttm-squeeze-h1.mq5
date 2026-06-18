#property strict
#property version   "5.0"
#property description "QM5_1291 carter-ttm-squeeze-h1 — Carter TTM Squeeze release + momentum (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1291 carter-ttm-squeeze-h1
// -----------------------------------------------------------------------------
// Source: John Carter, "Mastering the Trade" (McGraw-Hill, 2005,
//   ISBN 978-0071459587) — TTM Squeeze. FF Trading-Systems cluster (6e967762).
// Card: artifacts/cards_approved/QM5_1291_carter-ttm-squeeze-h1.md (g0 APPROVED).
//
// Realization (framework-native, closed-bar reads at shift 1 latest):
//
//   Squeeze STATE   : Bollinger Bands strictly INSIDE the Keltner Channel
//                       BB_Upper < KC_Upper  AND  BB_Lower > KC_Lower
//                     where BB = QM_BB_Upper/Lower(bb_period, bb_dev) and
//                     KC = EMA(kc_period) +/- kc_atr_mult * ATR(kc_atr_period).
//                     = low-volatility compression regime.
//
//   Squeeze LATCH   : the squeeze STATE held for at least squeeze_min_bars
//                     consecutive closed bars ENDING at shift 2 (the bar before
//                     the trigger bar). This is the "continues N bars" rule.
//
//   Release EVENT   : squeeze ON at shift 2 and OFF at shift 1. This single
//                     on->off transition is the ONE trigger event per bar
//                     (no two-cross-same-bar trap; everything else is a STATE).
//
//   Direction STATE : TTM momentum proxy = closed-form linear-regression slope
//                     of (close - midline) over mom_period closed bars, where
//                     midline = average of the Donchian mid ((HH+LL)/2) and the
//                     SMA(close) over the same window (Carter's TTM baseline).
//                       mom > 0 -> long bias ; mom < 0 -> short bias.
//
//   Macro STATE     : EMA(macro_ema_period) bias gate — long only if
//                     close[1] > EMA ; short only if close[1] < EMA.
//
//   Stop            : QM_StopATR(atr_period, sl_atr_mult) from entry.
//   Take profit     : QM_TakeRR(rr) off entry/SL (R-multiple, ~1:2).
//   Exits (closed-bar):
//     - Time-stop   : position older than time_stop_bars H1 bars -> close.
//     - Mom-flip    : TTM momentum sign turns AGAINST the open position -> close.
//     - (SL/TP are the primary exits, handled by the broker.)
//
//   Session         : trade only inside [session_start_h, session_end_h) broker
//                     time (Europe + US main session). Cheap O(1) per-tick gate.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed. The linear-regression slope is a fixed closed-form OLS over a
//   bounded window — a transparent non-ML computation (HR14 compliant).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1291;
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
input double strategy_bb_dev             = 2.0;    // Bollinger deviation (MANDATORY arg)
input int    strategy_kc_period          = 20;     // Keltner EMA midline period
input int    strategy_kc_atr_period      = 10;     // ATR period for Keltner width
input double strategy_kc_atr_mult        = 1.5;    // Keltner channel = EMA +/- mult*ATR
input int    strategy_squeeze_min_bars   = 6;      // squeeze must hold >= N bars before release
input int    strategy_mom_period         = 20;     // TTM momentum linear-regression window
input int    strategy_macro_ema_period   = 200;    // macro-bias EMA gate
input int    strategy_atr_period         = 14;     // ATR period for stop/target
input double strategy_sl_atr_mult        = 1.0;    // stop distance = mult * ATR
input double strategy_rr                 = 2.0;    // take-profit R-multiple (~1:2)
input int    strategy_time_stop_bars     = 24;     // close after N H1 bars without TP/SL
input int    strategy_session_start_h    = 6;      // broker-hour session open (inclusive)
input int    strategy_session_end_h      = 21;     // broker-hour session close (exclusive)
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers
// -----------------------------------------------------------------------------

// Squeeze-ON STATE at the given closed-bar shift: Bollinger Bands strictly
// inside the Keltner Channel (low-volatility compression). Fails closed (false)
// on any unavailable buffer read (warmup) so the gate is safe.
bool SqueezeOnAt(const int shift)
  {
   const double bb_up = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, shift);
   const double bb_lo = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_dev, shift);
   if(bb_up <= 0.0 || bb_lo <= 0.0)
      return false;

   const double mid = QM_EMA(_Symbol, _Period, strategy_kc_period, shift);
   const double atr = QM_ATR(_Symbol, _Period, strategy_kc_atr_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return false;

   const double kc_up = mid + strategy_kc_atr_mult * atr;
   const double kc_lo = mid - strategy_kc_atr_mult * atr;

   // BB inside KC => compression regime.
   return (bb_up < kc_up && bb_lo > kc_lo);
  }

// TTM momentum oscillator at the given trigger shift: closed-form OLS slope of
// (close - midline) over strategy_mom_period closed bars, where the midline is
// the average of the Donchian mid ((HH+LL)/2) and the SMA(close) of the window
// (Carter's TTM baseline). Returns the slope; sign gives the direction.
// `ok` is set false on any warmup/unavailable read. Bounded loop (mom_period)
// on the closed-bar path only — perf-allowed bespoke regression math.
double MomentumSlopeAt(const int trigger_shift, bool &ok)
  {
   ok = false;
   const int n = strategy_mom_period;
   if(n < 3)
      return 0.0;

   // --- Window high/low (Donchian) and close sum (SMA) over the n closed bars
   //     ending at trigger_shift. ---
   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   double close_sum = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int s = trigger_shift + k;
      const double hi = iHigh(_Symbol, _Period, s);   // perf-allowed: bounded closed-bar regression window
      const double lo = iLow(_Symbol, _Period, s);    // perf-allowed
      const double cl = iClose(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0 || cl <= 0.0)
         return 0.0;                                   // warmup -> fail closed
      if(hi > hh) hh = hi;
      if(lo < ll) ll = lo;
      close_sum += cl;
     }

   const double donchian_mid = 0.5 * (hh + ll);
   const double sma_close     = close_sum / (double)n;
   const double midline       = 0.5 * (donchian_mid + sma_close);

   // --- OLS slope of y = (close - midline) against x = bar index. We index x
   //     so that the most-recent bar (trigger_shift) is the largest x, i.e.
   //     x = (n-1-k) for k = 0..n-1; a positive slope => momentum building up
   //     toward the trigger bar. ---
   double sum_x = 0.0, sum_y = 0.0, sum_xx = 0.0, sum_xy = 0.0;
   for(int k = 0; k < n; ++k)
     {
      const int s = trigger_shift + k;
      const double cl = iClose(_Symbol, _Period, s); // perf-allowed: bounded closed-bar regression window
      if(cl <= 0.0)
         return 0.0;
      const double x = (double)(n - 1 - k);
      const double y = cl - midline;
      sum_x  += x;
      sum_y  += y;
      sum_xx += x * x;
      sum_xy += x * y;
     }

   const double denom = (double)n * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12)
      return 0.0;

   const double slope = ((double)n * sum_xy - sum_x * sum_y) / denom;
   ok = true;
   return slope;
  }

// Broker-time session gate: true if `broker_now` is inside the [start, end)
// hour window. Wrap-safe (end < start treated as overnight, though defaults are
// intraday). O(1).
bool InSession(const datetime broker_now)
  {
   MqlDateTime dt;
   TimeToStruct(broker_now, dt);
   const int h = dt.hour;
   if(strategy_session_start_h == strategy_session_end_h)
      return true; // degenerate full-day
   if(strategy_session_start_h < strategy_session_end_h)
      return (h >= strategy_session_start_h && h < strategy_session_end_h);
   // overnight wrap
   return (h >= strategy_session_start_h || h < strategy_session_end_h);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + spread guard. Regime / signal work
// is on the closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero
// modeled spread (ask == bid).
bool Strategy_NoTradeFilter()
  {
   // --- Session gate (broker time) ---
   if(!InSession(TimeCurrent()))
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Squeeze-release + momentum-direction entry. Caller guarantees
// QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Release EVENT: squeeze ON at shift 2, OFF at shift 1 (single transition) ---
   const bool sq_prev = SqueezeOnAt(2);
   const bool sq_now  = SqueezeOnAt(1);
   if(!(sq_prev && !sq_now))
      return false; // not a fresh release this bar

   // --- Squeeze LATCH: the squeeze STATE must have held for at least
   //     squeeze_min_bars consecutive bars ending at shift 2. We already know
   //     shift 2 is ON; require ON across shifts 2 .. (squeeze_min_bars+1). ---
   if(strategy_squeeze_min_bars > 1)
     {
      const int last_shift = strategy_squeeze_min_bars + 1; // shift 2 already counts as bar #1
      for(int s = 3; s <= last_shift; ++s)
        {
         if(!SqueezeOnAt(s))
            return false; // squeeze did not persist long enough
        }
     }

   // --- Direction STATE: TTM momentum slope over the last closed window ---
   bool mom_ok = false;
   const double mom = MomentumSlopeAt(1, mom_ok);
   if(!mom_ok)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 <= 0.0 || macro <= 0.0)
      return false;

   QM_OrderType dir;
   double entry;
   if(mom > 0.0)
     {
      // --- Macro STATE: long only with close above the macro EMA ---
      if(!(close1 > macro))
         return false;
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(mom < 0.0)
     {
      if(!(close1 < macro))
         return false;
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false; // flat momentum — no directional conviction

   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, dir, entry, strategy_atr_period, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ttm_squeeze_release";
   return true;
  }

// Primary exits are the broker-side ATR stop and RR target; no active
// management (trailing/BE) per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: time-stop (position too old) OR momentum-flip against the
// open direction. Caller closes the magic's positions when this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read its direction + open time.
   bool   have_pos    = false;
   long   pos_type    = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time-stop: position older than time_stop_bars H1 bars ---
   if(strategy_time_stop_bars > 0)
     {
      const int bar_seconds = PeriodSeconds(_Period);
      if(bar_seconds > 0)
        {
         const long held_bars = (long)((TimeCurrent() - open_time) / bar_seconds);
         if(held_bars >= (long)strategy_time_stop_bars)
            return true;
        }
     }

   // --- Momentum-flip exit: TTM momentum sign turns against the position ---
   bool mom_ok = false;
   const double mom = MomentumSlopeAt(1, mom_ok);
   if(mom_ok)
     {
      if(pos_type == POSITION_TYPE_BUY  && mom < 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && mom > 0.0)
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
