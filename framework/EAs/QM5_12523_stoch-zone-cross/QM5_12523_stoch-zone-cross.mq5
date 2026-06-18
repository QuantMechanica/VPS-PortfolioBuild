#property strict
#property version   "5.0"
#property description "QM5_12523 stoch-zone-cross — Stochastic OB/OS zone-cross reversal (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_12523 stoch-zone-cross
// -----------------------------------------------------------------------------
// Source: Backtest Rookies "Backtrader Stochastic Indicator Review" (2017-08-02).
// Card: artifacts/cards_approved/QM5_12523_stoch-zone-cross.md (g0_status APPROVED).
//
// Mechanics (long+short, closed-bar reads at shift 1; opposite-cross exit):
//   Stochastic %K and %D on completed bars (period=14, d_fast=3, d_slow=3).
//   Oversold zone   = both %K and %D <= os_level (default 20).
//   Overbought zone = both %K and %D >= ob_level (default 80).
//
//   Entry LONG   EVENT: %K crosses ABOVE %D  while BOTH are in the OS zone.
//   Entry SHORT  EVENT: %K crosses BELOW %D  while BOTH are in the OB zone.
//   Exit  LONG   EVENT: %K crosses BELOW %D  while BOTH are in the OB zone.
//   Exit  SHORT  EVENT: %K crosses ABOVE %D  while BOTH are in the OS zone.
//
//   The %K/%D CROSS is the single trigger EVENT (evaluated from shift 2 -> shift 1).
//   Zone membership is a STATE checked on the same trigger bar — this is ONE cross
//   event combined with a state, NOT two independent cross events on one bar, so it
//   avoids the two-cross-same-bar zero-trade trap.
//
//   Stop : protective catastrophic stop = sl_atr_mult * ATR(atr_period). The
//          primary exit is the opposite zone/cross condition.
//   No fixed TP — the strategy is mean-reversion held to the opposite signal.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12523;
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
input int    strategy_stoch_k_period    = 14;    // %K lookback period (card baseline)
input int    strategy_stoch_d_period    = 3;     // %D smoothing (d_fast)
input int    strategy_stoch_slowing     = 3;     // final %K slowing (d_slow)
input double strategy_os_level          = 20.0;  // oversold zone threshold
input double strategy_ob_level          = 80.0;  // overbought zone threshold
input int    strategy_atr_period        = 14;    // ATR period for protective stop
input double strategy_sl_atr_mult       = 3.0;   // catastrophic stop = mult * ATR

// -----------------------------------------------------------------------------
// Helpers (closed-bar reads). Stoch %K/%D via QM_Stoch_* — never raw iStochastic.
// -----------------------------------------------------------------------------

// %K crosses ABOVE %D between the prior closed bar (shift 2) and the last closed
// bar (shift 1): a single fresh upward cross EVENT.
bool StochCrossUp()
  {
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d_now  = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || d_now <= 0.0 || k_prev <= 0.0 || d_prev <= 0.0)
      return false;
   return (k_prev <= d_prev && k_now > d_now);
  }

// %K crosses BELOW %D between shift 2 and shift 1: a single fresh downward cross.
bool StochCrossDown()
  {
   const double k_now  = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d_now  = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double k_prev = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   const double d_prev = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 2);
   if(k_now <= 0.0 || d_now <= 0.0 || k_prev <= 0.0 || d_prev <= 0.0)
      return false;
   return (k_prev >= d_prev && k_now < d_now);
  }

// Both %K and %D in the OVERSOLD zone on the last closed bar (STATE).
bool InOversoldZone()
  {
   const double k_now = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d_now = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(k_now <= 0.0 || d_now <= 0.0)
      return false;
   return (k_now <= strategy_os_level && d_now <= strategy_os_level);
  }

// Both %K and %D in the OVERBOUGHT zone on the last closed bar (STATE).
bool InOverboughtZone()
  {
   const double k_now = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   const double d_now = QM_Stoch_D(_Symbol, _Period, strategy_stoch_k_period, strategy_stoch_d_period, strategy_stoch_slowing, 1);
   if(k_now <= 0.0 || d_now <= 0.0)
      return false;
   return (k_now >= strategy_ob_level && d_now >= strategy_ob_level);
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No spread/session/regime gating beyond the framework defaults. Mean-reversion
// on D1 needs no intraday window. Cheap O(1) — returns false (do not block).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry: zone-cross reversal. Caller guarantees QM_IsNewBar() == true.
//   LONG  : %K crosses above %D while BOTH in the oversold zone.
//   SHORT : %K crosses below %D while BOTH in the overbought zone.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // LONG: oversold-zone state + upward cross event.
   if(InOversoldZone() && StochCrossUp())
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed TP; opposite zone-cross is the primary exit
      req.reason = "stoch_zone_cross_long";
      return true;
     }

   // SHORT: overbought-zone state + downward cross event.
   if(InOverboughtZone() && StochCrossDown())
     {
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
      req.reason = "stoch_zone_cross_short";
      return true;
     }

   return false;
  }

// No active trade management beyond the protective ATR stop. Exit is handled by
// the opposite zone-cross condition in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Opposite zone-cross exit:
//   Exit LONG  : %K crosses below %D while BOTH in the overbought zone.
//   Exit SHORT : %K crosses above %D while BOTH in the oversold zone.
// The framework closes only THIS magic's position(s) on a true return.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
     }

   if(is_long && InOverboughtZone() && StochCrossDown())
      return true;
   if(is_short && InOversoldZone() && StochCrossUp())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
