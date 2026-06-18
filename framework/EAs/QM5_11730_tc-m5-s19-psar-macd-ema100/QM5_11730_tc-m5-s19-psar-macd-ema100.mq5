#property strict
#property version   "5.0"
#property description "QM5_11730 tc-m5-s19-psar-macd-ema100 — slow PSAR flip + MACD(64,128,9) + EMA(100) scalp (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11730 tc-m5-s19-psar-macd-ema100
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   Strategy #19, 2013 (source_id 40a4454c-64ff-5015-8538-9f7b32abc0e9).
// Card: artifacts/cards_approved/QM5_11730_tc-m5-s19-psar-macd-ema100.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE  : LONG  close[1] > EMA(100)[1]
//                  SHORT close[1] < EMA(100)[1]
//   MACD STATE   : LONG  MACD_Main(64,128,9) > 0   (above zero)
//                  SHORT MACD_Main(64,128,9) < 0   (below zero)
//   Trigger EVENT: slow PSAR(0.01,0.01) FLIP — exactly one event/bar.
//                  LONG : dot was above price (bar 2) AND now below price
//                         (bar 1) -> fresh flip to bullish.
//                  SHORT: dot was below price (bar 2) AND now above price
//                         (bar 1) -> fresh flip to bearish.
//   Stop         : sl_buffer_pips (3) beyond the current PSAR dot.
//                  LONG  sl = sar_now - buffer ; SHORT sl = sar_now + buffer.
//   Take profit  : tp_pips fixed (card 7-12; factory default 10).
//   Exit         : fixed SL / fixed TP / opposite PSAR flip before TP/SL.
//   Spread guard : skip only a genuinely wide spread > spread_cap_pips
//                  (fail-open on .DWX zero modeled spread).
//
// The EMA + MACD are STATES; the PSAR flip is the single trigger EVENT. This
// avoids the two-cross-same-bar zero-trade trap (only one fresh event needed).
// Note: PSAR step == max (0.01) is a deliberately very slow constant-rate SAR
// per the card; QM_SAR maps directly onto iSAR(step, maximum).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11730;
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
input double strategy_sar_max            = 0.01;    // PSAR acceleration maximum (== step: slow SAR)
input int    strategy_macd_fast          = 64;      // MACD fast EMA period
input int    strategy_macd_slow          = 128;     // MACD slow EMA period
input int    strategy_macd_signal        = 9;       // MACD signal SMA period
input double strategy_sl_buffer_pips     = 3.0;     // pips beyond the PSAR dot for the stop
input double strategy_tp_pips            = 10.0;    // fixed take-profit (pips; card 7-12)
input double strategy_spread_cap_pips    = 5.0;     // skip if spread wider than this (pips)

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

// One pip in price units (5-digit FX => 0.0001, JPY 3-digit => 0.01).
double StrategyPip()
  {
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double pt = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(pt <= 0.0)
      return 0.0;
   if(digits == 3 || digits == 5)
      return pt * 10.0;
   return pt;
  }

// Detect a fresh PSAR flip on the last closed bar.
//   returns +1 bullish flip (dot above @2 -> below @1)
//           -1 bearish flip (dot below @2 -> above @1)
//            0 no fresh flip / data not ready
int SarFlip()
  {
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar_now <= 0.0 || sar_prev <= 0.0)
      return 0;

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high2 = iHigh(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double low2  = iLow(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return 0;

   if(sar_prev >= high2 && sar_now < low1)   // dot above -> below price
      return +1;
   if(sar_prev <= low2  && sar_now > high1)  // dot below -> above price
      return -1;
   return 0;
  }

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime / signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // Spread guard — only a genuinely wide spread blocks; zero modeled spread
   // (ask == bid on .DWX) passes through.
   const double pip = StrategyPip();
   if(pip > 0.0)
     {
      const double spread = ask - bid;
      if(spread > 0.0 && spread > strategy_spread_cap_pips * pip)
         return true;
     }

   return false;
  }

// Entry. Caller guarantees QM_IsNewBar() == true (closed-bar gate).
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // One open position per symbol/magic.
   if(QM_TM_OpenPositionCount(QM_FrameworkMagic()) > 0)
      return false;

   const double pip = StrategyPip();
   if(pip <= 0.0)
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

   // --- Trigger EVENT: slow PSAR flip on the last closed bar ---
   const int flip = SarFlip();
   if(flip == 0)
      return false;

   const double sar_now = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   if(sar_now <= 0.0)
      return false;

   const bool is_long  = (flip > 0 && close1 > ema && macd > 0.0);
   const bool is_short = (flip < 0 && close1 < ema && macd < 0.0);
   if(!is_long && !is_short)
      return false;

   const double buffer  = strategy_sl_buffer_pips * pip;
   const double tp_dist = strategy_tp_pips * pip;
   if(buffer <= 0.0 || tp_dist <= 0.0)
      return false;

   if(is_long)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      // Stop: buffer pips below the PSAR dot (dot sits below price on a bull flip).
      double sl = sar_now - buffer;
      if(sl >= entry) // degenerate (dot above ask) — fall back to fixed buffer below entry
         sl = entry - buffer;
      req.type   = QM_BUY;
      req.price  = 0.0; // framework fills market price at send
      req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
      req.tp     = QM_StopRulesNormalizePrice(_Symbol, entry + tp_dist);
      req.reason = "tc_s19_psar_flip_long";
      return true;
     }

   // SHORT
   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;
   // Stop: buffer pips above the PSAR dot (dot sits above price on a bear flip).
   double sl = sar_now + buffer;
   if(sl <= entry) // degenerate (dot below bid) — fall back to fixed buffer above entry
      sl = entry + buffer;
   req.type   = QM_SELL;
   req.price  = 0.0;
   req.sl     = QM_StopRulesNormalizePrice(_Symbol, sl);
   req.tp     = QM_StopRulesNormalizePrice(_Symbol, entry - tp_dist);
   req.reason = "tc_s19_psar_flip_short";
   return true;
  }

// Fixed SL/TP only; no active trailing.
void Strategy_ManageOpenPosition()
  {
  }

// Discretionary exit: opposite PSAR flip before TP/SL is hit. Close a long on a
// fresh bearish flip, a short on a fresh bullish flip.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const int flip = SarFlip();
   if(flip == 0)
      return false;

   // Determine current position direction for this magic.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY  && flip < 0)
         return true;   // long held, bearish flip -> exit
      if(ptype == POSITION_TYPE_SELL && flip > 0)
         return true;   // short held, bullish flip -> exit
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
         QM_TM_ClosePosition(ticket, QM_EXIT_OPPOSITE_SIGNAL);
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
