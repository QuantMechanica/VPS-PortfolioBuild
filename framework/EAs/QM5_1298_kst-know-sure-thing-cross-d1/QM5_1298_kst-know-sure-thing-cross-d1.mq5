#property strict
#property version   "5.0"
#property description "QM5_1298 kst-know-sure-thing-cross-d1 — Pring KST signal-line cross (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_1298 kst-know-sure-thing-cross-d1
// -----------------------------------------------------------------------------
// Source: Martin J. Pring — "Summed Rate of Change (KST)", Stocks & Commodities
//   September 1992 + "Martin Pring on Market Momentum" (McGraw-Hill 1993).
// Card: artifacts/cards_approved/QM5_1298_kst-know-sure-thing-cross-d1.md
//   (g0_status APPROVED).
//
// Mechanics (D1, closed-bar reads; KST computed in-EA from bounded closed-bar
// closes — there is no built-in KST indicator):
//
//   ROC_n(shift)  = (close[shift] - close[shift+n]) / close[shift+n] * 100
//   RCMA1 = SMA_10(ROC_10) , weight 1
//   RCMA2 = SMA_10(ROC_15) , weight 2
//   RCMA3 = SMA_10(ROC_20) , weight 3
//   RCMA4 = SMA_15(ROC_30) , weight 4
//   KST        = 1*RCMA1 + 2*RCMA2 + 3*RCMA3 + 4*RCMA4
//   KST_signal = SMA_9(KST)
//
//   Trigger EVENT (the ONE event — avoids the two-cross-same-bar zero-trade trap):
//     BUY : KST crosses up through KST_signal
//           KST[2] <= signal[2]  AND  KST[1] > signal[1]
//     SELL: KST crosses down through KST_signal
//           KST[2] >= signal[2]  AND  KST[1] < signal[1]
//   Context STATEs (not events — evaluated at the trigger bar, shift 1):
//     BUY : KST[1] > 0  AND  close[1] > EMA(200)
//     SELL: KST[1] < 0  AND  close[1] < EMA(200)
//
//   Stop  : entry -/+ sl_atr_mult * ATR(14)
//   Take  : entry +/- tp_atr_mult * ATR(14)
//   Discretionary exits (Strategy_ExitSignal): KST/signal opposite cross OR
//     KST zero-line opposite cross OR time stop after max_hold_bars closed bars.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything else
// is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1298;
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
// KST component ROC periods (Pring canonical: 10/15/20/30).
input int    strategy_roc1_period       = 10;
input int    strategy_roc2_period       = 15;
input int    strategy_roc3_period       = 20;
input int    strategy_roc4_period       = 30;
// KST component smoothing SMA periods (Pring canonical: 10/10/10/15).
input int    strategy_rcma1_period      = 10;
input int    strategy_rcma2_period      = 10;
input int    strategy_rcma3_period      = 10;
input int    strategy_rcma4_period      = 15;
// Fixed integer component weights (transparent coefficient table, NOT ML).
input int    strategy_kst_weight1       = 1;
input int    strategy_kst_weight2       = 2;
input int    strategy_kst_weight3       = 3;
input int    strategy_kst_weight4       = 4;
input int    strategy_signal_period     = 9;      // SMA(KST) signal line (P3-sweep 7-14)
input int    strategy_ema_bias_period   = 200;    // long-term-trend bias filter
input int    strategy_atr_period        = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult       = 1.5;    // stop distance = mult * ATR (P3 1.0-2.5)
input double strategy_tp_atr_mult       = 3.0;    // target distance = mult * ATR (P3 2.0-4.5)
input int    strategy_max_hold_bars     = 30;     // time stop: close after N closed bars
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// File-scope time-stop bookkeeping: bar-open time of the bar at which the open
// position was entered. 0 = no tracked position.
datetime g_entry_bar_time = 0;

// -----------------------------------------------------------------------------
// KST computation helpers (closed-bar, bounded lookback — perf-allowed).
// All reads gated upstream by QM_IsNewBar; max close shift is small (~roc4+rcma4
// +signal+1 ≈ 54) so the chain is O(1) per closed bar.
// -----------------------------------------------------------------------------

// Rate of change in percent at a given closed-bar shift.
double KST_ROC(const int period, const int shift)
  {
   const double c_now  = iClose(_Symbol, _Period, shift);          // perf-allowed
   const double c_then = iClose(_Symbol, _Period, shift + period); // perf-allowed
   if(c_then <= 0.0)
      return 0.0;
   return (c_now - c_then) / c_then * 100.0;
  }

// Simple MA of ROC(period) over `smooth` consecutive closed bars ending at `shift`.
double KST_RCMA(const int roc_period, const int smooth, const int shift)
  {
   if(smooth <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < smooth; ++i)
      sum += KST_ROC(roc_period, shift + i);
   return sum / smooth;
  }

// Full KST value at a given closed-bar shift.
double KST_Value(const int shift)
  {
   const double rcma1 = KST_RCMA(strategy_roc1_period, strategy_rcma1_period, shift);
   const double rcma2 = KST_RCMA(strategy_roc2_period, strategy_rcma2_period, shift);
   const double rcma3 = KST_RCMA(strategy_roc3_period, strategy_rcma3_period, shift);
   const double rcma4 = KST_RCMA(strategy_roc4_period, strategy_rcma4_period, shift);
   return strategy_kst_weight1 * rcma1 +
          strategy_kst_weight2 * rcma2 +
          strategy_kst_weight3 * rcma3 +
          strategy_kst_weight4 * rcma4;
  }

// KST signal line = SMA over `strategy_signal_period` KST values ending at `shift`.
double KST_Signal(const int shift)
  {
   const int n = strategy_signal_period;
   if(n <= 0)
      return 0.0;
   double sum = 0.0;
   for(int i = 0; i < n; ++i)
      sum += KST_Value(shift + i);
   return sum / n;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — KST work is on the closed-bar
// path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to entry gate, do not block here

   const double stop_distance = strategy_sl_atr_mult * atr_value;
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

   // --- KST + signal at the last two closed bars (shift 1 = trigger bar) ---
   const double kst1 = KST_Value(1);
   const double kst2 = KST_Value(2);
   const double sig1 = KST_Signal(1);
   const double sig2 = KST_Signal(2);

   // --- Bias filter: close vs EMA(200) on the trigger bar ---
   const double ema_bias = QM_EMA(_Symbol, _Period, strategy_ema_bias_period, 1);
   if(ema_bias <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   // --- BUY: bullish signal-line cross (the ONE EVENT) + KST>0 + above EMA200 ---
   const bool cross_up   = (kst2 <= sig2 && kst1 > sig1);
   if(cross_up && kst1 > 0.0 && close1 > ema_bias)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_BUY, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "kst_signal_cross_long";
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // current (forming) bar open
      return true;
     }

   // --- SELL: bearish signal-line cross (the ONE EVENT) + KST<0 + below EMA200 ---
   const bool cross_down = (kst2 >= sig2 && kst1 < sig1);
   if(cross_down && kst1 < 0.0 && close1 < ema_bias)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_sl_atr_mult);
      const double tp = QM_TakeATRFromValue(_Symbol, QM_SELL, entry, atr_value, strategy_tp_atr_mult);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "kst_signal_cross_short";
      g_entry_bar_time = iTime(_Symbol, _Period, 0); // current (forming) bar open
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop/target. Discretionary
// exits live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: KST/signal opposite cross, KST zero-line opposite cross,
// or time stop. Direction-aware against the held position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   // Resolve current position direction for this EA's magic.
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
      break;
     }
   if(!is_long && !is_short)
      return false;

   const double kst1 = KST_Value(1);
   const double kst2 = KST_Value(2);
   const double sig1 = KST_Signal(1);
   const double sig2 = KST_Signal(2);

   const bool cross_down = (kst2 >= sig2 && kst1 < sig1); // bearish signal cross
   const bool cross_up   = (kst2 <= sig2 && kst1 > sig1); // bullish signal cross
   const bool zero_down  = (kst2 >= 0.0  && kst1 < 0.0);  // KST crosses below zero
   const bool zero_up    = (kst2 <= 0.0  && kst1 > 0.0);  // KST crosses above zero

   if(is_long  && (cross_down || zero_down))
      return true;
   if(is_short && (cross_up   || zero_up))
      return true;

   // Time stop: close after strategy_max_hold_bars closed bars since entry.
   if(g_entry_bar_time > 0 && strategy_max_hold_bars > 0)
     {
      const datetime cur_bar = iTime(_Symbol, _Period, 0); // current forming bar open
      const int secs_per_bar = PeriodSeconds(_Period);
      if(secs_per_bar > 0)
        {
         const int bars_held = (int)((cur_bar - g_entry_bar_time) / secs_per_bar);
         if(bars_held >= strategy_max_hold_bars)
            return true;
        }
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      g_entry_bar_time = 0;
     }

   if(!QM_IsNewBar())
      return;

   QM_EquityStreamOnNewBar();

   // Clear stale time-stop bookkeeping if the position closed via SL/TP.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      g_entry_bar_time = 0;

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
