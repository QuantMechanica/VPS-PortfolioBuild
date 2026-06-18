#property strict
#property version   "5.0"
#property description "QM5_1363 Brooks Wedge / Three-Push Reversal H4"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1363 Brooks Wedge / Three-Push Reversal (H4)
// -----------------------------------------------------------------------------
// Al Brooks "wedge" / three-push exhaustion-reversal. The WEDGE is a STATE: three
// sequential swing-high pivots (P1<P2<P3, strictly higher highs) whose push legs
// SHRINK and whose corrective pullbacks NARROW, each leg >= 1.5*ATR, spanning a
// bar-count window. The third-push FAILURE is the single trigger EVENT: a closed
// bar trades through the swing-low between P2 and P3 (bearish-wedge SELL) — mirror
// for the bullish wedge (three lower lows, close above the swing-high between the
// last two lows -> BUY).
//
// Pivots are detected on CLOSED bars only with a fixed 3-left/3-right window
// (the bar is the highest/lowest of a 7-bar window centred on itself). No
// real-time pivot recognition. A wedge triple (P1/P2/P3 bar-times) is marked
// consumed once it triggers, so the same wedge never re-fires.
//
// Exit: R-multiple TP off the final push (P3 - L3), beyond-wedge-extreme hard SL
// (P3 +/- 0.3*ATR, capped 3.0*ATR), one-time break-even shift at +1.0x last push,
// new-extreme invalidation, 24-bar time stop. Layout/idioms mirror sibling
// QM5_1327 (Brooks pin-bar) — only the structural primitive differs.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1363;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_tf        = PERIOD_H4;
input int    strategy_atr_period         = 14;
input int    strategy_sma_period         = 50;
input int    strategy_pivot_halfwin      = 3;      // 3-left + 3-right pivot window
input int    strategy_scan_bars          = 40;     // bounded closed-bar pivot scan depth
input double strategy_push_atr_min       = 1.5;    // each push leg >= 1.5 * ATR
input int    strategy_min_leg_bars       = 4;      // >= 4 H4 bars between adjacent pivots
input int    strategy_span_min_bars      = 10;     // total wedge span lower bound
input int    strategy_span_max_bars      = 30;     // total wedge span upper bound
input bool   strategy_use_sma_bias       = true;   // macro-bias agreement filter (P3-sweep)
input double strategy_tp_rr              = 1.5;    // TP = R_mult of the final push
input double strategy_sl_atr_buffer      = 0.3;    // SL = P3 +/- 0.3*ATR beyond extreme
input double strategy_sl_atr_cap         = 3.0;    // initial-SL distance cap (x ATR)
input double strategy_be_trigger_push    = 1.0;    // BE shift at +1.0x last-push favour
input double strategy_invalidate_atr     = 0.2;    // new-extreme invalidation buffer (x ATR)
input int    strategy_time_stop_bars     = 24;     // ~4 trading days
input double strategy_spread_atr_frac    = 0.4;    // spread guard: spread < 0.4 * ATR

// ---- position lifecycle state ----
ulong    g_active_ticket          = 0;
int      g_active_direction       = 0;       // +1 buy / -1 sell
double   g_initial_risk_price     = 0.0;     // |entry - sl| at open
double   g_last_push_price        = 0.0;     // |P3 - L3| of the triggering wedge
double   g_wedge_extreme          = 0.0;     // P3 (price of the wedge apex)
double   g_invalidate_atr_price   = 0.0;     // ATR snapshot for invalidation buffer
bool     g_be_done                = false;
bool     g_strategy_cadence_ready = false;

// ---- consumed-wedge guard (last fired triple, by pivot bar-time) ----
datetime g_used_p1_time           = 0;
datetime g_used_p2_time           = 0;
datetime g_used_p3_time           = 0;

double PipDistance()
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const int pip_factor = (digits == 3 || digits == 5) ? 10 : 1;
   return point * pip_factor;
  }

// Is the bar at `shift` a swing HIGH? Strict max of [shift-hw .. shift+hw].
// Requires shift >= hw and shift+hw within the scan history.
bool IsSwingHigh(const int shift, const int hw)
  {
   const double h = iHigh(_Symbol, strategy_tf, shift); // perf-allowed: fixed closed-bar pivot window
   for(int k = 1; k <= hw; ++k)
     {
      if(iHigh(_Symbol, strategy_tf, shift - k) >= h) // perf-allowed: bounded pivot window scan
         return false;
      if(iHigh(_Symbol, strategy_tf, shift + k) >= h) // perf-allowed: bounded pivot window scan
         return false;
     }
   return true;
  }

bool IsSwingLow(const int shift, const int hw)
  {
   const double l = iLow(_Symbol, strategy_tf, shift); // perf-allowed: fixed closed-bar pivot window
   for(int k = 1; k <= hw; ++k)
     {
      if(iLow(_Symbol, strategy_tf, shift - k) <= l) // perf-allowed: bounded pivot window scan
         return false;
      if(iLow(_Symbol, strategy_tf, shift + k) <= l) // perf-allowed: bounded pivot window scan
         return false;
     }
   return true;
  }

// Lowest LOW over shift range [a..b] inclusive (a <= b, both >= 1).
double LowBetween(const int a, const int b)
  {
   double lo = DBL_MAX;
   for(int s = a; s <= b; ++s)
      lo = MathMin(lo, iLow(_Symbol, strategy_tf, s)); // perf-allowed: bounded corrective-leg scan
   return lo;
  }

double HighBetween(const int a, const int b)
  {
   double hi = -DBL_MAX;
   for(int s = a; s <= b; ++s)
      hi = MathMax(hi, iHigh(_Symbol, strategy_tf, s)); // perf-allowed: bounded corrective-leg scan
   return hi;
  }

// Collect up to `max_n` most-recent swing-high pivot shifts (newest first).
// Scans shifts from (hw+1) outward to scan_bars; never reads beyond scan history.
int CollectSwingHighs(int &shifts[], const int hw, const int scan_bars, const int max_n)
  {
   int n = 0;
   const int last = scan_bars - hw; // ensure shift+hw stays within scan window
   for(int s = hw + 1; s <= last && n < max_n; ++s)
     {
      if(IsSwingHigh(s, hw))
        {
         shifts[n] = s;
         n++;
        }
     }
   return n;
  }

int CollectSwingLows(int &shifts[], const int hw, const int scan_bars, const int max_n)
  {
   int n = 0;
   const int last = scan_bars - hw;
   for(int s = hw + 1; s <= last && n < max_n; ++s)
     {
      if(IsSwingLow(s, hw))
        {
         shifts[n] = s;
         n++;
        }
     }
   return n;
  }

// Bearish wedge -> SELL. Detect three sequential higher-high pivots forming a
// narrowing/shrinking wedge, with the third-push-failure EVENT (close[1] below
// the swing-low between P2 and P3). Fills sl/tp/last-push/extreme on success.
bool PatternSell(double &entry_sl, double &entry_tp,
                 datetime &p1t, datetime &p2t, datetime &p3t)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   int hs[];
   ArrayResize(hs, 8);
   const int n = CollectSwingHighs(hs, strategy_pivot_halfwin, strategy_scan_bars, 8);
   if(n < 3)
      return false;

   // hs[] is newest-first. P3 = most recent, P2 = next, P1 = oldest of the three.
   const int s_p3 = hs[0];
   const int s_p2 = hs[1];
   const int s_p1 = hs[2];

   const double p1 = iHigh(_Symbol, strategy_tf, s_p1); // perf-allowed: pivot price
   const double p2 = iHigh(_Symbol, strategy_tf, s_p2); // perf-allowed: pivot price
   const double p3 = iHigh(_Symbol, strategy_tf, s_p3); // perf-allowed: pivot price

   // (2) Strictly monotonically increasing pivot highs.
   if(!(p3 > p2 && p2 > p1))
      return false;

   // Bar-count gates: shifts are larger going back in time (s_p1 > s_p2 > s_p3).
   const int leg_12_bars = s_p1 - s_p2; // bars between P1 and P2
   const int leg_23_bars = s_p2 - s_p3; // bars between P2 and P3
   if(leg_12_bars < strategy_min_leg_bars || leg_23_bars < strategy_min_leg_bars)
      return false;
   const int span_bars = s_p1 - s_p3;
   if(span_bars < strategy_span_min_bars || span_bars > strategy_span_max_bars)
      return false;

   // Corrective swing-lows: between P1&P2 and between P2&P3 (exclusive of pivots).
   const double low_12 = LowBetween(s_p2 + 1, s_p1 - 1);
   const double low_23 = LowBetween(s_p3 + 1, s_p2 - 1);
   if(low_12 == DBL_MAX || low_23 == DBL_MAX)
      return false;

   // (3) Decreasing push size: final push (from low_23 up to P3) smaller than the
   //     prior push (from low_12 up to P2).
   const double push_23 = p3 - low_23;
   const double push_12 = p2 - low_12;
   if(!(push_23 < push_12))
      return false;

   // (4) Narrowing corrective pullback: the P2->P3 corrective low sits HIGHER than
   //     the P1->P2 corrective low (wedge narrows, not widens).
   if(!(low_23 > low_12))
      return false;

   // (5) Magnitude meaningfulness: each push leg >= push_atr_min * ATR.
   if(push_12 < strategy_push_atr_min * atr || push_23 < strategy_push_atr_min * atr)
      return false;

   // (7) Reversal trigger EVENT: a closed bar trades below the swing-low between
   //     P2 and P3 (the wedge breaks on the downside). Use bar[1] close.
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: trigger close
   if(c1 >= low_23)
      return false;

   // (3-bias) Macro-bias agreement (optional, P3-sweep): reversal aligned with
   //          macro down-trend -> close[1] below SMA-50.
   if(strategy_use_sma_bias)
     {
      const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
      if(sma <= 0.0 || c1 >= sma)
         return false;
     }

   // Exit geometry. L3 = the corrective swing-low between P2 and P3.
   const double L3 = low_23;
   const double last_push = p3 - L3;
   if(last_push <= 0.0)
      return false;

   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid <= 0.0)
      return false;

   // SL beyond the wedge extreme (P3 + buffer*ATR), capped at sl_atr_cap*ATR.
   double sl = p3 + strategy_sl_atr_buffer * atr;
   const double max_sl = bid + strategy_sl_atr_cap * atr;
   if(sl > max_sl)
      sl = max_sl;
   const double risk = sl - bid;
   if(risk <= 0.0)
      return false;

   const double tp = bid - strategy_tp_rr * last_push;

   entry_sl = NormalizeDouble(sl, _Digits);
   entry_tp = NormalizeDouble(tp, _Digits);
   p1t = iTime(_Symbol, strategy_tf, s_p1); // perf-allowed: pivot time for consumed-wedge guard
   p2t = iTime(_Symbol, strategy_tf, s_p2); // perf-allowed: pivot time for consumed-wedge guard
   p3t = iTime(_Symbol, strategy_tf, s_p3); // perf-allowed: pivot time for consumed-wedge guard
   g_last_push_price = last_push;
   g_wedge_extreme = p3;
   g_invalidate_atr_price = atr;
   return true;
  }

// Bullish wedge -> BUY. Mirror: three strictly lower-low pivots, shrinking pushes,
// narrowing corrective rallies, magnitude gate, bar-count gate; EVENT = close[1]
// above the swing-high between the last two lows.
bool PatternBuy(double &entry_sl, double &entry_tp,
                datetime &p1t, datetime &p2t, datetime &p3t)
  {
   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   const double pip = PipDistance();
   if(atr <= 0.0 || pip <= 0.0)
      return false;

   int ls[];
   ArrayResize(ls, 8);
   const int n = CollectSwingLows(ls, strategy_pivot_halfwin, strategy_scan_bars, 8);
   if(n < 3)
      return false;

   const int s_p3 = ls[0];
   const int s_p2 = ls[1];
   const int s_p1 = ls[2];

   const double p1 = iLow(_Symbol, strategy_tf, s_p1); // perf-allowed: pivot price
   const double p2 = iLow(_Symbol, strategy_tf, s_p2); // perf-allowed: pivot price
   const double p3 = iLow(_Symbol, strategy_tf, s_p3); // perf-allowed: pivot price

   // Strictly monotonically decreasing pivot lows (three lower lows).
   if(!(p3 < p2 && p2 < p1))
      return false;

   const int leg_12_bars = s_p1 - s_p2;
   const int leg_23_bars = s_p2 - s_p3;
   if(leg_12_bars < strategy_min_leg_bars || leg_23_bars < strategy_min_leg_bars)
      return false;
   const int span_bars = s_p1 - s_p3;
   if(span_bars < strategy_span_min_bars || span_bars > strategy_span_max_bars)
      return false;

   // Corrective swing-highs between adjacent lows.
   const double high_12 = HighBetween(s_p2 + 1, s_p1 - 1);
   const double high_23 = HighBetween(s_p3 + 1, s_p2 - 1);
   if(high_12 == -DBL_MAX || high_23 == -DBL_MAX)
      return false;

   // Decreasing push size: final push (high_23 down to P3) smaller than prior.
   const double push_23 = high_23 - p3;
   const double push_12 = high_12 - p2;
   if(!(push_23 < push_12))
      return false;

   // Narrowing corrective rally: P2->P3 corrective high sits LOWER than P1->P2's.
   if(!(high_23 < high_12))
      return false;

   if(push_12 < strategy_push_atr_min * atr || push_23 < strategy_push_atr_min * atr)
      return false;

   // Reversal trigger EVENT: bar[1] closes above the swing-high between P2 and P3.
   const double c1 = iClose(_Symbol, strategy_tf, 1); // perf-allowed: trigger close
   if(c1 <= high_23)
      return false;

   if(strategy_use_sma_bias)
     {
      const double sma = QM_SMA(_Symbol, strategy_tf, strategy_sma_period, 1);
      if(sma <= 0.0 || c1 <= sma)
         return false;
     }

   const double H3 = high_23; // corrective swing-high between the last two lows
   const double last_push = H3 - p3;
   if(last_push <= 0.0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   double sl = p3 - strategy_sl_atr_buffer * atr;
   const double min_sl = ask - strategy_sl_atr_cap * atr;
   if(sl < min_sl)
      sl = min_sl;
   const double risk = ask - sl;
   if(risk <= 0.0)
      return false;

   const double tp = ask + strategy_tp_rr * last_push;

   entry_sl = NormalizeDouble(sl, _Digits);
   entry_tp = NormalizeDouble(tp, _Digits);
   p1t = iTime(_Symbol, strategy_tf, s_p1); // perf-allowed: pivot time for consumed-wedge guard
   p2t = iTime(_Symbol, strategy_tf, s_p2); // perf-allowed: pivot time for consumed-wedge guard
   p3t = iTime(_Symbol, strategy_tf, s_p3); // perf-allowed: pivot time for consumed-wedge guard
   g_last_push_price = last_push;
   g_wedge_extreme = p3;
   g_invalidate_atr_price = atr;
   return true;
  }

bool SelectOurPosition(ulong &ticket, int &direction, double &open_price,
                       double &sl, double &tp, double &volume, datetime &open_time)
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

void RefreshPositionLifecycle()
  {
   ulong ticket = 0;
   int direction = 0;
   double open_price = 0.0, sl = 0.0, tp = 0.0, volume = 0.0;
   datetime open_time = 0;

   if(SelectOurPosition(ticket, direction, open_price, sl, tp, volume, open_time))
     {
      if(ticket != g_active_ticket)
        {
         g_active_ticket = ticket;
         g_active_direction = direction;
         g_initial_risk_price = MathAbs(open_price - sl);
         g_be_done = false;
        }
      return;
     }

   g_active_ticket = 0;
   g_active_direction = 0;
   g_initial_risk_price = 0.0;
   g_be_done = false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   RefreshPositionLifecycle();

   // Fail-OPEN spread guard. .DWX quotes ask==bid (0 modeled spread) in the
   // tester; only block a genuinely wide live spread relative to ATR. Never
   // reject on zero spread.
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

// Trade Entry — evaluated once per new closed H4 bar. The wedge STATE plus the
// third-push-failure EVENT fire a single market entry; the consumed-wedge guard
// stops the same P1/P2/P3 triple from re-triggering.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   RefreshPositionLifecycle();
   if(g_active_ticket != 0)
      return false;

   double sl = 0.0, tp = 0.0;
   datetime p1t = 0, p2t = 0, p3t = 0;

   if(PatternSell(sl, tp, p1t, p2t, p3t))
     {
      if(p1t == g_used_p1_time && p2t == g_used_p2_time && p3t == g_used_p3_time)
         return false; // wedge already fired
      req.type = QM_SELL;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_WEDGE_3PUSH_REVERSAL_SELL_H4";
      g_used_p1_time = p1t;
      g_used_p2_time = p2t;
      g_used_p3_time = p3t;
      g_initial_risk_price = MathAbs(sl - SymbolInfoDouble(_Symbol, SYMBOL_BID));
      g_be_done = false;
      return true;
     }

   if(PatternBuy(sl, tp, p1t, p2t, p3t))
     {
      if(p1t == g_used_p1_time && p2t == g_used_p2_time && p3t == g_used_p3_time)
         return false;
      req.type = QM_BUY;
      req.sl = sl;
      req.tp = tp;
      req.reason = "BROOKS_WEDGE_3PUSH_REVERSAL_BUY_H4";
      g_used_p1_time = p1t;
      g_used_p2_time = p2t;
      g_used_p3_time = p3t;
      g_initial_risk_price = MathAbs(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - sl);
      g_be_done = false;
      return true;
     }

   return false;
  }

// Trade Management — one-time break-even shift when price advances +1.0x the last
// push in favour (static SL-to-entry move, NOT an adaptive trail).
void Strategy_ManageOpenPosition()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0 || g_be_done || g_last_push_price <= 0.0)
      return;
   if(!PositionSelectByTicket(g_active_ticket))
      return;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);
   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double market = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double moved = is_buy ? (market - open_price) : (open_price - market);

   if(moved >= strategy_be_trigger_push * g_last_push_price)
     {
      const double pip = PipDistance();
      const double be = is_buy ? (open_price + pip) : (open_price - pip);
      if(QM_TM_MoveSL(g_active_ticket, NormalizeDouble(be, _Digits), "brooks_wedge_be_shift"))
         g_be_done = true;
     }
  }

// Trade Close — new-extreme invalidation (wedge apex exceeded) OR 24-bar time stop.
bool Strategy_ExitSignal()
  {
   RefreshPositionLifecycle();
   if(g_active_ticket == 0)
      return false;
   if(!PositionSelectByTicket(g_active_ticket))
      return false;

   const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const bool is_buy = (ptype == POSITION_TYPE_BUY);

   // New-extreme invalidation: the wedge's apex pivot has been exceeded beyond the
   // ATR buffer -> the exhaustion read is wrong. Use current tick extreme.
   if(g_wedge_extreme > 0.0 && g_invalidate_atr_price > 0.0)
     {
      const double buf = strategy_invalidate_atr * g_invalidate_atr_price;
      if(is_buy)
        {
         // bullish wedge apex = lowest low (g_wedge_extreme = P3 low). Invalidate
         // if price makes a new low below P3 - buffer.
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid < g_wedge_extreme - buf)
            return true;
        }
      else
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && ask > g_wedge_extreme + buf)
            return true;
        }
     }

   // Time stop — only meaningful on a closed-bar cadence.
   if(g_strategy_cadence_ready)
     {
      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      const int bars_since_open = iBarShift(_Symbol, strategy_tf, open_time, false);
      if(bars_since_open >= strategy_time_stop_bars)
         return true;
     }

   return false;
  }

// News Filter Hook (callable for P8 News Impact phase).
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(!QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode_legacy))
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1363\",\"ea\":\"brooks-wedge-3push-h4\"}");
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

   // Single new-bar consume per tick; reused for time-stop cadence + entry gate.
   g_strategy_cadence_ready = QM_IsNewBar(_Symbol, strategy_tf);

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick management (BE shift) + discretionary exit (invalidation / time stop).
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
