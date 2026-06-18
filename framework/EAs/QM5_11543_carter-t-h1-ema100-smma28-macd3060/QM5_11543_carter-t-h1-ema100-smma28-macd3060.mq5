#property strict
#property version   "5.0"
#property description "QM5_11543 carter-t-h1-ema100-smma28-macd3060 — SMMA(28)/EMA(100) cross + MACD(30,60,30) sign confirm (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11543 carter-t-h1-ema100-smma28-macd3060
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         System #17, self-published 2014 (R1 CONDITIONAL).
// Card: artifacts/cards_approved/QM5_11543_carter-t-h1-ema100-smma28-macd3060.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trigger EVENT : SMMA(28) crosses EMA(100). ONE fresh cross per bar.
//                     up   -> SMMA(28) crosses ABOVE EMA(100)  => LONG candidate
//                     down -> SMMA(28) crosses BELOW EMA(100)  => SHORT candidate
//   Confirm STATE : MACD(30,60,30) MAIN line sign (NOT a second cross — avoids
//                     the two-cross-same-bar zero-trade trap):
//                     LONG  requires macd_main > 0
//                     SHORT requires macd_main < 0
//   Stop          : fixed sl_pips (50) from entry (scale-correct via QM_StopFixedPips).
//   Take profit   : tp_pips (85) from entry, expressed as RR = tp_pips/sl_pips so
//                     the distance is exactly the card's 85 pips off the 50-pip stop.
//   No-trade      : optional "no Friday entry" gate (broker time) + wide-spread guard
//                     (fail-OPEN on .DWX zero modeled spread).
//   One position per symbol/magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11543;
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
input int    strategy_smma_period       = 28;     // smoothed MA (trigger leg) period
input int    strategy_ema_period        = 100;    // EMA (trigger leg) period
input int    strategy_macd_fast         = 30;     // MACD fast EMA period
input int    strategy_macd_slow         = 60;     // MACD slow EMA period
input int    strategy_macd_signal       = 30;     // MACD signal EMA period
input int    strategy_sl_pips           = 50;     // stop distance in pips
input int    strategy_tp_pips           = 85;     // take-profit distance in pips (P2 midpoint of 70-100)
input bool   strategy_no_friday_entry   = true;   // skip new entries on Friday (broker time)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Returns TRUE to BLOCK trading this tick.
//   - Optional "no Friday entry" (broker time).
//   - Wide-spread guard, fail-OPEN on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // No new entries on Friday (broker time). Mon=1..Sun=0 in MqlDateTime.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return true;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Stop distance reference for the spread cap (scale-correct pip distance).
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

   // --- Trigger EVENT: SMMA(28) crosses EMA(100) (closed bars 1 vs 2) ---
   const double smma_now  = QM_SMMA(_Symbol, _Period, strategy_smma_period, 1);
   const double smma_prev = QM_SMMA(_Symbol, _Period, strategy_smma_period, 2);
   const double ema_now   = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   const double ema_prev  = QM_EMA(_Symbol, _Period, strategy_ema_period, 2);
   if(smma_now <= 0.0 || smma_prev <= 0.0 || ema_now <= 0.0 || ema_prev <= 0.0)
      return false;

   const bool crossed_up   = (smma_prev <= ema_prev && smma_now >  ema_now);
   const bool crossed_down = (smma_prev >= ema_prev && smma_now <  ema_now);
   if(!crossed_up && !crossed_down)
      return false;

   // --- Confirm STATE: MACD(30,60,30) main-line sign (NOT a second cross) ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast,
                                         strategy_macd_slow,
                                         strategy_macd_signal, 1);

   QM_OrderType side;
   if(crossed_up && macd_main > 0.0)
      side = QM_BUY;
   else if(crossed_down && macd_main < 0.0)
      side = QM_SELL;
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;

   // TP at tp_pips: express as RR off the realised sl distance so the TP is
   // exactly tp_pips from entry given the sl_pips stop.
   if(strategy_sl_pips <= 0)
      return false;
   const double rr = (double)strategy_tp_pips / (double)strategy_sl_pips;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (side == QM_BUY) ? "smma_ema_cross_up_macd_pos"
                                 : "smma_ema_cross_dn_macd_neg";
   return true;
  }

// Fixed-pip SL/TP only; no active management.
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
