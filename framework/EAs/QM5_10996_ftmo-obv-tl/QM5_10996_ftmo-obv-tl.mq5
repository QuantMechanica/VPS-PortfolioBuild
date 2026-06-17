#property strict
#property version   "5.0"
#property description "QM5_10996 ftmo-obv-tl — OBV Trendline Breakout w/ Donchian price confirmation (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10996 ftmo-obv-tl
// -----------------------------------------------------------------------------
// Source: FTMO, "Technical Indicators in Trading Strategies", 2026
//         https://ftmo.com/en/technical-indicators-in-trading-strategies/
// Card: artifacts/cards_approved/QM5_10996_ftmo-obv-tl.md (g0_status APPROVED).
//
// Mechanics (H1, closed-bar reads at shift 1; OBV from tick volume, advanced
// ONCE per closed bar and cached — never re-summed per tick):
//
//   OBV         : cumulative tick-volume balance. obv += sign(close-close_prev)
//                 * tick_volume of each newly closed bar. Cached in a ring of
//                 g_obv[] (index 1 = last closed bar, larger = older).
//   Donchian    : highest high / lowest low of the prior `donchian_period`
//                 closed bars (excluding the breakout bar itself).
//   OBV swings  : a 1-bar fractal pivot on the OBV series (obv[s] strictly above
//                 / below its immediate neighbours). The two most recent swing
//                 highs (for the long-blocking descending line) and swing lows
//                 (for the short-blocking ascending line) inside the last
//                 `obv_swing_lookback` bars define the OBV trendlines.
//   OBV slope   : obv[1] - obv[1+obv_slope_bars] (10-bar slope by default).
//
//   LONG  : close[1] > donchian_high + price_break_atr_mult * ATR
//           AND OBV closed above its descending swing-high trendline within the
//               last (1 + obv_break_recent_bars) closed bars
//           AND OBV 10-bar slope > 0.
//   SHORT : mirror (close[1] < donchian_low - ... ; OBV below ascending swing-low
//           line; slope < 0).
//
//   Filters: Donchian range height in [range_min_atr, range_max_atr] * ATR;
//            the two OBV swing pivots between `swing_gap_min` and `swing_gap_max`
//            bars apart; one position per symbol/magic.
//   Stop   : LONG SL = donchian_high - sl_atr_mult * ATR (breakout-level based).
//            SHORT SL = donchian_low + sl_atr_mult * ATR.
//   Take   : tp_rr * R from the entry/stop distance.
//   Exit   : time exit after `time_exit_bars` H1 bars; early exit when price has
//            closed back inside the Donchian range AND OBV has closed back across
//            the broken trendline.
//
// .DWX invariants honoured: OBV uses tick volume (exchange volume absent); OBV
// advanced once per closed bar in AdvanceState_OnNewBar (no per-tick re-sum);
// fail-OPEN spread guard; broker $0 swap not gated; prior CLOSE used for OBV
// sign; no external macro feed. Only the 5 Strategy_* hooks + AdvanceState +
// inputs are EA-specific; framework wiring is intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10996;
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
input int    donchian_period            = 30;    // Donchian breakout lookback (prior bars)
input int    atr_period                 = 14;    // ATR period (break threshold / stop / range filter)
input double price_break_atr_mult       = 0.10;  // price must clear Donchian level by this * ATR
input double sl_atr_mult                = 0.75;  // SL distance from breakout level = mult * ATR
input double tp_rr                      = 2.0;   // take-profit = tp_rr * R
input int    time_exit_bars             = 40;    // close after this many H1 bars in trade
input double range_min_atr              = 1.0;   // min Donchian range height in ATR units
input double range_max_atr              = 4.0;   // max Donchian range height in ATR units
input int    obv_swing_lookback         = 60;    // bars to scan for the two most-recent OBV swings
input int    obv_slope_bars             = 10;    // OBV slope measured over this many bars
input int    obv_break_recent_bars      = 2;     // OBV may have crossed its line up to this many bars ago
input int    swing_gap_min              = 8;     // min bar gap between the two OBV swing pivots
input int    swing_gap_max              = 45;    // max bar gap between the two OBV swing pivots
input double spread_pct_of_stop         = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar).
// g_obv[i]   : OBV value for closed-bar shift i (i=1 last closed, grows older).
// g_close[i] : close price for closed-bar shift i (mirror cache for sign math).
// -----------------------------------------------------------------------------
#define OBV_RING 200

double   g_obv[OBV_RING];
double   g_close_ring[OBV_RING];
bool     g_state_ready   = false;   // true once the ring is warm (>= needed bars)
int      g_obv_valid     = 0;       // number of valid ring entries (1..OBV_RING-1)
datetime g_last_bar_seen = 0;       // bar-open time of the most recent cached bar

// Per-trade bookkeeping for the time exit.
datetime g_entry_bar_time = 0;      // bar-open time when the live position opened

// Cached signal geometry recomputed each closed bar (read by entry/exit hooks).
double   g_donchian_high = 0.0;
double   g_donchian_low  = 0.0;
double   g_atr_cached    = 0.0;
// OBV trendline values projected to the LAST closed bar (shift 1) and the
// values one/two bars earlier, so the "crossed within recent bars" test is O(1).
double   g_obv_desc_line[4];        // descending swing-high line value at shift 1..3
double   g_obv_asc_line[4];         // ascending  swing-low  line value at shift 1..3
bool     g_desc_line_ok  = false;   // a valid descending swing-high line exists
bool     g_asc_line_ok   = false;   // a valid ascending  swing-low  line exists

// -----------------------------------------------------------------------------
// OBV ring helpers
// -----------------------------------------------------------------------------

// Rebuild the OBV ring from scratch on the first warm call, then advance by one
// bar per subsequent closed bar. The ring is small and bounded by OBV_RING.
void OBV_RebuildRing()
  {
   const int avail = Bars(_Symbol, _Period);                 // perf-allowed: once at warmup
   int n = OBV_RING - 1;
   if(n > avail - 2)
      n = avail - 2;
   if(n < 2)
     {
      g_obv_valid   = 0;
      g_state_ready = false;
      return;
     }

   // Build oldest -> newest cumulative OBV, then store into the shift-indexed
   // ring (index 1 = last closed bar). We anchor OBV at 0 for the oldest bar.
   double obv_run = 0.0;
   double prev_close = iClose(_Symbol, _Period, n + 1);       // perf-allowed: warmup scan
   for(int s = n; s >= 1; --s)
     {
      const double c   = iClose(_Symbol, _Period, s);         // perf-allowed: warmup scan
      const double vol = (double)iVolume(_Symbol, _Period, s);// perf-allowed: warmup scan
      if(c > prev_close)      obv_run += vol;
      else if(c < prev_close) obv_run -= vol;
      // c == prev_close: OBV unchanged
      g_obv[s]        = obv_run;
      g_close_ring[s] = c;
      prev_close      = c;
     }
   g_obv_valid     = n;
   g_state_ready   = true;
   g_last_bar_seen = iTime(_Symbol, _Period, 0);              // perf-allowed: bar stamp
  }

// Shift the ring one slot older and append the newly closed bar at index 1.
void OBV_AdvanceOneBar()
  {
   // Newly closed bar is at shift 1; previous last-closed is now at shift 2.
   const double c_new   = iClose(_Symbol, _Period, 1);        // perf-allowed: single closed bar
   const double vol_new = (double)iVolume(_Symbol, _Period, 1);// perf-allowed: single closed bar
   const double c_prev  = iClose(_Symbol, _Period, 2);        // perf-allowed: single closed bar

   // Shift existing entries older (index i -> i+1), bounded by OBV_RING.
   int top = g_obv_valid;
   if(top > OBV_RING - 2)
      top = OBV_RING - 2;
   for(int i = top; i >= 1; --i)
     {
      g_obv[i + 1]        = g_obv[i];
      g_close_ring[i + 1] = g_close_ring[i];
     }

   double obv_prev = g_obv[2];   // OBV of the now-second bar (post-shift)
   double obv_new  = obv_prev;
   if(c_new > c_prev)      obv_new += vol_new;
   else if(c_new < c_prev) obv_new -= vol_new;
   g_obv[1]        = obv_new;
   g_close_ring[1] = c_new;

   g_obv_valid = top + 1;
   if(g_obv_valid > OBV_RING - 1)
      g_obv_valid = OBV_RING - 1;
  }

// -----------------------------------------------------------------------------
// Signal geometry — recomputed once per closed bar from the cached ring.
// -----------------------------------------------------------------------------

// Find the two most-recent OBV swing pivots of a given polarity inside the
// lookback window. A 1-bar fractal: obv[s] strictly > both neighbours (high)
// or strictly < both neighbours (low). Returns the projected line value at
// shifts 1,2,3 in out_line[1..3]; out_ok=true iff two valid pivots gap-filtered.
void OBV_BuildTrendline(const bool want_high, double &out_line[], bool &out_ok)
  {
   out_ok = false;
   out_line[1] = 0.0; out_line[2] = 0.0; out_line[3] = 0.0;

   int last_scan = obv_swing_lookback;
   if(last_scan > g_obv_valid - 1)
      last_scan = g_obv_valid - 1;
   if(last_scan < 4)
      return;

   // Collect pivots from newest (small shift) to oldest. We want the two most
   // recent, so scan increasing shift and take the first two found.
   int    p1_shift = -1, p2_shift = -1;
   double p1_val = 0.0, p2_val = 0.0;
   for(int s = 2; s <= last_scan; ++s)   // need s-1 and s+1 to exist
     {
      const double mid  = g_obv[s];
      const double younger = g_obv[s - 1];
      const double older   = g_obv[s + 1];
      bool is_pivot = false;
      if(want_high)
         is_pivot = (mid > younger && mid > older);
      else
         is_pivot = (mid < younger && mid < older);
      if(!is_pivot)
         continue;
      if(p1_shift < 0)
        {
         p1_shift = s; p1_val = mid;
        }
      else
        {
         p2_shift = s; p2_val = mid;
         break;
        }
     }

   if(p1_shift < 0 || p2_shift < 0)
      return;

   const int gap = p2_shift - p1_shift;   // older shift - newer shift, > 0
   if(gap < swing_gap_min || gap > swing_gap_max)
      return;

   // Line through (p2_shift, p2_val) [older] and (p1_shift, p1_val) [newer].
   // slope per bar moving toward NOW (decreasing shift):
   //   value(shift) = p1_val + (p1_shift - shift) * slope_per_bar
   // where slope_per_bar = (p1_val - p2_val) / (p2_shift - p1_shift).
   const double slope_per_bar = (p1_val - p2_val) / (double)gap;
   for(int sh = 1; sh <= 3; ++sh)
      out_line[sh] = p1_val + (double)(p1_shift - sh) * slope_per_bar;

   out_ok = true;
  }

void Recompute_Donchian()
  {
   g_donchian_high = 0.0;
   g_donchian_low  = 0.0;
   if(g_obv_valid < donchian_period + 2)
      return;

   double hh = -DBL_MAX, ll = DBL_MAX;
   // Prior `donchian_period` closed bars EXCLUDING the breakout bar (shift 1):
   // use shifts 2 .. donchian_period+1.
   for(int s = 2; s <= donchian_period + 1; ++s)
     {
      const double h = iHigh(_Symbol, _Period, s);   // perf-allowed: closed-bar Donchian
      const double l = iLow(_Symbol, _Period, s);    // perf-allowed: closed-bar Donchian
      if(h > hh) hh = h;
      if(l < ll) ll = l;
     }
   g_donchian_high = hh;
   g_donchian_low  = ll;
  }

// Called ONCE per new closed bar (after OnTick passes QM_IsNewBar()).
void AdvanceState_OnNewBar()
  {
   const datetime cur_open = iTime(_Symbol, _Period, 0);   // perf-allowed: bar stamp
   if(!g_state_ready)
     {
      OBV_RebuildRing();
     }
   else if(cur_open != g_last_bar_seen)
     {
      OBV_AdvanceOneBar();
      g_last_bar_seen = cur_open;
     }

   g_atr_cached = QM_ATR(_Symbol, _Period, atr_period, 1);
   Recompute_Donchian();
   OBV_BuildTrendline(true,  g_obv_desc_line, g_desc_line_ok);  // descending swing-high line (long gate)
   OBV_BuildTrendline(false, g_obv_asc_line,  g_asc_line_ok);   // ascending  swing-low  line (short gate)
  }

// True if OBV closed above its descending line on shift 1 or within the last
// `obv_break_recent_bars` bars (states across shifts 1..1+recent).
bool OBV_BrokeAboveDescending()
  {
   if(!g_desc_line_ok)
      return false;
   int rb = obv_break_recent_bars;
   if(rb > 2) rb = 2;            // we only cache 3 line shifts
   for(int sh = 1; sh <= 1 + rb; ++sh)
      if(g_obv[sh] > g_obv_desc_line[sh])
         return true;
   return false;
  }

bool OBV_BrokeBelowAscending()
  {
   if(!g_asc_line_ok)
      return false;
   int rb = obv_break_recent_bars;
   if(rb > 2) rb = 2;
   for(int sh = 1; sh <= 1 + rb; ++sh)
      if(g_obv[sh] < g_obv_asc_line[sh])
         return true;
   return false;
  }

double OBV_Slope()
  {
   const int back = 1 + obv_slope_bars;
   if(g_obv_valid < back)
      return 0.0;
   return g_obv[1] - g_obv[back];
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;                 // no valid quote yet — do not block

   if(g_atr_cached <= 0.0)
      return false;                 // no ATR yet — defer to entry gate

   const double stop_distance = sl_atr_mult * g_atr_cached;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). Reads only
// cached state + current quotes.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_state_ready)
      return false;
   if(g_atr_cached <= 0.0)
      return false;
   if(g_donchian_high <= 0.0 || g_donchian_low <= 0.0)
      return false;

   // Donchian range-height filter (channel width within [min,max] * ATR).
   const double range_height = g_donchian_high - g_donchian_low;
   if(range_height < range_min_atr * g_atr_cached)
      return false;
   if(range_height > range_max_atr * g_atr_cached)
      return false;

   const double close1 = g_close_ring[1];
   if(close1 <= 0.0)
      return false;

   const double break_buffer = price_break_atr_mult * g_atr_cached;
   const double slope = OBV_Slope();

   // --- LONG ---
   if(close1 > g_donchian_high + break_buffer &&
      OBV_BrokeAboveDescending() &&
      slope > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL anchored at the breakout LEVEL (Donchian high) minus 0.75*ATR.
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                            g_donchian_high - sl_atr_mult * g_atr_cached);
      if(sl <= 0.0 || sl >= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "obv_tl_break_long";
      return true;
     }

   // --- SHORT ---
   if(close1 < g_donchian_low - break_buffer &&
      OBV_BrokeBelowAscending() &&
      slope < 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol,
                            g_donchian_low + sl_atr_mult * g_atr_cached);
      if(sl <= 0.0 || sl <= entry)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "obv_tl_break_short";
      return true;
     }

   return false;
  }

// Latch the entry bar-open time once a position is live (for the time exit).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_entry_bar_time = 0;
      return;
     }
   if(g_entry_bar_time != 0)
      return;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      g_entry_bar_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
  }

// Discretionary exits: (1) time exit after time_exit_bars H1 bars;
// (2) early exit when price closed back inside Donchian AND OBV closed back
// across the broken trendline. Evaluated on the closed bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_state_ready)
      return false;

   // Determine the live direction.
   bool is_long = false, found = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   // (1) Time exit — count closed H1 bars since entry.
   if(g_entry_bar_time > 0 && time_exit_bars > 0)
     {
      const int bars_since = iBarShift(_Symbol, _Period, g_entry_bar_time, false); // perf-allowed: age check
      if(bars_since >= time_exit_bars)
         return true;
     }

   // (2) Early structural exit.
   const double close1 = g_close_ring[1];
   if(close1 <= 0.0 || g_donchian_high <= 0.0 || g_donchian_low <= 0.0)
      return false;

   if(is_long)
     {
      const bool back_inside = (close1 < g_donchian_high);
      const bool obv_recross  = (g_desc_line_ok && g_obv[1] < g_obv_desc_line[1]);
      if(back_inside && obv_recross)
         return true;
     }
   else
     {
      const bool back_inside = (close1 > g_donchian_low);
      const bool obv_recross  = (g_asc_line_ok && g_obv[1] > g_obv_asc_line[1]);
      if(back_inside && obv_recross)
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

   g_state_ready   = false;
   g_obv_valid     = 0;
   g_last_bar_seen = 0;
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

   // Closed-bar work: advance OBV/Donchian/trendline state ONCE per new bar,
   // then evaluate exit + entry on that fresh closed bar.
   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

   QM_EquityStreamOnNewBar();

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

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
         g_entry_bar_time = iTime(_Symbol, _Period, 0);
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
