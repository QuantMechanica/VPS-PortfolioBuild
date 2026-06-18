#property strict
#property version   "5.0"
#property description "QM5_1314 vwap-sigma-bands-breakout-m15 — Session-VWAP sigma-band breakout (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1314 vwap-sigma-bands-breakout-m15
// -----------------------------------------------------------------------------
// Source: FF Trading-Systems VWAP cluster; Berkowitz/Logue/Noser JoF 1988
//         (academic VWAP) + Brian Shannon "Maximum Trading Gains with Anchored
//         VWAP". Card: artifacts/cards_approved/QM5_1314_vwap-sigma-bands-
//         breakout-m15.md (g0_status APPROVED).
//
// Mechanics (M15, closed-bar reads at shift 1; trend-CONTINUATION on band break):
//   Session anchor : 00:00 broker-time. Accumulators reset each broker-day.
//   VWAP STATE     : vwap = sum(tp*v)/sum(v) over the current session, where
//                    tp = (H+L+C)/3 and v = tick_volume (TICK-VOLUME PROXY — see
//                    flag below; .DWX has no real exchange volume).
//   Sigma STATE    : sigma = sqrt( sum((tp-vwap)^2 * v) / sum(v) ).
//   Bands STATE    : upper = vwap + k*sigma ; lower = vwap - k*sigma.
//   Trigger EVENT  : FIRST M15 close beyond a band — close[2] inside, close[1]
//                    beyond. ONE event (avoids the two-cross zero-trade trap;
//                    the band itself is STATE, the cross-out is the single EVENT).
//   BUY filters    : H1 close > EMA(macro) (trend bias) AND tick-vol[1] >
//                    SMA(tick-vol,20)[2] (volume confirmation) AND warm-up done
//                    AND inside entry session-window.
//   SELL           : mirror (close below lower band, H1 close < macro EMA).
//   Exit (manual)  : VWAP retest from the breakout side, OR end-of-session
//                    timeout at 23:30 broker-time.
//   Stop           : VWAP at entry (mean-return invalidates the breakout).
//   Take profit    : entry +/- tp_atr_mult * ATR(14, M15).
//   Re-arm         : after a flat->position transition the band-cross naturally
//                    re-arms (close must come from inside the band again).
//
// State is advanced ONCE per closed bar in AdvanceState_OnNewBar (intraday
// cached-state discipline). Strategy_EntrySignal only reads cached file-scope
// state + current quote — no per-tick history scans.
//
// .DWX INVARIANTS honoured:
//   * VWAP volume uses TICK volume (iVolume) — real volume is unavailable on
//     .DWX CFDs; flagged setfile_flag vwap_tick_volume_proxy.
//   * Spread guard fails OPEN on zero modeled spread.
//   * No swap gating. Session windows in BROKER time (platform clock).
//   * ONE band-cross is the trigger; everything else is STATE.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1314;
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
input double strategy_sigma_mult        = 2.0;    // k: band = VWAP +/- k*sigma (P3 1.5-2.5)
input int    strategy_warmup_bars       = 12;     // M15 bars since anchor before trading (P3 8-16)
input int    strategy_macro_ema_period  = 200;    // H1 macro-bias EMA period (P3 100-300)
input int    strategy_vol_sma_period    = 20;     // tick-volume confirmation SMA period
input double strategy_vol_sma_mult      = 1.0;    // tick-vol[1] must exceed this * SMA (P3 1.0-1.5)
input int    strategy_atr_period        = 14;     // ATR period for take-profit
input double strategy_tp_atr_mult       = 2.0;    // take-profit distance = mult * ATR (P3 1.5-3.0)
input int    strategy_entry_start_hour  = 2;      // entry window open, broker time (inclusive)
input int    strategy_entry_end_hour    = 20;     // entry window close, broker time (exclusive)
input int    strategy_eod_close_hour    = 23;     // end-of-session timeout hour, broker time
input int    strategy_eod_close_min     = 30;     // end-of-session timeout minute, broker time
input double strategy_spread_pct_of_atr = 25.0;   // skip if spread > this % of ATR distance

// -----------------------------------------------------------------------------
// File-scope cached session state (advanced once per closed bar)
// -----------------------------------------------------------------------------
datetime g_session_day      = 0;     // broker-date (midnight) of the active session
int      g_session_bars     = 0;     // closed M15 bars accumulated since the anchor
double   g_cum_v            = 0.0;    // cumulative tick-volume
double   g_cum_tpv          = 0.0;    // cumulative typical_price * volume
double   g_cum_tp2v         = 0.0;    // cumulative typical_price^2 * volume (for variance)
double   g_vwap            = 0.0;     // current session VWAP
double   g_sigma           = 0.0;     // current session volume-weighted sigma
double   g_upper_band      = 0.0;     // VWAP + k*sigma
double   g_lower_band      = 0.0;     // VWAP - k*sigma
bool     g_state_ready     = false;   // bands valid this session (warm-up complete)

// Trigger latch: a fresh band-cross detected on the just-closed bar.
int      g_cross_dir        = 0;      // +1 close crossed above upper, -1 below lower, 0 none

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

// Reset all session accumulators to a fresh anchor.
void ResetSessionState(const datetime day_anchor)
  {
   g_session_day  = day_anchor;
   g_session_bars = 0;
   g_cum_v        = 0.0;
   g_cum_tpv      = 0.0;
   g_cum_tp2v     = 0.0;
   g_vwap         = 0.0;
   g_sigma        = 0.0;
   g_upper_band   = 0.0;
   g_lower_band   = 0.0;
   g_state_ready  = false;
  }

// Advance session VWAP/sigma/bands by exactly ONE just-closed bar (shift 1).
// Called once per new closed bar (intraday cached-state discipline). Detects
// the broker-day rollover and re-anchors the accumulators at 00:00.
void AdvanceState_OnNewBar()
  {
   // Broker open-time of the bar that just closed (shift 1).
   const datetime bar_time = iTime(_Symbol, _Period, 1);      // perf-allowed: single closed-bar read
   if(bar_time <= 0)
      return;

   const datetime this_day = SessionDayOf(bar_time);
   if(this_day != g_session_day)
      ResetSessionState(this_day);   // new broker-day -> fresh session anchor

   const double h = iHigh(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double l = iLow(_Symbol, _Period, 1);    // perf-allowed: single closed-bar read
   const double c = iClose(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double v = (double)iVolume(_Symbol, _Period, 1); // TICK volume proxy (.DWX has no real volume)
   if(h <= 0.0 || l <= 0.0 || c <= 0.0)
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

   // Volume-weighted variance: E[tp^2] - E[tp]^2, clamped non-negative.
   double variance = (g_cum_tp2v / g_cum_v) - (g_vwap * g_vwap);
   if(variance < 0.0)
      variance = 0.0;
   g_sigma = MathSqrt(variance);

   g_upper_band = g_vwap + strategy_sigma_mult * g_sigma;
   g_lower_band = g_vwap - strategy_sigma_mult * g_sigma;

   // Bands are only tradeable after the warm-up window AND once sigma is real.
   g_state_ready = (g_session_bars >= strategy_warmup_bars && g_sigma > 0.0);

   // --- Trigger EVENT: first close beyond a band ---------------------------
   // Compare the just-closed bar (shift 1) against the band as it stood on the
   // PRIOR closed bar (shift 2). One event per breakout; the band is STATE.
   g_cross_dir = 0;
   if(g_state_ready && g_session_bars > strategy_warmup_bars)
     {
      const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
      if(close_prev > 0.0)
        {
         // Band level one bar earlier = the band BEFORE this bar's contribution.
         // Recompute the prior band from the accumulators minus this bar.
         const double prev_cum_v   = g_cum_v   - vv;
         const double prev_cum_tpv = g_cum_tpv - tp * vv;
         const double prev_cum_t2v = g_cum_tp2v - tp * tp * vv;
         if(prev_cum_v > 0.0)
           {
            const double prev_vwap = prev_cum_tpv / prev_cum_v;
            double prev_var = (prev_cum_t2v / prev_cum_v) - (prev_vwap * prev_vwap);
            if(prev_var < 0.0)
               prev_var = 0.0;
            const double prev_sigma = MathSqrt(prev_var);
            const double prev_upper = prev_vwap + strategy_sigma_mult * prev_sigma;
            const double prev_lower = prev_vwap - strategy_sigma_mult * prev_sigma;

            // close[2] inside band, close[1] beyond band -> fresh breakout.
            if(close_prev <= prev_upper && c > g_upper_band)
               g_cross_dir = +1;
            else if(close_prev >= prev_lower && c < g_lower_band)
               g_cross_dir = -1;
           }
        }
     }
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
   if(spread > 0.0 && spread > (strategy_spread_pct_of_atr / 100.0) * atr_value)
      return true;

   return false;
  }

// Breakout entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate),
// and AdvanceState_OnNewBar() has already run for this bar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Need a valid, warmed-up band state and a fresh cross EVENT this bar.
   if(!g_state_ready || g_cross_dir == 0)
      return false;
   if(g_vwap <= 0.0)
      return false;

   // --- Entry session-window (broker time of the just-closed bar) ----------
   const datetime bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(bar_time <= 0)
      return false;
   MqlDateTime bt;
   TimeToStruct(bar_time, bt);
   if(bt.hour < strategy_entry_start_hour || bt.hour >= strategy_entry_end_hour)
      return false;

   // --- Volume confirmation: tick-vol[1] above its tick-volume SMA ---------
   // No QM_* reader exists for tick volume (the price-SMA readers are for price
   // series), so compute the tick-vol SMA directly over a bounded, fixed window
   // (period bars, one-pass, closed bars only — no per-tick history scan).
   const double vol_last = (double)iVolume(_Symbol, _Period, 1); // perf-allowed: single read
   double vsum = 0.0;
   int    vcount = 0;
   for(int s = 2; s < 2 + strategy_vol_sma_period; ++s)
     {
      const double vs = (double)iVolume(_Symbol, _Period, s); // perf-allowed: bounded fixed window
      if(vs <= 0.0)
         continue;
      vsum += vs;
      vcount += 1;
     }
   if(vcount <= 0)
      return false;
   const double tickvol_sma = vsum / vcount;
   if(!(vol_last > strategy_vol_sma_mult * tickvol_sma))
      return false;

   // --- Macro bias on H1: close vs EMA(macro_period) -----------------------
   const double h1_close = iClose(_Symbol, PERIOD_H1, 1);  // perf-allowed: single closed-bar read
   const double h1_ema   = QM_EMA(_Symbol, PERIOD_H1, strategy_macro_ema_period, 1);
   if(h1_close <= 0.0 || h1_ema <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_cross_dir > 0)
     {
      // BUY: upper-band breakout, macro bias up.
      if(!(h1_close > h1_ema))
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL = session VWAP (mean-return invalidates the breakout).
      const double sl = QM_TM_NormalizePrice(_Symbol, g_vwap);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      if(!(sl < entry))      // VWAP must sit below entry for a long stop
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;      // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "vwap_sigma_break_long";
      return true;
     }
   else // g_cross_dir < 0
     {
      // SELL: lower-band breakdown, macro bias down.
      if(!(h1_close < h1_ema))
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_TM_NormalizePrice(_Symbol, g_vwap);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      if(!(sl > entry))      // VWAP must sit above entry for a short stop
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "vwap_sigma_break_short";
      return true;
     }
  }

// No active SL/TP management; the fixed VWAP stop + ATR target stand. The
// VWAP-retest and end-of-session timeout are handled in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Manual exit: (1) VWAP retest from the breakout side, or (2) end-of-session
// timeout at strategy_eod_close (broker time).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // --- End-of-session timeout (broker time) — applies to any open trade ---
   const datetime broker_now = TimeCurrent();
   MqlDateTime nowdt;
   TimeToStruct(broker_now, nowdt);
   const int now_minute = nowdt.hour * 60 + nowdt.min;
   const int eod_minute = strategy_eod_close_hour * 60 + strategy_eod_close_min;
   if(now_minute >= eod_minute)
      return true;

   if(g_vwap <= 0.0)
      return false;

   // --- VWAP retest from the breakout side ---------------------------------
   // BUY exits if price re-touches VWAP from above; SELL if from below.
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
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > 0.0 && bid <= g_vwap)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask > 0.0 && ask >= g_vwap)
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
