#property strict
#property version   "5.0"
#property description "QM5_38002 CodeTrading MACD EMA Trend Pullback"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA: QM5_38002
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 38002;
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
input ENUM_TIMEFRAMES strategy_signal_tf          = PERIOD_M15;
input int             strategy_trend_ema_period   = 200;
input int             strategy_pullback_ema_period = 50;
input int             strategy_fast_macd_period   = 12;
input int             strategy_slow_macd_period   = 26;
input int             strategy_signal_macd_period = 9;
input int             strategy_atr_period         = 14;
input double          strategy_atr_sl_mult        = 1.5;
input double          strategy_tp_rr_mult         = 2.0;
input bool            strategy_trailing_enabled   = true;
input double          strategy_trail_atr_mult     = 2.0;
input int             strategy_rollover_start_hhmm = 2355;
input int             strategy_rollover_end_hhmm   = 5;
input double          strategy_spread_filter_mult  = 1.8;

// -----------------------------------------------------------------------------
// State Cache & Indicators
// -----------------------------------------------------------------------------
double g_trend_ema    = 0.0;
double g_pullback_ema = 0.0;
double g_last_atr     = 0.0;
int    g_last_signal  = 0;

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
   g_trend_ema    = QM_EMA(_Symbol, strategy_signal_tf, strategy_trend_ema_period, 1, PRICE_CLOSE);
   g_pullback_ema = QM_EMA(_Symbol, strategy_signal_tf, strategy_pullback_ema_period, 1, PRICE_CLOSE);
   g_last_atr     = QM_ATR(_Symbol, strategy_signal_tf, MathMax(1, strategy_atr_period), 1);

   const double macd_main_1 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 1, PRICE_CLOSE);
   const double macd_sig_1  = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 1, PRICE_CLOSE);
   const double macd_main_2 = QM_MACD_Main(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 2, PRICE_CLOSE);
   const double macd_sig_2  = QM_MACD_Signal(_Symbol, strategy_signal_tf, strategy_fast_macd_period, strategy_slow_macd_period, strategy_signal_macd_period, 2, PRICE_CLOSE);

   const double macd_hist_1 = macd_main_1 - macd_sig_1;
   const double macd_hist_2 = macd_main_2 - macd_sig_2;

   const double close_1 = iClose(_Symbol, strategy_signal_tf, 1); // perf-allowed: closed-bar state advance behind QM_IsNewBar()
   const double low_1   = iLow(_Symbol, strategy_signal_tf, 1);   // perf-allowed: closed-bar state advance behind QM_IsNewBar()
   const double high_1  = iHigh(_Symbol, strategy_signal_tf, 1);  // perf-allowed: closed-bar state advance behind QM_IsNewBar()

   g_last_signal = 0;
   if(g_trend_ema > 0.0 && g_pullback_ema > 0.0 && close_1 > 0.0 && low_1 > 0.0 && high_1 > 0.0)
   {
      // Long: Close[1] > EMA(200)[1] && Low[1] <= EMA(50)[1] && MACD_Hist[1] > 0 && MACD_Hist[2] <= 0
      if(close_1 > g_trend_ema && low_1 <= g_pullback_ema && macd_hist_1 > 0.0 && macd_hist_2 <= 0.0)
         g_last_signal = 1;
      // Short: Close[1] < EMA(200)[1] && High[1] >= EMA(50)[1] && MACD_Hist[1] < 0 && MACD_Hist[2] >= 0
      else if(close_1 < g_trend_ema && high_1 >= g_pullback_ema && macd_hist_1 < 0.0 && macd_hist_2 >= 0.0)
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

   const double sl_distance = g_last_atr * strategy_atr_sl_mult;
   const double tp_distance = sl_distance * strategy_tp_rr_mult;
   if(sl_distance <= 0.0 || tp_distance <= 0.0)
      return false;

   req.type = side;
   req.sl = QM_StopRulesStopFromDistance(_Symbol, side, entry, sl_distance);
   req.tp = QM_StopRulesTakeFromDistance(_Symbol, side, entry, tp_distance);
   req.reason = (side == QM_BUY) ? "MACD_EMA_PULLBACK_LONG" : "MACD_EMA_PULLBACK_SHORT";

   return (req.sl > 0.0 && req.tp > 0.0);
}

void Strategy_ManageOpenPosition()
{
   if(!strategy_trailing_enabled || g_last_atr <= 0.0)
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

      QM_TM_TrailATR(ticket, MathMax(1, strategy_atr_period), strategy_trail_atr_mult);
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
