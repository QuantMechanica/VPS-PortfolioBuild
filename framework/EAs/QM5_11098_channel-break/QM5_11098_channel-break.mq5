#property strict
#property version   "5.0"
#property description "QM5_11098 channel-break — Linear-Regression Channel Breakout (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11098 channel-break
// -----------------------------------------------------------------------------
// Source: EarnForex "Channel Pattern Detector" (GitHub + article). Card:
//   artifacts/cards_approved/QM5_11098_channel-break.md (g0_status APPROVED).
//
// Mechanisation note: the source is an INDICATOR that draws ascending /
// descending / horizontal channels from pivot line-pairs. The card converts it
// to a deterministic, bounded EA. We replace the discretionary line-object
// search with a fully deterministic least-squares linear-regression channel
// over the LookBack window of PRIOR CLOSED bars (shifts 1..LookBack). This is a
// bounded, closed-bar, non-ML channel:
//
//   Channel fit (per closed bar, cached):
//     - Least-squares line of close vs. bar-index over shifts 1..LookBack.
//     - Residual stddev (sigma) of close about that line.
//     - Mid value at the signal bar (shift 1) = line projection at x=1.
//     - Resistance = mid + dev_mult * sigma ; Support = mid - dev_mult * sigma.
//   Channel-validity gate (deterministic, mirrors the source "Threshold"
//   tightness idea): channel is only valid if its half-width is a meaningful
//   multiple of ATR AND the close stays reasonably contained, i.e.
//     min_halfwidth_atr * ATR <= dev_mult*sigma <= max_halfwidth_atr * ATR.
//   This rejects degenerate (flat-noise) and blown-out (no structure) windows.
//
//   Entry (close-based breakout, one entry per fresh breakout):
//     LONG  : close[1] > Resistance + breakout_atr_mult * ATR  AND
//             close[2] <= Resistance@prev  (the break is a NEW event, not a
//             bar that was already outside) .
//     SHORT : close[1] < Support    - breakout_atr_mult * ATR  AND
//             close[2] >= Support@prev.
//   One open position per symbol/magic (framework single-position model).
//
//   Stop loss: opposite channel line at entry, capped at sl_atr_cap_mult*ATR
//     (card P2 baseline: opposite channel line, capped at 2.5 ATR).
//   Take profit: RR multiple of the realised stop distance.
//
//   Exit (Strategy_ExitSignal, closed-bar): close back INSIDE the channel
//     (long: close[1] < Resistance ; short: close[1] > Support) OR time stop
//     after max_hold_bars closed bars OR opposite-side channel breakout.
//
// .DWX invariants honoured: fail-OPEN spread guard (zero modeled spread never
// blocks), no swap gate, no external feed, prior-CLOSE breakout (gapless CFDs),
// multi-bar channel scaled to a multi-bar ATR baseline, QM_IsNewBar consumed
// once. All channel math is cached per closed bar (no per-tick CopyRates).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11098;
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
input int    strategy_channel_lookback  = 60;    // bars in the regression-channel window (prior closed bars)
input double strategy_dev_mult          = 2.0;   // channel half-width = dev_mult * residual stddev
input int    strategy_atr_period        = 14;    // ATR period (breakout buffer / stop cap)
input double strategy_breakout_atr_mult = 0.10;  // breakout buffer beyond the channel line (card: 0.10*ATR)
input double strategy_min_halfwidth_atr = 0.75;  // channel valid only if half-width >= this * ATR
input double strategy_max_halfwidth_atr = 6.0;   // channel valid only if half-width <= this * ATR
input double strategy_sl_atr_cap_mult   = 2.5;   // stop capped at this * ATR from entry (card P2 cap)
input double strategy_tp_rr             = 2.0;   // take-profit = tp_rr * realised stop distance
input int    strategy_max_hold_bars     = 12;    // time-stop: close after N closed bars (card: 12 H4 bars)
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance (fail-open)

// -----------------------------------------------------------------------------
// File-scope cached channel state — advanced ONCE per closed bar.
// All values describe the channel fitted to shifts 1..LookBack as of the most
// recently closed bar. _prev variants are the same channel projected one bar
// earlier (for fresh-breakout / fresh-exit event detection).
// -----------------------------------------------------------------------------
bool   g_chan_valid       = false;  // channel passed the validity gate this bar
double g_chan_resistance  = 0.0;    // upper line value at the signal bar (shift 1)
double g_chan_support     = 0.0;    // lower line value at the signal bar (shift 1)
double g_chan_resist_prev = 0.0;    // upper line value at shift 2 (previous bar)
double g_chan_support_prev= 0.0;    // lower line value at shift 2 (previous bar)
double g_chan_atr         = 0.0;    // ATR at shift 1, cached for this bar
int    g_bars_in_trade    = 0;      // closed-bar counter for the time stop

// Fit a least-squares line to close over [start_shift .. start_shift+n-1] and
// report the projected line value at a target shift plus the residual stddev.
// x is measured as "bars back from start_shift" so x=0 is the newest bar in the
// window. Deterministic, bounded O(n). Returns false on degenerate input.
bool FitChannel(const int start_shift, const int n,
                const int project_shift,
                double &line_at_project, double &sigma)
  {
   line_at_project = 0.0;
   sigma = 0.0;
   if(n < 5)
      return false;

   double sum_x = 0.0, sum_y = 0.0, sum_xy = 0.0, sum_xx = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const int    shift = start_shift + i;
      const double y     = iClose(_Symbol, _Period, shift); // perf-allowed: cached once per closed bar
      if(y <= 0.0)
         return false;
      const double x = (double)i;
      sum_x  += x;
      sum_y  += y;
      sum_xy += x * y;
      sum_xx += x * x;
     }

   const double dn    = (double)n;
   const double denom = dn * sum_xx - sum_x * sum_x;
   if(MathAbs(denom) < 1e-12)
      return false;

   const double slope     = (dn * sum_xy - sum_x * sum_y) / denom;       // per-bar drift
   const double intercept = (sum_y - slope * sum_x) / dn;                // value at x=0 (newest in window)

   // Residual stddev about the fitted line.
   double ss_res = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const int    shift = start_shift + i;
      const double y     = iClose(_Symbol, _Period, shift); // perf-allowed: cached once per closed bar
      const double yhat  = intercept + slope * (double)i;
      const double e     = y - yhat;
      ss_res += e * e;
     }
   sigma = MathSqrt(ss_res / dn);

   // Project the line to the requested shift. project_shift is expressed on the
   // same axis as the source shifts; x for that shift = (project_shift - start_shift).
   const double x_proj = (double)(project_shift - start_shift);
   line_at_project = intercept + slope * x_proj;
   return true;
  }

// Advance the cached channel state for the most recently closed bar. Called
// once per new closed bar (after the QM_IsNewBar gate in OnTick). Never adds a
// second timestamp gate.
void AdvanceState_OnNewBar()
  {
   g_chan_valid = false;
   g_chan_resistance   = 0.0;
   g_chan_support      = 0.0;
   g_chan_resist_prev  = 0.0;
   g_chan_support_prev = 0.0;

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   g_chan_atr = atr;
   if(atr <= 0.0)
      return;

   const int n = strategy_channel_lookback;

   // Current channel: window = shifts 1..n, projected to the signal bar (shift 1).
   double mid_now = 0.0, sigma_now = 0.0;
   if(!FitChannel(1, n, 1, mid_now, sigma_now))
      return;

   // Previous channel: window = shifts 2..n+1, projected to the previous signal
   // bar (shift 2). Used to detect a FRESH breakout/exit event.
   double mid_prev = 0.0, sigma_prev = 0.0;
   if(!FitChannel(2, n, 2, mid_prev, sigma_prev))
      return;

   const double half_now  = strategy_dev_mult * sigma_now;
   const double half_prev = strategy_dev_mult * sigma_prev;
   if(half_now <= 0.0)
      return;

   // Validity gate: channel half-width must sit within an ATR-scaled band.
   if(half_now < strategy_min_halfwidth_atr * atr)
      return;
   if(half_now > strategy_max_halfwidth_atr * atr)
      return;

   g_chan_resistance   = mid_now  + half_now;
   g_chan_support      = mid_now  - half_now;
   g_chan_resist_prev  = mid_prev + half_prev;
   g_chan_support_prev = mid_prev - half_prev;
   g_chan_valid        = true;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Fail-OPEN spread guard only (zero modeled .DWX
// spread never blocks). All channel/regime work is on the closed-bar path.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = g_chan_atr;
   if(atr_value <= 0.0)
      return false; // no channel yet — defer, do not block

   const double stop_distance = strategy_sl_atr_cap_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Channel-breakout entry. Caller guarantees QM_IsNewBar() == true (closed bar).
// Reads cached channel state only — no recompute here.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_chan_valid)
      return false;

   const double atr = g_chan_atr;
   if(atr <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return false;

   const double buffer = strategy_breakout_atr_mult * atr;

   // LONG: close[1] breaks above resistance + buffer, and the PRIOR bar was not
   //       already above its own resistance projection (fresh breakout event).
   const bool long_break  = (close1 > g_chan_resistance + buffer) &&
                            (close2 <= g_chan_resist_prev + buffer);
   // SHORT: symmetric below support.
   const bool short_break = (close1 < g_chan_support - buffer) &&
                            (close2 >= g_chan_support_prev - buffer);

   if(!long_break && !short_break)
      return false;

   const QM_OrderType side = long_break ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop = opposite channel line, capped at sl_atr_cap_mult * ATR from entry.
   const double cap_stop = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_sl_atr_cap_mult);
   double sl = 0.0;
   if(side == QM_BUY)
     {
      double line_stop = QM_StopRulesNormalizePrice(_Symbol, g_chan_support);
      // Use the closer (tighter) of opposite-line and ATR cap, but never beyond cap.
      if(line_stop <= 0.0 || line_stop >= entry)
         sl = cap_stop;                       // line not below entry → fall back to cap
      else
         sl = MathMax(line_stop, cap_stop);   // both below entry: pick the higher (closer to entry, never beyond cap)
     }
   else
     {
      double line_stop = QM_StopRulesNormalizePrice(_Symbol, g_chan_resistance);
      if(line_stop <= 0.0 || line_stop <= entry)
         sl = cap_stop;                       // line not above entry → fall back to cap
      else
         sl = MathMin(line_stop, cap_stop);   // both above entry: pick the lower (closer to entry, never beyond cap)
     }
   if(sl <= 0.0)
      return false;

   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_break ? "channel_break_long" : "channel_break_short";

   g_bars_in_trade = 0; // reset the time-stop counter on a fresh entry
   return true;
  }

// No active trade management beyond the fixed channel stop/target. The
// channel-re-entry, time-stop and opposite-breakout exits live in
// Strategy_ExitSignal. The per-closed-bar hold counter is advanced here.
void Strategy_ManageOpenPosition()
  {
  }

// Closed-bar exits: price closes back inside the channel, time stop, or an
// opposite-side channel breakout. One position per magic, so direction is read
// from the live position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
     {
      g_bars_in_trade = 0;
      return false;
     }

   // Advance the hold counter once per closed bar (this hook only runs on the
   // closed-bar path because OnTick gates exits separately — but to be safe we
   // increment here and the framework calls this each new-bar evaluation).
   g_bars_in_trade++;

   // Time stop.
   if(strategy_max_hold_bars > 0 && g_bars_in_trade >= strategy_max_hold_bars)
      return true;

   if(!g_chan_valid)
      return false; // no channel reference this bar; hold

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // Determine the live position direction for this magic.
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   const double atr = g_chan_atr;
   const double buffer = (atr > 0.0) ? strategy_breakout_atr_mult * atr : 0.0;

   if(is_long)
     {
      // Close long if price closes back inside the channel (below resistance)
      // OR breaks out the opposite (support) side.
      if(close1 < g_chan_resistance)
         return true;
      if(close1 < g_chan_support - buffer)
         return true;
     }
   else
     {
      if(close1 > g_chan_support)
         return true;
      if(close1 > g_chan_resistance + buffer)
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

   // Closed-bar gate: advance channel state + evaluate exits/entries once per
   // new closed bar. Consume QM_IsNewBar exactly once.
   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();

   QM_EquityStreamOnNewBar();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
