#property strict
#property version   "5.0"
#property description "QM5_11361 robo-bb-macd-ma-m15 — RoboForex BB(20,2)+SMA(2) cross + MACD(11,27,4) (M15)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11361 robo-bb-macd-ma-m15
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection, "Strategy based on BB, MACD, MA
//         indicators" (pages 26-27). Card:
//         artifacts/cards_approved/QM5_11361_robo-bb-macd-ma-m15.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M15):
//   EVENT  (trigger) : fast SMA(2) crosses the BB(20,2) middle band (= SMA20).
//                      Cross UP  -> long candidate; cross DOWN -> short candidate.
//                      Exactly ONE fresh cross event per bar (shift 2 vs 1).
//   STATE  (filter)  : MACD(11,27,4) main line sign. RoboForex uses the
//                      counter-intuitive recovery reading:
//                        LONG  requires MACD main  <  0  (rising from negative).
//                        SHORT requires MACD main  >  0  (falling from positive).
//                      MACD main can be negative — the readers return a signed
//                      double; never gate on a wide-spread / swap proxy.
//   Stop / Target    : fixed pips (pip-scaled, 5-digit / JPY safe via
//                      QM_StopFixedPips / QM_TakeFixedPips). SL 13 pips, TP 12.
//   One position per symbol/magic. No active trade management; SL/TP only.
//
// .DWX invariants honoured:
//   - Spread guard fails OPEN on zero modeled spread (only a genuinely wide
//     spread blocks; ask<=0/bid<=0 do not block).
//   - No swap gate. No external-macro CSV. Broker-time not needed (no session
//     window: the card has none beyond the M15 cadence + a spread cap).
//   - QM_IsNewBar consumed exactly once on the framework entry path.
//   - ONE event (the SMA/BB cross) is the trigger; MACD sign is a STATE, so the
//     two conditions do not need to co-occur as fresh events on the same bar.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11361;
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
input int    strategy_bb_period          = 20;    // Bollinger period (middle = SMA20)
input double strategy_bb_deviation       = 2.0;   // Bollinger deviation (mandatory arg)
input int    strategy_sma_period         = 2;     // fast SMA crossing the BB middle
input int    strategy_macd_fast          = 11;    // MACD fast EMA
input int    strategy_macd_slow          = 27;    // MACD slow EMA
input int    strategy_macd_signal        = 4;     // MACD signal EMA
input int    strategy_sl_pips            = 13;    // fixed stop-loss (pips)
input int    strategy_tp_pips            = 12;    // fixed take-profit (pips)
input double strategy_spread_cap_pips    = 5.0;   // skip only a genuinely wide spread (pips)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-OPEN on .DWX zero spread:
// a zero/negative modeled spread never blocks; only a real spread above the cap.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread = ask - bid;
   if(spread <= 0.0)
      return false; // zero modeled spread (.DWX) — fail OPEN

   const double cap_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap_distance <= 0.0)
      return false;

   // Only a genuinely wide spread blocks.
   if(spread > cap_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
//   EVENT : SMA(2) crosses the BB middle band (one fresh cross per bar).
//   STATE : MACD(11,27,4) main sign (long: <0, short: >0).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // BB middle (= SMA(bb_period)) at the last two closed bars.
   const double bb_mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double bb_mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(bb_mid_now <= 0.0 || bb_mid_prev <= 0.0)
      return false;

   // Fast SMA at the same two closed bars.
   const double sma_now  = QM_SMA(_Symbol, _Period, strategy_sma_period, 1);
   const double sma_prev = QM_SMA(_Symbol, _Period, strategy_sma_period, 2);
   if(sma_now <= 0.0 || sma_prev <= 0.0)
      return false;

   // EVENT: one fresh cross of the BB middle band by the fast SMA.
   const bool crossed_up   = (sma_prev <  bb_mid_prev && sma_now >= bb_mid_now);
   const bool crossed_down = (sma_prev >  bb_mid_prev && sma_now <= bb_mid_now);
   if(!crossed_up && !crossed_down)
      return false;

   // STATE: MACD main sign at the last closed bar. MACD main can be negative.
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);

   QM_OrderType side;
   if(crossed_up)
     {
      // LONG: cross up + MACD main below zero (recovery from negative).
      if(!(macd_main < 0.0))
         return false;
      side = QM_BUY;
     }
   else
     {
      // SHORT: cross down + MACD main above zero (falling from positive).
      if(!(macd_main > 0.0))
         return false;
      side = QM_SELL;
     }

   // Entry reference price + fixed-pip stop/target (pip-scaled, 5-digit/JPY safe).
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   const double tp = QM_TakeFixedPips(_Symbol, side, entry, strategy_tp_pips);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "robo_bb_macd_long" : "robo_bb_macd_short";
   return true;
  }

// Fixed SL/TP only — no active trade management.
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
