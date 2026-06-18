#property strict
#property version   "5.0"
#property description "QM5_1369 Goodman Wave Theory 3-C Mechanical Continuation H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1369 — Goodman Wave Theory 3-C (H1)
// -----------------------------------------------------------------------------
// Measured-move continuation. A ZigZag-style fractal detector identifies the most
// recent COMPLETED measured leg A->B (|B-A| >= 1.5*ATR). After the leg, price
// retraces in up to 3 Goodman sub-waves (C1=0.382, C2=0.500, C3=0.618 of the
// leg range R). The C2 (median) retrace is the single Goodman-canonical TRIGGER
// EVENT; the measured-leg + invalidation status is STATE. A reversal bar at the
// C-level + EMA(50) macro-bias agreement fires a continuation entry. TP projects
// R_mult*|R| from entry; SL sits at the next-deeper Cx + ATR cushion (capped at
// 1.0*R); hard-invalidation at 0.786*R; time-stop 30 bars.
//
// Swing detection note: fractal/ZigZag swing points are bespoke structural logic.
// Raw iHigh/iLow/iClose/iOpen/iTime reads on CLOSED bars are used inside a single
// QM_IsNewBar()-gated per-bar scan (perf-allowed). Indicator math (ATR, EMA) uses
// the pooled QM_* readers. State is advanced once per closed bar; the per-tick
// path is O(1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1369;
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
// Swing / measured-leg detection
input int    strategy_fractal_depth       = 8;      // ZigZag depth: bars each side of a swing extreme
input int    strategy_swing_scan_bars      = 400;   // closed-bar window scanned for swing points
input int    strategy_atr_period           = 14;
input double strategy_leg_min_atr_mult     = 1.5;   // measured leg must be >= 1.5 * ATR
// Goodman Fib retrace ratios of the measured-leg range R
input double strategy_fib_c1               = 0.382;
input double strategy_fib_c2               = 0.500;
input double strategy_fib_c3               = 0.618;
input double strategy_fib_invalidation     = 0.786; // deep-retrace trend-failure level
input double strategy_c_tolerance_r        = 0.15;  // +/- tol around a Cx target as fraction of R
// Entry confirmation
input double strategy_body_ratio_min       = 0.40;  // reversal-bar body/range ratio
input int    strategy_ema_period           = 50;    // macro-bias EMA
// Exit
input double strategy_tp_r_mult            = 1.0;   // TP = entry + R_mult * |R|
input double strategy_sl_cushion_atr       = 0.5;   // SL cushion in ATR beyond the deeper Cx
input double strategy_sl_cap_r             = 1.0;   // never risk more than 1.0 * |R|
input double strategy_be_trigger_r         = 0.5;   // move to BE after +0.5 R
input int    strategy_time_stop_bars       = 30;    // ~5 trading days on H1
// Filters
input double strategy_spread_atr_mult      = 0.4;   // block if spread > 0.4 * ATR (fail-OPEN on 0)
input int    strategy_rollover_block_hour  = 22;    // no new entry 22:00-23:00 broker time

// -----------------------------------------------------------------------------
// File-scope state (advanced once per closed bar)
// -----------------------------------------------------------------------------
datetime g_last_scan_bar    = 0;

// Measured leg A->B
bool     g_leg_valid        = false;
int      g_leg_dir          = 0;       // +1 bullish (A=low,B=high), -1 bearish
double   g_price_A          = 0.0;
double   g_price_B          = 0.0;
double   g_leg_R            = 0.0;      // signed: price(B) - price(A)
datetime g_time_B           = 0;       // bar time of B (leg completion)

// Goodman C-levels (absolute prices), recomputed when the leg changes
double   g_c1_level         = 0.0;
double   g_c2_level         = 0.0;
double   g_c3_level         = 0.0;
double   g_invalid_level    = 0.0;

// Cool-down: a measured leg killed by hard-invalidation cannot be re-entered
datetime g_dead_leg_time_B  = 0;
int      g_dead_leg_dir     = 0;

// Open-trade bookkeeping
datetime g_entry_bar_time   = 0;
bool     g_be_done          = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
double ATR_H1()
{
   return QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
}

bool HasPosition()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return true;
   }
   return false;
}

bool PositionIsLong()
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      return ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   }
   return false;
}

void ClosePosition(const QM_ExitReason reason)
{
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;
      QM_TM_ClosePosition(t, reason);
   }
}

// Fractal swing test on CLOSED bars: bar at `shift` is a swing-high if its high
// is strictly the highest within `depth` bars on each side (mirror for low).
// Reads closed bars only (shift >= 1). perf-allowed: bespoke structural logic.
bool IsSwingHigh(const int shift, const int depth)
{
   const double h = iHigh(_Symbol, PERIOD_H1, shift);   // perf-allowed
   if(h <= 0.0) return false;
   for(int k = 1; k <= depth; ++k)
   {
      if(iHigh(_Symbol, PERIOD_H1, shift - k) >= h) return false;   // perf-allowed (newer side)
      if(iHigh(_Symbol, PERIOD_H1, shift + k) >  h) return false;   // perf-allowed (older side)
   }
   return true;
}

bool IsSwingLow(const int shift, const int depth)
{
   const double l = iLow(_Symbol, PERIOD_H1, shift);    // perf-allowed
   if(l <= 0.0) return false;
   for(int k = 1; k <= depth; ++k)
   {
      if(iLow(_Symbol, PERIOD_H1, shift - k) <= l) return false;   // perf-allowed
      if(iLow(_Symbol, PERIOD_H1, shift + k) <  l) return false;   // perf-allowed
   }
   return true;
}

// Scan back over the closed-bar window, collect alternating swing extremes, and
// fix the most recent COMPLETED measured leg A->B where |B-A| >= leg_min*ATR.
// B is the more-recent (lower-shift) confirmed extreme; A the prior opposite one.
// Runs once per closed bar (QM_IsNewBar-gated). O(scan_bars) — bounded & cheap.
void AdvanceState_OnNewBar()
{
   const double atr = ATR_H1();

   // Reset leg; will re-establish from the scan.
   bool   found = false;
   int    found_dir = 0;
   double pA = 0.0, pB = 0.0;
   datetime tB = 0;

   const int depth = strategy_fractal_depth;
   const int total = Bars(_Symbol, PERIOD_H1);              // perf-allowed (bound only)
   int max_shift = strategy_swing_scan_bars;
   if(max_shift > total - depth - 2) max_shift = total - depth - 2;
   if(max_shift < depth + 2) { g_leg_valid = false; return; }

   // Walk from most-recent confirmable swing (shift = depth+1) outward to oldest.
   // First confirmed extreme = B; the next opposite-type confirmed extreme = A.
   int    b_type = 0;        // +1 high, -1 low
   double b_price = 0.0;
   datetime b_time = 0;
   bool   have_b = false;

   for(int s = depth + 1; s <= max_shift && !found; ++s)
   {
      const bool sh = IsSwingHigh(s, depth);
      const bool sl = IsSwingLow(s, depth);
      if(!sh && !sl) continue;
      const int    s_type  = sh ? +1 : -1;
      const double s_price = sh ? iHigh(_Symbol, PERIOD_H1, s) : iLow(_Symbol, PERIOD_H1, s); // perf-allowed
      const datetime s_time = iTime(_Symbol, PERIOD_H1, s);    // perf-allowed

      if(!have_b)
      {
         b_type = s_type; b_price = s_price; b_time = s_time; have_b = true;
         continue;
      }
      if(s_type == b_type)
      {
         // Same-direction extreme deeper in the past — keep the more extreme one
         // as the running B-anchor only if it has not yet been paired.
         if((b_type == +1 && s_price > b_price) || (b_type == -1 && s_price < b_price))
         { b_price = s_price; b_time = s_time; }
         continue;
      }

      // Opposite extreme = candidate A. Leg A(=s) -> B(=b_*).
      const double leg = b_price - s_price;        // signed B - A
      if(MathAbs(leg) >= strategy_leg_min_atr_mult * atr && atr > 0.0)
      {
         found = true;
         found_dir = (leg > 0.0) ? +1 : -1;
         pA = s_price; pB = b_price; tB = b_time;
      }
      else
      {
         // Leg too small — slide the anchor: this opposite extreme becomes the
         // new running B and keep scanning for a bigger paired leg.
         b_type = s_type; b_price = s_price; b_time = s_time;
      }
   }

   if(!found)
   {
      g_leg_valid = false;
      return;
   }

   g_leg_valid = true;
   g_leg_dir   = found_dir;
   g_price_A   = pA;
   g_price_B   = pB;
   g_leg_R     = pB - pA;            // signed
   g_time_B    = tB;

   const double R = MathAbs(g_leg_R);
   if(found_dir > 0)   // bullish leg: retrace DOWN from B
   {
      g_c1_level      = pB - strategy_fib_c1 * R;
      g_c2_level      = pB - strategy_fib_c2 * R;
      g_c3_level      = pB - strategy_fib_c3 * R;
      g_invalid_level = pB - strategy_fib_invalidation * R;
   }
   else                // bearish leg: retrace UP from B
   {
      g_c1_level      = pB + strategy_fib_c1 * R;
      g_c2_level      = pB + strategy_fib_c2 * R;
      g_c3_level      = pB + strategy_fib_c3 * R;
      g_invalid_level = pB + strategy_fib_invalidation * R;
   }
}

// Reversal-bar confirmation on the last CLOSED bar (shift 1).
// BUY: bar closes up with body >= ratio. SELL: closes down.
bool ReversalBarConfirms(const int dir)
{
   const double o = iOpen(_Symbol, PERIOD_H1, 1);   // perf-allowed
   const double c = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed
   const double h = iHigh(_Symbol, PERIOD_H1, 1);   // perf-allowed
   const double l = iLow(_Symbol, PERIOD_H1, 1);   // perf-allowed
   const double range = h - l;
   if(range <= 0.0) return false;
   const double body_ratio = MathAbs(c - o) / range;
   if(body_ratio < strategy_body_ratio_min) return false;
   if(dir > 0) return (c > o);
   return (c < o);
}

// True if the last closed bar's LOW (BUY) / HIGH (SELL) touched the C2 band.
bool C2Touched(const int dir, const double R)
{
   const double tol = strategy_c_tolerance_r * R;
   if(dir > 0)
   {
      const double lo = iLow(_Symbol, PERIOD_H1, 1);   // perf-allowed
      return (lo <= g_c2_level + tol && lo >= g_c2_level - tol - R); // reached at/below C2 within tol
   }
   const double hi = iHigh(_Symbol, PERIOD_H1, 1);   // perf-allowed
   return (hi >= g_c2_level - tol && hi <= g_c2_level + tol + R);
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-trade filter: fail-OPEN spread guard + broker-time rollover block. O(1).
bool Strategy_NoTradeFilter()
{
   // Rollover window: no new entry 22:00-23:00 broker time.
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(dt.hour == strategy_rollover_block_hour) return true;

   // Fail-OPEN spread guard: only block a genuinely wide spread. On .DWX the
   // tester quotes ask==bid (0 spread) -> never block.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = ATR_H1();
   if(ask > 0.0 && bid > 0.0 && ask > bid && atr > 0.0)
   {
      if((ask - bid) > strategy_spread_atr_mult * atr) return true;
   }
   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "GOODMAN_3C";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasPosition()) return false;
   if(!g_leg_valid) return false;

   const int dir = g_leg_dir;
   const double R = MathAbs(g_leg_R);
   if(R <= 0.0) return false;

   // Cool-down: a leg killed by hard-invalidation is dead for its continuation.
   if(g_time_B == g_dead_leg_time_B && dir == g_dead_leg_dir) return false;

   // Not invalidated: price has not closed beyond the 0.786 deep-retrace level.
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed
   if(close1 <= 0.0) return false;
   if(dir > 0 && close1 <= g_invalid_level) return false;
   if(dir < 0 && close1 >= g_invalid_level) return false;

   // C2 (median) retrace — the single Goodman-canonical TRIGGER.
   if(!C2Touched(dir, R)) return false;

   // Reversal-bar confirmation in the continuation direction.
   if(!ReversalBarConfirms(dir)) return false;

   // Macro-bias agreement: close vs EMA(50).
   const double ema = QM_EMA(_Symbol, PERIOD_H1, strategy_ema_period, 1);
   if(ema <= 0.0) return false;
   if(dir > 0 && !(close1 > ema)) return false;
   if(dir < 0 && !(close1 < ema)) return false;

   const QM_OrderType side = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   const double atr = ATR_H1();
   if(atr <= 0.0) return false;

   // SL: at C3 (deeper Cx beyond the C2 entry) + ATR cushion. Cap at 1.0*R.
   double sl;
   if(side == QM_BUY)
      sl = g_c3_level - strategy_sl_cushion_atr * atr;
   else
      sl = g_c3_level + strategy_sl_cushion_atr * atr;

   const double sl_cap = strategy_sl_cap_r * R;
   double sl_dist = MathAbs(entry - sl);
   if(sl_dist > sl_cap)
   {
      sl = (side == QM_BUY) ? entry - sl_cap : entry + sl_cap;
      sl_dist = sl_cap;
   }
   if(sl_dist <= 0.0) return false;

   // TP: project R_mult * |R| from entry (Goodman next-leg = prior-leg size).
   const double tp = (side == QM_BUY) ? entry + strategy_tp_r_mult * R
                                      : entry - strategy_tp_r_mult * R;

   req.type             = side;
   req.price            = 0.0;
   req.sl               = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp               = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason           = (side == QM_BUY) ? "GOODMAN_3C_BUY" : "GOODMAN_3C_SELL";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   g_entry_bar_time = iTime(_Symbol, PERIOD_H1, 0);   // perf-allowed
   g_be_done        = false;
   return true;
}

// One-time break-even shift after +0.5 R. O(1) per tick.
void Strategy_ManageOpenPosition()
{
   if(g_be_done) return;
   if(!HasPosition()) return;
   if(!g_leg_valid) return;

   const double R = MathAbs(g_leg_R);
   if(R <= 0.0) return;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const bool is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double px = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double moved = is_long ? (px - open_price) : (open_price - px);
      if(moved >= strategy_be_trigger_r * R)
      {
         QM_TM_MoveSL(t, QM_TM_NormalizePrice(_Symbol, open_price), "BE_0.5R");
         g_be_done = true;
      }
   }
}

// Discretionary exits: hard-invalidation, time-stop. (SL/TP handled by broker.)
bool Strategy_ExitSignal()
{
   if(!HasPosition()) return false;

   const bool is_long = PositionIsLong();
   const double close1 = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed

   // Hard-invalidation exit + mark the leg dead (cool-down).
   if(g_leg_valid && close1 > 0.0)
   {
      const bool invalidated = is_long ? (close1 <= g_invalid_level)
                                       : (close1 >= g_invalid_level);
      if(invalidated)
      {
         g_dead_leg_time_B = g_time_B;
         g_dead_leg_dir    = g_leg_dir;
         return true;
      }
   }

   // Time-stop: 30 H1 bars without TP/SL.
   if(g_entry_bar_time > 0)
   {
      const int bars_since = iBarShift(_Symbol, PERIOD_H1, g_entry_bar_time, false); // perf-allowed
      if(bars_since >= strategy_time_stop_bars) return true;
   }
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false; // defer to QM_NewsAllowsTrade(...)
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------
int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id, qm_magic_slot_offset, RISK_PERCENT, RISK_FIXED, PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy, qm_friday_close_enabled, qm_friday_close_hour_broker,
                        30, 30, qm_news_stale_max_hours, qm_news_min_impact, qm_rng_seed,
                        qm_stress_reject_probability, qm_news_temporal, qm_news_compliance))
      return INIT_FAILED;

   g_last_scan_bar   = 0;
   g_leg_valid       = false;
   g_entry_bar_time  = 0;
   g_be_done         = false;
   g_dead_leg_time_B = 0;
   g_dead_leg_dir    = 0;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1369\",\"strategy\":\"goodman-wave-theory-3c-h1\"}");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
}

void OnTick()
{
   if(!QM_KillSwitchCheck()) return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now)) return;
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows) return;
   if(QM_FrameworkHandleFridayClose()) return;

   if(Strategy_NoTradeFilter()) return;

   // Per-tick: trade management (break-even) + discretionary exits.
   Strategy_ManageOpenPosition();
   if(Strategy_ExitSignal())
   {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
      {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
      }
   }

   // Per-closed-bar gate — single consume.
   if(!QM_IsNewBar()) return;

   AdvanceState_OnNewBar();
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
   {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
   }
}

void OnTimer() { QM_FrameworkOnTimer(); }
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result) { QM_FrameworkOnTradeTransaction(trans, request, result); }
double OnTester() { QM_ChartUI_Refresh(); return QM_DefaultObjective(); }
