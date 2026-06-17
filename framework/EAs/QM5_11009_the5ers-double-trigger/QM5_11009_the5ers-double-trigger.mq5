#property strict
#property version   "5.0"
#property description "QM5_11009 the5ers-double-trigger — Double Top/Bottom Trigger-Line reversal (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11009 the5ers-double-trigger
// -----------------------------------------------------------------------------
// Source: The5ers "Five Powerful Reversal Patterns Every Trader Must Know"
//         (double top / double bottom + trigger-line break).
// Card: artifacts/cards_approved/QM5_11009_the5ers-double-trigger.md (APPROVED).
//
// Mechanics (closed-bar reads; H1):
//   The double top/bottom is a STATE formed over a 5..60 bar window: two
//   confirmed 3L/3R swing extremes of similar height (within tol*ATR), with an
//   intervening counter-swing (the TRIGGER LINE) at least sep*ATR away. The
//   trigger-line BREAK on close[1] is the single EVENT per bar — so we never
//   require two cross events on one bar (.DWX invariant #4): the pattern is a
//   latched state, the break is the trigger.
//
//   Double TOP  (short): prior uptrend (close>EMA & EMA slope up). Two swing
//     highs within tol*ATR, 5..60 bars apart; intervening swing LOW (trigger
//     line) >= sep*ATR below both highs. Short when close[1] breaks below the
//     trigger line by brk*ATR, with a body >= body_frac of the candle range.
//   Double BOTTOM (long): mirror — prior downtrend, two swing lows, intervening
//     swing HIGH trigger line, long when close[1] breaks above by brk*ATR.
//
//   Reject if the 2nd extreme exceeds the 1st by more than tol*ATR (failed M/W).
//   Stop : short = higher top + slbuf*ATR; long = lower bottom - slbuf*ATR.
//   Take : RR multiple of the initial stop distance (tp_rr).
//   Exit : (a) price closes back inside the pattern beyond the trigger line
//          (close[1] crosses to the wrong side of the trigger line);
//          (b) time stop after max_hold_bars H1 bars.
//
// Swing / structure detection is bespoke — raw iHigh/iLow/iClose reads are
// perf-allowed and run ONCE per closed bar inside DetectPattern_OnNewBar();
// the per-tick path only reads cached file-scope state + Bid/Ask.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11009;
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
input int    strategy_fractal_side       = 3;     // 3-left / 3-right fractal swing rule
input int    strategy_ema_period         = 100;   // trend-filter EMA period
input int    strategy_ema_slope_bars     = 30;    // bars over which EMA slope is measured
input int    strategy_atr_period         = 14;    // ATR period (tolerances / stop)
input int    strategy_pair_min_bars      = 5;     // min bars between the two extremes
input int    strategy_pair_max_bars      = 60;    // max bars between the two extremes
input double strategy_top_tol_atr        = 0.50;  // two extremes within this * ATR
input double strategy_trigger_sep_atr    = 1.00;  // trigger line >= this * ATR from extremes
input double strategy_break_atr          = 0.20;  // break depth beyond trigger line, * ATR
input double strategy_sl_buffer_atr      = 0.35;  // stop buffer beyond the extreme, * ATR
input double strategy_tp_rr              = 1.80;  // take profit as R multiple
input double strategy_break_body_frac    = 0.40;  // break candle body >= this fraction of range
input int    strategy_max_hold_bars      = 48;    // time stop, H1 bars
input int    strategy_scan_bars          = 80;    // bars scanned for swings (>= max_bars + 2*side)

// -----------------------------------------------------------------------------
// File-scope cached pattern state (advanced ONCE per closed bar)
// -----------------------------------------------------------------------------
// Latched candidate pattern; -1 = none. Set by DetectPattern_OnNewBar().
int      g_signal_dir        = 0;     // +1 long (double bottom), -1 short (double top), 0 none
double   g_trigger_line      = 0.0;   // intervening swing extreme = trigger line price
double   g_pattern_extreme   = 0.0;   // higher of two tops (short) / lower of two bottoms (long)
double   g_atr_cached        = 0.0;   // ATR value at detection
datetime g_signal_bar_time   = 0;     // bar-open time of the bar that produced the signal

// -----------------------------------------------------------------------------
// Swing detection — confirmed 3L/3R fractal on closed bars (perf-allowed raw OHLC)
// -----------------------------------------------------------------------------
// Returns the price of the most recent confirmed swing HIGH whose CENTER shift
// lies in [from_shift, to_shift]; out_center receives its center shift.
// A confirmed swing high at center c needs `side` higher bars on each side, so
// the smallest confirmable center is shift `side` (right side already closed).
bool FindSwingHigh(const int side, const int from_shift, const int to_shift,
                   double &out_price, int &out_center)
  {
   for(int c = from_shift; c <= to_shift; ++c)
     {
      const double hc = iHigh(_Symbol, _Period, c); // perf-allowed: structural swing scan
      if(hc <= 0.0)
         continue;
      bool is_high = true;
      for(int k = 1; k <= side; ++k)
        {
         const double hl = iHigh(_Symbol, _Period, c - k); // perf-allowed: right (newer) side
         const double hr = iHigh(_Symbol, _Period, c + k); // perf-allowed: left (older) side
         if(hl <= 0.0 || hr <= 0.0) { is_high = false; break; }
         if(hl >= hc || hr >= hc)   { is_high = false; break; }
        }
      if(is_high)
        {
         out_price  = hc;
         out_center = c;
         return true;
        }
     }
   return false;
  }

// Mirror: most recent confirmed swing LOW with center in [from_shift, to_shift].
bool FindSwingLow(const int side, const int from_shift, const int to_shift,
                  double &out_price, int &out_center)
  {
   for(int c = from_shift; c <= to_shift; ++c)
     {
      const double lc = iLow(_Symbol, _Period, c); // perf-allowed: structural swing scan
      if(lc <= 0.0)
         continue;
      bool is_low = true;
      for(int k = 1; k <= side; ++k)
        {
         const double ll = iLow(_Symbol, _Period, c - k); // perf-allowed: right (newer) side
         const double lr = iLow(_Symbol, _Period, c + k); // perf-allowed: left (older) side
         if(ll <= 0.0 || lr <= 0.0) { is_low = false; break; }
         if(ll <= lc || lr <= lc)   { is_low = false; break; }
        }
      if(is_low)
        {
         out_price  = lc;
         out_center = c;
         return true;
        }
     }
   return false;
  }

// Find a SECOND swing high OLDER than first_center (paired, within bar window).
bool FindPriorSwingHigh(const int side, const int first_center, const int max_back,
                        const int to_shift, double &out_price, int &out_center)
  {
   const int from_shift = first_center + strategy_pair_min_bars;
   const int last_shift = MathMin(to_shift, first_center + max_back);
   if(from_shift > last_shift)
      return false;
   return FindSwingHigh(side, from_shift, last_shift, out_price, out_center);
  }

bool FindPriorSwingLow(const int side, const int first_center, const int max_back,
                       const int to_shift, double &out_price, int &out_center)
  {
   const int from_shift = first_center + strategy_pair_min_bars;
   const int last_shift = MathMin(to_shift, first_center + max_back);
   if(from_shift > last_shift)
      return false;
   return FindSwingLow(side, from_shift, last_shift, out_price, out_center);
  }

// Lowest LOW between two shifts (the trigger line for a double top).
double LowestLowBetween(const int newer_shift, const int older_shift)
  {
   double lo = 0.0;
   for(int s = newer_shift; s <= older_shift; ++s)
     {
      const double l = iLow(_Symbol, _Period, s); // perf-allowed
      if(l <= 0.0) continue;
      if(lo <= 0.0 || l < lo) lo = l;
     }
   return lo;
  }

// Highest HIGH between two shifts (the trigger line for a double bottom).
double HighestHighBetween(const int newer_shift, const int older_shift)
  {
   double hi = 0.0;
   for(int s = newer_shift; s <= older_shift; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s); // perf-allowed
      if(h <= 0.0) continue;
      if(h > hi) hi = h;
     }
   return hi;
  }

// -----------------------------------------------------------------------------
// Pattern detection — runs ONCE per closed bar. Latches g_signal_* or clears.
// -----------------------------------------------------------------------------
void DetectPattern_OnNewBar()
  {
   g_signal_dir      = 0;
   g_trigger_line    = 0.0;
   g_pattern_extreme = 0.0;
   g_atr_cached      = 0.0;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: trigger-bar close
   const double open1  = iOpen(_Symbol, _Period, 1); // perf-allowed: trigger-bar open
   const double high1  = iHigh(_Symbol, _Period, 1); // perf-allowed: trigger-bar high
   const double low1   = iLow(_Symbol, _Period, 1);  // perf-allowed: trigger-bar low
   if(close1 <= 0.0 || open1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return;

   // Break-candle body filter (shared by both directions).
   const double range1 = high1 - low1;
   const double body1  = MathAbs(close1 - open1);
   const bool body_ok  = (range1 > 0.0 && (body1 / range1) >= strategy_break_body_frac);
   if(!body_ok)
      return;

   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_period, 1 + strategy_ema_slope_bars);
   if(ema_now <= 0.0 || ema_prev <= 0.0)
      return;

   const int side       = strategy_fractal_side;
   const int max_back    = strategy_pair_max_bars;
   const int scan_to     = strategy_scan_bars;
   const double tol      = strategy_top_tol_atr      * atr;
   const double sep      = strategy_trigger_sep_atr  * atr;
   const double brk      = strategy_break_atr        * atr;

   // ============================ DOUBLE TOP (short) =========================
   // Prior uptrend: close above EMA and EMA sloping up over slope window.
   if(close1 > ema_now && ema_now > ema_prev)
     {
      double h1_price = 0.0; int h1_center = 0;
      // Most-recent confirmed swing high (earliest confirmable center = side).
      if(FindSwingHigh(side, side, scan_to, h1_price, h1_center))
        {
         double h2_price = 0.0; int h2_center = 0;
         if(FindPriorSwingHigh(side, h1_center, max_back, scan_to, h2_price, h2_center))
           {
            // Two tops within tolerance.
            if(MathAbs(h1_price - h2_price) <= tol)
              {
               // Reject failed M: 2nd (older) top must not exceed 1st by > tol.
               // (newer top h1 vs older top h2 — neither breaks the other badly)
               const double higher_top = MathMax(h1_price, h2_price);
               // Intervening swing low between the two tops = trigger line.
               const double trig = LowestLowBetween(h1_center + 1, h2_center - 1);
               if(trig > 0.0)
                 {
                  // Trigger line at least sep below BOTH tops.
                  if((h1_price - trig) >= sep && (h2_price - trig) >= sep)
                    {
                     // Break EVENT: close[1] breaks below trigger by brk.
                     if(close1 <= (trig - brk))
                       {
                        g_signal_dir      = -1;
                        g_trigger_line    = trig;
                        g_pattern_extreme = higher_top;
                        g_atr_cached      = atr;
                        g_signal_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: current forming bar
                        return;
                       }
                    }
                 }
              }
           }
        }
     }

   // ========================== DOUBLE BOTTOM (long) =========================
   // Prior downtrend: close below EMA and EMA sloping down over slope window.
   if(close1 < ema_now && ema_now < ema_prev)
     {
      double l1_price = 0.0; int l1_center = 0;
      if(FindSwingLow(side, side, scan_to, l1_price, l1_center))
        {
         double l2_price = 0.0; int l2_center = 0;
         if(FindPriorSwingLow(side, l1_center, max_back, scan_to, l2_price, l2_center))
           {
            if(MathAbs(l1_price - l2_price) <= tol)
              {
               const double lower_bottom = MathMin(l1_price, l2_price);
               const double trig = HighestHighBetween(l1_center + 1, l2_center - 1);
               if(trig > 0.0)
                 {
                  if((trig - l1_price) >= sep && (trig - l2_price) >= sep)
                    {
                     if(close1 >= (trig + brk))
                       {
                        g_signal_dir      = +1;
                        g_trigger_line    = trig;
                        g_pattern_extreme = lower_bottom;
                        g_atr_cached      = atr;
                        g_signal_bar_time = iTime(_Symbol, _Period, 0); // perf-allowed: current forming bar
                        return;
                       }
                    }
                 }
              }
           }
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. No spread guard needed beyond fail-open default —
// .DWX models zero spread; never block on it. Returns false (do not block).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). Reads the
// pattern state latched by DetectPattern_OnNewBar() this same bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_signal_dir == 0 || g_atr_cached <= 0.0 || g_trigger_line <= 0.0 || g_pattern_extreme <= 0.0)
      return false;

   const double sl_pad = strategy_sl_buffer_atr * g_atr_cached;

   if(g_signal_dir < 0)
     {
      // SHORT: stop above the higher top by sl_buffer*ATR.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_pattern_extreme + sl_pad);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "double_top_trigger_short";
      return true;
     }
   else
     {
      // LONG: stop below the lower bottom by sl_buffer*ATR.
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_pattern_extreme - sl_pad);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "double_bottom_trigger_long";
      return true;
     }
  }

// Fixed structural stop + RR target; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (separate from SL/TP):
//   (a) signal exit — price closes back inside the pattern beyond the trigger
//       line (closed-bar reversal of the break);
//   (b) time stop — position held >= max_hold_bars H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Select this EA's open position to read direction + open time.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long pos_type = PositionGetInteger(POSITION_TYPE);

      // (b) Time stop — bars held since entry.
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_held = iBarShift(_Symbol, _Period, open_time, false);
      if(bars_held >= strategy_max_hold_bars)
         return true;

      // (a) Signal exit — close[1] back on the wrong side of the trigger line.
      // For a short, the break was DOWN through the trigger; a close back above
      // it = pattern invalidated. Mirror for long. Use the stored trigger line.
      if(g_trigger_line > 0.0)
        {
         const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed bar
         if(close1 > 0.0)
           {
            if(pos_type == POSITION_TYPE_SELL && close1 > g_trigger_line)
               return true;
            if(pos_type == POSITION_TYPE_BUY  && close1 < g_trigger_line)
               return true;
           }
        }
      break; // single position per magic
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

   // Advance cached pattern state ONCE per closed bar before the entry gate.
   DetectPattern_OnNewBar();

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
