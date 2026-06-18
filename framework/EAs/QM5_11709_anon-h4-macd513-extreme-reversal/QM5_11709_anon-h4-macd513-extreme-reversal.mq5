#property strict
#property version   "5.0"
#property description "QM5_11709 anon-h4-macd513-extreme-reversal — MACD(5,13,1) extreme reversal fade (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11709 anon-h4-macd513-extreme-reversal
// -----------------------------------------------------------------------------
// Source: Anonymous, "4 Hour MACD Forex Strategy", self-published PDF (136212376).
// Card: artifacts/cards_approved/QM5_11709_anon-h4-macd513-extreme-reversal.md
//       (g0_status APPROVED).
//
// Mechanics (counter-trend fade, closed-bar reads at shift 1, H4):
//   MACD(5,13,1): with signal period = 1 the Main buffer is effectively the raw
//   MACD line ("histogram" in the card). When MACD reaches an extreme (beyond
//   +/- macd_extreme_level) and then turns back TOWARD zero, momentum is judged
//   exhausted and we FADE it.
//
//   Trigger EVENT (short — overbought reversal):
//     MACD@2 > +level  AND  MACD@1 <= +level  AND  MACD@1 < MACD@2
//     (it WAS extreme on the bar before last; on the last closed bar it has
//      dropped back through the level and is declining = the turn).
//   Trigger EVENT (long — oversold reversal):
//     MACD@2 < -level  AND  MACD@1 >= -level  AND  MACD@1 > MACD@2
//
//   The extreme-and-turn is ONE event read from two adjacent closed bars
//   (shift 2 vs shift 1) — NOT two crosses on the same bar (avoids the
//   two-cross zero-trade trap).
//
//   Optional STATE filter (slow-MA context, default ON): prefer short only when
//   price is below the slow SMA stack, long only when above. State, never a
//   second event.
//
//   Stop  : fixed macd_sl_pips from entry (card: 30 pips), scale-correct via
//           QM_StopFixedPips.
//   Target: RR multiple of the stop distance (card factory default 2x SL),
//           via QM_TakeRR — a single staggered-free exit.
//   Spread guard: skip only a genuinely wide spread (fail-open on .DWX zero
//           modeled spread).
//
//   Level scaling: macd_extreme_level is calibrated for EURUSD 5-digit quotes.
//   For other 5-digit pairs (GBPUSD) the factor is 1.0; for differently-scaled
//   symbols it is rescaled by (_Point / 0.00001) so the threshold stays
//   meaningful. JPY/index symbols are out of this card's universe.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11709;
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
input int    strategy_macd_fast        = 5;       // MACD fast EMA period
input int    strategy_macd_slow        = 13;      // MACD slow EMA period
input int    strategy_macd_signal      = 1;       // MACD signal period (=1 -> Main is the raw MACD line)
input double strategy_macd_extreme     = 0.0045;  // extreme threshold (EURUSD 5-digit normalized)
input bool   strategy_use_ma_filter    = true;    // require slow-MA side agreement (STATE)
input int    strategy_slow_sma_period  = 89;      // slow SMA for trend-context filter
input int    strategy_sl_pips          = 30;      // stop distance in pips (card: 30)
input double strategy_tp_rr            = 2.0;      // take-profit = tp_rr * stop distance
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// Extreme level rescaled from EURUSD 5-digit calibration to the active symbol.
double MacdExtremeLevel()
  {
   const double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double factor = 1.0;
   if(pt > 0.0)
      factor = pt / 0.00001; // EURUSD/GBPUSD 5-digit -> 1.0
   return strategy_macd_extreme * factor;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
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

// Counter-trend fade entry. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // MACD Main on the two most recent closed bars (signal=1 -> Main = raw MACD line).
   const double macd1 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 1);
   const double macd2 = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                     strategy_macd_slow, strategy_macd_signal, 2);

   const double level = MacdExtremeLevel();
   if(level <= 0.0)
      return false;

   // Trigger EVENT (single, two adjacent closed bars):
   //   short = was overbought-extreme @2, dropped back through +level @1 and declining.
   const bool short_event = (macd2 >  level && macd1 <=  level && macd1 < macd2);
   //   long  = was oversold-extreme  @2, rose back through -level @1 and rising.
   const bool long_event  = (macd2 < -level && macd1 >= -level && macd1 > macd2);

   if(!short_event && !long_event)
      return false;

   // Optional STATE filter: slow-MA trend context (close@1 vs slow SMA).
   if(strategy_use_ma_filter)
     {
      const double slow_sma = QM_SMA(_Symbol, _Period, strategy_slow_sma_period, 1);
      const double close1   = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
      if(slow_sma <= 0.0 || close1 <= 0.0)
         return false;
      if(short_event && !(close1 < slow_sma))
         return false; // fade up-extremes only when price already below the slow MA
      if(long_event && !(close1 > slow_sma))
         return false; // fade down-extremes only when price already above the slow MA
     }

   const QM_OrderType dir = short_event ? QM_SELL : QM_BUY;

   const double entry = (dir == QM_SELL) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, dir, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0; // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = short_event ? "macd_extreme_fade_short" : "macd_extreme_fade_long";
   return true;
  }

// Fixed SL/TP only — no active management beyond the bracket.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the SL/TP bracket.
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
