#property strict
#property version   "5.0"
#property description "QM5_11829 carter-m5-s19-psar-macd64128-ema100-m5 — PSAR flip + MACD(64,128,9) + EMA(100) trend (M5)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11829 carter-m5-s19-psar-macd64128-ema100-m5
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "20 Forex Trading Strategies (5 Minute Time Frame)",
//   Strategy 19, self-published 2014.
// Card: artifacts/cards_approved/QM5_11829_carter-m5-s19-psar-macd64128-ema100-m5.md
//   (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1; M5):
//   Trend STATE  : LONG  close[1] > EMA(100)[1]   (price above long-term EMA)
//                  SHORT close[1] < EMA(100)[1]
//   MACD STATE   : LONG  MACD_Main(64,128,9) > 0   (slow MACD above zero line)
//                  SHORT MACD_Main(64,128,9) < 0   (slow MACD below zero line)
//   Trigger EVENT: PSAR FLIP — exactly one event/bar.
//                  LONG : PSAR was >= High[2] (dot above) AND now <  Low[1]
//                         (dot below price) -> fresh flip to bullish.
//                  SHORT: PSAR was <= Low[2]  (dot below) AND now >  High[1]
//                         (dot above price) -> fresh flip to bearish.
//   Stop         : 3 pips beyond the PSAR dot + the dot's distance to close,
//                  capped at sl_cap_pips. (Card: "3 pips below PSAR dot".)
//   Take profit  : tp_pips fixed (card: 7-12 pips; factory uses 10).
//   Spread guard : skip only a genuinely wide spread > spread_cap_pips
//                  (fail-open on .DWX zero modeled spread).
//
// PSAR PARAMS: card says source "0.01-0.01" notation is ambiguous; card
//   resolves it to the factory-standard step=0.02, max=0.2. (Sibling QM5_11558
//   used 0.01/0.10; THIS card mandates the standard 0.02/0.20 set.)
//
// The EMA + MACD are STATES; the PSAR flip is the single trigger EVENT. This
// avoids the two-cross-same-bar zero-trade trap (only one fresh event needed).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11829;
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
input double strategy_sar_step           = 0.02;    // PSAR acceleration step (card standard)
input double strategy_sar_max            = 0.20;    // PSAR acceleration maximum (card standard)
input int    strategy_macd_fast          = 64;      // MACD fast EMA period
input int    strategy_macd_slow          = 128;     // MACD slow EMA period
input int    strategy_macd_signal        = 9;       // MACD signal SMA period
input double strategy_sl_buffer_pips     = 3.0;     // pips beyond PSAR for the stop (card)
input double strategy_sl_cap_pips        = 15.0;    // max stop distance (pips) — tight stop guard
input double strategy_tp_pips            = 10.0;    // fixed take-profit (pips; card 7-12, factory 10)
input double strategy_spread_cap_pips    = 5.0;     // skip if spread wider than this (pips)
input bool   strategy_no_friday_entry    = true;    // block new entries on Friday

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

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard + no-Friday-entry only — regime /
// signal work is on the closed-bar path in Strategy_EntrySignal. Fail-open on
// .DWX zero modeled spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   // No-Friday-entry (card filter). Use broker time -> UTC for a stable DOW.
   if(strategy_no_friday_entry)
     {
      const datetime utc_now = QM_BrokerToUTC(TimeCurrent());
      MqlDateTime dt;
      TimeToStruct(utc_now, dt);
      if(dt.day_of_week == 5) // Friday
         return true;
     }

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

   // --- Trigger EVENT: PSAR flip between bar 2 (prev) and bar 1 (now) ---
   const double sar_now  = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 1);
   const double sar_prev = QM_SAR(_Symbol, _Period, strategy_sar_step, strategy_sar_max, 2);
   if(sar_now <= 0.0 || sar_prev <= 0.0)
      return false;

   const double high1 = iHigh(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double low1  = iLow(_Symbol, _Period, 1);  // perf-allowed: single closed-bar read
   const double high2 = iHigh(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   const double low2  = iLow(_Symbol, _Period, 2);  // perf-allowed: single closed-bar read
   if(high1 <= 0.0 || low1 <= 0.0 || high2 <= 0.0 || low2 <= 0.0)
      return false;

   // Bullish flip: dot was above price (bar 2) and is now below price (bar 1).
   const bool flip_up   = (sar_prev >= high2 && sar_now < low1);
   // Bearish flip: dot was below price (bar 2) and is now above price (bar 1).
   const bool flip_down = (sar_prev <= low2  && sar_now > high1);

   bool is_long  = false;
   bool is_short = false;

   if(flip_up && close1 > ema && macd > 0.0)
      is_long = true;
   else if(flip_down && close1 < ema && macd < 0.0)
      is_short = true;

   if(!is_long && !is_short)
      return false;

   // --- Stop distance: buffer pips beyond the PSAR dot, capped ---
   double stop_dist = strategy_sl_buffer_pips * pip + MathAbs(close1 - sar_now);
   const double cap = strategy_sl_cap_pips * pip;
   if(stop_dist > cap)
      stop_dist = cap;
   if(stop_dist <= 0.0)
      return false;

   const double tp_dist = strategy_tp_pips * pip;
   if(tp_dist <= 0.0)
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
      req.reason = "carter_s19_psar_flip_long";
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
   req.reason = "carter_s19_psar_flip_short";
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
