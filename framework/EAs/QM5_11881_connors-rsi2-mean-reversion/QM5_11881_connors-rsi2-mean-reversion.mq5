#property strict
#property version   "5.0"
#property description "QM5_11881 connors-rsi2-mean-reversion — Connors 2-period RSI mean reversion (D1, SMA200 regime)"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA — QM5_11881 connors-rsi2-mean-reversion
// -----------------------------------------------------------------------------
// Source: Larry Connors & Cesar Alvarez, "Short Term Trading Strategies That
//         Work" (2009), the "2-Period RSI" rule (pp17-18 / Strategies 8-9).
//         source_id 2f18abf6-a4aa-5974-8299-aa2d8913fa7d.
// Card: artifacts/cards_approved/QM5_11881_connors-rsi2-mean-reversion.md
//       (g0_status APPROVED).
//
// Mechanics (D1, all signal reads on CLOSED bars at shift >= 1):
//   Trend STATE   : close@1 > SMA(200) -> macro uptrend (longs only).
//                   close@1 < SMA(200) -> macro downtrend (shorts only).
//   Down/up day   : co-condition STATE for the pullback:
//                   LONG  needs close@1 < close@2 (a down day).
//                   SHORT needs close@1 > close@2 (an up day).
//   Entry EVENT   : the SINGLE trigger — RSI(2) crosses INTO the extreme on the
//                   last closed bar (modelled as a fresh cross, NOT a level test,
//                   so it does not re-fire every bar RSI stays extreme, and the
//                   regime/down-day remain STATES — avoids the two-cross trap):
//                   LONG  -> rsi@1 < rsi_long_entry  AND rsi@2 >= rsi_long_entry.
//                   SHORT -> rsi@1 > rsi_short_entry AND rsi@2 <= rsi_short_entry.
//   Stop          : entry -/+ atr_stop_mult * ATR(14)  (card: ATR x 2.0).
//                   P2 cap: skip the trade if the ATR stop distance exceeds
//                   max_stop_pips (default 100 pips), scale-correct via pip helper.
//   Exit          : single-bar RSI(2) reverts past the exit level
//                   (LONG rsi@1 > exit_long, SHORT rsi@1 < exit_short), OR the
//                   macro trend breaks, OR max-hold bars elapsed (card 10 D1
//                   bars). The protective ATR stop is the disaster brake; the
//                   RSI-cross exit acts as the dynamic TP (card: no fixed TP).
//
// One position per magic. RISK_FIXED in backtest, RISK_PERCENT for live.
// Symbols (all present in dwx_symbol_matrix.csv — NO ports needed):
//   EURUSD.DWX, GBPUSD.DWX, USDJPY.DWX, USDCAD.DWX, USDCHF.DWX, AUDUSD.DWX,
//   NZDUSD.DWX, EURJPY.DWX, GBPJPY.DWX, NDX.DWX, WS30.DWX, SP500.DWX.
//   NDX.DWX / WS30.DWX are live-tradable indices; SP500.DWX is backtest-only
//   (broker routes no orders on SP500 — live promotion is a T6-gate concern).
// Only the 5 Strategy_* hooks + Strategy inputs are EA-specific.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11881;
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
input ENUM_TIMEFRAMES strategy_timeframe   = PERIOD_D1;  // card TF = D1
input int    strategy_rsi_period           = 2;      // Connors RSI(2)
input int    strategy_sma_trend_period     = 200;    // SMA(200) macro regime filter
input int    strategy_atr_period           = 14;     // ATR for the protective stop
input double strategy_rsi_long_entry       = 10.0;   // RSI(2) < this -> oversold (long)
input double strategy_rsi_short_entry      = 90.0;   // RSI(2) > this -> overbought (short)
input double strategy_rsi_exit_long        = 65.0;   // RSI(2) > this -> exit long
input double strategy_rsi_exit_short       = 35.0;   // RSI(2) < this -> exit short
input double strategy_atr_stop_mult        = 2.0;    // stop distance = mult * ATR(14)
input double strategy_max_stop_pips        = 100.0;  // P2 cap: skip if ATR stop > this (pips)
input int    strategy_max_hold_bars        = 10;     // max-hold exit (D1 bars)
input bool   strategy_require_down_day      = true;  // card: down/up day co-condition
input bool   strategy_enable_shorts        = true;   // mirror shorts below SMA200
input double strategy_spread_cap_pips      = 30.0;   // block only if spread > this (pips)

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

   // Fail-OPEN: only a genuinely wide spread blocks; zero/negative passes
   // (.DWX models ask==bid -> spread 0; never block on that).
   const double spread = ask - bid;
   if(spread > 0.0)
     {
      const double cap_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_spread_cap_pips);
      if(cap_dist > 0.0 && spread > cap_dist)
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

   // Closed-bar reads (shift 1 = last closed bar, shift 2 = prior).
   const double close_1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: single closed-bar read
   const double close_2 = iClose(_Symbol, strategy_timeframe, 2); // perf-allowed: single closed-bar read
   const double sma_200 = QM_SMA(_Symbol, strategy_timeframe, strategy_sma_trend_period, 1);
   const double atr     = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(close_1 <= 0.0 || close_2 <= 0.0 || sma_200 <= 0.0 || atr <= 0.0)
      return false;

   // RSI(2): last closed bar (shift 1) and the prior bar (shift 2). The cross
   // of the entry threshold between them is the single trigger EVENT.
   const double rsi_1 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 1);
   const double rsi_2 = QM_RSI(_Symbol, strategy_timeframe, strategy_rsi_period, 2);
   if(rsi_1 <= 0.0 || rsi_2 <= 0.0)
      return false;

   // Protective-stop distance and the P2 max-stop cap (skip trade if too wide).
   const double stop_distance = strategy_atr_stop_mult * atr;
   if(stop_distance <= 0.0)
      return false;
   const double max_stop_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)strategy_max_stop_pips);
   if(max_stop_dist > 0.0 && stop_distance > max_stop_dist)
      return false; // ATR stop wider than the card P2 cap — skip

   // LONG: macro uptrend STATE + down-day STATE + RSI(2) crosses INTO oversold EVENT.
   const bool long_trend = (close_1 > sma_200);
   const bool long_day   = (!strategy_require_down_day || close_1 < close_2);
   const bool long_event = (rsi_1 < strategy_rsi_long_entry &&
                            rsi_2 >= strategy_rsi_long_entry);
   if(long_trend && long_day && long_event)
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
      req.tp     = 0.0;   // exit is rule-based (RSI revert / trend break / max-hold)
      req.reason = "connors_rsi2_long";
      return true;
     }

   // SHORT (mirror): macro downtrend STATE + up-day STATE + RSI(2) crosses INTO overbought.
   if(strategy_enable_shorts)
     {
      const bool short_trend = (close_1 < sma_200);
      const bool short_day   = (!strategy_require_down_day || close_1 > close_2);
      const bool short_event = (rsi_1 > strategy_rsi_short_entry &&
                                rsi_2 <= strategy_rsi_short_entry);
      if(short_trend && short_day && short_event)
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
// exits (RSI revert / trend break / max-hold) live in Strategy_ExitSignal.
void Strategy_ManageOpenPosition()
  {
  }

// Rule exit: single-bar RSI(2) reverts past the exit level, OR the macro trend
// breaks, OR the position has been held for max_hold_bars closed D1 bars.
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

   const long tf_seconds = (long)PeriodSeconds(strategy_timeframe);
   const datetime now    = TimeCurrent();

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

      // Max-hold: whole D1 bars elapsed since the position opened.
      if(strategy_max_hold_bars > 0 && tf_seconds > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         if(opened > 0)
           {
            const long bars_held = (long)((now - opened) / tf_seconds);
            if(bars_held >= (long)strategy_max_hold_bars)
               return true;
           }
        }

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY)
        {
         // Exit long: RSI(2) recovered above exit level OR trend broke down.
         if(rsi_1 > strategy_rsi_exit_long || close_1 < sma_200)
            return true;
        }
      else if(ptype == POSITION_TYPE_SELL)
        {
         // Exit short: RSI(2) fell below exit level OR trend broke up.
         if(rsi_1 < strategy_rsi_exit_short || close_1 > sma_200)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_11881_connors-rsi2-mean-reversion\"}");
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
