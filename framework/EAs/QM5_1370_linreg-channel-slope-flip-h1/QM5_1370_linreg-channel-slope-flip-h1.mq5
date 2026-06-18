#property strict
#property version   "5.0"
#property description "QM5_1370 linreg-channel-slope-flip-h1 — Linear-Regression channel slope-flip + band-touch entry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1370 linreg-channel-slope-flip-h1
// -----------------------------------------------------------------------------
// Source: FF Trading-Systems "Linear regression channel" / "Raff regression
//   channel" cluster. Raff (early-1980s) Raff Regression Channel + Lien (S&C
//   1991) +/-k*sigma deviation bands + MetaQuotes built-in LR channel.
//   Card: artifacts/cards_approved/QM5_1370_linreg-channel-slope-flip-h1.md
//   (g0_status APPROVED). Card frontmatter ea_id reads QM5_12155 (stale); the
//   authoritative build-target ea_id is 1370 (frontmatter mismatch flagged).
//
// Construction (in-EA, closed-form OLS over N CLOSED-bar closes; NO ML):
//   Index the regression window by i = 1..N where i = N is the MOST RECENT
//   closed bar (shift 1) and i = 1 is the OLDEST (shift N). With
//     Sx  = sum(i)          = N(N+1)/2
//     Sxx = sum(i^2)        = N(N+1)(2N+1)/6
//     Sy  = sum(close_i)
//     Sxy = sum(i*close_i)
//   slope  s = (N*Sxy - Sx*Sy) / (N*Sxx - Sx*Sx)
//   intcpt b = (Sy - s*Sx) / N
//   Regression value at the most recent closed bar (i = N): LR = b + s*N.
//   sigma_LR = stddev of residuals (close_i - (b + s*i)) over the window — the
//   Raff-Lien deviation of price from the line itself (NOT the std of price).
//   Bands: upper = LR + k*sigma_LR ; lower = LR - k*sigma_LR.
//
// Trigger / state split (avoids the two-event zero-trade trap):
//   EVENT (single) : slope SIGN-FLIP — s_now > 0 AND s was <= 0 within the last
//                    `flip_lookback` closed bars (BUY); mirror for SELL. The
//                    slope crossing zero is the ONE entry EVENT.
//   STATE          : band-touch within `touch_lookback` bars, bullish/bearish
//                    recovery (close back on the correct side of the line),
//                    EMA(200) macro-bias, sigma-not-squeezed. All STATE on the
//                    same closed bar.
//
// Exit (Strategy_ExitSignal / Strategy_ManageOpenPosition):
//   - Opposite-band TP with a 0.5*ATR cushion (set as req.tp at entry; the
//     channel-target side. The absolute band moves with each bar, so the live
//     exit also closes if the CURRENT cushioned opposite band is reached).
//   - Slope-flip-REVERSE: slope crosses zero in the opposite direction -> close.
//   - Time-stop: `time_stop_bars` closed bars without TP/SL/reverse -> close.
//   - One-time break-even shift once price advances 1.0*ATR in favour.
//
// Stop (frozen at entry, does NOT track the moving channel):
//   BUY  SL = lower_band(entry) - stop_atr_buf*ATR, distance capped at
//            stop_atr_cap*ATR.  SELL mirror.
//
// .DWX INVARIANTS honoured:
//   * Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).  * No swap gate.  * Broker-time windows via the platform
//     clock; rollover-blackout in broker time.  * Prior CLOSE referenced, not a
//     gap/range.  * QM_IsNewBar() consumed ONCE per tick.  * One slope-flip is
//     the single EVENT; the channel + band touch are STATE.  * All math in-EA,
//     no ML, RISK_FIXED in tester, one position per magic.
//
// State (LR window, slope history, bands, bar index, frozen SL, cool-down) is
// advanced ONCE per closed bar in AdvanceState_OnNewBar; the per-tick exit /
// manage / entry paths only READ cached file-scope state + the current quote.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1370;
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
input int    strategy_lr_window         = 50;    // N: regression window of closed H1 closes (P3 30-80)
input double strategy_k_sigma           = 2.0;   // k: band = LR +/- k*sigma_LR (P3 1.5-2.5)
input int    strategy_flip_lookback     = 5;     // slope sign-flip must have occurred within N bars
input int    strategy_touch_lookback    = 3;     // band touched within N closed bars
input int    strategy_ema_macro_period  = 200;   // EMA macro-bias filter
input bool   strategy_macro_bias_on     = true;  // require EMA(200) macro agreement (P3 on/off)
input int    strategy_atr_period        = 14;    // ATR period (SL/TP cushion sizing)
input double strategy_tp_atr_cushion    = 0.5;   // TP cushion before the opposite band = mult*ATR
input double strategy_sl_atr_buf        = 0.5;   // SL = band -/+ buf*ATR (frozen at entry)
input double strategy_sl_atr_cap        = 2.5;   // cap initial SL distance at cap*ATR
input double strategy_be_atr_trigger    = 1.0;   // break-even shift after price advances mult*ATR
input int    strategy_time_stop_bars    = 36;    // close after this many H1 bars without exit
input int    strategy_cooldown_bars     = 6;     // no re-entry for N bars after a reverse exit
input double strategy_min_sigma_atr     = 0.2;   // skip if sigma_LR < this * ATR (squeezed channel)
input double strategy_spread_pct_of_atr = 30.0;  // skip only if spread > this % of ATR (fail-open)
input int    strategy_rollover_hour     = 22;    // no new entry in the hour at/after this broker hour
input int    strategy_rollover_end_hour = 23;    // ... up to (exclusive) this broker hour

// -----------------------------------------------------------------------------
// File-scope cached regression state (advanced once per closed bar)
// -----------------------------------------------------------------------------
long     g_bar_index        = 0;      // monotonic closed-bar counter (advanced on new bar)
datetime g_last_bar_time    = 0;      // open-time of the last bar we advanced on (dedupe guard)

double   g_slope            = 0.0;    // current OLS slope (per-bar)
double   g_slope_prev       = 0.0;    // slope on the previous closed bar
double   g_lr_value         = 0.0;    // regression line value at the most recent closed bar
double   g_sigma_lr         = 0.0;    // stddev of residuals around the line
double   g_upper_band       = 0.0;    // LR + k*sigma_LR
double   g_lower_band       = 0.0;    // LR - k*sigma_LR
double   g_atr_value        = 0.0;    // ATR(period) at shift 1
bool     g_state_ready      = false;  // regression window fully populated + sigma valid

// Slope sign-flip latches: bar index at which the slope last turned +/-.
long     g_last_flip_up_bar   = -1;   // last bar where slope crossed up through 0
long     g_last_flip_dn_bar   = -1;   // last bar where slope crossed down through 0

// Band-touch latches: most recent bar index where price tagged each band.
long     g_last_lower_touch_bar = -1;
long     g_last_upper_touch_bar = -1;

// Per-position bookkeeping.
long     g_entry_bar_index    = -1;   // bar index at which the open position was entered
int      g_entry_dir          = 0;    // +1 long / -1 short of the open position
bool     g_be_done            = false;// break-even shift already applied for this position
long     g_cooldown_until_bar = -1;   // no new entry until g_bar_index > this

// -----------------------------------------------------------------------------
// Closed-form OLS over the regression window of CLOSED-bar closes.
// i = 1..N, i = N is the most recent closed bar (shift 1). Returns false if the
// window cannot be filled with valid closes.
// -----------------------------------------------------------------------------
bool ComputeRegression(const int n, double &slope, double &intercept,
                       double &lr_at_recent, double &sigma_resid)
  {
   if(n < 3)
      return false;

   double sy  = 0.0;
   double sxy = 0.0;
   // i runs 1..N; shift = N - i + 1  (i=N -> shift 1 most recent; i=1 -> shift N).
   for(int i = 1; i <= n; i++)
     {
      const int shift = n - i + 1;
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
      if(c <= 0.0)
         return false;
      sy  += c;
      sxy += (double)i * c;
     }

   const double dn  = (double)n;
   const double sx  = dn * (dn + 1.0) / 2.0;            // sum(i)
   const double sxx = dn * (dn + 1.0) * (2.0 * dn + 1.0) / 6.0; // sum(i^2)
   const double denom = dn * sxx - sx * sx;
   if(MathAbs(denom) < 1e-12)
      return false;

   slope     = (dn * sxy - sx * sy) / denom;
   intercept = (sy - slope * sx) / dn;
   lr_at_recent = intercept + slope * dn;               // line value at i = N (shift 1)

   // Residual stddev around the regression line (Raff-Lien sigma).
   double ss = 0.0;
   for(int i = 1; i <= n; i++)
     {
      const int shift = n - i + 1;
      const double c = iClose(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
      const double fitted = intercept + slope * (double)i;
      const double resid  = c - fitted;
      ss += resid * resid;
     }
   sigma_resid = MathSqrt(ss / dn);
   return true;
  }

// Advance regression / slope / band state by exactly ONE just-closed bar.
// Called once per new closed bar. Reads only closed-bar data (shift >= 1).
void AdvanceState_OnNewBar()
  {
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_time <= 0 || bar_time == g_last_bar_time)
      return; // no fresh closed bar (or already advanced) — leave state intact
   g_last_bar_time = bar_time;
   g_bar_index += 1;

   g_slope_prev = g_slope; // carry previous slope before recompute

   double slope = 0.0, intercept = 0.0, lr = 0.0, sigma = 0.0;
   if(!ComputeRegression(strategy_lr_window, slope, intercept, lr, sigma))
     {
      g_state_ready = false;
      return;
     }

   g_slope     = slope;
   g_lr_value  = lr;
   g_sigma_lr  = sigma;
   g_upper_band = lr + strategy_k_sigma * sigma;
   g_lower_band = lr - strategy_k_sigma * sigma;

   g_atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   g_state_ready = (sigma > 0.0 && g_atr_value > 0.0 && g_bar_index >= (long)strategy_lr_window);

   if(!g_state_ready)
      return;

   // --- Slope sign-flip detection (EVENT) on this closed bar. ---
   if(g_slope_prev <= 0.0 && g_slope > 0.0)
      g_last_flip_up_bar = g_bar_index;   // crossed up through zero
   else if(g_slope_prev >= 0.0 && g_slope < 0.0)
      g_last_flip_dn_bar = g_bar_index;   // crossed down through zero

   // --- Band-touch latches (STATE). Low tags the lower band / high tags the
   //     upper band on the just-closed bar. ---
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(low1 > 0.0 && low1 <= g_lower_band)
      g_last_lower_touch_bar = g_bar_index;
   if(high1 > 0.0 && high1 >= g_upper_band)
      g_last_upper_touch_bar = g_bar_index;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: broker-time rollover blackout + wide-spread guard.
// Returns TRUE to BLOCK. Fail-open on .DWX zero/negative modeled spread.
bool Strategy_NoTradeFilter()
  {
   // --- No new entry in the broker-time pre-rollover hour (22:00-23:00). ---
   const datetime broker_now = TimeCurrent(); // broker time on the tester clock
   MqlDateTime bt;
   TimeToStruct(broker_now, bt);
   if(bt.hour >= strategy_rollover_hour && bt.hour < strategy_rollover_end_hour)
      return true;

   // --- Wide-spread guard relative to ATR. Fail-open on zero modeled spread. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block
   if(g_atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate
   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr / 100.0) * g_atr_value)
      return true;  // genuinely wide spread
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true and AdvanceState_OnNewBar()
// has already run for this closed bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(!g_state_ready)
      return false;

   // Cool-down after a slope-flip-reverse exit.
   if(g_bar_index <= g_cooldown_until_bar)
      return false;

   // Squeezed/flat channel guard: regression has no meaningful deviation.
   if(g_sigma_lr < strategy_min_sigma_atr * g_atr_value)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   double ema_macro = 0.0;
   if(strategy_macro_bias_on)
     {
      ema_macro = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
      if(ema_macro <= 0.0)
         return false;
     }

   // ---------------------------- BUY ----------------------------
   // EVENT: slope flipped UP within the last flip_lookback closed bars.
   const bool flip_up = (g_last_flip_up_bar >= 0 &&
                         (g_bar_index - g_last_flip_up_bar) < (long)strategy_flip_lookback);
   // STATE: lower band tagged within touch_lookback bars.
   const bool lower_touched = (g_last_lower_touch_bar >= 0 &&
                               (g_bar_index - g_last_lower_touch_bar) < (long)strategy_touch_lookback);
   // STATE: bullish recovery — close back above the regression line.
   const bool recover_bull = (close1 > g_lr_value);
   // STATE: macro-bias agreement (optional).
   const bool macro_bull = (!strategy_macro_bias_on || close1 > ema_macro);

   if(flip_up && lower_touched && recover_bull && macro_bull && g_slope > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL frozen at the lower band minus an ATR buffer, capped in distance.
      double sl = g_lower_band - strategy_sl_atr_buf * g_atr_value;
      const double cap = entry - strategy_sl_atr_cap * g_atr_value;
      if(sl < cap)
         sl = cap; // do not let SL sit further than the cap from entry
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;
      // TP: opposite (upper) band minus a cushion (channel target).
      double tp = g_upper_band - strategy_tp_atr_cushion * g_atr_value;
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      if(tp <= entry)
         return false; // band target not above entry yet — skip this bar
      req.type   = QM_BUY;
      req.price  = 0.0;  // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "lr_slopeflip_long";
      g_entry_bar_index = g_bar_index;
      g_entry_dir       = +1;
      g_be_done         = false;
      return true;
     }

   // ---------------------------- SELL ---------------------------
   const bool flip_dn = (g_last_flip_dn_bar >= 0 &&
                         (g_bar_index - g_last_flip_dn_bar) < (long)strategy_flip_lookback);
   const bool upper_touched = (g_last_upper_touch_bar >= 0 &&
                               (g_bar_index - g_last_upper_touch_bar) < (long)strategy_touch_lookback);
   const bool recover_bear = (close1 < g_lr_value);
   const bool macro_bear = (!strategy_macro_bias_on || close1 < ema_macro);

   if(flip_dn && upper_touched && recover_bear && macro_bear && g_slope < 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = g_upper_band + strategy_sl_atr_buf * g_atr_value;
      const double cap = entry + strategy_sl_atr_cap * g_atr_value;
      if(sl > cap)
         sl = cap;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)
         return false;
      double tp = g_lower_band + strategy_tp_atr_cushion * g_atr_value;
      tp = QM_StopRulesNormalizePrice(_Symbol, tp);
      if(tp >= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "lr_slopeflip_short";
      g_entry_bar_index = g_bar_index;
      g_entry_dir       = -1;
      g_be_done         = false;
      return true;
     }

   return false;
  }

// Per-tick management: one-time break-even shift once price advances be_trigger
// * ATR in favour. Reads cached ATR + the live position.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_entry_dir = 0; // no open position — reset direction latch
      return;
     }
   if(g_be_done || g_atr_value <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long   ptype = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double trigger = strategy_be_atr_trigger * g_atr_value;

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && (bid - open_price) >= trigger)
           {
            if(QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "lr_breakeven"))
               g_be_done = true;
           }
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && (open_price - ask) >= trigger)
           {
            if(QM_TM_MoveSL(ticket, QM_StopRulesNormalizePrice(_Symbol, open_price), "lr_breakeven"))
               g_be_done = true;
           }
        }
      break;
     }
  }

// Discretionary exits (whichever first), evaluated each tick on cached state:
//   - slope-flip-REVERSE: slope crossed zero opposite to the entry direction
//   - time-stop: time_stop_bars closed bars elapsed since entry
//   - opposite cushioned band reached (the moving channel target / mean side)
// On a reverse exit the cool-down latch is armed so the next entry waits.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open direction from the live position.
   int dir = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      dir = (ptype == POSITION_TYPE_BUY) ? +1 : -1;
      break;
     }
   if(dir == 0)
      return false;

   // Time-stop: bars elapsed since entry.
   if(g_entry_bar_index >= 0 &&
      (g_bar_index - g_entry_bar_index) >= (long)strategy_time_stop_bars)
      return true;

   if(!g_state_ready)
      return false;

   if(dir > 0)
     {
      // Slope-flip-reverse: slope rotated down through zero -> thesis invalid.
      const bool reverse = (g_slope_prev >= 0.0 && g_slope < 0.0);
      if(reverse)
        {
         g_cooldown_until_bar = g_bar_index + (long)strategy_cooldown_bars;
         return true;
        }
      // Moving opposite (upper) cushioned band reached intrabar.
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double target = g_upper_band - strategy_tp_atr_cushion * g_atr_value;
      if(bid > 0.0 && target > 0.0 && bid >= target)
         return true;
      return false;
     }

   // dir < 0 (short)
   const bool reverse = (g_slope_prev <= 0.0 && g_slope > 0.0);
   if(reverse)
     {
      g_cooldown_until_bar = g_bar_index + (long)strategy_cooldown_bars;
      return true;
     }
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double target = g_lower_band + strategy_tp_atr_cushion * g_atr_value;
   if(ask > 0.0 && target > 0.0 && ask <= target)
      return true;
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring — do NOT edit below this line unless you know why.
// (AdvanceState_OnNewBar is invoked once, immediately after the QM_IsNewBar()
//  gate, so the per-tick exit/manage paths read freshly-cached regression state.)
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

   // Advance cached regression state ONCE per closed bar (single QM_IsNewBar
   // consume per tick — latched into new_bar). The per-tick paths below read
   // the cached state; entry fires only on the new-bar tick.
   const bool new_bar = QM_IsNewBar();
   if(new_bar)
     {
      AdvanceState_OnNewBar();
      QM_EquityStreamOnNewBar();
     }

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

   // Entry only on the new-bar tick (state just advanced this tick).
   if(!new_bar)
      return;

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
