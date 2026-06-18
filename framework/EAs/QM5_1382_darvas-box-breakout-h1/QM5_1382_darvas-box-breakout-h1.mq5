#property strict
#property version   "5.0"
#property description "QM5_1382 darvas-box-breakout-h1 — Nicolas Darvas defended-box consolidation breakout (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1382 darvas-box-breakout-h1
// -----------------------------------------------------------------------------
// Source: Nicolas Darvas "How I Made $2,000,000 in the Stock Market" (1960,
//   Citadel 2007, ISBN 978-0-8065-1894-9) + ForexFactory Darvas-cluster FX
//   adaptation. Card: artifacts/cards_approved/QM5_1382_darvas-box-breakout-h1.md
//   (g0_status APPROVED). frontmatter ea_id reads QM5_12165 (stale); BUILD
//   TARGET ea_id = 1382 per build prompt — qm_ea_id is set to 1382 below and
//   the mismatch is flagged in the build_result.
//
// THE DARVAS PRIMITIVE — box is a STATE, breakout is the single EVENT:
//   A "box" forms when a swing extreme HOLDS, i.e. the most-recent 12 closed
//   bars stayed strictly INSIDE [box_bottom, box_top] (both extremes are "stale"
//   / "no longer attacked"). The box is reconstructed statelessly on the
//   just-closed bar from the 24-bar window BEFORE the breakout bar. The single
//   trigger is the breakout of the box top (BUY) or bottom (SELL) on the
//   just-closed bar's close.
//
// All reads on CLOSED bars. Under the framework new-bar gate the just-closed
// (breakout) bar = shift 1; the box-construction window is the 24 bars BEFORE
// it = shift 2..25. The 12-bar defended-window is shift 2..13.
//
//   Box construction (window W=24 over shift 2..25):
//     box_top    = max(high[2..25]),  box_bottom = min(low[2..25])
//     j_top/j_bot = age (shift) of the extreme bar; must be >= 13 (i.e. NOT in
//                   the recent 12-bar defended window) -> extreme is "stale".
//     width gate : 0.4*ATR(14,D1) <= (box_top-box_bottom) <= 1.5*ATR(14,D1)
//     defended   : for ALL k in [2..13]: high[k] < box_top AND low[k] > box_bottom
//     stillness  : for ALL k in [2..13]: |mid_price[k]-box_mid| <= 0.6*box_height
//                  (the 12 inside bars used at most 60% of box height each side)
//
//   Entry — BUY (upside breakout), on the just-closed bar (shift 1):
//     EVENT  breakout : close[1] > box_top + buffer_atr*ATR(14,H1)
//     STATE  strength : body_ratio[1] >= 0.45 AND range[1] >= 0.8*ATR(14,H1)
//     guard  re-box   : (box_top,box_bottom) != last-broken box (one trade per box)
//     guard  cooldown : not within cooldown_bars after a SL hit on this symbol
//     guard  1-pos    : QM_TM_OpenPositionCount(magic) == 0
//   Entry — SELL: mirror (close[1] < box_bottom - buffer, bear strength).
//
//   Stop (initial, hard — only BE-ratchet + breakout-level trail tighten it):
//     BUY  = box_bottom - sl_buffer_atr*ATR(14,H1), capped sl_cap_atr*ATR away
//     SELL = box_top    + sl_buffer_atr*ATR(14,H1)
//   TP : entry +/- tp_mult * box_height (box-projected target)
//
//   Management (Strategy_ManageOpenPosition), box latched at entry time:
//     BE-ratchet : after +1.0*box_height favourable -> SL to entry
//     Trail      : after BE, SL trails up to box_top (BUY) / down to box_bottom (SELL)
//   Exit (Strategy_ExitSignal), on the closed bar:
//     Re-entry-into-box : BUY close[1] < box_top - reentry_atr*ATR -> close
//                         SELL close[1] > box_bottom + reentry_atr*ATR -> close
//     Time-stop : position held >= time_stop_bars H1 bars -> close
//
//   Session : no new entry 22:00-06:00 broker-time (low-liquidity false breaks).
//   Spread  : skip only a genuinely WIDE spread (fail-OPEN on .DWX zero spread).
//   News    : central two-axis framework filter (Strategy_NewsFilterHook defers).
//
// Only the 5 Strategy_* hooks + Strategy inputs + the small file-scope box/guard
// state are EA-specific. Everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1382;
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
input int    strategy_lookback_bars      = 24;   // box window W (bars before breakout) — P3 18-30
input int    strategy_defended_bars      = 12;   // defended/stillness window (recent bars inside box)
input int    strategy_atr_period         = 14;   // H1 ATR period (SL/buffers/strength)
input int    strategy_d1_atr_period      = 14;   // D1 ATR period (box-width gate)
input double strategy_box_width_min_d1    = 0.4;  // box height >= this * ATR(14,D1)
input double strategy_box_width_max_d1    = 1.5;  // box height <= this * ATR(14,D1)
input double strategy_stillness_frac      = 0.6;  // inside bars stay within this * height of box mid
input double strategy_breakout_buf_atr    = 0.2;  // breakout buffer = this * ATR(14,H1)
input double strategy_body_ratio_min      = 0.45; // breakout-bar body/range minimum
input double strategy_range_atr_min       = 0.8;  // breakout-bar range >= this * ATR(14,H1)
input double strategy_sl_buffer_atr       = 0.3;  // initial SL buffer = this * ATR(14,H1) — P3 0.2-0.5
input double strategy_sl_cap_atr          = 2.5;  // cap initial SL distance to this * ATR(14,H1)
input double strategy_tp_box_mult         = 1.5;  // TP = entry +/- this * box height — P3 1.0-2.5
input double strategy_be_box_mult         = 1.0;  // BE ratchet after +this * box height favourable
input double strategy_reentry_atr         = 0.3;  // failed-breakout re-entry-into-box buffer * ATR(14,H1)
input int    strategy_time_stop_bars      = 48;   // close after N H1 bars without TP/SL
input int    strategy_cooldown_bars       = 24;   // no new entry for N bars after a SL hit
input int    strategy_no_entry_start_hour = 22;   // no-new-entry window start (broker, inclusive)
input int    strategy_no_entry_end_hour   = 6;    // no-new-entry window end (broker, exclusive)
input double strategy_spread_pct_of_stop  = 30.0; // skip if spread > this % of stop distance (fail-OPEN)

// -----------------------------------------------------------------------------
// File-scope state.
//   Box latched at entry time so management/exit reference the box the trade was
//   opened on (not a re-derived current box). Re-box guard remembers the last
//   broken box so the same (top,bottom) cannot fire a second trade. Cooldown
//   counts H1 bars since the last SL-hit close.
// -----------------------------------------------------------------------------
double   g_open_box_top      = 0.0;   // box top of the live position
double   g_open_box_bottom   = 0.0;   // box bottom of the live position
double   g_open_box_height   = 0.0;
bool     g_be_done           = false; // BE ratchet already applied for live position
double   g_last_broken_top   = 0.0;   // re-box guard: last box that already produced a trade
double   g_last_broken_bottom= 0.0;
datetime g_cooldown_until    = 0;     // bar-open time until which new entries are suppressed
double   g_last_equity       = 0.0;   // to detect SL/loss closes for cooldown arming
bool     g_had_position      = false; // previous-tick position presence (close detector)

// -----------------------------------------------------------------------------
// Box reconstruction (stateless, closed-bar). Fills out_* and returns true iff a
// valid defended Darvas box exists over the window BEFORE the breakout bar.
//   br = breakout-bar shift (1 = just-closed bar). Window = [br+1 .. br+W].
//   Defended/stillness window = the `defended` bars immediately before the
//   breakout bar = [br+1 .. br+defended].
// -----------------------------------------------------------------------------
bool BuildBox(const int br, double &out_top, double &out_bottom, double &out_height)
  {
   out_top = 0.0; out_bottom = 0.0; out_height = 0.0;

   const int W   = strategy_lookback_bars;
   const int DEF = strategy_defended_bars;
   if(W < DEF + 1 || DEF < 1)
      return false;

   const int win_start = br + 1;          // first bar of construction window
   const int win_end   = br + W;          // last bar of construction window (oldest)

   // --- box extremes + their age (shift) over the window. ---
   double box_top = -DBL_MAX, box_bottom = DBL_MAX;
   int    j_top = -1, j_bot = -1;
   for(int i = win_start; i <= win_end; ++i)
     {
      const double h = iHigh(_Symbol, _Period, i); // perf-allowed
      const double l = iLow(_Symbol, _Period, i);  // perf-allowed
      if(h <= 0.0 || l <= 0.0)
         return false;
      if(h > box_top)    { box_top = h;    j_top = i; }
      if(l < box_bottom) { box_bottom = l; j_bot = i; }
     }
   if(box_top <= 0.0 || box_bottom <= 0.0 || box_top <= box_bottom)
      return false;

   // --- both extremes must be "stale": outside the recent defended window. ---
   // j_top/j_bot are shifts; the defended window is [win_start .. br+DEF].
   if(j_top < win_start + DEF || j_bot < win_start + DEF)
      return false;

   const double height = box_top - box_bottom;

   // --- box-width gate vs daily ATR. ---
   const double atr_d1 = QM_ATR(_Symbol, PERIOD_D1, strategy_d1_atr_period, 1);
   if(atr_d1 <= 0.0)
      return false;
   if(height < strategy_box_width_min_d1 * atr_d1 || height > strategy_box_width_max_d1 * atr_d1)
      return false;

   // --- defended + stillness check over the recent DEF bars. ---
   const double box_mid    = 0.5 * (box_top + box_bottom);
   const double still_band = strategy_stillness_frac * height;
   for(int k = win_start; k <= win_start + DEF - 1; ++k)
     {
      const double hk = iHigh(_Symbol, _Period, k);  // perf-allowed
      const double lk = iLow(_Symbol, _Period, k);   // perf-allowed
      const double ck = iClose(_Symbol, _Period, k); // perf-allowed
      if(hk <= 0.0 || lk <= 0.0 || ck <= 0.0)
         return false;
      // defended: recent bars stayed strictly inside the box.
      if(hk >= box_top || lk <= box_bottom)
         return false;
      // stillness: bar median within still_band of the box midpoint.
      const double mid_k = 0.5 * (hk + lk);
      if(MathAbs(mid_k - box_mid) > still_band)
         return false;
     }

   out_top = box_top; out_bottom = box_bottom; out_height = height;
   return true;
  }

// Breakout-bar strength: body ratio + range vs ATR. Reads the breakout bar (br).
bool BreakoutBarStrong(const int br, const double atr_h1)
  {
   const double o = iOpen(_Symbol, _Period, br);  // perf-allowed
   const double c = iClose(_Symbol, _Period, br); // perf-allowed
   const double h = iHigh(_Symbol, _Period, br);  // perf-allowed
   const double l = iLow(_Symbol, _Period, br);   // perf-allowed
   if(o <= 0.0 || c <= 0.0 || h <= 0.0 || l <= 0.0)
      return false;
   const double range = h - l;
   if(range <= 0.0)
      return false;
   const double body = MathAbs(c - o);
   if((body / range) < strategy_body_ratio_min)
      return false;
   if(range < strategy_range_atr_min * atr_h1)
      return false;
   return true;
  }

// Latch the box of the live position direction into file-scope for mgmt/exit.
void LatchOpenBox(const double box_top, const double box_bottom, const double height)
  {
   g_open_box_top    = box_top;
   g_open_box_bottom = box_bottom;
   g_open_box_height = height;
   g_be_done         = false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: no-entry overnight window (broker) + wide-spread guard.
// Returns TRUE to BLOCK. Fail-OPEN on .DWX zero/negative modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- No-new-entry window 22:00-06:00 broker-time (wrap window). ---
   MqlDateTime bt;
   TimeToStruct(TimeCurrent(), bt);
   const int s = strategy_no_entry_start_hour;
   const int e = strategy_no_entry_end_hour;
   if(s <= e)
     {
      if(bt.hour >= s && bt.hour < e)
         return true;
     }
   else
     {
      // wrap-around (e.g. 22..06): blocked if hour>=s OR hour<e.
      if(bt.hour >= s || bt.hour < e)
         return true;
     }

   // --- Wide-spread guard relative to ATR-scaled stop distance (fail-OPEN). ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, never block on zero price

   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;
   const double stop_distance = strategy_sl_cap_atr * atr_h1;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread

   return false; // .DWX zero spread -> never blocked
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Cooldown after a SL hit on this symbol.
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed (current bar open)
   if(g_cooldown_until > 0 && bar_open < g_cooldown_until)
      return false;

   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;

   // Breakout bar = just-closed bar (shift 1). Box from the 24 bars before it.
   const int br = 1;
   double box_top, box_bottom, height;
   if(!BuildBox(br, box_top, box_bottom, height))
      return false;

   // Re-box guard: the same box (top,bottom) must not produce a second trade.
   // A new box (different extremes) is required after a break.
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double eps   = (point > 0.0) ? point : 0.0000001;
   if(g_last_broken_top > 0.0 && g_last_broken_bottom > 0.0 &&
      MathAbs(box_top - g_last_broken_top) < eps &&
      MathAbs(box_bottom - g_last_broken_bottom) < eps)
      return false;

   const double close_brk = iClose(_Symbol, _Period, br); // perf-allowed
   if(close_brk <= 0.0)
      return false;
   const double buf = strategy_breakout_buf_atr * atr_h1;

   // ---------------------------- BUY (upside break) ----------------------------
   if(close_brk > box_top + buf && BreakoutBarStrong(br, atr_h1))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Initial SL = box_bottom - buffer, capped to sl_cap_atr * ATR away.
      double sl = box_bottom - strategy_sl_buffer_atr * atr_h1;
      const double max_dist = strategy_sl_cap_atr * atr_h1;
      if(entry - sl > max_dist)
         sl = entry - max_dist;
      const double tp = entry + strategy_tp_box_mult * height;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry || tp <= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "darvas_box_break_long";
      LatchOpenBox(box_top, box_bottom, height);
      g_last_broken_top = box_top; g_last_broken_bottom = box_bottom;
      return true;
     }

   // ---------------------------- SELL (downside break) -------------------------
   if(close_brk < box_bottom - buf && BreakoutBarStrong(br, atr_h1))
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = box_top + strategy_sl_buffer_atr * atr_h1;
      const double max_dist = strategy_sl_cap_atr * atr_h1;
      if(sl - entry > max_dist)
         sl = entry + max_dist;
      const double tp = entry - strategy_tp_box_mult * height;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= entry || tp >= entry || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "darvas_box_break_short";
      LatchOpenBox(box_top, box_bottom, height);
      g_last_broken_top = box_top; g_last_broken_bottom = box_bottom;
      return true;
     }

   return false;
  }

// Management: BE ratchet after +1.0 box-height favourable, then trail SL to the
// breakout level (box_top for BUY / box_bottom for SELL). Only ever tightens.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;
   if(g_open_box_height <= 0.0)
      return; // no latched box (e.g. position pre-existing across restart)

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long   ptype  = PositionGetInteger(POSITION_TYPE);
      const double entry  = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0) return;
         // BE ratchet.
         if(!g_be_done && bid - entry >= strategy_be_box_mult * g_open_box_height)
           {
            const double be = QM_StopRulesNormalizePrice(_Symbol, entry);
            if(be > cur_sl)
               QM_TM_MoveSL(ticket, be, "darvas_be_ratchet");
            g_be_done = true;
           }
         // Trail to breakout level (box_top) after BE — only ratchets up.
         if(g_be_done)
           {
            const double trail = QM_StopRulesNormalizePrice(_Symbol, g_open_box_top);
            if(trail > cur_sl && trail < bid)
               QM_TM_MoveSL(ticket, trail, "darvas_trail_breakout");
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0) return;
         if(!g_be_done && entry - ask >= strategy_be_box_mult * g_open_box_height)
           {
            const double be = QM_StopRulesNormalizePrice(_Symbol, entry);
            if(cur_sl <= 0.0 || be < cur_sl)
               QM_TM_MoveSL(ticket, be, "darvas_be_ratchet");
            g_be_done = true;
           }
         if(g_be_done)
           {
            const double trail = QM_StopRulesNormalizePrice(_Symbol, g_open_box_bottom);
            if((cur_sl <= 0.0 || trail < cur_sl) && trail > ask)
               QM_TM_MoveSL(ticket, trail, "darvas_trail_breakout");
           }
        }
      break;
     }
  }

// Discretionary exits on the closed bar:
//   - Failed breakout: price falls back INTO the box by > reentry_atr*ATR.
//   - Time-stop: position held >= time_stop_bars H1 bars.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(g_open_box_top <= 0.0 || g_open_box_bottom <= 0.0)
      return false;

   bool     is_long = false, is_short = false;
   datetime open_time = 0;
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
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(!is_long && !is_short)
      return false;

   // --- Time-stop. ---
   const datetime bar_open = iTime(_Symbol, _Period, 0); // perf-allowed
   if(open_time > 0 && bar_open > open_time)
     {
      const int secs = PeriodSeconds(_Period);
      if(secs > 0 && (int)((bar_open - open_time) / secs) >= strategy_time_stop_bars)
         return true;
     }

   // --- Failed-breakout re-entry-into-box. ---
   const double close_sig = iClose(_Symbol, _Period, 1); // perf-allowed
   if(close_sig <= 0.0)
      return false;
   const double atr_h1 = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_h1 <= 0.0)
      return false;
   const double reentry = strategy_reentry_atr * atr_h1;

   if(is_long)
      return (close_sig < g_open_box_top - reentry);
   // is_short
   return (close_sig > g_open_box_bottom + reentry);
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

   g_last_equity = AccountInfoDouble(ACCOUNT_EQUITY);
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

   // Per-tick: trade management (BE ratchet + breakout-level trail).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (failed-breakout / time-stop).
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

   // --- Detect a just-closed position; arm cooldown if it closed at a loss. ---
   const int    magic   = QM_FrameworkMagic();
   const bool   has_pos = (QM_TM_OpenPositionCount(magic) > 0);
   const double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_had_position && !has_pos)
     {
      // Position closed since last new bar. If equity fell, treat as a SL/loss
      // and arm the cooldown for strategy_cooldown_bars H1 bars.
      if(equity < g_last_equity)
        {
         const int secs = PeriodSeconds(_Period);
         g_cooldown_until = iTime(_Symbol, _Period, 0) + (datetime)(strategy_cooldown_bars * secs);
        }
      // Reset latched box state once flat.
      g_open_box_top = 0.0; g_open_box_bottom = 0.0; g_open_box_height = 0.0;
      g_be_done = false;
     }
   g_had_position = has_pos;
   g_last_equity  = equity;

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
