#property strict
#property version   "5.0"
#property description "QM5_1375 heiken-ashi-sma-smoothed-color-flip-h1 — SMA(6)-smoothed Heikin-Ashi color-flip + EMA(200) bias + no-wick confirm (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1375 heiken-ashi-sma-smoothed-color-flip-h1
// -----------------------------------------------------------------------------
// Source: forexfactory Trading-Systems "Smoothed Heiken Ashi" / "HA SMA" cluster;
// Dan Valcu "Heikin Ashi: How to Trade Without Candlestick Patterns" (2004).
// Card: artifacts/cards_approved/QM5_1375_heiken-ashi-sma-smoothed-color-flip-h1.md
//       (g0_status APPROVED). BUILD TARGET ea_id = 1375 (card frontmatter carries a
//       stale ea_id of QM5_12159 — flagged as mismatch; build uses 1375).
//
// Mechanics (closed-bar reads at shift 1; SMA-smoothed HA computed in-EA over a
// bounded seed window — perf-allowed bounded closed-bar reads, only run on the
// QM_IsNewBar-gated entry/exit path):
//
//   Step 1 — Pre-smooth OHLC with SMA(pre_smooth) (card SMA(6)). sO/sH/sL/sC per bar.
//   Step 2 — Heikin-Ashi transform on the SMA-smoothed series (recursive from a
//            bounded seed):
//              haClose = (sO + sH + sL + sC) / 4
//              haOpen  = (haOpen_prev + haClose_prev) / 2   (seed = (sO+sC)/2)
//              haHigh  = max(sH, haOpen, haClose)
//              haLow   = min(sL, haOpen, haClose)
//   Color  — haClose > haOpen => +1 (green), haClose < haOpen => -1 (red).
//
//   Trend STATE  : raw-close EMA(macro_ema) side on H1 (bias from the actual
//                  market, not the smoothed view). Long only if close(1) > EMA;
//                  short only if close(1) < EMA. (Macro-bias filter, a STATE.)
//   Trigger EVENT: HA-SMA COLOR FLIP — the ONE discrete event:
//                    Long  : color(2) = red  AND color(1) = green (flip to green)
//                    Short : color(2) = green AND color(1) = red   (flip to red)
//                  We never require two cross EVENTS on one bar (.DWX two-cross
//                  zero-trade trap). The macro-EMA side and the no-wick confirm
//                  below are STATES on the signal bar.
//   Confirm STATE: "no-wick-rejection" canonical HA strength signal, with the
//                  card's 5%-of-range tolerance:
//                    Long  : haOpen(1) - haLow(1)  <= wick_tol * (haHigh(1)-haLow(1))
//                    Short : haHigh(1) - haOpen(1) <= wick_tol * (haHigh(1)-haLow(1))
//   Stop         : BUY  = min(haLow(1), haLow(2))  - sl_atr_buffer * ATR ; SELL mirror.
//   Take profit  : tp_atr_mult * ATR from entry (fixed-ATR target).
//   Manage       : once unrealized >= trail_arm_atr * ATR, trail SL to
//                    BUY  : max(prior_sl, haLow(1)  - trail_atr_buffer * ATR)
//                    SELL : min(prior_sl, haHigh(1) + trail_atr_buffer * ATR)
//   Exit         : (a) HA-SMA color flip AGAINST the position (single event), or
//                  (b) time-stop after max_hold_bars H1 bars.
//   Re-arm       : single-position-per-magic + a cooldown of cooldown_bars H1
//                  bars after the last exit (anti chop-driven re-flip churn).
//   Session      : 06:00-21:00 broker time (DXZ NY-close broker clock).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1375;
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
input int    strategy_pre_smooth_period   = 6;     // OHLC pre-smoothing SMA period (card SMA6; P3 4..10)
input int    strategy_macro_ema_period    = 200;   // H1 macro-bias EMA on raw close (P3 150..300)
input int    strategy_ha_seed_bars        = 120;   // smoothed-HA recursion seed depth (bounded)
input int    strategy_atr_period          = 14;    // ATR period (stop / target / trail)
input double strategy_wick_tol_pct        = 5.0;   // no-wick confirm tolerance: % of HA range (card 5%)
input double strategy_sl_atr_buffer       = 0.5;   // SL = struct low/high -/+ buffer*ATR (card 0.5; P3 0.3..1.0)
input double strategy_tp_atr_mult         = 2.0;   // TP distance = mult*ATR (card 2.0; P3 1.5..3.0)
input double strategy_trail_arm_atr       = 1.0;   // arm trail once unreal >= this*ATR (card 1.0)
input double strategy_trail_atr_buffer    = 0.5;   // trail SL = HA low/high -/+ this*ATR (card 0.5)
input int    strategy_max_hold_bars       = 48;    // time-stop: close after N H1 bars (card 48)
input int    strategy_cooldown_bars       = 6;     // suppress re-entry for N H1 bars after exit (card 6)
input int    strategy_session_start_hour  = 6;     // broker-time session open (inclusive)
input int    strategy_session_end_hour    = 21;    // broker-time session close (exclusive)
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope state: re-entry cooldown anchor (last-exit bar time).
// -----------------------------------------------------------------------------
datetime g_last_exit_bar_time = 0;

// -----------------------------------------------------------------------------
// SMA-smoothed Heikin-Ashi computation.
// -----------------------------------------------------------------------------
// Computes the HA open/close/high/low and the discrete color at a given closed-bar
// shift, plus the prior bar's color, in one recursive pass over a bounded seed
// window. perf-allowed: bounded closed-bar reads on the QM_IsNewBar-gated path
// only — never per-tick history scans.
//
// Returns false if history is not yet available.
// -----------------------------------------------------------------------------
bool ComputeSmoothedHA(const int shift,
                       double &ha_open_here,
                       double &ha_close_here,
                       double &ha_high_here,
                       double &ha_low_here,
                       double &ha_high_prev,
                       double &ha_low_prev,
                       int    &color_here,
                       int    &color_prev)
  {
   const int pre  = (strategy_pre_smooth_period < 1 ? 1 : strategy_pre_smooth_period);
   const int seed = (strategy_ha_seed_bars < 20 ? 20 : strategy_ha_seed_bars);

   // Oldest bar of the HA recursion seed. We need the HA values at `shift` and
   // `shift+1` (for the prior-bar color + prior structure).
   const int oldest = shift + seed;
   if(Bars(_Symbol, _Period) <= oldest + pre + 2)
      return false;

   // Seed the recursion at `oldest`: HA_open = (sO+sC)/2, HA_close = avg(sOHLC).
   double sO = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_OPEN);
   double sH = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_HIGH);
   double sL = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_LOW);
   double sC = QM_SMA(_Symbol, _Period, pre, oldest, PRICE_CLOSE);
   if(sO <= 0.0 || sC <= 0.0)
      return false;

   double prev_ha_open  = (sO + sC) / 2.0;
   double prev_ha_close = (sO + sH + sL + sC) / 4.0;

   // We need the HA candle at shifts: shift, shift+1. Track them as the
   // recursion advances down to those shifts.
   double o_at[2];   // index 0 -> shift, 1 -> shift+1
   double c_at[2];
   double h_at[2];
   double l_at[2];
   bool   have_at[2];
   for(int k = 0; k < 2; ++k)
     {
      o_at[k] = 0.0; c_at[k] = 0.0; h_at[k] = 0.0; l_at[k] = 0.0;
      have_at[k] = false;
     }

   // Recurse forward from oldest-1 down to `shift`.
   for(int s = oldest - 1; s >= shift; --s)
     {
      sO = QM_SMA(_Symbol, _Period, pre, s, PRICE_OPEN);
      sH = QM_SMA(_Symbol, _Period, pre, s, PRICE_HIGH);
      sL = QM_SMA(_Symbol, _Period, pre, s, PRICE_LOW);
      sC = QM_SMA(_Symbol, _Period, pre, s, PRICE_CLOSE);
      if(sO <= 0.0 || sC <= 0.0)
         return false;

      const double cur_ha_close = (sO + sH + sL + sC) / 4.0;
      const double cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;
      const double cur_ha_high  = MathMax(sH, MathMax(cur_ha_open, cur_ha_close));
      const double cur_ha_low   = MathMin(sL, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;

      const int rel = s - shift; // 0 for `shift`, 1 for `shift+1`
      if(rel >= 0 && rel <= 1)
        {
         o_at[rel] = cur_ha_open;
         c_at[rel] = cur_ha_close;
         h_at[rel] = cur_ha_high;
         l_at[rel] = cur_ha_low;
         have_at[rel] = true;
        }
     }

   if(!have_at[0] || !have_at[1])
      return false;

   ha_open_here  = o_at[0];
   ha_close_here = c_at[0];
   ha_high_here  = h_at[0];
   ha_low_here   = l_at[0];
   ha_high_prev  = h_at[1];
   ha_low_prev   = l_at[1];

   color_here = (c_at[0] > o_at[0]) ? +1 : -1;   // color at `shift`
   color_prev = (c_at[1] > o_at[1]) ? +1 : -1;   // color at `shift+1`
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: broker-time session window + spread guard. The
// SMA-HA / EMA work is on the closed-bar path. Fail-open on .DWX zero modeled
// spread.
bool Strategy_NoTradeFilter()
  {
   // --- Session window (broker time, 06:00-21:00 inclusive/exclusive). ---
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int h = dt.hour;
   if(strategy_session_start_hour <= strategy_session_end_hour)
     {
      if(h < strategy_session_start_hour || h >= strategy_session_end_hour)
         return true;
     }
   else
     {
      // wrap-around (not used by default, defensive)
      if(h < strategy_session_start_hour && h >= strategy_session_end_hour)
         return true;
     }

   // --- Spread guard (fail-open on zero modeled .DWX spread). ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_buffer * atr_value;
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
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Re-entry cooldown: suppress for cooldown_bars H1 bars after the last exit.
   if(g_last_exit_bar_time > 0 && strategy_cooldown_bars > 0)
     {
      const int sec_per_bar = PeriodSeconds(_Period);
      const datetime bar_now = iTime(_Symbol, _Period, 0); // perf-allowed: single bar-time read
      if(bar_now > 0 &&
         (bar_now - g_last_exit_bar_time) < (datetime)(strategy_cooldown_bars * sec_per_bar))
         return false;
     }

   // --- SMA-HA at shift 1 (last closed bar): candle + this/prior color + prior structure. ---
   double ha_open, ha_close, ha_high, ha_low, ha_high_p, ha_low_p;
   int    color_1, color_2;   // color at shift 1, color at shift 2
   if(!ComputeSmoothedHA(1, ha_open, ha_close, ha_high, ha_low, ha_high_p, ha_low_p, color_1, color_2))
      return false;

   // --- Macro-bias STATE: raw-close H1 EMA side vs last closed bar close. ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(ema <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Trigger EVENT: HA-SMA color flip on the last closed bar (single event). ---
   const bool flip_up   = (color_2 == -1 && color_1 == +1);
   const bool flip_down = (color_2 == +1 && color_1 == -1);

   // --- No-wick-rejection confirm STATE (card 5%-of-range tolerance). ---
   const double ha_range = ha_high - ha_low;
   if(ha_range <= 0.0)
      return false;
   const double wick_tol = (strategy_wick_tol_pct / 100.0) * ha_range;
   const bool   no_lower_wick = ((ha_open - ha_low)  <= wick_tol); // bullish strength
   const bool   no_upper_wick = ((ha_high - ha_open) <= wick_tol); // bearish strength

   if(flip_up && close1 > ema && no_lower_wick)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL just below the recent HA-SMA structure low minus an ATR buffer.
      double sl = MathMin(ha_low, ha_low_p) - strategy_sl_atr_buffer * atr_value;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "hasma_flip_long";
      return true;
     }

   if(flip_down && close1 < ema && no_upper_wick)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      // SL just above the recent HA-SMA structure high plus an ATR buffer.
      double sl = MathMax(ha_high, ha_high_p) + strategy_sl_atr_buffer * atr_value;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "hasma_flip_short";
      return true;
     }

   return false;
  }

// Active management: once unrealized profit >= trail_arm_atr * ATR, trail the SL
// to the HA-SMA structure (HA low/high of the last closed bar) -/+ a buffer*ATR.
// Monotone (only tightens). Reads cached closed-bar HA on each call; O(small).
void Strategy_ManageOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return;

   double ha_open, ha_close, ha_high, ha_low, ha_high_p, ha_low_p;
   int    color_1, color_2;
   if(!ComputeSmoothedHA(1, ha_open, ha_close, ha_high, ha_low, ha_high_p, ha_low_p, color_1, color_2))
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long   ptype = PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid <= 0.0)
            continue;
         // Arm only once in profit by trail_arm_atr * ATR.
         if((bid - open_price) < strategy_trail_arm_atr * atr_value)
            continue;
         double new_sl = ha_low - strategy_trail_atr_buffer * atr_value;
         new_sl = QM_StopRulesNormalizePrice(_Symbol, new_sl);
         // Only tighten, and never above current price.
         if(new_sl > cur_sl && new_sl < bid)
            QM_TM_MoveSL(ticket, new_sl, "hasma_trail_long");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(ask <= 0.0)
            continue;
         if((open_price - ask) < strategy_trail_arm_atr * atr_value)
            continue;
         double new_sl = ha_high + strategy_trail_atr_buffer * atr_value;
         new_sl = QM_StopRulesNormalizePrice(_Symbol, new_sl);
         // Only tighten (move down), and never below current price.
         if((cur_sl <= 0.0 || new_sl < cur_sl) && new_sl > ask)
            QM_TM_MoveSL(ticket, new_sl, "hasma_trail_short");
        }
     }
  }

// Discretionary exit: (a) HA-SMA color flip AGAINST the open position (single
// event), or (b) time-stop after max_hold_bars H1 bars.
//   BUY  closes on flip to red   (color(2) = +1 AND color(1) = -1).
//   SELL closes on flip to green (color(2) = -1 AND color(1) = +1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double ha_open, ha_close, ha_high, ha_low, ha_high_p, ha_low_p;
   int    color_1, color_2;
   if(!ComputeSmoothedHA(1, ha_open, ha_close, ha_high, ha_low, ha_high_p, ha_low_p, color_1, color_2))
      return false;

   const bool flip_to_red   = (color_2 == +1 && color_1 == -1);
   const bool flip_to_green = (color_2 == -1 && color_1 == +1);

   const datetime now = TimeCurrent();
   const int sec_per_bar = PeriodSeconds(_Period);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long ptype = PositionGetInteger(POSITION_TYPE);

      // (a) color-flip-against exit.
      if(ptype == POSITION_TYPE_BUY && flip_to_red)
         return true;
      if(ptype == POSITION_TYPE_SELL && flip_to_green)
         return true;

      // (b) time-stop after max_hold_bars H1 bars.
      if(strategy_max_hold_bars > 0 && sec_per_bar > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0 && (now - opened) >= (datetime)(strategy_max_hold_bars * sec_per_bar))
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

   g_last_exit_bar_time = 0;
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
         // Anchor the re-entry cooldown at the bar on which we exited.
         g_last_exit_bar_time = iTime(_Symbol, _Period, 0);
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
