#property strict
#property version   "5.0"
#property description "QM5_11643 robo-ema828-cci30-psar-h1 — EMA8/28 + CCI30 + PSAR (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11643 robo-ema828-cci30-psar-h1
// -----------------------------------------------------------------------------
// Source: RoboForex Educational Team, "Forex Strategy Collection" (~2015),
//         strategy "EMA + CCI + PSAR", page 75.
// Card: artifacts/cards_approved/QM5_11643_robo-ema828-cci30-psar-h1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT : CCI(30) zero-line cross.
//                     long  -> cci@2 <= 0 AND cci@1 > 0
//                     short -> cci@2 >= 0 AND cci@1 < 0
//                   This is the ONE fresh event per bar. The EMA stack and the
//                   PSAR position are confirming STATES (not second events), so
//                   we never require two crosses on the same bar.
//   Stack STATE   : EMA(8) > EMA(28) for long, EMA(8) < EMA(28) for short.
//   PSAR STATE    : SAR below the last close for long (uptrend),
//                   SAR above the last close for short (downtrend).
//   Stop          : entry -/+ sl_atr_mult * ATR(atr_period).
//   Take profit   : entry +/- tp_atr_mult * ATR (same ATR value as the stop).
//   PSAR trail    : while in a position, ratchet the SL toward the current
//                   closed-bar SAR (never loosened) as a trailing reference.
//   Spread guard  : skip only a genuinely wide spread > spread_pct_of_stop of
//                   the stop distance (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11643;
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
input int    strategy_ema_fast_period    = 8;      // fast EMA (trend stack)
input int    strategy_ema_slow_period    = 28;     // slow EMA (trend stack)
input int    strategy_cci_period         = 30;     // CCI lookback (zero-cross trigger)
input double strategy_psar_step          = 0.02;   // Parabolic SAR acceleration step
input double strategy_psar_max           = 0.20;   // Parabolic SAR max acceleration
input int    strategy_atr_period         = 14;     // ATR period (stop / target / trail)
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR
input bool   strategy_psar_trail_enabled = true;   // ratchet SL toward closed-bar SAR
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

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Confirming STATE: EMA(8)/EMA(28) stack (closed bar) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // --- Confirming STATE: PSAR position vs last close ---
   const double sar   = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || close1 <= 0.0)
      return false;

   // --- Trigger EVENT: CCI(30) zero-line cross (one fresh event/bar) ---
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   const bool cci_cross_up   = (cci_prev <= 0.0 && cci_now > 0.0);
   const bool cci_cross_down = (cci_prev >= 0.0 && cci_now < 0.0);

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- LONG: CCI crosses up, bullish stack, SAR below price ---
   if(cci_cross_up && ema_fast > ema_slow && sar < close1)
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
      req.reason = "ema828_cci30_psar_long";
      return true;
     }

   // --- SHORT: CCI crosses down, bearish stack, SAR above price ---
   if(cci_cross_down && ema_fast < ema_slow && sar > close1)
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
      req.reason = "ema828_cci30_psar_short";
      return true;
     }

   return false;
  }

// PSAR trailing stop: ratchet the SL toward the current closed-bar SAR in the
// trade's favour. Never loosens an existing stop. Runs per tick but only reads
// pooled indicator values + position fields — O(1).
void Strategy_ManageOpenPosition()
  {
   if(!strategy_psar_trail_enabled)
      return;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return;

   const double sar = QM_SAR(_Symbol, _Period, strategy_psar_step, strategy_psar_max, 1);
   if(sar <= 0.0)
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

      const long ptype   = PositionGetInteger(POSITION_TYPE);
      const double cur_sl = PositionGetDouble(POSITION_SL);

      if(ptype == POSITION_TYPE_BUY)
        {
         // Trail up only: SAR below current price, tighter than the current SL.
         if(sar > cur_sl)
            QM_TM_MoveSL(ticket, sar, "psar_trail");
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Trail down only: SAR above current price, tighter than the current SL.
         if(cur_sl <= 0.0 || sar < cur_sl)
            QM_TM_MoveSL(ticket, sar, "psar_trail");
        }
     }
  }

// SL/TP and the PSAR trail handle exits. No discretionary close signal.
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
