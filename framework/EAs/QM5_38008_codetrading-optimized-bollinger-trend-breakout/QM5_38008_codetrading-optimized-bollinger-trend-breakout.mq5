#property strict
#property version   "5.0"
#property description "QM5_38008 CodeTrading Optimized Bollinger Trend Breakout"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38008
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38008;
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
input ENUM_TIMEFRAMES strategy_signal_tf           = PERIOD_D1;
input int             strategy_bb_period           = 20;
input double          strategy_bb_dev              = 2.50;
input int             strategy_trend_ema_period    = 200;
input int             strategy_trend_slope_lookback = 5;
input int             strategy_atr_period          = 14;
input double          strategy_atr_sl_mult         = 2.0;
input double          strategy_tp_rr_mult          = 5.0;
input bool            strategy_use_mid_exit        = true;
input bool            strategy_be_enabled          = true;
input double          strategy_be_trigger_r        = 1.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_bb_upper       = 0.0;
double g_bb_lower       = 0.0;
double g_bb_middle      = 0.0;
double g_ema200_1       = 0.0;
double g_ema200_5       = 0.0;
double g_last_atr       = 0.0;
double g_last_close1    = 0.0;
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
   const double open1  = iOpen(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar calculation
   const double close1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar calculation
   const double high1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar calculation
   const double low1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: closed-bar calculation

   if(open1 <= 0.0 || close1 <= 0.0 || high1 <= 0.0 || low1 <= 0.0)
      return;

   g_bb_upper   = QM_BB_Upper(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_bb_lower   = QM_BB_Lower(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_bb_middle  = QM_BB_Middle(_Symbol, strategy_signal_tf, strategy_bb_period, strategy_bb_dev, 1, PRICE_CLOSE);
   g_ema200_1   = QM_EMA(_Symbol, strategy_signal_tf, strategy_trend_ema_period, 1, PRICE_CLOSE);
   g_ema200_5   = QM_EMA(_Symbol, strategy_signal_tf, strategy_trend_ema_period, strategy_trend_slope_lookback, PRICE_CLOSE);
   g_last_atr   = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);
   g_last_close1 = close1;

   g_last_signal = 0;

   if(g_bb_upper > 0.0 && g_bb_lower > 0.0 && g_ema200_1 > 0.0 && g_ema200_5 > 0.0 && g_last_atr > 0.0)
   {
      // Long: Close[1] > UpperBB[1] && EMA200[1] > EMA200[5] && Close[1] > Open[1]
      if(close1 > g_bb_upper && g_ema200_1 > g_ema200_5 && close1 > open1)
         g_last_signal = 1;
      // Short: Close[1] < LowerBB[1] && EMA200[1] < EMA200[5] && Close[1] < Open[1]
      else if(close1 < g_bb_lower && g_ema200_1 < g_ema200_5 && close1 < open1)
         g_last_signal = -1;
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

   if(g_last_signal == 0 || g_last_atr <= 0.0)
      return false;

   const QM_OrderType side = (g_last_signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   const double sl_dist = g_last_atr * strategy_atr_sl_mult;
   if(sl_dist <= 0.0)
      return false;

   double sl = 0.0;
   double tp = 0.0;

   if(side == QM_BUY)
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist);
      tp = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist * strategy_tp_rr_mult);
   }
   else
   {
      sl = QM_StopRulesNormalizePrice(_Symbol, entry + sl_dist);
      tp = QM_StopRulesNormalizePrice(_Symbol, entry - sl_dist * strategy_tp_rr_mult);
   }

   req.type = side;
   req.sl = sl;
   req.tp = tp;
   req.reason = (side == QM_BUY) ? "BOLL_BREAKOUT_LONG" : "BOLL_BREAKOUT_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
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

      // Midline trailing exit on closed bar
      if(strategy_use_mid_exit && g_bb_middle > 0.0 && g_last_close1 > 0.0)
      {
         if(pos_type == POSITION_TYPE_BUY && g_last_close1 < g_bb_middle)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
         else if(pos_type == POSITION_TYPE_SELL && g_last_close1 > g_bb_middle)
         {
            QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
            continue;
         }
      }

      // Break-even lock
      if(strategy_be_enabled && g_last_atr > 0.0)
      {
         const double initial_risk = (current_sl > 0.0) ? MathAbs(open_price - current_sl) : (g_last_atr * strategy_atr_sl_mult);
         const double be_trigger   = initial_risk * strategy_be_trigger_r;

         if(pos_type == POSITION_TYPE_BUY)
         {
            const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(bid - open_price >= be_trigger && (current_sl < open_price || current_sl == 0.0))
            {
               const double new_sl = QM_StopRulesNormalizePrice(_Symbol, open_price + 2.0 * point);
               QM_TM_MoveSL(ticket, new_sl, "BE_LOCK");
            }
         }
         else if(pos_type == POSITION_TYPE_SELL)
         {
            const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(open_price - ask >= be_trigger && (current_sl > open_price || current_sl == 0.0))
            {
               const double new_sl = QM_StopRulesNormalizePrice(_Symbol, open_price - 2.0 * point);
               QM_TM_MoveSL(ticket, new_sl, "BE_LOCK");
            }
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
