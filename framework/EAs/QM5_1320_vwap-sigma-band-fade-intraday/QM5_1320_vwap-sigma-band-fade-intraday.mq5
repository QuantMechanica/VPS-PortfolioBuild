#property strict
#property version   "5.0"
#property description "QM5_1320 vwap-sigma-band-fade-intraday — Session-VWAP sigma-band FADE (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1320 vwap-sigma-band-fade-intraday
// -----------------------------------------------------------------------------
// BUILD TARGET ea_id = 1320 (card frontmatter says QM5_12130 — STALE; this EA is
// built and registered as 1320 per the orchestrator build target. Mismatch flagged
// in the build_result notes.)
//
// Source: FF Trading-Systems VWAP cluster (FADE branch); Berkowitz/Logue/Noser
//         JoF 43:1 1988 (academic VWAP) + Brian Shannon "Maximum Trading Gains
//         with Anchored VWAP" (sigma-band fade methodology). Card:
//         artifacts/cards_approved/QM5_1320_vwap-sigma-band-fade-intraday.md
//         (g0_status APPROVED). Direct sibling of QM5_1314 (breakout branch),
//         same indicator pair, OPPOSITE-side mean-reversion edge.
//
// Mechanics (M15, closed-bar reads at shift 1; mean-reversion FADE back to VWAP):
//   Session anchor : 06:00 broker-time. Accumulators re-anchor each broker-day
//                    at the first bar whose hour >= session_start_hour. Bars
//                    before 06:00 do not contribute to VWAP/sigma.
//   VWAP STATE     : vwap = sum(tp*v)/sum(v) over the current session, where
//                    tp = (H+L+C)/3 and v = tick_volume (TICK-VOLUME PROXY — .DWX
//                    has no real exchange volume; flagged below).
//   Sigma STATE    : sigma = sqrt( sum(tp^2*v)/sum(v) - vwap^2 ), clamped >= 0.
//   Bands STATE    : upper = vwap + k*sigma ; lower = vwap - k*sigma.
//   Trigger EVENT  : on the just-closed bar (shift 1) a REJECTION candle:
//                    SELL  -> high[1] >= upper AND close[1] < upper (wick spiked
//                             into/through the upper band but closed back inside)
//                             AND bearish-body agreement.
//                    BUY   -> low[1]  <= lower AND close[1] > lower AND bullish.
//                    This is the ONE event; the band is STATE. (Avoids the
//                    two-cross zero-trade trap.)
//   Entry filters  : RSI14(M15)[1] > rsi_high (SELL) / < rsi_low (BUY);
//                    macro-bias CONSISTENCY close[1] vs EMA(macro)[H1]
//                    (fade upper ONLY in macro-UPtrend; fade lower ONLY in
//                    macro-DOWNtrend — fade WITH the macro trend, not against it);
//                    min session age (warm-up bars since anchor); band width
//                    > width_atr_mult * ATR(20,M15); inside session window;
//                    re-arm gate (suppress same-side re-entry until close has
//                    crossed VWAP since the last same-side exit).
//   Exit (manual)  : (1) close re-touches VWAP (fade thesis = back to the mean);
//                    (2) hard TP cap tp_atr_cap_mult * ATR(20,M15) from entry
//                        (carried as the order TP);
//                    (3) time-stop after timestop_bars M15 bars;
//                    (4) session-close at session_end_hour broker-time.
//   Stop           : hard SL = entry +/- sl_atr_mult * ATR(20,M15). No widening.
//
// State is advanced ONCE per closed bar in AdvanceState_OnNewBar (intraday
// cached-state discipline). Strategy_EntrySignal only reads cached file-scope
// state + bounded closed-bar reads — no per-tick history scans.
//
// .DWX INVARIANTS honoured:
//   * VWAP volume uses TICK volume (iVolume) — real volume unavailable on .DWX
//     CFDs; PROXY flagged (vwap_tick_volume_proxy).
//   * Spread guard fails OPEN on zero modeled spread.
//   * No swap gating. Session windows in BROKER time (platform clock).
//   * ONE rejection candle is the trigger; everything else is STATE.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1320;
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
input double strategy_sigma_mult        = 2.0;   // k: band = VWAP +/- k*sigma (P3 1.8-2.5)
input int    strategy_warmup_bars       = 8;     // min M15 bars since anchor (2h anti-noise; P3 6-12)
input int    strategy_macro_ema_period  = 200;   // H1 macro-bias EMA period (P3 100-300)
input double strategy_rsi_high          = 65.0;  // SELL: RSI14[1] must exceed (P3 60-75)
input double strategy_rsi_low           = 35.0;  // BUY: RSI14[1] must fall below (P3 25-40)
input int    strategy_rsi_period        = 14;    // RSI period (M15)
input int    strategy_atr_period        = 20;    // ATR period for SL / TP cap / band-width
input double strategy_sl_atr_mult       = 0.8;   // hard SL distance = mult * ATR (P3 0.5-1.2)
input double strategy_tp_atr_cap_mult   = 1.5;   // hard TP cap distance = mult * ATR
input double strategy_width_atr_mult    = 0.5;   // band width must exceed mult * ATR
input double strategy_doji_body_frac    = 0.1;   // |close-open| < frac*(H-L) => doji handling
input int    strategy_timestop_bars     = 12;    // close after N M15 bars (3h) w/o VWAP touch
input int    strategy_session_start_hour = 6;    // session anchor hour, broker time (inclusive)
input int    strategy_session_end_hour  = 21;    // session close hour, broker time (close-all)

// -----------------------------------------------------------------------------
// File-scope cached session state (advanced once per closed bar)
// -----------------------------------------------------------------------------
datetime g_session_day      = 0;     // broker-date (midnight) of the active session
bool     g_session_anchored = false; // true once the 06:00 anchor bar has been seen today
int      g_session_bars     = 0;     // closed M15 bars accumulated since the anchor
double   g_cum_v            = 0.0;   // cumulative tick-volume
double   g_cum_tpv          = 0.0;   // cumulative typical_price * volume
double   g_cum_tp2v         = 0.0;   // cumulative typical_price^2 * volume (variance)
double   g_vwap            = 0.0;    // current session VWAP
double   g_sigma           = 0.0;    // current session volume-weighted sigma
double   g_upper_band      = 0.0;    // VWAP + k*sigma
double   g_lower_band      = 0.0;    // VWAP - k*sigma
bool     g_state_ready     = false;  // bands valid this session (warm-up complete)

// Trigger latch: a fresh rejection candle on the just-closed bar.
int      g_fade_dir         = 0;     // +1 BUY fade (lower band), -1 SELL fade (upper band), 0 none

// Trade bookkeeping for time-stop + re-arm.
datetime g_entry_bar_time   = 0;     // bar-open time of the bar on which we entered
int      g_last_exit_dir    = 0;     // +1 last exit was a long fade, -1 short, 0 none
bool     g_rearm_ok         = true;  // re-arm satisfied (close crossed VWAP since last exit)

// Broker-midnight of a broker datetime.
datetime SessionDayOf(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
  }

// Reset all session accumulators to a fresh (un-anchored) day.
void ResetSessionState(const datetime day_anchor)
  {
   g_session_day     = day_anchor;
   g_session_anchored = false;
   g_session_bars    = 0;
   g_cum_v           = 0.0;
   g_cum_tpv         = 0.0;
   g_cum_tp2v        = 0.0;
   g_vwap            = 0.0;
   g_sigma           = 0.0;
   g_upper_band      = 0.0;
   g_lower_band      = 0.0;
   g_state_ready     = false;
   g_fade_dir        = 0;
  }

// Advance session VWAP/sigma/bands by exactly ONE just-closed bar (shift 1).
// Called once per new closed bar (intraday cached-state discipline). Detects the
// broker-day rollover and only accumulates from the 06:00 session anchor onward.
void AdvanceState_OnNewBar()
  {
   g_fade_dir = 0;

   // Broker open-time of the bar that just closed (shift 1).
   const datetime bar_time = iTime(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   if(bar_time <= 0)
      return;

   const datetime this_day = SessionDayOf(bar_time);
   if(this_day != g_session_day)
      ResetSessionState(this_day);     // new broker-day -> fresh session anchor

   MqlDateTime bt;
   TimeToStruct(bar_time, bt);

   // Only accumulate inside the session window [start_hour, end_hour).
   if(bt.hour < strategy_session_start_hour || bt.hour >= strategy_session_end_hour)
      return;

   g_session_anchored = true;

   const double h = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double l = iLow(_Symbol, _Period, 1);    // perf-allowed: single closed-bar read
   const double c = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double o = iOpen(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double v = (double)iVolume(_Symbol, _Period, 1); // TICK volume proxy (.DWX has no real volume)
   if(h <= 0.0 || l <= 0.0 || c <= 0.0 || o <= 0.0)
      return;

   const double tp = (h + l + c) / 3.0;
   const double vv = (v > 0.0 ? v : 1.0);          // guard a zero-tick bar

   g_cum_v    += vv;
   g_cum_tpv  += tp * vv;
   g_cum_tp2v += tp * tp * vv;
   g_session_bars += 1;

   if(g_cum_v <= 0.0)
      return;

   g_vwap = g_cum_tpv / g_cum_v;

   double variance = (g_cum_tp2v / g_cum_v) - (g_vwap * g_vwap);
   if(variance < 0.0)
      variance = 0.0;
   g_sigma = MathSqrt(variance);

   g_upper_band = g_vwap + strategy_sigma_mult * g_sigma;
   g_lower_band = g_vwap - strategy_sigma_mult * g_sigma;

   // Bands tradeable only after the warm-up window AND once sigma is real.
   g_state_ready = (g_session_bars >= strategy_warmup_bars && g_sigma > 0.0);

   // --- Re-arm bookkeeping: a same-side re-entry is suppressed until close has
   //     crossed VWAP (price returned to / through the mean) since the last exit.
   if(g_last_exit_dir > 0 && c <= g_vwap)        // long fade exited; close back at/below VWAP
      g_rearm_ok = true;
   else if(g_last_exit_dir < 0 && c >= g_vwap)   // short fade exited; close back at/above VWAP
      g_rearm_ok = true;

   if(!g_state_ready)
      return;

   // --- Trigger EVENT: rejection candle on the just-closed bar ---------------
   // SELL fade: spiked into/through the upper band, closed back inside.
   const bool sell_touch = (h >= g_upper_band && c < g_upper_band);
   const bool buy_touch  = (l <= g_lower_band && c > g_lower_band);

   const double body  = c - o;
   const double range = h - l;

   // Body agreement (with doji-leaning handling per card rule 2).
   bool bearish_ok;
   bool bullish_ok;
   if(range > 0.0 && MathAbs(body) < strategy_doji_body_frac * range)
     {
      // Doji-ish: lean bearish if close sits below the doji mid + small buffer; mirror for bullish.
      const double mid = (o + c) / 2.0;
      bearish_ok = (c < mid + strategy_doji_body_frac * range);
      bullish_ok = (c > mid - strategy_doji_body_frac * range);
     }
   else
     {
      bearish_ok = (c < o);
      bullish_ok = (c > o);
     }

   if(sell_touch && bearish_ok)
      g_fade_dir = -1;
   else if(buy_touch && bullish_ok)
      g_fade_dir = +1;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only (fail-open on .DWX zero spread).
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_width_atr_mult * atr_value))
      return true;

   return false;
  }

// Fade entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate), and
// AdvanceState_OnNewBar() has already run for this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Need a warmed-up band state and a fresh rejection EVENT this bar.
   if(!g_state_ready || g_fade_dir == 0)
      return false;
   if(g_vwap <= 0.0)
      return false;

   // --- Entry session-window (broker time of the just-closed bar) ----------
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_time <= 0)
      return false;
   MqlDateTime bt;
   TimeToStruct(bar_time, bt);
   if(bt.hour < strategy_session_start_hour || bt.hour >= strategy_session_end_hour)
      return false;

   // --- Band width must be meaningful: > width_atr_mult * ATR(20,M15) -------
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;
   if((g_upper_band - g_lower_band) <= strategy_width_atr_mult * atr_value)
      return false;

   // --- RSI confirmation (M15, closed bar) ---------------------------------
   const double rsi = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi <= 0.0)
      return false;

   // --- Macro-bias CONSISTENCY on H1: close vs EMA(macro_period) -----------
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1);  // perf-allowed: single closed-bar read
   const double h1_ema   = QM_EMA(_Symbol, PERIOD_H1, strategy_macro_ema_period, 1);
   if(h1_close <= 0.0 || h1_ema <= 0.0)
      return false;

   // Re-arm: suppress same-side re-entry until close has crossed VWAP since exit.
   if(g_fade_dir == g_last_exit_dir && !g_rearm_ok)
      return false;

   if(g_fade_dir < 0)
     {
      // SELL fade upper band: RSI overbought + macro-UPtrend (fade WITH macro).
      if(!(rsi > strategy_rsi_high))
         return false;
      if(!(h1_close > h1_ema))
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_cap_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      if(!(sl > entry) || !(tp < entry))   // SELL: SL above, TP below
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;      // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "vwap_sigma_fade_short";
      g_entry_bar_time = bar_time;
      g_rearm_ok = false;
      return true;
     }
   else // g_fade_dir > 0
     {
      // BUY fade lower band: RSI oversold + macro-DOWNtrend (fade WITH macro).
      if(!(rsi < strategy_rsi_low))
         return false;
      if(!(h1_close < h1_ema))
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_cap_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      if(!(sl < entry) || !(tp > entry))   // BUY: SL below, TP above
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "vwap_sigma_fade_long";
      g_entry_bar_time = bar_time;
      g_rearm_ok = false;
      return true;
     }
  }

// No active SL/TP modification; the hard ATR SL + ATR TP-cap stand. The primary
// VWAP-touch exit, time-stop, and session-close are handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Manual exit: (1) close re-touches VWAP (primary fade target); (2) time-stop
// after timestop_bars M15 bars; (3) session-close at session_end_hour broker time.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // --- Session-close (broker time) — applies to any open trade ------------
   const datetime broker_now = TimeCurrent();
   MqlDateTime nowdt;
   TimeToStruct(broker_now, nowdt);
   if(nowdt.hour >= strategy_session_end_hour)
      return true;

   // --- Time-stop: N M15 bars elapsed since entry --------------------------
   if(g_entry_bar_time > 0)
     {
      const datetime last_closed = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(last_closed > 0)
        {
         const long elapsed_bars = (long)((last_closed - g_entry_bar_time) / (PeriodSeconds(_Period)));
         if(elapsed_bars >= strategy_timestop_bars)
            return true;
        }
     }

   if(g_vwap <= 0.0)
      return false;

   // --- Primary exit: price re-touches VWAP from the fade side -------------
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // Long fade from below VWAP: exit when bid rises back to/through VWAP.
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid >= g_vwap)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Short fade from above VWAP: exit when ask falls back to/through VWAP.
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && ask <= g_vwap)
            return true;
        }
     }
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

   ResetSessionState(0);
   g_last_exit_dir = 0;
   g_rearm_ok      = true;
   g_entry_bar_time = 0;
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
      // Latch the exit side for the re-arm gate before closing.
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         const long ptype = PositionGetInteger(POSITION_TYPE);
         g_last_exit_dir = (ptype == POSITION_TYPE_BUY ? +1 : -1);
         g_rearm_ok = false;   // require a VWAP cross before re-arming the same side
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      g_entry_bar_time = 0;
     }

   if(!QM_IsNewBar())
      return;

   // FIRST on a new closed bar: advance cached session VWAP/sigma/band state.
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
