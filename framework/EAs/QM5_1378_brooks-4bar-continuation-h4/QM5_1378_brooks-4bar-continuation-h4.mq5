#property strict
#property version   "5.0"
#property description "QM5_1378 Brooks 4-Bar Continuation H1/L1 (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1378 Brooks 4-Bar Continuation / Breakout-Pullback-Failed-Test (H4)
// -----------------------------------------------------------------------------
// Brooks H1 (bull) / L1 (bear) pullback-continuation primitive. Detected purely
// from CLOSED-bar geometry. With the LAST fully-closed bar = bar[1] (the signal
// bar) at the new-bar event, the 3-bar pattern body is:
//
//   bar[3]  breakout bar   strong with-trend bar, body_ratio >= 0.55,
//                          range >= 1.2*ATR, closes at a new 10-bar extreme.
//   bar[2]  pullback bar   1-bar opposite pullback that FAILS to break the
//                          breakout bar's stop-side (low[2] > low[3] for bull),
//                          meaningful (range[2] >= 0.5*ATR).
//   bar[1]  signal bar     with-trend re-thrust closing back through the
//                          pullback bar's extreme (close[1] > high[2] for bull),
//                          body_ratio >= 0.40.
//
// STATE (context, must hold but are not the trigger):
//   - macro bias: close[1] vs SMA50, SMA50 vs SMA200 agreement.
//   - swing context: breakout bar low above the 20-bar swing-low (bull).
//
// EVENT (the single trigger): completion of the signal bar. On that closed-bar
// event we arm a buy-stop (bull) / sell-stop (bear) at the signal bar's
// stop-side + 1 pip, valid for the next 2 H4 bars. Fill within 2 bars -> trade;
// otherwise the pending order expires (stale). Single QM_IsNewBar consume/tick.
//
// EXIT: R-multiple TP on (signal-bar-high - pullback-low) range; one-time
// break-even ratchet at +1R(range); after BE, a Brooks-style stair-step trail
// to the prior-2-bar low (bull) / high (bear); pattern-invalidation market exit
// if close breaks back through the pullback's extreme; 24-bar time stop.
// Cool-down: after a SL hit on this symbol, no new entry for 12 H4 bars.
//
// .DWX invariants honoured: fail-OPEN spread guard, no swap gate, single
// QM_IsNewBar consume/tick, prior-CLOSE referenced (gapless feed), one position
// per magic, all logic in-EA, RISK_FIXED tester default. Layout mirrors sibling
// QM5_1362 (Brooks 2-bar reversal) — only the candle primitive + pending-stop
// trigger differ.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1378;
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
input ENUM_TIMEFRAMES strategy_tf              = PERIOD_H4;
input int    strategy_atr_period               = 14;
input int    strategy_sma_fast_period          = 50;    // macro-bias fast SMA
input int    strategy_sma_slow_period          = 200;   // macro-bias slow SMA
input int    strategy_swing_lookback           = 20;    // swing-high/low window
input int    strategy_breakout_newhigh_lb      = 10;    // breakout closes at new N-bar extreme
input double strategy_breakout_body_min_frac   = 0.55;  // breakout bar body/range
input double strategy_breakout_range_atr_frac  = 1.20;  // breakout range >= 1.2*ATR
input double strategy_pullback_range_atr_frac  = 0.50;  // pullback range >= 0.5*ATR
input double strategy_signal_body_min_frac     = 0.40;  // signal bar body/range
input int    strategy_pending_valid_bars       = 2;     // buy/sell-stop valid for N H4 bars
input double strategy_entry_trigger_pips       = 1.0;   // stop offset beyond signal bar extreme
input double strategy_sl_buffer_atr            = 0.30;  // SL beyond pullback extreme
input double strategy_sl_cap_atr               = 2.50;  // cap initial SL distance
input double strategy_tp_range_mult            = 2.0;   // TP = R_mult * (high[1]-low[2])
input double strategy_be_trigger_range_mult    = 1.0;   // BE ratchet after +1.0*range
input int    strategy_trail_bars               = 2;     // trail to prior-N-bar low/high after BE
input int    strategy_time_stop_bars           = 24;    // time stop (~4 trading days)
input int    strategy_sl_cooldown_bars         = 12;    // no entry for N bars after a SL hit
input double strategy_spread_atr_frac          = 0.40;  // spread guard: spread < 0.40*ATR

// --- position / order lifecycle state -----------------------------------
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;     // +1 buy / -1 sell
double   g_signal_range           = 0.0;   // (high[1]-low[2]) at arm time (BUY) / (high[2]-low[1]) (SELL)
double   g_pullback_extreme       = 0.0;   // low[2] (BUY) / high[2] (SELL) for invalidation exit
double   g_active_sl              = 0.0;   // last-known SL (to classify SL hit vs TP)
bool     g_be_done                = false;
bool     g_strategy_cadence_ready = false;

ulong    g_pending_ticket         = 0;     // our live buy/sell-stop ticket
int      g_pending_direction      = 0;

int      g_cooldown_remaining     = 0;     // H4 bars left in post-SL cooldown

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

// Select this EA's open position (one-per-magic). Returns false if none.
bool SelectOurPosition(ulong &ticket, int &direction, double &open_price, double &sl, double &tp, datetime &open_time)
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

// Find this EA's live pending stop order on this symbol, if any.
bool SelectOurPendingOrder(ulong &ticket, int &direction)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ord_ticket = OrderGetTicket(i);
      if(ord_ticket == 0 || !OrderSelect(ord_ticket))
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      const ENUM_ORDER_TYPE otype = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(otype == ORDER_TYPE_BUY_STOP)
        { ticket = ord_ticket; direction = 1; return true; }
      if(otype == ORDER_TYPE_SELL_STOP)
        { ticket = ord_ticket; direction = -1; return true; }
     }
   return false;
  }

// Maintain position + pending-order lifecycle; arm SL-hit cooldown on close.
void RefreshLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0;
   double sl = 0.0;
   double tp = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_be_done = false;
        }
      if(sl > 0.0)
         g_active_sl = sl;             // track current SL for hit classification
      return;
     }

   // No open position now. If one JUST closed, classify SL-hit -> cooldown.
   if(g_active_ticket != 0)
     {
      if(g_active_sl > 0.0)
        {
         const double last_close = iClose(_Symbol, strategy_tf, 1); // perf-allowed: closed-bar SL-hit classification
         const bool sl_hit = (g_active_direction > 0) ? (last_close <= g_active_sl)
                                                       : (last_close >= g_active_sl);
         if(sl_hit)
            g_cooldown_remaining = MathMax(strategy_sl_cooldown_bars, 0);
        }
      g_active_ticket = 0;
      g_active_direction = 0;
      g_signal_range = 0.0;
      g_pullback_extreme = 0.0;
      g_active_sl = 0.0;
      g_be_done = false;
     }

   // Track our pending stop order (so we never stack a second one).
   ulong pend_ticket = 0;
   int pend_dir = 0;
   if(SelectOurPendingOrder(pend_ticket, pend_dir))
     {
      g_pending_ticket = pend_ticket;
      g_pending_direction = pend_dir;
     }
   else
     {
      g_pending_ticket = 0;
      g_pending_direction = 0;
     }
  }

void AdvanceCooldown()
  {
   if(g_cooldown_remaining > 0)
      g_cooldown_remaining--;
  }

// Bullish H1: breakout=bar[3], pullback=bar[2], signal=bar[1] (last closed).
// Returns the buy-stop price, SL price, TP price, signal range, and the
// pullback low (for invalidation) via out-params.
bool PatternBuy(double &out_stop, double &out_sl, double &out_tp, double &out_range, double &out_pullback_low)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const double o3 = iOpen(_Symbol, strategy_tf, 3);  // perf-allowed: fixed closed-bar OHLC structural pattern
   const double c3 = iClose(_Symbol, strategy_tf, 3); // perf-allowed
   const double h3 = iHigh(_Symbol, strategy_tf, 3);  // perf-allowed
   const double l3 = iLow(_Symbol, strategy_tf, 3);   // perf-allowed

   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed
   const double h2 = iHigh(_Symbol, strategy_tf, 2);  // perf-allowed
   const double l2 = iLow(_Symbol, strategy_tf, 2);   // perf-allowed
   const double o2 = iOpen(_Symbol, strategy_tf, 2);  // perf-allowed

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed

   const double range3 = h3 - l3;
   const double range2 = h2 - l2;
   const double range1 = h1 - l1;
   if(range3 <= 0.0 || range2 <= 0.0 || range1 <= 0.0)
      return false;

   // 1) Breakout bar (bar[3]): strong bull bar at a new N-bar high close.
   if(!(c3 > o3))
      return false;
   if((c3 - o3) < strategy_breakout_body_min_frac * range3)
      return false;
   if(range3 < strategy_breakout_range_atr_frac * atr)
      return false;
   const double prior_high = HighestHigh(4, strategy_breakout_newhigh_lb); // bars [4..4+lb-1]
   if(c3 <= prior_high)
      return false;

   // 2) Pullback bar (bar[2]): bear/doji, low ABOVE breakout low (failed test),
   //    meaningful range (not a doji-creep). bull bars are NOT a valid pullback.
   if(c2 > o2)               // an up-bar is not a pullback
      return false;
   if(l2 <= l3)              // failed-test: pullback must NOT break breakout low
      return false;
   if(range2 < strategy_pullback_range_atr_frac * atr)
      return false;

   // 3) Signal bar (bar[1]): bull re-thrust closing above the pullback high.
   if(!(c1 > o1))
      return false;
   if(c1 <= h2)
      return false;
   if((c1 - o1) < strategy_signal_body_min_frac * range1)
      return false;

   // STATE: macro-bias agreement (up-trend regime confirmed).
   const double sma_fast = QM_SMA(_Symbol, strategy_tf, strategy_sma_fast_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_tf, strategy_sma_slow_period, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;
   if(!(c1 > sma_fast && sma_fast > sma_slow))
      return false;

   // STATE: swing context — breakout originates from above the swing-low.
   const double swing_low = LowestLow(3, strategy_swing_lookback);
   if(l3 < swing_low)
      return false;

   // Entry trigger: buy-stop just above the signal-bar high.
   const double stop_price = h1 + strategy_entry_trigger_pips * pip;

   // SL below the pullback's low; cap the distance from the trigger.
   double sl = l2 - strategy_sl_buffer_atr * atr;
   const double sl_cap = strategy_sl_cap_atr * atr;
   if(stop_price - sl > sl_cap)
      sl = stop_price - sl_cap;
   if(stop_price - sl <= 0.0)
      return false;

   const double range = h1 - l2;            // signal-bar-plus-pullback range
   if(range <= 0.0)
      return false;

   out_stop = NormalizeDouble(stop_price, _Digits);
   out_sl   = NormalizeDouble(sl, _Digits);
   out_tp   = NormalizeDouble(stop_price + strategy_tp_range_mult * range, _Digits);
   out_range = range;
   out_pullback_low = l2;
   return true;
  }

// Bearish L1 — mirror of PatternBuy.
bool PatternSell(double &out_stop, double &out_sl, double &out_tp, double &out_range, double &out_pullback_high)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   const double o3 = iOpen(_Symbol, strategy_tf, 3);  // perf-allowed
   const double c3 = iClose(_Symbol, strategy_tf, 3); // perf-allowed
   const double h3 = iHigh(_Symbol, strategy_tf, 3);  // perf-allowed
   const double l3 = iLow(_Symbol, strategy_tf, 3);   // perf-allowed

   const double c2 = iClose(_Symbol, strategy_tf, 2); // perf-allowed
   const double h2 = iHigh(_Symbol, strategy_tf, 2);  // perf-allowed
   const double l2 = iLow(_Symbol, strategy_tf, 2);   // perf-allowed
   const double o2 = iOpen(_Symbol, strategy_tf, 2);  // perf-allowed

   const double o1 = iOpen(_Symbol, strategy_tf, 1);  // perf-allowed
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed
   const double h1 = iHigh(_Symbol, strategy_tf, 1);  // perf-allowed
   const double l1 = iLow(_Symbol, strategy_tf, 1);   // perf-allowed

   const double range3 = h3 - l3;
   const double range2 = h2 - l2;
   const double range1 = h1 - l1;
   if(range3 <= 0.0 || range2 <= 0.0 || range1 <= 0.0)
      return false;

   // 1) Breakout bar (bar[3]): strong bear bar at a new N-bar low close.
   if(!(c3 < o3))
      return false;
   if((o3 - c3) < strategy_breakout_body_min_frac * range3)
      return false;
   if(range3 < strategy_breakout_range_atr_frac * atr)
      return false;
   const double prior_low = LowestLow(4, strategy_breakout_newhigh_lb);
   if(c3 >= prior_low)
      return false;

   // 2) Pullback bar (bar[2]): bull/doji, high BELOW breakout high (failed test).
   if(c2 < o2)               // a down-bar is not a pullback
      return false;
   if(h2 >= h3)              // failed-test: pullback must NOT break breakout high
      return false;
   if(range2 < strategy_pullback_range_atr_frac * atr)
      return false;

   // 3) Signal bar (bar[1]): bear re-thrust closing below the pullback low.
   if(!(c1 < o1))
      return false;
   if(c1 >= l2)
      return false;
   if((o1 - c1) < strategy_signal_body_min_frac * range1)
      return false;

   // STATE: macro-bias agreement (down-trend regime confirmed).
   const double sma_fast = QM_SMA(_Symbol, strategy_tf, strategy_sma_fast_period, 1);
   const double sma_slow = QM_SMA(_Symbol, strategy_tf, strategy_sma_slow_period, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false;
   if(!(c1 < sma_fast && sma_fast < sma_slow))
      return false;

   // STATE: swing context — breakout originates from below the swing-high.
   const double swing_high = HighestHigh(3, strategy_swing_lookback);
   if(h3 > swing_high)
      return false;

   // Entry trigger: sell-stop just below the signal-bar low.
   const double stop_price = l1 - strategy_entry_trigger_pips * pip;

   double sl = h2 + strategy_sl_buffer_atr * atr;
   const double sl_cap = strategy_sl_cap_atr * atr;
   if(sl - stop_price > sl_cap)
      sl = stop_price + sl_cap;
   if(sl - stop_price <= 0.0)
      return false;

   const double range = h2 - l1;            // signal-bar-plus-pullback range
   if(range <= 0.0)
      return false;

   out_stop = NormalizeDouble(stop_price, _Digits);
   out_sl   = NormalizeDouble(sl, _Digits);
   out_tp   = NormalizeDouble(stop_price - strategy_tp_range_mult * range, _Digits);
   out_range = range;
   out_pullback_high = h2;
   return true;
  }

// No Trade Filter (time, spread, news). Fail-OPEN spread guard.
bool Strategy_NoTradeFilter()
  {
   RefreshLifecycle();

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

// Trade Entry — signal-bar completion is the EVENT; arm a buy/sell-STOP at the
// signal-bar extreme valid for N bars. Macro-bias + swing are STATE.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY_STOP;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshLifecycle();

   // One position per magic; one armed pending order at a time; cooldown gate.
   if(g_active_ticket != 0 || g_pending_ticket != 0)
      return false;
   if(g_cooldown_remaining > 0)
      return false;

   const int valid_secs = strategy_pending_valid_bars * PeriodSeconds(strategy_tf);

   double stop_p = 0.0, sl = 0.0, tp = 0.0, range = 0.0, pb = 0.0;

   if(PatternBuy(stop_p, sl, tp, range, pb))
     {
      req.type = QM_BUY_STOP;
      req.price = stop_p;
      req.sl = sl;
      req.tp = tp;
      req.expiration_seconds = valid_secs;
      req.reason = "BROOKS_4BAR_H1_CONT_BUY_H4";
      g_signal_range = range;
      g_pullback_extreme = pb;
      g_be_done = false;
      return true;
     }

   if(PatternSell(stop_p, sl, tp, range, pb))
     {
      req.type = QM_SELL_STOP;
      req.price = stop_p;
      req.sl = sl;
      req.tp = tp;
      req.expiration_seconds = valid_secs;
      req.reason = "BROOKS_4BAR_L1_CONT_SELL_H4";
      g_signal_range = range;
      g_pullback_extreme = pb;
      g_be_done = false;
      return true;
     }

   return false;
  }

// Trade Management — one-time BE ratchet at +1R(range), then a Brooks-style
// stair-step trail to the prior-N-bar low (BUY) / high (SELL) once per closed bar.
void Strategy_ManageOpenPosition()
  {
   RefreshLifecycle();
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

   // 1) One-time BE ratchet.
   if(!g_be_done && moved >= strategy_be_trigger_range_mult * g_signal_range)
     {
      const double be_price = is_buy ? (open_price + pip) : (open_price - pip);
      if(QM_TM_MoveSL(g_active_ticket, NormalizeDouble(be_price, _Digits), "brooks_4bar_be_ratchet"))
        {
         g_be_done = true;
         g_active_sl = NormalizeDouble(be_price, _Digits);
        }
     }

   // 2) After BE, stair-step trail once per closed bar (never loosen the stop).
   if(g_be_done && g_strategy_cadence_ready)
     {
      if(is_buy)
        {
         const double trail = LowestLow(1, strategy_trail_bars);
         if(trail > cur_sl && trail < market)
           {
            if(QM_TM_MoveSL(g_active_ticket, NormalizeDouble(trail, _Digits), "brooks_4bar_trail"))
               g_active_sl = NormalizeDouble(trail, _Digits);
           }
        }
      else
        {
         const double trail = HighestHigh(1, strategy_trail_bars);
         if((cur_sl <= 0.0 || trail < cur_sl) && trail > market)
           {
            if(QM_TM_MoveSL(g_active_ticket, NormalizeDouble(trail, _Digits), "brooks_4bar_trail"))
               g_active_sl = NormalizeDouble(trail, _Digits);
           }
        }
     }
  }

// Trade Close — pattern-invalidation (close back through the pullback extreme)
// OR 24-bar time stop. Evaluated once per closed bar.
bool Strategy_ExitSignal()
  {
   RefreshLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!g_strategy_cadence_ready)
      return false;

   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   // Pattern-invalidation: the failed-test thesis is broken.
   if(g_pullback_extreme > 0.0)
     {
      const double last_close = iClose(_Symbol, strategy_tf, 1); // perf-allowed: closed-bar invalidation check
      if(g_active_direction > 0 && last_close < g_pullback_extreme)
         return true;
      if(g_active_direction < 0 && last_close > g_pullback_extreme)
         return true;
     }

   // Time stop.
   const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
   const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
   return (bars_since_open >= strategy_time_stop_bars);
  }

// News Filter Hook — also blocks if the signal bar overlapped a high-impact event.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1378\",\"ea\":\"brooks-4bar-continuation-h4\"}");
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

   // Single QM_IsNewBar consume per tick — latched and reused everywhere.
   g_strategy_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);
   if(g_strategy_cadence_ready)
      AdvanceCooldown();

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
