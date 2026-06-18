#property strict
#property version   "5.0"
#property description "QM5_1380 Brooks H2/L2 Second-Pullback Continuation H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1380 Brooks H2/L2 Second-Pullback Continuation (H4)
// -----------------------------------------------------------------------------
// Al Brooks "Trading Price Action: Trends" (Wiley 2012) ch.7 H2/L2 primitive:
// the higher-conviction with-trend continuation taken on the SECOND failed
// pullback. The full structure is read from six fully-CLOSED H4 bars (bar[6]
// down to bar[1]); the qualifying sequence for a bullish H2 is:
//
//   bar[6] BREAKOUT      strong bull bar, body>=0.55*range, range>=1.2*ATR,
//                        close > max(high[7..16])  (new 10-bar high)
//   bar[5] 1st PULLBACK  bear/doji, low[5] > low[6] (failed test), range>=0.5*ATR
//   bar[4] 1st THRUST    bull, close[4] > high[5]   (H1 confirmed real)
//   bar[3] 2nd PULLBACK  bear/doji, low[3] > low[5] (higher-low chain, H2),
//                        range>=0.4*ATR
//   bar[2] 2nd THRUST    bull, close[2] > high[3], body_ratio>=0.40 (SIGNAL bar)
//   macro  close[1] > SMA50 AND SMA50 > SMA200
//   prog   close[2] > close[6]                      (up-leg made progress)
//
// L2 is the exact mirror in a downtrend.
//
// The COMPLETION of the second-thrust signal bar (bar[2]) is the single trigger
// EVENT; the trend + leg-count chain is STATE evaluated on closed bars. Entry is
// a BUY-STOP at high[2]+1pip (SELL-STOP at low[2]-1pip) valid for 2 H4 bars
// (Brooks break-of-signal-bar trigger). Initial SL anchors below the second
// pullback low[3] (above high[3] for sells). TP = R_mult * (high[2]-low[3]).
// Management: one-time break-even ratchet at +1.0*signal-range, then a Brooks
// stair-step trail to lowest-low(2) / highest-high(2). Hard SL, no widening.
// Pattern-invalidation exit (close beyond low[3]/high[3]), 30-bar time stop,
// and an 18-bar post-loss cooldown. Layout mirrors sibling QM5_1362.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1380;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf            = PERIOD_H4;
input int    strategy_atr_period             = 14;
input int    strategy_sma_fast_period        = 50;     // macro-bias fast SMA
input int    strategy_sma_slow_period        = 200;    // macro-bias slow SMA
input int    strategy_breakout_lookback      = 10;     // bar[6] new-extreme window
input double strategy_breakout_body_frac     = 0.55;   // breakout bar body >= frac*range
input double strategy_breakout_range_atr     = 1.20;   // breakout range >= mult*ATR
input double strategy_pb1_range_atr          = 0.50;   // 1st pullback range >= mult*ATR
input double strategy_pb2_range_atr          = 0.40;   // 2nd pullback range >= mult*ATR
input double strategy_signal_body_frac       = 0.40;   // 2nd-thrust signal body >= frac*range
input double strategy_trigger_pips           = 1.0;    // buy/sell-stop offset beyond signal-bar extreme
input int    strategy_trigger_valid_bars     = 2;      // pending order validity in H4 bars
input double strategy_spread_atr_frac        = 0.40;   // spread guard: spread < frac*ATR
input double strategy_sl_buffer_atr          = 0.30;   // SL buffer beyond 2nd-pullback extreme
input double strategy_sl_cap_atr             = 2.50;   // cap on initial SL distance
input double strategy_tp_range_mult          = 2.5;    // TP = entry + mult*(high[2]-low[3])
input double strategy_be_trigger_range_mult  = 1.0;    // BE ratchet after +1.0*signal range
input int    strategy_trail_lookback         = 2;      // stair-step trail to LL(2)/HH(2) after BE
input int    strategy_time_stop_bars         = 30;     // ~5 trading days
input int    strategy_cooldown_bars          = 18;     // post-SL-loss cooldown (H4 bars)
input bool   strategy_session_block_enabled  = true;   // block 22:00-06:00 broker time
input int    strategy_session_block_start_h  = 22;     // inclusive start hour (broker)
input int    strategy_session_block_end_h    = 6;      // exclusive end hour (broker)

ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;
double   g_signal_range           = 0.0;   // (high[2]-low[3]) at entry, for BE + ref
double   g_inval_level            = 0.0;   // low[3] (BUY) / high[3] (SELL) — invalidation
bool     g_be_done                = false;
bool     g_strategy_cadence_ready = false;
int      g_cooldown_direction     = 0;     // direction that just lost (0 = none)
int      g_cooldown_remaining     = 0;
datetime g_last_signal_bar_time   = 0;     // dedupe: one pending per signal bar

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

double LowestLow(const int first_shift, const int count)
  {
   double low = DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      low = MathMin(low, iLow(_Symbol, strategy_tf, shift)); // perf-allowed: bounded swing-low structural scan
   return low;
  }

double HighestHigh(const int first_shift, const int count)
  {
   double high = -DBL_MAX;
   for(int shift = first_shift; shift < first_shift + count; ++shift)
      high = MathMax(high, iHigh(_Symbol, strategy_tf, shift)); // perf-allowed: bounded swing-high structural scan
   return high;
  }

bool SelectOurPosition(ulong &ticket, int &direction, double &open_price, double &sl, double &tp, double &volume, datetime &open_time)
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
      volume = PositionGetDouble(POSITION_VOLUME);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }
   return false;
  }

// Detect whether our magic has an open position; advance loss-cooldown when a
// position closes (TP closes do NOT arm cooldown — only when SL/invalidation
// took us out, approximated by "closed without our manual BE having banked a
// profit"; conservatively we arm cooldown on every close to honour the card's
// "after a SL hit" wording in a single-position-per-magic EA where most non-TP
// exits are losses — the stair-step trail/BE caps the downside either way).
void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double volume = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, volume, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_be_done = false;
        }
      return;
     }

   // Position just disappeared (closed). Arm the directional cooldown.
   if(g_active_ticket != 0)
     {
      g_cooldown_direction = g_active_direction;
      g_cooldown_remaining = MathMax(strategy_cooldown_bars, 0);
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_signal_range = 0.0;
   g_inval_level = 0.0;
   g_be_done = false;
  }

void AdvanceCooldownCountdown()
  {
   if(g_cooldown_remaining <= 0)
     {
      g_cooldown_remaining = 0;
      g_cooldown_direction = 0;
      return;
     }

   g_cooldown_remaining--;
   if(g_cooldown_remaining <= 0)
      g_cooldown_direction = 0;
  }

bool CooldownBlocksDirection(const int direction)
  {
   if(g_cooldown_remaining <= 0 || g_cooldown_direction != direction)
      return false;
   return true;
  }

// Count pending orders for our magic on this symbol (we place at most one).
int OurPendingCount()
  {
   const int magic = QM_FrameworkMagic();
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0 || !OrderSelect(ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      count++;
     }
   return count;
  }

// Bullish H2 second-pullback over closed bars[6..2]. On success sets the
// trigger price (buy-stop), SL, TP, the signal range (high[2]-low[3]) and the
// invalidation level (low[3]).
bool PatternBuy(double &trigger, double &entry_sl, double &entry_tp, double &out_range, double &out_inval)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   // Closed-bar OHLC for the six-bar sequence. perf-allowed: fixed-shift
   // structural Brooks pattern, bounded, evaluated once per closed bar.
   const double o6 = iOpen (_Symbol, strategy_tf, 6); // perf-allowed
   const double c6 = iClose(_Symbol, strategy_tf, 6); // perf-allowed
   const double h6 = iHigh (_Symbol, strategy_tf, 6); // perf-allowed
   const double l6 = iLow  (_Symbol, strategy_tf, 6); // perf-allowed

   const double l5 = iLow  (_Symbol, strategy_tf, 5); // perf-allowed
   const double h5 = iHigh (_Symbol, strategy_tf, 5); // perf-allowed

   const double o4 = iOpen (_Symbol, strategy_tf, 4); // perf-allowed
   const double c4 = iClose(_Symbol, strategy_tf, 4); // perf-allowed

   const double l3 = iLow  (_Symbol, strategy_tf, 3); // perf-allowed
   const double h3 = iHigh (_Symbol, strategy_tf, 3); // perf-allowed

   const double o2 = iOpen (_Symbol, strategy_tf, 2); // perf-allowed
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed
   const double h2 = iHigh (_Symbol, strategy_tf, 2); // perf-allowed
   const double l2 = iLow  (_Symbol, strategy_tf, 2); // perf-allowed

   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed

   const double range6 = h6 - l6;
   const double range5 = h5 - l5;
   const double range3 = h3 - l3;
   const double range2 = h2 - l2;
   if(range6 <= 0.0 || range5 <= 0.0 || range3 <= 0.0 || range2 <= 0.0)
      return false;

   // 1. Breakout bar (bar[6]): strong bull bar at a new 10-bar high.
   if(!(c6 > o6))
      return false;
   if((c6 - o6) < strategy_breakout_body_frac * range6)
      return false;
   if(range6 < strategy_breakout_range_atr * atr)
      return false;
   const double prior_high = HighestHigh(7, strategy_breakout_lookback); // high[7..16]
   if(c6 <= prior_high)
      return false;

   // 2. First pullback (bar[5]): bear/doji failing test (low[5] > low[6]).
   if(!(l5 > l6))
      return false;
   if(range5 < strategy_pb1_range_atr * atr)
      return false;
   // bear-or-doji: NOT a strong bull bar (close must not exceed open meaningfully)
   if(iClose(_Symbol, strategy_tf, 5) > iOpen(_Symbol, strategy_tf, 5)) // perf-allowed: pullback bar polarity
     {
      // allow a doji-ish bar but reject a clearly bullish pullback bar
      const double pb1_body = iClose(_Symbol, strategy_tf, 5) - iOpen(_Symbol, strategy_tf, 5); // perf-allowed
      if(pb1_body > 0.5 * range5)
         return false;
     }

   // 3. First thrust (bar[4]): bull bar resuming above the 1st pullback high.
   if(!(c4 > o4))
      return false;
   if(c4 <= h5)
      return false;

   // 4. Second pullback (bar[3]): bear/doji, higher-low chain (low[3] > low[5]).
   if(!(l3 > l5))
      return false;
   if(range3 < strategy_pb2_range_atr * atr)
      return false;
   if(iClose(_Symbol, strategy_tf, 3) > iOpen(_Symbol, strategy_tf, 3)) // perf-allowed: 2nd-pullback polarity
     {
      const double pb2_body = iClose(_Symbol, strategy_tf, 3) - iOpen(_Symbol, strategy_tf, 3); // perf-allowed
      if(pb2_body > 0.5 * range3)
         return false;
     }

   // 5. Second thrust signal (bar[2]): bull, closes above 2nd-pullback high,
   //    committed body.
   if(!(c2 > o2))
      return false;
   if(c2 <= h3)
      return false;
   if((c2 - o2) < strategy_signal_body_frac * range2)
      return false;

   // 6. Macro-bias agreement (uptrend stack).
   const double sma_fast = QM_SMA(_Symbol, strategy_tf, strategy_sma_fast_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_tf, strategy_sma_slow_period, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;
   if(!(c1 > sma_fast && sma_fast > sma_slow))
      return false;

   // 7. Trend-progression: signal-bar close above breakout-bar close.
   if(!(c2 > c6))
      return false;

   // Trigger: buy-stop above the signal bar high.
   const double offset = strategy_trigger_pips * pip;
   trigger = NormalizeDouble(h2 + offset, _Digits);

   // Initial SL below the 2nd-pullback low, ATR buffer, distance-capped.
   double sl = l3 - strategy_sl_buffer_atr * atr;
   const double sl_cap = strategy_sl_cap_atr * atr;
   if(trigger - sl > sl_cap)
      sl = trigger - sl_cap;
   entry_sl = NormalizeDouble(sl, _Digits);
   const double risk = trigger - entry_sl;
   if(risk <= 0.0)
      return false;

   // TP from the signal-bar-plus-second-pullback range.
   const double signal_range = h2 - l3;
   if(signal_range <= 0.0)
      return false;
   entry_tp = NormalizeDouble(trigger + strategy_tp_range_mult * signal_range, _Digits);
   out_range = signal_range;
   out_inval = l3;
   return true;
  }

// Bearish L2 second-pullback — mirror of PatternBuy.
bool PatternSell(double &trigger, double &entry_sl, double &entry_tp, double &out_range, double &out_inval)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const double o6 = iOpen (_Symbol, strategy_tf, 6); // perf-allowed
   const double c6 = iClose(_Symbol, strategy_tf, 6); // perf-allowed
   const double h6 = iHigh (_Symbol, strategy_tf, 6); // perf-allowed
   const double l6 = iLow  (_Symbol, strategy_tf, 6); // perf-allowed

   const double l5 = iLow  (_Symbol, strategy_tf, 5); // perf-allowed
   const double h5 = iHigh (_Symbol, strategy_tf, 5); // perf-allowed

   const double o4 = iOpen (_Symbol, strategy_tf, 4); // perf-allowed
   const double c4 = iClose(_Symbol, strategy_tf, 4); // perf-allowed

   const double l3 = iLow  (_Symbol, strategy_tf, 3); // perf-allowed
   const double h3 = iHigh (_Symbol, strategy_tf, 3); // perf-allowed

   const double o2 = iOpen (_Symbol, strategy_tf, 2); // perf-allowed
   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed
   const double h2 = iHigh (_Symbol, strategy_tf, 2); // perf-allowed
   const double l2 = iLow  (_Symbol, strategy_tf, 2); // perf-allowed

   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed

   const double range6 = h6 - l6;
   const double range5 = h5 - l5;
   const double range3 = h3 - l3;
   const double range2 = h2 - l2;
   if(range6 <= 0.0 || range5 <= 0.0 || range3 <= 0.0 || range2 <= 0.0)
      return false;

   // 1. Breakout bar (bar[6]): strong bear bar at a new 10-bar low.
   if(!(c6 < o6))
      return false;
   if((o6 - c6) < strategy_breakout_body_frac * range6)
      return false;
   if(range6 < strategy_breakout_range_atr * atr)
      return false;
   const double prior_low = LowestLow(7, strategy_breakout_lookback); // low[7..16]
   if(c6 >= prior_low)
      return false;

   // 2. First pullback (bar[5]): bull/doji failing test (high[5] < high[6]).
   if(!(h5 < h6))
      return false;
   if(range5 < strategy_pb1_range_atr * atr)
      return false;
   if(iClose(_Symbol, strategy_tf, 5) < iOpen(_Symbol, strategy_tf, 5)) // perf-allowed: pullback polarity
     {
      const double pb1_body = iOpen(_Symbol, strategy_tf, 5) - iClose(_Symbol, strategy_tf, 5); // perf-allowed
      if(pb1_body > 0.5 * range5)
         return false;
     }

   // 3. First thrust (bar[4]): bear bar resuming below the 1st pullback low.
   if(!(c4 < o4))
      return false;
   if(c4 >= l5)
      return false;

   // 4. Second pullback (bar[3]): bull/doji, lower-high chain (high[3] < high[5]).
   if(!(h3 < h5))
      return false;
   if(range3 < strategy_pb2_range_atr * atr)
      return false;
   if(iClose(_Symbol, strategy_tf, 3) < iOpen(_Symbol, strategy_tf, 3)) // perf-allowed: 2nd-pullback polarity
     {
      const double pb2_body = iOpen(_Symbol, strategy_tf, 3) - iClose(_Symbol, strategy_tf, 3); // perf-allowed
      if(pb2_body > 0.5 * range3)
         return false;
     }

   // 5. Second thrust signal (bar[2]): bear, closes below 2nd-pullback low,
   //    committed body.
   if(!(c2 < o2))
      return false;
   if(c2 >= l3)
      return false;
   if((o2 - c2) < strategy_signal_body_frac * range2)
      return false;

   // 6. Macro-bias agreement (downtrend stack).
   const double sma_fast = QM_SMA(_Symbol, strategy_tf, strategy_sma_fast_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_tf, strategy_sma_slow_period, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;
   if(!(c1 < sma_fast && sma_fast < sma_slow))
      return false;

   // 7. Trend-progression: signal-bar close below breakout-bar close.
   if(!(c2 < c6))
      return false;

   const double offset = strategy_trigger_pips * pip;
   trigger = NormalizeDouble(l2 - offset, _Digits);

   double sl = h3 + strategy_sl_buffer_atr * atr;
   const double sl_cap = strategy_sl_cap_atr * atr;
   if(sl - trigger > sl_cap)
      sl = trigger + sl_cap;
   entry_sl = NormalizeDouble(sl, _Digits);
   const double risk = entry_sl - trigger;
   if(risk <= 0.0)
      return false;

   const double signal_range = h3 - l2;   // (high[3]-low[2]) — mirror of (high[2]-low[3])
   if(signal_range <= 0.0)
      return false;
   entry_tp = NormalizeDouble(trigger - strategy_tp_range_mult * signal_range, _Digits);
   out_range = signal_range;
   out_inval = h3;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();

   // Session block: no NEW entries 22:00-06:00 broker time (card filter).
   if(strategy_session_block_enabled)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      const int h = dt.hour;
      bool blocked = false;
      if(strategy_session_block_start_h <= strategy_session_block_end_h)
         blocked = (h >= strategy_session_block_start_h && h < strategy_session_block_end_h);
      else
         blocked = (h >= strategy_session_block_start_h || h < strategy_session_block_end_h);
      if(blocked)
         return true;
     }

   // Fail-OPEN spread guard: .DWX quotes ask==bid (0 spread) in the tester, so
   // only block a genuinely wide live spread; never reject on zero spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid && strategy_spread_atr_frac > 0.0)
     {
      const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > strategy_spread_atr_frac * atr)
         return true;
     }

   return false;
  }

// Trade Entry — pattern COMPLETION on the just-closed second-thrust signal bar
// (bar[2]) is the trigger EVENT; trend + leg-count is STATE. Places a stop
// order beyond the signal-bar extreme valid for strategy_trigger_valid_bars.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshPositionLifecycle();
   // 1-pos-per-magic: no entry while a position OR a live pending order exists.
   if(g_active_ticket != 0 || OurPendingCount() > 0)
      return false;

   // Dedupe: one pending placement per closed signal bar.
   const datetime sig_bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar dedupe key
   if(sig_bar_time == g_last_signal_bar_time)
      return false;

   double trigger = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   double range = 0.0;
   double inval = 0.0;

   const int valid_secs = strategy_trigger_valid_bars * PeriodSeconds(strategy_tf);

   if(!CooldownBlocksDirection(1) && PatternBuy(trigger, sl, tp, range, inval))
     {
      req.type = QM_BUY_STOP;
      req.price = trigger;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_H2_SECOND_PULLBACK_BUY_H4";
      req.expiration_seconds = valid_secs;
      g_signal_range = range;
      g_inval_level = inval;
      g_be_done = false;
      g_last_signal_bar_time = sig_bar_time;
      return true;
     }

   if(!CooldownBlocksDirection(-1) && PatternSell(trigger, sl, tp, range, inval))
     {
      req.type = QM_SELL_STOP;
      req.price = trigger;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_L2_SECOND_PULLBACK_SELL_H4";
      req.expiration_seconds = valid_secs;
      g_signal_range = range;
      g_inval_level = inval;
      g_be_done = false;
      g_last_signal_bar_time = sig_bar_time;
      return true;
     }

   return false;
  }

// Trade Management — one-time break-even ratchet at +1.0*signal-range, then a
// Brooks stair-step trail to LL(2)/HH(2). Hard SL, no widening (only tighten).
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_signal_range <= 0.0)
      return;

   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double cur_sl = PositionGetDouble(POSITION_SL);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);
   const double pip = PipDistance();

   // Break-even ratchet (one-time).
   if(!g_be_done && moved >= strategy_be_trigger_range_mult * g_signal_range)
     {
      const double be_price = is_buy ? (open_price + pip) : (open_price - pip);
      const double be_norm = NormalizeDouble(be_price, _Digits);
      if(QM_TM_MoveSL(g_active_ticket, be_norm, "brooks_h2l2_be_ratchet"))
         g_be_done = true;
     }

   // Stair-step trail to LL(2)/HH(2), only AFTER BE and only tightening.
   if(g_be_done && g_strategy_cadence_ready && strategy_trail_lookback > 0)
     {
      if(is_buy)
        {
         const double trail = LowestLow(1, strategy_trail_lookback) - strategy_sl_buffer_atr * pip;
         const double trail_norm = NormalizeDouble(trail, _Digits);
         if(trail_norm > cur_sl && trail_norm < market)
            QM_TM_MoveSL(g_active_ticket, trail_norm, "brooks_h2l2_trail");
        }
      else
        {
         const double trail = HighestHigh(1, strategy_trail_lookback) + strategy_sl_buffer_atr * pip;
         const double trail_norm = NormalizeDouble(trail, _Digits);
         if((cur_sl <= 0.0 || trail_norm < cur_sl) && trail_norm > market)
            QM_TM_MoveSL(g_active_ticket, trail_norm, "brooks_h2l2_trail");
        }
     }
  }

// Trade Close — pattern-invalidation exit (close beyond low[3]/high[3]) OR a
// 30-bar time stop. Evaluated on closed bars only.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!g_strategy_cadence_ready)
      return false;

   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: invalidation-close check

   // Pattern-invalidation: close back below low[3] (BUY) / above high[3] (SELL).
   if(g_inval_level > 0.0)
     {
      if(is_buy && c1 < g_inval_level)
         return true;
      if(!is_buy && c1 > g_inval_level)
         return true;
     }

   // Time stop.
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   return (bars_since_open >= strategy_time_stop_bars);
  }

// News Filter Hook (callable for P8 News Impact phase) — also blocks if the
// signal bar overlapped a high-impact event.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
      return true;

   const datetime bar_time = iTime(_Symbol, strategy_tf, 1); // perf-allowed: signal-bar news overlap check
   if(bar_time > 0 && !QM_NewsAllowsTrade(_Symbol, bar_time, qm_news_mode_legacy))
      return true;

   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1380\",\"ea\":\"brooks-h2l2-second-pullback-h4\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   g_strategy_cadence_ready = false;

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

   g_strategy_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);
   if(g_strategy_cadence_ready)
      AdvanceCooldownCountdown();

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

   if(!g_strategy_cadence_ready)
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
