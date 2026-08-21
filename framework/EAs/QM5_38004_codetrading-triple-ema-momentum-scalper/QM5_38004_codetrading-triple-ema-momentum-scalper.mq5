#property strict
#property version   "5.0"
#property description "QM5_38004 CodeTrading Triple EMA Momentum Scalper"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38004
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38004;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_M5;
input int             strategy_fast_ema_period     = 8;
input int             strategy_med_ema_period      = 21;
input int             strategy_slow_ema_period     = 55;
input int             strategy_atr_period          = 14;
input double          strategy_sl_buffer_pips      = 2.0;
input double          strategy_tp_rr               = 2.0;
input bool            strategy_trail_enabled       = true;
input double          strategy_trail_trigger_r     = 1.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_ema_fast       = 0.0;
double g_ema_med        = 0.0;
double g_ema_slow       = 0.0;
double g_last_atr       = 0.0;
int    g_last_signal    = 0;

int StrategyHhmm(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.hour * 100 + dt.min;
}

bool StrategyInRolloverWindow(const datetime t)
{
   const int hhmm = StrategyHhmm(t);
   if(strategy_rollover_start_hhmm > strategy_rollover_end_hhmm)
      return (hhmm >= strategy_rollover_start_hhmm || hhmm < strategy_rollover_end_hhmm);
   return (hhmm >= strategy_rollover_start_hhmm && hhmm < strategy_rollover_end_hhmm);
}

void AdvanceState_OnNewBar()
{
   const double open1  = iOpen(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar candlestick calculation
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar candlestick calculation
   const double high1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar candlestick calculation
   const double low1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: closed-bar candlestick calculation

   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return;

   g_ema_fast = QM_EMA(_Symbol, strategy_signal_tf, strategy_fast_ema_period, 1, PRICE_CLOSE);
   g_ema_med  = QM_EMA(_Symbol, strategy_signal_tf, strategy_med_ema_period,  1, PRICE_CLOSE);
   g_ema_slow = QM_EMA(_Symbol, strategy_signal_tf, strategy_slow_ema_period, 1, PRICE_CLOSE);
   g_last_atr = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);

   g_last_signal = 0;
   if(g_ema_fast > 0.0 && g_ema_med > 0.0 && g_ema_slow > 0.0)
   {
      // Bullish Ribbon: EMA(8) > EMA(21) > EMA(55)
      // Pocket Pullback: Low[1] <= EMA(8)[1] && Close[1] > EMA(21)[1] && Close[1] > Open[1]
      if(g_ema_fast > g_ema_med && g_ema_med > g_ema_slow &&
         low1 <= g_ema_fast && close1 > g_ema_med && close1 > open1)
      {
         g_last_signal = 1;
      }
      // Bearish Ribbon: EMA(8) < EMA(21) < EMA(55)
      // Pocket Pullback: High[1] >= EMA(8)[1] && Close[1] < EMA(21)[1] && Close[1] < Open[1]
      else if(g_ema_fast < g_ema_med && g_ema_med < g_ema_slow &&
              high1 >= g_ema_fast && close1 < g_ema_med && close1 < open1)
      {
         g_last_signal = -1;
      }
   }
}

// -----------------------------------------------------------------------------
// Strategy hooks
// -----------------------------------------------------------------------------

bool Strategy_NoTradeFilter()
{
   if(StrategyInRolloverWindow(TimeCurrent()))
      return true;

   const int magic = QM_FrameworkMagic();
   if(QM_TM_OpenPositionCount(magic) >= 1)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   if(ask > bid && g_last_atr > 0.0)
   {
      const double spread = ask - bid;
      if(spread > g_last_atr * strategy_spread_filter_mult)
         return true;
   }

   return false;
}

bool Strategy_EntrySignal(QM_EntryRequest &req)
{
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(g_last_signal == 0 || g_last_atr <= 0.0 || g_ema_slow <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double pip_dist = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_sl_buffer_pips));
   const double buffer = (pip_dist > 0.0) ? pip_dist : (strategy_sl_buffer_pips * SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0);

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = g_ema_slow - buffer;
      if(sl >= entry)
         sl = entry - g_last_atr * 1.5;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double sl_dist = entry - sl;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + strategy_tp_rr * sl_dist);
   }
   else
   {
      sl = g_ema_slow + buffer;
      if(sl <= entry)
         sl = entry + g_last_atr * 1.5;
      sl = QM_StopRulesNormalizePrice(_Symbol, sl);
      const double sl_dist = sl - entry;
      if(sl_dist <= 0.0)
         return false;
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - strategy_tp_rr * sl_dist);
   }

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "TRIPLE_EMA_MOM_LONG" : "TRIPLE_EMA_MOM_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_trail_enabled || g_ema_med <= 0.0)
      return;

   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      const double current_sl = PositionGetDouble(POSITION_SL);
      const double point      = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      if(pos_type == POSITION_TYPE_BUY)
      {
         const double sl_dist = (current_sl > 0.0 && current_sl < open_price) ? (open_price - current_sl) : (g_last_atr * 1.5);
         const double r_trigger = sl_dist * strategy_trail_trigger_r;
         const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         if(bid - open_price >= r_trigger)
         {
            const double new_sl = QM_StopRulesNormalizePrice(_Symbol, MathMax(open_price + 2.0 * point, g_ema_med));
            if(new_sl > current_sl + point)
               QM_TM_MoveSL(ticket, new_sl, "TRAIL_EMA21");
         }
      }
      else if(pos_type == POSITION_TYPE_SELL)
      {
         const double sl_dist = (current_sl > open_price) ? (current_sl - open_price) : (g_last_atr * 1.5);
         const double r_trigger = sl_dist * strategy_trail_trigger_r;
         const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

         if(open_price - ask >= r_trigger)
         {
            const double candidate_sl = (g_ema_med > 0.0) ? MathMin(open_price - 2.0 * point, g_ema_med) : (open_price - 2.0 * point);
            const double new_sl = QM_StopRulesNormalizePrice(_Symbol, candidate_sl);
            if(current_sl == 0.0 || new_sl < current_sl - point)
               QM_TM_MoveSL(ticket, new_sl, "TRAIL_EMA21");
         }
      }
   }
}

bool Strategy_ExitSignal()
{
   return false;
}

bool Strategy_NewsFilterHook(const datetime broker_time)
{
   return false;
}

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

int OnInit()
{
   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
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
   QM_FrameworkTrackOpenPositionMae();
   if(!QM_KillSwitchCheck())
      return;

   const datetime broker_now = TimeCurrent();
   if(Strategy_NewsFilterHook(broker_now))
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(!QM_IsNewBar())
      return;

   AdvanceState_OnNewBar();
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
