#property strict
#property version   "5.0"
#property description "QM5_11008 the5ers-hs-neckline — Head & Shoulders neckline-break reversal (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11008 the5ers-hs-neckline
// -----------------------------------------------------------------------------
// Source: The5ers blog "Five Powerful Reversal Patterns Every Trader Must Know"
//   https://the5ers.com/five-powerful-reversal-patterns-every-trader-must-know/
// Card: artifacts/cards_approved/QM5_11008_the5ers-hs-neckline.md (g0 APPROVED).
//
// Mechanics (closed-bar H4, deterministic, bounded pivot scan):
//   Pivots      : 3-left/3-right fractal swing highs & lows on closed bars.
//   Bearish H&S : prior up-trend (close>EMA(100) for >=20 of prior 30 bars);
//                 three swing highs LS, HEAD, RS with HEAD exceeding both
//                 shoulders by >= head_atr_mult*ATR; RS within shoulder_atr_mult
//                 *ATR of LS and below HEAD; neckline connects the two swing
//                 lows between the peaks; LS->RS span in [span_min,span_max]
//                 bars; neckline slope <= slope_atr_mult*ATR per bar.
//                 ENTRY short when close[1] breaks below the projected neckline
//                 by >= break_atr_mult*ATR.
//   Bullish IH&S: mirror image (inverse), enter long on upward neckline break.
//   Stop        : short -> RS-high + sl_atr_mult*ATR ; long -> RS-low - sl_atr_mult*ATR.
//   Take profit : take_rr (default 2.0) R off the structural stop.
//   Exit        : (a) close[1] closes back across the neckline after entry;
//                 (b) time stop after time_stop_bars closed H4 bars.
//
// Determinism: pivot detection is a single bounded loop over the last
// scan_lookback closed bars; no recursion, no per-tick history scans. Pattern
// state (neckline @ entry, entry bar time) is cached when the position opens
// and cleared when flat. Only the 5 Strategy_* hooks + inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11008;
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
input int    strategy_pivot_left        = 3;      // fractal bars to the left
input int    strategy_pivot_right       = 3;      // fractal bars to the right (confirmation lag)
input int    strategy_ema_period        = 100;    // prior-trend EMA
input int    strategy_trend_lookback    = 30;     // prior-trend window (bars)
input int    strategy_trend_min_count   = 20;     // min bars on-trend within window
input int    strategy_atr_period        = 14;     // ATR period (tolerances / stop)
input double strategy_head_atr_mult     = 0.75;   // head must exceed shoulders by this * ATR
input double strategy_shoulder_atr_mult = 1.0;    // RS within this * ATR of LS
input double strategy_break_atr_mult    = 0.25;   // neckline break threshold (* ATR)
input double strategy_slope_atr_mult    = 0.20;   // max neckline |slope| per bar (* ATR)
input int    strategy_span_min          = 20;     // min LS->RS span (bars)
input int    strategy_span_max          = 120;    // max LS->RS span (bars)
input double strategy_sl_atr_mult       = 0.5;    // stop buffer beyond RS extreme (* ATR)
input double strategy_take_rr           = 2.0;    // take-profit at this R multiple
input int    strategy_time_stop_bars    = 30;     // close after this many H4 bars
input int    strategy_scan_lookback     = 160;    // bounded closed-bar scan depth

// -----------------------------------------------------------------------------
// File-scope cached pattern state for the single open position. Set when an
// entry fires; cleared when flat. Deterministic — never PnL-dependent.
// -----------------------------------------------------------------------------
double   g_entry_neckline   = 0.0;  // projected neckline price at the entry bar
int      g_entry_dir        = 0;    // +1 long (IH&S), -1 short (H&S), 0 none
datetime g_entry_bar_time   = 0;    // iTime of the bar that triggered entry

// -----------------------------------------------------------------------------
// Bounded fractal pivot scan over closed bars. Fills the swing-high and
// swing-low arrays (shift index + price) found within scan_lookback bars.
// A pivot at shift s is confirmed only when it has pivot_right closed bars to
// its right, so the smallest usable shift is pivot_right+1 (here >=1 anyway).
// perf-allowed: bounded one-pass closed-bar read, gated by QM_IsNewBar upstream.
// -----------------------------------------------------------------------------
int ScanPivots(const bool want_high,
               int &out_shift[],
               double &out_price[])
  {
   const int left  = strategy_pivot_left;
   const int right = strategy_pivot_right;
   const int max_shift = strategy_scan_lookback;
   int n = 0;
   ArrayResize(out_shift, 0);
   ArrayResize(out_price, 0);

   // Confirmed pivots live at shift >= right+1 (need 'right' newer bars) and
   // shift <= max_shift-left (need 'left' older bars).
   const int first = right + 1;
   const int last  = max_shift - left;
   for(int s = first; s <= last; ++s)
     {
      const double center = want_high ? iHigh(_Symbol, _Period, s)  // perf-allowed
                                      : iLow(_Symbol, _Period, s);
      if(center <= 0.0)
         continue;

      bool is_pivot = true;
      for(int k = 1; k <= left && is_pivot; ++k)
        {
         const double v = want_high ? iHigh(_Symbol, _Period, s + k)
                                    : iLow(_Symbol, _Period, s + k);
         if(v <= 0.0) { is_pivot = false; break; }
         if(want_high) { if(v >= center) is_pivot = false; }
         else          { if(v <= center) is_pivot = false; }
        }
      for(int k = 1; k <= right && is_pivot; ++k)
        {
         const double v = want_high ? iHigh(_Symbol, _Period, s - k)
                                    : iLow(_Symbol, _Period, s - k);
         if(v <= 0.0) { is_pivot = false; break; }
         if(want_high) { if(v >= center) is_pivot = false; }
         else          { if(v <= center) is_pivot = false; }
        }
      if(!is_pivot)
         continue;

      ArrayResize(out_shift, n + 1);
      ArrayResize(out_price, n + 1);
      out_shift[n] = s;
      out_price[n] = center;
      ++n;
     }
   return n; // ordered newest(smallest shift) -> oldest(largest shift)
  }

// Find the single most-extreme swing-low between two shifts (exclusive bounds
// older>newer in shift terms). Returns true and fills shift/price if found.
bool ExtremeBetween(const bool want_low,
                    const int newer_shift,
                    const int older_shift,
                    int &out_shift,
                    double &out_price)
  {
   bool found = false;
   double best = 0.0;
   int    best_shift = -1;
   for(int s = newer_shift + 1; s < older_shift; ++s)
     {
      const double v = want_low ? iLow(_Symbol, _Period, s)   // perf-allowed: bounded
                                : iHigh(_Symbol, _Period, s);
      if(v <= 0.0)
         continue;
      if(!found) { best = v; best_shift = s; found = true; continue; }
      if(want_low)  { if(v < best) { best = v; best_shift = s; } }
      else          { if(v > best) { best = v; best_shift = s; } }
     }
   if(found) { out_shift = best_shift; out_price = best; }
   return found;
  }

// Prior-trend filter: close above (above=true) / below the EMA for at least
// trend_min_count of the trend_lookback bars ENDING just before the head's
// left shoulder. We anchor the window at the right shoulder shift for a stable,
// deterministic reference. Returns true if the trend condition holds.
bool PriorTrend(const bool want_above, const int anchor_shift)
  {
   const int start = anchor_shift + 1;
   const int end   = anchor_shift + strategy_trend_lookback;
   int count = 0;
   int seen  = 0;
   for(int s = start; s <= end; ++s)
     {
      const double c   = iClose(_Symbol, _Period, s);  // perf-allowed: bounded window
      const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
      if(c <= 0.0 || ema <= 0.0)
         continue;
      ++seen;
      if(want_above) { if(c > ema) ++count; }
      else           { if(c < ema) ++count; }
     }
   if(seen < strategy_trend_min_count)
      return false;
   return (count >= strategy_trend_min_count);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap per-tick gate. No spread cap configured for this structural pattern;
// fail-open on .DWX zero modeled spread. Only invalid quotes are skipped, and
// even then we do not block (defer to the entry gate).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Try to assemble a Head & Shoulders (short) or inverse H&S (long) on the last
// closed bar and, if the neckline broke by the threshold, fill `req`.
// Caller guarantees QM_IsNewBar() == true.
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

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed bar
   if(close1 <= 0.0)
      return false;

   // ---- Try BEARISH H&S (three swing highs) -> SHORT ----
   {
      int    hi_shift[]; double hi_price[];
      const int nh = ScanPivots(true, hi_shift, hi_price);
      // Need at least 3 swing highs: RS (newest) .. HEAD .. LS (oldest).
      // Iterate over consecutive triplets newest->oldest.
      for(int i = 0; i + 2 < nh; ++i)
        {
         const int    rs_s = hi_shift[i];     const double rs_h = hi_price[i];
         const int    hd_s = hi_shift[i + 1]; const double hd_h = hi_price[i + 1];
         const int    ls_s = hi_shift[i + 2]; const double ls_h = hi_price[i + 2];

         // Geometry: head is the middle peak and the highest.
         if(!(hd_h > rs_h + strategy_head_atr_mult * atr))     continue;
         if(!(hd_h > ls_h + strategy_head_atr_mult * atr))     continue;
         // Right shoulder within tolerance of left shoulder, and below head.
         if(MathAbs(rs_h - ls_h) > strategy_shoulder_atr_mult * atr) continue;
         if(!(rs_h < hd_h))                                    continue;
         // Span LS->RS within bounds.
         const int span = ls_s - rs_s;
         if(span < strategy_span_min || span > strategy_span_max) continue;

         // Neckline = the two swing lows between (LS,HEAD) and (HEAD,RS).
         int    lo1_s; double lo1_p; // between RS and HEAD (newer)
         int    lo2_s; double lo2_p; // between HEAD and LS (older)
         if(!ExtremeBetween(true, rs_s, hd_s, lo1_s, lo1_p)) continue;
         if(!ExtremeBetween(true, hd_s, ls_s, lo2_s, lo2_p)) continue;

         // Neckline slope per bar (price change / bar distance).
         const int neck_span = lo2_s - lo1_s;
         if(neck_span <= 0) continue;
         const double slope = (lo1_p - lo2_p) / (double)neck_span; // per bar, newer-older
         if(MathAbs(slope) > strategy_slope_atr_mult * atr) continue;

         // Project the neckline to the just-closed bar (shift 1).
         const double neck_at_1 = lo1_p + slope * (double)(lo1_s - 1);

         // Prior up-trend before the pattern (anchored at left shoulder).
         if(!PriorTrend(true, ls_s)) continue;

         // Break trigger: close[1] below neckline by the threshold.
         if(!(close1 < neck_at_1 - strategy_break_atr_mult * atr)) continue;

         // Structural stop above RS high + buffer; TP at take_rr R.
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0) continue;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, rs_h + strategy_sl_atr_mult * atr);
         if(sl <= entry) continue; // stop must sit above a short entry
         const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_take_rr);
         if(tp <= 0.0) continue;

         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "hs_neckline_short";
         g_entry_neckline = neck_at_1;
         g_entry_dir      = -1;
         g_entry_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: entry-bar stamp
         return true;
        }
   }

   // ---- Try BULLISH inverse H&S (three swing lows) -> LONG ----
   {
      int    lo_shift[]; double lo_price[];
      const int nl = ScanPivots(false, lo_shift, lo_price);
      for(int i = 0; i + 2 < nl; ++i)
        {
         const int    rs_s = lo_shift[i];     const double rs_l = lo_price[i];
         const int    hd_s = lo_shift[i + 1]; const double hd_l = lo_price[i + 1];
         const int    ls_s = lo_shift[i + 2]; const double ls_l = lo_price[i + 2];

         // Head is the lowest middle trough.
         if(!(hd_l < rs_l - strategy_head_atr_mult * atr))     continue;
         if(!(hd_l < ls_l - strategy_head_atr_mult * atr))     continue;
         if(MathAbs(rs_l - ls_l) > strategy_shoulder_atr_mult * atr) continue;
         if(!(rs_l > hd_l))                                    continue;
         const int span = ls_s - rs_s;
         if(span < strategy_span_min || span > strategy_span_max) continue;

         // Neckline = the two swing highs between the troughs.
         int    hi1_s; double hi1_p;
         int    hi2_s; double hi2_p;
         if(!ExtremeBetween(false, rs_s, hd_s, hi1_s, hi1_p)) continue;
         if(!ExtremeBetween(false, hd_s, ls_s, hi2_s, hi2_p)) continue;

         const int neck_span = hi2_s - hi1_s;
         if(neck_span <= 0) continue;
         const double slope = (hi1_p - hi2_p) / (double)neck_span;
         if(MathAbs(slope) > strategy_slope_atr_mult * atr) continue;

         const double neck_at_1 = hi1_p + slope * (double)(hi1_s - 1);

         if(!PriorTrend(false, ls_s)) continue;

         if(!(close1 > neck_at_1 + strategy_break_atr_mult * atr)) continue;

         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0) continue;
         const double sl = QM_StopRulesNormalizePrice(_Symbol, rs_l - strategy_sl_atr_mult * atr);
         if(sl >= entry || sl <= 0.0) continue; // stop must sit below a long entry
         const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_take_rr);
         if(tp <= 0.0) continue;

         req.type   = QM_BUY;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "ihs_neckline_long";
         g_entry_neckline = neck_at_1;
         g_entry_dir      = +1;
         g_entry_bar_time = iTime(_Symbol, _Period, 1);
         return true;
        }
   }

   return false;
  }

// No active SL/TP trailing — fixed structural stop + RR target. Clear cached
// pattern state once we are flat so a stale neckline can't drive an exit.
void Strategy_ManageOpenPosition()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
     {
      g_entry_neckline = 0.0;
      g_entry_dir      = 0;
      g_entry_bar_time = 0;
     }
  }

// Discretionary exits, evaluated once per closed bar (cheap O(1) reads):
//   (a) signal exit: close[1] closes back across the neckline after entry;
//   (b) time stop: time_stop_bars closed H4 bars elapsed since the entry bar.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   if(g_entry_dir == 0 || g_entry_neckline <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed bar
   if(close1 <= 0.0)
      return false;

   // (a) Neckline re-cross against the trade direction.
   if(g_entry_dir < 0 && close1 > g_entry_neckline) return true; // short: back above
   if(g_entry_dir > 0 && close1 < g_entry_neckline) return true; // long: back below

   // (b) Time stop. Count closed bars from the entry bar to the last closed bar.
   if(g_entry_bar_time > 0)
     {
      const datetime t1 = iTime(_Symbol, _Period, 1); // perf-allowed: bar stamp
      const int idx = iBarShift(_Symbol, _Period, g_entry_bar_time, false);
      if(idx >= 0 && (idx - 1) >= strategy_time_stop_bars)
         return true;
      // Fallback guard if the entry bar rolled out of history.
      if(idx < 0 && t1 > 0)
         return false;
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
