#property strict
#property version   "5.0"
#property description "QM5_11345 continuation-method-ema50-sma5-wpr — MTF EMA50 trend + WPR pullback-resume + SMA5 trail (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11345 continuation-method-ema50-sma5-wpr
// -----------------------------------------------------------------------------
// Source: "Secret to Winning Forex — The Continuation Method" (anonymous ebook),
//         pages 11-22. Card: artifacts/cards_approved/
//         QM5_11345_continuation-method-ema50-sma5-wpr.md (g0_status APPROVED).
//
// Mechanics (MTF trend continuation; closed-bar reads at shift 1):
//   Higher-TF trend STATE : EMA(50) on higher TF (default W1) sloping. Up if
//                           EMA50[1] > EMA50[1+slope_bars]; down if <. Skip when
//                           |slope| < flat-floor (in price distance) — "flat".
//   Pullback STATE        : on entry TF, price recently CLOSED through EMA(50)
//                           against the impulse — at least one of the last
//                           pullback_bars closed below EMA50 (long) / above (short).
//   Trigger EVENT (single): WPR(14) crosses back from the exhaustion zone:
//                           LONG  -> WPR was <= -80, now > -80 (oversold recovery).
//                           SHORT -> WPR was >= -20, now < -20 (overbought roll).
//   Entry                 : market at the close of the signal bar (single-entry
//                           framework path; the "BuyStop above the bar" of the
//                           book is approximated by the resume cross + market).
//   Stop                  : structural swing low/high (StopStructure) over
//                           swing_lookback, clamped to [sl_min_pips, sl_max_pips].
//                           Skip if structural distance > sl_max_pips.
//   Take profit           : 2:1 R:R off the (clamped) stop distance.
//   Trail exit            : close on `exit_consec` consecutive closes on the wrong
//                           side of SMA(5) (below for long, above for short).
//   Spread guard          : fail-OPEN on .DWX zero modeled spread; block only a
//                           genuinely wide spread > spread_pct_of_stop of stop dist.
//
// .DWX invariants honoured: fail-open spread, no swap gate, single QM_IsNewBar
// consume, ONE event (WPR cross) + states, broker-time-agnostic (no session),
// pip-scaled SL bounds via QM_StopRulesPipsToPriceDistance, no external feed.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11345;
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
input int    strategy_htf               = PERIOD_W1; // higher-TF trend filter (W1 for a D1 entry chart)
input int    strategy_ema_period        = 50;        // EMA period (trend + pullback reference)
input int    strategy_slope_bars        = 10;        // EMA50[1] vs EMA50[1+slope_bars] for the slope
input double strategy_flat_floor_pips    = 10.0;     // skip when |EMA50 slope| < this (flat HTF)
input int    strategy_wpr_period        = 14;        // Williams %R period
input double strategy_wpr_os_level       = -80.0;    // oversold exhaustion (long arm)
input double strategy_wpr_ob_level       = -20.0;    // overbought exhaustion (short arm)
input int    strategy_pullback_bars     = 5;         // bars to look back for a pullback close through EMA50
input int    strategy_swing_lookback    = 10;        // bars for the structural swing SL
input int    strategy_sl_min_pips       = 20;        // SL clamp lower bound (pips)
input int    strategy_sl_max_pips       = 100;       // SL clamp upper bound; skip if structure wider (pips)
input double strategy_tp_rr             = 2.0;       // take-profit R:R off the stop distance
input int    strategy_sma_trail_period  = 5;         // SMA period for the trailing exit
input int    strategy_exit_consec       = 2;         // consecutive wrong-side closes to exit
input double strategy_spread_pct_of_stop = 15.0;     // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work runs on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Reference stop distance = the SL clamp lower bound, scaled to price.
   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Build a long/short entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const ENUM_TIMEFRAMES htf = (ENUM_TIMEFRAMES)strategy_htf;

   // --- Higher-TF trend STATE: EMA(50) slope (closed bars on the HTF) ---
   const double htf_ema_now  = QM_EMA(_Symbol, htf, strategy_ema_period, 1);
   const double htf_ema_back = QM_EMA(_Symbol, htf, strategy_ema_period, 1 + strategy_slope_bars);
   if(htf_ema_now <= 0.0 || htf_ema_back <= 0.0)
      return false;

   const double slope = htf_ema_now - htf_ema_back;
   const double flat_floor = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_flat_floor_pips);
   if(MathAbs(slope) < flat_floor)
      return false; // flat HTF — no continuation trade

   const bool trend_up   = (slope > 0.0);
   const bool trend_down = (slope < 0.0);

   // --- Entry-TF EMA(50) for the pullback reference (closed bar) ---
   const double ema_etf = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema_etf <= 0.0)
      return false;

   // --- Pullback STATE: at least one of the last pullback_bars closed on the
   //     counter-trend side of the entry-TF EMA50 (price pulled back). ---
   bool pulled_back = false;
   for(int s = 1; s <= strategy_pullback_bars; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(c <= 0.0)
         continue;
      const double ema_s = QM_EMA(_Symbol, _Period, strategy_ema_period, s);
      if(ema_s <= 0.0)
         continue;
      if(trend_up && c < ema_s)   { pulled_back = true; break; }
      if(trend_down && c > ema_s) { pulled_back = true; break; }
     }
   if(!pulled_back)
      return false;

   // --- Trigger EVENT (single): WPR crosses back out of the exhaustion zone ---
   const double wpr_now  = QM_WPR(_Symbol, _Period, strategy_wpr_period, 1);
   const double wpr_prev = QM_WPR(_Symbol, _Period, strategy_wpr_period, 2);
   // WPR is in [-100, 0]; readers return that range. Guard against the rare 0.0
   // "no data" only by requiring a real cross (prev/now straddle the level).

   bool go_long  = false;
   bool go_short = false;
   if(trend_up)
      go_long = (wpr_prev <= strategy_wpr_os_level && wpr_now > strategy_wpr_os_level);
   else if(trend_down)
      go_short = (wpr_prev >= strategy_wpr_ob_level && wpr_now < strategy_wpr_ob_level);

   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;

   // --- Entry price (market) ---
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // --- Structural stop, clamped to [sl_min_pips, sl_max_pips] ---
   double sl = QM_StopStructure(_Symbol, side, entry, strategy_swing_lookback);
   if(sl <= 0.0)
      return false;

   double stop_dist = MathAbs(entry - sl);
   const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_pips);
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_max_pips);
   if(stop_dist > max_dist)
      return false; // swing too far — skip per card "skip if > 100 pips"
   if(stop_dist < min_dist)
     {
      // Widen to the minimum stop distance from entry.
      stop_dist = min_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol,
              go_long ? entry - stop_dist : entry + stop_dist);
     }

   // --- Take profit: 2:1 R:R off the (clamped) stop ---
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "continuation_wpr_long" : "continuation_wpr_short";
   return true;
  }

// Fixed structural stop + RR target; the SMA5 trail exit is in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Trail exit: `exit_consec` consecutive closes on the wrong side of SMA(5).
// LONG closes below SMA5; SHORT closes above SMA5. Closed-bar reads at shift 1..N.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine open-position direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      is_long  = (ptype == POSITION_TYPE_BUY);
      is_short = (ptype == POSITION_TYPE_SELL);
      break;
     }
   if(!is_long && !is_short)
      return false;

   // Require `exit_consec` consecutive wrong-side closes (shifts 1..exit_consec).
   for(int s = 1; s <= strategy_exit_consec; ++s)
     {
      const double c   = iClose(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      const double sma = QM_SMA(_Symbol, _Period, strategy_sma_trail_period, s);
      if(c <= 0.0 || sma <= 0.0)
         return false; // incomplete data — do not force an exit
      if(is_long && c >= sma)
         return false; // a close back above SMA5 resets the count
      if(is_short && c <= sma)
         return false;
     }
   return true; // all of the last exit_consec closes were on the wrong side
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
