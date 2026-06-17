#property strict
#property version   "5.0"
#property description "QM5_11216 ft-ema-skip — Freqtrade EMA Skip Pump local-min reversal (long-only, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11216 ft-ema-skip
// -----------------------------------------------------------------------------
// Source: freqtrade-strategies "EMASkipPump.py" (berlinguyinca), GitHub commit
//   dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4.
// Card: artifacts/cards_approved/QM5_11216_ft-ema-skip.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1; M5). This is a pump/dump
// avoidance mean-reversion: buy a local-minimum reversal below the short EMAs,
// at/below the lower Bollinger band, only when volume is NOT a pump spike.
//
//   Volume filter STATE : tick_vol[1] < mean(tick_vol[2..vol_mean_period+1]) *
//                         vol_mean_mult   (avoid pump spikes; mult is a cap, so
//                         this almost never blocks a normal bar — fail-open).
//   Below-EMA STATE     : close[1] < EMA(short)  AND  close[1] < EMA(medium).
//   Local-min EVENT     : close[1] == MIN(close, local_extreme_period)  — the
//                         closed bar is the lowest close of the lookback window.
//   Lower-band STATE    : close[1] <= BB_Lower(bb_period, bb_dev, TYPICAL).
//   All true on the closed bar -> enter long at next bar open (market send).
//
//   Stop  : QM_StopATR(atr_period, atr_sl_mult) (card baseline 14 / 1.5),
//           never wider than the source -roi_stop_pct (-5%) of entry.
//   Take  : roi_target (source 10%) above entry, as a fixed fractional TP.
//   Exit  : symmetric local-maximum reversal —
//           close[1] > EMA(short) AND close[1] > EMA(medium) AND
//           close[1] == MAX(close, local_extreme_period) AND
//           close[1] >= BB_Upper(...). Plus framework SL/TP/Friday-close.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks).
//   - No swap gate.
//   - Volume is MT5 TICK volume (card: "Map Freqtrade exchange volume to MT5
//     tick volume"); read via a bounded closed-bar loop (perf-allowed, gated by
//     the framework new-bar gate).
//   - Local-min/max are CLOSE-based (gapless CFDs), not range/gap based.
//   - No external macro CSV.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11216;
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
input int    strategy_ema_short_period    = 5;      // EMA(5) — close must be below
input int    strategy_ema_medium_period   = 12;     // EMA(12) — close must be below
input int    strategy_local_extreme_period = 12;    // rolling MIN/MAX(12) lookback
input int    strategy_bb_period           = 20;     // Bollinger period
input double strategy_bb_deviation        = 2.0;    // Bollinger deviation
input int    strategy_vol_mean_period     = 30;     // rolling mean volume lookback
input double strategy_vol_mean_mult       = 20.0;   // pump cap: vol < mean*mult
input int    strategy_atr_period          = 14;     // ATR period for the stop
input double strategy_atr_sl_mult         = 1.5;    // stop distance = mult * ATR
input double strategy_roi_target_pct      = 10.0;   // source ROI target, % of entry
input double strategy_max_stop_pct        = 5.0;    // source -5% stop cap, % of entry
input double strategy_spread_pct_of_stop  = 15.0;   // skip if spread > this % of stop distance

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

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_atr_sl_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Mean tick volume over the window that PRECEDES the trigger bar:
// shifts (start_shift .. start_shift+period-1). Closed-bar gated by the
// framework new-bar gate, so this bounded loop runs once per closed bar.
double VolumeMean(const int period, const int start_shift)
  {
   if(period <= 0)
      return 0.0;
   double sum = 0.0;
   int counted = 0;
   for(int s = start_shift; s < start_shift + period; ++s)
     {
      const long v = iVolume(_Symbol, _Period, s); // perf-allowed: tick-volume mean, closed-bar gated
      if(v <= 0)
         continue;
      sum += (double)v;
      ++counted;
     }
   if(counted <= 0)
      return 0.0;
   return sum / (double)counted;
  }

// Lowest close over [start_shift .. start_shift+period-1].
double LowestClose(const int period, const int start_shift)
  {
   double lo = DBL_MAX;
   for(int s = start_shift; s < start_shift + period; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: rolling-min close, closed-bar gated
      if(c <= 0.0)
         continue;
      if(c < lo)
         lo = c;
     }
   return (lo == DBL_MAX) ? 0.0 : lo;
  }

// Highest close over [start_shift .. start_shift+period-1].
double HighestClose(const int period, const int start_shift)
  {
   double hi = 0.0;
   for(int s = start_shift; s < start_shift + period; ++s)
     {
      const double c = iClose(_Symbol, _Period, s); // perf-allowed: rolling-max close, closed-bar gated
      if(c <= 0.0)
         continue;
      if(c > hi)
         hi = c;
     }
   return hi;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Below-EMA STATE: close below short and medium EMAs (closed bar) ---
   const double ema_short  = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 1);
   const double ema_medium = QM_EMA(_Symbol, _Period, strategy_ema_medium_period, 1);
   if(ema_short <= 0.0 || ema_medium <= 0.0)
      return false;
   if(!(close1 < ema_short && close1 < ema_medium))
      return false;

   // --- Local-minimum EVENT: closed bar is the lowest close of the window ---
   // Window includes the trigger bar itself: shifts 1 .. local_extreme_period.
   const double local_min = LowestClose(strategy_local_extreme_period, 1);
   if(local_min <= 0.0)
      return false;
   if(close1 > local_min)
      return false; // close1 must BE the minimum (<= every other close in window)

   // --- Lower-band STATE: close at/below the lower Bollinger band ---
   const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_deviation, 1, PRICE_TYPICAL);
   if(bb_lower <= 0.0)
      return false;
   if(!(close1 <= bb_lower))
      return false;

   // --- Volume filter STATE: not a pump spike (fail-open via the cap) ---
   // Mean over the 30 bars BEFORE the trigger bar (shifts 2 .. period+1).
   const double vol_mean = VolumeMean(strategy_vol_mean_period, 2);
   if(vol_mean > 0.0)
     {
      const long vol1 = iVolume(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if((double)vol1 >= vol_mean * strategy_vol_mean_mult)
         return false; // pump spike — skip
     }

   // --- Build the long entry. Framework sizes lots (no lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // ATR stop, capped to never exceed the source -max_stop_pct of entry.
   double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double max_stop_dist = entry * (strategy_max_stop_pct / 100.0);
   if(max_stop_dist > 0.0)
     {
      const double sl_floor = entry - max_stop_dist; // tightest (highest) allowed SL price
      if(sl < sl_floor)
         sl = sl_floor; // ATR stop wider than -5% cap -> tighten to the cap
     }
   sl = QM_TM_NormalizePrice(_Symbol, sl);
   if(!(sl < entry))
      return false;

   // ROI target as a fixed fractional TP above entry (source 10%).
   double tp = entry * (1.0 + strategy_roi_target_pct / 100.0);
   tp = QM_TM_NormalizePrice(_Symbol, tp);
   if(!(tp > entry))
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ema_skip_pump_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / ROI target. The
// symmetric local-maximum exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Symmetric exit: local-maximum reversal above the short EMAs, at/above the
// upper Bollinger band. One state evaluated on the closed bar.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double ema_short  = QM_EMA(_Symbol, _Period, strategy_ema_short_period, 1);
   const double ema_medium = QM_EMA(_Symbol, _Period, strategy_ema_medium_period, 1);
   if(ema_short <= 0.0 || ema_medium <= 0.0)
      return false;
   if(!(close1 > ema_short && close1 > ema_medium))
      return false;

   const double local_max = HighestClose(strategy_local_extreme_period, 1);
   if(local_max <= 0.0)
      return false;
   if(close1 < local_max)
      return false; // close1 must BE the maximum

   const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                       strategy_bb_deviation, 1, PRICE_TYPICAL);
   if(bb_upper <= 0.0)
      return false;

   return (close1 >= bb_upper);
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
