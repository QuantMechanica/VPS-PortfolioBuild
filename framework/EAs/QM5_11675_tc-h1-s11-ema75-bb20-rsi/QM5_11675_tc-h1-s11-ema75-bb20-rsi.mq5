#property strict
#property version   "5.0"
#property description "QM5_11675 tc-h1-s11-ema75-bb20-rsi — EMA75 trend + BB20 mid-cross + RSI (H1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11675 tc-h1-s11-ema75-bb20-rsi
// -----------------------------------------------------------------------------
// Source: Thomas Carter, "Forex Trading Strategy #11", in: 20 Forex Trading
// Strategies Collection (H1), self-published 2014.
// Card: artifacts/cards_approved/QM5_11675_tc-h1-s11-ema75-bb20-rsi.md (APPROVED).
//
// Mechanics (closed-bar reads at shift 1; H1):
//   Trend STATE  : close vs EMA(trend_period). Long needs close > EMA75,
//                  short needs close < EMA75.
//   Momentum STATE: RSI(rsi_period) vs 50. Long needs RSI > 50, short RSI < 50.
//   Trigger EVENT: price CROSSES the BB(period,dev) MIDDLE band (the 20-SMA).
//                  Long  = close[2] <= mid[2] AND close[1] > mid[1]
//                  Short = close[2] >= mid[2] AND close[1] < mid[1]
//                  Exactly ONE cross event drives entry; EMA75 and RSI are
//                  confirming states evaluated on the same closed bar. This
//                  deliberately avoids the two-cross-same-bar zero-trade trap:
//                  the EMA/RSI conditions are level states, never fresh crosses.
//   Stop         : QM_StopATR(period=atr, mult=sl_atr_mult).
//   Take profit  : QM_TakeRR(rr = tp_rr) — reward:risk multiple off the stop.
//   Exit         : managed purely by the ATR stop / RR target (no discretionary
//                  exit). One position per magic.
//
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific. Everything
// else is framework wiring and MUST stay intact.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11675;
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
input int    strategy_ema_trend_period  = 75;     // macro trend anchor EMA
input int    strategy_bb_period          = 20;    // Bollinger middle = 20-SMA
input double strategy_bb_deviation       = 2.0;   // BB deviation (mid band uses SMA; arg mandatory)
input int    strategy_rsi_period         = 14;    // RSI lookback
input double strategy_rsi_mid_level      = 50.0;  // RSI momentum threshold
input int    strategy_atr_period         = 14;    // ATR period for the stop
input double strategy_sl_atr_mult        = 2.0;   // stop distance = mult * ATR
input double strategy_tp_rr              = 2.0;   // take-profit reward:risk multiple
input double strategy_spread_pct_of_stop = 15.0; // skip if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Spread guard only — fail-open on .DWX zero spread.
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

   // --- Closed-bar reads (shift 1 = last closed bar, shift 2 = prior) ---
   const double ema_trend = QM_EMA(_Symbol, _Period, strategy_ema_trend_period, 1);
   if(ema_trend <= 0.0)
      return false;

   const double mid_now  = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 1);
   const double mid_prev = QM_BB_Middle(_Symbol, _Period, strategy_bb_period, strategy_bb_deviation, 2);
   if(mid_now <= 0.0 || mid_prev <= 0.0)
      return false;

   const double close_now  = iClose(_Symbol, _Period, 1); // perf-allowed: single closed-bar read
   const double close_prev = iClose(_Symbol, _Period, 2); // perf-allowed: single closed-bar read
   if(close_now <= 0.0 || close_prev <= 0.0)
      return false;

   const double rsi_now = QM_RSI(_Symbol, _Period, strategy_rsi_period, 1);
   if(rsi_now <= 0.0)
      return false;

   // --- Trigger EVENT: close crosses the BB middle band on the last closed bar.
   //     States (EMA75 side, RSI side) confirm; they are NOT cross events. ---
   const bool cross_up   = (close_prev <= mid_prev && close_now > mid_now);
   const bool cross_down = (close_prev >= mid_prev && close_now < mid_now);

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;
   const double entry_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry_bid <= 0.0)
      return false;

   // --- Long: cross up + price above EMA75 (trend) + RSI above mid (momentum) ---
   if(cross_up && close_now > ema_trend && rsi_now > strategy_rsi_mid_level)
     {
      const double sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_BUY, entry, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema75_bbmid_rsi_long";
      return true;
     }

   // --- Short: cross down + price below EMA75 (trend) + RSI below mid ---
   if(cross_down && close_now < ema_trend && rsi_now < strategy_rsi_mid_level)
     {
      const double sl = QM_StopATR(_Symbol, QM_SELL, entry_bid, strategy_atr_period, strategy_sl_atr_mult);
      const double tp = QM_TakeRR(_Symbol, QM_SELL, entry_bid, sl, strategy_tp_rr);
      if(sl <= 0.0 || tp <= 0.0)
         return false;
      req.type   = QM_SELL;
      req.price  = 0.0;
      req.sl     = sl;
      req.tp     = tp;
      req.reason = "ema75_bbmid_rsi_short";
      return true;
     }

   return false;
  }

// No active management beyond the fixed ATR stop / RR target.
void Strategy_ManageOpenPosition()
  {
  }

// No discretionary exit — the ATR stop and RR take-profit own the exit.
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
