#property strict
#property version   "5.0"
#property description "QM5_12481 gh-bb-w — Bollinger Bottom-W Reversal (long-only, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12481 gh-bb-w
// -----------------------------------------------------------------------------
// Source: je-suis-tm quant-trading "Bollinger Bands Pattern Recognition"
//   (GitHub: bollinger_bands + signal_generation). Card g0_status APPROVED:
//   artifacts/cards_approved/QM5_12481_gh-bb-w.md.
//
// Long-only Bollinger bottom-W reversal. Per the card:
//   mid   = SMA(price, length)
//   upper = mid + dev * std ;  lower = mid - dev * std
//   width = (upper - lower) / mid            <- the "bb-w" band-width regime
//
// STATE / EVENT decomposition (avoids the two-cross same-bar zero-trade trap):
//   Vol-regime STATE : a SQUEEZE occurred inside the pattern horizon, i.e. the
//                      band width fell to (or below) a contraction fraction of
//                      its horizon-max. The W bottoms form during the squeeze.
//   W-bottom STATE   : within the horizon there is a first bottom near the lower
//                      band, then a middle node near the mid band, then a second
//                      bottom near the lower band that is BELOW the first bottom.
//   Trigger EVENT    : price closes ABOVE the upper band on the trigger bar while
//                      the PRIOR closed bar was at/below it. ONE fresh breakout
//                      event per bar — the single trigger.
//
// Exit:
//   - Width contraction: band width < beta (point-scaled). Source default exit.
//   - Failed breakout  : close back below the mid band after entry.
//
// Stop: 3.0 * ATR(atr_period) from entry (card adds the ATR protection the
//       source lacked).
//
// The horizon scan is cached once per closed bar (intraday discipline) so the
// per-tick path stays O(1). Only the 5 Strategy_* hooks + Strategy inputs are
// EA-specific; everything else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12481;
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
input int    strategy_bb_period          = 20;     // Bollinger length (SMA + stdev)
input double strategy_bb_deviation       = 2.0;    // Bollinger band deviation (std mult)
input int    strategy_pattern_horizon    = 75;     // bars searched for the W pattern
input double strategy_band_touch_frac    = 0.15;   // "near band" tolerance, as a fraction of band half-width
input double strategy_squeeze_frac       = 0.70;   // squeeze = width <= this * horizon-max width
input double strategy_exit_width_frac    = 0.40;   // contraction exit: width < this * horizon-max width
input int    strategy_atr_period         = 20;     // ATR period for the protective stop
input double strategy_sl_atr_mult        = 3.0;    // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached pattern state (advanced once per closed bar).
// -----------------------------------------------------------------------------
bool   g_pattern_ready   = false;   // W-bottom + squeeze present in the horizon
bool   g_breakout_event  = false;   // fresh upper-band breakout on the trigger bar
double g_mid_last        = 0.0;     // mid band at the last closed bar (shift 1)
double g_width_last      = 0.0;     // band width at the last closed bar (shift 1)
double g_atr_last        = 0.0;     // ATR at the last closed bar (shift 1)

// Compute the (upper-lower)/mid band width at a given closed-bar shift.
double BandWidthAtShift(const int shift)
  {
   const double up  = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double lo  = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   const double mid = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, shift);
   if(up <= 0.0 || lo <= 0.0 || mid <= 0.0)
      return 0.0;
   return (up - lo) / mid;
  }

// Re-scan the pattern horizon ONCE per new closed bar. Reads closed-bar shifts
// only; never loops further back than the horizon. Sets the cached state used
// by the O(1) per-tick entry gate.
void AdvanceState_OnNewBar()
  {
   g_pattern_ready  = false;
   g_breakout_event = false;

   const double mid1   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double up1    = QM_BB_Upper (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double up2    = QM_BB_Upper (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   const double width1 = BandWidthAtShift(1);
   const double atr1   = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);

   g_mid_last   = mid1;
   g_width_last = width1;
   g_atr_last   = atr1;

   if(mid1 <= 0.0 || up1 <= 0.0 || up2 <= 0.0)
      return;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return;

   // --- Trigger EVENT: fresh breakout above the upper band (one event/bar). ---
   // shift 1 close above its band, shift 2 close at/below its band.
   const bool breakout = (close1 > up1 && close2 <= up2);
   if(!breakout)
      return; // no fresh breakout this bar — nothing to arm
   g_breakout_event = true;

   // --- Pattern horizon scan over closed bars 2 .. horizon+1 (before trigger). ---
   // Track the max band width (for the squeeze test), the first bottom near the
   // lower band, a middle node near mid, and a second (lower) bottom near lower.
   const int    first_shift = 2;
   const int    last_shift  = strategy_pattern_horizon + 1;

   double max_width   = 0.0;
   double min_width   = 0.0;
   bool   have_minmax = false;

   // W-structure scanned newest->oldest so the "second bottom" is the more recent
   // of the two (closer to the breakout), matching the source's W shape.
   bool   first_bottom_seen  = false;  // OLDER bottom (found last in this order)
   bool   middle_node_seen   = false;  // mid-band touch between the two bottoms
   bool   second_bottom_seen = false;  // NEWER bottom (found first), lower of the two
   double second_bottom_dist = 0.0;    // |close - lower| of the second bottom

   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double up_s  = QM_BB_Upper (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
      const double lo_s  = QM_BB_Lower (_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
      const double mid_s = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, s);
      if(up_s <= 0.0 || lo_s <= 0.0 || mid_s <= 0.0)
         continue;

      const double half = (up_s - lo_s) / 2.0;          // band half-width
      if(half <= 0.0)
         continue;
      const double tol = strategy_band_touch_frac * half; // "near band" tolerance

      const double w_s = (up_s - lo_s) / mid_s;
      if(!have_minmax)
        {
         max_width = w_s; min_width = w_s; have_minmax = true;
        }
      else
        {
         if(w_s > max_width) max_width = w_s;
         if(w_s < min_width) min_width = w_s;
        }

      const double c_s = iClose(_Symbol, _Period, s);    // perf-allowed: single closed-bar read
      if(c_s <= 0.0)
         continue;

      const double dist_lower = MathAbs(c_s - lo_s);
      const double dist_mid   = MathAbs(c_s - mid_s);
      const bool   near_lower = (dist_lower <= tol);
      const bool   near_mid   = (dist_mid   <= tol);

      // Sequence in newest->oldest scan: second bottom -> middle node -> first bottom.
      if(!second_bottom_seen)
        {
         if(near_lower)
           {
            second_bottom_seen = true;
            second_bottom_dist = dist_lower;
           }
        }
      else if(!middle_node_seen)
        {
         if(near_mid)
            middle_node_seen = true;
        }
      else if(!first_bottom_seen)
        {
         // First (older) bottom must be near the lower band AND be HIGHER off the
         // band than the second bottom (second bottom is the lower low of the W).
         if(near_lower && dist_lower > second_bottom_dist)
            first_bottom_seen = true;
        }
     }

   const bool w_shape = (second_bottom_seen && middle_node_seen && first_bottom_seen);
   if(!w_shape)
      return;

   // --- Vol-regime STATE: a squeeze formed inside the horizon (width fell to
   //     <= squeeze_frac of the horizon-max width). The W builds in the squeeze. ---
   bool squeezed = false;
   if(have_minmax && max_width > 0.0)
      squeezed = (min_width <= strategy_squeeze_frac * max_width);

   g_pattern_ready = (w_shape && squeezed);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   if(g_atr_last <= 0.0)
      return false; // no ATR yet — defer to entry gate

   const double stop_distance = strategy_sl_atr_mult * g_atr_last;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true. Reads cached state
// only; the horizon scan already ran in AdvanceState_OnNewBar.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_breakout_event || !g_pattern_ready)
      return false;
   if(g_atr_last <= 0.0)
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, g_atr_last, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed TP; exit on width contraction / failed breakout
   req.reason = "bb_w_breakout_long";
   return true;
  }

// No active trade management beyond the protective ATR stop. Exits are in
// Strategy_ExitSignal (width contraction / failed breakout).
void Strategy_ManageOpenPosition()
  {
  }

// Exit when (a) band width contracts below the exit fraction of the recent
// horizon-max width, or (b) price closes back below the mid band (failed
// breakout). Both read cached closed-bar state.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   // Failed breakout: last closed price below the mid band.
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(g_mid_last > 0.0 && close1 > 0.0 && close1 < g_mid_last)
      return true;

   // Width contraction exit: compare current width to a horizon-max baseline.
   if(g_width_last > 0.0)
     {
      double max_width = g_width_last;
      const int last_shift = strategy_pattern_horizon + 1;
      for(int s = 1; s <= last_shift; ++s)
        {
         const double w_s = BandWidthAtShift(s);
         if(w_s > max_width)
            max_width = w_s;
        }
      if(max_width > 0.0 && g_width_last < strategy_exit_width_frac * max_width)
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

   // New closed bar: advance the cached pattern/breakout state ONCE.
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
