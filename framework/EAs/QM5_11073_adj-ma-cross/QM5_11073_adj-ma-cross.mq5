#property strict
#property version   "5.0"
#property description "QM5_11073 adj-ma-cross — EarnForex Adjustable MA Cross (EMA fast/slow cross, close-and-reverse, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11073 adj-ma-cross
// -----------------------------------------------------------------------------
// Source: EarnForex "Adjustable MA" (https://github.com/EarnForex/Adjustable-MA).
// Card: artifacts/cards_approved/QM5_11073_adj-ma-cross.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; TradeDirection BOTH):
//   Fast EMA(Period_1=20, PRICE_CLOSE), Slow EMA(Period_2=22, PRICE_CLOSE).
//   Trigger EVENT (entry):
//     LONG  : fast EMA crosses ABOVE slow EMA (bullish cross)  AND
//             (fastMA - slowMA) >= MinDiff price-distance.
//     SHORT : fast EMA crosses BELOW slow EMA (bearish cross)  AND
//             (slowMA - fastMA) >= MinDiff price-distance.
//   Close-and-reverse: the opposite cross is the primary EXIT. The framework
//     runs Strategy_ExitSignal (closes the open position on an opposite cross)
//     BEFORE Strategy_EntrySignal in the same OnTick, so a single new cross both
//     closes the old side and opens the new one (reverse).
//   Catastrophic stop: entry -/+ ATR(atr_period) * atr_mult  (bounded testing
//     hard stop; source defaults SL/TP/trailing to 0 — we add a hard ATR stop).
//   No take-profit: exit is by signal reversal (source TakeProfit = 0).
//
// .DWX invariants honoured:
//   - The MA cross is ONE event (QM_Sig_MA_Cross); MinDiff is a STATE confirm on
//     the same closed bar — no two-cross-same-bar zero-trade trap.
//   - MinDiff is a per-symbol price threshold (MinDiff * SYMBOL_POINT), faithful
//     to the source; on .DWX it is a tiny near-zero noise filter on the cross.
//   - No spread/swap gate (fail-open); D1 close-based logic, no gap rule.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11073;
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
input int    strategy_ema_fast_period   = 20;     // Period_1 — fast EMA (source default 20)
input int    strategy_ema_slow_period   = 22;     // Period_2 — slow EMA (source default 22)
input int    strategy_min_diff_points   = 3;      // MinDiff: min fast/slow separation, in points (source default 3 * _Point)
input int    strategy_atr_period        = 20;     // catastrophic ATR stop period
input double strategy_atr_mult          = 3.0;    // catastrophic ATR stop multiple (entry +/- mult*ATR)

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// No per-tick filter. Source baseline trades the full week/day window; spread is
// fail-open on .DWX (zero modeled spread) so no spread gate. O(1).
bool Strategy_NoTradeFilter()
  {
   return false;
  }

// Close-and-reverse entry. Caller guarantees QM_IsNewBar() == true (closed bar).
// The opposite-side close (if any) already ran in Strategy_ExitSignal this tick.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic. After a reversal, ExitSignal has closed
   // the opposite side earlier in this same OnTick, so count is 0 here.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema_fast = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   if(ema_fast <= 0.0 || ema_slow <= 0.0)
      return false;

   // MinDiff as a price distance, faithful to the source (MinDiff * _Point).
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;
   const double min_diff = strategy_min_diff_points * point;

   // Trigger EVENT: fresh cross on the last closed bar.
   const int cross = QM_Sig_MA_Cross(_Symbol, _Period,
                                     strategy_ema_fast_period, strategy_ema_slow_period, 1);

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   if(cross > 0)
     {
      // Bullish cross + MinDiff separation confirm (STATE on the closed bar).
      if((ema_fast - ema_slow) < min_diff)
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no TP — exit by signal reversal
      req.reason = "adj_ma_cross_long";
      return true;
     }

   if(cross < 0)
     {
      // Bearish cross + MinDiff separation confirm.
      if((ema_slow - ema_fast) < min_diff)
         return false;
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "adj_ma_cross_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed catastrophic ATR stop. Reversal exit
// lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Primary exit = signal reversal. Close the open position when the fast EMA
// crosses to the OPPOSITE side of the slow EMA (one event at shift 1). The
// MinDiff confirm is NOT applied to the exit — any opposite cross flattens, then
// EntrySignal decides whether to re-open with the MinDiff threshold.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const int cross = QM_Sig_MA_Cross(_Symbol, _Period,
                                     strategy_ema_fast_period, strategy_ema_slow_period, 1);
   if(cross == 0)
      return false;

   // Determine current position side; close only on an OPPOSITE cross.
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross < 0)
         return true;   // long open, bearish cross -> close
      if(ptype == POSITION_TYPE_SELL && cross > 0)
         return true;   // short open, bullish cross -> close
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
