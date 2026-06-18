#property strict
#property version   "5.0"
#property description "QM5_11372 micro-trading-bb18-ema3-macd-m1 — BB(18,EMA) midline + EMA(3) cross + MACD/RSI states (M1 scalp)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11372 micro-trading-bb18-ema3-macd-m1
// -----------------------------------------------------------------------------
// Source: "9 Forex Systems" — Micro Trading the 1 Minute Chart (DayTradeForex.com).
// Card: artifacts/cards_approved/QM5_11372_micro-trading-bb18-ema3-macd-m1.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1, M1 scalp):
//   Trigger EVENT : EMA(3) crosses the BB(18,EMA) middle band (basis = EMA18).
//                   LONG  = EMA3 was <= midline at shift 2, now > midline at shift 1.
//                   SHORT = mirror. ONE fresh cross event per bar (the NOTE: EMA3 vs
//                   BB-midline cross is the single EVENT; MACD/RSI are STATES).
//   MACD STATE    : MACD main(12,26,9) > 0 for long / < 0 for short. MACD may be
//                   negative — this is a SIGN read, never a reject-on-nonpositive gate.
//   RSI STATE     : RSI(14) > 50 for long / < 50 for short (momentum confirmation).
//   Stop          : fixed pips (default 8), scale-correct via pip helper.
//   Take profit   : fixed pips (default 10), scale-correct via pip helper.
//   Defensive exit: EMA(3) closes back across the BB midline against the position.
//   Session       : trade only London/NY active hours (broker time); skip the
//                   Asian dead zone (22:00-07:00 broker). Card states broker time.
//   Spread guard  : block only a genuinely wide spread (fail-OPEN on .DWX zero
//                   modeled spread — ask==bid in the tester is NOT blocked).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11372;
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
input int    strategy_bb_period          = 18;    // Bollinger basis period (EMA-based)
input double strategy_bb_deviation       = 2.0;   // BB deviation (mandatory arg; midline = basis)
input int    strategy_ema_fast_period    = 3;     // fast EMA crossing the BB midline
input int    strategy_macd_fast          = 12;    // MACD fast EMA
input int    strategy_macd_slow          = 26;    // MACD slow EMA
input int    strategy_macd_signal        = 9;     // MACD signal EMA
input int    strategy_rsi_period         = 14;    // RSI period
input double strategy_rsi_mid            = 50.0;  // RSI momentum midline
input double strategy_tp_pips            = 10.0;  // fixed take-profit (pips)
input double strategy_sl_pips            = 8.0;   // fixed stop-loss (pips)
input int    strategy_session_start_hour = 7;     // first active broker hour (London open ~07)
input int    strategy_session_end_hour   = 22;    // first dead broker hour (Asian dead zone start)
input double strategy_spread_cap_pips    = 8.0;   // skip only genuinely wide spread (fail-open on 0)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + spread guard.
// Fail-OPEN on .DWX zero modeled spread (ask==bid must NOT block).
bool Strategy_NoTradeFilter()
  {
   // --- Session filter (broker time). Active window [start, end); the card's
   //     22:00-07:00 Asian dead zone is excluded. Hours are already broker-time
   //     per the card ("London open 07:00 or NY open 13:00 broker time"). ---
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   const int hour = dt.hour;
   bool in_session;
   if(strategy_session_start_hour <= strategy_session_end_hour)
      in_session = (hour >= strategy_session_start_hour && hour < strategy_session_end_hour);
   else // wrap-around window
      in_session = (hour >= strategy_session_start_hour || hour < strategy_session_end_hour);
   if(!in_session)
      return true; // outside active session — block

   // --- Spread guard (fail-OPEN). Only a genuinely wide spread blocks. ---
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   if(cap > 0.0 && ask > bid && (ask - bid) > cap)
      return true; // genuinely wide spread — block

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
// EVENT = EMA3 crossing the BB(18) midline; MACD sign + RSI vs 50 are STATES.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Closed-bar reads (shift 1 = last closed bar, shift 2 = prior). ---
   const double ema_now  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(ema_now <= 0.0 || ema_prev <= 0.0 || mid_now <= 0.0 || mid_prev <= 0.0)
      return false;

   // --- Trigger EVENT: EMA3 fresh cross of the BB midline (one event/bar). ---
   const bool cross_up   = (ema_prev <= mid_prev && ema_now > mid_now);
   const bool cross_down = (ema_prev >= mid_prev && ema_now < mid_now);
   if(!cross_up && !cross_down)
      return false;

   // --- STATE confirmations: MACD main sign + RSI vs midline. MACD CAN be
   //     negative — this is a sign read only, never a reject-on-nonpositive. ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const double rsi_val   = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_val <= 0.0)
      return false;

   const double entry = (cross_up ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID));
   if(entry <= 0.0)
      return false;

   if(cross_up)
     {
      if(!(macd_main > 0.0))            return false; // MACD positive state
      if(!(rsi_val > strategy_rsi_mid)) return false; // RSI momentum positive
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
      const double tp = QM_StopRulesNormalizePrice(_Symbol, entry +
                        QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips));
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "micro_bb_ema_macd_long";
      return true;
     }

   // cross_down -> SHORT
   if(!(macd_main < 0.0))            return false; // MACD negative state
   if(!(rsi_val < strategy_rsi_mid)) return false; // RSI momentum negative
   const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
   const double tp = QM_StopRulesNormalizePrice(_Symbol, entry -
                     QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips));
   if(sl <= 0.0 || tp <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "micro_bb_ema_macd_short";
   return true;
  }

// No active trade management beyond the fixed pip stop/target.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: EMA(3) closes back across the BB midline against the open
// position (long exits on EMA3 below midline; short exits on EMA3 above).
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ema_now = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double mid_now = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   if(ema_now <= 0.0 || mid_now <= 0.0)
      return false;

   // Determine current direction from the open position.
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found = true;
      break;
     }
   if(!found)
      return false;

   if(is_long)
      return (ema_now < mid_now);  // EMA3 fell back below midline
   return (ema_now > mid_now);     // short: EMA3 rose back above midline
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
