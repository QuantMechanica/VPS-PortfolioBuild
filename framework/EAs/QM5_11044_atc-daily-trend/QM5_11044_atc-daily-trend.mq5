#property strict
#property version   "5.0"
#property description "QM5_11044 atc-daily-trend — D1 EMA-stack trend, H4 reversal exit (FX, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11044 atc-daily-trend
// -----------------------------------------------------------------------------
// Source: Sergey Nikitin, Interview (ATC 2011), MQL5 Articles 541.
// Card: artifacts/cards_approved/QM5_11044_atc-daily-trend.md (g0_status APPROVED).
//
// Mechanics (long & short, multi-timeframe; closed-bar reads at shift 1):
//   D1 trend STATE (base timeframe = D1):
//     long  : close(D1) > EMA(slow,D1)  AND  EMA(fast,D1) > EMA(slow,D1)
//     short : close(D1) < EMA(slow,D1)  AND  EMA(fast,D1) < EMA(slow,D1)
//   Entry  : one position in the D1 trend direction (one per symbol/magic).
//   Stop   : distance = max(sl_floor_pips, sl_atr_mult * ATR(atr_period, H4)).
//            150 source "points" on a 5-digit FX feed = 15 pips; expressed as a
//            pips floor so QM_StopRulesPipsToPriceDistance scales 3/5-digit + JPY.
//   Exit   : H4 reversal —
//              long  : close(H4) < EMA(exit,H4)
//              short : close(H4) > EMA(exit,H4)
//            plus D1 opposite-trend flip (trend proxy reverses).
//   Vol filter: skip entry when ATR(atr_period,D1) is below the rolling
//               atr_pctile-th percentile of the last atr_pctile_lookback closed
//               D1 ATR readings (choppy / low-volatility regime guard).
//   Spread guard: fail-open on .DWX zero modeled spread; blocks only a
//                 genuinely wide spread > spread_pct_of_stop of the stop distance.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11044;
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
input int    strategy_ema_fast_period    = 20;     // D1 trend fast EMA
input int    strategy_ema_slow_period    = 50;     // D1 trend slow EMA
input ENUM_TIMEFRAMES strategy_exit_tf   = PERIOD_H4; // lower-timeframe reversal frame
input int    strategy_exit_ema_period    = 20;     // EMA on exit TF for reversal exit
input int    strategy_atr_period         = 14;     // ATR period (stop + vol filter)
input double strategy_sl_atr_mult        = 1.5;    // stop ATR multiple (on exit TF ATR)
input int    strategy_sl_floor_pips      = 15;     // SL floor (150 source points = 15 pips on 5-digit FX)
input int    strategy_atr_pctile_lookback = 20;    // D1 ATR percentile window (bars)
input double strategy_atr_pctile         = 20.0;   // skip entry if ATR(D1) below this percentile
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Internal helpers
// -----------------------------------------------------------------------------

// D1 trend proxy on closed bars. Returns +1 long-trend, -1 short-trend, 0 none.
int ATC_D1Trend()
  {
   const double ema_fast = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_fast_period, 1);
   const double ema_slow = QM_EMA(_Symbol, PERIOD_D1, strategy_ema_slow_period, 1);
   const double close1   = iClose(_Symbol, PERIOD_D1, 1); // perf-allowed: single closed-bar read
   if(ema_fast <= 0.0 || ema_slow <= 0.0 || close1 <= 0.0)
      return 0;

   if(close1 > ema_slow && ema_fast > ema_slow)
      return +1;
   if(close1 < ema_slow && ema_fast < ema_slow)
      return -1;
   return 0;
  }

// Stop distance (price) = max(floor_pips_distance, sl_atr_mult * ATR(exit_tf)).
// Returns 0.0 if neither component is available.
double ATC_StopDistance()
  {
   double dist = 0.0;
   const double floor_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_floor_pips);
   if(floor_dist > 0.0)
      dist = floor_dist;

   const double atr_exit = QM_ATR(_Symbol, strategy_exit_tf, strategy_atr_period, 1);
   if(atr_exit > 0.0)
     {
      const double atr_dist = strategy_sl_atr_mult * atr_exit;
      if(atr_dist > dist)
         dist = atr_dist;
     }
   return dist;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double stop_distance = ATC_StopDistance();
   if(stop_distance <= 0.0)
      return false; // no stop reference yet — defer to entry gate, do not block

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry on the D1 trend direction. Caller guarantees QM_IsNewBar() == true.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const int trend = ATC_D1Trend();
   if(trend == 0)
      return false;

   // --- Volatility filter: ATR(D1) above the rolling percentile -------------
   // Compare the most recent closed-bar ATR against the atr_pctile-th
   // percentile of the prior atr_pctile_lookback closed-bar ATR readings.
   const double atr_now = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr_now <= 0.0)
      return false;

   if(strategy_atr_pctile_lookback > 0 && strategy_atr_pctile > 0.0)
     {
      double samples[];
      ArrayResize(samples, strategy_atr_pctile_lookback);
      int n = 0;
      for(int s = 1; s <= strategy_atr_pctile_lookback; ++s)
        {
         const double a = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, s);
         if(a > 0.0)
            samples[n++] = a;
        }
      if(n > 0)
        {
         ArrayResize(samples, n);
         ArraySort(samples); // ascending
         // index of the percentile threshold within [0, n-1]
         int idx = (int)MathFloor((strategy_atr_pctile / 100.0) * (n - 1));
         if(idx < 0)
            idx = 0;
         if(idx > n - 1)
            idx = n - 1;
         const double threshold = samples[idx];
         if(atr_now < threshold)
            return false; // low-volatility / choppy regime — skip
        }
     }

   // --- Build the entry. Framework sizes lots (no lots field). --------------
   const QM_OrderType side = (trend > 0) ? QM_BUY : QM_SELL;
   const double entry = (trend > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                    : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double stop_distance = ATC_StopDistance();
   if(stop_distance <= 0.0)
      return false;

   const double sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, stop_distance);
   if(sl <= 0.0)
      return false;

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = 0.0;   // no fixed target — exit by SL or H4/D1 reversal
   req.reason = (trend > 0) ? "atc_d1_trend_long" : "atc_d1_trend_short";
   return true;
  }

// No active trade management beyond the fixed stop. Reversal exits live in
// Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Reversal exit: H4 (exit TF) close vs EMA(exit) against position direction,
// or a D1 opposite-trend flip.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine current position direction for this EA's magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         is_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         is_short = true;
     }
   if(!is_long && !is_short)
      return false;

   // --- H4 reversal: exit-TF close vs EMA(exit) on the closed bar -----------
   const double exit_close = iClose(_Symbol, strategy_exit_tf, 1); // perf-allowed: single closed-bar read
   const double exit_ema   = QM_EMA(_Symbol, strategy_exit_tf, strategy_exit_ema_period, 1);
   if(exit_close > 0.0 && exit_ema > 0.0)
     {
      if(is_long && exit_close < exit_ema)
         return true;
      if(is_short && exit_close > exit_ema)
         return true;
     }

   // --- D1 opposite-trend flip ---------------------------------------------
   const int trend = ATC_D1Trend();
   if(is_long && trend < 0)
      return true;
   if(is_short && trend > 0)
      return true;

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
