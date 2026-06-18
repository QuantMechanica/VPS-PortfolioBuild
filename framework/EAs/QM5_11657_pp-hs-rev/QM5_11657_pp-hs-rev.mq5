#property strict
#property version   "5.0"
#property description "QM5_11657 pp-hs-rev — PatternPy Head-and-Shoulders reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11657 pp-hs-rev
// -----------------------------------------------------------------------------
// Source: Keith Orange / keithorange, PatternPy,
//   tradingpatterns/tradingpatterns.py detect_head_shoulder.
// Card: artifacts/cards_approved/QM5_11657_pp-hs-rev.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads, swing points computed in-EA from bounded OHLC):
//
//   SWING DETECTION (fractal, window = swing_window):
//     A swing HIGH at shift s is a bar whose high is the strict maximum over
//     the [s-window .. s+window] closed-bar neighbourhood. Swing LOW is the
//     symmetric strict minimum. Computed on CLOSED bars only (s >= 1+window),
//     so the centre bar is already confirmed by `window` later closed bars —
//     no lookahead.
//
//   HEAD-AND-SHOULDERS STATE (bearish, short setup):
//     From the most recent confirmed swing highs P1(left shoulder), P2(head),
//     P3(right shoulder) with the two intervening swing lows T1, T2 (troughs):
//       - head is the highest:  P2 > P1  AND  P2 > P3
//       - shoulders roughly level: |P1 - P3| <= shoulder_tol_pct% of P2
//       - troughs roughly level (neckline): |T1 - T2| <= neckline_tol_pct% of P2
//     This is a STATE describing the formed structure.
//
//   INVERSE H&S STATE (bullish, long setup): mirror — swing LOWS for the three
//     points (head is the lowest) and the two intervening swing HIGHS as the
//     neckline pair.
//
//   TRIGGER EVENT — the single entry trigger is the NECKLINE BREAK:
//     neckline price = the trough pair's level interpolated to the trigger bar
//     (linear through T1,T2). Bearish: close[1] crosses BELOW the neckline
//     while close[2] was still AT/ABOVE it (one fresh cross, never two-on-one-
//     bar). Inverse: close[1] crosses ABOVE the neckline.
//
//   STOP : ATR(atr_period) emergency stop, sl_atr_mult * ATR (card seed 2.0).
//   TAKE : RR multiple of the stop distance (tp_rr).
//   TIME EXIT: close after max_hold_bars closed bars in the position.
//   OPPOSITE EXIT: an inverse pattern neckline break closes a short (and vice
//     versa) — handled via Strategy_ExitSignal opposite-structure detection.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11657;
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
input int    strategy_swing_window      = 3;     // fractal half-width (card window=3)
input int    strategy_scan_bars         = 120;   // closed bars scanned for the structure
input double strategy_shoulder_tol_pct  = 8.0;   // |left-right shoulder| tol, % of head price
input double strategy_neckline_tol_pct  = 6.0;   // |trough1-trough2| tol, % of head price
input int    strategy_atr_period        = 14;    // ATR period for the emergency stop
input double strategy_sl_atr_mult       = 2.0;   // stop distance = mult * ATR (card seed)
input double strategy_tp_rr             = 2.0;   // take-profit = tp_rr * stop distance
input int    strategy_max_hold_bars     = 12;    // time exit (card: 12 H4 bars)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope structure cache. Recomputed once per closed bar in
// AdvanceState_OnNewBar(); the per-tick hooks only read these cached values.
// -----------------------------------------------------------------------------
// Bearish H&S: a fresh neckline break-DOWN was confirmed on the just-closed bar.
bool   g_hs_short_ready  = false;
double g_hs_neckline     = 0.0;   // neckline price at the trigger bar (shift 1)
// Bullish inverse H&S: fresh neckline break-UP confirmed on the just-closed bar.
bool   g_ihs_long_ready  = false;
double g_ihs_neckline    = 0.0;
// Cached ATR (closed bar) used for stop/target/spread reference.
double g_atr_cached      = 0.0;
// Bars held since entry (advanced once per closed bar while in position).
int    g_bars_in_trade   = 0;
bool   g_in_position_prev = false;

// -----------------------------------------------------------------------------
// Swing detection helpers (closed-bar, bounded). perf-allowed: bespoke
// structural pivot math the framework readers cannot express. Each call is a
// bounded (2*window+1) neighbourhood read on CLOSED bars, run once per closed
// bar inside the QM_IsNewBar gate.
// -----------------------------------------------------------------------------

// TRUE if the bar at `shift` is a strict swing HIGH over its +/- window
// neighbourhood. Requires shift-window >= 1 so the whole window is closed.
bool IsSwingHigh(const int shift, const int window)
  {
   if(shift - window < 1)
      return false;
   const double h = iHigh(_Symbol, _Period, shift); // perf-allowed: structural pivot
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= window; ++k)
     {
      if(iHigh(_Symbol, _Period, shift - k) >= h)  // a later bar is higher/equal
         return false;
      if(iHigh(_Symbol, _Period, shift + k) >= h)  // an earlier bar is higher/equal
         return false;
     }
   return true;
  }

// TRUE if the bar at `shift` is a strict swing LOW over its +/- window
// neighbourhood.
bool IsSwingLow(const int shift, const int window)
  {
   if(shift - window < 1)
      return false;
   const double l = iLow(_Symbol, _Period, shift); // perf-allowed: structural pivot
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= window; ++k)
     {
      if(iLow(_Symbol, _Period, shift - k) <= l)
         return false;
      if(iLow(_Symbol, _Period, shift + k) <= l)
         return false;
     }
   return true;
  }

// Collect up to `max_pts` confirmed swing-HIGH shifts, newest first, scanning
// closed bars from shift 1+window outward to scan_bars.
int CollectSwingHighs(int &out_shifts[], double &out_prices[], const int max_pts,
                      const int window, const int scan_bars)
  {
   int n = 0;
   const int start = 1 + window;
   for(int s = start; s <= scan_bars && n < max_pts; ++s)
     {
      if(IsSwingHigh(s, window))
        {
         out_shifts[n] = s;
         out_prices[n] = iHigh(_Symbol, _Period, s); // perf-allowed: structural pivot
         ++n;
        }
     }
   return n;
  }

int CollectSwingLows(int &out_shifts[], double &out_prices[], const int max_pts,
                     const int window, const int scan_bars)
  {
   int n = 0;
   const int start = 1 + window;
   for(int s = start; s <= scan_bars && n < max_pts; ++s)
     {
      if(IsSwingLow(s, window))
        {
         out_shifts[n] = s;
         out_prices[n] = iLow(_Symbol, _Period, s); // perf-allowed: structural pivot
         ++n;
        }
     }
   return n;
  }

// Neckline price (linear through the two troughs/peaks) evaluated at trigger bar.
// shift_a/price_a is the OLDER pivot (larger shift), shift_b/price_b the NEWER.
double NecklineAt(const int trigger_shift,
                  const int shift_a, const double price_a,
                  const int shift_b, const double price_b)
  {
   const int span = shift_a - shift_b; // > 0 (older has larger shift)
   if(span == 0)
      return price_b;
   // slope per bar moving from b toward newer bars (decreasing shift).
   const double slope = (price_b - price_a) / (double)span;
   // bars from b to the trigger bar (trigger_shift < shift_b => positive steps).
   const double steps = (double)(shift_b - trigger_shift);
   return price_b + slope * steps;
  }

// -----------------------------------------------------------------------------
// Structure evaluation — runs once per closed bar. Detects whether a fresh
// neckline break completed on the just-closed bar (shift 1) for either the
// bearish H&S (short) or the bullish inverse H&S (long) structure.
// -----------------------------------------------------------------------------

// Evaluate the bearish Head-and-Shoulders structure + neckline break-down.
// Sets out_ready/out_neckline. Three swing HIGHS (P1 left shoulder, P2 head,
// P3 right shoulder, newest=P3) with two intervening swing LOWS (troughs).
void EvalHeadShoulders(bool &out_ready, double &out_neckline)
  {
   out_ready    = false;
   out_neckline = 0.0;

   const int MAXP = 16;
   int    hi_sh[16];
   double hi_pr[16];
   int    lo_sh[16];
   double lo_pr[16];
   const int nh = CollectSwingHighs(hi_sh, hi_pr, MAXP, strategy_swing_window, strategy_scan_bars);
   const int nl = CollectSwingLows(lo_sh, lo_pr, MAXP, strategy_swing_window, strategy_scan_bars);
   if(nh < 3 || nl < 2)
      return;

   // Newest three swing highs (arrays are newest-first): P3 newest, P2 mid, P1 oldest.
   const int    p3_sh = hi_sh[0]; const double p3 = hi_pr[0]; // right shoulder
   const int    p2_sh = hi_sh[1]; const double p2 = hi_pr[1]; // head
   const int    p1_sh = hi_sh[2]; const double p1 = hi_pr[2]; // left shoulder
   if(p2 <= 0.0)
      return;

   // Head must be the highest peak.
   if(!(p2 > p1 && p2 > p3))
      return;
   // Shoulders roughly level.
   if(MathAbs(p1 - p3) > (strategy_shoulder_tol_pct / 100.0) * p2)
      return;

   // Two troughs: the swing low BETWEEN P1 and P2, and the one between P2 and P3.
   // T1 sits in (p2_sh, p1_sh); T2 sits in (p3_sh, p2_sh)  [shift terms].
   int    t1_sh = -1; double t1 = 0.0;
   int    t2_sh = -1; double t2 = 0.0;
   for(int i = 0; i < nl; ++i)
     {
      const int s = lo_sh[i];
      if(t2_sh < 0 && s > p3_sh && s < p2_sh) { t2_sh = s; t2 = lo_pr[i]; } // newest trough
      if(t1_sh < 0 && s > p2_sh && s < p1_sh) { t1_sh = s; t1 = lo_pr[i]; } // older trough
     }
   if(t1_sh < 0 || t2_sh < 0)
      return;
   // Neckline (trough pair) roughly level.
   if(MathAbs(t1 - t2) > (strategy_neckline_tol_pct / 100.0) * p2)
      return;

   // Neckline at the just-closed trigger bar (shift 1) and the prior bar (shift 2).
   // Older trough = t1 (larger shift), newer = t2.
   const double nl_at_1 = NecklineAt(1, t1_sh, t1, t2_sh, t2);
   const double nl_at_2 = NecklineAt(2, t1_sh, t1, t2_sh, t2);

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: structural confirm
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: structural confirm
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   // Single fresh break-DOWN event: prior close at/above neckline, this close below.
   const bool broke_down = (close2 >= nl_at_2 && close1 < nl_at_1);
   if(!broke_down)
      return;

   out_ready    = true;
   out_neckline = nl_at_1;
  }

// Evaluate the bullish inverse Head-and-Shoulders structure + neckline break-up.
// Mirror: three swing LOWS (head is the lowest) with two intervening swing HIGHS.
void EvalInverseHeadShoulders(bool &out_ready, double &out_neckline)
  {
   out_ready    = false;
   out_neckline = 0.0;

   const int MAXP = 16;
   int    lo_sh[16];
   double lo_pr[16];
   int    hi_sh[16];
   double hi_pr[16];
   const int nl = CollectSwingLows(lo_sh, lo_pr, MAXP, strategy_swing_window, strategy_scan_bars);
   const int nh = CollectSwingHighs(hi_sh, hi_pr, MAXP, strategy_swing_window, strategy_scan_bars);
   if(nl < 3 || nh < 2)
      return;

   const int    p3_sh = lo_sh[0]; const double p3 = lo_pr[0]; // right shoulder (trough)
   const int    p2_sh = lo_sh[1]; const double p2 = lo_pr[1]; // head (lowest)
   const int    p1_sh = lo_sh[2]; const double p1 = lo_pr[2]; // left shoulder
   if(p2 <= 0.0)
      return;

   // Head must be the lowest.
   if(!(p2 < p1 && p2 < p3))
      return;
   // Shoulders roughly level (tolerance scaled by head price magnitude).
   if(MathAbs(p1 - p3) > (strategy_shoulder_tol_pct / 100.0) * p2)
      return;

   // Two neckline peaks: swing high between P1 and P2, and between P2 and P3.
   int    t1_sh = -1; double t1 = 0.0;
   int    t2_sh = -1; double t2 = 0.0;
   for(int i = 0; i < nh; ++i)
     {
      const int s = hi_sh[i];
      if(t2_sh < 0 && s > p3_sh && s < p2_sh) { t2_sh = s; t2 = hi_pr[i]; }
      if(t1_sh < 0 && s > p2_sh && s < p1_sh) { t1_sh = s; t1 = hi_pr[i]; }
     }
   if(t1_sh < 0 || t2_sh < 0)
      return;
   if(MathAbs(t1 - t2) > (strategy_neckline_tol_pct / 100.0) * p2)
      return;

   const double nl_at_1 = NecklineAt(1, t1_sh, t1, t2_sh, t2);
   const double nl_at_2 = NecklineAt(2, t1_sh, t1, t2_sh, t2);

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: structural confirm
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: structural confirm
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   // Single fresh break-UP event: prior close at/below neckline, this close above.
   const bool broke_up = (close2 <= nl_at_2 && close1 > nl_at_1);
   if(!broke_up)
      return;

   out_ready    = true;
   out_neckline = nl_at_1;
  }

// Advance all cached structure/state ONCE per closed bar (called from OnTick
// after the QM_IsNewBar gate). No second timestamp gate inside.
void AdvanceState_OnNewBar()
  {
   g_atr_cached = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   EvalHeadShoulders(g_hs_short_ready, g_hs_neckline);
   EvalInverseHeadShoulders(g_ihs_long_ready, g_ihs_neckline);

   // Track bars-in-trade for the time exit.
   const bool in_pos = (QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0);
   if(in_pos)
     {
      if(g_in_position_prev)
         g_bars_in_trade++;
      else
         g_bars_in_trade = 1; // first closed bar after entry
     }
   else
      g_bars_in_trade = 0;
   g_in_position_prev = in_pos;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — structural work is cached on
// the closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   if(g_atr_cached <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * g_atr_cached;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). Reads only
// the cached structure flags + a fresh ATR for stop sizing.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = g_atr_cached;
   if(atr_value <= 0.0)
      return false;

   // --- SHORT: bearish H&S neckline break-down (single trigger event) ---
   if(g_hs_short_ready)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "hs_neckline_break_short";
      return true;
     }

   // --- LONG: bullish inverse H&S neckline break-up (single trigger event) ---
   if(g_ihs_long_ready)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ihs_neckline_break_long";
      return true;
     }

   return false;
  }

// No active management beyond the fixed ATR stop/RR target and the time/
// opposite exits in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: time stop (max_hold_bars closed bars) OR an opposite
// structural neckline break. Long is closed by a bearish H&S break; short by
// a bullish inverse H&S break. Both read cached, closed-bar state.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Time stop.
   if(strategy_max_hold_bars > 0 && g_bars_in_trade >= strategy_max_hold_bars)
      return true;

   // Determine current position direction for this EA's magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }

   // Opposite-structure exit (closed-bar event).
   if(is_long && g_hs_short_ready)   // bearish break closes a long
      return true;
   if(is_short && g_ihs_long_ready)  // bullish break closes a short
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
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar())
      return;

   // Closed-bar work: advance cached structure state ONCE, then evaluate entry.
   AdvanceState_OnNewBar();

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
