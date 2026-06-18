#property strict
#property version   "5.0"
#property description "QM5_1388 Brooks Micro-Channel Failed-Test Reversal H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1388 Brooks Micro-Channel Failed-Test (Failed-Breakout) Reversal (H1)
// -----------------------------------------------------------------------------
// STATE  : a tight Brooks micro-channel completed on a recent 8-bar window
//          (8 same-direction bars, monotone stop-side, range <= 1.8*ATR, rising/
//          falling slope) that then BROKE OUT past its own extreme but FAILED to
//          extend a full 1.0*ATR before re-entering the channel.
// EVENT  : ONE trigger per detected failed-test — the current closed reversal bar
//          [1] is a counter-direction bar (body >= 0.45*range) that closes back
//          INSIDE the original channel, with bar-2 confirmation and a macro-bias
//          (SMA-50) gate. The micro-channel + failed breakout is the STATE; the
//          reversal-bar close back inside the channel is the single EVENT. Entry
//          is a market order at the H1 close of bar[1] (fade the failed breakout).
// EXIT   : hard SL at the failed-test breakout extreme +/- 0.3*ATR; TP at
//          entry +/- 2.0*ATR; a bar-3 invalidation (the failed extreme is
//          re-broken within 3 bars of entry => flatten); a 24-bar time stop; and
//          a Brooks break-even / lock-half trail (BE-0.1*ATR after 1.0*ATR,
//          entry+/-0.75*ATR after 1.5*ATR).
// FILTERS: fail-OPEN spread guard, broker-time session window (07:00-20:00, no
//          Friday entries after 18:00), volatility floor + shock-spike guard, a
//          per-channel failed-test re-use guard, and a 4-trades/symbol/week cap.
//          News handled centrally via the framework two-axis filter.
//
// .DWX invariants honoured: fail-OPEN spread guard, NO swap gate, prior-CLOSE
// (gapless) tests only, single QM_IsNewBar consume per OnTick, one position per
// magic, RISK_FIXED in tester, all logic in-EA (no ML).
//
// Card: QM5_1388_brooks-micro-channel-failed-test-h1 (build ea_id=1388).
// NOTE: card frontmatter ea_id=QM5_12167 is STALE; build target ea_id is 1388
//       per the build assignment — qm_ea_id is set to 1388 here.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1388;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf            = PERIOD_H1;
input int    strategy_channel_len            = 8;     // bars in the micro-channel window (W)
input int    strategy_atr_period             = 14;
input int    strategy_sma_period             = 50;    // macro-bias gate
input double strategy_channel_tol_atr        = 1.8;   // tight micro-channel: 8-bar range <= tol*ATR
input double strategy_failed_test_atr         = 1.0;   // breakout must fail to extend a full 1.0*ATR
input double strategy_body_ratio_min         = 0.45;  // reversal bar body >= 0.45 * range
input int    strategy_form_min_back          = 3;     // channel completed 3..10 bars before bar[1]
input int    strategy_form_max_back          = 10;
input int    strategy_breakout_max_back      = 3;     // breakout bar j in {2..3}
input double strategy_tp_atr_mult            = 2.0;   // TP = entry +/- 2.0*ATR
input double strategy_sl_atr_buffer          = 0.30;  // SL = failed extreme +/- 0.3*ATR
input int    strategy_invalidation_bars      = 3;     // bar-3 re-break invalidation window
input int    strategy_time_stop_bars         = 24;    // ~1 trading day
input double strategy_be_trigger_atr         = 1.0;   // move SL to BE-0.1*ATR after 1.0*ATR move
input double strategy_be_buffer_atr          = 0.10;
input double strategy_lock_trigger_atr       = 1.5;   // lock half after 1.5*ATR move
input double strategy_lock_atr               = 0.75;  // ... SL to entry +/- 0.75*ATR
input double strategy_vol_floor_ratio        = 0.70;  // ATR[1] >= ratio * ATR[20]
input int    strategy_vol_floor_back         = 20;
input double strategy_vol_spike_ratio        = 2.50;  // skip if ATR[1] > ratio * ATR[60]
input int    strategy_vol_spike_back         = 60;
input int    strategy_reuse_guard_bars       = 24;    // no re-entry on same channel for N bars
input int    strategy_weekly_trade_cap       = 4;     // max failed-test trades / symbol / week
input int    strategy_session_start_hour     = 7;     // broker-time entry window start
input int    strategy_session_end_hour       = 20;    // broker-time entry window end (exclusive)
input int    strategy_friday_no_entry_hour   = 18;    // no new Friday entries from this hour
input double strategy_spread_mult            = 2.0;   // fail-OPEN: block only spread > mult*median
input int    strategy_spread_lookback        = 20;

// -----------------------------------------------------------------------------
// File-scope state
// -----------------------------------------------------------------------------
double   g_median_spread_points   = 0.0;
bool     g_new_bar                = false;   // latched QM_IsNewBar() for this tick

ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;       // +1 buy / -1 sell
double   g_atr_at_entry           = 0.0;     // ATR captured at fill (for trail math)
double   g_failed_extreme         = 0.0;     // breakout extreme (bar j) of the live trade
datetime g_entry_bar_time         = 0;       // open time of the entry bar
bool     g_be_done                = false;   // break-even step applied
bool     g_lock_done              = false;   // lock-half step applied

datetime g_last_channel_origin    = 0;       // bar time of last traded channel's oldest bar
int      g_reuse_guard_remaining  = 0;       // bars left before the same channel may re-trade

// Rolling weekly trade-count window: timestamps of recent fills.
datetime g_recent_fills[];

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double LowestLowRange(const int first_shift, const int count)
  {
   double low = DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      low = MathMin(low, iLow(_Symbol, strategy_tf, shift)); // perf-allowed: bounded structural swing-low scan
   return low;
  }

double HighestHighRange(const int first_shift, const int count)
  {
   double high = -DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      high = MathMax(high, iHigh(_Symbol, strategy_tf, shift)); // perf-allowed: bounded structural swing-high scan
   return high;
  }

void RefreshSpreadMedian()
  {
   double spreads[];
   ArrayResize(spreads, strategy_spread_lookback);
   int n = 0;
   for(int shift = 1; shift <= strategy_spread_lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, strategy_tf, shift);
      if(spread > 0)
        {
         spreads[n] = (double)spread;
         n++;
        }
     }

   if(n <= 0)
     {
      g_median_spread_points = 0.0;
      return;
     }

   ArrayResize(spreads, n);
   ArraySort(spreads);
   if((n % 2) == 1)
      g_median_spread_points = spreads[n / 2];
   else
      g_median_spread_points = 0.5 * (spreads[n / 2 - 1] + spreads[n / 2]);
  }

// Count fills inside the trailing 7-day window; prune older entries in place.
int RecentWeeklyTradeCount(const datetime now)
  {
   const datetime cutoff = now - 7 * 24 * 60 * 60;
   int write = 0;
   const int total = ArraySize(g_recent_fills);
   for(int i = 0; i < total; ++i)
     {
      if(g_recent_fills[i] >= cutoff)
        {
         g_recent_fills[write] = g_recent_fills[i];
         write++;
        }
     }
   if(write != total)
      ArrayResize(g_recent_fills, write);
   return write;
  }

void RegisterFill(const datetime when)
  {
   const int n = ArraySize(g_recent_fills);
   ArrayResize(g_recent_fills, n + 1);
   g_recent_fills[n] = when;
  }

// Selects this EA's open position (single position per magic, HR14).
bool SelectOurPosition(ulong &ticket, int &direction, double &open_price,
                       double &sl, double &tp, datetime &open_time)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      direction = (ptype == POSITION_TYPE_BUY) ? 1 : -1;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      sl = PositionGetDouble(POSITION_SL);
      tp = PositionGetDouble(POSITION_TP);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Refresh the cached lifecycle state; arm the per-channel re-use guard on close.
void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0, sl = 0.0, tp = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
        }
      return;
     }

   // No live position. If we were tracking one, it just closed.
   if(g_active_ticket != 0)
     {
      g_reuse_guard_remaining = MathMax(strategy_reuse_guard_bars, 0);
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_atr_at_entry = 0.0;
   g_failed_extreme = 0.0;
   g_entry_bar_time = 0;
   g_be_done = false;
   g_lock_done = false;
  }

// -----------------------------------------------------------------------------
// Micro-channel detection (STATE).
// Checks for a valid bullish (dir=+1) or bearish (dir=-1) micro-channel whose
// 8-bar window is [origin_shift .. origin_shift + len - 1] (origin_shift = the
// most-recent bar of the channel). Fills mc_high / mc_low when valid.
// -----------------------------------------------------------------------------
bool DetectMicroChannelAt(const int dir, const int origin_shift,
                          const double atr, double &mc_high, double &mc_low)
  {
   const int len = strategy_channel_len;
   if(len < 2 || atr <= 0.0)
      return false;

   const int oldest = origin_shift + len - 1;

   mc_high = -DBL_MAX;
   mc_low  =  DBL_MAX;

   // Walk shifts origin_shift (newest channel bar) .. oldest.
   for(int s = origin_shift; s <= oldest; ++s)
     {
      const double o = iOpen(_Symbol, strategy_tf, s);  // perf-allowed: fixed closed-bar OHLC structural pattern
      const double c = iClose(_Symbol, strategy_tf, s);  // perf-allowed
      const double h = iHigh(_Symbol, strategy_tf, s);   // perf-allowed
      const double l = iLow(_Symbol, strategy_tf, s);    // perf-allowed
      const double range = h - l;
      if(range <= 0.0)
         return false;

      // (1) all bars same-direction.
      if(dir > 0 && !(c > o))
         return false;
      if(dir < 0 && !(c < o))
         return false;

      mc_high = MathMax(mc_high, h);
      mc_low  = MathMin(mc_low, l);

      // (2) monotone stop-side vs the older neighbour (shift s+1).
      if(s < oldest)
        {
         const double l_prev = iLow(_Symbol, strategy_tf, s + 1);  // perf-allowed
         const double h_prev = iHigh(_Symbol, strategy_tf, s + 1); // perf-allowed
         // bull: each low at/above the preceding (older) bar's low.
         if(dir > 0 && !(l >= l_prev))
            return false;
         // bear: each high at/below the preceding (older) bar's high.
         if(dir < 0 && !(h <= h_prev))
            return false;
        }
     }

   // (3) tight range: 8-bar range <= tol * ATR.
   const double chan_range = mc_high - mc_low;
   if(chan_range <= 0.0 || chan_range > strategy_channel_tol_atr * atr)
      return false;

   // (4) range slope: rising (bull) / falling (bear) measured over the half-window.
   const int mid = origin_shift + (len / 2);
   const double swing_now  = (dir > 0) ? HighestHighRange(origin_shift, len / 2)
                                       : LowestLowRange(origin_shift, len / 2);
   const double swing_prev = (dir > 0) ? HighestHighRange(mid, len / 2)
                                       : LowestLowRange(mid, len / 2);
   if(dir > 0 && !(swing_now > swing_prev))
      return false;
   if(dir < 0 && !(swing_now < swing_prev))
      return false;

   return true;
  }

// -----------------------------------------------------------------------------
// Failed-test reversal detection (STATE + EVENT) for SELL (dir=-1 reversal, i.e.
// a failed BULLISH breakout) or BUY (dir=+1 reversal, failed BEARISH breakout).
// `rev_dir` is the trade direction: -1 SELL / +1 BUY.
// On success fills mc_high/mc_low (origin channel) and failed_extreme (breakout
// extreme of bar j) and origin_oldest_time (oldest channel bar time, for re-use
// guard).
// -----------------------------------------------------------------------------
bool DetectFailedTest(const int rev_dir, const double atr,
                      double &mc_high, double &mc_low,
                      double &failed_extreme, datetime &origin_oldest_time)
  {
   if(atr <= 0.0)
      return false;

   // The micro-channel is BULLISH for a SELL reversal, BEARISH for a BUY reversal.
   const int chan_dir = (rev_dir < 0) ? +1 : -1;
   const int len = strategy_channel_len;

   // Try each candidate "channel completed back" position. The channel's newest
   // bar sits `back` bars before bar[1]; i.e. origin_shift = back + 1, scanning
   // back in [form_min_back .. form_max_back].
   for(int back = strategy_form_min_back; back <= strategy_form_max_back; ++back)
     {
      const int origin_shift = back + 1;
      double ch_high = 0.0, ch_low = 0.0;
      if(!DetectMicroChannelAt(chan_dir, origin_shift, atr, ch_high, ch_low))
         continue;

      // Breakout bar j in {2 .. breakout_max_back+1}: a bar BETWEEN the channel
      // and bar[1] that pierced the channel extreme but failed to extend 1.0*ATR.
      // j must sit strictly newer than the channel's newest bar (j < origin_shift)
      // and within {2..breakout_max_back+1}.
      const int j_hi = MathMin(strategy_breakout_max_back + 1, origin_shift - 1);
      for(int j = 2; j <= j_hi; ++j)
        {
         if(chan_dir > 0)
           {
            // Failed BULLISH breakout: high[j] pierced channel top but < 1.0*ATR beyond.
            const double hj = iHigh(_Symbol, strategy_tf, j); // perf-allowed: structural breakout-bar extreme
            if(!(hj > ch_high))
               continue;
            if((hj - ch_high) >= strategy_failed_test_atr * atr)
               continue; // breakout extended too far — not a failed test
            failed_extreme = hj;
           }
         else
           {
            // Failed BEARISH breakout: low[j] pierced channel bottom but < 1.0*ATR beyond.
            const double lj = iLow(_Symbol, strategy_tf, j); // perf-allowed
            if(!(lj < ch_low))
               continue;
            if((ch_low - lj) >= strategy_failed_test_atr * atr)
               continue;
            failed_extreme = lj;
           }

         // Reversal bar[1]: counter-direction bar, body >= 0.45*range, closed back
         // inside the original channel.
         const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed: reversal-bar pattern
         const double c1 = iClose(_Symbol, strategy_tf, 1);  // perf-allowed
         const double h1 = iHigh(_Symbol, strategy_tf, 1);   // perf-allowed
         const double l1 = iLow(_Symbol, strategy_tf, 1);    // perf-allowed
         const double range1 = h1 - l1;
         if(range1 <= 0.0)
            continue;
         const double body1 = MathAbs(c1 - o1);
         if(body1 < strategy_body_ratio_min * range1)
            continue;

         const double o2 = iOpen(_Symbol, strategy_tf, 2);  // perf-allowed: bar-2 confirmation
         const double c2 = iClose(_Symbol, strategy_tf, 2);  // perf-allowed

         if(rev_dir < 0)
           {
            // SELL: bear reversal bar closing back inside (below the channel top).
            if(!(c1 < o1))
               continue;
            if(!(c1 < ch_high))
               continue;
            // Bar-2 confirmation: close below bar2 close AND bar2 open.
            if(!(c1 < c2 && c1 < o2))
               continue;
           }
         else
           {
            // BUY: bull reversal bar closing back inside (above the channel bottom).
            if(!(c1 > o1))
               continue;
            if(!(c1 > ch_low))
               continue;
            if(!(c1 > c2 && c1 > o2))
               continue;
           }

         mc_high = ch_high;
         mc_low  = ch_low;
         origin_oldest_time = iTime(_Symbol, strategy_tf, origin_shift + len - 1); // perf-allowed: channel-origin id
         return true;
        }
     }
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No Trade Filter — fail-OPEN spread guard + broker-time session windows +
// Friday late-entry cutoff. Cheap O(1)-ish per-tick checks.
bool Strategy_NoTradeFilter()
  {
   RefreshSpreadMedian();

   // Fail-OPEN spread guard: .DWX quotes 0 spread in the tester, so only block a
   // genuinely wide live spread; never reject on zero/median-absent spread.
   if(g_median_spread_points > 0.0 && strategy_spread_mult > 0.0)
     {
      const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if((double)current_spread > strategy_spread_mult * g_median_spread_points)
         return true;
     }

   // Broker-time session window: TimeCurrent() in the tester IS broker time.
   MqlDateTime bt;
   TimeToStruct(TimeCurrent(), bt);
   const int hour = bt.hour;

   // Enter only within [session_start .. session_end) broker-time.
   if(hour < strategy_session_start_hour || hour >= strategy_session_end_hour)
      return true;

   // Friday (day_of_week == 5): no new entries from friday_no_entry_hour.
   if(bt.day_of_week == 5 && hour >= strategy_friday_no_entry_hour)
      return true;

   return false;
  }

// Trade Entry — ONE event: a confirmed micro-channel failed-test reversal on the
// current closed bar[1]. Market order at the bar[1] close (framework fills at
// send price). SELL fades a failed bullish breakout; BUY fades a failed bearish
// breakout.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One position per magic (HR14).
   if(g_active_ticket != 0 || QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Per-channel failed-test re-use guard.
   if(g_reuse_guard_remaining > 0)
      return false;

   const double atr   = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double atr_floor = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, strategy_vol_floor_back);
   const double atr_spike = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, strategy_vol_spike_back);
   const double pip   = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   // Volatility floor: avoid dead markets.
   if(atr_floor > 0.0 && atr < strategy_vol_floor_ratio * atr_floor)
      return false;
   // Shock-spike guard: skip violent regimes.
   if(atr_spike > 0.0 && atr > strategy_vol_spike_ratio * atr_spike)
      return false;

   const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
   if(sma <= 0.0)
      return false;
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: macro-bias gate vs SMA

   // Weekly trade cap (per symbol).
   const datetime now = TimeCurrent();
   if(RecentWeeklyTradeCount(now) >= strategy_weekly_trade_cap)
      return false;

   double mc_high = 0.0, mc_low = 0.0, failed_extreme = 0.0;
   datetime origin_oldest = 0;

   // --- SELL: failed bullish micro-channel breakout (fade the failure).
   //     Macro-bias gate: close[1] < SMA(50) (downtrend / transition).
   if(c1 < sma && DetectFailedTest(-1, atr, mc_high, mc_low, failed_extreme, origin_oldest))
     {
      // Same-channel re-use guard (by channel-origin bar time).
      if(origin_oldest != 0 && origin_oldest == g_last_channel_origin && g_reuse_guard_remaining > 0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double sl = failed_extreme + strategy_sl_atr_buffer * atr; // above the failed extreme
      const double tp = entry - strategy_tp_atr_mult * atr;

      req.type = QM_SELL;
      req.price = 0.0; // market
      req.sl    = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp    = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "BROOKS_MC_FAILED_TEST_SELL_H1";

      g_atr_at_entry = atr;
      g_failed_extreme = failed_extreme;
      g_last_channel_origin = origin_oldest;
      return true;
     }

   // --- BUY: failed bearish micro-channel breakout (fade the failure).
   //     Macro-bias gate: close[1] > SMA(50) (uptrend / transition).
   if(c1 > sma && DetectFailedTest(+1, atr, mc_high, mc_low, failed_extreme, origin_oldest))
     {
      if(origin_oldest != 0 && origin_oldest == g_last_channel_origin && g_reuse_guard_remaining > 0)
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double sl = failed_extreme - strategy_sl_atr_buffer * atr; // below the failed extreme
      const double tp = entry + strategy_tp_atr_mult * atr;

      req.type = QM_BUY;
      req.price = 0.0; // market
      req.sl    = QM_TM_NormalizePrice(_Symbol, sl);
      req.tp    = QM_TM_NormalizePrice(_Symbol, tp);
      req.reason = "BROOKS_MC_FAILED_TEST_BUY_H1";

      g_atr_at_entry = atr;
      g_failed_extreme = failed_extreme;
      g_last_channel_origin = origin_oldest;
      return true;
     }

   return false;
  }

// Trade Management — Brooks break-even / lock-half steps (one-directional SL
// ratchet). After price moves 1.0*ATR in favour, SL -> break-even - 0.1*ATR.
// After 1.5*ATR, SL -> entry +/- 0.75*ATR (lock half the move). Steps recomputed
// per closed bar; SL only ever ratchets toward profit.
void Strategy_ManageOpenPosition()
  {
   if(g_active_ticket == 0 || g_atr_at_entry <= 0.0)
      return;
   if(!g_new_bar)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double cur_sl = PositionGetDouble(POSITION_SL);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   // Lock-half step takes priority (it is the tighter, later step).
   if(!g_lock_done && moved >= strategy_lock_trigger_atr * g_atr_at_entry)
     {
      const double new_sl = is_buy ? (open_price + strategy_lock_atr * g_atr_at_entry)
                                   : (open_price - strategy_lock_atr * g_atr_at_entry);
      bool ratchet = is_buy ? ((cur_sl <= 0.0 || new_sl > cur_sl) && new_sl < market)
                            : ((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > market);
      if(ratchet)
        {
         QM_TM_MoveSL(g_active_ticket, QM_TM_NormalizePrice(_Symbol, new_sl), "brooks_ft_lock_half");
         g_lock_done = true;
         g_be_done = true;
        }
      return;
     }

   // Break-even step.
   if(!g_be_done && moved >= strategy_be_trigger_atr * g_atr_at_entry)
     {
      const double new_sl = is_buy ? (open_price - strategy_be_buffer_atr * g_atr_at_entry)
                                   : (open_price + strategy_be_buffer_atr * g_atr_at_entry);
      bool ratchet = is_buy ? ((cur_sl <= 0.0 || new_sl > cur_sl) && new_sl < market)
                            : ((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > market);
      if(ratchet)
        {
         QM_TM_MoveSL(g_active_ticket, QM_TM_NormalizePrice(_Symbol, new_sl), "brooks_ft_break_even");
         g_be_done = true;
        }
     }
  }

// Trade Close — (a) bar-3 invalidation: the failed-test extreme is re-broken
// within invalidation_bars of entry => the reversal failed, flatten; (b) 24-bar
// time stop. Both evaluated per closed bar.
bool Strategy_ExitSignal()
  {
   if(g_active_ticket == 0)
      return false;
   if(!g_new_bar)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);

   // (a) Bar-3 invalidation: within the first `invalidation_bars` closed bars after
   //     entry, if any of those bars re-broke the failed-test extreme, flatten.
   if(g_failed_extreme > 0.0 && bars_since_open >= 1 && bars_since_open <= strategy_invalidation_bars)
     {
      for(int s = 1; s <= bars_since_open; ++s)
        {
         if(is_buy)
           {
            // BUY: invalidated if a bar's low re-broke below the failed (low) extreme.
            const double ls = iLow(_Symbol, strategy_tf, s); // perf-allowed: invalidation re-break check
            if(ls < g_failed_extreme)
               return true;
           }
         else
           {
            // SELL: invalidated if a bar's high re-broke above the failed (high) extreme.
            const double hs = iHigh(_Symbol, strategy_tf, s); // perf-allowed
            if(hs > g_failed_extreme)
               return true;
           }
        }
     }

   // (b) Time stop.
   if(bars_since_open >= strategy_time_stop_bars)
      return true;

   return false;
  }

// News Filter Hook — defer to the central two-axis filter (handled in OnTick),
// plus block if the reversal bar itself overlapped a high-impact event.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   const datetime bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar news overlap check
   if(bar_time > 0 && !QM_NewsAllowsTrade2(_Symbol, bar_time, qm_news_temporal, qm_news_compliance))
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
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

   ArrayResize(g_recent_fills, 0);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1388\",\"ea\":\"brooks-micro-channel-failed-test-h1\"}");
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

   // Single QM_IsNewBar consume per tick — latched for entry, trail and exit.
   g_new_bar = QM_IsNewBar(_Symbol, strategy_tf);

   // Per-closed-bar bookkeeping: lifecycle refresh + re-use guard countdown.
   RefreshPositionLifecycle();
   if(g_new_bar && g_reuse_guard_remaining > 0)
      g_reuse_guard_remaining--;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick trade management (SL ratchet only acts on new bars internally).
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

   if(!g_new_bar)
      return;

   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      if(QM_TM_OpenPosition(req, out_ticket))
        {
         g_entry_bar_time = iTime(_Symbol, strategy_tf, 0); // perf-allowed: entry-bar open-time id
         g_be_done = false;
         g_lock_done = false;
         RegisterFill(broker_now);
        }
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
