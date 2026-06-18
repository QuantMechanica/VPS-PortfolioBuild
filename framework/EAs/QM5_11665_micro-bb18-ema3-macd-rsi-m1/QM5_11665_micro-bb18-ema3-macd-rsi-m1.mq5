#property strict
#property version   "5.0"
#property description "QM5_11665 micro-bb18-ema3-macd-rsi-m1 — M1 EMA3/EMA18-cross scalp w/ MACD+RSI confluence"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11665 micro-bb18-ema3-macd-rsi-m1
// -----------------------------------------------------------------------------
// Source: Anonymous (DayTradeForex.com), "Micro Trading the 1 Minute Charts",
//   in: 9 Forex Systems (MoneyTec compilation, ~2006).
// Card: artifacts/cards_approved/QM5_11665_micro-bb18-ema3-macd-rsi-m1.md
//       (g0_status APPROVED).
//
// Mechanics (M1, closed-bar reads at shift 1):
//   The BB(18,EMA) MIDDLE band == EMA(18) of closes (per card Implementation
//   Notes — "Bollinger Bands Exponential Set at 18" means EMA(18) is the mid).
//
//   Trigger EVENT (exactly one cross/bar — avoids the two-cross-same-bar trap):
//     LONG  : EMA(3) crosses ABOVE EMA(18)   [ema3_prev <= ema18_prev && ema3_now > ema18_now]
//     SHORT : EMA(3) crosses BELOW EMA(18)   [ema3_prev >= ema18_prev && ema3_now < ema18_now]
//
//   Confirming STATES (current side, not events):
//     LONG  : MACD histogram (Main-Signal) > 0  AND  RSI(14) > rsi_mid (50)
//     SHORT : MACD histogram (Main-Signal) < 0  AND  RSI(14) < rsi_mid (50)
//
//   Stop  : fixed sl_pips (10), widened to sl_atr_mult * ATR(M1) if that is wider.
//   Take  : fixed tp_pips (7).
//   Exit  : SL/TP only (whichever hits first); no discretionary exit.
//   Spread: skip a genuinely wide spread > spread_pct_of_stop of stop distance
//           (fail-open on .DWX zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11665;
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
input int    strategy_ema_fast_period   = 3;     // fast EMA (the crossing line)
input int    strategy_bb_mid_period     = 18;    // BB(18,EMA) middle band = EMA(18)
input int    strategy_macd_fast         = 12;    // MACD fast EMA
input int    strategy_macd_slow         = 26;    // MACD slow EMA
input int    strategy_macd_signal       = 9;     // MACD signal EMA
input int    strategy_rsi_period        = 14;    // RSI lookback period
input double strategy_rsi_mid           = 50.0;  // RSI side threshold (>mid long, <mid short)
input int    strategy_sl_pips           = 10;    // fixed stop in pips
input int    strategy_tp_pips           = 7;     // fixed take in pips
input int    strategy_atr_period        = 14;    // ATR period for the floor-widened stop
input double strategy_sl_atr_mult       = 2.0;   // stop = max(sl_pips, mult*ATR)
input double strategy_spread_pct_of_stop = 25.0; // skip if spread > this % of stop distance

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

   // Stop-distance reference for the spread cap (use the fixed-pip stop, scale-correct).
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

   // --- Trigger EVENT: EMA(3) cross of the BB(18,EMA) middle band == EMA(18) ---
   const double ema3_now   = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema3_prev  = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema18_now  = QM_EMA(_Symbol, _Period, strategy_bb_mid_period, 1);
   const double ema18_prev = QM_EMA(_Symbol, _Period, strategy_bb_mid_period, 2);
   if(ema3_now <= 0.0 || ema3_prev <= 0.0 || ema18_now <= 0.0 || ema18_prev <= 0.0)
      return false;

   const bool cross_up   = (ema3_prev <= ema18_prev && ema3_now > ema18_now);
   const bool cross_down = (ema3_prev >= ema18_prev && ema3_now < ema18_now);
   if(!cross_up && !cross_down)
      return false; // exactly one cross event drives a side; otherwise no entry

   // --- Confirming STATE: MACD histogram side (Main - Signal), closed bar ---
   const double macd_main = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                         strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_sig  = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast,
                                           strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_hist = macd_main - macd_sig;

   // --- Confirming STATE: RSI(14) side, closed bar ---
   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   QM_OrderType side;
   if(cross_up)
     {
      // LONG confluence: MACD hist > 0 AND RSI > mid
      if(!(macd_hist > 0.0 && rsi_now > strategy_rsi_mid))
         return false;
      side = QM_BUY;
     }
   else
     {
      // SHORT confluence: MACD hist < 0 AND RSI < mid
      if(!(macd_hist < 0.0 && rsi_now < strategy_rsi_mid))
         return false;
      side = QM_SELL;
     }

   // --- Stop = max(fixed pips, sl_atr_mult * ATR); Take = fixed pips ---
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double atr_value     = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double fixed_stop_d  = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_pips);
   if(fixed_stop_d <= 0.0)
      return false;
   const double atr_stop_d    = (atr_value > 0.0) ? strategy_sl_atr_mult * atr_value : 0.0;
   const double stop_distance = (atr_stop_d > fixed_stop_d) ? atr_stop_d : fixed_stop_d;
   const double take_distance = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(take_distance <= 0.0)
      return false;

   double sl, tp;
   if(side == QM_BUY)
     {
      sl = entry - stop_distance;
      tp = entry + take_distance;
     }
   else
     {
      sl = entry + stop_distance;
      tp = entry - take_distance;
     }

   req.type   = side;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp     = QM_StopRulesNormalizePrice(_Symbol, tp);
   req.reason = (side == QM_BUY) ? "micro_bb18_ema3_long" : "micro_bb18_ema3_short";
   return true;
  }

// No active trade management — the fixed SL/TP run the trade.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — SL/TP only.
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
