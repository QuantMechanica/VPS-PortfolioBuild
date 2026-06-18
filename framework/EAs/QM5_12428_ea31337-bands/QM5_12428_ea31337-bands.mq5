#property strict
#property version   "5.0"
#property description "QM5_12428 ea31337-bands — EA31337 Bollinger Band excursion/reentry (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12428 ea31337-bands
// -----------------------------------------------------------------------------
// Source: EA31337 Strategy-Bands (Stg_Bands.mqh SignalOpen()).
//   https://github.com/EA31337/Strategy-Bands/blob/master/Stg_Bands.mqh
// Card: artifacts/cards_approved/QM5_12428_ea31337-bands.md (g0_status APPROVED).
//
// Strategy family: mean-reversion / Bollinger-band reentry. Closed-bar reads at
// shift 1. Bollinger Bands period 24, deviation 1.0, applied price OPEN (H1).
//
// Mechanics (per card Entry section, EA31337 SignalOpenMethod=4, level=0):
//   The single trigger EVENT is the REENTRY: price excursed beyond a band over
//   a short lookback and the most recent CLOSED bar has returned inside the
//   band. The excursion and the base-line slope are STATES observed across the
//   lookback — never a second cross EVENT on the same bar. This is the .DWX
//   two-cross-same-bar zero-trade trap avoidance.
//
//   Long:
//     STATE  : min(low[1..lookback]) < lower_band  (price excursed below band)
//     STATE  : base line rising  -> mid[1] - mid[2] > signal_level (default 0)
//     STATE  : method 4 -> the lookback low is below the current base line
//     EVENT  : reentry -> close[1] is back above the lower band, but the bar
//              just prior (close[2]) was at/below it (returned from below).
//   Short (mirror):
//     STATE  : max(high[1..lookback]) > upper_band
//     STATE  : base line falling -> mid[1] - mid[2] < -signal_level
//     STATE  : method 4 -> the lookback high is above the current base line
//     EVENT  : reentry -> close[1] back below upper band, close[2] at/above it.
//
//   Stop   : protective ATR-based stop (card Stop Loss note: source price-stop
//            method not directly portable -> V5 ATR fallback).
//   Take   : RR multiple of the stop distance.
//   Exits  : (a) time exit after exit_max_bars closed bars held (card close-time
//                -30 bars); (b) opposite band-reentry signal closes early.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12428;
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
input int    strategy_bb_period          = 24;     // EA31337 Bollinger period
input double strategy_bb_deviation       = 1.0;    // EA31337 Bollinger deviation
input int    strategy_excursion_lookback = 3;      // bars (current/prev/pre-prev) for the band excursion
input double strategy_signal_level       = 0.0;    // EA31337 SignalOpenLevel: min base-line slope
input int    strategy_atr_period         = 14;     // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_rr              = 1.5;    // take-profit RR multiple of the stop
input int    strategy_exit_max_bars      = 30;     // EA31337 close-time: exit after N bars held
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Shared Bollinger band-reentry signal (closed-bar). Returns +1 long / -1 short
// / 0. Applied price OPEN per the card. The reentry is the single EVENT; the
// excursion and base-line slope are STATES across the lookback window.
// -----------------------------------------------------------------------------
int BandSignal()
  {
   const double lower1 = QM_BB_Lower(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_OPEN);
   const double upper1 = QM_BB_Upper(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_OPEN);
   const double mid1   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1, PRICE_OPEN);
   const double mid2   = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2, PRICE_OPEN);
   if(lower1 <= 0.0 || upper1 <= 0.0 || mid1 <= 0.0 || mid2 <= 0.0)
      return 0;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close1 <= 0.0 || close2 <= 0.0)
      return 0;

   // Lowest low / highest high across the excursion lookback (shifts 1..N).
   double lowest  = iLow(_Symbol, _Period, 1);   // perf-allowed: bounded closed-bar scan
   double highest = iHigh(_Symbol, _Period, 1);  // perf-allowed: bounded closed-bar scan
   const int last_shift = strategy_excursion_lookback < 1 ? 1 : strategy_excursion_lookback;
   for(int s = 1; s <= last_shift; ++s)
     {
      const double lo = iLow(_Symbol, _Period, s);
      const double hi = iHigh(_Symbol, _Period, s);
      if(lo > 0.0 && lo < lowest)
         lowest = lo;
      if(hi > 0.0 && hi > highest)
         highest = hi;
     }

   const double base_slope = mid1 - mid2;

   // --- Long: excursion below lower band + rising base + method-4 + reentry ---
   const bool long_excursion = (lowest < lower1);
   const bool long_slope     = (base_slope > strategy_signal_level);
   const bool long_method4   = (lowest < mid1);
   // Reentry EVENT: prior closed bar at/below the band, latest closed bar above.
   const bool long_reentry   = (close2 <= lower1 && close1 > lower1);
   if(long_excursion && long_slope && long_method4 && long_reentry)
      return 1;

   // --- Short: excursion above upper band + falling base + method-4 + reentry --
   const bool short_excursion = (highest > upper1);
   const bool short_slope      = (base_slope < -strategy_signal_level);
   const bool short_method4    = (highest > mid1);
   const bool short_reentry    = (close2 >= upper1 && close1 < upper1);
   if(short_excursion && short_slope && short_method4 && short_reentry)
      return -1;

   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
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

   const int sig = BandSignal();
   if(sig == 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(sig > 0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ea31337_bands_long";
      return true;
     }

   // sig < 0 -> short
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ea31337_bands_short";
   return true;
  }

// Fixed ATR stop/RR target carry the position; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: time stop (>= exit_max_bars held) OR opposite band signal.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Find this EA's open position to read its direction + open time.
   long pos_type = -1;
   datetime open_time = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type  = PositionGetInteger(POSITION_TYPE);
      open_time = (datetime)PositionGetInteger(POSITION_TIME);
      break;
     }
   if(pos_type < 0)
      return false;

   // Time exit: bars held = elapsed broker seconds / bar seconds. Pure time
   // math (no iTime/Bars strategy reads). PeriodSeconds() is framework-safe.
   const int bar_secs = PeriodSeconds(_Period);
   if(bar_secs > 0 && open_time > 0)
     {
      const long held_bars = (long)((TimeCurrent() - open_time) / bar_secs);
      if(held_bars >= strategy_exit_max_bars)
         return true;
     }

   // Opposite-signal exit: long open + fresh short reentry, or short open +
   // fresh long reentry.
   const int sig = BandSignal();
   if(pos_type == POSITION_TYPE_BUY && sig < 0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && sig > 0)
      return true;

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
