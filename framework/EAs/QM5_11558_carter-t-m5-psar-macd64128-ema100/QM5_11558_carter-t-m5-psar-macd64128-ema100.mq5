#property strict
#property version   "5.0"
#property description "QM5_11558 carter-t-m5-psar-macd64128-ema100 - PSAR + MACD(64,128,9) + EMA(100) trend (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA - QM5_11558 carter-t-m5-psar-macd64128-ema100
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   System #19, self-published 2014.
// Card: artifacts/cards_approved/QM5_11558_carter-t-m5-psar-macd64128-ema100.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE  : LONG  close[1] > EMA(100)[1]
//                  SHORT close[1] < EMA(100)[1]
//   MACD STATE   : LONG  MACD_Main(64,128,9) > 0   (above zero)
//                  SHORT MACD_Main(64,128,9) < 0   (below zero)
//   PSAR STATE   : LONG  PSAR(0.01,0.1)[1] < Low[1]
//                  SHORT PSAR(0.01,0.1)[1] > High[1]
//   Stop         : 3 pips + |close[1] - PSAR[1]|, capped at sl_cap_pips (15).
//   Take profit  : tp_pips (9) fixed.
//   Spread guard : skip only a genuinely wide spread > spread_cap_pips
//                  (fail-open on .DWX zero modeled spread).
//   No-Friday-entry: per card; broker-time day-of-week gate.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11558;
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
input int    strategy_ema_period         = 100;     // trend-filter EMA period
input double strategy_sar_step           = 0.01;    // PSAR acceleration step
input double strategy_sar_max            = 0.10;    // PSAR acceleration maximum
input int    strategy_macd_fast          = 64;      // MACD fast EMA period
input int    strategy_macd_slow          = 128;     // MACD slow EMA period
input int    strategy_macd_signal        = 9;       // MACD signal SMA period
input int    strategy_sl_buffer_pips     = 3;       // pips beyond PSAR for the stop
input int    strategy_sl_cap_pips        = 15;      // max stop distance (pips)
input int    strategy_tp_pips            = 9;       // fixed take-profit (pips)
input int    strategy_spread_cap_pips    = 5;       // skip if spread wider than this (pips)
input bool   strategy_no_friday_entry    = true;    // block new entries on Friday

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only - regime /
// signal work is on the closed-bar path in Strategy_EntrySignal. Fail-open on
// .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet - do not block on it

   // Spread guard - only a genuinely wide spread blocks; zero modeled spread
   // (ask == bid on .DWX) passes through.
   const double spread_cap = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_spread_cap_pips);
   if(spread_cap > 0.0)
     {
      const double spread = ask - bid;
      if(spread > 0.0 && spread > spread_cap)
         return true;
     }

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

   if(strategy_no_friday_entry)
     {
      MqlDateTime dt;
      TimeToStruct(TimeCurrent(), dt);
      if(dt.day_of_week == 5)
         return false;
     }

   const double buffer_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_buffer_pips);
   const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_sl_cap_pips);
   const double tp_dist = QM_StopRulesPipsToPriceDistance(_Symbol, strategy_tp_pips);
   if(buffer_dist <= 0.0 || cap_dist <= 0.0 || tp_dist <= 0.0)
      return false;

   // --- Trend STATE: close[1] vs EMA(100)[1] ---
   const double ema = QM_EMA(_Symbol, _Period, strategy_ema_period, 1);
   if(ema <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   // --- MACD STATE: MACD_Main zero-side (64,128,9) ---
   const double macd = QM_MACD_Main(_Symbol, _Period, strategy_macd_fast,
                                    strategy_macd_slow, strategy_macd_signal, 1);

   // --- PSAR STATE: dot below/above the closed signal bar ---
   const double sar_now = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar_now <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   if(high1 <= 0.0 || low1 <= 0.0)
      return false;

   bool is_long  = false;
   bool is_short = false;

   if(close1 > ema && sar_now < low1 && macd > 0.0)
      is_long = true;
   else if(close1 < ema && sar_now > high1 && macd < 0.0)
      is_short = true;

   if(!is_long && !is_short)
      return false;

   // --- Stop distance: buffer pips beyond the PSAR dot, capped ---
   double stop_dist = buffer_dist + MathAbs(close1 - sar_now);
   if(stop_dist > cap_dist)
      stop_dist = cap_dist;
   if(stop_dist <= 0.0)
      return false;

   if(is_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, entry - stop_dist);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
      req.reason = "carter_psar_flip_long";
      return true;
     }

   // SHORT
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, entry + stop_dist);
   req.tp     = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
   req.reason = "carter_psar_flip_short";
   return true;
  }

// Fixed SL/TP only; no active management.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit beyond the fixed SL/TP set at entry.
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
