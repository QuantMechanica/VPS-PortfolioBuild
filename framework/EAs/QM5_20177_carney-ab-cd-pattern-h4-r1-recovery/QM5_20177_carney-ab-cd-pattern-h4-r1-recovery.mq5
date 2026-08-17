#property strict
#property version   "5.0"
#property description "QM5_20177 Carney AB=CD 4-pivot harmonic projection (H4, fractal pivots)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails). The framework provides:
//
//   - QM_IsNewBar(sym="", tf=PERIOD_CURRENT)  — closed-bar gate
//   - QM_ATR / QM_EMA / QM_SMA / QM_RSI / QM_MACD_Main / QM_MACD_Signal /
//     QM_ADX / QM_ADX_PlusDI / QM_ADX_MinusDI /
//     QM_BB_Upper / QM_BB_Middle / QM_BB_Lower    (from QM_Indicators.mqh)
//   - QM_TM_OpenPosition(req, ticket) / QM_TM_ClosePosition(ticket, reason)
//   - QM_TM_MoveToBreakEven / QM_TM_TrailATR / QM_TM_TrailStep / QM_TM_PartialClose
//   - QM_LotsForRisk(symbol, sl_points)        — risk model lot sizing
//   - QM_StopFixedPips / QM_StopATR / QM_StopStructure / QM_StopVolatility
//   - QM_FrameworkTrackOpenPositionMae / QM_FrameworkHandleFridayClose /
//     QM_KillSwitchCheck / QM_NewsAllowsTrade
//
// DO NOT
//   - Write per-EA IsNewBar() — use QM_IsNewBar()
//   - Call iATR / iMA / iRSI / iMACD / iADX / iBands or CopyBuffer directly —
//     use the QM_* readers above. The framework pools handles and releases them
//     on shutdown.
//   - CopyRates over warmup windows on every tick. If you genuinely need raw
//     bar arrays, gate by QM_IsNewBar so the work runs once per closed bar.
//   - Hand-edit framework/include/QM/QM_MagicResolver.mqh. After adding rows
//     to magic_numbers.csv, run:
//         python framework/scripts/update_magic_resolver.py
//     This is idempotent and preserves all rows.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 20177;
input int    qm_magic_slot_offset       = 0;
// FW3: Q07 Multi-Seed uses one of the canonical seeds (42, 17, 99, 7, 2026).
// All other phases use 42 by default. Stress / noise dimensions read from
// this single seed so reproducibility is guaranteed across re-runs.
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
// FW1 2026-05-23 — Two-axis news filter per Vault Q09.
//   AXIS A (temporal): per-event behaviour. Default mode 3 = pause 30min pre+post.
//   AXIS B (compliance): prop-firm blackout overlay. Default DXZ = no extra rules.
// A trade is allowed only if BOTH axes allow. See Vault `Q09 News Impact Mode`.
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;     // 14 days; SETUP_DATA_MISSING if older
input string qm_news_min_impact           = "high";  // high / medium / low
// Legacy single-mode input kept for back-compat with pre-FW1 setfiles.
// New EAs use qm_news_temporal + qm_news_compliance above and leave this OFF.
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
// FW2 2026-05-23 — only populated by Q05 MED / Q06 HARSH stress setfiles.
// Default 0.0 = no rejection (Q02/Q03/Q04/Q07/Q08/Q09/Q10/Q13 backtests).
// Q06 HARSH sets to 0.10 (10% of entries randomly dropped before broker send,
// deterministic per qm_rng_seed). MED slip/spread/commission live in the
// tester groups file, not as EA inputs.
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
// Carney AB=CD 4-pivot harmonic (A-B-C alternating fractal pivots, entry at the
// projected D = C + (B - A) equal-magnitude measured move). See SPEC.md §1 for
// the two documented simplifications vs. the source card.
input int    pivot_scan_start           = 4;      // first fractal scan shift (skips 1-3 to keep touch/confirm bars clear)
input int    pivot_scan_max             = 80;     // last fractal scan shift (bounded pivot search)
input double bc_ab_ratio_min            = 0.382;  // min BC/AB retracement (Carney published range)
input double bc_ab_ratio_max            = 0.886;  // max BC/AB retracement (Carney published range)
input double time_symmetry_tolerance    = 0.20;   // max |CD-bars/AB-bars - 1| at the D-touch bar
input double projection_touch_atr_mult  = 0.5;    // +/- ATR tolerance around the projected D level
input int    atr_period                 = 14;     // ATR period (H4) for stop / spread / touch tolerance
input double sl_atr_mult                = 1.0;    // structural stop = D_proj -/+ mult*ATR
input double t1_fib                     = 0.382;  // T1 target = fib retrace of CD leg (close 50%)
input double t2_fib                     = 0.618;  // T2 target = fib retrace of CD leg (close remainder)
input double time_stop_mult             = 1.5;    // time-stop = multiplier * measured CD-leg bars
input int    d1_rsi_period              = 14;     // D1 regime-filter RSI period
input double d1_rsi_lo                   = 25.0;   // D1 RSI lower band (mixed-trend regime gate)
input double d1_rsi_hi                   = 75.0;   // D1 RSI upper band (mixed-trend regime gate)
input double spread_atr_mult_cap        = 0.3;    // skip entry if spread > cap*ATR
input int    cooldown_bars              = 18;     // no same-direction re-entry within N H4 bars

// -----------------------------------------------------------------------------
// File-scope state — tracks the open-trade projection geometry and per-direction
// cooldown anchors. Set on entry, consumed by Strategy_ManageOpenPosition.
// -----------------------------------------------------------------------------
datetime g_position_entry_time = 0;
double   g_position_D          = 0.0;
double   g_position_C          = 0.0;
int      g_position_cd_bars    = 0;
bool     g_t1_done             = false;
datetime g_last_long_entry_time  = 0;
datetime g_last_short_entry_time = 0;

// -----------------------------------------------------------------------------
// FindABC — locate the three most-recent alternating fractal pivots A-B-C.
// prices[0]=C (most recent), prices[1]=B, prices[2]=A. Returns the A/B/C prices,
// the A->B bar-count (ab_bars) and the B->C bar-count (c_bars_from_b), and TRUE
// only when the pivot polarity matches the requested direction. Fractal-based
// pivot detection is the framework-sanctioned substitute for the card's
// ZigZag(12,5,3) — see SPEC.md §1.
// -----------------------------------------------------------------------------
bool FindABC(const string sym, const bool bullish,
             double &A, double &B, double &C,
             int &c_bars_from_b, int &ab_bars, int &c_shift)
  {
   double prices[3];
   int    shifts[3];
   bool   is_upper[3];
   int    found = 0;
   // perf-allowed: bounded fractal pivot scan (<= pivot_scan_max-pivot_scan_start
   // iterations). Only reached from QM_IsNewBar-gated Strategy_EntrySignal, so it
   // runs once per closed H4 bar, not per tick.
   for(int s = pivot_scan_start; s <= pivot_scan_max && found < 3; s++) // perf-allowed
     {
      const double up = QM_FractalUpper(sym, PERIOD_CURRENT, s);
      const double dn = QM_FractalLower(sym, PERIOD_CURRENT, s);
      const bool has_up = (up != EMPTY_VALUE && up > 0.0);
      const bool has_dn = (dn != EMPTY_VALUE && dn > 0.0);
      if(!has_up && !has_dn)
         continue;
      if(has_up && has_dn)
         continue; // ambiguous bar (both fractals print), skip
      const bool this_is_upper = has_up;
      if(found > 0 && is_upper[found - 1] == this_is_upper)
         continue; // pivots must alternate high/low
      prices[found]   = this_is_upper ? up : dn;
      shifts[found]   = s;
      is_upper[found] = this_is_upper;
      found++;
     }
   if(found < 3)
      return false;

   C = prices[0];
   B = prices[1];
   A = prices[2];
   ab_bars       = shifts[2] - shifts[1];   // A -> B bar-count
   c_bars_from_b = shifts[1] - shifts[0];   // B -> C bar-count (>0)
   c_shift       = shifts[0];                // C -> live-edge distance

   if(bullish)
      return (!is_upper[0] && is_upper[1] && !is_upper[2] && C > A); // C=low, B=high, A=low, C>A
   else
      return ( is_upper[0] && !is_upper[1] && is_upper[2] && C < A); // C=high, B=low, A=high, C<A
  }

// -----------------------------------------------------------------------------
// Strategy hooks — implement these against the card mechanically.
// -----------------------------------------------------------------------------

// Return TRUE to BLOCK trading this tick (e.g. wrong session, news window,
// regime filter). Cheap O(1) checks only — runs on every tick.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Populate `req` with entry order parameters and return TRUE if a NEW entry
// should fire on this closed bar. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.symbol_slot = qm_magic_slot_offset;

   const double atr14_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   if(atr14_1 <= 0.0)
      return false;

   // Spread filter — never fail-closed on a zero/absent spread.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double spread = ask - bid;
   if(spread > 0.0 && spread > spread_atr_mult_cap * atr14_1)
      return false;

   // D1 regime filter — AB=CD is a mixed-trend counter-reversal pattern.
   MqlRates d1c1;
   if(!QM_ReadBar(_Symbol, PERIOD_D1, 1, d1c1))
      return false;
   const double d1_rsi_1 = QM_RSI(_Symbol, PERIOD_D1, d1_rsi_period, 1);
   const bool d1_regime_ok = (d1_rsi_1 >= d1_rsi_lo && d1_rsi_1 <= d1_rsi_hi);

   MqlRates c1, c2;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 1, c1)) // confirmation-bar candidate
      return false;
   if(!QM_ReadBar(_Symbol, PERIOD_CURRENT, 2, c2)) // touch-bar candidate
      return false;

   const double tol = projection_touch_atr_mult * atr14_1;

   // ---- Bullish attempt ----
   double A = 0.0, B = 0.0, C = 0.0;
   int c_bars = 0, ab_bars = 0, c_shift = 0;
   if(FindABC(_Symbol, true, A, B, C, c_bars, ab_bars, c_shift) && d1_regime_ok)
     {
      const double ab_range = (B - A);
      if(ab_range > 0.0)
        {
         const double bc_ratio = (B - C) / ab_range;
         const int cd_bars = c_shift - 2; // C pivot through the D-touch bar (shift 2)
         const bool time_symmetry_ok =
            cd_bars > 0 &&
            MathAbs((double)cd_bars / (double)ab_bars - 1.0) <= time_symmetry_tolerance;
         if(bc_ratio >= bc_ab_ratio_min && bc_ratio <= bc_ab_ratio_max &&
            ab_bars >= 3 && ab_bars <= 60 && time_symmetry_ok)
           {
            const double d_proj = C + (B - A);
            const double t1 = d_proj + t1_fib * (C - d_proj);
            const bool touch_ok =
               (c2.low  <= d_proj + tol) && (c2.low  >= d_proj - tol) &&
               (c2.close >= d_proj - tol) && (c2.close <= d_proj + tol);
            const bool confirm_ok = (c1.close > c2.high);
            const bool t1_ok = (ask < t1);
            const int bars_since_long = (g_last_long_entry_time > 0)
               ? iBarShift(_Symbol, PERIOD_CURRENT, g_last_long_entry_time, false) // perf-allowed structural bar-index lookup
               : 999999;
            const bool long_ok = touch_ok && confirm_ok && t1_ok && bars_since_long > cooldown_bars;
            if(long_ok)
              {
               req.type   = QM_BUY;
               req.price  = ask;
               req.sl     = d_proj - sl_atr_mult * atr14_1; // structural stop below projection
               req.tp     = 0.0;
               req.reason = "carney_abcd_long";
               g_position_entry_time  = c1.time;
               g_position_D           = d_proj;
               g_position_C           = C;
               g_position_cd_bars     = cd_bars;
               g_t1_done              = false;
               g_last_long_entry_time = c1.time;
               return true;
              }
           }
        }
     }

   // ---- Bearish attempt ----
   double A2 = 0.0, B2 = 0.0, C2p = 0.0;
   int c_bars2 = 0, ab_bars2 = 0, c_shift2 = 0;
   if(FindABC(_Symbol, false, A2, B2, C2p, c_bars2, ab_bars2, c_shift2) && d1_regime_ok)
     {
      const double ab_range = (A2 - B2);
      if(ab_range > 0.0)
        {
         const double bc_ratio = (C2p - B2) / ab_range;
         const int cd_bars = c_shift2 - 2; // C pivot through the D-touch bar (shift 2)
         const bool time_symmetry_ok =
            cd_bars > 0 &&
            MathAbs((double)cd_bars / (double)ab_bars2 - 1.0) <= time_symmetry_tolerance;
         if(bc_ratio >= bc_ab_ratio_min && bc_ratio <= bc_ab_ratio_max &&
            ab_bars2 >= 3 && ab_bars2 <= 60 && time_symmetry_ok)
           {
            const double d_proj = C2p - (A2 - B2);
            const double t1 = d_proj + t1_fib * (C2p - d_proj);
            const bool touch_ok =
               (c2.high <= d_proj + tol) && (c2.high >= d_proj - tol) &&
               (c2.close >= d_proj - tol) && (c2.close <= d_proj + tol);
            const bool confirm_ok = (c1.close < c2.low);
            const bool t1_ok = (bid > t1);
            const int bars_since_short = (g_last_short_entry_time > 0)
               ? iBarShift(_Symbol, PERIOD_CURRENT, g_last_short_entry_time, false) // perf-allowed structural bar-index lookup
               : 999999;
            const bool short_ok = touch_ok && confirm_ok && t1_ok && bars_since_short > cooldown_bars;
            if(short_ok)
              {
               req.type   = QM_SELL;
               req.price  = bid;
               req.sl     = d_proj + sl_atr_mult * atr14_1; // structural stop above projection
               req.tp     = 0.0;
               req.reason = "carney_abcd_short";
               g_position_entry_time   = c1.time;
               g_position_D            = d_proj;
               g_position_C            = C2p;
               g_position_cd_bars      = cd_bars;
               g_t1_done               = false;
               g_last_short_entry_time = c1.time;
               return true;
              }
           }
        }
     }

   return false;
  }

// Called every tick when an open position exists for this EA's magic.
// T1 partial (50%) at fib retrace of the CD leg, ATR-trail the remainder to T2,
// flat bar-cap time-stop. T1/T2 use the same formula both directions (the sign
// of (C - D) flips naturally between long and short).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   const double atr14_1 = QM_ATR(_Symbol, PERIOD_CURRENT, atr_period, 1);
   const int derived_time_stop_cap = (int)MathRound(time_stop_mult * g_position_cd_bars);
   const int time_stop_cap = (derived_time_stop_cap > 1) ? derived_time_stop_cap : 1;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      // Restart-safety: geometry is file-scope only. If it was lost (e.g. a live
      // restart mid-trade) leave the hard SL to protect the position rather than
      // acting on a zeroed D/C level. In the tester D/C are always set.
      if(g_position_D <= 0.0 || g_position_C <= 0.0 || g_position_cd_bars <= 0)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const bool   is_buy = (ptype == POSITION_TYPE_BUY);
      const double vol    = PositionGetDouble(POSITION_VOLUME);
      const double bid    = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask    = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      const double t1 = g_position_D + t1_fib * (g_position_C - g_position_D);
      const double t2 = g_position_D + t2_fib * (g_position_C - g_position_D);

      if(!g_t1_done)
        {
         const bool t1_hit = is_buy ? (bid >= t1) : (ask <= t1);
         if(t1_hit)
           {
            QM_TM_PartialClose(ticket, vol * 0.5, QM_EXIT_STRATEGY);
            g_t1_done = true;
           }
        }
      else
        {
         if(atr14_1 > 0.0)
            QM_TM_TrailATR(ticket, atr_period, 1.0);
         const bool t2_hit = is_buy ? (bid >= t2) : (ask <= t2);
         if(t2_hit)
           {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
           }
        }

      // Time-stop: exit regardless of P&L once the flat bar-cap elapses.
      const int bars_since_entry = (g_position_entry_time > 0)
         ? iBarShift(_Symbol, PERIOD_CURRENT, g_position_entry_time, false) // perf-allowed structural bar-index lookup
         : 0;
      if(bars_since_entry >= time_stop_cap)
        {
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
         continue;
        }
     }
  }

// Return TRUE to close the open position now. SL/TP + management own the exits
// here; nothing extra to do.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Optional news-filter override. Return TRUE to suppress trading regardless
// of qm_news_mode (defaults to "ask the framework").
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false; // defer to QM_NewsAllowsTrade(...)
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
   // Q08 evidence lifecycle: sample floating P&L before any per-tick guard can
   // return. QM_KillSwitchCheck retains the same call as a compatibility
   // fallback for pre-template EAs; keep this explicit hook in all new builds.
   QM_FrameworkTrackOpenPositionMae();

   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
      return;
   if(QM_FrameworkHandleFridayClose())
      return;

   if(Strategy_NoTradeFilter())
      return;

   // Per-tick: trade management can adjust SL/TP on open positions.
   // Management, rule-based exits and the Friday sweep above MUST keep
   // running through news windows — the news gate below blocks NEW entries
   // only (2026-07-02 audit rule; canonical order per QM5_12821 OnTick,
   // commit dc418a720).
   Strategy_ManageOpenPosition();

   // Per-tick: discretionary exit (e.g. time stop). Separate from SL/TP.
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

   // Per-closed-bar: entry-signal evaluation. Gating here avoids 99% of
   // per-tick recompute mistakes — EntrySignal sees one new closed bar per
   // call, not every incoming tick.
   // FW1 — 2-axis check. Falls through to legacy `qm_news_mode_legacy` only
   // when both new axes are at their OFF defaults. Gates NEW entries only —
   // never the management/exit paths above.
   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   // FW6 2026-05-23 — emit end-of-day equity snapshot if the day rolled
   // since last tick. Cheap: most calls early-return on same-day check.
   QM_EquityStreamOnNewBar();

   QM_EntryRequest req;
   ZeroMemory(req); // symbol_slot=0 (host slot) + expiration=0 defaults; garbage
                    // in unset fields = the silent-zero-trades class (9e4cfedb1)
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
   // FW4: feeds closing-deal net-profits to the KS kill-switch.
   // No-op outside Q13 (when no baseline.json exists).
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
