#property strict
#property version   "5.0"
#property description "QM5_11033 atc-bulls-trend — Bulls Power trend-change continuation (FX, H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11033 atc-bulls-trend
// -----------------------------------------------------------------------------
// Source: Tomasz Tauzowski, "All I can do is pray for a loss position"
//         (ATC 2010), MQL5 Articles — https://www.mql5.com/en/articles/537
// Card: artifacts/cards_approved/QM5_11033_atc-bulls-trend.md (g0_status APPROVED).
//
// Mechanics (both directions, closed-bar reads at shift 1):
//   Bulls Power[i] = High[i]  - EMA(close, bulls_period)[i]   (definitional)
//   Bears Power[i] = Low[i]   - EMA(close, bulls_period)[i]
//   Slope          = BullsPower[1] - BullsPower[1+trend_lookback]
//   Slope is normalised by ATR(atr_period) so the threshold is scale-invariant
//   across 5-digit FX and JPY pairs (card: "ATR-normalized units").
//
//   Long  STATE/EVENT:
//     BullsPower[1] > 0  AND  (slope / ATR) >= bulls_slope_threshold
//     AND close[1] > EMA(bulls_period)  AND  no open position for this magic.
//   Short STATE/EVENT:
//     ( BullsPower[1] < 0 OR (bear_confirm && BearsPower[1] < 0) )
//     AND (slope / ATR) <= -bulls_slope_threshold
//     AND close[1] < EMA(bulls_period)  AND  no open position for this magic.
//
//   Stop  : SL distance = max( sl_pips equiv , sl_atr_mult * ATR ), per card.
//   Take  : TP = tp_rr * SL (card: TP = 2 * SL).
//   Exit  : optional early close when Bulls Power crosses back through zero
//           (against the open position) before SL/TP.
//   Filter: trade only during the London/NY liquid window (broker-time hours);
//           optional ADX(period) >= adx_threshold trend-change confirmation;
//           spread guard fails OPEN on .DWX zero modeled spread.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11033;
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
input int    strategy_bulls_period       = 13;    // Bulls/Bears Power EMA period
input int    strategy_trend_lookback     = 5;     // bars back for the slope measure
input double strategy_slope_threshold     = 0.25;  // min |slope|/ATR (ATR-normalized units)
input bool   strategy_bear_confirm        = false; // also require BearsPower<0 for shorts
input int    strategy_atr_period          = 14;    // ATR period (slope norm / stop floor)
input double strategy_sl_atr_mult         = 1.5;   // SL distance = mult * ATR (card baseline)
input int    strategy_sl_min_pips         = 40;    // SL floor in pips equivalent (card baseline)
input double strategy_tp_rr               = 2.0;   // TP = tp_rr * SL distance (card: 2R)
input bool   strategy_zero_cross_exit     = true;  // early close on Bulls Power zero re-cross
input int    strategy_session_start_broker = 9;    // London/NY window start hour (broker time)
input int    strategy_session_end_broker   = 22;   // London/NY window end hour (broker time)
input bool   strategy_use_adx_filter      = true;  // require ADX >= threshold (trend confirm)
input int    strategy_adx_period          = 14;    // ADX period
input double strategy_adx_threshold       = 18.0;  // ADX trend-change confirmation floor
input double strategy_spread_pct_of_stop  = 15.0;  // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Helpers — Bulls/Bears Power are definitional (no QM_* reader exists):
//   BullsPower[shift] = High[shift] - EMA(close, period)[shift]
//   BearsPower[shift] = Low[shift]  - EMA(close, period)[shift]
// EMA via the handle-pooled QM_EMA reader; High/Low via single closed-bar reads
// (perf-allowed, like the reference EA's iClose at shift 1).
// -----------------------------------------------------------------------------
double BullsPowerAt(const int shift)
  {
   const double ema  = QM_EMA(_Symbol, _Period, strategy_bulls_period, shift);
   const double high = iHigh(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   if(ema <= 0.0 || high <= 0.0)
      return 0.0;
   return high - ema;
  }

double BearsPowerAt(const int shift)
  {
   const double ema = QM_EMA(_Symbol, _Period, strategy_bulls_period, shift);
   const double low = iLow(_Symbol, _Period, shift); // perf-allowed: single closed-bar read
   if(ema <= 0.0 || low <= 0.0)
      return 0.0;
   return low - ema;
  }

// SL distance in price terms: max( sl_min_pips equiv , sl_atr_mult * ATR ).
double StopDistance(const double atr_value)
  {
   const double pip_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_min_pips);
   const double atr_dist = strategy_sl_atr_mult * atr_value;
   return (pip_dist > atr_dist) ? pip_dist : atr_dist;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate: session window (broker time) + spread guard.
// Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   // Session window in BROKER time (London open through NY afternoon).
   if(QM_Sig_Session(TimeCurrent(), strategy_session_start_broker, strategy_session_end_broker) == 0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = StopDistance(atr_value);
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
   // One open position per symbol/magic (card: only one open position at a time).
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double ema1   = QM_EMA(_Symbol, _Period, strategy_bulls_period, 1);
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(ema1 <= 0.0 || close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- Bulls Power now (shift 1) and slope over the lookback window ---
   const double bulls_now  = BullsPowerAt(1);
   const double bulls_back = BullsPowerAt(1 + strategy_trend_lookback);
   const double slope_norm = (bulls_now - bulls_back) / atr_value; // ATR-normalized units

   // --- Optional ADX trend-change confirmation (STATE) ---
   if(strategy_use_adx_filter)
     {
      const double adx = QM_ADX(_Symbol, _Period, strategy_adx_period, 1);
      if(adx < strategy_adx_threshold)
         return false;
     }

   bool go_long  = false;
   bool go_short = false;

   // --- Long: Bulls Power positive + rising slope + price above EMA ---
   if(bulls_now > 0.0 &&
      slope_norm >= strategy_slope_threshold &&
      close1 > ema1)
      go_long = true;

   // --- Short: Bulls Power negative (opt. Bears confirm) + falling slope + price below EMA ---
   if(!go_long)
     {
      bool bear_side = (bulls_now < 0.0);
      if(strategy_bear_confirm)
        {
         const double bears_now = BearsPowerAt(1);
         bear_side = (bear_side && bears_now < 0.0);
        }
      if(bear_side &&
         slope_norm <= -strategy_slope_threshold &&
         close1 < ema1)
         go_short = true;
     }

   if(!go_long && !go_short)
      return false;

   const QM_OrderType otype = go_long ? QM_BUY : QM_SELL;
   const double entry = go_long ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double stop_distance = StopDistance(atr_value);
   if(stop_distance <= 0.0)
      return false;

   const double sl = (otype == QM_BUY) ? (entry - stop_distance) : (entry + stop_distance);
   const double tp = (otype == QM_BUY) ? (entry + strategy_tp_rr * stop_distance)
                                       : (entry - strategy_tp_rr * stop_distance);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = otype;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = go_long ? "atc_bulls_long" : "atc_bulls_short";
   return true;
  }

// No active trade management beyond the fixed SL/TP. The optional zero-cross
// early exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Optional early exit: Bulls Power crosses back through zero AGAINST the open
// position before SL/TP. One event at shift 1 (was on the other side at shift 2).
bool Strategy_ExitSignal()
  {
   if(!strategy_zero_cross_exit)
      return false;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Determine the open direction for this magic.
   bool is_long  = false;
   bool is_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)  is_long  = true;
      if(ptype == POSITION_TYPE_SELL) is_short = true;
     }
   if(!is_long && !is_short)
      return false;

   const double bulls_now  = BullsPowerAt(1);
   const double bulls_prev = BullsPowerAt(2);

   // Long: Bulls Power crossed down through zero (was >=0, now <0).
   if(is_long && bulls_prev >= 0.0 && bulls_now < 0.0)
      return true;
   // Short: Bulls Power crossed up through zero (was <=0, now >0).
   if(is_short && bulls_prev <= 0.0 && bulls_now > 0.0)
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
