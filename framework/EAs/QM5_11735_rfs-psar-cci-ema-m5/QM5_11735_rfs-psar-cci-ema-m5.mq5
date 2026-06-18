#property strict
#property version   "5.0"
#property description "QM5_11735 rfs-psar-cci-ema-m5 — PSAR+CCI+EMA impulse scalper (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11735 rfs-psar-cci-ema-m5
// -----------------------------------------------------------------------------
// Source: Anonymous, "Scalping with use of Parabolic SAR + CCI", Robo-forex
//   Strategy Compilation (robofx.com), ~2015.
// Card: artifacts/cards_approved/QM5_11735_rfs-psar-cci-ema-m5.md (g0 APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; symmetric long/short):
//   Trend STATE (long) : EMA(slow=50) < close  AND  EMA(fast=21) > EMA(slow=50)
//                        AND  PSAR dot < close  (SAR in uptrend mode).
//   Trend STATE (short): EMA(slow=50) > close  AND  EMA(fast=21) < EMA(slow=50)
//                        AND  PSAR dot > close  (SAR in downtrend mode).
//   Trigger EVENT      : CCI(45) crosses the +100 / -100 threshold (ONE event):
//                        long  = CCI[2] <= +100 < CCI[1];
//                        short = CCI[2] >= -100 > CCI[1].
//                        The EMA stack + SAR side are STATES (currently above /
//                        below); the CCI band-cross is the single trigger EVENT,
//                        so the two-cross-same-bar zero-trade trap is avoided.
//   Stop loss          : at the EMA(slow) level (card: SL = EMA50), with a small
//                        per-point buffer below(long)/above(short).
//   Take profit        : symbol-specific fixed pip target, scale-correct via
//                        QM_StopRulesPipsToPriceDistance (default 10 pips; the
//                        per-symbol value is set in the .set file).
//   Defensive exit     : opposite PSAR side (SAR flips against the position).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11735;
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
input int    strategy_ema_fast_period   = 21;     // fast EMA (trend confirmation)
input int    strategy_ema_slow_period   = 50;     // slow EMA (bias + stop level)
input double strategy_sar_step          = 0.02;   // PSAR acceleration step
input double strategy_sar_max           = 0.2;    // PSAR acceleration maximum
input int    strategy_cci_period        = 45;     // CCI lookback period
input double strategy_cci_threshold     = 100.0;  // CCI band level (+/-)
input double strategy_tp_pips           = 10.0;   // symbol-specific fixed take-profit (pips)
input double strategy_sl_buffer_pts     = 1.0;    // SL buffer beyond EMA(slow), in points

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No cheap per-tick block needed; regime/signal work runs on the closed-bar
// entry path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate). One open
// position per symbol/magic.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar indicator reads (shift 1 = last closed bar) ---
   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double sar1 = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar1 <= 0.0)
      return false;

   // CCI band-cross EVENT: prev bar (shift 2) on one side, current closed bar
   // (shift 1) on the other side of +/- threshold.
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   const bool cci_cross_up   = (cci_prev <=  strategy_cci_threshold &&
                                cci_now  >   strategy_cci_threshold);
   const bool cci_cross_down = (cci_prev >= -strategy_cci_threshold &&
                                cci_now  <  -strategy_cci_threshold);

   // --- Long: bullish EMA stack STATE + price above slow EMA + SAR below price ---
   const bool long_state = (ema_slow < close1 && ema_fast > ema_slow && sar1 < close1);
   // --- Short: bearish EMA stack STATE + price below slow EMA + SAR above price ---
   const bool short_state = (ema_slow > close1 && ema_fast < ema_slow && sar1 > close1);

   QM_OrderType side;
   if(long_state && cci_cross_up)
      side = QM_BUY;
   else if(short_state && cci_cross_down)
      side = QM_SELL;
   else
      return false;

   // --- Entry price + stop (at EMA(slow) with a small buffer) + fixed-pip TP ---
   const double tp_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
   if(tp_distance <= 0.0)
      return false;
   const double buffer = strategy_sl_buffer_pts * _Point;

   if(side == QM_BUY)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, ema_slow - buffer);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_distance);
      if(!(sl < entry) || !(tp > entry))
         return false; // EMA above price → invalid long stop; skip
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "psar_cci_ema_long";
      return true;
     }
   else
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopRulesNormalizePrice(_Symbol, ema_slow + buffer);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_distance);
      if(!(sl > entry) || !(tp < entry))
         return false; // EMA below price → invalid short stop; skip
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "psar_cci_ema_short";
      return true;
     }
  }

// Fixed EMA-stop + fixed-pip TP; no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: PSAR flips against the open position (SAR side reverses).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double sar1   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar1 <= 0.0 || close1 <= 0.0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      // Long open but SAR now above price → uptrend ended → exit.
      if(ptype == POSITION_TYPE_BUY && sar1 > close1)
         return true;
      // Short open but SAR now below price → downtrend ended → exit.
      if(ptype == POSITION_TYPE_SELL && sar1 < close1)
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
