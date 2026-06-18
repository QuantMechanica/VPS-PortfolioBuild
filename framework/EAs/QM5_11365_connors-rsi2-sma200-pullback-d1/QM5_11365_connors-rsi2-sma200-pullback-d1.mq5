#property strict
#property version   "5.0"
#property description "QM5_11365 connors-rsi2-sma200-pullback-d1 — Connors RSI(2) mean reversion (D1)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11365 connors-rsi2-sma200-pullback-d1
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "Short-Term Trading Strategies That
//         Work" (2009), "The 2 Period RSI". source_id 52847e5c-...-2979d92.
// Card: artifacts/cards_approved/QM5_11365_connors-rsi2-sma200-pullback-d1.md
//       (g0_status APPROVED).
//
// Mechanics (D1, all reads on CLOSED bars at shift >= 1):
//   Trend STATE  : close > SMA(200)  -> macro uptrend  (mirror for downtrend).
//   Entry EVENT  : RSI(2) crosses INTO the extreme on the prior closed bar:
//                  LONG  -> rsi@1 < entry_long  AND  rsi@2 >= entry_long.
//                  SHORT -> rsi@1 > entry_short AND  rsi@2 <= entry_short.
//                  The SMA200 trend is the STATE; the RSI(2) extreme cross is
//                  the single EVENT (card NOTE). Modelling it as a cross (not a
//                  level test) avoids re-firing on every bar RSI stays extreme.
//   Stop         : entry -/+ atr_stop_mult * ATR(14)  (card: ATR x 1.5).
//   Exit         : RSI(2) reverts past the exit level (LONG rsi > exit_long,
//                  SHORT rsi < exit_short), OR the macro trend breaks
//                  (LONG close < SMA200, SHORT close > SMA200). Connors exit.
//   Spread guard : fail-OPEN — block only a genuinely wide spread (.DWX quotes
//                  ask==bid, modeled spread 0; never block on zero spread).
//
// One position per magic. RISK_FIXED in backtest, RISK_PERCENT for live.
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11365;
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
input ENUM_TIMEFRAMES strategy_timeframe        = PERIOD_D1;  // card TF = D1
input int    strategy_rsi_period         = 2;     // Connors RSI(2)
input int    strategy_sma_trend_period   = 200;   // SMA(200) macro trend filter
input int    strategy_atr_period         = 14;    // ATR for the protective stop
input double strategy_entry_rsi_long     = 10.0;  // RSI(2) < this -> oversold pullback (long)
input double strategy_entry_rsi_short    = 90.0;  // RSI(2) > this -> overbought rally (short)
input double strategy_exit_rsi_long      = 65.0;  // RSI(2) > this -> exit long (Connors)
input double strategy_exit_rsi_short     = 35.0;  // RSI(2) < this -> exit short (mirror)
input double strategy_atr_stop_mult      = 1.5;   // stop distance = mult * ATR(14)
input bool   strategy_enable_shorts      = true;  // mirror shorts below SMA200
input double strategy_spread_pct_of_stop = 15.0;  // block only if spread > this % of stop distance

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

// Cheap O(1) per-tick gate. Wrong-timeframe guard + fail-OPEN spread guard.
bool Strategy_NoTradeFilter()
  {
   // D1-native strategy: refuse to trade if attached to a non-D1 chart.
   if(_Period != strategy_timeframe)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false; // no valid quote yet — do not block on it

   const double atr_value = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(atr_value <= 0.0)
      return false; // no ATR yet — defer to the entry gate, do not block here

   const double stop_distance = strategy_atr_stop_mult * atr_value;
   if(stop_distance <= 0.0)
      return false;

   const double spread = ask - bid;
   // Fail-OPEN: only a genuinely wide spread blocks; zero/negative passes.
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

   // Closed-bar reads (shift 1 = last closed bar, shift 2 = the one before).
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed-bar read
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double atr     = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   const double rsi_1   = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double rsi_2   = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 2);
   if(close_1 <= 0.0 || sma_200 <= 0.0 || atr <= 0.0 || rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   // LONG: macro uptrend STATE + RSI(2) crosses INTO the oversold extreme EVENT.
   const bool long_trend = (close_1 > sma_200);
   const bool long_event = (rsi_1 < strategy_entry_rsi_long &&
                            rsi_2 >= strategy_entry_rsi_long);
   if(long_trend && long_event)
     {
      const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if(entry <= 0.0)
         return false;
      const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_stop_mult);
      if(sl <= 0.0 || sl >= entry)
         return false;
      req.type   = QM_BUY;
      req.price  = 0.0;   // framework fills market price at send
      req.sl     = sl;
      req.tp     = 0.0;   // exit is rule-based (RSI revert / trend break)
      req.reason = "connors_rsi2_long";
      return true;
     }

   // SHORT (mirror): macro downtrend STATE + RSI(2) crosses INTO overbought.
   if(strategy_enable_shorts)
     {
      const bool short_trend = (close_1 < sma_200);
      const bool short_event = (rsi_1 > strategy_entry_rsi_short &&
                                rsi_2 <= strategy_entry_rsi_short);
      if(short_trend && short_event)
        {
         const double entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(entry <= 0.0)
            return false;
         const double sl = QM_StopATRFromValue(_Symbol, QM_SELL, entry, atr, strategy_atr_stop_mult);
         if(sl <= entry)
            return false;
         req.type   = QM_SELL;
         req.price  = 0.0;
         req.sl     = sl;
         req.tp     = 0.0;
         req.reason = "connors_rsi2_short";
         return true;
        }
     }

   return false;
  }

// No active trade management beyond the fixed ATR protective stop. The rule
// exits (RSI revert / trend break) live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Rule exit: RSI(2) reverts past the exit level OR the macro trend breaks.
bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) <= 0)
      return false;

   const double close_1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed-bar read
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double rsi_1   = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   if(close_1 <= 0.0 || sma_200 <= 0.0 || rsi_1 <= 0.0)
      return false;

   // Determine our open side (one position per magic on this symbol).
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // Exit long: RSI(2) recovered above exit level OR trend broke down.
         if(rsi_1 > strategy_exit_rsi_long || close_1 < sma_200)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Exit short: RSI(2) fell below exit level OR trend broke up.
         if(rsi_1 < strategy_exit_rsi_short || close_1 > sma_200)
            return true;
        }
      return false;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11365_connors-rsi2-sma200-pullback-d1\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

   if(!QM_IsNewBar(_Symbol, strategy_timeframe))
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
