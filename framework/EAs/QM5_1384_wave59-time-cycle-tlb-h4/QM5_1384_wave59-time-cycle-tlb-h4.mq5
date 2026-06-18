#property strict
#property version   "5.0"
#property description "QM5_1384 Wave59 Time-Cycle + Three-Line-Break (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 — QM5_1384 wave59-time-cycle-tlb-h4
// -----------------------------------------------------------------------------
// Strategy (per card QM5_1384_wave59-time-cycle-tlb-h4):
//   - A deterministic bar-count "time cycle" projects WHEN a swing reversal is
//     due: cycle_low = round(median(bar-gaps between the last N confirmed pivot
//     lows)); cycle_high = mirror on pivot highs. Recomputed each new closed
//     bar from history — no PnL feedback (HR14-safe).
//   - A Three-Line-Break (TLB) chart is built in-EA from CLOSED H4 closes only
//     (no time, no OHLC range): a new "line"/block forms only when the close
//     exceeds the extreme of the prior `tlb_lines` blocks. The color FLIP
//     (red->green / green->red) is the single trigger EVENT.
//   - Entry fires when the TLB flip on bar[1] coincides with the cycle window
//     [cycle - 2, cycle + 2] measured from the last confirmed opposite pivot,
//     with a candidate-proximity gate, a soft macro-bias gate, and a cycle-
//     length sanity gate.
//
// Only the five Strategy_* hooks below are EA-specific. Bespoke structural math
// (pivot scan, TLB block construction) uses direct iClose/iTime reads under the
// documented // perf-allowed exception (gated to one rebuild per closed bar).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1384;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_pivot_k            = 3;      // fractal half-width for pivots
input int    strategy_cycle_pivots       = 10;     // last-N confirmed pivots for cycle median
input int    strategy_cycle_window       = 2;      // +/- bars around projected cycle bar
input int    strategy_cycle_min          = 8;      // cycle-length sanity floor
input int    strategy_cycle_max          = 60;     // cycle-length sanity ceiling
input int    strategy_tlb_lines          = 3;      // canonical three-line-break
input int    strategy_tlb_blocks_max     = 400;    // TLB block buffer depth
input int    strategy_atr_period         = 14;
input double strategy_cand_atr_mult      = 1.5;    // new low/high proximity to prior pivot
input double strategy_sl_atr             = 0.5;    // SL buffer beyond confirmed extreme
input double strategy_max_sl_atr         = 2.5;    // cap on initial SL distance
input double strategy_tp_fraction        = 0.5;    // half-cycle TP fraction (P3 sweep)
input double strategy_macro_atr          = 2.0;    // catastrophic-trend soft filter band
input int    strategy_macro_sma          = 200;
input double strategy_spread_atr         = 0.4;    // fail-open spread cap (xATR)
input double strategy_timestop_cycle_mult = 1.5;   // time-stop = mult * cycle bars
input int    strategy_session_start_hour = 6;      // broker-time no-trade window [22,06)
input int    strategy_session_end_hour   = 22;

// File-scope cached structural state (rebuilt once per closed bar) -------------
int      g_pivot_low_shift  = -1;   // bar shift of last confirmed pivot LOW
double   g_pivot_low_price  = 0.0;
int      g_pivot_high_shift = -1;   // bar shift of last confirmed pivot HIGH
double   g_pivot_high_price = 0.0;
int      g_cycle_low        = 0;    // projected bars between pivot lows
int      g_cycle_high       = 0;    // projected bars between pivot highs

int      g_tlb_color1       = 0;    // TLB color of most-recent block: +1 green / -1 red / 0 none
int      g_tlb_color2       = 0;    // prior block color (for flip detection)

datetime g_last_build_bar   = 0;
datetime g_cooldown_until   = 0;
datetime g_last_hist_check  = 0;
datetime g_entry_bar_time   = 0;    // bar time the active position was opened on

// --- Pivot scan: a confirmed pivot needs `k` lower-low (or higher-high)
//     neighbours on EACH side. We scan closed bars (shift>=1). -----------------
bool TC_FindPivot(const bool want_low, const int k, const int max_scan,
                  int &out_shift, double &out_price)
  {
   out_shift = -1;
   out_price = 0.0;
   const int last = max_scan - k;
   for(int c = 1 + k; c <= last; ++c)               // candidate center bar
     {
      // perf-allowed: bespoke pivot structure, gated to one closed-bar rebuild.
      const double center = want_low ? iLow(_Symbol, strategy_tf, c)
                                     : iHigh(_Symbol, strategy_tf, c);
      if(center <= 0.0)
         continue;
      bool ok = true;
      for(int j = 1; j <= k && ok; ++j)
        {
         const double lo_l = want_low ? iLow(_Symbol, strategy_tf, c - j)
                                      : iHigh(_Symbol, strategy_tf, c - j);
         const double lo_r = want_low ? iLow(_Symbol, strategy_tf, c + j)
                                      : iHigh(_Symbol, strategy_tf, c + j);
         if(lo_l <= 0.0 || lo_r <= 0.0)
           { ok = false; break; }
         if(want_low)
           {
            if(!(center < lo_l) || !(center < lo_r)) ok = false;
           }
         else
           {
            if(!(center > lo_l) || !(center > lo_r)) ok = false;
           }
        }
      if(ok)
        {
         out_shift = c;
         out_price = center;
         return true;     // nearest confirmed pivot (smallest shift)
        }
     }
   return false;
  }

// --- Collect last-N confirmed pivot shifts (want_low/high), then median gap. --
int TC_CycleLength(const bool want_low, const int k, const int n_pivots, const int max_scan)
  {
   int shifts[];
   ArrayResize(shifts, 0);
   int found = 0;
   int c = 1 + k;
   const int last = max_scan - k;
   while(c <= last && found < n_pivots)
     {
      const double center = want_low ? iLow(_Symbol, strategy_tf, c)   // perf-allowed
                                     : iHigh(_Symbol, strategy_tf, c);
      if(center <= 0.0) { ++c; continue; }
      bool ok = true;
      for(int j = 1; j <= k && ok; ++j)
        {
         const double lo_l = want_low ? iLow(_Symbol, strategy_tf, c - j)
                                      : iHigh(_Symbol, strategy_tf, c - j);
         const double lo_r = want_low ? iLow(_Symbol, strategy_tf, c + j)
                                      : iHigh(_Symbol, strategy_tf, c + j);
         if(lo_l <= 0.0 || lo_r <= 0.0) { ok = false; break; }
         if(want_low) { if(!(center < lo_l) || !(center < lo_r)) ok = false; }
         else         { if(!(center > lo_l) || !(center > lo_r)) ok = false; }
        }
      if(ok)
        {
         ArrayResize(shifts, found + 1);
         shifts[found] = c;
         ++found;
         c += k + 1;     // step past the confirmed pivot's right window
        }
      else
         ++c;
     }
   if(found < 3)
      return 0;          // not enough pivots to estimate a cycle

   // gaps between consecutive pivots (shifts are increasing into the past)
   int gaps[];
   const int ng = found - 1;
   ArrayResize(gaps, ng);
   for(int g = 0; g < ng; ++g)
      gaps[g] = shifts[g + 1] - shifts[g];     // positive bar-count gap

   ArraySort(gaps);
   double med;
   if((ng % 2) == 1)
      med = (double)gaps[ng / 2];
   else
      med = 0.5 * ((double)gaps[ng / 2 - 1] + (double)gaps[ng / 2]);
   return (int)MathRound(med);
  }

// --- TLB construction from CLOSED closes only (oldest -> newest). The color of
//     the most-recent block and the prior block are cached for flip detection.
//     A new block forms only when close breaks the extreme of the prior
//     `tlb_lines` blocks (continuation) OR breaks the opposite extreme of the
//     last `tlb_lines` blocks (reversal => color flip). ------------------------
void TC_BuildTLB(const int max_scan)
  {
   g_tlb_color1 = 0;
   g_tlb_color2 = 0;

   // Block extremes (top/bottom of each TLB line block) and color, in build order.
   double btop[];
   double bbot[];
   int    bcol[];
   ArrayResize(btop, 0);
   ArrayResize(bbot, 0);
   ArrayResize(bcol, 0);
   int nb = 0;

   const int cap = strategy_tlb_blocks_max;
   const int nlines = strategy_tlb_lines;

   // Walk closed closes from oldest (largest shift) to newest (shift 1).
   const int start = MathMin(max_scan, cap + nlines + 5);
   double prev_close = 0.0;
   for(int s = start; s >= 1; --s)
     {
      const double cl = iClose(_Symbol, strategy_tf, s);   // perf-allowed
      if(cl <= 0.0)
         continue;

      if(nb == 0)
        {
         if(prev_close <= 0.0) { prev_close = cl; continue; }
         // seed the first block from the first two valid closes
         const int col = (cl > prev_close) ? 1 : ((cl < prev_close) ? -1 : 0);
         if(col == 0) { prev_close = cl; continue; }
         ArrayResize(btop, 1); ArrayResize(bbot, 1); ArrayResize(bcol, 1);
         btop[0] = MathMax(cl, prev_close);
         bbot[0] = MathMin(cl, prev_close);
         bcol[0] = col;
         nb = 1;
         prev_close = cl;
         continue;
        }

      // reference window = last min(nlines, nb) blocks
      const int win = MathMin(nlines, nb);
      double hi = -DBL_MAX, lo = DBL_MAX;
      for(int w = nb - win; w < nb; ++w)
        {
         if(btop[w] > hi) hi = btop[w];
         if(bbot[w] < lo) lo = bbot[w];
        }
      const int cur_col = bcol[nb - 1];

      if(cur_col > 0)
        {
         if(cl > hi)                         // green continuation
           { TC_PushBlock(btop, bbot, bcol, nb, prev_close, cl, 1); }
         else if(cl < lo)                    // reversal to red (break of range)
           { TC_PushBlock(btop, bbot, bcol, nb, prev_close, cl, -1); }
        }
      else // cur_col < 0
        {
         if(cl < lo)                         // red continuation
           { TC_PushBlock(btop, bbot, bcol, nb, prev_close, cl, -1); }
         else if(cl > hi)                    // reversal to green
           { TC_PushBlock(btop, bbot, bcol, nb, prev_close, cl, 1); }
        }
      prev_close = cl;
     }

   if(nb >= 1) g_tlb_color1 = bcol[nb - 1];
   if(nb >= 2) g_tlb_color2 = bcol[nb - 2];
  }

// helper to append a TLB block and keep nb in sync (range = prior_close..close)
void TC_PushBlock(double &btop[], double &bbot[], int &bcol[], int &nb,
                  const double prior_close, const double cl, const int col)
  {
   ArrayResize(btop, nb + 1);
   ArrayResize(bbot, nb + 1);
   ArrayResize(bcol, nb + 1);
   btop[nb] = MathMax(cl, prior_close);
   bbot[nb] = MathMin(cl, prior_close);
   bcol[nb] = col;
   ++nb;
  }

// --- Rebuild all cached structural state once per closed bar. -----------------
void TC_RebuildState()
  {
   const int avail = Bars(_Symbol, strategy_tf);
   const int max_scan = MathMin(avail - 2, strategy_tlb_blocks_max + 50);
   if(max_scan < 5 * strategy_pivot_k + 10)
      return;

   TC_FindPivot(true,  strategy_pivot_k, max_scan, g_pivot_low_shift,  g_pivot_low_price);
   TC_FindPivot(false, strategy_pivot_k, max_scan, g_pivot_high_shift, g_pivot_high_price);
   g_cycle_low  = TC_CycleLength(true,  strategy_pivot_k, strategy_cycle_pivots, max_scan);
   g_cycle_high = TC_CycleLength(false, strategy_pivot_k, strategy_cycle_pivots, max_scan);
   TC_BuildTLB(max_scan);
  }

// --- SL-cooldown: after an SL hit, block `cycle_low` bars on this symbol. ------
void TC_UpdateCooldown()
  {
   const datetime now = TimeCurrent();
   const datetime from_time = (g_last_hist_check > 0) ? g_last_hist_check : (now - 86400 * 30);
   g_last_hist_check = now;
   if(!HistorySelect(from_time, now))
      return;
   const int magic = QM_FrameworkMagic();
   const int total = HistoryDealsTotal();
   const int cyc = (g_cycle_low >= strategy_cycle_min) ? g_cycle_low : strategy_cycle_min;
   for(int i = total - 1; i >= 0; --i)
     {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      if((int)HistoryDealGetInteger(deal, DEAL_MAGIC) != magic) continue;
      if(HistoryDealGetString(deal, DEAL_SYMBOL) != _Symbol) continue;
      if((ENUM_DEAL_REASON)HistoryDealGetInteger(deal, DEAL_REASON) != DEAL_REASON_SL) continue;
      const datetime deal_time = (datetime)HistoryDealGetInteger(deal, DEAL_TIME);
      const datetime until = deal_time + (datetime)(cyc * PeriodSeconds(strategy_tf));
      if(until > g_cooldown_until)
         g_cooldown_until = until;
     }
  }

// =============================================================================
// Strategy hooks
// =============================================================================

bool Strategy_NoTradeFilter()
  {
   // Broker-time liquidity window: no new entries [22:00, 06:00).
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour >= strategy_session_end_hour || dt.hour < strategy_session_start_hour)
      return true;

   if(g_cooldown_until > 0 && TimeCurrent() < g_cooldown_until)
      return true;

   // Fail-OPEN spread guard: only block a genuinely WIDE spread. .DWX quotes
   // ask==bid (0 modeled spread) in the tester => never block on zero spread.
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(atr <= 0.0)
      return false;   // can't size the cap -> fail open
   if(ask > 0.0 && bid > 0.0 && ask > bid && (ask - bid) > strategy_spread_atr * atr)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   TC_UpdateCooldown();
   if(g_cooldown_until > 0 && TimeCurrent() < g_cooldown_until)
      return false;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, strategy_tf, 1);   // perf-allowed (last closed bar)
   const double low1   = iLow(_Symbol, strategy_tf, 1);
   const double high1  = iHigh(_Symbol, strategy_tf, 1);
   if(close1 <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   const double sma200 = QM_SMA(_Symbol, strategy_tf, strategy_macro_sma, 1);
   if(sma200 <= 0.0)
      return false;

   int direction = 0;
   double sl_anchor = 0.0;

   // ----- Bullish: cycle window from last pivot LOW + TLB flip red->green -----
   if(g_pivot_low_shift > 0 && g_cycle_low >= strategy_cycle_min && g_cycle_low <= strategy_cycle_max)
     {
      // bar[1] is one closed bar; bars since the pivot low = g_pivot_low_shift - 1.
      const int bars_since = g_pivot_low_shift - 1;
      const bool in_window = (bars_since >= g_cycle_low - strategy_cycle_window) &&
                             (bars_since <= g_cycle_low + strategy_cycle_window);
      const bool tlb_flip_up = (g_tlb_color1 > 0 && g_tlb_color2 < 0);
      const bool cand_ok = (low1 <= g_pivot_low_price + strategy_cand_atr_mult * atr);
      const bool macro_ok = (close1 > sma200 - strategy_macro_atr * atr);
      if(in_window && tlb_flip_up && cand_ok && macro_ok)
        {
         direction = 1;
         sl_anchor = low1;
        }
     }

   // ----- Bearish: cycle window from last pivot HIGH + TLB flip green->red ----
   if(direction == 0 &&
      g_pivot_high_shift > 0 && g_cycle_high >= strategy_cycle_min && g_cycle_high <= strategy_cycle_max)
     {
      const int bars_since = g_pivot_high_shift - 1;
      const bool in_window = (bars_since >= g_cycle_high - strategy_cycle_window) &&
                             (bars_since <= g_cycle_high + strategy_cycle_window);
      const bool tlb_flip_dn = (g_tlb_color1 < 0 && g_tlb_color2 > 0);
      const bool cand_ok = (high1 >= g_pivot_high_price - strategy_cand_atr_mult * atr);
      const bool macro_ok = (close1 < sma200 + strategy_macro_atr * atr);
      if(in_window && tlb_flip_dn && cand_ok && macro_ok)
        {
         direction = -1;
         sl_anchor = high1;
        }
     }

   if(direction == 0)
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Initial SL: just beyond the confirmed cycle extreme, capped at max_sl_atr.
   double sl = (direction > 0) ? (sl_anchor - strategy_sl_atr * atr)
                               : (sl_anchor + strategy_sl_atr * atr);
   const double max_sl = strategy_max_sl_atr * atr;
   if(direction > 0 && (entry - sl) > max_sl) sl = entry - max_sl;
   if(direction < 0 && (sl - entry) > max_sl) sl = entry + max_sl;

   // TP: half-cycle projection. Project the next opposite-cycle extreme
   // (cycle_high/2 bars worth of the confirmed swing amplitude) and take
   // strategy_tp_fraction of the entry->projection distance.
   const int proj_cycle = (direction > 0) ? g_cycle_high : g_cycle_low;
   const double swing_amp = (direction > 0) ? (g_pivot_high_price - sl_anchor)
                                            : (sl_anchor - g_pivot_low_price);
   double tp;
   if(proj_cycle > 0 && swing_amp > 0.0)
     {
      const double dist = strategy_tp_fraction * swing_amp;
      tp = (direction > 0) ? (entry + dist) : (entry - dist);
     }
   else
     {
      // Fallback: 2 ATR target if amplitude is degenerate.
      tp = (direction > 0) ? (entry + 2.0 * atr) : (entry - 2.0 * atr);
     }

   // sanity: SL/TP on correct sides
   if(direction > 0 && (sl >= entry || tp <= entry)) return false;
   if(direction < 0 && (sl <= entry || tp >= entry)) return false;

   req.type   = (direction > 0) ? QM_BUY : QM_SELL;
   req.price  = 0.0;
   req.sl     = NormalizeDouble(sl, _Digits);
   req.tp     = NormalizeDouble(tp, _Digits);
   req.reason = (direction > 0) ? "cycle_low_tlb_green_flip" : "cycle_high_tlb_red_flip";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_entry_bar_time = iTime(_Symbol, strategy_tf, 0);   // perf-allowed
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // No active trailing per card (hard SL, no widening). Break-even is not in
   // the card mechanics; SL/TP/TLB-reversal/time-stop handle the exit. No-op.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);

      // TLB reversal exit: color flipped back against the position.
      if(is_buy && g_tlb_color1 < 0)  return true;
      if(!is_buy && g_tlb_color1 > 0) return true;

      // Time-stop: 1.5 * cycle bars without TP/SL/reversal.
      const int cyc = is_buy ? ((g_cycle_low > 0) ? g_cycle_low : strategy_cycle_min)
                             : ((g_cycle_high > 0) ? g_cycle_high : strategy_cycle_min);
      const int max_hold = (int)MathRound(strategy_timestop_cycle_mult * (double)cyc);
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int held_bars = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(max_hold > 0 && held_bars >= max_hold)
         return true;
     }
   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to central QM_NewsAllowsTrade
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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

   // Per-tick: discretionary exit (TLB reversal / time-stop) on cached state.
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

   // Single new-bar consume per tick.
   if(!QM_IsNewBar())
      return;

   // Rebuild cached structural state ONCE per closed bar.
   const datetime bar0 = iTime(_Symbol, strategy_tf, 0);
   if(bar0 != g_last_build_bar)
     {
      TC_RebuildState();
      g_last_build_bar = bar0;
     }

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
