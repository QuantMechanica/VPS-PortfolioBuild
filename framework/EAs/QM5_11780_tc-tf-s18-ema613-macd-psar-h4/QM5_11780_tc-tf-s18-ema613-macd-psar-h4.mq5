#property strict
#property version   "5.0"
#property description "QM5_11780 tc-tf-s18-ema613-macd-psar-h4 — EMA6/13 cross + MACD + PSAR confluence (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11780 tc-tf-s18-ema613-macd-psar-h4
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems" (Strategy #18), self-published 2014, pp.43-44.
// Card: artifacts/cards_approved/QM5_11780_tc-tf-s18-ema613-macd-psar-h4.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Trigger EVENT : EMA(6) crosses EMA(13) on the just-closed bar. This is the
//                   SINGLE trigger (fast vs slow at shift 1 vs shift 2). MACD
//                   side and PSAR side are confirming STATES, so we never demand
//                   two fresh cross events on one bar (the zero-trade trap).
//   MACD STATE    : LONG needs MACD main > 0 ; SHORT needs MACD main < 0.
//   PSAR STATE    : LONG needs PSAR below price (dot under the closed bar's low);
//                   SHORT needs PSAR above price (dot over the closed bar's high).
//   Exit          : EMA(6) crosses back the opposite way, OR PSAR flips to the
//                   wrong side — whichever comes first (card "Exit" section).
//   Stop          : 2 x ATR(14) on H4 (card factory default).
//   Take profit   : 4 x ATR(14) on H4 => RR 2.0 of the ATR stop.
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11780;
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
input int    strategy_ema_fast_period   = 6;      // fast EMA (cross trigger)
input int    strategy_ema_slow_period   = 13;     // slow EMA (cross trigger)
input int    strategy_macd_fast         = 12;     // MACD fast EMA
input int    strategy_macd_slow         = 26;     // MACD slow EMA
input int    strategy_macd_signal       = 9;      // MACD signal EMA
input double strategy_sar_step          = 0.02;   // ParabolicSAR acceleration step
input double strategy_sar_max           = 0.2;    // ParabolicSAR acceleration max
input int    strategy_atr_period        = 14;     // ATR period for SL/TP
input double strategy_atr_sl_mult       = 2.0;    // SL = 2 x ATR (card default)
input double strategy_atr_tp_mult       = 4.0;    // TP = 4 x ATR (card default => RR 2.0)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   const double stop_distance = strategy_atr_sl_mult * atr;
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

   // --- Trigger EVENT: EMA(6) crosses EMA(13) on the just-closed bar ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);
   if(!cross_up && !cross_down)
      return false;

   // --- Confirming STATE: MACD main side ---
   const double macd = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);

   // --- Confirming STATE: PSAR side relative to the closed bar's range ---
   const double sar   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   const bool long_ok  = (cross_up   && macd > 0.0 && sar < low1);
   const bool short_ok = (cross_down && macd < 0.0 && sar > high1);
   if(!long_ok && !short_ok)
      return false;

   const QM_OrderType side = long_ok ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   // Stop = 2 x ATR(14); Take = 4 x ATR(14) (card factory default).
   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_tp_mult);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_ok ? "carter_s18_ema_macd_psar_long" : "carter_s18_ema_macd_psar_short";
   return true;
  }

// Fixed ATR SL/TP only — no active in-trade SL trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: close when EMA(6) crosses back the opposite way OR PSAR
// flips to the wrong side of price — whichever comes first (card Exit section).
// Closed-bar reads at shift 1/2; evaluated once per bar via the OnTick new-bar
// gate that fronts the manual-exit path.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open side for this magic.
   bool is_long = false;
   bool found   = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      is_long = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      found   = true;
      break;
     }
   if(!found)
      return false;

   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0)
      return false;

   const double sar   = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   if(is_long)
     {
      const bool ema_reverse = (ema_fast_1 < ema_slow_1); // EMA crossed back down
      const bool psar_flip   = (sar > high1);             // PSAR now above price
      return (ema_reverse || psar_flip);
     }
   else
     {
      const bool ema_reverse = (ema_fast_1 > ema_slow_1); // EMA crossed back up
      const bool psar_flip   = (sar < low1);              // PSAR now below price
      return (ema_reverse || psar_flip);
     }
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

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Per-closed-bar discretionary exit (EMA reverse cross OR PSAR flip).
   if(Strategy_ExitSignal())
     {
      const int magic = QM_FrameworkMagic();
      for(int i = PositionsTotal() - 1; i >= 0; --i)
        {
         const ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket))
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
