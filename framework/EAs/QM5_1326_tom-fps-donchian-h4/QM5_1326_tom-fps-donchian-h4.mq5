#property strict
#property version   "5.0"
#property description "QM5_1326 tom-fps-donchian-h4 — Tom Yeoman FPS Donchian-break + EMA-stack (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1326 tom-fps-donchian-h4
// -----------------------------------------------------------------------------
// Source: Tom Yeoman "Forex Profit System" master-thread (ForexFactory thread/12503),
//   Donchian-channel-breakout + EMA-50/200-stack-bias variant (H4).
// Card: artifacts/cards_approved/QM5_1326_tom-fps-donchian-h4.md (g0_status APPROVED).
//
// Mechanics (H4, closed-bar reads; shift 1 = last closed bar, shift 2 = the bar
// before it). The close-confirmed Donchian-band break is the single trigger
// EVENT; the EMA stack, macro-bias, channel-width and re-arm are STATES evaluated
// on the same closed bar.
//
//   Donchian channel over the N bars PRIOR to the candidate-break bar:
//     For the BUY/SELL break test on the last closed bar (shift 1):
//       DC_upper = max(high[2 .. N+1])   (N bars before the break bar)
//       DC_lower = min(low [2 .. N+1])
//     For the "was inside just before" test (shift 2):
//       DC_upper_prev = max(high[3 .. N+2])
//       DC_lower_prev = min(low [3 .. N+2])
//     DC_mid (current bands, used by the trail exit) = (DC_upper + DC_lower)/2.
//
//   Entry — BUY (EVENT = close-confirmed upper break):
//     EVENT  break    : close[1] >  DC_upper       AND  close[2] <= DC_upper_prev
//     STATE  macro    : close[1] >  EMA(200)[1]                     (FPS signature)
//     STATE  slope    : EMA(50)[1] > EMA(200)[1]                    (Tom's stack)
//     STATE  width    : (DC_upper - DC_lower) > width_atr_mult * ATR(14)
//     STATE  flat     : no open position (1-pos-per-magic, HR14)
//     STATE  re-arm   : >= rearm_inside_bars consecutive inside-channel closed
//                       bars have elapsed since the last position close.
//   Entry — SELL: mirror (close[1] < DC_lower & close[2] >= DC_lower_prev;
//                 close[1] < EMA200; EMA50 < EMA200; width gate; re-arm).
//
//   Stop (static at entry):
//     BUY  : DC_lower - stop_atr_buf * ATR, distance capped at stop_cap_atr * ATR
//     SELL : DC_upper + stop_atr_buf * ATR, distance capped at stop_cap_atr * ATR
//   No fixed TP — trend-follow; the three exits below let winners run.
//
//   Exit (Strategy_ExitSignal), whichever first:
//     - Opposite Donchian break  : BUY close[1] < DC_lower ; SELL mirror.
//     - Donchian-mid trail        : BUY close[1] < DC_mid AFTER the position is
//       >= trail_arm_atr * ATR in profit (anti-give-back). SELL mirror.
//     - EMA-200 macro-bias flip   : BUY close crosses below EMA200 on the closed
//       bar (close[2] >= EMA200[2] & close[1] < EMA200[1]). SELL mirror.
//
//   Spread : skip only a genuinely wide spread (fail-open on .DWX zero spread).
//   News   : central two-axis framework filter (Friday-close + news handled in
//            OnTick wiring). No intraday session gate — H4 macro EMAs gate drift.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1326;
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
input int    strategy_dc_period          = 20;    // Donchian channel period N (P3 sweep 14..30)
input int    strategy_ema_macro_period   = 200;   // macro-bias EMA (FPS signature)
input int    strategy_ema_slope_period   = 50;    // intermediate-trend EMA (stack gate)
input int    strategy_atr_period         = 14;    // ATR period (width gate + SL + trail-arm)
input double strategy_width_atr_mult     = 1.5;   // channel-width gate: (upper-lower) > mult*ATR
input double strategy_stop_atr_buf       = 0.5;   // SL = opposite band -/+ buf*ATR
input double strategy_stop_cap_atr       = 4.0;   // cap on initial-SL distance in ATR units
input double strategy_trail_arm_atr      = 1.5;   // DC-mid trail arms after >= mult*ATR profit
input int    strategy_rearm_inside_bars  = 3;     // inside-channel bars required after a close
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop-buffer distance

// -----------------------------------------------------------------------------
// File-scope re-arm state (advanced once per closed bar inside Strategy_EntrySignal,
// which the framework calls only on a new closed bar). Tom's anti-stack rule:
// after any exit, require N consecutive inside-channel closed bars before re-entry.
// -----------------------------------------------------------------------------
bool     g_had_position    = false;  // was a position open at the previous new-bar evaluation?
bool     g_rearm_pending   = false;  // a close happened; waiting for inside-bar streak
int      g_inside_streak   = 0;      // consecutive inside-channel closed bars observed
datetime g_last_eval_bar   = 0;      // last bar-open time the re-arm state was advanced for

// -----------------------------------------------------------------------------
// Donchian helpers — bounded loop of N bars (N<=30), closed-bar reads only.
// `first_shift` is the oldest-newest start: bands span [first_shift .. first_shift+N-1].
// iHigh/iLow are perf-allowed bespoke structural reads (no QM_Donchian helper exists).
// -----------------------------------------------------------------------------
double DonchianUpper(const int first_shift, const int n)
  {
   double hi = -DBL_MAX;
   for(int i = first_shift; i < first_shift + n; ++i)
     {
      const double h = iHigh(_Symbol, _Period, i); // perf-allowed
      if(h > hi) hi = h;
     }
   return hi;
  }

double DonchianLower(const int first_shift, const int n)
  {
   double lo = DBL_MAX;
   for(int i = first_shift; i < first_shift + n; ++i)
     {
      const double l = iLow(_Symbol, _Period, i); // perf-allowed
      if(l < lo) lo = l;
     }
   return lo;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: wide-spread guard only (no intraday session on H4).
// Returns TRUE to BLOCK. Fail-open on .DWX zero/negative modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote — defer, do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_stop_atr_buf * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true; // genuinely wide spread

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). The
// close-confirmed Donchian break is the single trigger EVENT.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const int magic = QM_FrameworkMagic();
   const bool has_pos = (QM_TM_OpenPositionCount(magic) > 0);

   // --- Donchian bands (closed-bar). N bars before the candidate-break bar. ---
   const int n = strategy_dc_period;
   const double dc_upper      = DonchianUpper(2, n);          // bands for break bar (shift 1)
   const double dc_lower      = DonchianLower(2, n);
   const double dc_upper_prev = DonchianUpper(3, n);          // bands one bar earlier (shift 2)
   const double dc_lower_prev = DonchianLower(3, n);
   if(dc_upper <= 0.0 || dc_lower <= 0.0 || dc_upper_prev <= 0.0 || dc_lower_prev <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed (break bar close)
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed (prior close)
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   // --- Advance re-arm state once per closed bar (this fn runs on new bars only). ---
   const datetime bar_open = (datetime)iTime(_Symbol, _Period, 0); // perf-allowed: bar-open key
   if(bar_open != g_last_eval_bar)
     {
      g_last_eval_bar = bar_open;
      // Detect a close transition: had a position last eval, now flat.
      if(g_had_position && !has_pos)
        {
         g_rearm_pending = true;
         g_inside_streak = 0;
        }
      // Count the last closed bar (shift 1) as inside/outside the channel it broke.
      const bool inside = (close1 < dc_upper && close1 > dc_lower);
      if(inside) g_inside_streak++;
      else       g_inside_streak = 0;
      if(g_rearm_pending && g_inside_streak >= strategy_rearm_inside_bars)
         g_rearm_pending = false;
      g_had_position = has_pos;
     }

   // One open position per symbol/magic.
   if(has_pos)
      return false;
   // Re-arm gate: block new entries until the inside-bar streak is satisfied.
   if(g_rearm_pending)
      return false;

   // --- EMA stack + ATR (closed bar). ---
   const double ema_macro = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
   const double ema_slope = QM_EMA(_Symbol, _Period, strategy_ema_slope_period, 1);
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(ema_macro <= 0.0 || ema_slope <= 0.0 || atr_value <= 0.0)
      return false;

   const double width      = dc_upper - dc_lower;
   const bool   width_ok   = (width > strategy_width_atr_mult * atr_value);
   if(!width_ok)
      return false;

   // ---------------------------- BUY ----------------------------
   const bool break_up   = (close1 > dc_upper && close2 <= dc_upper_prev); // EVENT
   const bool macro_bull = (close1 > ema_macro);
   const bool slope_bull = (ema_slope > ema_macro);

   if(break_up && macro_bull && slope_bull)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL = opposite (lower) band minus an ATR cushion, distance-capped.
      double sl = dc_lower - strategy_stop_atr_buf * atr_value;
      const double cap_dist = strategy_stop_cap_atr * atr_value;
      if(entry - sl > cap_dist)
         sl = entry - cap_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — trend-follow
      req.reason = "fps_donchian_long";
      return true;
     }

   // ---------------------------- SELL ---------------------------
   const bool break_dn   = (close1 < dc_lower && close2 >= dc_lower_prev); // EVENT
   const bool macro_bear = (close1 < ema_macro);
   const bool slope_bear = (ema_slope < ema_macro);

   if(break_dn && macro_bear && slope_bear)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      double sl = dc_upper + strategy_stop_atr_buf * atr_value;
      const double cap_dist = strategy_stop_cap_atr * atr_value;
      if(sl - entry > cap_dist)
         sl = entry + cap_dist;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      if(sl <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "fps_donchian_short";
      return true;
     }

   return false;
  }

// Static SL handles the protective side; in-position management is via the three
// closed-bar exits in Strategy_ExitSignal. No active SL/TP modification.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exits (whichever fires first), evaluated on the closed bar:
//   - opposite Donchian break (full channel-flip)
//   - Donchian-mid trail, armed only after >= trail_arm_atr * ATR of open profit
//   - EMA-200 macro-bias flip
// Direction + open-profit taken from the live open position for this EA's magic.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine open direction + current open profit (price distance from entry).
   bool   is_long  = false;
   bool   is_short = false;
   double open_price = 0.0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
      open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      break;
     }
   if(!is_long && !is_short)
      return false;

   const int n = strategy_dc_period;
   const double dc_upper = DonchianUpper(2, n);
   const double dc_lower = DonchianLower(2, n);
   if(dc_upper <= 0.0 || dc_lower <= 0.0)
      return false;
   const double dc_mid = 0.5 * (dc_upper + dc_lower);

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed
   const double ema_macro_now  = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 1);
   const double ema_macro_prev = QM_EMA(_Symbol, _Period, strategy_ema_macro_period, 2);
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(close1 <= 0.0 || close2 <= 0.0 || ema_macro_now <= 0.0 || ema_macro_prev <= 0.0 || atr_value <= 0.0)
      return false;

   const double trail_arm_dist = strategy_trail_arm_atr * atr_value;

   if(is_long)
     {
      const bool flip_exit  = (close1 < dc_lower);                                   // opposite break
      const bool armed      = (open_price > 0.0 && (close1 - open_price) >= trail_arm_dist);
      const bool mid_trail  = (armed && close1 < dc_mid);                            // give-back trail
      const bool bias_flip  = (close2 >= ema_macro_prev && close1 < ema_macro_now);  // EMA200 flip-down
      return (flip_exit || mid_trail || bias_flip);
     }

   // is_short
   const bool flip_exit  = (close1 > dc_upper);                                   // opposite break
   const bool armed      = (open_price > 0.0 && (open_price - close1) >= trail_arm_dist);
   const bool mid_trail  = (armed && close1 > dc_mid);                            // give-back trail
   const bool bias_flip  = (close2 <= ema_macro_prev && close1 > ema_macro_now);  // EMA200 flip-up
   return (flip_exit || mid_trail || bias_flip);
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
