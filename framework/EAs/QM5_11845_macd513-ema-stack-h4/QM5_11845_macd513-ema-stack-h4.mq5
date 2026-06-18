#property strict
#property version   "5.0"
#property description "QM5_11845 macd513-ema-stack-h4 — MACD(5,13,1) zero-cross + EMA(21) trend filter (H4)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11845 macd513-ema-stack-h4
// -----------------------------------------------------------------------------
// Source: forexstrategiesresources.com user post, "4-Hour MACD Forex Strategy"
//         (~2007). Source PDF 136212376-4-Hour-MACD-Forex-Strategy.pdf.
// Card: artifacts/cards_approved/QM5_11845_macd513-ema-stack-h4.md (g0_status APPROVED).
//
// Mechanics (closed-bar reads at shift 1/2 on H4):
//   Trend STATE  : close(1) vs EMA(trend_period). Above => long bias,
//                  below => short bias. (The card's EMA(21) directional filter.)
//   Trigger EVENT: MACD(5,13,1) MAIN line crosses zero. ONE fresh cross per bar
//                  is the trigger; the EMA filter is a STATE, never a second
//                  event on the same bar (avoids the two-cross zero-trade trap).
//                  With signal=1 the signal line is a 1-bar EMA of the MACD line,
//                  so the MAIN-line zero-cross is the card's "histogram" zero-cross.
//   Long  : close(1) > EMA(trend)  AND  MACD main crosses up   through 0.
//   Short : close(1) < EMA(trend)  AND  MACD main crosses down through 0.
//   Stop  : sl_atr_mult * ATR(atr_period) from entry.
//   Take  : tp_atr_mult * ATR(atr_period) from entry (same ATR value as stop).
//   Defensive exit: MACD main crosses zero back in the opposite direction.
//   Spread guard : skip only a genuinely wide spread (fail-open on .DWX zero
//                  modeled spread).
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11845;
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
input int    strategy_macd_fast_period   = 5;      // MACD fast EMA
input int    strategy_macd_slow_period   = 13;     // MACD slow EMA
input int    strategy_macd_signal_period = 1;      // MACD signal EMA
input int    strategy_trend_ema_period   = 21;     // directional trend filter EMA
input int    strategy_atr_period         = 14;     // ATR period (stop / target)
input double strategy_sl_atr_mult        = 2.0;    // stop distance  = mult * ATR
input double strategy_tp_atr_mult        = 4.0;    // target distance = mult * ATR
input double strategy_spread_pct_of_stop = 15.0;   // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — regime/signal work is on the
// closed-bar path in Strategy_EntrySignal. Fail-open on .DWX zero spread.
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

   // --- MACD(5,13,1) MAIN line: prev at shift 2, now at shift 1 ---
   const double macd_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);
   const bool cross_up   = (macd_prev <= 0.0 && macd_now > 0.0); // single EVENT
   const bool cross_down = (macd_prev >= 0.0 && macd_now < 0.0); // single EVENT
   if(!cross_up && !cross_down)
      return false;

   // --- Trend STATE: close(1) vs EMA(trend). Filter, not a second event. ---
   const double ema_trend = QM_EMA(_Symbol, _Period, strategy_trend_ema_period, 1);
   if(ema_trend <= 0.0)
      return false;
   const double close1 = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   if(close1 <= 0.0)
      return false;

   const double atr_value = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false;

   QM_OrderType dir;
   if(cross_up && close1 > ema_trend)
      dir = QM_BUY;
   else if(cross_down && close1 < ema_trend)
      dir = QM_SELL;
   else
      return false; // cross direction and trend bias disagree — no trade

   // --- Build entry. Framework sizes lots (no lots field). ---
   const double entry = (dir == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, dir, entry, atr_value, strategy_sl_atr_mult);
   const double tp = QM_TakeATRFromValue(_Symbol, dir, entry, atr_value, strategy_tp_atr_mult);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type   = dir;
   req.price  = 0.0;   // framework fills market price at send
   req.sl     = sl;
   req.tp     = tp;
   req.reason = (dir == QM_BUY) ? "macd513_zero_cross_long" : "macd513_zero_cross_short";
   return true;
  }

// No active trade management beyond the fixed ATR stop/target. The defensive
// MACD-reversal exit lives in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Defensive exit: MACD main line crosses zero back against the open position.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double macd_now  = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 1);
   const double macd_prev = QM_MACD_Main(_Symbol, _Period,
                                         strategy_macd_fast_period,
                                         strategy_macd_slow_period,
                                         strategy_macd_signal_period, 2);

   const bool cross_up   = (macd_prev <= 0.0 && macd_now > 0.0);
   const bool cross_down = (macd_prev >= 0.0 && macd_now < 0.0);
   if(!cross_up && !cross_down)
      return false;

   // Determine the open direction; exit only on an opposite-direction cross.
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket))
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      const long ptype = PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && cross_down)
         return true;
      if(ptype == POSITION_TYPE_SELL && cross_up)
         return true;
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
