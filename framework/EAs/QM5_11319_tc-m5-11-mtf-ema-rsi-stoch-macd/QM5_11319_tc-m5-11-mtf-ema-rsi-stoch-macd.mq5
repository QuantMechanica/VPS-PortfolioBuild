#property strict
#property version   "5.0"
#property description "QM5_11319 tc-m5-11-mtf-ema-rsi-stoch-macd — H4 EMA bias + M5 momentum stack"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11319 tc-m5-11-mtf-ema-rsi-stoch-macd
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   5 Min Trading System #11 (pp. 28-29). Card:
//   artifacts/cards_approved/QM5_11319_tc-m5-11-mtf-ema-rsi-stoch-macd.md
//   (g0_status APPROVED).
//
// Multi-timeframe confluence (same-symbol higher-TF aggregation, NOT a basket):
//   the higher timeframe (H4) is read on the SAME symbol via the QM_* readers —
//   no foreign-symbol warmup / SymbolGuard needed.
//
// Mechanics (all reads on CLOSED bars; M5 entry TF, H4 bias TF):
//   Bias STATE (H4)   : EMA(5) > EMA(10) -> longs only; EMA(5) < EMA(10) -> shorts.
//   Trigger EVENT (M5): EMA(5) crosses EMA(10). This is the ONE fresh event; all
//                       other conditions are STATES read on the same closed bar,
//                       so we never require two crosses on the same bar (the
//                       zero-trade trap the card NOTE warns about).
//   Momentum STATE 1  : RSI(14) > 50 (long) / < 50 (short).
//   Momentum STATE 2  : Stoch %K rising and < cap (long); falling and > floor (short).
//                       Slope = %K@1 vs %K@2. Cap/floor on %K@1.
//   Momentum STATE 3  : MACD histogram per card disjunction (hist = main-signal):
//                       long  -> (hist1<=0 && hist0... ) collapses to "hist rising"
//                       i.e. cross-up OR negative-but-increasing => hist@1 > hist@2.
//                       MACD may be negative; we never gate on its sign alone.
//   Stop / Take       : fixed pips (card baseline 25 / 25), scale-correct via
//                       QM_StopFixedPips / explicit pip-distance TP.
//   Exit              : SL/TP only (source has no indicator exit).
//   Spread guard      : skip only a genuinely wide spread (fail-open on .DWX
//                       zero modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11319;
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
input ENUM_TIMEFRAMES strategy_bias_tf        = PERIOD_H4;  // higher-TF EMA bias
input int    strategy_ema_fast_period         = 5;          // EMA fast (bias TF + entry TF)
input int    strategy_ema_slow_period         = 10;         // EMA slow (bias TF + entry TF)
input int    strategy_rsi_period              = 14;         // RSI period (entry TF)
input double strategy_rsi_mid                 = 50.0;       // RSI midline filter
input int    strategy_stoch_k                 = 5;          // Stochastic %K period
input int    strategy_stoch_d                 = 3;          // Stochastic %D period
input int    strategy_stoch_slow              = 3;          // Stochastic slowing
input double strategy_stoch_cap               = 80.0;       // long: %K must be < cap
input double strategy_stoch_floor             = 20.0;       // short: %K must be > floor
input int    strategy_macd_fast               = 12;         // MACD fast EMA
input int    strategy_macd_slow               = 26;         // MACD slow EMA
input int    strategy_macd_signal             = 9;          // MACD signal EMA
input double strategy_sl_pips                 = 25.0;       // stop loss (pips)
input double strategy_tp_pips                 = 25.0;       // take profit (pips)
input double strategy_spread_pct_of_stop      = 50.0;       // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — never block on a zero price

   const double stop_distance = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_sl_pips);
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true on the M5 entry TF.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- H4 bias STATE (closed H4 bar at shift 1) ---
   const double h4_fast = QM_EMA(_Symbol, strategy_bias_tf, strategy_ema_fast_period, 1);
   const double h4_slow = QM_EMA(_Symbol, strategy_bias_tf, strategy_ema_slow_period, 1);
   if(h4_fast <= 0.0 || h4_slow <= 0.0)
      return false;
   const int bias = (h4_fast > h4_slow) ? 1 : ((h4_fast < h4_slow) ? -1 : 0);
   if(bias == 0)
      return false;

   // --- M5 entry-TF EMAs (closed bars at shift 1 and 2 for the cross EVENT) ---
   const double ema_fast_1 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 1);
   const double ema_slow_1 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 1);
   const double ema_fast_2 = QM_EMA(_Symbol, _Period, strategy_ema_fast_period, 2);
   const double ema_slow_2 = QM_EMA(_Symbol, _Period, strategy_ema_slow_period, 2);
   if(ema_fast_1 <= 0.0 || ema_slow_1 <= 0.0 || ema_fast_2 <= 0.0 || ema_slow_2 <= 0.0)
      return false;

   const bool cross_up   = (ema_fast_2 <= ema_slow_2 && ema_fast_1 >  ema_slow_1);
   const bool cross_down = (ema_fast_2 >= ema_slow_2 && ema_fast_1 <  ema_slow_1);

   // --- Momentum STATES (all read on the same M5 closed bar) ---
   const double rsi_1 = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_1 <= 0.0)
      return false;

   const double k1 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 1);
   const double k2 = QM_Stoch_K(_Symbol, _Period, strategy_stoch_k, strategy_stoch_d, strategy_stoch_slow, 2);
   if(k1 <= 0.0 || k2 <= 0.0)
      return false;

   const double macd_main_1   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_signal_1 = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 1);
   const double macd_main_2   = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   const double macd_signal_2 = QM_MACD_Signal(_Symbol, _Period, strategy_macd_fast, strategy_macd_slow, strategy_macd_signal, 2);
   // Histogram = MACD line - signal line. May be negative — never gate on sign.
   const double hist_1 = macd_main_1 - macd_signal_1;
   const double hist_2 = macd_main_2 - macd_signal_2;

   // LONG: H4 bias up, M5 EMA cross up (EVENT), RSI>50, %K rising and < cap,
   //       MACD histogram rising (cross-up OR negative-but-increasing).
   if(bias > 0 && cross_up)
     {
      const bool rsi_ok   = (rsi_1 > strategy_rsi_mid);
      const bool stoch_ok = (k1 > k2 && k1 < strategy_stoch_cap);
      const bool macd_ok  = (hist_1 > hist_2);   // card disjunction collapses to rising hist
      if(rsi_ok && stoch_ok && macd_ok)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_BUY, entry, (int)strategy_sl_pips);
         const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_BUY;
         req.price  = 0.0;   // framework fills market price at send
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "tc_m5_11_long";
         return true;
        }
      return false;
     }

   // SHORT: mirror image.
   if(bias < 0 && cross_down)
     {
      const bool rsi_ok   = (rsi_1 < strategy_rsi_mid);
      const bool stoch_ok = (k1 < k2 && k1 > strategy_stoch_floor);
      const bool macd_ok  = (hist_1 < hist_2);   // cross-down OR positive-but-decreasing
      if(rsi_ok && stoch_ok && macd_ok)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopFixedPips(_Symbol, QM_SELL, entry, (int)strategy_sl_pips);
         const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_tp_pips);
         const double tp = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
         if(sl <= 0.0 || tp <= 0.0)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = tp;
         req.reason = "tc_m5_11_short";
         return true;
        }
      return false;
     }

   return false;
  }

// SL/TP only — source has no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — source has no indicator exit (SL/TP handle it).
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
