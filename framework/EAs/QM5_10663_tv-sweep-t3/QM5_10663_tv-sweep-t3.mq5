#property strict
#property version   "5.0"
#property description "QM5_10663 tv-sweep-t3 — liquidity sweep + T3 turn + BOS/strong-close confirmation"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_10663 tv-sweep-t3
// -----------------------------------------------------------------------------
// Source: chervolino "Sweep2Trade Pro [CHE]" (TradingView), card QM5_10663.
//
// Mechanic (baseline, P2):
//   - Self-computed T3 (Tillson) moving average; direction = T3[1] vs T3[2].
//   - R-squared trend-quality filter over a lookback of closes; trade only when
//     R-squared >= threshold.
//   - LONG sequence (short mirrors):
//       1. Bullish liquidity sweep: a recent bar pokes BELOW the prior swing low
//          and closes back ABOVE it (stop-run + reclaim).
//       2. After the sweep, a finite-state machine waits (up to a timeout, in
//          bars) for T3 to turn UP.
//       3. Final confirmation within the timeout: bullish BOS through the recent
//          swing high (close-mode, baseline) AND a strong close in the top
//          quartile of the candle range.
//       4. Enter LONG on the next bar (i.e. when the confirmation bar has
//          closed). Stop just beyond the sweep wick; TP at 2R.
//   - One position per magic. No pyramiding / re-entry (card forbids it).
//
// All strategy state advances ONCE per closed bar (sweep detection, swing
// levels, T3 cascade, FSM). The per-tick path only fires the queued entry.
// T3 is computed by a single forward EMA-cascade reconstruction from closed
// bars — no lazy handle, no per-tick CopyRates. (.DWX invariant: decouple
// sweep from confirmation across bars; T3 self-computed; fail-open spread;
// points->pips via framework helpers.)
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10663;
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
// --- T3 (Tillson) moving average ---
input int    InpT3Period                = 8;      // T3 length (EMA cascade base)
input double InpT3VFactor               = 0.7;    // T3 volume/hot factor (0..1)
// --- R-squared trend-quality filter ---
input int    InpRsqLookback             = 20;     // bars for linear-regression R^2
input double InpRsqThreshold            = 0.20;   // min R^2 to allow entries
// --- Structure / swing detection ---
input int    InpSwingLookback           = 10;     // bars each side for swing pivots
input int    InpSweepScanBars           = 6;      // recent bars scanned for a sweep
// --- Finite-state machine ---
input int    InpConfirmTimeoutBars      = 8;      // bars allowed sweep -> confirmation
// --- Confirmation strength ---
input double InpStrongCloseQuartile     = 0.75;   // close must be in top/bottom 25% of range
input bool   InpRequireCloseBeyondT3    = false;  // P3 strict: long needs close>T3 (short close<T3)
// --- Exit ---
input double InpTargetRR                = 2.0;    // take-profit at 2R
input double InpStopBufferPips          = 2.0;    // extra pips beyond the sweep wick

// -----------------------------------------------------------------------------
// File-scope cached strategy state (advanced once per closed bar)
// -----------------------------------------------------------------------------
// T3 cascade: six successive EMAs. Maintained recursively across bars so we
// never recompute a deep warmup window per tick.
double g_t3_e1 = 0.0, g_t3_e2 = 0.0, g_t3_e3 = 0.0;
double g_t3_e4 = 0.0, g_t3_e5 = 0.0, g_t3_e6 = 0.0;
bool   g_t3_seeded = false;
double g_t3_curr   = 0.0;   // T3 on last closed bar (shift 1)
double g_t3_prev   = 0.0;   // T3 on the bar before that (shift 2)
int    g_t3_bars   = 0;     // closed bars folded into the cascade

// Tillson T3 coefficients (derived from v-factor once at init).
double g_t3_c1 = 0.0, g_t3_c2 = 0.0, g_t3_c3 = 0.0, g_t3_c4 = 0.0;
double g_t3_alpha = 0.0;

// Most recent confirmed swing levels (from closed bars).
double g_swing_high  = 0.0;
double g_swing_low   = 0.0;
bool   g_have_swings = false;

// FSM state. dir: 0 = idle, +1 = long setup armed, -1 = short setup armed.
int      g_fsm_dir        = 0;
int      g_fsm_age        = 0;      // bars since the sweep fired
double   g_fsm_sweep_wick = 0.0;    // extreme of the sweep bar (low for long, high for short)
double   g_fsm_swing_ref  = 0.0;    // BOS reference level captured at sweep time

// Queued entry produced by the new-bar evaluation, consumed on the next tick.
bool         g_entry_ready = false;
QM_OrderType g_entry_type  = QM_BUY;
double       g_entry_sl    = 0.0;

// -----------------------------------------------------------------------------
// T3 helpers
// -----------------------------------------------------------------------------
void T3_InitCoeffs()
  {
   const double a  = InpT3VFactor;
   const double a2 = a * a;
   const double a3 = a2 * a;
   g_t3_c1 = -a3;
   g_t3_c2 = 3.0 * a2 + 3.0 * a3;
   g_t3_c3 = -6.0 * a2 - 3.0 * a - 3.0 * a3;
   g_t3_c4 = 1.0 + 3.0 * a + a3 + 3.0 * a2;
   const int period = (InpT3Period < 1) ? 1 : InpT3Period;
   g_t3_alpha = 2.0 / (period + 1.0);
  }

double T3_Ema(const double prev, const double price, const bool seeded)
  {
   if(!seeded)
      return price;
   return prev + g_t3_alpha * (price - prev);
  }

// Fold ONE closed-bar close into the six-stage EMA cascade and update T3.
void T3_Advance(const double close_price)
  {
   const bool seeded = g_t3_seeded;
   g_t3_e1 = T3_Ema(g_t3_e1, close_price, seeded);
   g_t3_e2 = T3_Ema(g_t3_e2, g_t3_e1,     seeded);
   g_t3_e3 = T3_Ema(g_t3_e3, g_t3_e2,     seeded);
   g_t3_e4 = T3_Ema(g_t3_e4, g_t3_e3,     seeded);
   g_t3_e5 = T3_Ema(g_t3_e5, g_t3_e4,     seeded);
   g_t3_e6 = T3_Ema(g_t3_e6, g_t3_e5,     seeded);
   g_t3_seeded = true;

   const double t3 = g_t3_c1 * g_t3_e6 + g_t3_c2 * g_t3_e5 +
                     g_t3_c3 * g_t3_e4 + g_t3_c4 * g_t3_e3;
   g_t3_prev = g_t3_curr;
   g_t3_curr = t3;
   g_t3_bars++;
  }

// Backfill the cascade from history the first time we run, so T3 direction is
// valid immediately rather than after a live warmup. One pass, oldest->newest,
// over closed bars only. Returns true when seeded.
bool T3_Backfill()
  {
   const int warm = 6 * ((InpT3Period < 1) ? 1 : InpT3Period) + 10;
   const int avail = Bars(_Symbol, _Period);
   if(avail < warm + 2)
      return false;
   // Oldest first: shift = warm down to 1 (closed bars only).
   for(int shift = warm; shift >= 1; --shift)
     {
      const double c = iClose(_Symbol, _Period, shift);
      if(c <= 0.0)
         continue;
      T3_Advance(c);
     }
   return g_t3_bars >= 2;
  }

// -----------------------------------------------------------------------------
// R-squared (coefficient of determination) of close vs bar index over lookback.
// Measures how linearly trending the recent closes are. Closed bars only.
// -----------------------------------------------------------------------------
double Compute_RSquared(const int lookback)
  {
   const int n = (lookback < 3) ? 3 : lookback;
   double sx = 0.0, sy = 0.0, sxx = 0.0, syy = 0.0, sxy = 0.0;
   int cnt = 0;
   for(int k = 0; k < n; ++k)
     {
      const int shift = k + 1;                 // closed bars: 1..n
      const double y = iClose(_Symbol, _Period, shift);
      if(y <= 0.0)
         continue;
      const double x = (double)k;
      sx  += x;   sy  += y;
      sxx += x * x; syy += y * y;
      sxy += x * y;
      cnt++;
     }
   if(cnt < 3)
      return 0.0;
   const double dn   = cnt;
   const double cov  = sxy - (sx * sy) / dn;
   const double varx = sxx - (sx * sx) / dn;
   const double vary = syy - (sy * sy) / dn;
   if(varx <= 0.0 || vary <= 0.0)
      return 0.0;
   const double r = cov / MathSqrt(varx * vary);
   return r * r;
  }

// -----------------------------------------------------------------------------
// Swing pivots from closed bars. A confirmed swing high at center index c needs
// `lb` bars on each side that are lower; mirror for swing low. We take the most
// recent confirmed pivots that sit safely in the past (so they are not the very
// bars we sweep). Closed bars only.
// -----------------------------------------------------------------------------
void Update_SwingLevels(const int lb)
  {
   const int lookback = (lb < 2) ? 2 : lb;
   const int scan = 2 * lookback + InpSweepScanBars + 5;
   double last_high = 0.0;
   double last_low  = 0.0;
   bool   got_high  = false;
   bool   got_low   = false;

   // Center candidate c must have `lookback` confirmed bars on each side; the
   // newest valid center is at shift = lookback+1 (so center stays in the past).
   for(int c = lookback + 1; c <= scan; ++c)
     {
      const double ch = iHigh(_Symbol, _Period, c);
      const double cl = iLow(_Symbol, _Period, c);
      if(ch <= 0.0 || cl <= 0.0)
         continue;

      bool is_high = true;
      bool is_low  = true;
      for(int s = 1; s <= lookback; ++s)
        {
         const double rh = iHigh(_Symbol, _Period, c - s);
         const double lh = iHigh(_Symbol, _Period, c + s);
         const double rl = iLow(_Symbol, _Period, c - s);
         const double ll = iLow(_Symbol, _Period, c + s);
         if(rh <= 0.0 || lh <= 0.0 || rl <= 0.0 || ll <= 0.0)
           { is_high = false; is_low = false; break; }
         if(ch <= rh || ch <= lh) is_high = false;
         if(cl >= rl || cl >= ll) is_low  = false;
         if(!is_high && !is_low) break;
        }

      if(is_high && !got_high) { last_high = ch; got_high = true; }
      if(is_low  && !got_low ) { last_low  = cl; got_low  = true; }
      if(got_high && got_low) break;
     }

   if(got_high) g_swing_high = last_high;
   if(got_low)  g_swing_low  = last_low;
   g_have_swings = (g_swing_high > 0.0 && g_swing_low > 0.0);
  }

// -----------------------------------------------------------------------------
// Strong-close test: close in the top (long) / bottom (short) quartile of the
// bar's range. quartile arg is the fraction defining "strong" (default 0.75).
// -----------------------------------------------------------------------------
bool Is_StrongClose(const int shift, const bool bullish)
  {
   const double hi = iHigh(_Symbol, _Period, shift);
   const double lo = iLow(_Symbol, _Period, shift);
   const double cl = iClose(_Symbol, _Period, shift);
   const double rng = hi - lo;
   if(rng <= 0.0)
      return false;
   const double pos = (cl - lo) / rng;             // 0 = at low, 1 = at high
   if(bullish)
      return pos >= InpStrongCloseQuartile;
   return pos <= (1.0 - InpStrongCloseQuartile);
  }

// -----------------------------------------------------------------------------
// New-bar state machine. Runs ONCE per closed bar (caller gates on QM_IsNewBar).
//   step 1: advance T3 + swing levels + R^2
//   step 2: detect a fresh sweep -> arm the FSM
//   step 3: if armed, age the FSM, check T3 turn + BOS + strong close -> queue
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   // --- step 1: fold the just-closed bar (shift 1) into cached state ---
   const double close1 = iClose(_Symbol, _Period, 1);
   if(close1 > 0.0)
      T3_Advance(close1);
   Update_SwingLevels(InpSwingLookback);

   const double rsq = Compute_RSquared(InpRsqLookback);
   const bool trend_ok = (rsq >= InpRsqThreshold);

   // --- age / expire an armed setup ---
   if(g_fsm_dir != 0)
     {
      g_fsm_age++;
      if(g_fsm_age > InpConfirmTimeoutBars)
         g_fsm_dir = 0;   // timeout reset
     }

   if(!g_have_swings)
      return;

   // --- step 2: detect a fresh liquidity sweep on a recent closed bar ---
   // Bullish sweep: a recent bar's LOW pokes below g_swing_low but its CLOSE is
   // back above g_swing_low (stop-run + reclaim). Bearish mirrors with the high.
   // Scan most-recent-first; the just-closed bar (shift 1) is the freshest.
   if(g_fsm_dir == 0 && trend_ok)
     {
      const int scan = (InpSweepScanBars < 1) ? 1 : InpSweepScanBars;
      for(int s = 1; s <= scan; ++s)
        {
         const double lo = iLow(_Symbol, _Period, s);
         const double hi = iHigh(_Symbol, _Period, s);
         const double cl = iClose(_Symbol, _Period, s);
         if(lo <= 0.0 || hi <= 0.0 || cl <= 0.0)
            continue;

         // bullish sweep + reclaim of swing low
         if(lo < g_swing_low && cl > g_swing_low)
           {
            g_fsm_dir        = +1;
            g_fsm_age        = 0;
            g_fsm_sweep_wick = lo;
            g_fsm_swing_ref  = g_swing_high;   // BOS target for the long
            break;
           }
         // bearish sweep + reclaim of swing high
         if(hi > g_swing_high && cl < g_swing_high)
           {
            g_fsm_dir        = -1;
            g_fsm_age        = 0;
            g_fsm_sweep_wick = hi;
            g_fsm_swing_ref  = g_swing_low;    // BOS target for the short
            break;
           }
        }
     }

   if(g_fsm_dir == 0)
      return;

   // --- step 3: confirmation on the just-closed bar (shift 1) ---
   const double c1     = iClose(_Symbol, _Period, 1);
   const bool   t3_up  = (g_t3_curr > g_t3_prev);
   const bool   t3_dn  = (g_t3_curr < g_t3_prev);

   if(g_fsm_dir > 0)
     {
      const bool bos     = (c1 > g_fsm_swing_ref);          // close-mode BOS up
      const bool strong  = Is_StrongClose(1, true);
      const bool t3_side = (!InpRequireCloseBeyondT3) || (c1 > g_t3_curr);
      if(t3_up && bos && strong && t3_side)
        {
         g_entry_ready = true;
         g_entry_type  = QM_BUY;
         const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpStopBufferPips));
         g_entry_sl    = g_fsm_sweep_wick - buf;            // stop beyond sweep wick
         g_fsm_dir     = 0;                                 // setup consumed
        }
     }
   else // g_fsm_dir < 0
     {
      const bool bos     = (c1 < g_fsm_swing_ref);          // close-mode BOS down
      const bool strong  = Is_StrongClose(1, false);
      const bool t3_side = (!InpRequireCloseBeyondT3) || (c1 < g_t3_curr);
      if(t3_dn && bos && strong && t3_side)
        {
         g_entry_ready = true;
         g_entry_type  = QM_SELL;
         const double buf = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(InpStopBufferPips));
         g_entry_sl    = g_fsm_sweep_wick + buf;
         g_fsm_dir     = 0;
        }
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick guard. No regime/session restriction beyond the R^2 trend
// filter (applied in the new-bar evaluation). Fail-OPEN on spread per .DWX
// invariant: only block a genuinely wide quoted spread, never zero spread.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Fires the queued entry produced by AdvanceState_OnNewBar. Caller guarantees
// QM_IsNewBar()==true. One position per magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_entry_ready)
      return false;
   g_entry_ready = false;   // single-shot; cleared whether or not we open

   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;         // one position per magic, no pyramiding

   const double entry_price = QM_EntryMarketPrice(g_entry_type);
   if(entry_price <= 0.0 || g_entry_sl <= 0.0)
      return false;

   // Validate stop is on the correct side and non-degenerate.
   if(g_entry_type == QM_BUY && g_entry_sl >= entry_price)
      return false;
   if(g_entry_type == QM_SELL && g_entry_sl <= entry_price)
      return false;

   req.type   = g_entry_type;
   req.price  = 0.0;        // market fill at send
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, g_entry_sl);
   req.tp     = QM_StopRulesNormalizePrice(_Symbol,
                  QM_TakeRR(_Symbol, g_entry_type, entry_price, g_entry_sl, InpTargetRR));
   req.reason = "sweep_t3_bos";
   return true;
  }

// SL/TP are set at entry (stop beyond sweep, TP at 2R). Baseline does not trail.
void Strategy_ManageOpenPosition()
  {
  }

// SL/TP fully define the exit for the baseline variant.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central QM news filter.
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

   T3_InitCoeffs();
   T3_Backfill();          // seed the cascade from history (closed bars only)

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

   // Advance closed-bar strategy state FIRST, then fire any queued entry.
   AdvanceState_OnNewBar();

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
