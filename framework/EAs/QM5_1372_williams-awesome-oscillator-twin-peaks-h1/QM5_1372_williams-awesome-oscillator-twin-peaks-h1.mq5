#property strict
#property version   "5.0"
#property description "QM5_1372 williams-awesome-oscillator-twin-peaks-h1 — Bill Williams Awesome Oscillator twin-peaks confirmation entry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1372 williams-awesome-oscillator-twin-peaks-h1
// -----------------------------------------------------------------------------
// Source: Bill Williams, "Trading Chaos" (Wiley 1995, ISBN 0-471-11929-6) and
//   "New Trading Dimensions" (Wiley 1998, ISBN 0-471-29541-8). Awesome
//   Oscillator (AO) twin-peaks pattern. FF Trading-Systems AO cluster
//   (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
// Card: artifacts/cards_approved/QM5_1372_williams-awesome-oscillator-twin-peaks-h1.md
//   (g0 APPROVED). NOTE: card frontmatter ea_id reads QM5_12156 (stale); the
//   authoritative BUILD-TARGET ea_id is 1372 per the build task. Flagged.
//
// Awesome Oscillator (computed in-EA; no built-in handle exists for it):
//
//   median_price[s] = (high[s] + low[s]) / 2
//   AO[s]           = SMA(median_price, 5)[s] - SMA(median_price, 34)[s]
//
// AO is read on CLOSED bars only (shift >= 1 inside the entry/exit hooks, which
// run under the QM_IsNewBar gate). Each SMA is a bounded fixed-window mean over
// closed-bar median prices — a transparent closed-form computation (HR14: no ML,
// no adaptive parameters). The median-price reads are bounded single closed-bar
// iHigh/iLow reads (perf-allowed), capped by ao_slow (34).
//
// --- TWIN-PEAKS pattern (BUY = bullish twin troughs) -------------------------
//   Searching back over a bounded lookback (pattern_lookback, default 50 bars):
//     1. AO is below zero in the formation region (bullish setup zone).   STATE
//     2. Trough A = first local minimum (AO[a] < AO[a-1] && AO[a] < AO[a+1])
//        found scanning back from the most-recent confirmed trough.       STATE
//     3. Trough B = a later (more recent) local minimum, separated from A by
//        at least min_trough_gap bars, with B at shift >= 2 (confirmed).   STATE
//     4. Higher second trough: AO[B] > AO[A] (B shallower — bullish
//        divergence-style shape) and both AO[A] < 0, AO[B] < 0.            STATE
//     5. No new trough between B and now; AO rising out of B.              STATE
//     6. Signal/confirmation EVENT: AO[1] > AO[2] (second-peak confirmation
//        on the just-closed bar) AND AO was NOT yet rising one bar earlier
//        in a way already fired — i.e. the rise-confirmation just turned on.
//        This single rising-confirmation is the lone trigger EVENT.        EVENT
//   Plus macro bias: close[1] > EMA(close, macro) for BUY.                 STATE
//
//   SELL mirrors: AO above zero; two local MAXIMA (peaks) with the second peak
//   LOWER than the first (AO[B] < AO[A], both > 0); AO falling confirmation;
//   close[1] < EMA(macro).
//
//   Only the rising/falling confirmation on the just-closed bar is an EVENT.
//   The twin-trough/twin-peak geometry, the zero-line region, the higher/lower
//   relation and the macro bias are all STATES — no two-fresh-cross-same-bar
//   zero-trade trap. One-signal-per-pattern is enforced by requiring the
//   confirmation to be FRESH (rising on [1] but not already rising on [2]).
//
//   Exit (closed-bar, any of):
//     - AO color-flip / saucer-inversion: BUY closes when AO turns down
//       (AO[1] < AO[2]) after having confirmed; SELL closes when AO turns up.
//     - AO zero-cross against the position (full pattern invalidation): BUY
//       closes when AO crosses below zero; SELL when AO crosses above zero.
//     - Time-stop: close after time_stop_bars (48) H1 bars in trade (O(1)
//       position-age check, broker time).
//   Stop : entry -/+ sl_atr_mult * ATR(14) (hard ATR stop).
//   Take : entry +/- tp_atr_mult * ATR(14), expressed via QM_TakeRR off the SL.
//
//   Session     : none (H1 swing pattern trades any hour). The NoTradeFilter is
//                 a fail-OPEN spread guard only.
//   Spread guard: only a genuinely wide spread blocks (fail-OPEN on .DWX zero
//                 modeled spread, ask == bid).
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed, $0-swap-independent (pure price-derived AO geometry).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1372;
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
input int    strategy_ao_fast            = 5;     // AO fast SMA window over median price (Bill Williams 5)
input int    strategy_ao_slow            = 34;    // AO slow SMA window over median price (Bill Williams 34)
input int    strategy_pattern_lookback   = 50;    // bars back to search for trough/peak A (card cap 50)
input int    strategy_min_trough_gap     = 5;     // min bar separation between extreme A and B (card >= 5)
input int    strategy_macro_ema_period   = 200;   // macro-bias EMA gate (H1)
input int    strategy_atr_period         = 14;    // ATR period for stop/target
input double strategy_sl_atr_mult        = 1.5;   // hard stop = mult * ATR from entry
input double strategy_tp_atr_mult        = 2.0;   // take profit = mult * ATR from entry
input int    strategy_time_stop_bars     = 48;    // close after N H1 bars if no other exit (card 48)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers — Awesome Oscillator computed in-EA.
// -----------------------------------------------------------------------------

// Median-price SMA over `period` bars ending at closed-bar `shift`:
//   mean over s in [shift, shift+period-1] of (high[s]+low[s])/2.
// Bounded closed-bar reads (capped by strategy_ao_slow). Fail-closed (ok=false)
// on warmup / invalid reads.
double MedianSMA(const int period, const int shift, bool &ok)
  {
   ok = false;
   if(period < 1)
      return 0.0;
   double sum = 0.0;
   for(int s = shift; s < shift + period; ++s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar median-price read
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0)
         return 0.0;
      sum += 0.5 * (hi + lo);
     }
   ok = true;
   return sum / (double)period;
  }

// Awesome Oscillator at closed-bar `shift`: SMA(median,fast) - SMA(median,slow).
double AOAt(const int shift, bool &ok)
  {
   ok = false;
   bool f_ok=false, s_ok=false;
   const double fast = MedianSMA(strategy_ao_fast, shift, f_ok);
   const double slow = MedianSMA(strategy_ao_slow, shift, s_ok);
   if(!(f_ok && s_ok))
      return 0.0;
   ok = true;
   return fast - slow;
  }

// True if AO at `shift` is a confirmed local trough (lower than both neighbours)
// and below zero. Neighbours at shift-1 (newer) and shift+1 (older).
bool IsTroughBelowZero(const int shift, bool &ok)
  {
   ok = false;
   bool a_ok=false, n_ok=false, o_ok=false;
   const double a = AOAt(shift,     a_ok);
   const double n = AOAt(shift - 1, n_ok);
   const double o = AOAt(shift + 1, o_ok);
   if(!(a_ok && n_ok && o_ok))
      return false;
   ok = true;
   return (a < 0.0 && a < n && a < o);
  }

// True if AO at `shift` is a confirmed local peak (higher than both neighbours)
// and above zero.
bool IsPeakAboveZero(const int shift, bool &ok)
  {
   ok = false;
   bool a_ok=false, n_ok=false, o_ok=false;
   const double a = AOAt(shift,     a_ok);
   const double n = AOAt(shift - 1, n_ok);
   const double o = AOAt(shift + 1, o_ok);
   if(!(a_ok && n_ok && o_ok))
      return false;
   ok = true;
   return (a > 0.0 && a > n && a > o);
  }

// Scan back from `from_shift` (inclusive) up to pattern_lookback bars and return
// the shift of the first confirmed trough-below-zero found, or -1 if none.
int FindTroughBack(const int from_shift)
  {
   const int cap = from_shift + strategy_pattern_lookback;
   for(int s = from_shift; s <= cap; ++s)
     {
      bool t_ok=false;
      if(IsTroughBelowZero(s, t_ok) && t_ok)
         return s;
      // stop scanning if AO became unavailable (warmup boundary)
      if(!t_ok)
        {
         // distinguish "not a trough" (t_ok true) from "unavailable" — IsTrough
         // sets t_ok=false only when a read failed; in that case bail.
         bool probe=false;
         AOAt(s, probe);
         if(!probe)
            return -1;
        }
     }
   return -1;
  }

// Scan back from `from_shift` for the first confirmed peak-above-zero. -1 if none.
int FindPeakBack(const int from_shift)
  {
   const int cap = from_shift + strategy_pattern_lookback;
   for(int s = from_shift; s <= cap; ++s)
     {
      bool p_ok=false;
      if(IsPeakAboveZero(s, p_ok) && p_ok)
         return s;
      if(!p_ok)
        {
         bool probe=false;
         AOAt(s, probe);
         if(!probe)
            return -1;
        }
     }
   return -1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: fail-OPEN spread guard only (no session window — H1
// swing pattern trades any hour). Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
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

// AO twin-peaks entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // AO on the three newest closed bars (shift 1,2,3) for the confirmation EVENT.
   bool ao1_ok=false, ao2_ok=false, ao3_ok=false;
   const double ao1 = AOAt(1, ao1_ok);
   const double ao2 = AOAt(2, ao2_ok);
   const double ao3 = AOAt(3, ao3_ok);
   if(!(ao1_ok && ao2_ok && ao3_ok))
      return false; // warmup / unavailable -> no trade

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close1 <= 0.0 || macro <= 0.0)
      return false;

   // --- FRESH rising/falling confirmation on the just-closed bar [1] = EVENT ---
   // Rising just turned on: AO[1] > AO[2] (rising now) AND NOT( AO[2] > AO[3] )
   // (was not already rising one bar earlier) -> one-signal-per-pattern.
   const bool fresh_rise = (ao1 > ao2 && !(ao2 > ao3)); // EVENT (bullish confirm)
   const bool fresh_fall = (ao1 < ao2 && !(ao2 < ao3)); // EVENT (bearish confirm)

   const bool macro_long  = (close1 > macro);           // STATE
   const bool macro_short = (close1 < macro);           // STATE

   QM_OrderType dir;
   double entry = 0.0;
   bool   have_signal = false;

   // ---------------- BULLISH twin troughs (BUY) ----------------
   if(fresh_rise && macro_long)
     {
      // Trough B = most recent confirmed trough-below-zero (must be at shift>=2,
      // i.e. confirmed; the rise off it formed bar [1]). Search from shift 2.
      const int tB = FindTroughBack(2);
      if(tB >= 2)
        {
         // Trough A = an EARLIER (older) confirmed trough, separated from B by
         // at least min_trough_gap bars. Search from tB + gap.
         const int tA = FindTroughBack(tB + strategy_min_trough_gap);
         if(tA > tB)
           {
            bool aoA_ok=false, aoB_ok=false;
            const double aoA = AOAt(tA, aoA_ok);
            const double aoB = AOAt(tB, aoB_ok);
            if(aoA_ok && aoB_ok && aoA < 0.0 && aoB < 0.0 && aoB > aoA)
              {
               // Higher (shallower) second trough below zero -> bullish twin peaks.
               dir   = QM_BUY;
               entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
               have_signal = true;
              }
           }
        }
     }

   // ---------------- BEARISH twin peaks (SELL) ----------------
   if(!have_signal && fresh_fall && macro_short)
     {
      const int pB = FindPeakBack(2);
      if(pB >= 2)
        {
         const int pA = FindPeakBack(pB + strategy_min_trough_gap);
         if(pA > pB)
           {
            bool aoA_ok=false, aoB_ok=false;
            const double aoA = AOAt(pA, aoA_ok);
            const double aoB = AOAt(pB, aoB_ok);
            if(aoA_ok && aoB_ok && aoA > 0.0 && aoB > 0.0 && aoB < aoA)
              {
               // Lower (shallower) second peak above zero -> bearish twin peaks.
               dir   = QM_SELL;
               entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
               have_signal = true;
              }
           }
        }
     }

   if(!have_signal || entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Hard ATR stop ---
   double sl;
   if(dir == QM_BUY)
      sl = entry - strategy_sl_atr_mult * atr_value;
   else
      sl = entry + strategy_sl_atr_mult * atr_value;
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_atr_mult * ATR from entry via RR off the stop so the
   //     framework's price normalization applies. ---
   const double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   const double rr = (strategy_tp_atr_mult * atr_value) / sl_dist;
   if(rr <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ao_twin_peaks_confirm";
   return true;
  }

// Primary exits are the broker-side ATR stop and ATR target; no active
// trailing/BE management per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: AO color-flip (saucer inversion) against the position, AO
// zero-cross against the position, or the time-stop. Caller closes the magic's
// positions when this returns true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read direction + open time.
   bool have_pos = false;
   long pos_type = -1;
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

   // --- Time-stop: close after time_stop_bars H1 bars (O(1) age check) ---
   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const long max_age = (long)strategy_time_stop_bars * (long)PeriodSeconds(_Period);
      if((long)(TimeCurrent() - open_time) >= max_age)
         return true;
     }

   bool ao1_ok=false, ao2_ok=false;
   const double ao1 = AOAt(1, ao1_ok);
   const double ao2 = AOAt(2, ao2_ok);
   if(!(ao1_ok && ao2_ok))
      return false;

   // --- AO color-flip / saucer inversion against the position ---
   // BUY closes when AO turns down (red); SELL closes when AO turns up (green).
   if(pos_type == POSITION_TYPE_BUY  && ao1 < ao2)
      return true;
   if(pos_type == POSITION_TYPE_SELL && ao1 > ao2)
      return true;

   // --- AO zero-cross against the position (full pattern invalidation) ---
   // BUY closes when AO crosses below zero; SELL when it crosses above zero.
   if(pos_type == POSITION_TYPE_BUY  && ao2 >= 0.0 && ao1 < 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && ao2 <= 0.0 && ao1 > 0.0)
      return true;

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
