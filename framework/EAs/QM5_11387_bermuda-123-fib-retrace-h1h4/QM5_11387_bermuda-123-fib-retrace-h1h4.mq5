#property strict
#property version   "5.0"
#property description "QM5_11387 bermuda-123-fib-retrace-h1h4 — 1-2-3 reversal + Fibonacci retrace breakout (H1/H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11387 bermuda-123-fib-retrace-h1h4
// -----------------------------------------------------------------------------
// Source: "Forex Bermuda Trading Strategy" (anonymous, superiorfxsignals.com,
//         2012 PDF). Card:
//         artifacts/cards_approved/QM5_11387_bermuda-123-fib-retrace-h1h4.md
//         (g0_status APPROVED). Only the mechanizable 1-2-3 + Fibonacci
//         component is implemented; the discretionary triangle overlay is
//         excluded per the card.
//
// Mechanics (all reads on CLOSED bars at shift >= 1; non-repainting):
//   Swing pivots : N-bar fractal. A swing HIGH is confirmed at shift s when
//                  High[s] is the strict max over [s-N .. s+N]; a swing LOW
//                  when Low[s] is the strict min over the same window. A pivot
//                  is only ever CONFIRMED N bars after it printed (the +N side
//                  is in the past relative to the current closed bar), so the
//                  pattern can never repaint.
//   1-2-3 (bull) : Point1 = a confirmed swing LOW, Point2 = a later confirmed
//                  swing HIGH (P2 high > P1 low), Point3 = the most recent
//                  confirmed swing LOW after P2 with P3 low > P1 low (direction
//                  preserved) AND retrace depth
//                     (P2 - P3) / (P2 - P1)  in [fib_lo, fib_hi].
//   1-2-3 (bear) : mirror — P1 swing HIGH, P2 later swing LOW, P3 later swing
//                  HIGH with P3 < P1 and (P3 - P2)/(P1 - P2) in [fib_lo, fib_hi].
//   Entry EVENT  : a single trigger — the last CLOSED bar closes BEYOND P2
//                  (close > P2_high for LONG, close < P2_low for SHORT) within
//                  max_entry_bars closed bars of P3 confirmation. The structure
//                  detection (fractals) and the breakout-close happen on
//                  different bars, so there is no two-events-same-bar zero-trade
//                  trap.
//   Higher-TF    : an optional same-symbol H4 trend read (close vs EMA) can
//                  gate H1 entries; default OFF so the H1 and H4 variants both
//                  trade their own structure. When enabled it is a same-symbol
//                  aggregation only (no foreign feed).
//   Stop         : LONG = P3_low - sl_buffer_pips; SHORT = P3_high + sl_buffer.
//                  Skip the trade if the resulting stop distance exceeds
//                  sl_cap_pips (P2 50-pip cap).
//   Take profit  : Fib extension of the P1->P2 leg beyond P2.
//                  LONG  TP1 = P2 + tp1_ratio*(P2-P1); TP2 = P2 + tp2_ratio*(P2-P1).
//                  The order TP is placed at TP2 (full target). At TP1 we close
//                  partial_close_pct of the position once, then trail the
//                  remainder with ATR(trail_atr_period) * trail_atr_mult.
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Confirmed pivots + the active 1-2-3 structure are advanced ONCE per closed
// bar in AdvanceState_OnNewBar(); the per-tick path is O(1) over cached state.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11387;
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
input int    strategy_fractal_n          = 2;      // N-bar fractal half-window (card N=2 default; sweep 2/3/4)
input double strategy_fib_lo             = 0.236;  // min retrace depth of P1->P2 leg
input double strategy_fib_hi             = 0.618;  // max retrace depth of P1->P2 leg
input int    strategy_max_entry_bars     = 3;      // closed bars after P3 to allow the breakout entry
input int    strategy_sl_buffer_pips     = 5;      // buffer beyond P3 for the protective stop
input int    strategy_sl_cap_pips        = 50;     // P2 hard cap on stop distance; skip if wider
input double strategy_tp1_ratio          = 0.618;  // TP1 = P2 + ratio*(P2-P1) (Fib 161.8 extension)
input double strategy_tp2_ratio          = 1.618;  // TP2 = P2 + ratio*(P2-P1) (Fib 261.8 extension)
input double strategy_partial_close_pct  = 60.0;   // % of position closed at TP1
input int    strategy_trail_atr_period   = 14;     // ATR period for the post-TP1 trail
input double strategy_trail_atr_mult     = 0.5;    // ATR multiple for the post-TP1 trail
input int    strategy_pivot_scan_bars    = 240;    // closed-bar window scanned for pivots (bounded)
input bool   strategy_use_htf_filter     = false;  // gate entries by H4 EMA trend (same symbol)
input int    strategy_htf_ema_period     = 50;     // H4 EMA period when the HTF filter is enabled
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached 1-2-3 structure (advanced once per closed bar).
//   g_pattern_dir : +1 bullish 1-2-3 armed, -1 bearish, 0 none.
//   g_p1/p2/p3    : the three pattern price levels.
//   g_bars_since_p3 : closed bars elapsed since P3 was confirmed.
// -----------------------------------------------------------------------------
int      g_pattern_dir      = 0;
double   g_p1               = 0.0;   // Point 1 extreme (low for bull, high for bear)
double   g_p2               = 0.0;   // Point 2 extreme (high for bull, low for bear)
double   g_p3               = 0.0;   // Point 3 retrace extreme
int      g_bars_since_p3    = 0;

// Partial-close bookkeeping for the open position.
ulong    g_managed_ticket   = 0;     // ticket the partial/trail state belongs to
bool     g_partial_done     = false; // TP1 partial already taken on g_managed_ticket
double   g_tp1_price        = 0.0;   // cached TP1 level for the open position

// Pip distance for the active symbol (5-digit / JPY aware via StopRules).
double PipDistance(const int pips)
  {
   return QM_StopRulesPipsToPriceDistance(_Symbol, pips);
  }

// Is the bar at `shift` a confirmed N-bar fractal swing HIGH?
// Confirmed means High[shift] is the strict maximum over [shift-N .. shift+N].
// Requires shift >= N+1 so the +N look-ahead side is itself a closed bar.
bool IsSwingHigh(const int shift, const int n)
  {
   if(shift < n + 1)
      return false;
   const double h = iHigh(_Symbol, _Period, shift); // perf-allowed: per-closed-bar pivot scan
   if(h <= 0.0)
      return false;
   for(int k = 1; k <= n; ++k)
     {
      if(iHigh(_Symbol, _Period, shift - k) >= h) return false; // perf-allowed
      if(iHigh(_Symbol, _Period, shift + k) >= h) return false; // perf-allowed
     }
   return true;
  }

// Is the bar at `shift` a confirmed N-bar fractal swing LOW?
bool IsSwingLow(const int shift, const int n)
  {
   if(shift < n + 1)
      return false;
   const double l = iLow(_Symbol, _Period, shift); // perf-allowed: per-closed-bar pivot scan
   if(l <= 0.0)
      return false;
   for(int k = 1; k <= n; ++k)
     {
      if(iLow(_Symbol, _Period, shift - k) <= l) return false; // perf-allowed
      if(iLow(_Symbol, _Period, shift + k) <= l) return false; // perf-allowed
     }
   return true;
  }

// Find the most recent confirmed swing HIGH at shift >= from_shift, scanning
// outward (older). Returns the shift, or -1 if none within the bounded window.
int RecentSwingHigh(const int from_shift, const int n, const int max_shift)
  {
   for(int s = from_shift; s <= max_shift; ++s)
      if(IsSwingHigh(s, n))
         return s;
   return -1;
  }

// Find the most recent confirmed swing LOW at shift >= from_shift.
int RecentSwingLow(const int from_shift, const int n, const int max_shift)
  {
   for(int s = from_shift; s <= max_shift; ++s)
      if(IsSwingLow(s, n))
         return s;
   return -1;
  }

// Detect a fresh 1-2-3 structure from the most recent confirmed pivots and
// latch it. Sets g_pattern_dir / g_p1 / g_p2 / g_p3 / g_bars_since_p3.
// Order (most recent -> older): P3 (retrace), P2 (extreme), P1 (origin).
void DetectPattern_OnNewBar()
  {
   const int n        = strategy_fractal_n;
   const int max_shift = strategy_pivot_scan_bars;
   // First confirmable pivot shift is n+1 (needs +n closed bars of look-ahead).
   const int first    = n + 1;

   // --- BULLISH 1-2-3: P3 = recent swing LOW, P2 = swing HIGH older than P3,
   //     P1 = swing LOW older than P2. ---
   const int p3l = RecentSwingLow(first, n, max_shift);
   if(p3l > 0)
     {
      const int p2h = RecentSwingHigh(p3l + 1, n, max_shift);
      if(p2h > 0)
        {
         const int p1l = RecentSwingLow(p2h + 1, n, max_shift);
         if(p1l > 0)
           {
            const double p1 = iLow(_Symbol, _Period, p1l);  // perf-allowed
            const double p2 = iHigh(_Symbol, _Period, p2h);  // perf-allowed
            const double p3 = iLow(_Symbol, _Period, p3l);  // perf-allowed
            const double leg = p2 - p1;
            if(p1 > 0.0 && leg > 0.0 && p3 > p1)             // direction preserved
              {
               const double depth = (p2 - p3) / leg;
               if(depth >= strategy_fib_lo && depth <= strategy_fib_hi)
                 {
                  g_pattern_dir   = 1;
                  g_p1            = p1;
                  g_p2            = p2;
                  g_p3            = p3;
                  g_bars_since_p3 = p3l;  // closed bars since P3 confirmation bar
                  return;
                 }
              }
           }
        }
     }

   // --- BEARISH 1-2-3: P3 = recent swing HIGH, P2 = swing LOW older than P3,
   //     P1 = swing HIGH older than P2. ---
   const int p3h = RecentSwingHigh(first, n, max_shift);
   if(p3h > 0)
     {
      const int p2l = RecentSwingLow(p3h + 1, n, max_shift);
      if(p2l > 0)
        {
         const int p1h = RecentSwingHigh(p2l + 1, n, max_shift);
         if(p1h > 0)
           {
            const double p1 = iHigh(_Symbol, _Period, p1h); // perf-allowed
            const double p2 = iLow(_Symbol, _Period, p2l);  // perf-allowed
            const double p3 = iHigh(_Symbol, _Period, p3h); // perf-allowed
            const double leg = p1 - p2;
            if(p2 > 0.0 && leg > 0.0 && p3 < p1)            // direction preserved
              {
               const double depth = (p3 - p2) / leg;
               if(depth >= strategy_fib_lo && depth <= strategy_fib_hi)
                 {
                  g_pattern_dir   = -1;
                  g_p1            = p1;
                  g_p2            = p2;
                  g_p3            = p3;
                  g_bars_since_p3 = p3h;
                  return;
                 }
              }
           }
        }
     }

   // No valid structure this bar.
   g_pattern_dir   = 0;
   g_p1 = 0.0; g_p2 = 0.0; g_p3 = 0.0;
   g_bars_since_p3 = 0;
  }

// Optional same-symbol H4 trend gate. +1 long-ok, -1 short-ok, 0 no read.
int HTFBias()
  {
   if(!strategy_use_htf_filter)
      return 0; // disabled: caller treats 0 as "no constraint"
   const double ema = QM_EMA(_Symbol, PERIOD_H4, strategy_htf_ema_period, 1);
   const double c   = iClose(_Symbol, PERIOD_H4, 1); // perf-allowed: single closed H4 bar
   if(ema <= 0.0 || c <= 0.0)
      return 0;
   return (c > ema) ? 1 : -1;
  }

// Advance cached structure once per closed bar.
void AdvanceState_OnNewBar()
  {
   DetectPattern_OnNewBar();
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
      return false; // no valid quote yet — do not block on it

   const double stop_distance = PipDistance(strategy_sl_cap_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry fires when the last closed bar closed beyond P2 in the pattern
// direction, within max_entry_bars of P3, and (if enabled) the H4 bias agrees.
// Caller guarantees QM_IsNewBar() == true and AdvanceState ran this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_pattern_dir == 0 || g_p1 <= 0.0 || g_p2 <= 0.0 || g_p3 <= 0.0)
      return false;
   // Entry window: P3 must be recent enough that the breakout is timely.
   if(g_bars_since_p3 > strategy_fractal_n + strategy_max_entry_bars)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar trigger read
   if(close1 <= 0.0)
      return false;

   const double sl_buf  = PipDistance(strategy_sl_buffer_pips);
   const double cap_dist = PipDistance(strategy_sl_cap_pips);
   const int    htf      = HTFBias();

   if(g_pattern_dir > 0)
     {
      // Breakout EVENT: closed above P2 high.
      if(!(close1 > g_p2))
         return false;
      if(strategy_use_htf_filter && htf < 0)
         return false; // H4 trend disagrees with the long
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_p3 - sl_buf);
      if(sl <= 0.0 || sl >= entry)
         return false;
      // P2 stop cap: skip if the protective stop is wider than the cap.
      if(cap_dist > 0.0 && (entry - sl) > cap_dist)
         return false;
      const double leg = g_p2 - g_p1;
      const double tp2 = QM_StopRulesNormalizePrice(_Symbol, g_p2 + strategy_tp2_ratio * leg);
      if(tp2 <= entry)
         return false;
      g_tp1_price = QM_StopRulesNormalizePrice(_Symbol, g_p2 + strategy_tp1_ratio * leg);

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp2;
      req.reason = "bermuda_123_fib_long";
      g_pattern_dir = 0;  // consume the latch on fire
      return true;
     }
   else // bearish
     {
      // Breakout EVENT: closed below P2 low.
      if(!(close1 < g_p2))
         return false;
      if(strategy_use_htf_filter && htf > 0)
         return false; // H4 trend disagrees with the short
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, g_p3 + sl_buf);
      if(sl <= 0.0 || sl <= entry)
         return false;
      if(cap_dist > 0.0 && (sl - entry) > cap_dist)
         return false;
      const double leg = g_p1 - g_p2;
      const double tp2 = QM_StopRulesNormalizePrice(_Symbol, g_p2 - strategy_tp2_ratio * leg);
      if(tp2 <= 0.0 || tp2 >= entry)
         return false;
      g_tp1_price = QM_StopRulesNormalizePrice(_Symbol, g_p2 - strategy_tp1_ratio * leg);

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp2;
      req.reason = "bermuda_123_fib_short";
      g_pattern_dir = 0;
      return true;
     }
  }

// Trade management: close partial_close_pct at TP1 once, then ATR-trail the
// remainder. O(1) per tick over the single open position for this magic.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // New position since we last looked — reset partial bookkeeping.
      if(ticket != g_managed_ticket)
        {
         g_managed_ticket = ticket;
         g_partial_done   = false;
        }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool is_buy = (ptype == POSITION_TYPE_BUY);
      const double mkt  = is_buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                 : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(mkt <= 0.0)
         return;

      // Phase 1: take the TP1 partial once when price reaches TP1.
      if(!g_partial_done && g_tp1_price > 0.0)
        {
         const bool hit_tp1 = is_buy ? (mkt >= g_tp1_price) : (mkt <= g_tp1_price);
         if(hit_tp1)
           {
            const double vol  = PositionGetDouble(POSITION_VOLUME);
            const double part = QM_TM_NormalizeVolume(_Symbol, vol * (strategy_partial_close_pct / 100.0));
            if(part > 0.0 && part < vol)
               QM_TM_PartialClose(ticket, part, QM_EXIT_STRATEGY);
            g_partial_done = true; // even if normalization rejected, trail from here
           }
        }

      // Phase 2: after the partial, ATR-trail the runner.
      if(g_partial_done)
         QM_TM_TrailATR(ticket, strategy_trail_atr_period, strategy_trail_atr_mult);

      return; // single position per magic
     }
  }

// No discretionary exit beyond SL/TP and the managed trail.
bool Strategy_ExitSignal()
  {
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

   // Advance the cached 1-2-3 / Fibonacci structure once per closed bar.
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
