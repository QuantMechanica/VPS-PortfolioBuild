#property strict
#property version   "5.0"
#property description "QM5_11485 carter-t-cci100-macd-momentum-m5 — CCI(100) breakout + MACD momentum confirmation (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11485 carter-t-cci100-macd-momentum-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//         System #13 (2014). Card g0_status APPROVED.
// Card: artifacts/cards_approved/QM5_11485_carter-t-cci100-macd-momentum-m5.md
//
// Concept (momentum BREAKOUT, not fade): CCI crossing INTO the +/-100 zone marks
// the start of a strong directional phase; MACD momentum confirms it.
//
// Mechanics (closed-bar reads, shift 1 = last closed bar):
//   Trigger EVENT (ONE per bar):
//     LONG : CCI crosses up through +cci_level   (cci@2 <= +L  &&  cci@1 >  +L)
//     SHORT: CCI crosses down through -cci_level  (cci@2 >= -L  &&  cci@1 < -L)
//   Confirming STATE (read at the same closed bar — NOT a second cross, so we
//   never require two cross EVENTS on one bar):
//     LONG : MACD main > signal  AND  MACD main rising   (main@1 > main@2)
//     SHORT: MACD main < signal  AND  MACD main falling  (main@1 < main@2)
//   Stop  : fixed pips (scale-correct via QM_StopFixedPips).
//   Take  : RR multiple of the stop distance (QM_TakeRR).
//   No-Friday-entry filter (card "No Friday entry").
//   Spread guard: only a genuinely wide spread blocks (fail-open on .DWX zero
//                 modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11485;
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
input int    strategy_cci_period        = 14;     // CCI period (Carter: 14)
input double strategy_cci_level         = 100.0;  // +/- breakout threshold (Carter: 100)
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal SMA
input int    strategy_sl_pips           = 15;     // stop distance in pips (P2 cap)
input double strategy_tp_rr             = 0.667;  // take = RR * stop (10/15 pips ~= 0.667R)
input bool   strategy_no_friday_entry   = true;   // card: no Friday entry
input double strategy_spread_pct_of_stop = 25.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — entry logic is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
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

   // No-Friday-entry filter (card).
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5) // Friday
         return false;
     }

   // --- CCI trigger EVENT (one fresh cross per bar) ---
   const double cci_now  = QM_CCI(_Symbol, _Period, strategy_cci_period, 1);
   const double cci_prev = QM_CCI(_Symbol, _Period, strategy_cci_period, 2);

   const bool cross_up   = (cci_prev <=  strategy_cci_level && cci_now >  strategy_cci_level);
   const bool cross_down = (cci_prev >= -strategy_cci_level && cci_now < -strategy_cci_level);
   if(!cross_up && !cross_down)
      return false;

   // --- MACD confirming STATE at the same closed bar (not a second cross) ---
   const double macd_main_now  = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_prev = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                              strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_signal_now = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                                 strategy_macd_slow, strategy_macd_signal, 1);

   QM_OrderType dir;
   if(cross_up)
     {
      // LONG: MACD main above signal AND momentum rising.
      if(!(macd_main_now > macd_signal_now && macd_main_now > macd_main_prev))
         return false;
      dir = QM_BUY;
     }
   else
     {
      // SHORT: MACD main below signal AND momentum falling.
      if(!(macd_main_now < macd_signal_now && macd_main_now < macd_main_prev))
         return false;
      dir = QM_SELL;
     }

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "cci100_macd_long" : "cci100_macd_short";
   return true;
  }

// Fixed-stop / fixed-target strategy: no active management beyond SL/TP.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — SL/TP carry the trade.
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
