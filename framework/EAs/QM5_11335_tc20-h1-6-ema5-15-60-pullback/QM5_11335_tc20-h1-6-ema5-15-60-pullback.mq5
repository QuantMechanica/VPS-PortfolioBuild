#property strict
#property version   "5.0"
#property description "QM5_11335 TC20 H1 #6 — EMA(5/15/60) cascade + pullback-to-EMA60 (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11335 tc20-h1-6-ema5-15-60-pullback
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (1 Hour Time Frame)",
//         Strategy #6. Card: artifacts/cards_approved/
//         QM5_11335_tc20-h1-6-ema5-15-60-pullback.md (g0_status APPROVED).
//
// Mechanics (long + short mirror, closed-bar reads at shift 1):
//   Trend STATE (LONG):
//     - Cascade alignment  : EMA5 > EMA15 > EMA60   (full stack)
//     - Direction          : EMA60 rising (EMA60@1 > EMA60@2) AND
//                            EMA15 rising (EMA15@1 > EMA15@2)
//   Pullback-resume EVENT (LONG) — the SINGLE trigger, one per bar:
//     - Trigger bar (shift 1) wick TOUCHED EMA60 from above: Low@1 <= EMA60@1
//     - Close held above the slow EMA: Close@1 > EMA60@1
//     - It is a genuine pullback (not a hover): the PRIOR bar did not touch,
//       Low@2 > EMA60@2  (price was away, came down, tagged EMA60, resumed).
//   SHORT is the exact mirror (cascade inverted, EMA falling, High@1 >= EMA60@1,
//   Close@1 < EMA60@1, High@2 < EMA60@2).
//
// The cascade + rising/falling EMAs are STATES; the pullback-touch-and-resume
// is the ONE event. No two coincident crosses are required (avoids the
// .DWX zero-trade two-cross-same-bar trap).
//
//   Stop   : fixed 30 pips (card §Exit / §Stop Loss). P3 may sweep to ATR*1.5.
//   Take   : fixed 50 pips (card §Exit).
//   Spread : skip only a genuinely WIDE spread > cap pips (fail-open on the
//            .DWX zero modeled spread).
//   Exit   : SL/TP only — card specifies no discretionary/management exit.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11335;
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
input int    strategy_ema_fast_period   = 5;      // fast EMA (cascade top)
input int    strategy_ema_mid_period    = 15;     // middle EMA
input int    strategy_ema_slow_period   = 60;     // slow EMA (pullback target)
input int    strategy_sl_pips           = 30;     // fixed stop, pips (card §Exit/Stop)
input int    strategy_tp_pips           = 50;     // fixed target, pips (card §Exit)
input int    strategy_spread_cap_pips   = 20;     // skip only a genuinely wide spread

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — trend/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   if(strategy_spread_cap_pips <= 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double spread     = ask - bid;
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap <= 0.0)
      return false;

   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > spread_cap)
      return true;

   return false;
  }

// Long + short entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   if(strategy_ema_fast_period <= 0 || strategy_ema_mid_period <= 0 ||
      strategy_ema_slow_period <= 0 || strategy_sl_pips <= 0 || strategy_tp_pips <= 0)
      return false;

   // --- EMA STATE (closed bars). shift 1 = last closed bar, shift 2 = prior. ---
   const double ema5_1  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema15_1 = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  1);
   const double ema60_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema15_2 = QM_EMA(_Symbol, _Period, strategy_ema_mid_period,  2);
   const double ema60_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema5_1 <= 0.0 || ema15_1 <= 0.0 || ema60_1 <= 0.0 ||
      ema15_2 <= 0.0 || ema60_2 <= 0.0)
      return false;

   // Prior + trigger bar OHLC (single closed-bar reads — perf-allowed).
   const double low1  = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double close1 = iClose(_Symbol, _Period, 1);// perf-allowed: single closed-bar read
   const double low2  = iLow(_Symbol, _Period, 2);   // perf-allowed: single closed-bar read
   const double high2 = iHigh(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   if(low1 <= 0.0 || high1 <= 0.0 || close1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0)
      return false;

   // --- LONG ----------------------------------------------------------------
   // STATE: full cascade up + EMA60 & EMA15 rising.
   const bool long_cascade = (ema5_1 > ema15_1 && ema15_1 > ema60_1);
   const bool long_rising  = (ema60_1 > ema60_2 && ema15_1 > ema15_2);
   // EVENT (single, one per bar): trigger bar tagged EMA60 from above and
   // closed back above it, while the prior bar had NOT yet tagged it.
   const bool long_touch   = (low1 <= ema60_1 && close1 > ema60_1 && low2 > ema60_2);
   if(long_cascade && long_rising && long_touch)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl,
                                  (double)strategy_tp_pips / (double)strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_cascade_pullback_long";
      return true;
     }

   // --- SHORT (mirror) ------------------------------------------------------
   const bool short_cascade = (ema5_1 < ema15_1 && ema15_1 < ema60_1);
   const bool short_falling = (ema60_1 < ema60_2 && ema15_1 < ema15_2);
   const bool short_touch   = (high1 >= ema60_1 && close1 < ema60_1 && high2 < ema60_2);
   if(short_cascade && short_falling && short_touch)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, strategy_sl_pips);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry, sl,
                                  (double)strategy_tp_pips / (double)strategy_sl_pips);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema_cascade_pullback_short";
      return true;
     }

   return false;
  }

// Fixed SL/TP only — card specifies no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — exits are the fixed 30-pip SL / 50-pip TP.
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
