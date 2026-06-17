#property strict
#property version   "5.0"
#property description "QM5_11220 ft-multirsi — Freqtrade Multi-RSI MTF mean-reversion (long-only, M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11220 ft-multirsi
// -----------------------------------------------------------------------------
// Source: freqtrade-strategies "MultiRSI.py" (Gert Wohlgemuth, based on Creslin),
//         commit dbd5b0b21cfbf5ee80588d37458ace2467b7f8a4.
// Card: artifacts/cards_approved/QM5_11220_ft-multirsi.md (g0_status APPROVED).
//
// Mechanics (long-only, closed-bar reads at shift 1; base TF M5):
//   Trend  STATE : SMA(fast) >= SMA(slow) on the M5 base frame.
//   Dislocation  : M5 RSI < (HTF-slow RSI - rsi_gap).
//   Trigger EVENT: that dislocation becomes TRUE on this bar but was FALSE on the
//                  prior bar (one fresh event/bar). The trend gate + the HTF RSI
//                  level are STATES; only the dislocation crossing is the EVENT,
//                  per the .DWX "don't require two cross EVENTs" invariant.
//   Exit   STATE : M5 RSI > M10 RSI  AND  M5 RSI > HTF-slow RSI (source ROI exit).
//   Take profit  : entry + roi_pct (source ROI = 1% immediate).
//   Stop         : QM_StopATR(atr_period, atr_stop_mult); never wider than the
//                  source -5% disaster cap (clamped tighter if ATR stop exceeds it).
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX 0 spread).
//
// MTF NOTE (ported): the source resamples to M10 and M40. MT5 has a native
//   PERIOD_M10 but NO PERIOD_M40 (valid minute frames stop at M30, next is H1).
//   The M40 RSI is therefore read on the nearest native frame PERIOD_M30. This
//   is a deliberate port — see SPEC.md / open_questions in the build result.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11220;
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
input int    strategy_rsi_period        = 14;     // RSI period (all timeframes)
input double strategy_rsi_gap           = 20.0;   // M5 RSI must be this far below the HTF-slow RSI
input int    strategy_sma_fast          = 5;      // fast SMA (trend gate) on M5
input int    strategy_sma_slow          = 200;    // slow SMA (trend gate) on M5
input int    strategy_atr_period        = 14;     // ATR period for the stop
input double strategy_atr_stop_mult     = 1.5;    // stop distance = mult * ATR
input double strategy_roi_pct           = 1.0;    // take-profit, percent of entry (source ROI)
input double strategy_disaster_cap_pct  = 5.0;    // max stop distance, percent of entry (source -5%)
input double strategy_spread_pct_of_stop = 15.0;  // skip if spread > this % of stop distance

// Mid (M10) and slow (M40 -> nearest native M30) higher-timeframe RSI frames.
#define QM_MULTIRSI_TF_MID   PERIOD_M10
#define QM_MULTIRSI_TF_SLOW  PERIOD_M30   // M40 ported to nearest native MT5 frame

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only; regime/signal work is on the
// closed-bar path. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Only a genuinely wide spread blocks; zero/negative modeled spread passes.
   if(spread > 0.0 && spread > (strategy_spread_pct_of_stop / 100.0) * stop_distance)
      return true;

   return false;
  }

// Long-only entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   // --- Trend STATE: fast SMA >= slow SMA on the M5 base frame (closed bar). ---
   const double sma_fast = QM_SMA(_Symbol, _Period, strategy_sma_fast, 1);
   const double sma_slow = QM_SMA(_Symbol, _Period, strategy_sma_slow, 1);
   if(sma_fast <= 0.0 || sma_slow <= 0.0)
      return false; // SMA200 not warmed up yet
   if(!(sma_fast >= sma_slow))
      return false;

   // --- Multi-TF RSI STATES (closed bars). M40 read on nearest native M30. ---
   const double rsi_m5_now  = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_m5_prev = QM_RSI(_Symbol, _Period, strategy_rsi_period, 2);
   const double rsi_slow_now  = QM_RSI(_Symbol, QM_MULTIRSI_TF_SLOW, strategy_rsi_period, 1);
   const double rsi_slow_prev = QM_RSI(_Symbol, QM_MULTIRSI_TF_SLOW, strategy_rsi_period, 2);
   if(rsi_m5_now <= 0.0 || rsi_m5_prev <= 0.0 || rsi_slow_now <= 0.0 || rsi_slow_prev <= 0.0)
      return false; // HTF RSI not warmed up yet

   // --- Trigger EVENT: dislocation becomes true on this bar, false on the last.
   //     dislocated := M5 RSI < (slow RSI - gap). The trend gate + RSI levels are
   //     STATES; only the fresh crossing into dislocation is the EVENT. ---
   const bool disloc_now  = (rsi_m5_now  < (rsi_slow_now  - strategy_rsi_gap));
   const bool disloc_prev = (rsi_m5_prev < (rsi_slow_prev - strategy_rsi_gap));
   if(!(disloc_now && !disloc_prev))
      return false;

   // --- Build the long entry. Framework sizes lots (NO lots field). ---
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   // Stop: ATR-derived, clamped no wider than the source -5% disaster cap.
   double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_stop_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;
   const double cap_dist = entry * (strategy_disaster_cap_pct / 100.0);
   const double min_sl   = entry - cap_dist; // tightest allowed (widest stop) floor
   if(sl < min_sl)
      sl = QM_TM_NormalizePrice(_Symbol, min_sl); // clamp tighter than -5%
   if(sl <= 0.0 || sl >= entry)
      return false;

   // Take profit: source ROI 1% immediate target above entry.
   const double tp = QM_TM_NormalizePrice(_Symbol, entry * (1.0 + strategy_roi_pct / 100.0));
   if(tp <= entry)
      return false;

   req.type   = QM_BUY;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = "ft_multirsi_long";
   return true;
  }

// No active trade management beyond the fixed ATR stop / ROI target and the
// RSI-recovery exit in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Source signal exit STATE: M5 RSI > M10 RSI AND M5 RSI > M40(M30) RSI.
bool Strategy_ExitSignal()
  {
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) <= 0)
      return false;

   const double rsi_m5   = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   const double rsi_mid  = QM_RSI(_Symbol, QM_MULTIRSI_TF_MID,  strategy_rsi_period, 1);
   const double rsi_slow = QM_RSI(_Symbol, QM_MULTIRSI_TF_SLOW, strategy_rsi_period, 1);
   if(rsi_m5 <= 0.0 || rsi_mid <= 0.0 || rsi_slow <= 0.0)
      return false;

   return (rsi_m5 > rsi_mid && rsi_m5 > rsi_slow);
  }

// Defer to the central two-axis news filter.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11220\",\"slug\":\"ft-multirsi\"}");
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
