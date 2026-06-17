#property strict
#property version   "5.0"
#property description "QM5_11010 the5ers-quasimodo-retest — Quasimodo swing-structure reversal retest (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11010 the5ers-quasimodo-retest
// -----------------------------------------------------------------------------
// Source: The5ers blog "Five Powerful Reversal Patterns Every Trader Must Know"
//         (Quasimodo / over-and-under section).
// Card: artifacts/cards_approved/QM5_11010_the5ers-quasimodo-retest.md (g0 APPROVED).
//
// Mechanics (H1, closed-bar only, non-repainting 3L/3R fractal swings):
//
//   Swing detection: a confirmed swing HIGH at shift k requires the 3 bars to its
//   left (k+1..k+3) AND the 3 bars to its right (k-1..k-3) to have strictly lower
//   highs. Symmetric for a swing LOW. The most recent confirmable fractal sits at
//   shift >= 4 (its 3 right-bars must be closed). This makes swings deterministic
//   and non-repainting.
//
//   BEARISH Quasimodo (after an uptrend):
//     ordered recent swings form  HH1 -> HL1 -> HH2  with HH2 > HH1, HL1 the higher
//     low between them, followed by a momentum break: the latest confirmed swing LOW
//     LL1 < HL1 - break_mult*ATR. Entry level = HH2 (last peak before the lower low).
//     SHORT triggers when a later closed bar finishes BELOW HH2 and within
//     retest_mult*ATR of HH2 (retest of the broken peak), within retest_window bars
//     of the break.
//
//   BULLISH Quasimodo (after a downtrend): mirror image. LL1 -> LH1 -> LL2 with
//     LL2 < LL1, then break: latest swing HIGH HH1 > LH1 + break_mult*ATR. Entry
//     level = LL2. LONG triggers when a later closed bar finishes ABOVE LL2 and
//     within retest_mult*ATR of LL2.
//
//   Stop  : short -> entry + retest_mult*ATR above the retest level (HH2);
//           long  -> entry - retest_mult*ATR below the retest level (LL2).
//   Take  : tp_rr R-multiple of the initial stop distance.
//   Signal exit: close if price closes beyond the retested level by exit_mult*ATR
//                AGAINST the trade.
//   Time stop: close after time_stop_bars H1 bars.
//
// Determinism / bounds: the setup scan runs ONCE per closed bar over a bounded
// scan_window, caches the active setup (level/dir/break-bar/expiry) in file-scope
// state, and the per-tick entry check only compares the current closed bar to the
// cached level. No per-tick history scans.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11010;
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
input int    strategy_fractal_left      = 3;      // left bars for a confirmed fractal
input int    strategy_fractal_right     = 3;      // right bars for a confirmed fractal
input int    strategy_scan_window       = 120;    // bars scanned for the swing sequence
input int    strategy_atr_period        = 14;     // ATR period (tolerances / stop)
input double strategy_break_atr_mult    = 0.50;   // momentum-break threshold * ATR
input double strategy_retest_atr_mult   = 0.35;   // retest tolerance & stop buffer * ATR
input double strategy_exit_atr_mult     = 0.50;   // adverse-close exit beyond level * ATR
input double strategy_tp_rr             = 2.0;    // take-profit R-multiple
input int    strategy_retest_window     = 80;     // max bars after break to allow retest
input int    strategy_time_stop_bars    = 60;     // close after this many H1 bars
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached setup state — advanced ONCE per closed bar.
//   g_setup_dir : +1 bullish (long, level=LL2), -1 bearish (short, level=HH2), 0 none
//   g_setup_level : the retest price level (HH2 or LL2)
//   g_setup_break_time : bar-open time of the momentum-break swing bar
//   g_setup_atr : ATR snapshot at detection (for tolerances & stop)
// -----------------------------------------------------------------------------
int      g_setup_dir        = 0;
double   g_setup_level      = 0.0;
datetime g_setup_break_time = 0;
double   g_setup_atr        = 0.0;

// -----------------------------------------------------------------------------
// Swing helpers (closed-bar, bounded). perf-allowed: bespoke structural logic,
// gated by QM_IsNewBar via AdvanceSetup_OnNewBar (runs once per closed bar).
// -----------------------------------------------------------------------------

// Confirmed swing HIGH at shift k: highs at k strictly greater than the L left and
// R right neighbours. Requires k-R >= 1 (all right bars closed) — caller ensures it.
bool IsSwingHigh(const int k, const int L, const int R)
  {
   const double h = iHigh(_Symbol, _Period, k); // perf-allowed
   if(h <= 0.0)
      return false;
   for(int j = 1; j <= L; ++j)
     {
      const double hl = iHigh(_Symbol, _Period, k + j); // perf-allowed
      if(hl <= 0.0 || hl >= h)
         return false;
     }
   for(int j = 1; j <= R; ++j)
     {
      const double hr = iHigh(_Symbol, _Period, k - j); // perf-allowed
      if(hr <= 0.0 || hr >= h)
         return false;
     }
   return true;
  }

// Confirmed swing LOW at shift k.
bool IsSwingLow(const int k, const int L, const int R)
  {
   const double lo = iLow(_Symbol, _Period, k); // perf-allowed
   if(lo <= 0.0)
      return false;
   for(int j = 1; j <= L; ++j)
     {
      const double ll = iLow(_Symbol, _Period, k + j); // perf-allowed
      if(ll <= 0.0 || ll <= lo)
         return false;
     }
   for(int j = 1; j <= R; ++j)
     {
      const double lr = iLow(_Symbol, _Period, k - j); // perf-allowed
      if(lr <= 0.0 || lr <= lo)
         return false;
     }
   return true;
  }

// Scan the window once per closed bar and (re)detect the active Quasimodo setup.
// Newest-first: the latest confirmed fractal is the momentum-break swing; we then
// look backward for the qualifying HH/HL/HH (bearish) or LL/LH/LL (bullish) legs.
void AdvanceSetup_OnNewBar()
  {
   const int L = strategy_fractal_left;
   const int R = strategy_fractal_right;
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return;

   // Bound the scan; first confirmable fractal is at shift R+1 (>=4 by default).
   const int first_k = R + 1;
   const int last_k  = strategy_scan_window;

   // --- BEARISH: latest confirmed swing LOW is the momentum break (LL1) ---
   // Look back for: HH2 (>HH1) most-recent high above the low, HL1 higher-low
   // between HH1 and HH2, HH1 earlier high. LL1 < HL1 - break_mult*ATR.
   {
      int    ll_k = -1; double ll_price = 0.0;
      for(int k = first_k; k <= last_k; ++k)
         if(IsSwingLow(k, L, R)) { ll_k = k; ll_price = iLow(_Symbol, _Period, k); break; } // perf-allowed

      if(ll_k > 0)
        {
         // Collect the two most-recent swing highs strictly older than the break low,
         // plus the higher-low between them.
         int    hh2_k = -1; double hh2_p = 0.0;
         int    hh1_k = -1; double hh1_p = 0.0;
         for(int k = ll_k + 1; k <= last_k; ++k)
            if(IsSwingHigh(k, L, R))
              {
               if(hh2_k < 0) { hh2_k = k; hh2_p = iHigh(_Symbol, _Period, k); } // perf-allowed
               else          { hh1_k = k; hh1_p = iHigh(_Symbol, _Period, k); break; } // perf-allowed
              }
         // Higher-low between HH1 and HH2 (uptrend leg).
         int    hl1_k = -1; double hl1_p = 0.0;
         if(hh2_k > 0 && hh1_k > 0)
            for(int k = hh2_k + 1; k < hh1_k; ++k)
               if(IsSwingLow(k, L, R)) { hl1_k = k; hl1_p = iLow(_Symbol, _Period, k); break; } // perf-allowed

         const bool legs_ok = (hh2_k > 0 && hh1_k > 0 && hl1_k > 0 &&
                               hh2_p > hh1_p &&            // higher high
                               hl1_p > 0.0 &&
                               ll_price < hl1_p - strategy_break_atr_mult * atr); // momentum break below HL1
         if(legs_ok)
           {
            g_setup_dir        = -1;
            g_setup_level      = hh2_p;                         // entry/retest level
            g_setup_break_time = iTime(_Symbol, _Period, ll_k); // perf-allowed: break-bar time
            g_setup_atr        = atr;
            return;
           }
        }
   }

   // --- BULLISH: latest confirmed swing HIGH is the momentum break (HH1) ---
   {
      int    hh_k = -1; double hh_price = 0.0;
      for(int k = first_k; k <= last_k; ++k)
         if(IsSwingHigh(k, L, R)) { hh_k = k; hh_price = iHigh(_Symbol, _Period, k); break; } // perf-allowed

      if(hh_k > 0)
        {
         int    ll2_k = -1; double ll2_p = 0.0;
         int    ll1_k = -1; double ll1_p = 0.0;
         for(int k = hh_k + 1; k <= last_k; ++k)
            if(IsSwingLow(k, L, R))
              {
               if(ll2_k < 0) { ll2_k = k; ll2_p = iLow(_Symbol, _Period, k); } // perf-allowed
               else          { ll1_k = k; ll1_p = iLow(_Symbol, _Period, k); break; } // perf-allowed
              }
         int    lh1_k = -1; double lh1_p = 0.0;
         if(ll2_k > 0 && ll1_k > 0)
            for(int k = ll2_k + 1; k < ll1_k; ++k)
               if(IsSwingHigh(k, L, R)) { lh1_k = k; lh1_p = iHigh(_Symbol, _Period, k); break; } // perf-allowed

         const bool legs_ok = (ll2_k > 0 && ll1_k > 0 && lh1_k > 0 &&
                               ll2_p < ll1_p &&            // lower low
                               lh1_p > 0.0 &&
                               hh_price > lh1_p + strategy_break_atr_mult * atr); // momentum break above LH1
         if(legs_ok)
           {
            g_setup_dir        = +1;
            g_setup_level      = ll2_p;
            g_setup_break_time = iTime(_Symbol, _Period, hh_k); // perf-allowed
            g_setup_atr        = atr;
            return;
           }
        }
   }

   // No qualifying setup this bar — leave any existing cached setup intact until it
   // is consumed by an entry or expires by the retest window in Strategy_EntrySignal.
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
      return false; // no valid quote yet — do not block

   if(g_setup_atr <= 0.0)
      return false; // no setup baseline yet — defer to entry gate

   const double stop_distance = strategy_retest_atr_mult * g_setup_atr;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the closed-bar path. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic; no pyramiding.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(g_setup_dir == 0 || g_setup_level <= 0.0 || g_setup_atr <= 0.0)
      return false;

   // Retest must occur within retest_window bars after the break; else expire.
   const datetime break_t = g_setup_break_time;
   if(break_t > 0)
     {
      const int bars_since = iBarShift(_Symbol, _Period, break_t, false); // perf-allowed
      if(bars_since < 0 || bars_since > strategy_retest_window)
        {
         g_setup_dir = 0;     // expired
         return false;
        }
     }

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: last closed bar
   if(close1 <= 0.0)
      return false;

   const double tol = strategy_retest_atr_mult * g_setup_atr;
   const double entry = (g_setup_dir > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                          : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   if(g_setup_dir < 0)
     {
      // SHORT: closed bar finishes BELOW HH2 and within tol of HH2 (retest of peak).
      if(!(close1 < g_setup_level))
         return false;
      if((g_setup_level - close1) > tol)
         return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_setup_level + tol);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "quasimodo_short_retest";
      g_setup_dir = 0;    // consume the setup
      return true;
     }
   else
     {
      // LONG: closed bar finishes ABOVE LL2 and within tol of LL2.
      if(!(close1 > g_setup_level))
         return false;
      if((close1 - g_setup_level) > tol)
         return false;

      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_setup_level - tol);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "quasimodo_long_retest";
      g_setup_dir = 0;
      return true;
     }
  }

// Active management: time-stop only. Closes the position after time_stop_bars H1
// bars from entry. Adverse-close signal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const datetime open_t = (datetime)PositionGetInteger(POSITION_TIME);
      if(open_t <= 0)
         continue;
      const int bars_held = iBarShift(_Symbol, _Period, open_t, false); // perf-allowed
      if(bars_held >= strategy_time_stop_bars)
         QM_TM_ClosePosition(ticket, QM_EXIT_TIME_STOP);
     }
  }

// Signal exit: close if the last closed bar finishes beyond the retested level by
// exit_mult*ATR AGAINST the open position. Returns TRUE to close all magic positions.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(g_setup_atr <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: last closed bar
   if(close1 <= 0.0)
      return false;

   const double buf = strategy_exit_atr_mult * g_setup_atr;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      // Adverse close beyond the entry reference by buf.
      if(ptype == POSITION_TYPE_SELL && close1 > open_price + buf)
         return true;  // short going against us
      if(ptype == POSITION_TYPE_BUY && close1 < open_price - buf)
         return true;  // long going against us
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

   // Advance the cached Quasimodo setup once per closed bar (bounded scan).
   AdvanceSetup_OnNewBar();

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
