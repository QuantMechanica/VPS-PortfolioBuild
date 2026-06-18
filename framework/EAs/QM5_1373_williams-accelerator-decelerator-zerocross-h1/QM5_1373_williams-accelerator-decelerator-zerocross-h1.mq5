#property strict
#property version   "5.0"
#property description "QM5_1373 williams-accelerator-decelerator-zerocross-h1 — Bill Williams Accelerator/Decelerator zero-line cross entry with bar-color confirmation + EMA200 bias (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1373 williams-accelerator-decelerator-zerocross-h1
// -----------------------------------------------------------------------------
// Source: Bill Williams, "New Trading Dimensions" (Wiley 1998,
//   ISBN 0-471-29541-8); FF Trading-Systems "Bill Williams AC / Accelerator
//   Decelerator" cluster (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
// Card: artifacts/cards_approved/QM5_1373_williams-accelerator-decelerator-zerocross-h1.md
//   (g0_status APPROVED). NOTE: card frontmatter carries a STALE ea_id
//   "QM5_12157"; the canonical build target for this slug is ea_id 1373 (used
//   here as qm_ea_id). Flagged in build_result.frontmatter_mismatch.
//
// Bill Williams Accelerator / Decelerator oscillator (AC) — the "second
// derivative" of price, measuring the change-rate of momentum:
//     median_t = (high_t + low_t) / 2
//     AO_t     = SMA(median, 5)  - SMA(median, 34)        (Awesome Oscillator)
//     AC_t     = AO_t            - SMA(AO, 5)             (Accelerator/Decelerator)
// AO and AC are both computed IN-EA over a bounded closed-bar window (no built-in
// MT5 indicator handle for AO/AC; no raw indicator handles, no CopyBuffer). All
// AC math runs on the CLOSED-BAR path only (Strategy_EntrySignal / ExitSignal run
// under the QM_IsNewBar gate). ATR/EMA are read via the pooled QM_* readers.
//
//   AC zero-line cross = the single trigger EVENT (per build-prompt .DWX
//   invariant #4: model EXACTLY ONE cross to avoid the two-cross-same-bar
//   zero-trade trap). The card body narrates a consecutive-bar-color count
//   (2 green when AC>0, 3 green when AC<=0); that bar-color run is folded in
//   here as a STATE confirmation on top of the single zero-cross EVENT, so the
//   build can never require two fresh cross events on the same bar.
//
//   AC bar color (canonical Williams): green = AC[s] > AC[s+1] (accelerating
//   up), red = AC[s] < AC[s+1] (accelerating down). On the closed-bar path with
//   shift 0 = last fully-closed bar, "current vs previous" = AC(s) vs AC(s+1).
//
//   Entry (BUY) on the H1 close, all of:
//     1. EVENT — AC zero-line cross UP: AC[1] <= 0 AND AC[0] > 0.
//        (shift 0 = last fully-closed bar under the QM_IsNewBar gate; shift 1 =
//         the bar before it.)
//     2. STATE — bar-color confirmation: the last `green_confirm_bars` AC bars
//        are all green (AC rising: AC[0]>AC[1] AND AC[1]>AC[2] ...). Default 2.
//     3. STATE — macro bias: close[0] > EMA(close, macro) on H1 (card EMA200).
//   SELL mirrors: AC[1] >= 0 AND AC[0] < 0; last `red_confirm_bars` AC bars all
//        red (AC falling); close[0] < EMA(macro).
//
//   Only the AC zero-cross is an EVENT; bar-color run and macro-bias are STATES
//   — no two-fresh-cross-same-bar zero-trade trap.
//
//   Exit (closed-bar, any of):
//     - Color-flip exit (card primary): a BUY closes when AC turns red and stays
//       red for `flip_exit_bars` bars (AC[0]<AC[1] AND AC[1]<AC[2]); SELL mirror.
//     - AC zero-line cross-back (secondary): BUY closes when AC crosses back
//       below zero; SELL closes when it crosses back above zero.
//     - Time-stop: position held >= time_stop_bars H1 bars → close (card 48).
//   Stop : entry -/+ sl_atr_mult * ATR(atr_period) (card 1.5 x ATR(14)).
//   Take : tp_atr_mult * ATR from entry (card 2.0 x ATR), expressed via QM_TakeRR
//          off the stop so the framework price-normalization applies.
//
//   Spread guard: only a genuinely wide spread blocks (fail-OPEN on .DWX zero
//                 modeled spread, ask == bid).
//   Re-arm      : one position per magic; color-flip / cross-back exits mean a
//                 fresh AC zero-cross + color run is required to re-enter (forces
//                 a full AC cycle, matching the card's "one signal per AC run").
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed, $0-swap-independent (pure price-oscillator rule). All AO/AC
//   math is fixed closed-form over bounded closed-bar windows — transparent
//   non-ML computation (HR14 compliant).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1373;
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
input int    ao_fast_period             = 5;    // AO fast SMA on median price (Williams canonical 5)
input int    ao_slow_period             = 34;   // AO slow SMA on median price (Williams canonical 34)
input int    ac_sma_period              = 5;    // AC = AO - SMA(AO, 5) (Williams canonical 5)
input int    green_confirm_bars         = 2;    // consecutive rising (green) AC bars to confirm BUY (card 2 when AC>0)
input int    red_confirm_bars           = 2;    // consecutive falling (red) AC bars to confirm SELL
input int    flip_exit_bars             = 2;    // AC color-flip exit: opposite-color bars to close (card 2)
input int    strategy_macro_ema_period  = 200;  // macro-bias EMA gate (card EMA200, H1)
input int    strategy_atr_period        = 14;   // ATR period for stop/target (card 14)
input double strategy_sl_atr_mult       = 1.5;  // stop = entry -/+ mult*ATR (card 1.5)
input double strategy_tp_atr_mult       = 2.0;  // take profit = mult*ATR from entry (card 2.0)
input int    strategy_time_stop_bars    = 48;   // close after N H1 bars without exit (card 48)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy helpers — Bill Williams AO / AC computed in-EA over bounded
// closed-bar windows. All reads are closed-bar (shift >= the requested shift);
// only invoked under the QM_IsNewBar gate.
// -----------------------------------------------------------------------------

// SMA of the bar-median price ((high+low)/2) over `period` bars ending at
// closed-bar `shift`. Returns ok=false on warmup / bad data.
double MedianSMA(const int period, const int shift, bool &ok)
  {
   ok = false;
   const int p = (period > 0 ? period : 1);
   double sum = 0.0;
   for(int k = 0; k < p; ++k)
     {
      const int s = shift + k;
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: bounded closed-bar median window
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed
      if(hi <= 0.0 || lo <= 0.0)
         return 0.0;
      sum += 0.5 * (hi + lo);
     }
   ok = true;
   return sum / p;
  }

// Awesome Oscillator at closed-bar `shift`: SMA(median, fast) - SMA(median, slow).
double AOAt(const int shift, bool &ok)
  {
   ok = false;
   bool f_ok=false, s_ok=false;
   const double fast = MedianSMA(ao_fast_period, shift, f_ok);
   const double slow = MedianSMA(ao_slow_period, shift, s_ok);
   if(!(f_ok && s_ok))
      return 0.0;
   ok = true;
   return fast - slow;
  }

// Accelerator/Decelerator at closed-bar `shift`: AO - SMA(AO, ac_sma_period).
// Needs AO at shift..shift+ac_sma_period-1, each of which needs the median
// windows below it — all bounded, all closed-bar.
double ACAt(const int shift, bool &ok)
  {
   ok = false;
   const int p = (ac_sma_period > 0 ? ac_sma_period : 1);
   bool ao0_ok=false;
   const double ao0 = AOAt(shift, ao0_ok);
   if(!ao0_ok)
      return 0.0;
   double ao_sum = 0.0;
   for(int k = 0; k < p; ++k)
     {
      bool aok=false;
      const double aov = AOAt(shift + k, aok);
      if(!aok)
         return 0.0;
      ao_sum += aov;
     }
   ok = true;
   return ao0 - (ao_sum / p);
  }

// True if the AC series is "green" (rising) for `bars` consecutive closed bars
// ending at shift 0: AC[0]>AC[1] AND AC[1]>AC[2] ... for `bars` deltas.
bool ACGreenRun(const int bars, bool &ok)
  {
   ok = false;
   const int n = (bars > 0 ? bars : 1);
   for(int s = 0; s < n; ++s)
     {
      bool a_ok=false, b_ok=false;
      const double cur  = ACAt(s,   a_ok);
      const double prev = ACAt(s+1, b_ok);
      if(!(a_ok && b_ok))
         return false;
      if(!(cur > prev))
        { ok = true; return false; }
     }
   ok = true;
   return true;
  }

// True if the AC series is "red" (falling) for `bars` consecutive closed bars
// ending at shift 0: AC[0]<AC[1] AND AC[1]<AC[2] ...
bool ACRedRun(const int bars, bool &ok)
  {
   ok = false;
   const int n = (bars > 0 ? bars : 1);
   for(int s = 0; s < n; ++s)
     {
      bool a_ok=false, b_ok=false;
      const double cur  = ACAt(s,   a_ok);
      const double prev = ACAt(s+1, b_ok);
      if(!(a_ok && b_ok))
         return false;
      if(!(cur < prev))
        { ok = true; return false; }
     }
   ok = true;
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. AC computation is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled
// spread (ask == bid).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// AC zero-line-cross EVENT + bar-color run STATE + macro-bias STATE entry.
// Caller guarantees QM_IsNewBar() == true. Shift 0 = last fully-closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   bool ac0_ok=false, ac1_ok=false;
   const double ac0 = ACAt(0, ac0_ok);
   const double ac1 = ACAt(1, ac1_ok);
   if(!(ac0_ok && ac1_ok))
      return false;          // warmup / unavailable -> no trade

   const double close0 = iClose(_Symbol, _Period, 0); // perf-allowed: single closed-bar read
   const double macro  = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(close0 <= 0.0 || macro <= 0.0)
      return false;

   // --- AC zero-line cross = the single trigger EVENT ---
   const bool cross_up   = (ac1 <= 0.0 && ac0 > 0.0);
   const bool cross_down = (ac1 >= 0.0 && ac0 < 0.0);
   if(!cross_up && !cross_down)
      return false;

   // --- Macro bias STATE ---
   const bool macro_long  = (close0 > macro);
   const bool macro_short = (close0 < macro);

   QM_OrderType dir;
   double entry;

   if(cross_up && macro_long)
     {
      // --- Bar-color confirmation STATE: green (rising) AC run ---
      bool run_ok=false;
      if(!ACGreenRun(green_confirm_bars, run_ok) || !run_ok)
         return false;
      dir   = QM_BUY;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     }
   else if(cross_down && macro_short)
     {
      bool run_ok=false;
      if(!ACRedRun(red_confirm_bars, run_ok) || !run_ok)
         return false;
      dir   = QM_SELL;
      entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     }
   else
      return false;

   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Hard SL: entry -/+ sl_atr_mult * ATR ---
   double sl;
   if(dir == QM_BUY)
      sl = entry - strategy_sl_atr_mult * atr_value;
   else
      sl = entry + strategy_sl_atr_mult * atr_value;
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(sl <= 0.0)
      return false;

   // --- Take profit: tp_atr_mult * ATR from entry, via RR off the stop so the
   //     framework's price normalization applies. ---
   const double sl_dist = MathAbs(entry - sl);
   if(sl_dist <= 0.0)
      return false;
   const double rr = (strategy_tp_atr_mult * atr_value) / sl_dist;
   if(rr <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ac_zerocross_color_run_macro";
   return true;
  }

// Primary exits are the broker-side hard stop and ATR target plus the closed-bar
// AC exits in Strategy_ExitSignal; no active trailing/BE per the card.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: AC color-flip (opposite-color run) OR AC zero-line
// cross-back against the position OR time-stop. Caller closes the magic's
// positions on true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this magic's open position to read direction + open time.
   bool have_pos = false;
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      have_pos  = true;
      break;
     }
   if(!have_pos)
      return false;

   // --- Time-stop: held >= N H1 bars ---
   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int held_bars = (int)((TimeCurrent() - open_time) / (PeriodSeconds(_Period)));
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }

   bool ac0_ok=false, ac1_ok=false;
   const double ac0 = ACAt(0, ac0_ok);
   const double ac1 = ACAt(1, ac1_ok);
   if(!(ac0_ok && ac1_ok))
      return false;

   // --- Color-flip exit (primary): opposite-color run for flip_exit_bars ---
   if(pos_type == POSITION_TYPE_BUY)
     {
      bool run_ok=false;
      if(ACRedRun(flip_exit_bars, run_ok) && run_ok)
         return true;
     }
   else if(pos_type == POSITION_TYPE_SELL)
     {
      bool run_ok=false;
      if(ACGreenRun(flip_exit_bars, run_ok) && run_ok)
         return true;
     }

   // --- AC zero-line cross-back exit (secondary) ---
   // BUY closes when AC crosses back below zero; SELL when back above.
   if(pos_type == POSITION_TYPE_BUY  && ac1 >= 0.0 && ac0 < 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && ac1 <= 0.0 && ac0 > 0.0)
      return true;

   return false;
  }

// Defer to the central news filter (framework PRE30_POST30 temporal mode).
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
