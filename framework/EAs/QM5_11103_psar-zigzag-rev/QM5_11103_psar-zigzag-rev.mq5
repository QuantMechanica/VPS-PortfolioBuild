#property strict
#property version   "5.0"
#property description "QM5_11103 psar-zigzag-rev — ZigZag-on-Parabolic-SAR swing reversal (FX/XAU, H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11103 psar-zigzag-rev
// -----------------------------------------------------------------------------
// Source: EarnForex "ZigZagOnParabolic", GitHub repository + MQL5 source.
//         https://github.com/EarnForex/ZigZagOnParabolic
// Card: artifacts/cards_approved/QM5_11103_psar-zigzag-rev.md (g0_status APPROVED).
//
// Mechanics (closed-bar evaluation only — NON-REPAINTING reversal detection):
//   The EarnForex indicator marks a ZigZag peak/trough whenever the Parabolic
//   SAR flips relative to the bar MIDPOINT ((high+low)/2). We mechanise the
//   SAR-vs-midpoint flip as a hard, deterministic reversal signal evaluated on
//   the last two FULLY CLOSED bars (shift 2 = prior, shift 1 = detection bar):
//
//     mid(s)  = (high[s] + low[s]) / 2
//     sar(s)  = Parabolic SAR(step, maximum) at shift s
//
//     NEW TROUGH (long, SAR flips ABOVE->BELOW price):
//        sar@2 >= mid@2  AND  sar@1 <  mid@1
//     NEW PEAK   (short, SAR flips BELOW->ABOVE price):
//        sar@2 <= mid@2  AND  sar@1 >  mid@1
//
//   Both shift-1 and shift-2 are closed bars; the standard Parabolic SAR value
//   at a closed shift is computed forward and never revises on later bars, so a
//   detection that fires on bar shift 1 can NEVER repaint. We act ONLY on the
//   detection-bar close, never on a back-shifted chart-time extremum.
//
//   Entry  : market BUY on a fresh trough detection; market SELL on a fresh peak
//            detection. One active position per symbol/magic.
//   Filter : the new swing must extend > min_swing_atr * ATR(atr_period) from the
//            last OPPOSITE confirmed swing extreme (trough vs prior peak, peak vs
//            prior trough). Suppresses micro-oscillation noise.
//   Exit   : (a) opposite detection (long closes on the next peak; short on the
//            next trough), OR (b) safety time stop after time_stop_bars H4 bars.
//   Stop   : hard SL = sl_atr_mult * ATR(atr_period) from entry. No fixed TP —
//            the card's exit is reversal/time-stop driven (tp = 0 = none).
//   Spread : fail-OPEN on .DWX (0 modeled spread); block only a genuinely wide
//            quoted spread.
//
// Detection state (last swing kind/price + bars-in-trade) is cached once per
// closed bar at file scope; the per-tick path is O(1).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11103;
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
input double strategy_sar_step          = 0.02;  // Parabolic SAR acceleration step (source default)
input double strategy_sar_maximum       = 0.20;  // Parabolic SAR acceleration maximum (source default)
input int    strategy_atr_period        = 14;    // ATR period (swing filter + stop)
input double strategy_min_swing_atr     = 1.0;   // require swing move > this * ATR from opposite swing (0 disables)
input double strategy_sl_atr_mult       = 2.5;   // hard stop distance = mult * ATR (card P2 baseline)
input int    strategy_time_stop_bars    = 16;    // safety time stop, in H4 bars (0 disables)
input double strategy_spread_pct_of_stop = 15.0; // skip new entries if spread > this % of stop distance

// -----------------------------------------------------------------------------
// File-scope cached detection state (advanced once per closed bar).
//   g_last_swing_kind: +1 = last confirmed swing was a PEAK (short signal),
//                      -1 = last confirmed swing was a TROUGH (long signal),
//                       0 = none yet.
//   g_last_peak_price / g_last_trough_price: price of the most recent confirmed
//                      peak / trough (the bar midpoint extreme used for the
//                      opposite-swing distance filter).
//   g_signal_bar_time: bar-open time of the detection bar we last ACTED on, so a
//                      single detection fires at most one entry.
//   g_entry_bar_time : bar-open time of the bar on which the live position was
//                      opened (for the time-stop bar count).
// -----------------------------------------------------------------------------
int      g_last_swing_kind    = 0;
double   g_last_peak_price     = 0.0;
double   g_last_trough_price   = 0.0;
datetime g_last_signal_time    = 0;   // detection bar time we last entered against
datetime g_entry_bar_time      = 0;   // bar-open time at entry (time-stop anchor)

// Cached fresh-detection flags for THIS closed bar (set by AdvanceState_OnNewBar).
bool     g_fresh_trough        = false;  // long signal fired on the just-closed bar
bool     g_fresh_peak          = false;  // short signal fired on the just-closed bar
datetime g_detection_bar_time  = 0;      // bar-open time of the detection bar (shift 1)

// -----------------------------------------------------------------------------
// Closed-bar detection: read SAR + midpoint on the last two closed bars and
// flag a fresh peak / trough. NON-REPAINTING (closed shifts only, forward SAR).
// Updates the last-swing kind/price cache used by the opposite-swing filter.
// -----------------------------------------------------------------------------
void AdvanceState_OnNewBar()
  {
   g_fresh_trough = false;
   g_fresh_peak   = false;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_maximum, 1);
   const double sar2 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_maximum, 2);
   if(sar1 <= 0.0 || sar2 <= 0.0)
      return;

   // Bar midpoints on the two closed detection bars. Single closed-bar reads.
   const double hi1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read, QM_IsNewBar-gated
   const double lo1 = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double hi2 = iHigh(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   const double lo2 = iLow(_Symbol, _Period, 2);   // perf-allowed: single closed-bar read
   if(hi1 <= 0.0 || lo1 <= 0.0 || hi2 <= 0.0 || lo2 <= 0.0)
      return;

   const double mid1 = (hi1 + lo1) / 2.0;
   const double mid2 = (hi2 + lo2) / 2.0;

   // SAR flips from at/above price to below price => NEW TROUGH (bullish).
   const bool trough = (sar2 >= mid2 && sar1 < mid1);
   // SAR flips from at/below price to above price => NEW PEAK (bearish).
   const bool peak   = (sar2 <= mid2 && sar1 > mid1);

   g_detection_bar_time = iTime(_Symbol, _Period, 1); // perf-allowed: closed detection-bar id

   if(trough)
     {
      // The trough extreme is the detection bar's low.
      g_last_trough_price = lo1;
      g_last_swing_kind   = -1;
      g_fresh_trough      = true;
     }
   else if(peak)
     {
      // The peak extreme is the detection bar's high.
      g_last_peak_price = hi1;
      g_last_swing_kind = 1;
      g_fresh_peak      = true;
     }
  }

// True if the fresh swing extends far enough from the last OPPOSITE swing.
// For a trough: distance from the last recorded peak. For a peak: from the last
// recorded trough. Passes (no suppression) when no opposite swing exists yet.
bool SwingMovePasses(const bool is_trough)
  {
   if(strategy_min_swing_atr <= 0.0)
      return true;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return true; // no ATR yet — do not suppress

   const double threshold = strategy_min_swing_atr * atr_value;

   if(is_trough)
     {
      if(g_last_peak_price <= 0.0)
         return true; // no opposite swing recorded yet
      return ((g_last_peak_price - g_last_trough_price) > threshold);
     }
   else
     {
      if(g_last_trough_price <= 0.0)
         return true;
      return ((g_last_peak_price - g_last_trough_price) > threshold);
     }
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Market reversal entry. Caller guarantees QM_IsNewBar() == true (closed-bar
// gate); fresh-detection flags were just refreshed by AdvanceState_OnNewBar().
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(!g_fresh_trough && !g_fresh_peak)
      return false;

   // Single-fire guard: never enter twice off the same detection bar.
   if(g_detection_bar_time == g_last_signal_time)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(g_fresh_trough)
     {
      if(!SwingMovePasses(true))
         return false;

      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;

      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP — reversal/time-stop exit
      req.reason = "psar_zz_trough_long";
      g_last_signal_time = g_detection_bar_time;
      g_entry_bar_time   = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open id (time-stop anchor)
      return true;
     }

   // g_fresh_peak
   if(!SwingMovePasses(false))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;

   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = 0.0;
   req.reason = "psar_zz_peak_short";
   g_last_signal_time = g_detection_bar_time;
   g_entry_bar_time   = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open id
   return true;
  }

// No active trade management beyond the fixed ATR stop. Exit is handled by
// Strategy_ExitSignal (opposite detection + time stop).
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: opposite SAR-flip detection OR the bar-count time stop.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the live position direction (one position per magic).
   long ptype = -1;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      ptype = PositionGetInteger(POSITION_TYPE);
      break;
     }
   if(ptype < 0)
      return false;

   // (a) Opposite detection: long exits on a fresh peak; short on a fresh trough.
   //     Flags are refreshed once per closed bar in AdvanceState_OnNewBar().
   if(ptype == POSITION_TYPE_BUY && g_fresh_peak)
      return true;
   if(ptype == POSITION_TYPE_SELL && g_fresh_trough)
      return true;

   // (b) Safety time stop: close after time_stop_bars H4 bars in trade.
   if(strategy_time_stop_bars > 0 && g_entry_bar_time > 0)
     {
      const datetime now_bar = iTime(_Symbol, _Period, 0); // perf-allowed: current bar-open id
      if(now_bar > g_entry_bar_time)
        {
         const long secs_per_bar = PeriodSeconds(_Period);
         if(secs_per_bar > 0)
           {
            const long bars_in_trade = (long)((now_bar - g_entry_bar_time) / secs_per_bar);
            if(bars_in_trade >= strategy_time_stop_bars)
               return true;
           }
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

   g_last_swing_kind   = 0;
   g_last_peak_price    = 0.0;
   g_last_trough_price  = 0.0;
   g_last_signal_time   = 0;
   g_entry_bar_time     = 0;
   g_fresh_trough       = false;
   g_fresh_peak         = false;
   g_detection_bar_time = 0;

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

   // Per-tick: no active management beyond the fixed stop (no-op).
   Strategy_ManageOpenPosition();

   // Closed-bar structural work only — refresh detection BEFORE exit/entry so
   // both read the same fresh swing flags. QM_IsNewBar is single-consume.
   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Refresh non-repainting SAR-vs-midpoint detection for this closed bar.
   AdvanceState_OnNewBar();

   // Per-closed-bar discretionary exit (opposite detection / time stop).
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
