#property strict
#property version   "5.0"
#property description "QM5_11277 blade-m5-ema-zone-scalp — Blade M5 EMA-Zone Trend Scalp"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11277 blade-m5-ema-zone-scalp
// -----------------------------------------------------------------------------
// Source: "The Blade Forex Strategies" (ForexSuccessSecrets.com), M5 Scalping
// System, pp.11-25. Card: artifacts/cards_approved/QM5_11277_blade-m5-ema-zone-scalp.md
// (g0_status APPROVED, source_id e78a9f1f-4e6a-563c-a080-915133d6ed28).
//
// Mechanics (M5, closed-bar reads at shift 1; long + short symmetric):
//   Trend STATE  : EMA(10/21/50) stacked in trend direction AND EMA(50) sloping.
//                  Long  -> ema10 > ema21 > ema50  AND  ema50[1] > ema50[slope_bars].
//                  Short -> ema10 < ema21 < ema50  AND  ema50[1] < ema50[slope_bars].
//   Zone STATE   : the band between EMA(10) and EMA(21). Long midpoint touch =
//                  close at/below the zone midpoint and still >= EMA(21).
//   Entry EVENT  : the closed bar FRESHLY retraces into the zone — the prior
//                  closed bar was OUTSIDE the zone on the trend side (long: prior
//                  close above the zone top), this bar's close is inside the zone
//                  at/below midpoint. One event per retrace, not a per-bar state.
//   Session STATE: London or New York only, in BROKER time converted to UTC,
//                  with a 30-min buffer off each session open/close (card rule).
//   Stop         : structural — 5 pips beyond EMA(21) on the opposite side
//                  (".DWX models 0 spread"; the card's "+ spread" term is 0 here).
//   Take profit  : +tp_pips (default 10). Weak-trend reduction handled by tuning,
//                  not by adaptive logic.
//   Break-even   : SL -> entry once price is +be_trigger_pips in profit.
//   Session exit : close an open position when both sessions are inactive
//                  (card: "close position at session end if still open").
//   One position per magic (card: "max 1 trade per session").
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11277;
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
input int    strategy_ema_zone_fast     = 10;     // EMA(10) — fast zone edge
input int    strategy_ema_zone_slow     = 21;     // EMA(21) — slow zone edge / stop anchor
input int    strategy_ema_trend         = 50;     // EMA(50) — trend / slope filter
input int    strategy_slope_lookback    = 5;      // EMA(50) slope proxy: compare shift 1 vs this
input int    strategy_sl_pips           = 5;      // stop placed this many pips beyond EMA(21)
input int    strategy_tp_pips           = 10;     // take profit, fixed pips
input int    strategy_be_trigger_pips   = 5;      // move SL to break-even at +this many pips
// Session windows in UTC (the card's London/NY windows are stated in GMT=UTC).
input int    strategy_london_start_utc  = 8;      // London session open hour (UTC)
input int    strategy_london_end_utc    = 17;     // London session close hour (UTC)
input int    strategy_ny_start_utc      = 13;     // New York session open hour (UTC)
input int    strategy_ny_end_utc        = 22;     // New York session close hour (UTC)
input int    strategy_session_buffer_min = 30;    // no entries within this many min of open/close
input double strategy_spread_pct_of_stop = 50.0;  // skip only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers (EA-local, pure)
// -----------------------------------------------------------------------------

// True if `utc` lies within [start_hour, end_hour) shrunk by buffer_min at both
// ends. Hours are whole UTC hours; the buffer trims the first/last buffer_min.
bool BladeInBufferedWindow(const datetime utc,
                           const int start_hour,
                           const int end_hour,
                           const int buffer_min)
  {
   const datetime day0 = utc - (utc % 86400);            // UTC midnight of this day
   const datetime open_t  = day0 + start_hour * 3600;
   const datetime close_t = day0 + end_hour   * 3600;
   const datetime buf     = buffer_min * 60;
   const datetime lo = open_t + buf;
   const datetime hi = close_t - buf;
   if(hi <= lo)
      return false;
   return (utc >= lo && utc < hi);
  }

// True if the broker timestamp is inside an active (buffered) London or NY window.
bool BladeSessionActive(const datetime broker_now)
  {
   const datetime utc = QM_BrokerToUTC(broker_now);
   if(BladeInBufferedWindow(utc, strategy_london_start_utc, strategy_london_end_utc,
                            strategy_session_buffer_min))
      return true;
   if(BladeInBufferedWindow(utc, strategy_ny_start_utc, strategy_ny_end_utc,
                            strategy_session_buffer_min))
      return true;
   return false;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window + fail-open spread guard.
bool Strategy_NoTradeFilter()
  {
   // Session filter (broker time -> UTC). Outside London/NY buffered windows: block.
   if(!BladeSessionActive(TimeCurrent()))
      return true;

   // Fail-open spread guard. .DWX models 0 spread; only a genuinely wide spread
   // blocks. Reference distance = the fixed pip stop distance.
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic (card: max 1 trade per session).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar EMA reads (shift 1 = last closed bar) ---
   const double ema10_1 = QM_EMA(_Symbol, _Period, strategy_ema_zone_fast, 1);
   const double ema21_1 = QM_EMA(_Symbol, _Period, strategy_ema_zone_slow, 1);
   const double ema50_1 = QM_EMA(_Symbol, _Period, strategy_ema_trend,     1);
   if(ema10_1 <= 0.0 || ema21_1 <= 0.0 || ema50_1 <= 0.0)
      return false;

   // EMA(50) slope proxy: shift 1 versus shift slope_lookback (card "visibly sloping").
   const double ema50_back = QM_EMA(_Symbol, _Period, strategy_ema_trend,
                                    strategy_slope_lookback + 1);
   if(ema50_back <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // Zone edges and midpoint (shift 1).
   const double zone_hi  = MathMax(ema10_1, ema21_1);
   const double zone_lo  = MathMin(ema10_1, ema21_1);
   const double zone_mid = (ema10_1 + ema21_1) / 2.0;

   // ---------------- LONG ----------------
   // Trend STATE: bullish EMA stack + EMA(50) rising.
   const bool long_stack = (ema10_1 > ema21_1 && ema21_1 > ema50_1);
   const bool long_slope = (ema50_1 > ema50_back);
   if(long_stack && long_slope)
     {
      // Zone STATE: close inside the zone, at/below midpoint, not through EMA(21).
      const bool in_zone_now = (close1 <= zone_mid && close1 >= zone_lo);
      // Entry EVENT: fresh retrace — prior closed bar was ABOVE the zone top.
      const bool fresh_retrace = (close2 > zone_hi);
      if(in_zone_now && fresh_retrace)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         // Stop: sl_pips beyond EMA(21) (below for longs). "+ spread" = 0 on .DWX.
         const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
         const double sl = QM_StopRulesNormalizePrice(_Symbol, ema21_1 - sl_dist);
         const double tp = QM_TakeFixedPips(_Symbol, QM_BUY, entry, strategy_tp_pips);
         if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "blade_zone_long";
         return true;
        }
     }

   // ---------------- SHORT ----------------
   const bool short_stack = (ema10_1 < ema21_1 && ema21_1 < ema50_1);
   const bool short_slope = (ema50_1 < ema50_back);
   if(short_stack && short_slope)
     {
      // Zone STATE: close inside the zone, at/above midpoint, not through EMA(21).
      const bool in_zone_now = (close1 >= zone_mid && close1 <= zone_hi);
      // Entry EVENT: fresh retrace — prior closed bar was BELOW the zone bottom.
      const bool fresh_retrace = (close2 < zone_lo);
      if(in_zone_now && fresh_retrace)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
         const double sl = QM_StopRulesNormalizePrice(_Symbol, ema21_1 + sl_dist);
         const double tp = QM_TakeFixedPips(_Symbol, QM_SELL, entry, strategy_tp_pips);
         if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "blade_zone_short";
         return true;
        }
     }

   return false;
  }

// Break-even management: move SL to entry once +be_trigger_pips in profit.
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
      QM_TM_MoveToBreakEven(ticket, strategy_be_trigger_pips, 0);
     }
  }

// Session-end exit: close any open position once both sessions are inactive.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;
   return !BladeSessionActive(TimeCurrent());
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
