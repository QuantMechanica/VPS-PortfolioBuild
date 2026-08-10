#property strict
#property version   "5.0"
#property description "QM5_20074 Horizontal S/R Break + Retest (H1)"
// Strategy Card: QM5_20074 (trendline-horizontal-sr-retest), G0 APPROVED.
// Source lineage: 6e967762-b26d-59a3-b076-35c17f2e7c36 (FF Trendline-Trader cluster,
// horizontal-S/R variant). Distinct from the diagonal sibling QM5_20076: this EA uses
// ZERO-SLOPE horizontal levels detected from >=3 swing-price clusters, not a sloped line.

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — Horizontal S/R Break + Retest
// -----------------------------------------------------------------------------
// Deterministic 3-bar-fractal swing detection feeds a bounded list of recent
// swing highs and lows (last strategy_lookback_bars H1 bars). Sorted swing
// prices are partitioned into clusters whose span <= cluster_frac*ATR; any
// cluster with >= min_swings members is a horizontal level (price = cluster
// mean). A closed bar that CLOSES beyond a level by >= break_frac*ATR (freshly
// crossing it from the prior bar) arms a break. A bounded retest (a bar that
// wicks back to the level within retest_frac*ATR and closes back on the break
// side) triggers a market entry at the open of the next bar. Exits: fixed
// RR=2.0 take-profit, an opposite-side S/R break against the position, or a
// 50-bar time-stop.
//
// Framework corset: every per-tick call is O(1) (spread gate + cached exit
// flag). All structural detection runs ONCE per closed bar inside
// Strategy_EntrySignal (the framework consumes QM_IsNewBar once per bar). Raw
// iHigh/iLow/iClose reads are bespoke structural-logic exceptions, tagged
// // perf-allowed and evaluated only behind that closed-bar gate.
// =============================================================================

#define QM5_20074_MAXSWINGS 512

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20074;
input int    qm_magic_slot_offset       = 0;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsMode qm_news_mode          = QM_NEWS_OFF;
input int    qm_news_pause_before_minutes = 30;
input int    qm_news_pause_after_minutes  = 30;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_fractal_k         = 3;     // Card: 3-bar fractal half-width each side (P3 {2,3,4}).
input int    strategy_lookback_bars     = 200;   // Card: scan window for swing clustering (bars).
input int    strategy_atr_period        = 14;    // Card: ATR(14,H1) for cluster/break/retest/stop scale.
input int    strategy_min_swings        = 3;     // Card: min swing-cluster count to declare a level (P3 {2,3,4}).
input double strategy_cluster_atr_frac  = 0.5;   // Card: cluster-width tolerance as fraction of ATR (P3 {0.3,0.5,0.7}).
input double strategy_break_atr_frac    = 0.3;   // Card: close must break the level by frac*ATR (P3 {0.2,0.3,0.5}).
input double strategy_retest_atr_frac   = 0.1;   // Card: retest touch tolerance as fraction of ATR.
input double strategy_sl_atr_frac       = 0.3;   // Card: SL buffer beyond retest extreme, frac*ATR (P3 {0.2,0.3,0.5}).
input int    strategy_retest_bars       = 20;    // Card: retest window (bars after break) (P3 {10,20,40}).
input double strategy_rr                = 2.0;   // Card: fixed reward:risk take-profit (P3 {1.5,2.0,2.5,3.0}).
input int    strategy_time_stop_bars    = 50;    // Card: max-hold flatten (~2 trading days).
input bool   strategy_time_stop_enabled = true;  // Card: tertiary time-stop exit (P3-toggleable).
input bool   strategy_opp_break_exit    = true;  // Card: secondary opposite-side S/R break exit (P3-toggleable).
input int    strategy_spread_cap_pts    = 25;    // Card: spread cap (points); only blocks a genuine wide spread.

// -----------------------------------------------------------------------------
// File-scope structural state (advanced once per closed bar).
// -----------------------------------------------------------------------------
long   g_bar_counter = -1;    // monotonic index of the last closed bar (advances only on real closed bars).
double g_atr         = 0.0;   // ATR(period) at the last closed bar; per-bar read only.

// Bounded rolling lists of recent confirmed swing prices (pruned by age each bar).
double g_sh_px[QM5_20074_MAXSWINGS]; long g_sh_ctr[QM5_20074_MAXSWINGS]; int g_sh_n = 0;  // swing highs.
double g_sl_px[QM5_20074_MAXSWINGS]; long g_sl_ctr[QM5_20074_MAXSWINGS]; int g_sl_n = 0;  // swing lows.

// Break signals computed once per bar (reused by entry-arming and opposite-exit).
double g_res_break = 0.0;     // level a resistance was freshly broken UPWARD this bar, else 0.
double g_sup_break = 0.0;     // level a support was freshly broken DOWNWARD this bar, else 0.

// LONG setup: resistance broken up, awaiting a retest of the broken level.
bool   g_long_active     = false;
double g_long_level      = 0.0;
long   g_long_break_ctr  = -1;
double g_long_retest_low = 0.0;   // low of the confirming retest bar (SL anchor).
bool   g_long_confirm    = false; // set on the confirm bar; consumed by Strategy_EntrySignal.

// SHORT setup: support broken down, awaiting a retest of the broken level.
bool   g_short_active     = false;
double g_short_level      = 0.0;
long   g_short_break_ctr  = -1;
double g_short_retest_high = 0.0; // high of the confirming retest bar (SL anchor).
bool   g_short_confirm    = false;

// Open-position tracking for structural exits (time-stop + opposite-break).
int    g_pos_dir       = 0;       // 0 flat, +1 long, -1 short.
long   g_pos_entry_ctr = -1;
bool   g_exit_requested = false;  // set once-per-bar; read O(1) per tick by Strategy_ExitSignal.

// -----------------------------------------------------------------------------
// Structural helpers (all behind the framework closed-bar gate).
// -----------------------------------------------------------------------------
bool IsSwingHigh(const int center_shift)
  {
   const double hc = iHigh(_Symbol, _Period, center_shift); // perf-allowed: bespoke fractal pivot, once per closed H1 bar.
   if(hc <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_k; j++)
     {
      const double hn = iHigh(_Symbol, _Period, center_shift - j); // perf-allowed: fractal newer-side neighbor.
      const double ho = iHigh(_Symbol, _Period, center_shift + j); // perf-allowed: fractal older-side neighbor.
      if(hn <= 0.0 || ho <= 0.0)
         return false;
      if(hc <= hn || hc <= ho)
         return false;
     }
   return true;
  }

bool IsSwingLow(const int center_shift)
  {
   const double lc = iLow(_Symbol, _Period, center_shift); // perf-allowed: bespoke fractal pivot, once per closed H1 bar.
   if(lc <= 0.0)
      return false;
   for(int j = 1; j <= strategy_fractal_k; j++)
     {
      const double ln = iLow(_Symbol, _Period, center_shift - j); // perf-allowed: fractal newer-side neighbor.
      const double lo = iLow(_Symbol, _Period, center_shift + j); // perf-allowed: fractal older-side neighbor.
      if(ln <= 0.0 || lo <= 0.0)
         return false;
      if(lc >= ln || lc >= lo)
         return false;
     }
   return true;
  }

// Drop entries older than the lookback window (compact in place).
void PruneSwings()
  {
   const long min_ctr = g_bar_counter - (long)strategy_lookback_bars;
   int w = 0;
   for(int i = 0; i < g_sh_n; i++)
      if(g_sh_ctr[i] >= min_ctr)
        { g_sh_px[w] = g_sh_px[i]; g_sh_ctr[w] = g_sh_ctr[i]; w++; }
   g_sh_n = w;

   w = 0;
   for(int i = 0; i < g_sl_n; i++)
      if(g_sl_ctr[i] >= min_ctr)
        { g_sl_px[w] = g_sl_px[i]; g_sl_ctr[w] = g_sl_ctr[i]; w++; }
   g_sl_n = w;
  }

void PushSwingHigh(const double px, const long ctr)
  {
   if(g_sh_n >= QM5_20074_MAXSWINGS)
      return; // pruning keeps this from happening in practice; guard against overflow.
   g_sh_px[g_sh_n] = px; g_sh_ctr[g_sh_n] = ctr; g_sh_n++;
  }

void PushSwingLow(const double px, const long ctr)
  {
   if(g_sl_n >= QM5_20074_MAXSWINGS)
      return;
   g_sl_px[g_sl_n] = px; g_sl_ctr[g_sl_n] = ctr; g_sl_n++;
  }

void DetectPivots()
  {
   const int c = strategy_fractal_k + 1; // center shift: needs k closed bars on the newer side (c-k == 1).
   const long center_ctr = g_bar_counter - (long)(c - 1);
   if(IsSwingHigh(c))
      PushSwingHigh(iHigh(_Symbol, _Period, c), center_ctr); // perf-allowed: record confirmed pivot price.
   if(IsSwingLow(c))
      PushSwingLow(iLow(_Symbol, _Period, c), center_ctr);   // perf-allowed: record confirmed pivot price.
  }

// Partition sorted swing prices into clusters of span <= width; emit the mean of
// each cluster with >= min_count members. Returns the number of levels found.
int BuildLevels(const double &src[], const int n, const double width, const int min_count, double &out_levels[])
  {
   if(n < min_count || width <= 0.0)
      return 0;
   double sorted[];
   ArrayResize(sorted, n);
   for(int i = 0; i < n; i++)
      sorted[i] = src[i];
   ArraySort(sorted); // ascending.

   int lc = 0;
   int i = 0;
   while(i < n)
     {
      int j = i;
      double sum = 0.0;
      int cnt = 0;
      while(j < n && (sorted[j] - sorted[i]) <= width)
        { sum += sorted[j]; cnt++; j++; }
      if(cnt >= min_count)
        { out_levels[lc] = sum / (double)cnt; lc++; }
      i = j;
     }
   return lc;
  }

// Highest resistance level the current bar freshly broke UPWARD (else 0).
double ComputeResistanceBreak(const double c1, const double c2, const double thr, const double width)
  {
   double levels[QM5_20074_MAXSWINGS];
   const int lc = BuildLevels(g_sh_px, g_sh_n, width, strategy_min_swings, levels);
   double best = 0.0;
   bool found = false;
   for(int i = 0; i < lc; i++)
     {
      const double L = levels[i];
      if(c2 <= L + thr && c1 > L + thr) // fresh upward cross of the break threshold.
        {
         if(!found || L > best)
           { best = L; found = true; }
        }
     }
   return found ? best : 0.0;
  }

// Lowest support level the current bar freshly broke DOWNWARD (else 0).
double ComputeSupportBreak(const double c1, const double c2, const double thr, const double width)
  {
   double levels[QM5_20074_MAXSWINGS];
   const int lc = BuildLevels(g_sl_px, g_sl_n, width, strategy_min_swings, levels);
   double best = 0.0;
   bool found = false;
   for(int i = 0; i < lc; i++)
     {
      const double L = levels[i];
      if(c2 >= L - thr && c1 < L - thr) // fresh downward cross of the break threshold.
        {
         if(!found || L < best)
           { best = L; found = true; }
        }
     }
   return found ? best : 0.0;
  }

void UpdateLongMachine()
  {
   if(!g_long_active)
     {
      if(g_res_break > 0.0)
        {
         g_long_active = true;
         g_long_level = g_res_break;
         g_long_break_ctr = g_bar_counter;
         g_long_retest_low = 0.0;
        }
      return;
     }

   if(g_bar_counter - g_long_break_ctr > (long)strategy_retest_bars)
     {
      g_long_active = false; // break event expired without a retest.
      return;
     }

   const double R = g_long_level;
   const double low1   = iLow(_Symbol, _Period, 1);   // perf-allowed: closed-bar retest wick.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar retest confirm.
   if(low1 <= 0.0 || close1 <= 0.0)
      return;
   if(low1 <= R + strategy_retest_atr_frac * g_atr && close1 > R)
     {
      g_long_retest_low = low1;
      g_long_confirm = true; // enter long at the open of the next (current forming) bar.
     }
  }

void UpdateShortMachine()
  {
   if(!g_short_active)
     {
      if(g_sup_break > 0.0)
        {
         g_short_active = true;
         g_short_level = g_sup_break;
         g_short_break_ctr = g_bar_counter;
         g_short_retest_high = 0.0;
        }
      return;
     }

   if(g_bar_counter - g_short_break_ctr > (long)strategy_retest_bars)
     {
      g_short_active = false;
      return;
     }

   const double S = g_short_level;
   const double high1  = iHigh(_Symbol, _Period, 1);  // perf-allowed: closed-bar retest wick.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar retest confirm.
   if(high1 <= 0.0 || close1 <= 0.0)
      return;
   if(high1 >= S - strategy_retest_atr_frac * g_atr && close1 < S)
     {
      g_short_retest_high = high1;
      g_short_confirm = true; // enter short at the open of the next (current forming) bar.
     }
  }

void UpdateExitState()
  {
   if(g_pos_dir == 0)
     {
      g_exit_requested = false;
      return;
     }

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) == 0)
     {
      // Position closed by SL/TP (or a prior exit); clear tracking.
      g_pos_dir = 0;
      g_exit_requested = false;
      return;
     }

   if(strategy_time_stop_enabled && g_bar_counter - g_pos_entry_ctr >= (long)strategy_time_stop_bars)
     {
      g_exit_requested = true;
      return;
     }

   if(strategy_opp_break_exit)
     {
      // Opposite-side S/R break against the position closes it.
      if(g_pos_dir > 0 && g_sup_break > 0.0)
         g_exit_requested = true;
      else
         if(g_pos_dir < 0 && g_res_break > 0.0)
            g_exit_requested = true;
     }
  }

void AdvanceStructuralState()
  {
   g_bar_counter++;
   g_atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(g_atr <= 0.0)
      return; // ATR warmup — no detection yet.

   DetectPivots();
   PruneSwings();

   const double c1  = iClose(_Symbol, _Period, 1); // perf-allowed: closed-bar break test.
   const double c2  = iClose(_Symbol, _Period, 2); // perf-allowed: prior-bar break reference (fresh-cross).
   const double thr = strategy_break_atr_frac * g_atr;
   const double width = strategy_cluster_atr_frac * g_atr;
   if(c1 > 0.0 && c2 > 0.0)
     {
      g_res_break = ComputeResistanceBreak(c1, c2, thr, width);
      g_sup_break = ComputeSupportBreak(c1, c2, thr, width);
     }
   else
     {
      g_res_break = 0.0;
      g_sup_break = 0.0;
     }

   UpdateLongMachine();
   UpdateShortMachine();
   UpdateExitState();
  }

// -----------------------------------------------------------------------------
// Strategy hooks.
// -----------------------------------------------------------------------------

// No Trade Filter — spread gate only (Friday close handled by the framework).
// Never fail-closed on zero modeled spread (.DWX invariant #1).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double cap = strategy_spread_cap_pts * point;
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > cap)
      return true; // block only a genuinely wide spread.
   return false;
  }

// Trade Entry — advances structural state once per closed bar, then fires a
// market entry when a bounded retest of a broken horizontal level confirms.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_long_confirm = false;
   g_short_confirm = false;
   AdvanceStructuralState();

   if(g_atr <= 0.0)
      return false;

   // One position per symbol per magic.
   if(g_pos_dir != 0)
      return false;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0 || QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double buffer = strategy_sl_atr_frac * g_atr;

   if(g_long_confirm && g_long_retest_low > 0.0)
     {
      const double entry_est = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry_est <= 0.0)
        {
         g_long_active = false;
         return false;
        }
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_long_retest_low - buffer); // card: retest low - 0.3*ATR.
      if(sl <= 0.0 || sl >= entry_est)
        {
         g_long_active = false;
         return false;
        }
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry_est, sl, strategy_rr);
      req.type = QM_BUY;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "HSR_LONG_RETEST";

      g_pos_dir = 1;
      g_pos_entry_ctr = g_bar_counter;
      g_long_active = false;
      g_exit_requested = false;
      return true;
     }

   if(g_short_confirm && g_short_retest_high > 0.0)
     {
      const double entry_est = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry_est <= 0.0)
        {
         g_short_active = false;
         return false;
        }
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_short_retest_high + buffer); // card: retest high + 0.3*ATR.
      if(sl <= entry_est)
        {
         g_short_active = false;
         return false;
        }
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry_est, sl, strategy_rr);
      req.type = QM_SELL;
      req.price = 0.0;
      req.sl = sl;
      req.tp = tp;
      req.reason = "HSR_SHORT_RETEST";

      g_pos_dir = -1;
      g_pos_entry_ctr = g_bar_counter;
      g_short_active = false;
      g_exit_requested = false;
      return true;
     }

   return false;
  }

// Trade Management — baseline carries no trailing/BE/partial logic (card §Stop Loss).
void Strategy_ManageOpenPosition()
  {
   // No per-tick management in the baseline; SL/TP ride to the framework.
  }

// Trade Close — reads the once-per-bar cached decision (time-stop or opposite
// S/R break). RR take-profit and the initial SL are broker-side.
bool Strategy_ExitSignal()
  {
   return g_exit_requested;
  }

// News Filter Hook — defer to the central QM_NewsAllowsTrade gate (off for P2).
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        qm_news_pause_before_minutes,
                        qm_news_pause_after_minutes,
                        qm_news_stale_max_hours,
                        qm_news_min_impact))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_20074_trendline-horizontal-sr-retest\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (time-stop / opposite-break). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   if(!QM_IsNewBar())
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
