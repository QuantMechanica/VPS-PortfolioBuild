#property strict
#property version   "5.0"
#property description "QM5_11521 carter-t-ema6-13-macd-psar-h4-gbp — EMA6/13 cross + MACD + PSAR confluence (H4, GBP)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11521 carter-t-ema6-13-macd-psar-h4-gbp
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trend Following Strategies: 20 Trend Following
//         Systems" (System #18), self-published 2014.
// Card: artifacts/cards_approved/QM5_11521_carter-t-ema6-13-macd-psar-h4-gbp.md
//       (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; one position per magic):
//   Trigger EVENT : EMA(6) crosses EMA(13) within the last N closed bars.
//                   N defaults to 3 per card. This is the single trigger; MACD
//                   and PSAR are confirming states.
//   MACD STATE    : LONG needs MACD main > 0 ; SHORT needs MACD main < 0.
//   PSAR STATE    : LONG needs PSAR below the prior bar's low (dot under price);
//                   SHORT needs PSAR above the prior bar's high (dot over price).
//   Stop          : fixed pips (source 40p GBPUSD H4; pip-scaled for JPY).
//   Take profit   : RR multiple of the stop (source 100p/40p = 2.5R; the JPY
//                   pair's 150p/60p is also 2.5R, so one RR input is portable).
//   Filter        : optional "no Friday entry" (source-specified).
//   Spread guard  : block only a genuinely wide spread (fail-open on .DWX zero
//                   modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11521;
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
input int    strategy_ema_cross_lookback = 3;     // cross must occur within last N closed bars
input int    strategy_sl_pips           = 40;     // stop distance in pips (GBPUSD H4 source)
input double strategy_tp_rr             = 2.5;    // take = RR * stop (100/40 = 60/150 = 2.5)
input bool   strategy_no_friday_entry   = true;   // source: no Friday entry
input int    strategy_spread_cap_pips   = 20;     // source spread cap

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

int Strategy_EmaCrossWithinLookback()
  {
   const int lookback = (strategy_ema_cross_lookback < 1) ? 1 : strategy_ema_cross_lookback;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const double ema_fast_now = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift);
      const double ema_slow_now = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift);
      const double ema_fast_prev = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, shift + 1);
      const double ema_slow_prev = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, shift + 1);
      if(ema_fast_now <= 0.0 || ema_slow_now <= 0.0 || ema_fast_prev <= 0.0 || ema_slow_prev <= 0.0)
         continue;

      if(ema_fast_prev <= ema_slow_prev && ema_fast_now > ema_slow_now)
         return +1;
      if(ema_fast_prev >= ema_slow_prev && ema_fast_now < ema_slow_now)
         return -1;
     }
   return 0;
  }

// Cheap O(1) per-tick gate. Spread guard only — signal work is on the closed-bar
// path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double max_spread = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(max_spread <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > max_spread)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // Optional "no Friday entry" filter (source-specified). Bar-open time of the
   // forming bar (shift 0) is the entry timestamp.
   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(iTime(_Symbol, _Period, 0), dt); // perf-allowed: single bar-open read
      if(dt.day_of_week == 5)
         return false;
     }

   // --- Trigger EVENT: EMA(6) crosses EMA(13) within the last N closed bars ---
   const int cross_dir = Strategy_EmaCrossWithinLookback();
   if(cross_dir == 0)
      return false;

   // --- Confirming STATE: MACD main side ---
   const double macd = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);

   // --- Confirming STATE: PSAR side relative to the closed bar's range ---
   const double sar  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double low1 = iLow(_Symbol, _Period, 1);   // perf-allowed: single closed-bar read
   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(sar <= 0.0 || low1 <= 0.0 || high1 <= 0.0)
      return false;

   const bool long_ok  = (cross_dir > 0 && macd > 0.0 && sar < low1);
   const bool short_ok = (cross_dir < 0 && macd < 0.0 && sar > high1);
   if(!long_ok && !short_ok)
      return false;

   const QM_OrderType side = long_ok ? QM_BUY : QM_SELL;

   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopFixedPips(_Symbol, side, entry, strategy_sl_pips);
   if(sl <= 0.0)
      return false;
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_tp_rr);
   if(tp <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = long_ok ? "carter_ema_macd_psar_long" : "carter_ema_macd_psar_short";
   return true;
  }

// Fixed pip SL/TP only — no active trade management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP. EMA-cross reversal will simply
// arm a fresh opposite entry once the current position is flat.
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
