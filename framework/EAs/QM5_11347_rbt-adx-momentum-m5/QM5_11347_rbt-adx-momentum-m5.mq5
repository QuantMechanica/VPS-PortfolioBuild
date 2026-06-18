#property strict
#property version   "5.0"
#property description "QM5_11347 rbt-adx-momentum-m5 — RoboForex ADX + Momentum M5 scalp"

#include <QM/QM_Common.mqh>
#include <QM/QM_Signals.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11347 rbt-adx-momentum-m5
// -----------------------------------------------------------------------------
// Source: RoboForex "Strategy ADX and Momentum" (institutional, R1 CONDITIONAL).
// Card: artifacts/cards_approved/QM5_11347_rbt-adx-momentum-m5.md (g0_status APPROVED).
//
// Mechanics (M5, closed-bar reads at shift 1; one position per magic):
//   Trigger EVENT : Momentum(period) crosses the 100 baseline (one event/bar).
//                   LONG  = Momentum crosses UP through 100 (mom@2<=100, mom@1>100).
//                   SHORT = Momentum crosses DOWN through 100 (mom@2>=100, mom@1<100).
//   Trend STATE   : ADX(period) > adx_threshold (strong trend present).
//   Direction STATE: +DI > -DI for LONG  /  -DI > +DI for SHORT  (closed bar).
//   Macro STATE   : optional EMA(ema_period) gate — price above EMA for LONG,
//                   below for SHORT (input ema_filter, default OFF per card).
//   Session STATE : trade only inside London+NY (default UTC 13:00-22:00, card
//                   "GMT"). Window evaluated in UTC via QM_BrokerToUTC so the
//                   broker DST offset (GMT+2/+3) cannot drift it into dead hours.
//   Stop          : fixed sl_pips from entry (scale-correct via pip factor).
//   Take profit   : fixed tp_pips from entry, expressed as an RR multiple of the
//                   stop distance so it stays scale-correct on 5-digit / JPY.
//
// DWX-correctness notes:
//   - Momentum CROSS is the single EVENT; ADX/DI/EMA are confirming STATES, so we
//     never require two fresh crosses on the same bar (zero-trade trap, inv #4).
//   - Spread guard fails OPEN on .DWX zero modeled spread (inv #1): only a
//     genuinely wide spread > spread_cap_pips blocks.
//   - No swap gate (inv #2). No external-macro CSV (inv #11). Pip-scaled
//     SL/TP via the framework pip-factor helpers (inv #14).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11347;
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
input int    strategy_adx_period        = 14;     // ADX + DI period
input double strategy_adx_threshold     = 25.0;   // ADX strong-trend floor
input int    strategy_mom_period        = 14;     // Momentum period
input double strategy_mom_baseline      = 100.0;  // Momentum cross baseline
input bool   strategy_ema_filter        = false;  // optional EMA macro gate (card: optional)
input int    strategy_ema_period        = 55;     // EMA period for the macro gate
input int    strategy_sl_pips           = 6;      // fixed stop, pips (card 5-7 midpoint)
input int    strategy_tp_pips           = 15;     // fixed target, pips (card 14-16 midpoint)
input int    strategy_session_start_utc = 13;     // London+NY window start (UTC/GMT)
input int    strategy_session_end_utc   = 22;     // London+NY window end (UTC/GMT)
input double strategy_spread_cap_pips   = 3.0;    // skip genuinely wide spread (card cap)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Session/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero/negative modeled spread on .DWX — never block

   // Convert the pip cap to a price distance so it scales on 5-digit / JPY.
   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   // Only a genuinely wide spread blocks.
   if(spread > cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Session STATE: London+NY only, evaluated in UTC (card "GMT"). ---
   const datetime broker_now = TimeCurrent();
   const datetime utc_now    = QM_BrokerToUTC(broker_now);
   if(QM_Sig_Session(utc_now, strategy_session_start_utc, strategy_session_end_utc) != 1)
      return false;

   // --- Trend STATE: ADX above the strong-trend threshold (closed bar). ---
   const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
   if(adx <= 0.0)
      return false;
   if(!(adx > strategy_adx_threshold))
      return false;

   // --- Direction STATE: +DI vs -DI (closed bar). ---
   const double plus_di  = QM_ADX_PlusDI(_Symbol, _Period, strategy_adx_period, 1);
   const double minus_di = QM_ADX_MinusDI(_Symbol, _Period, strategy_adx_period, 1);
   if(plus_di <= 0.0 || minus_di <= 0.0)
      return false;

   // --- Trigger EVENT: Momentum crosses the baseline (one fresh event/bar). ---
   const double mom_now  = QM_Momentum(_Symbol, _Period, strategy_mom_period, 1);
   const double mom_prev = QM_Momentum(_Symbol, _Period, strategy_mom_period, 2);
   if(mom_now <= 0.0 || mom_prev <= 0.0)
      return false;

   const bool mom_cross_up   = (mom_prev <= strategy_mom_baseline && mom_now > strategy_mom_baseline);
   const bool mom_cross_down = (mom_prev >= strategy_mom_baseline && mom_now < strategy_mom_baseline);

   // --- Optional macro STATE: price vs EMA (closed bar). ---
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   double ema = 0.0;
   if(strategy_ema_filter)
     {
      ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
      if(ema <= 0.0)
         return false;
     }

   bool go_long  = false;
   bool go_short = false;

   // LONG: momentum crosses up + strong trend + +DI dominance (+ optional EMA).
   if(mom_cross_up && (plus_di > minus_di))
     {
      if(!strategy_ema_filter || close1 > ema)
         go_long = true;
     }
   // SHORT: momentum crosses down + strong trend + -DI dominance (+ optional EMA).
   else if(mom_cross_down && (minus_di > plus_di))
     {
      if(!strategy_ema_filter || close1 < ema)
         go_short = true;
     }

   if(!go_long && !go_short)
      return false;

   const QM_OrderType side = go_long ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY)
                        ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Fixed-pip stop; fixed-pip target expressed as an RR multiple of the stop
   // distance so both stay scale-correct on 5-digit / JPY symbols.
   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double rr = (strategy_sl_pips > 0)
                     ? ((double)strategy_tp_pips / (double)strategy_sl_pips)
                     : 0.0;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = go_long ? "adx_mom_long" : "adx_mom_short";
   return true;
  }

// Fixed SL/TP only — no active trade management for this scalp.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP.
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
