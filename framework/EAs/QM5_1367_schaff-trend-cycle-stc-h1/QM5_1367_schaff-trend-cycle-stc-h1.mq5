#property strict
#property version   "5.0"
#property description "QM5_1367 schaff-trend-cycle-stc-h1 — Schaff Trend Cycle 25/75 zone-cross + EMA200 bias (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1367 schaff-trend-cycle-stc-h1
// -----------------------------------------------------------------------------
// Source: Doug Schaff (FX42 Currency Trading Group), "Schaff Trend Cycle:
//   Faster Cycles, Less Lag", Stocks & Commodities Nov 2008; FF Trading-Systems
//   STC cluster (source_id 6e967762-b26d-59a3-b076-35c17f2e7c36).
// Card: artifacts/cards_approved/QM5_1367_schaff-trend-cycle-stc-h1.md
//   (g0 APPROVED). NOTE: card frontmatter carries a STALE ea_id "QM5_12152";
//   the canonical build target for this slug is ea_id 1367 (used here as
//   qm_ea_id). Flagged in build_result.frontmatter_mismatch.
//
// Schaff Trend Cycle (STC) — a double-Stochastic smoothing of a MACD/PPO
// oscillator. Bounded 0..100 like a Stochastic but reacts faster than MACD.
// Computed ENTIRELY IN-EA (no built-in handle); reconstructed over bounded
// closed-bar windows on the CLOSED-BAR path only (cached once per new H1 bar).
// No raw indicator handles, no CopyBuffer; ATR/EMA bias read via pooled QM_*.
//
//   Construction (Schaff defaults; P3-sweep ranges in the card):
//     1. MACD_raw_t = EMA_fast(close, 23)_t - EMA_slow(close, 50)_t
//     2. %K1_t = stochastic of MACD_raw over cycle=10:
//          (MACD_raw_t - min)/(max - min) * 100, smoothed by an EMA factor 0.5.
//     3. %K2_t = stochastic of %K1 over cycle=10, smoothed by EMA factor 0.5.
//          -> STC line, bounded 0..100.
//     4. EMA(200, H1) on close — macro trend-bias.
//   The "EMA factor 0.5" smoothing is the canonical Schaff recursion:
//       smoothed_t = smoothed_{t-1} + 0.5 * (raw_t - smoothed_{t-1}).
//   We reconstruct the recursive %K1 / STC series over a bounded warmup window
//   seeded at the oldest bar and rolled forward to the target shift.
//
//   Trigger EVENT (the ONLY event — avoids the two-cross zero-trade trap):
//     BUY  : STC[2] < os_level (25)  AND  STC[1] >= os_level   (cross-up of 25)
//     SELL : STC[2] > ob_level (75)  AND  STC[1] <= ob_level   (cross-down of 75)
//   (shift 1 = last fully-closed bar under QM_IsNewBar; shift 2 = the bar before.)
//
//   STATES (not events): EMA200 trend bias + slope, bar-agreement (prior close
//   direction), spread guard, single-position guard, post-SL cool-down.
//
//   Entry BUY : close[1] > EMA200  AND  EMA200[1] >= EMA200[6] (slope-up)
//               AND STC cross-up of 25  AND  close[1] > close[2] (bar agrees)
//               AND spread ok  AND no open position  AND not in cool-down.
//   Entry SELL: mirror (close<EMA200, slope-down, STC cross-down of 75,
//               close[1] < close[2]).
//   Exit      : STC opposite zone-cross (BUY closes on STC cross-down of 75;
//               SELL on STC cross-up of 25); OR EMA-bias flip; OR time-stop
//               (24 H1 bars). Hard ATR SL + ATR TP set at entry. One-time
//               break-even shift after +1.0*ATR favourable move.
//   Cool-down : after a SL hit on the same symbol, no new entry for 12 H1 bars.
//
//   One position per magic. RISK_FIXED in tester, RISK_PERCENT live. No ML, no
//   external feed, $0-swap-independent. All STC math is fixed closed-form over
//   bounded closed-bar windows — transparent non-ML computation (HR14 compliant).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1367;
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
input int    strategy_macd_fast         = 23;     // MACD fast EMA (P3 18-28)
input int    strategy_macd_slow         = 50;     // MACD slow EMA (P3 40-60)
input int    strategy_stc_cycle         = 10;     // STC stochastic cycle length
input double strategy_stc_smooth_factor = 0.5;    // Schaff EMA smoothing factor (0..1)
input double strategy_stc_os_level      = 25.0;   // oversold cross-up trigger for BUY
input double strategy_stc_ob_level      = 75.0;   // overbought cross-down trigger for SELL
input int    strategy_ema_bias_period   = 200;    // H1 macro trend-bias EMA
input int    strategy_ema_slope_lookback = 5;     // bars back for EMA200 slope confirmation
input int    strategy_atr_period        = 14;     // ATR period (stop / target / BE)
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR (P3 1.0-2.5)
input double strategy_tp_atr_mult       = 2.0;    // target distance = mult * ATR (P3 1.5-3.0)
input double strategy_be_atr_mult       = 1.0;    // BE shift trigger = mult * ATR favourable
input int    strategy_time_stop_bars    = 24;     // close after N H1 bars without exit
input int    strategy_cooldown_bars     = 12;     // bars to wait after a SL hit (same symbol)
input double strategy_spread_pct_of_stop = 30.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached STC state (advanced once per closed H1 bar)
// -----------------------------------------------------------------------------
// STC at the two most recent CLOSED bars: stc1 = shift 1 (current closed),
// stc2 = shift 2. The zone-cross events derive from these.
double g_stc1 = 0.0;   // STC at shift 1
double g_stc2 = 0.0;   // STC at shift 2
bool   g_stc_ready = false;

// Post-SL cool-down: bar-time of the last SL hit on this symbol; entries are
// suppressed until strategy_cooldown_bars H1 bars have elapsed past it.
datetime g_last_sl_bar_time = 0;

// Equity-curve hint for SL detection: the magic's open-position count last bar.
int    g_prev_pos_count = 0;

// -----------------------------------------------------------------------------
// STC computation helpers (closed-bar, bounded — perf-allowed raw OHLC reads)
// -----------------------------------------------------------------------------

// EMA of close at a closed-bar shift, reconstructed over a bounded warmup
// window. Used for the MACD_raw fast/slow legs. Returns ok=false on warmup gap.
double EMA_CloseAt(const int period, const int shift, const int warmup, bool &ok)
  {
   ok = false;
   if(period <= 0)
      return 0.0;
   const int oldest = shift + warmup;
   const double k = 2.0 / (period + 1.0);
   double seed = iClose(_Symbol, _Period, oldest); // perf-allowed: bounded closed-bar
   if(seed <= 0.0)
      return 0.0;
   double ema = seed;
   for(int s = oldest - 1; s >= shift; --s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed
      if(c <= 0.0)
         return 0.0;
      ema = c * k + ema * (1.0 - k);
     }
   ok = true;
   return ema;
  }

// MACD_raw = EMA_fast(close) - EMA_slow(close) at a closed-bar shift.
double MACDRawAt(const int shift, bool &ok)
  {
   ok = false;
   // Warmup for the slow EMA dominates; 4x the slow period settles it well below
   // the float noise floor.
   const int warmup = 4 * strategy_macd_slow + 10;
   bool fast_ok=false, slow_ok=false;
   const double fast = EMA_CloseAt(strategy_macd_fast, shift, warmup, fast_ok);
   const double slow = EMA_CloseAt(strategy_macd_slow, shift, warmup, slow_ok);
   if(!fast_ok || !slow_ok)
      return 0.0;
   ok = true;
   return fast - slow;
  }

// Schaff smoothing recursion: smoothed += factor * (raw - smoothed).
double SchaffSmooth(const double prev, const double raw, const double factor)
  {
   return prev + factor * (raw - prev);
  }

// %K1 series value at a closed-bar shift: stochastic of MACD_raw over the cycle,
// Schaff-smoothed. Reconstructed recursively over a bounded warmup so the
// smoother has converged. Returns ok=false on warmup gap.
double STC_K1At(const int shift, bool &ok)
  {
   ok = false;
   const int cyc = (strategy_stc_cycle > 0 ? strategy_stc_cycle : 10);
   const double f = (strategy_stc_smooth_factor > 0.0 && strategy_stc_smooth_factor <= 1.0)
                    ? strategy_stc_smooth_factor : 0.5;
   const int warmup = 30;            // settle the 0.5 smoother
   const int oldest = shift + warmup;

   double k1 = 0.0;
   bool seeded = false;

   for(int s = oldest; s >= shift; --s)
     {
      // stochastic of MACD_raw over [s .. s+cyc-1].
      double hh = -DBL_MAX, ll = DBL_MAX, cur = 0.0;
      bool window_ok = true;
      for(int j = 0; j < cyc; ++j)
        {
         bool m_ok=false;
         const double m = MACDRawAt(s + j, m_ok);
         if(!m_ok) { window_ok = false; break; }
         if(j == 0) cur = m;
         if(m > hh) hh = m;
         if(m < ll) ll = m;
        }
      if(!window_ok)
         return 0.0;
      const double rng = hh - ll;
      const double rawk = (rng > 0.0) ? 100.0 * (cur - ll) / rng : 50.0;
      if(!seeded)
        { k1 = rawk; seeded = true; }
      else
         k1 = SchaffSmooth(k1, rawk, f);
     }
   ok = seeded;
   return k1;
  }

// STC line value at a closed-bar shift: stochastic of the %K1 series over the
// cycle, Schaff-smoothed. Reconstructed recursively over a bounded warmup.
double STC_LineAt(const int shift, bool &ok)
  {
   ok = false;
   const int cyc = (strategy_stc_cycle > 0 ? strategy_stc_cycle : 10);
   const double f = (strategy_stc_smooth_factor > 0.0 && strategy_stc_smooth_factor <= 1.0)
                    ? strategy_stc_smooth_factor : 0.5;
   const int warmup = 30;            // settle the final 0.5 smoother
   const int oldest = shift + warmup;

   double stc = 0.0;
   bool seeded = false;

   for(int s = oldest; s >= shift; --s)
     {
      // stochastic of %K1 over [s .. s+cyc-1].
      double hh = -DBL_MAX, ll = DBL_MAX, cur = 0.0;
      bool window_ok = true;
      for(int j = 0; j < cyc; ++j)
        {
         bool k_ok=false;
         const double v = STC_K1At(s + j, k_ok);
         if(!k_ok) { window_ok = false; break; }
         if(j == 0) cur = v;
         if(v > hh) hh = v;
         if(v < ll) ll = v;
        }
      if(!window_ok)
         return 0.0;
      const double rng = hh - ll;
      const double rawk2 = (rng > 0.0) ? 100.0 * (cur - ll) / rng : 50.0;
      if(!seeded)
        { stc = rawk2; seeded = true; }
      else
         stc = SchaffSmooth(stc, rawk2, f);
     }
   ok = seeded;
   return stc;
  }

// Advance cached STC for the two most recent closed bars. Called ONCE per new
// closed H1 bar from OnTick (after the QM_IsNewBar gate). No internal timestamp
// gate. Bounded closed-bar work.
void AdvanceState_OnNewBar()
  {
   bool ok1=false, ok2=false;
   const double s1 = STC_LineAt(1, ok1);
   const double s2 = STC_LineAt(2, ok2);
   if(ok1 && ok2)
     {
      g_stc1 = s1;
      g_stc2 = s2;
      g_stc_ready = true;
     }
   else
     {
      g_stc_ready = false;
     }

   // SL-hit cool-down detection: if a position closed since last bar (count
   // dropped) and the last closed bar's high/low touched the broker-side stop,
   // we conservatively treat any position disappearance with no open position
   // now as a possible stop and start the cool-down. We use position-count drop
   // as the trigger; TP exits also drop the count but a cool-down after a TP is
   // harmless (it only delays re-entry by a few bars and the STC re-cross is rare).
   const int magic = QM_FrameworkMagic();
   const int now_count = QM_TM_OpenPositionCount(magic);
   if(g_prev_pos_count > 0 && now_count == 0)
      g_last_sl_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: bar-open time
   g_prev_pos_count = now_count;
  }

// True if the current closed bar is still inside the post-SL cool-down window.
bool InCooldown()
  {
   if(g_last_sl_bar_time <= 0 || strategy_cooldown_bars <= 0)
      return false;
   const datetime bar1 = iTime(_Symbol, _Period, 1); // perf-allowed: bar-open time
   if(bar1 <= 0)
      return false;
   const int elapsed = (int)((bar1 - g_last_sl_bar_time) / PeriodSeconds(_Period));
   return (elapsed >= 0 && elapsed < strategy_cooldown_bars);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard. Fail-OPEN on .DWX zero modeled spread
// (ask == bid); only a genuinely wide spread blocks. (No session window in the
// card — STC trades the full H1 schedule; the rollover/news windows are handled
// by the framework news filter + Friday-close.)
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate) and that
// AdvanceState_OnNewBar() already ran this bar (STC cached).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(!g_stc_ready)
      return false;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Post-SL cool-down.
   if(InCooldown())
      return false;

   const double ema_bias  = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   const double ema_slope = QM_EMA(_Symbol, _Period, strategy_ema_bias_period,
                                   1 + strategy_ema_slope_lookback);
   if(ema_bias <= 0.0 || ema_slope <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2);
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // STC zone-cross EVENTS (single trigger per side).
   const bool cross_up_os   = (g_stc2 < strategy_stc_os_level && g_stc1 >= strategy_stc_os_level);
   const bool cross_down_ob = (g_stc2 > strategy_stc_ob_level && g_stc1 <= strategy_stc_ob_level);

   // --- BUY: bullish bias + slope-up + STC cross-up of 25 + bar agrees ---
   if(close1 > ema_bias &&             // STATE: trend bias
      ema_bias >= ema_slope &&         // STATE: EMA200 slope-up confirmation
      cross_up_os &&                   // EVENT: the only trigger
      close1 > close2)                 // STATE: trigger bar closed up
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "stc_cross_up_25";
      return true;
     }

   // --- SELL: bearish bias + slope-down + STC cross-down of 75 + bar agrees ---
   if(close1 < ema_bias &&
      ema_bias <= ema_slope &&         // STATE: EMA200 slope-down confirmation
      cross_down_ob &&
      close1 < close2)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "stc_cross_down_75";
      return true;
     }

   return false;
  }

// Per-tick: one-time break-even shift after +strategy_be_atr_mult * ATR favourable.
// QM_TM_MoveToBreakEven is idempotent (only moves the SL toward BE once it is
// improving), so calling it per tick after the trigger is safe.
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   // Break-even trigger distance expressed in pips for the framework helper.
   const double be_dist_price = strategy_be_atr_mult * atr_value;
   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return;
   const int trigger_pips = (int)MathRound(be_dist_price / pip);
   if(trigger_pips <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      QM_TM_MoveToBreakEven(ticket, trigger_pips, 2);
     }
  }

// Closed-bar exits: STC opposite zone-cross, EMA-bias flip against the position,
// or time-stop. Caller closes the magic's positions on true.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(!g_stc_ready)
      return false;

   // Find this magic's open position to read direction + open time.
   bool have_long  = false;
   bool have_short = false;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  have_long  = true;
      if(ptype == POSITION_TYPE_SELL) have_short = true;
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
     }
   if(!have_long && !have_short)
      return false;

   // --- Time-stop: held >= N H1 bars ---
   if(strategy_time_stop_bars > 0 && open_time > 0)
     {
      const int held_bars = (int)((TimeCurrent() - open_time) / PeriodSeconds(_Period));
      if(held_bars >= strategy_time_stop_bars)
         return true;
     }

   const double ema_bias = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed single read

   // STC opposite zone-cross EVENTS.
   const bool cross_up_os   = (g_stc2 < strategy_stc_os_level && g_stc1 >= strategy_stc_os_level);
   const bool cross_down_ob = (g_stc2 > strategy_stc_ob_level && g_stc1 <= strategy_stc_ob_level);

   if(have_long)
     {
      // Schaff re-arm rule: BUY closes on STC cross-down through 75.
      if(cross_down_ob)
         return true;
      // EMA-bias flip against the long.
      if(ema_bias > 0.0 && close1 > 0.0 && close1 < ema_bias)
         return true;
     }

   if(have_short)
     {
      // SELL closes on STC cross-up through 25.
      if(cross_up_os)
         return true;
      if(ema_bias > 0.0 && close1 > 0.0 && close1 > ema_bias)
         return true;
     }

   return false;
  }

// Defer to the central news filter (card: 30-min skip pre/post tier-1
// USD/EUR/GBP/JPY news, satisfied by the framework's PRE30_POST30 temporal mode).
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

   g_stc_ready        = false;
   g_last_sl_bar_time = 0;
   g_prev_pos_count   = 0;

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

   // Advance cached STC state ONCE per closed bar, then run the entry gate.
   AdvanceState_OnNewBar();

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
