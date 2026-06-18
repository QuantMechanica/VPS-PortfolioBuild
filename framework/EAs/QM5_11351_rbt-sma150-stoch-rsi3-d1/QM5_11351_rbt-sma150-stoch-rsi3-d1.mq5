#property strict
#property version   "5.0"
#property description "QM5_11351 rbt-sma150-stoch-rsi3-d1 — RoboForex SMA150 + Stoch(8,3,3) + RSI(3) pullback (long/short, D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11351 rbt-sma150-stoch-rsi3-d1
// -----------------------------------------------------------------------------
// Source: RoboForex Strategy Collection "Strategy SMA 150 + Stochastic + RSI".
// Card: artifacts/cards_approved/QM5_11351_rbt-sma150-stoch-rsi3-d1.md (g0 APPROVED).
//
// Mechanics (long + mirror short, closed-bar reads at shift 1; D1):
//   Trend STATE   : LONG  close > SMA(trend) ; SHORT close < SMA(trend).
//   Stoch STATE   : LONG  %K < lo AND heading up   (K[1] > K[2]).
//                   SHORT %K > hi AND heading down  (K[1] < K[2]).
//   Trigger EVENT : single fresh RSI(3) recovery cross of the extreme level:
//                   LONG  RSI[2] < lo AND RSI[1] >= lo  (cross back ABOVE lo).
//                   SHORT RSI[2] > hi AND RSI[1] <= hi  (cross back BELOW hi).
//   ZERO-TRADE GUARD: the trend + stoch are STATES; only the RSI(3) cross is the
//                   EVENT. We never demand two fresh crossovers on the same bar.
//   Stop          : ATR(atr_period) * sl_atr_mult, clamped to [min_pips, max_pips];
//                   if ATR*mult > max_pips the entry is SKIPPED (card rule).
//   Take profit   : tp_rr * stop distance (2:1 R:R via QM_TakeRR).
//   Spread guard  : fail-OPEN on .DWX zero modeled spread; only a genuinely wide
//                   spread > spread_pct_of_stop of the stop distance blocks.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11351;
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
input int    strategy_sma_trend_period   = 150;    // macro-trend SMA (price above=up)
input int    strategy_rsi_period         = 3;      // fast RSI for pullback exhaustion
input double strategy_rsi_lo             = 20.0;   // RSI oversold / long cross level
input double strategy_rsi_hi             = 80.0;   // RSI overbought / short cross level
input int    strategy_stoch_k            = 8;      // Stochastic %K period
input int    strategy_stoch_d            = 3;      // Stochastic %D period
input int    strategy_stoch_slowing      = 3;      // Stochastic slowing
input double strategy_stoch_lo           = 20.0;   // %K oversold zone (long)
input double strategy_stoch_hi           = 80.0;   // %K overbought zone (short)
input int    strategy_atr_period         = 14;     // ATR period for the stop proxy
input double strategy_sl_atr_mult        = 1.5;    // stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;    // take profit = rr * stop distance
input double strategy_sl_min_pips        = 30.0;   // floor on the stop distance (pips)
input double strategy_sl_max_pips        = 200.0;  // skip the entry if ATR*mult exceeds this
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is in
// Strategy_EntrySignal on the closed-bar path. Fail-OPEN on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   double stop_distance = strategy_sl_atr_mult * atr_value;
   const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_min_pips);
   if(min_dist > 0.0 && stop_distance < min_dist)
      stop_distance = min_dist;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long + mirror short entry. Caller guarantees QM_IsNewBar() == true (closed bar).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- Trend STATE: price vs SMA(trend) on the closed bar ---
   const double sma_trend = QM_SMA(_Symbol, _Period, strategy_sma_trend_period, 1);
   if(sma_trend <= 0.0)
      return false;

   // --- Stochastic %K STATE: level + direction (closed bars 1 vs 2) ---
   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slowing, 2);
   if(k1 <= 0.0 || k2 <= 0.0)
      return false;

   // --- RSI(3) recovery cross EVENT (the single trigger) ---
   const double rsi1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi2 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   if(rsi1 <= 0.0 || rsi2 <= 0.0)
      return false;

   // --- Volatility / stop sizing (shared ATR) ---
   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   double stop_distance = strategy_sl_atr_mult * atr_value;
   const double min_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_min_pips);
   const double max_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_max_pips);
   // Card: skip the trade entirely if ATR*mult exceeds the max-pips ceiling.
   if(max_dist > 0.0 && (strategy_sl_atr_mult * atr_value) > max_dist)
      return false;
   if(min_dist > 0.0 && stop_distance < min_dist)
      stop_distance = min_dist;
   if(stop_distance <= 0.0)
      return false;

   QM_OrderType dir;
   string reason;

   const bool long_trend = (close1 > sma_trend);
   const bool long_stoch = (k1 < strategy_stoch_lo && k1 > k2);          // oversold + heading up
   const bool long_event = (rsi2 < strategy_rsi_lo && rsi1 >= strategy_rsi_lo); // cross back above lo

   const bool short_trend = (close1 < sma_trend);
   const bool short_stoch = (k1 > strategy_stoch_hi && k1 < k2);         // overbought + heading down
   const bool short_event = (rsi2 > strategy_rsi_hi && rsi1 <= strategy_rsi_hi); // cross back below hi

   if(long_trend && long_stoch && long_event)
     {
      dir    = QM_BUY;
      reason = "sma150_stoch_rsi3_long";
     }
   else if(short_trend && short_stoch && short_event)
     {
      dir    = QM_SELL;
      reason = "sma150_stoch_rsi3_short";
     }
   else
      return false;

   // --- Build the entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = (dir == QM_BUY) ? (entry - stop_distance) : (entry + stop_distance);
   const double tp = QM_TakeRR(_Symbol, dir, entry, sl, strategy_tp_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_TM_NormalizePrice(_Symbol, sl);
   req.tp     = QM_TM_NormalizePrice(_Symbol, tp);
   req.reason = reason;
   return true;
  }

// Fixed ATR stop + 2R target only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the bracket (SL/TP).
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
