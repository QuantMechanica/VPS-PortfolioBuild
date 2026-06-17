#property strict
#property version   "5.0"
#property description "QM5_10675 tv-ls-mr-xau — TradingView XAU Liquidity Sweep Mean Reversion"

#include <QM/QM_Common.mqh>

// =============================================================================
// QM5_10675 — TradingView XAU Liquidity Sweep Mean Reversion
// -----------------------------------------------------------------------------
// Source: Just_Aboy, "Liquidity Sweep Mean Reversion [XAUUSD/XAGUSD]",
//   https://www.tradingview.com/script/fVu5DNuk/  (card g0_status: APPROVED)
//
// Mechanic (closed-bar only, .DWX-tester safe):
//   * Map liquidity pools = highest-high / lowest-low over a short (20) and a
//     long (50) lookback on the base timeframe.
//   * Bullish sweep  = a recent bar WICKS BELOW the mapped liquidity low and
//     CLOSES BACK INSIDE the range. (sweep is decoupled from the reversal:
//     it may have occurred up to qm_sweep_lookback bars ago — DWX invariant #4).
//   * Bearish sweep  = mirror above the liquidity high.
//   * Balanced LONG  = active bullish sweep + price reclaims fast/slow EMA
//     structure (close>fast EMA AND fast EMA>slow EMA) + close above session
//     VWAP + opposing-pool TP gives >= min RRR.
//   * Balanced SHORT = mirror below VWAP after a bearish sweep.
//   * Stop  = beyond the sweep wick + buffer, floored to max(0.15*ATR, ...).
//   * TP    = opposing liquidity pool (full).
//   * Exits = TP/SL, plus a hard time-stop after N base bars.
//
// Only the 5 Strategy_* hooks below carry strategy logic. All framework wiring
// (OnInit/OnTick/news/Friday-close/risk/magic) is the stock skeleton.
//
// .DWX invariants honoured (see codex_build_ea.md "BACKTEST INVARIANTS"):
//   #1 spread guard fails OPEN on zero modeled spread.
//   #3 QM_IsNewBar consumed ONCE per tick (latched in OnTick by the skeleton).
//   #4 sweep EVENT decoupled from the reversal STATE across bars.
//   #5 session window kept in UTC but applied to the broker clock via
//      QM_BrokerToUTC so the 08:00-20:00 UTC window lands on real hours.
//   #14 gold scaling: all price distances are ATR/structure-derived (price
//      units), never raw *_points; the buffer floor uses ATR, not points.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10675;
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
// Liquidity-pool lookbacks (base-TF bars).
input int    qm_lookback_short          = 20;     // short liquidity map
input int    qm_lookback_long           = 50;     // long liquidity map
// Sweep is decoupled from the reversal: it may have fired in the last N bars.
input int    qm_sweep_lookback          = 5;      // bars to scan for a sweep
// EMA structure (fast must be above slow for a long; mirror for short).
input int    qm_ema_fast                = 9;
input int    qm_ema_slow                = 21;
// Session VWAP window, in UTC hours (card default 08:00-20:00 UTC).
input int    qm_session_start_utc       = 8;
input int    qm_session_end_utc         = 20;
// Stop / target shaping.
input double qm_sl_buffer_pct           = 0.3;    // % of price beyond the wick
input int    qm_atr_period              = 14;
input double qm_sl_atr_floor_mult       = 0.15;   // floor: max(0.15*ATR, buffer)
input double qm_min_rrr                 = 1.5;    // skip if pool TP < this RRR
input double qm_max_sl_atr_mult         = 2.5;    // skip if stop > 2.5*ATR
// Hard time-stop, expressed in base-TF bars (card: 36 M5 bars).
input int    qm_time_stop_bars          = 36;

// -----------------------------------------------------------------------------
// Cached per-closed-bar strategy state (advanced once per new bar; the per-tick
// hooks only read these). Prevents per-tick CopyRates / VWAP re-summing.
// -----------------------------------------------------------------------------
double   g_liq_high      = 0.0;   // mapped liquidity high (opposing pool for short)
double   g_liq_low       = 0.0;   // mapped liquidity low  (opposing pool for long)
double   g_sweep_low     = 0.0;   // wick low of the detected bullish sweep
double   g_sweep_high    = 0.0;   // wick high of the detected bearish sweep
bool     g_bull_sweep    = false; // a bullish sweep is active in the window
bool     g_bear_sweep    = false; // a bearish sweep is active in the window
double   g_session_vwap  = 0.0;   // current session VWAP
double   g_vwap_cum_pv   = 0.0;   // cumulative (typical*volume) this session
double   g_vwap_cum_v    = 0.0;   // cumulative volume this session
datetime g_vwap_day      = 0;     // session/day anchor for the VWAP reset
datetime g_state_bar     = 0;     // last bar advanced (idempotency guard)
datetime g_entry_bar     = 0;     // bar-open time when the position opened

// -----------------------------------------------------------------------------
// Liquidity map: highest-high / lowest-low over the short & long lookbacks.
// Closed bars only (shift>=1). // perf-allowed: structural extreme scan, run
// ONCE per new closed bar from AdvanceState_OnNewBar (not per tick).
// -----------------------------------------------------------------------------
void MapLiquidityPools()
  {
   const int look = MathMax(qm_lookback_short, qm_lookback_long);
   double hh = -DBL_MAX;
   double ll =  DBL_MAX;
   for(int s = 1; s <= look; ++s)
     {
      const double hi = iHigh(_Symbol, _Period, s); // perf-allowed: closed-bar map
      const double lo = iLow(_Symbol, _Period, s);  // perf-allowed: closed-bar map
      if(hi > hh) hh = hi;
      if(lo < ll) ll = lo;
     }
   if(hh > -DBL_MAX) g_liq_high = hh;
   if(ll <  DBL_MAX) g_liq_low  = ll;
  }

// -----------------------------------------------------------------------------
// Sweep detection across the last qm_sweep_lookback CLOSED bars (DWX #4:
// the sweep EVENT is decoupled from the reversal/entry that happens NOW).
// Bullish sweep: a bar wicked below g_liq_low but CLOSED back inside the range.
// Bearish sweep: a bar wicked above g_liq_high but CLOSED back inside.
// -----------------------------------------------------------------------------
void DetectSweeps()
  {
   g_bull_sweep = false;
   g_bear_sweep = false;
   g_sweep_low  = 0.0;
   g_sweep_high = 0.0;

   if(g_liq_low <= 0.0 || g_liq_high <= 0.0)
      return;

   const int win = MathMax(1, qm_sweep_lookback);
   for(int s = 1; s <= win; ++s)
     {
      const double lo = iLow(_Symbol, _Period, s);   // perf-allowed: closed-bar scan
      const double hi = iHigh(_Symbol, _Period, s);  // perf-allowed: closed-bar scan
      const double cl = iClose(_Symbol, _Period, s); // perf-allowed: closed-bar scan

      // Most-recent qualifying sweep wins (keep the closest wick to "now").
      if(!g_bull_sweep && lo < g_liq_low && cl > g_liq_low)
        {
         g_bull_sweep = true;
         g_sweep_low  = lo;
        }
      if(!g_bear_sweep && hi > g_liq_high && cl < g_liq_high)
        {
         g_bear_sweep = true;
         g_sweep_high = hi;
        }
     }
  }

// -----------------------------------------------------------------------------
// Session VWAP, advanced ONE closed bar at a time. Resets at session start
// (the first in-session bar of a new UTC day). Uses tick volume — .DWX CFDs
// only carry tick volume, which is fine as a VWAP weight.
// -----------------------------------------------------------------------------
bool InSessionUTC(const datetime utc)
  {
   MqlDateTime st;
   TimeToStruct(utc, st);
   const int h = st.hour;
   if(qm_session_start_utc <= qm_session_end_utc)
      return (h >= qm_session_start_utc && h < qm_session_end_utc);
   // wrap-around safety (not expected for 8..20, but keep it robust)
   return (h >= qm_session_start_utc || h < qm_session_end_utc);
  }

void AdvanceSessionVWAP()
  {
   const datetime bar_broker = iTime(_Symbol, _Period, 1); // closed bar open
   if(bar_broker <= 0)
      return;
   const datetime bar_utc = QM_BrokerToUTC(bar_broker);

   if(!InSessionUTC(bar_utc))
     {
      // Out of session: hold the last VWAP; the next session start resets it.
      return;
     }

   MqlDateTime u;
   TimeToStruct(bar_utc, u);
   const datetime day_anchor = (datetime)(((long)bar_utc / 86400) * 86400);
   // New session day OR first in-session bar after a gap -> reset cumulatives.
   if(g_vwap_day != day_anchor)
     {
      g_vwap_day    = day_anchor;
      g_vwap_cum_pv = 0.0;
      g_vwap_cum_v  = 0.0;
     }

   const double hi  = iHigh(_Symbol, _Period, 1);              // perf-allowed
   const double lo  = iLow(_Symbol, _Period, 1);               // perf-allowed
   const double cl  = iClose(_Symbol, _Period, 1);             // perf-allowed
   const double tp  = (hi + lo + cl) / 3.0;
   double vol = (double)iTickVolume(_Symbol, _Period, 1);      // perf-allowed
   if(vol <= 0.0) vol = 1.0;                                   // gapless guard

   g_vwap_cum_pv += tp * vol;
   g_vwap_cum_v  += vol;
   if(g_vwap_cum_v > 0.0)
      g_session_vwap = g_vwap_cum_pv / g_vwap_cum_v;
  }

// -----------------------------------------------------------------------------
// Per-new-bar state advance. Called once after the OnTick QM_IsNewBar gate.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 == g_state_bar)
      return;                 // already advanced for this bar
   g_state_bar = t0;

   MapLiquidityPools();
   DetectSweeps();
   AdvanceSessionVWAP();
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Block trading outside the UTC session window. Cheap O(1) per tick.
// Spread guard FAILS OPEN on zero modeled spread (.DWX #1).
bool Strategy_NoTradeFilter()
  {
   const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
   if(!InSessionUTC(utc_now))
      return true;

   // Wide-spread guard only (never block on zero/equal spread in the tester).
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask > 0.0 && bid > 0.0 && ask > bid)
     {
      const double atr = QM_ATR(_Symbol, _Period, qm_atr_period, 1);
      if(atr > 0.0 && (ask - bid) > atr) // spread wider than a full ATR = junk tick
         return true;
     }
   return false;
  }

// One closed-bar entry. Caller guarantees QM_IsNewBar()==true and has already
// called AdvanceState_OnNewBar() this bar (state cached). O(1) here.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One position per magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(g_liq_high <= 0.0 || g_liq_low <= 0.0 || g_session_vwap <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, _Period, qm_atr_period, 1);
   if(atr <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1);   // last closed bar
   const double ema_f  = QM_EMA(_Symbol, _Period, qm_ema_fast, 1);
   const double ema_s  = QM_EMA(_Symbol, _Period, qm_ema_slow, 1);
   if(close1 <= 0.0 || ema_f <= 0.0 || ema_s <= 0.0)
      return false;

   // ----- LONG: bullish sweep + EMA reclaim + above VWAP + opposing-pool RRR
   if(g_bull_sweep && g_sweep_low > 0.0 &&
      close1 > ema_f && ema_f > ema_s &&
      close1 > g_session_vwap)
     {
      const double entry = close1;
      // Stop beyond the sweep wick + % buffer, floored to ATR fraction.
      const double buf   = entry * (qm_sl_buffer_pct / 100.0);
      double sl          = g_sweep_low - buf;
      const double floor_dist = qm_sl_atr_floor_mult * atr;
      if((entry - sl) < floor_dist)
         sl = entry - floor_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);

      const double risk = entry - sl;
      if(risk <= 0.0)
         return false;
      if(risk > qm_max_sl_atr_mult * atr)         // skip oversized stop
         return false;

      const double tp = g_liq_high;               // opposing pool
      if((tp - entry) < qm_min_rrr * risk)         // RRR floor
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;                            // market fill
      req.sl     = sl;
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "ls_mr_long_sweep";
      g_entry_bar = iTime(_Symbol, _Period, 0);
      return true;
     }

   // ----- SHORT: bearish sweep + EMA reclaim (below) + below VWAP + RRR
   if(g_bear_sweep && g_sweep_high > 0.0 &&
      close1 < ema_f && ema_f < ema_s &&
      close1 < g_session_vwap)
     {
      const double entry = close1;
      const double buf   = entry * (qm_sl_buffer_pct / 100.0);
      double sl          = g_sweep_high + buf;
      const double floor_dist = qm_sl_atr_floor_mult * atr;
      if((sl - entry) < floor_dist)
         sl = entry + floor_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);

      const double risk = sl - entry;
      if(risk <= 0.0)
         return false;
      if(risk > qm_max_sl_atr_mult * atr)
         return false;

      const double tp = g_liq_low;                // opposing pool
      if((entry - tp) < qm_min_rrr * risk)
         return false;

      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
      req.reason = "ls_mr_short_sweep";
      g_entry_bar = iTime(_Symbol, _Period, 0);
      return true;
     }

   return false;
  }

// TP/SL ride on the broker; partial exits disabled in baseline (one-position
// accounting). Nothing to actively manage here.
void Strategy_ManageOpenPosition()
  {
  }

// Hard time-stop: close after qm_time_stop_bars base bars if neither TP nor SL
// has been hit. Counts elapsed bars since the entry bar.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;
   if(g_entry_bar <= 0 || qm_time_stop_bars <= 0)
      return false;

   const datetime bar_now = iTime(_Symbol, _Period, 0);
   if(bar_now <= 0)
      return false;

   const int secs = PeriodSeconds(_Period);
   if(secs <= 0)
      return false;
   const int bars_elapsed = (int)((bar_now - g_entry_bar) / secs);
   if(bars_elapsed >= qm_time_stop_bars)
     {
      g_entry_bar = 0;
      return true;     // skeleton closes this magic's position with QM_EXIT_STRATEGY
     }
   return false;
  }

// Defer to the central two-axis news filter.
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

   // Single-consume new-bar gate (DWX #3). Advance cached state ONCE, then
   // evaluate entry on the same closed bar.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

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
