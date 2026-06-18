#property strict
#property version   "5.0"
#property description "QM5_11426 williams-consecutive-down-closes-d1 — Larry Williams consecutive-close mean reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11426 williams-consecutive-down-closes-d1
// -----------------------------------------------------------------------------
// Source: Larry Williams, "Inner Circle Workshop Trading Method".
// Card: artifacts/cards_approved/QM5_11426_williams-consecutive-down-closes-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads at shift 1..31; gapless-safe — uses prior
// CLOSE, never prior RANGE/gap):
//
//   STATE  (deterministic from CLOSED bars):
//     LONG  : Close[1] < Close[2]  AND  Close[2] < Close[3]   (two lower closes)
//             AND  uc1 < uc2        where uc = High - Close     (upper shadow
//                                    contracting -> bearish momentum decelerating)
//             AND  Close[1] > Close[1+trend_lookback]          (medium-term up bias)
//     SHORT : mirror — two higher closes, lower-shadow (Close-Low) contracting,
//             Close[1] < Close[1+trend_lookback].
//
//   EVENT  (the entry trigger): a single pending STOP order placed at the open
//     of the new bar:
//     LONG  BUYSTOP  at  Open[0] + uc1
//     SHORT SELLSTOP at  Open[0] - lc1   (lc = Close - Low)
//     The order is DAY-ONLY: it expires at the end of the current D1 bar if not
//     filled (expiration_seconds = seconds remaining in the bar).
//
//   STOP : LONG  Low[1]  - 1 pip ;  SHORT  High[1] + 1 pip.   Capped at sl_cap_pips.
//   TAKE : entry + tp_mult * uc1 (LONG) ;  entry - tp_mult * lc1 (SHORT).
//
//   Spread guard : skip only a genuinely wide spread > spread_cap_pips
//                  (fail-OPEN on .DWX zero modeled spread).
//
// One position per magic; one live pending stop per magic at a time. Only the
// 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11426;
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
input int    strategy_consec_closes     = 2;     // # of consecutive lower/higher closes required
input int    strategy_trend_lookback    = 30;    // medium-term bias: Close[1] vs Close[1+lookback]
input bool   strategy_use_shadow_filter = true;  // require contracting shadow (uc/lc decelerating)
input double strategy_tp_mult           = 2.0;   // take-profit = tp_mult * signal-day shadow distance
input int    strategy_sl_cap_pips       = 80;    // hard cap on stop distance, in pips
input double strategy_spread_cap_pips   = 25.0;  // skip if spread wider than this (fail-open)
input bool   strategy_enable_short      = true;  // mirror short setups

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a missing/zero quote

   const double spread = ask - bid;
   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(ask > bid && spread > 0.0 && cap > 0.0 && spread > cap)
      return true;

   return false;
  }

// Remove this-EA's stale pending stop orders before evaluating a fresh bar, so
// the day-only order from the previous bar never carries over. Pending orders
// also carry an expiration, but this is the deterministic per-bar cleanup.
void QM_RemoveStalePendingThisMagic()
  {
   const int magic = QM_FrameworkMagic();
   const datetime bar_open = iTime(_Symbol, _Period, 0); // current bar open time
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      // Only pending stop orders belong to this strategy.
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot != ORDER_TYPE_BUY_STOP && ot != ORDER_TYPE_SELL_STOP)
         continue;
      // Cancel any pending order that was placed on an earlier bar.
      if((datetime)OrderGetInteger(ORDER_TIME_SETUP) < bar_open)
         QM_TM_RemovePendingOrder(ticket, "day_only_cancel_prev_bar");
     }
  }

// Count this-EA's live pending stop orders on this symbol.
int QM_PendingCountThisMagic()
  {
   int count = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = OrdersTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = OrderGetTicket(i);
      if(ticket == 0)
         continue;
      if(!OrderSelect(ticket))
         continue;
      if((int)OrderGetInteger(ORDER_MAGIC) != magic)
         continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol)
         continue;
      const ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(ot == ORDER_TYPE_BUY_STOP || ot == ORDER_TYPE_SELL_STOP)
         count++;
     }
   return count;
  }

// Closed-bar entry. Caller guarantees QM_IsNewBar() == true (one call per bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Clear any unfilled day-only pending from a previous bar first.
   QM_RemoveStalePendingThisMagic();

   // One position per magic, and one live pending stop at a time.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;
   if(QM_PendingCountThisMagic() > 0)
      return false;

   const int n = (strategy_consec_closes < 1) ? 1 : strategy_consec_closes;
   // We need closes at shifts 1 .. n+1 plus the trend-lookback reference.
   // perf-allowed: fixed-shift closed-bar OHLC reads for bespoke candle logic.
   const double open0 = iOpen(_Symbol, _Period, 0);
   if(open0 <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1);
   const double low1  = iLow(_Symbol, _Period, 1);
   const double close1 = iClose(_Symbol, _Period, 1);
   const double high2 = iHigh(_Symbol, _Period, 2);
   const double low2  = iLow(_Symbol, _Period, 2);
   const double close2 = iClose(_Symbol, _Period, 2);
   if(high1 <= 0.0 || low1 <= 0.0 || close1 <= 0.0 ||
      high2 <= 0.0 || low2 <= 0.0 || close2 <= 0.0)
      return false;

   // Medium-term bias reference: close[1 + trend_lookback].
   const int trend_shift = 1 + ((strategy_trend_lookback > 0) ? strategy_trend_lookback : 30);
   const double close_trend = iClose(_Symbol, _Period, trend_shift);
   if(close_trend <= 0.0)
      return false;

   const double pip = QM_StopRulesPipsToPriceDistance(_Symbol, 1);
   if(pip <= 0.0)
      return false;

   // ---- LONG setup: n consecutive LOWER closes ----
   bool long_consec = true;
   for(int k = 1; k <= n; ++k)
     {
      const double c_a = iClose(_Symbol, _Period, k);     // more recent
      const double c_b = iClose(_Symbol, _Period, k + 1); // older
      if(c_a <= 0.0 || c_b <= 0.0) { long_consec = false; break; }
      if(!(c_a < c_b)) { long_consec = false; break; }
     }
   if(long_consec)
     {
      const double uc1 = high1 - close1; // signal-day upper shadow
      const double uc2 = high2 - close2;
      const bool shadow_ok = (!strategy_use_shadow_filter) || (uc1 < uc2);
      const bool trend_ok  = (close1 > close_trend);
      // uc1 must be positive to give a meaningful BUYSTOP offset and TP.
      if(uc1 > 0.0 && shadow_ok && trend_ok)
        {
         const double entry = QM_TM_NormalizePrice(_Symbol, open0 + uc1);
         double sl = low1 - pip;
         // Cap stop distance at sl_cap_pips measured from entry.
         const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
         if(sl_cap_dist > 0.0 && (entry - sl) > sl_cap_dist)
            sl = entry - sl_cap_dist;
         const double tp = QM_TM_NormalizePrice(_Symbol, entry + strategy_tp_mult * uc1);
         sl = QM_TM_NormalizePrice(_Symbol, sl);
         if(entry > 0.0 && sl > 0.0 && tp > entry && sl < entry)
           {
            req.type   = QM_BUY_STOP;
            req.price  = entry;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "williams_consec_down_long";
            req.expiration_seconds = QM_SecondsToBarEnd();
            return true;
           }
        }
     }

   if(!strategy_enable_short)
      return false;

   // ---- SHORT setup: n consecutive HIGHER closes ----
   bool short_consec = true;
   for(int k = 1; k <= n; ++k)
     {
      const double c_a = iClose(_Symbol, _Period, k);     // more recent
      const double c_b = iClose(_Symbol, _Period, k + 1); // older
      if(c_a <= 0.0 || c_b <= 0.0) { short_consec = false; break; }
      if(!(c_a > c_b)) { short_consec = false; break; }
     }
   if(short_consec)
     {
      const double lc1 = close1 - low1; // signal-day lower shadow
      const double lc2 = close2 - low2;
      const bool shadow_ok = (!strategy_use_shadow_filter) || (lc1 < lc2);
      const bool trend_ok  = (close1 < close_trend);
      if(lc1 > 0.0 && shadow_ok && trend_ok)
        {
         const double entry = QM_TM_NormalizePrice(_Symbol, open0 - lc1);
         double sl = high1 + pip;
         const double sl_cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
         if(sl_cap_dist > 0.0 && (sl - entry) > sl_cap_dist)
            sl = entry + sl_cap_dist;
         const double tp = QM_TM_NormalizePrice(_Symbol, entry - strategy_tp_mult * lc1);
         sl = QM_TM_NormalizePrice(_Symbol, sl);
         if(entry > 0.0 && tp > 0.0 && tp < entry && sl > entry)
           {
            req.type   = QM_SELL_STOP;
            req.price  = entry;
            req.sl     = sl;
            req.tp     = tp;
            req.reason = "williams_consec_up_short";
            req.expiration_seconds = QM_SecondsToBarEnd();
            return true;
           }
        }
     }

   return false;
  }

// Per-tick: SL/TP are fixed at entry; the only management is day-only cancel of
// an unfilled pending order once its bar has ended. (Belt-and-suspenders to the
// pending-order expiration set on the request.)
void Strategy_ManageOpenPosition()
  {
   QM_RemoveStalePendingThisMagic();
  }

// No discretionary close — exit is via the fixed SL/TP on the filled order.
bool Strategy_ExitSignal()
  {
   return false;
  }

// Defer to the central news filter.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// Seconds remaining until the current bar closes (for day-only pending orders).
int QM_SecondsToBarEnd()
  {
   const datetime bar_open = iTime(_Symbol, _Period, 0);
   if(bar_open <= 0)
      return 0;
   const int tf_seconds = PeriodSeconds(_Period);
   if(tf_seconds <= 0)
      return 0;
   const datetime bar_end = bar_open + tf_seconds;
   const int remaining = (int)(bar_end - TimeCurrent());
   return (remaining > 0) ? remaining : 0;
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
