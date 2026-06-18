#property strict
#property version   "5.0"
#property description "QM5_1389 Goodman Wave Theory Measured-Move Projection H1"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_1389 — Goodman Wave Theory: Measured-Move Projection (H1)
// -----------------------------------------------------------------------------
// 4-pivot ABCD wave-equality structure. A ZigZag/fractal swing detector on CLOSED
// bars identifies three alternating swing extremes A (impulse-1 start), B
// (impulse-1 end / correction start) and C (correction end). The measured-move
// target is D = C + (B - A) (BUY) / C - (A - B) (SELL): impulse-2 equals impulse-1.
//
// The leg structure {A,B,C,D_target} is STATE (advanced once per closed bar).
// The single Goodman-canonical TRIGGER EVENT is the breakout-of-B confirming the
// correction is complete and impulse-2 has resumed (close[1] > B for BUY), while
// price is still within the first 30% of the C->D zone (not chasing).
//
// Gates: |B-A| >= 1.5*ATR(D1) (meaningful impulse); correction (B-C)/(B-A) in
// [0.30,0.80]; freshness (C within 30 H1 bars, A within 100); macro-bias close vs
// SMA(50,H1); H1-ATR floor & regime ceiling; session 07:00-20:00 broker; no new
// Friday entries after 18:00 broker; spread fail-OPEN; one position per magic.
//
// Exits: TP = D_target (fixed at entry); SL = C -/+ 0.3*ATR(H1); wave-failure if
// price retraces beyond A; time-stop 48 H1 bars; partial-TP 50% at the C->D
// midpoint then BE on remainder + prior-bar swing trail. Re-use guard: no second
// trade on the same (A,B,C) triple for 48 H1 bars.
//
// Swing detection is bespoke structural logic; raw iHigh/iLow/iClose/iOpen/iTime
// on CLOSED bars run inside a single QM_IsNewBar()-gated per-bar scan
// (perf-allowed). Indicator math (ATR, SMA) uses the pooled QM_* readers. The
// per-tick path is O(1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1389;
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
// Swing / ABCD-pivot detection
input int    strategy_fractal_depth       = 8;     // ZigZag depth: bars each side of a swing extreme
input int    strategy_swing_scan_bars     = 100;   // closed-bar window scanned for A,B,C pivots
input int    strategy_atr_period          = 14;
// Wave-magnitude & retracement gates
input double strategy_leg_min_atr_d1_mult = 1.5;   // |B-A| >= 1.5 * ATR(14,D1)
input double strategy_retrace_min         = 0.30;  // (B-C)/(B-A) lower bound
input double strategy_retrace_max         = 0.80;  // (B-C)/(B-A) upper bound
// Freshness (in H1 bars from now)
input int    strategy_c_max_age_bars      = 30;    // C completed within last 30 H1 bars
input int    strategy_a_max_age_bars      = 100;   // A within last 100 H1 bars
// Entry-zone & confirmation
input double strategy_entry_zone_frac     = 0.30;  // enter only within first 30% of C->D
input int    strategy_sma_period          = 50;    // macro-bias SMA(H1)
// Volatility gates
input int    strategy_vol_floor_lookback  = 20;    // ATR[1] >= 0.7 * ATR[lookback]
input double strategy_vol_floor_mult       = 0.7;
input int    strategy_vol_ceiling_lookback = 60;   // skip if ATR[1] > 2.5 * ATR[ceiling_lb]
input double strategy_vol_ceiling_mult     = 2.5;
// Exit
input double strategy_sl_atr_mult         = 0.3;   // SL = C -/+ 0.3 * ATR(H1)
input int    strategy_time_stop_bars      = 48;    // ~2 trading days on H1
input double strategy_partial_frac        = 0.50;  // close 50% at C->D midpoint
input double strategy_partial_trigger     = 0.50;  // midpoint = 50% of C->D
// Filters
input double strategy_spread_atr_mult     = 0.4;   // block if spread > 0.4 * ATR (fail-OPEN on 0)
input int    strategy_session_start_hour  = 7;     // 07:00 broker time
input int    strategy_session_end_hour    = 20;    // 20:00 broker time
input int    strategy_friday_cutoff_hour  = 18;    // no new entries after 18:00 Fri broker

// -----------------------------------------------------------------------------
// File-scope state (advanced once per closed bar)
// -----------------------------------------------------------------------------
datetime g_last_scan_bar    = 0;

// ABCD structure
bool     g_struct_valid     = false;
int      g_dir              = 0;       // +1 bullish, -1 bearish
double   g_price_A          = 0.0;
double   g_price_B          = 0.0;
double   g_price_C          = 0.0;
double   g_D_target         = 0.0;
datetime g_time_A           = 0;
datetime g_time_B           = 0;
datetime g_time_C           = 0;

// Re-use guard: a given (A,B,C) triple cannot be re-entered for 48 H1 bars
datetime g_used_time_C      = 0;
int      g_used_dir         = 0;
datetime g_used_at_bar      = 0;

// Open-trade bookkeeping
datetime g_entry_bar_time   = 0;
double   g_trade_A          = 0.0;     // A-level captured at entry (wave-failure ref)
double   g_trade_C          = 0.0;
double   g_trade_D          = 0.0;
int      g_trade_dir        = 0;
bool     g_partial_done     = false;

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------
double ATR_H1(const int shift)
{
   return QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, shift);
}

double ATR_D1()
{
   return QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
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

// Fractal swing test on CLOSED bars: bar at `shift` is a swing-high if its high is
// strictly the highest within `depth` bars on each side (mirror for low). Reads
// closed bars only (shift >= 1). perf-allowed: bespoke structural logic.
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

// Scan the closed-bar window for the three most-recent ALTERNATING swing extremes:
//   C = most recent confirmed extreme, B = prior opposite extreme, A = prior again.
// Then validate the Goodman measured-move structure and compute D_target.
// Runs once per closed bar (QM_IsNewBar-gated). O(scan_bars * depth) — bounded.
void AdvanceState_OnNewBar()
{
   g_struct_valid = false;

   const int depth = strategy_fractal_depth;
   const int total = Bars(_Symbol, PERIOD_H1);             // perf-allowed (bound only)
   int max_shift = strategy_swing_scan_bars;
   if(max_shift > total - depth - 2) max_shift = total - depth - 2;
   if(max_shift < depth + 2) return;

   // Collect up to 3 alternating extremes from most-recent (low shift) outward.
   int      piv_type[3];   // +1 high, -1 low
   double   piv_price[3];
   datetime piv_time[3];
   int      n = 0;
   int      last_type = 0;

   for(int s = depth + 1; s <= max_shift && n < 3; ++s)
   {
      const bool sh = IsSwingHigh(s, depth);
      const bool sl = IsSwingLow(s, depth);
      if(!sh && !sl) continue;
      const int    s_type  = sh ? +1 : -1;
      const double s_price = sh ? iHigh(_Symbol, PERIOD_H1, s)
                                : iLow(_Symbol, PERIOD_H1, s);   // perf-allowed
      const datetime s_time = iTime(_Symbol, PERIOD_H1, s);      // perf-allowed

      if(n == 0)
      {
         piv_type[0] = s_type; piv_price[0] = s_price; piv_time[0] = s_time;
         last_type = s_type; n = 1;
         continue;
      }
      if(s_type == last_type)
      {
         // Same-direction extreme deeper in the past: keep the more-extreme one as
         // the current alternating anchor (extends the leg further back).
         if((s_type == +1 && s_price > piv_price[n-1]) ||
            (s_type == -1 && s_price < piv_price[n-1]))
         {
            piv_price[n-1] = s_price; piv_time[n-1] = s_time;
         }
         continue;
      }
      // Opposite extreme — next pivot in the alternating sequence.
      piv_type[n] = s_type; piv_price[n] = s_price; piv_time[n] = s_time;
      last_type = s_type; n++;
   }

   if(n < 3) return;

   // Sequence is [C, B, A] (most-recent first). Map to A,B,C (oldest -> newest).
   const int    C_type  = piv_type[0];
   const double C_price = piv_price[0];
   const datetime C_time = piv_time[0];
   const double B_price = piv_price[1];
   const datetime B_time = piv_time[1];
   const double A_price = piv_price[2];
   const datetime A_time = piv_time[2];

   // Direction: bullish measured-move has C as a swing-LOW (correction bottom),
   // B as a swing-HIGH (impulse-1 top), A as a swing-LOW (impulse-1 start).
   int dir = 0;
   if(C_type == -1)      dir = +1;   // BUY: A(low) < B(high) > C(low)
   else                  dir = -1;   // SELL: A(high) > B(low) < C(high)

   // Structure ordering (Goodman canonical: correction shallow, C does not breach A).
   if(dir > 0)
   {
      // A<B, B>C, C>A
      if(!(A_price < B_price && B_price > C_price && C_price > A_price)) return;
   }
   else
   {
      // A>B, B<C, C<A
      if(!(A_price > B_price && B_price < C_price && C_price < A_price)) return;
   }

   // Wave-magnitude: impulse-1 meaningful vs daily ATR.
   const double atr_d1 = ATR_D1();
   if(atr_d1 <= 0.0) return;
   const double impulse1 = MathAbs(B_price - A_price);
   if(impulse1 < strategy_leg_min_atr_d1_mult * atr_d1) return;

   // Retracement ratio of the correction (B->C) vs impulse-1.
   const double correction = MathAbs(B_price - C_price);
   const double ratio = correction / impulse1;
   if(ratio < strategy_retrace_min || ratio > strategy_retrace_max) return;

   // Measured-move target: impulse-2 equals impulse-1, projected from C.
   const double D = (dir > 0) ? C_price + impulse1 : C_price - impulse1;

   g_struct_valid = true;
   g_dir       = dir;
   g_price_A   = A_price;
   g_price_B   = B_price;
   g_price_C   = C_price;
   g_D_target  = D;
   g_time_A    = A_time;
   g_time_B    = B_time;
   g_time_C    = C_time;
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No-trade filter: fail-OPEN spread guard + session/Friday gates (broker time). O(1).
bool Strategy_NoTradeFilter()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);   // broker time

   // Session gate: only enter on bars closing 07:00-20:00 broker (skip Asian).
   if(dt.hour < strategy_session_start_hour || dt.hour >= strategy_session_end_hour)
      return true;

   // Friday gate: no new entries after 18:00 broker on Friday.
   if(dt.day_of_week == 5 && dt.hour >= strategy_friday_cutoff_hour)
      return true;

   // Fail-OPEN spread guard: only block a genuinely wide spread. On .DWX the tester
   // quotes ask==bid (0 spread) -> never block.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = ATR_H1(1);
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
   req.reason = "GOODMAN_MM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasPosition()) return false;
   if(!g_struct_valid) return false;

   const int dir = g_dir;
   const double A = g_price_A;
   const double B = g_price_B;
   const double C = g_price_C;
   const double D = g_D_target;
   const double cd = D - C;             // signed C->D span
   if(MathAbs(cd) <= 0.0) return false;

   // Re-use guard: same (A,B,C) triple cannot be re-entered within 48 H1 bars.
   if(g_time_C == g_used_time_C && dir == g_used_dir && g_used_at_bar > 0)
   {
      const int bars_since_use = iBarShift(_Symbol, PERIOD_H1, g_used_at_bar, false); // perf-allowed
      if(bars_since_use < strategy_time_stop_bars) return false;
   }

   // Wave-freshness: C and A young enough.
   const int c_age = iBarShift(_Symbol, PERIOD_H1, g_time_C, false);   // perf-allowed
   const int a_age = iBarShift(_Symbol, PERIOD_H1, g_time_A, false);   // perf-allowed
   if(c_age > strategy_c_max_age_bars) return false;
   if(a_age > strategy_a_max_age_bars) return false;

   const double close1 = iClose(_Symbol, PERIOD_H1, 1);   // perf-allowed
   if(close1 <= 0.0) return false;

   // Breakout-of-B: impulse-2 has resumed above (BUY) / below (SELL) the impulse-1
   // extreme — the single Goodman measured-move TRIGGER EVENT.
   if(dir > 0 && !(close1 > B)) return false;
   if(dir < 0 && !(close1 < B)) return false;

   // Position within the first 30% of the C->D zone (early in impulse-2, not chasing).
   const double progressed = (dir > 0) ? (close1 - C) : (C - close1);
   const double span = MathAbs(cd);
   if(progressed <= 0.0) return false;
   if(progressed / span > strategy_entry_zone_frac) return false;

   // Macro-bias gate: close vs SMA(50,H1).
   const double sma = QM_SMA(_Symbol, PERIOD_H1, strategy_sma_period, 1);
   if(sma <= 0.0) return false;
   if(dir > 0 && !(close1 > sma)) return false;
   if(dir < 0 && !(close1 < sma)) return false;

   // Volatility floor + regime ceiling.
   const double atr1 = ATR_H1(1);
   const double atr_floor = ATR_H1(strategy_vol_floor_lookback);
   const double atr_ceiling = ATR_H1(strategy_vol_ceiling_lookback);
   if(atr1 <= 0.0) return false;
   if(atr_floor > 0.0 && atr1 < strategy_vol_floor_mult * atr_floor) return false;
   if(atr_ceiling > 0.0 && atr1 > strategy_vol_ceiling_mult * atr_ceiling) return false;

   const QM_OrderType side = (dir > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0) return false;

   // SL just beyond the C-pivot: C -/+ 0.3 * ATR(H1). TP = measured-move D_target.
   double sl = (side == QM_BUY) ? C - strategy_sl_atr_mult * atr1
                                : C + strategy_sl_atr_mult * atr1;
   const double tp = D;

   // Guard: SL must sit on the correct side of entry, TP on the other.
   if(side == QM_BUY  && !(sl < entry && tp > entry)) return false;
   if(side == QM_SELL && !(sl > entry && tp < entry)) return false;

   req.type             = side;
   req.price            = 0.0;
   req.sl               = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp               = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason           = (side == QM_BUY) ? "GOODMAN_MM_BUY" : "GOODMAN_MM_SELL";
   req.symbol_slot      = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // Capture trade-scoped structure for management/exits + arm the re-use guard.
   g_entry_bar_time = iTime(_Symbol, PERIOD_H1, 0);   // perf-allowed
   g_trade_A        = A;
   g_trade_C        = C;
   g_trade_D        = D;
   g_trade_dir      = dir;
   g_partial_done   = false;

   g_used_time_C    = g_time_C;
   g_used_dir       = dir;
   g_used_at_bar    = g_entry_bar_time;
   return true;
}

// Partial-TP at the C->D midpoint, then BE on the remainder + prior-bar swing trail.
// O(1) per tick (single closed-bar reads).
void Strategy_ManageOpenPosition()
{
   if(!HasPosition()) return;
   if(g_trade_dir == 0) return;

   const double mid = g_trade_C + strategy_partial_trigger * (g_trade_D - g_trade_C);

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic) continue;

      const bool is_long = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double px = is_long ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      const bool past_mid = is_long ? (px >= mid) : (px <= mid);

      if(!g_partial_done && past_mid)
      {
         // Close 50% and move SL on the remainder to break-even.
         const double vol = PositionGetDouble(POSITION_VOLUME);
         const double part = QM_TM_NormalizeVolume(_Symbol, vol * strategy_partial_frac);
         if(part > 0.0)
            QM_TM_PartialClose(t, part, QM_EXIT_STRATEGY);
         QM_TM_MoveSL(t, QM_TM_NormalizePrice(_Symbol, open_price), "MM_PARTIAL_BE");
         g_partial_done = true;
      }
      else if(g_partial_done)
      {
         // Prior-bar swing trail on the remaining position.
         const double prev_low  = iLow(_Symbol, PERIOD_H1, 1);    // perf-allowed
         const double prev_high = iHigh(_Symbol, PERIOD_H1, 1);   // perf-allowed
         const double cur_sl = PositionGetDouble(POSITION_SL);
         if(is_long)
         {
            if(prev_low > cur_sl && prev_low < px)
               QM_TM_MoveSL(t, QM_TM_NormalizePrice(_Symbol, prev_low), "MM_TRAIL");
         }
         else
         {
            if((cur_sl == 0.0 || prev_high < cur_sl) && prev_high > px)
               QM_TM_MoveSL(t, QM_TM_NormalizePrice(_Symbol, prev_high), "MM_TRAIL");
         }
      }
   }
}

// Discretionary exits: wave-failure (retrace beyond A) + time-stop. (TP/SL by broker.)
bool Strategy_ExitSignal()
{
   if(!HasPosition()) return false;
   if(g_trade_dir == 0) return false;

   const bool is_long = PositionIsLong();

   // Wave-failure: impulse-2 retraces beyond A -> ABCD structure invalidated.
   const double low1  = iLow(_Symbol, PERIOD_H1, 1);    // perf-allowed
   const double high1 = iHigh(_Symbol, PERIOD_H1, 1);   // perf-allowed
   if(is_long && low1 > 0.0 && low1 < g_trade_A)  return true;
   if(!is_long && high1 > 0.0 && high1 > g_trade_A) return true;

   // Time-stop: 48 H1 bars (~2 trading days) without TP/SL/wave-failure.
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

   g_last_scan_bar  = 0;
   g_struct_valid   = false;
   g_entry_bar_time = 0;
   g_trade_dir      = 0;
   g_partial_done   = false;
   g_used_time_C    = 0;
   g_used_dir       = 0;
   g_used_at_bar    = 0;
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1389\",\"strategy\":\"goodman-wave-theory-measured-move-h1\"}");
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

   // Per-tick: trade management (partial/BE/trail) + discretionary exits.
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

   // Entry no-trade filter only gates NEW entries (not management/exits above).
   if(Strategy_NoTradeFilter()) return;

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
