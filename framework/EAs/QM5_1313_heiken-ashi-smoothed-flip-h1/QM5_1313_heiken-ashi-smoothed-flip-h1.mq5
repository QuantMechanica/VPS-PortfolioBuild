#property strict
#property version   "5.0"
#property description "QM5_1313 heiken-ashi-smoothed-flip-h1 — Smoothed Heikin-Ashi color-flip + EMA(200) trend (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1313 heiken-ashi-smoothed-flip-h1
// -----------------------------------------------------------------------------
// Source: forexfactory Trading-Systems "Heiken Ashi Smoothed" cluster; Dan Valcu
// "Heiken Ashi: How to Trade Without Candlestick Patterns" (S&C Feb 2004).
// Card: artifacts/cards_approved/QM5_1313_heiken-ashi-smoothed-flip-h1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; smoothed-HA computed in-EA over a
// bounded seed window — perf-allowed bounded closed-bar reads, only run on the
// QM_IsNewBar-gated entry/exit path):
//
//   Step 1 — Pre-smooth OHLC with EMA(pre_smooth) (card SMA(6); build directive
//            specifies QM_EMA for the pre-smoothing). sO/sH/sL/sC per bar.
//   Step 2 — HA transform on the smoothed series (recursive from a bounded seed):
//              haClose = (sO + sH + sL + sC) / 4
//              haOpen  = (haOpen_prev + haClose_prev) / 2   (seed = (sO+sC)/2)
//   Step 3 — Post-smooth haOpen / haClose with SMA(post_smooth) (card SMA(2)).
//   Color  — smHaClose > smHaOpen => +1 (green), else -1 (red).
//
//   Trend STATE  : EMA(macro_ema) side on H1. Long only if close(1) > EMA;
//                  short only if close(1) < EMA. (Macro bias filter, a STATE.)
//   Trigger EVENT: smoothed-HA COLOR FLIP one bar ago + same-color confirmation
//                  on the last closed bar — a single discrete state transition:
//                    Long  : color(2) = -1  AND  color(1) = +1  (flip to green)
//                  i.e. the flip is the ONE event; the macro-EMA side and the
//                  confirmation are STATES. We never require two cross EVENTS on
//                  one bar (.DWX two-cross-same-bar zero-trade trap).
//   Stop         : BUY  = smHaLow(1)  - sl_atr_buffer * ATR ; SELL mirror on high.
//   Take profit  : tp_atr_mult * ATR from entry (RR-free fixed-ATR target).
//   Exit         : smoothed-HA color flip AGAINST the position (single event).
//   Re-arm       : single-position-per-magic + flip-against exit naturally
//                  prevents stacked entries during one trend leg.
//   Session      : 06:00-21:00 broker time (DXZ NY-close broker clock).
//   Spread guard : block only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1313;
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
input int    strategy_pre_smooth_period   = 6;     // OHLC pre-smoothing EMA period (card SMA6; P3 4..10)
input int    strategy_post_smooth_period  = 2;     // HA post-smoothing SMA period (card SMA2; P3 1..4)
input int    strategy_macro_ema_period    = 200;   // H1 macro-bias EMA (P3 150..300)
input int    strategy_ha_seed_bars        = 120;   // smoothed-HA recursion seed depth (bounded)
input int    strategy_atr_period          = 14;    // ATR period (stop / target)
input double strategy_sl_atr_buffer       = 1.0;   // SL = smHa low/high -/+ buffer * ATR (P3 0.5..1.5)
input double strategy_tp_atr_mult         = 2.5;   // TP distance = mult * ATR (P3 1.5..4.0)
input int    strategy_session_start_hour  = 6;     // broker-time session open (inclusive)
input int    strategy_session_end_hour    = 21;    // broker-time session close (exclusive)
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Smoothed Heikin-Ashi computation.
// -----------------------------------------------------------------------------
// Computes the post-smoothed HA open/close/high/low and the discrete color at a
// given closed-bar shift, plus the prior bar's color, in one recursive pass over
// a bounded seed window. perf-allowed: bounded closed-bar reads on the
// QM_IsNewBar-gated path only — never per-tick history scans.
//
// Returns false if history is not yet available.
// -----------------------------------------------------------------------------

// EMA pre-smoothing of a single price series at `shift` is provided by QM_EMA.
// For the HA recursion we need the EMA-smoothed OHLC at several shifts; QM_EMA
// reads each (sym, tf, period, shift, price) cheaply via pooled handles.

bool ComputeSmoothedHA(const int shift,
                       double &sm_ha_open,
                       double &sm_ha_close,
                       double &sm_ha_high,
                       double &sm_ha_low,
                       int    &color_here,
                       int    &color_prev)
  {
   const int pre  = (strategy_pre_smooth_period  < 1 ? 1 : strategy_pre_smooth_period);
   const int post = (strategy_post_smooth_period < 1 ? 1 : strategy_post_smooth_period);
   const int seed = (strategy_ha_seed_bars < 20 ? 20 : strategy_ha_seed_bars);

   // Oldest bar of the HA recursion seed. We must be able to post-smooth the HA
   // arrays at `shift` and `shift+1` with an SMA(post), so the recursion has to
   // extend back to shift + (post-1) for the prior-color comparison.
   const int oldest = shift + seed;
   if(Bars(_Symbol, _Period) <= oldest + pre + 2)
      return false;

   // Rolling buffers of raw HA open/close from `oldest` down to `shift-?`.
   // We only need enough recent HA values to post-smooth at shift and shift+1
   // and shift+2 (for color_prev of the prior bar). Keep a small window of the
   // last (post + 2) HA values.
   const int keep = post + 3;
   double ha_open_win[];
   double ha_close_win[];
   ArrayResize(ha_open_win, keep);
   ArrayResize(ha_close_win, keep);
   ArrayInitialize(ha_open_win, 0.0);
   ArrayInitialize(ha_close_win, 0.0);

   // Seed the recursion at `oldest`: HA_open = (sO+sC)/2, HA_close = avg(sOHLC).
   double sO = QM_EMA(_Symbol, _Period, pre, oldest, PRICE_OPEN);
   double sH = QM_EMA(_Symbol, _Period, pre, oldest, PRICE_HIGH);
   double sL = QM_EMA(_Symbol, _Period, pre, oldest, PRICE_LOW);
   double sC = QM_EMA(_Symbol, _Period, pre, oldest, PRICE_CLOSE);
   if(sO <= 0.0 || sC <= 0.0)
      return false;

   double prev_ha_open  = (sO + sC) / 2.0;
   double prev_ha_close = (sO + sH + sL + sC) / 4.0;

   // We need the post-smoothed HA at shifts: shift, shift+1, shift+2.
   // Track them as the recursion advances to those shifts.
   double smo_at[3];   // index 0 -> shift, 1 -> shift+1, 2 -> shift+2
   double smc_at[3];
   double smh_at[3];
   double sml_at[3];
   bool   have_at[3];
   for(int k = 0; k < 3; ++k)
     {
      smo_at[k] = 0.0; smc_at[k] = 0.0; smh_at[k] = 0.0; sml_at[k] = 0.0;
      have_at[k] = false;
     }

   // Recurse forward from oldest-1 down to (shift - 0). We post-smooth the HA
   // open/close over the last `post` raw HA values via a rolling window.
   // Initialize the window's first element with the seed.
   int win_count = 0;
   ha_open_win[win_count % keep]  = prev_ha_open;
   ha_close_win[win_count % keep] = prev_ha_close;
   win_count++;

   for(int s = oldest - 1; s >= shift; --s)
     {
      sO = QM_EMA(_Symbol, _Period, pre, s, PRICE_OPEN);
      sH = QM_EMA(_Symbol, _Period, pre, s, PRICE_HIGH);
      sL = QM_EMA(_Symbol, _Period, pre, s, PRICE_LOW);
      sC = QM_EMA(_Symbol, _Period, pre, s, PRICE_CLOSE);
      if(sO <= 0.0 || sC <= 0.0)
         return false;

      const double cur_ha_close = (sO + sH + sL + sC) / 4.0;
      const double cur_ha_open  = (prev_ha_open + prev_ha_close) / 2.0;
      const double cur_ha_high  = MathMax(sH, MathMax(cur_ha_open, cur_ha_close));
      const double cur_ha_low   = MathMin(sL, MathMin(cur_ha_open, cur_ha_close));

      prev_ha_open  = cur_ha_open;
      prev_ha_close = cur_ha_close;

      ha_open_win[win_count % keep]  = cur_ha_open;
      ha_close_win[win_count % keep] = cur_ha_close;
      win_count++;

      // Once we have at least `post` raw HA values, the post-smoothed value at
      // this bar `s` is the SMA of the last `post` raw HA open/close.
      if(win_count >= post)
        {
         double sum_o = 0.0, sum_c = 0.0;
         for(int j = 0; j < post; ++j)
           {
            const int idx = (win_count - 1 - j) % keep;
            sum_o += ha_open_win[idx];
            sum_c += ha_close_win[idx];
           }
         const double po = sum_o / post;     // post-smoothed HA open at bar s
         const double pc = sum_c / post;     // post-smoothed HA close at bar s

         // Bucket into shift / shift+1 / shift+2 if this bar is one of them.
         const int rel = s - shift; // 0,1,2 for the bars we care about
         if(rel >= 0 && rel <= 2)
           {
            smo_at[rel] = po;
            smc_at[rel] = pc;
            smh_at[rel] = cur_ha_high;
            sml_at[rel] = cur_ha_low;
            have_at[rel] = true;
           }
        }
     }

   if(!have_at[0] || !have_at[1] || !have_at[2])
      return false;

   sm_ha_open  = smo_at[0];
   sm_ha_close = smc_at[0];
   sm_ha_high  = smh_at[0];
   sm_ha_low   = sml_at[0];

   color_here = (smc_at[0] > smo_at[0]) ? +1 : -1;   // color at `shift`
   color_prev = (smc_at[1] > smo_at[1]) ? +1 : -1;   // color at `shift+1`
   return true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: broker-time session window + spread guard. The
// smoothed-HA / EMA work is on the closed-bar path. Fail-open on .DWX zero
// modeled spread.
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

   // --- Smoothed-HA at shift 1 (last closed bar): value + this/prior color. ---
   double sm_open, sm_close, sm_high, sm_low;
   int    color_1, color_2;   // color at shift 1, color at shift 2
   if(!ComputeSmoothedHA(1, sm_open, sm_close, sm_high, sm_low, color_1, color_2))
      return false;

   // --- Macro-bias STATE: H1 EMA side vs last closed bar close. ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_macro_ema_period, 1);
   if(ema <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Trigger EVENT: smoothed-HA color flip one bar ago (single event). ---
   // Long  : flip to green => color(2) = -1 AND color(1) = +1.
   // Short : flip to red   => color(2) = +1 AND color(1) = -1.
   const bool flip_up   = (color_2 == -1 && color_1 == +1);
   const bool flip_down = (color_2 == +1 && color_1 == -1);

   if(flip_up && close1 > ema)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // SL = smoothed-HA low of the signal bar minus an ATR buffer.
      double sl = sm_low - strategy_sl_atr_buffer * atr_value;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smha_flip_long";
      return true;
     }

   if(flip_down && close1 < ema)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      // SL = smoothed-HA high of the signal bar plus an ATR buffer.
      double sl = sm_high + strategy_sl_atr_buffer * atr_value;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0 || sl <= entry)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "smha_flip_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed ATR stop/target. The discretionary
// color-flip-against exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: smoothed-HA color flip AGAINST the open position.
//   BUY  closes when color flips to red   (color(2) = +1 AND color(1) = -1).
//   SELL closes when color flips to green  (color(2) = -1 AND color(1) = +1).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   double sm_open, sm_close, sm_high, sm_low;
   int    color_1, color_2;
   if(!ComputeSmoothedHA(1, sm_open, sm_close, sm_high, sm_low, color_1, color_2))
      return false;

   const bool flip_to_red   = (color_2 == +1 && color_1 == -1);
   const bool flip_to_green = (color_2 == -1 && color_1 == +1);

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && flip_to_red)
         return true;
      if(ptype == POSITION_TYPE_SELL && flip_to_green)
         return true;
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
