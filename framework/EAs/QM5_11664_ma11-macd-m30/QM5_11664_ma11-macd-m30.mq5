#property strict
#property version   "5.0"
#property description "QM5_11664 ma11-macd-m30 — MA(11) price-cross + MACD-direction filter (M30)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11664 ma11-macd-m30
// -----------------------------------------------------------------------------
// Source: Anonymous, "Moving Average Intraday System", in 9 Forex Systems
//   (MoneyTec compilation, ~2006). R1 FAIL (anonymous forum), R2/R3/R4 PASS.
// Card: artifacts/cards_approved/QM5_11664_ma11-macd-m30.md (g0_status APPROVED).
//
// Mechanics (M30, closed-bar reads):
//   Trend STATE  : MACD main line direction (filter).
//                  Long requires MACD main > 0; short requires MACD main < 0.
//   Trigger EVENT: Close crosses the SMA(11) (ONE event).
//                  Long  = Close crossed ABOVE SMA(11);
//                  Short = Close crossed BELOW SMA(11).
//   1-bar confirm: per the source ("wait at least one more candle before
//                  entering"). The cross is detected on the signal bar
//                  (shift 3 -> shift 2); the confirmation bar is shift 1 and
//                  must still be on the correct side of SMA(11). Entry fires
//                  at the next bar open. The MACD cross is NOT a second event:
//                  MACD is a STATE, so we never need two fresh crosses on the
//                  same bar (avoids the two-cross zero-trade trap).
//   Stop         : 2 * ATR(14) factory default.
//   Exit         : price crosses back through SMA(11) in the opposite
//                  direction (defensive manual exit).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11664;
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
input int    strategy_ma_period          = 11;     // price-cross moving average (SMA)
input int    strategy_macd_fast          = 12;     // MACD fast EMA
input int    strategy_macd_slow          = 26;     // MACD slow EMA
input int    strategy_macd_signal        = 9;      // MACD signal EMA
input int    strategy_atr_period         = 14;     // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;    // stop distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work lives in
// Strategy_EntrySignal on the closed-bar path. Fail-open on .DWX zero spread.
bool Strategy_NoTradeFilter()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

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

   // Closed-bar SMA(11) values at the signal bar (shift 2) and the bar before
   // it (shift 3) to detect the cross EVENT, plus the confirmation bar (shift 1).
   const double ma_s1 = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   const double ma_s2 = QM_SMA(_Symbol, _Period, strategy_ma_period, 2);
   const double ma_s3 = QM_SMA(_Symbol, _Period, strategy_ma_period, 3);
   if(ma_s1 <= 0.0 || ma_s2 <= 0.0 || ma_s3 <= 0.0)
      return false;

   const double close_s1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read (confirm)
   const double close_s2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read (signal)
   const double close_s3 = iClose(_Symbol, _Period, 3); // perf-allowed: single closed-bar read (pre-signal)
   if(close_s1 <= 0.0 || close_s2 <= 0.0 || close_s3 <= 0.0)
      return false;

   // MACD main-line direction STATE on the confirmation bar (shift 1).
   const double macd_main = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast, strategy_macd_slow,
                                         strategy_macd_signal, 1, PRICE_CLOSE);

   // --- Cross EVENT on the signal bar: shift 3 below -> shift 2 above ---
   const bool crossed_up   = (close_s3 < ma_s3 && close_s2 > ma_s2);
   const bool crossed_down = (close_s3 > ma_s3 && close_s2 < ma_s2);

   // --- 1-bar confirmation: side must still hold on the confirmation bar ---
   const bool confirm_up   = (close_s1 > ma_s1);
   const bool confirm_down = (close_s1 < ma_s1);

   // LONG: fresh upward cross, still above on confirm bar, MACD main > 0.
   if(crossed_up && confirm_up && macd_main > 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // no fixed target; exit on opposite MA cross
      req.reason = "ma11_cross_up_macd_pos";
      return true;
     }

   // SHORT: fresh downward cross, still below on confirm bar, MACD main < 0.
   if(crossed_down && confirm_down && macd_main < 0.0)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATR(_Symbol, QM_SELL, entry, strategy_atr_period, strategy_sl_atr_mult);
      if(sl <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = 0.0;
      req.reason = "ma11_cross_down_macd_neg";
      return true;
     }

   return false;
  }

// No active trade management beyond the fixed ATR stop. Exit handled in
// Strategy_ExitSignal (price crossing back through the MA).
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: price crosses back through SMA(11) against the open side.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double ma_s1 = QM_SMA(_Symbol, _Period, strategy_ma_period, 1);
   const double ma_s2 = QM_SMA(_Symbol, _Period, strategy_ma_period, 2);
   if(ma_s1 <= 0.0 || ma_s2 <= 0.0)
      return false;

   const double close_s1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_s2 = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close_s1 <= 0.0 || close_s2 <= 0.0)
      return false;

   // Determine the open side from the position(s) under this magic.
   bool have_long  = false;
   bool have_short = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
         have_long = true;
      else if(ptype == POSITION_TYPE_SELL)
         have_short = true;
     }

   // Cross-back EVENT: above->below closes a long; below->above closes a short.
   const bool crossed_down = (close_s2 > ma_s2 && close_s1 < ma_s1);
   const bool crossed_up   = (close_s2 < ma_s2 && close_s1 > ma_s1);

   if(have_long && crossed_down)
      return true;
   if(have_short && crossed_up)
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
