#property strict
#property version   "5.0"
#property description "QM5_11638 robo-bb120-3dev-ema48-h1 — Triple BB(120,3dev) extreme fade + EMA cross confirm (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11638 robo-bb120-3dev-ema48-h1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         "Triple BB Channel", pages 59-60.
// Card: artifacts/cards_approved/QM5_11638_robo-bb120-3dev-ema48-h1.md (g0 APPROVED).
//
// Mechanics (mean reversion, closed-bar reads at shift 1, H1):
//   BB(120) period 120 = slow long-run mean; 3-sigma band = extreme extension.
//   Trade is the reversion from the 3-sigma extreme back toward the center.
//
//   Trigger EVENT (one event/bar):
//     LONG : EMA(fast) crosses ABOVE EMA(slow)  -> fast MA confirms reversal up.
//     SHORT: EMA(fast) crosses BELOW EMA(slow).
//   Confirming STATE (observed within a small lookback window BEFORE the
//   trigger bar, never the same bar — avoids the two-cross-same-bar trap):
//     LONG : the bar Low touched/crossed BELOW BB(120,3sigma) lower band.
//     SHORT: the bar High touched/crossed ABOVE BB(120,3sigma) upper band.
//   Stop  : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take  : entry +/- tp_atr_mult * ATR (same ATR value as the stop).
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//                 modeled spread).
//
//   NOTE on naming: the slug says "ema48" / "3dev"; the APPROVED card body
//   specifies EMA(4)/EMA(8) fast cross + BB(120, 3-sigma) band. Per HR9 the
//   card body is authoritative — defaults follow EMA(4)/EMA(8) & deviation 3.0.
//   Both EMA periods and the BB deviation are inputs (operator-sweepable).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11638;
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
input int    strategy_bb_period          = 120;    // slow Bollinger period (long-run mean)
input double strategy_bb_deviation       = 3.0;    // 3-sigma extreme band
input int    strategy_ema_fast_period    = 4;      // fast EMA (reversal confirmation)
input int    strategy_ema_slow_period    = 8;      // slow EMA (reversal confirmation)
input int    strategy_band_lookback      = 5;      // bars back to look for the 3-sigma touch state
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
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

// Helper: did the bar Low touch/cross BELOW the 3-sigma lower band within the
// lookback window that PRECEDES the trigger bar (shifts 2 .. lookback+1)?
bool BandTouchedLowerRecently()
  {
   const int first_shift = 2;
   const int last_shift  = strategy_band_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double bb_lower = QM_BB_Lower(_Symbol, _Period, strategy_bb_period,
                                          strategy_bb_deviation, s, PRICE_CLOSE);
      if(bb_lower <= 0.0)
         continue;
      const double low_s = iLow(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(low_s <= 0.0)
         continue;
      if(low_s <= bb_lower)
         return true;
     }
   return false;
  }

// Helper: did the bar High touch/cross ABOVE the 3-sigma upper band within the
// lookback window that PRECEDES the trigger bar (shifts 2 .. lookback+1)?
bool BandTouchedUpperRecently()
  {
   const int first_shift = 2;
   const int last_shift  = strategy_band_lookback + 1;
   for(int s = first_shift; s <= last_shift; ++s)
     {
      const double bb_upper = QM_BB_Upper(_Symbol, _Period, strategy_bb_period,
                                          strategy_bb_deviation, s, PRICE_CLOSE);
      if(bb_upper <= 0.0)
         continue;
      const double high_s = iHigh(_Symbol, _Period, s); // perf-allowed: single closed-bar read
      if(high_s <= 0.0)
         continue;
      if(high_s >= bb_upper)
         return true;
     }
   return false;
  }

// Long/short mean-reversion entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trigger EVENT: fresh EMA(fast)/EMA(slow) cross at shift 1 ---
   const double ema_fast_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_now  = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 ||
      ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0)
      return false;

   const bool crossed_up   = (ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now);
   const bool crossed_down = (ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now);
   if(!crossed_up && !crossed_down)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG: extreme-low fade. EMA cross up + a 3-sigma lower-band touch
   //     observed in the preceding lookback window (state, not same bar). ---
   if(crossed_up && BandTouchedLowerRecently())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "robo_bb3_fade_long";
      return true;
     }

   // --- SHORT: extreme-high fade. EMA cross down + a 3-sigma upper-band touch
   //     observed in the preceding lookback window. ---
   if(crossed_down && BandTouchedUpperRecently())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "robo_bb3_fade_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// No defensive signal exit — the ATR stop and the BB-reversion TP carry the
// position. Mean-reversion: opposite EMA cross is the next trade's trigger,
// not an early exit.
bool Strategy_ExitSignal()
  {
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
