#property strict
#property version   "5.0"
#property description "QM5_1165 Unger Gold Linear Regression Trend"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1165;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input ENUM_TIMEFRAMES strategy_timeframe = PERIOD_H1;
input int    strategy_lr_period          = 40;
input double strategy_lr_dev             = 1.0;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_atr_tp_mult        = 4.0;
input int    strategy_max_hold_bars      = 72;
input int    strategy_trade_start_hour_broker = 1;
input int    strategy_trade_end_hour_broker   = 23;
input int    strategy_max_spread_points  = 250;

bool   g_lr_state_ready = false;
double g_lr_close_1     = 0.0;
double g_lr_close_2     = 0.0;
double g_lr_line_1      = 0.0;
double g_lr_line_2      = 0.0;
double g_lr_upper_1     = 0.0;
double g_lr_upper_2     = 0.0;
double g_lr_lower_1     = 0.0;
double g_lr_lower_2     = 0.0;

bool Strategy_NoTradeFilter()
  {
   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return true;
   if(strategy_max_spread_points > 0 && ask > bid &&
      (ask - bid) > (strategy_max_spread_points * point))
      return true;

   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   const int start_h = MathMax(0, MathMin(23, strategy_trade_start_hour_broker));
   const int end_h = MathMax(0, MathMin(23, strategy_trade_end_hour_broker));
   if(start_h == end_h)
      return false;
   if(start_h < end_h)
      return !(now.hour >= start_h && now.hour < end_h);
   return !(now.hour >= start_h || now.hour < end_h);
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

   g_lr_state_ready = false;
   if(strategy_lr_period < 5 || strategy_atr_period < 1 ||
      strategy_lr_dev <= 0.0 || strategy_atr_sl_mult <= 0.0 ||
      strategy_atr_tp_mult <= 0.0)
      return false;

   double sum_x = 0.0;
   double sum_x2 = 0.0;
   double sum_y_1 = 0.0;
   double sum_xy_1 = 0.0;
   double sum_y_2 = 0.0;
   double sum_xy_2 = 0.0;

   for(int i = 0; i < strategy_lr_period; ++i)
     {
      const double x = (double)i;
      const int shift_1 = strategy_lr_period - i;
      const int shift_2 = strategy_lr_period + 1 - i;
      const double y_1 = iClose(_Symbol, strategy_timeframe, shift_1); // perf-allowed: bounded H1 close window for card linear-regression channel, called only after framework QM_IsNewBar().
      const double y_2 = iClose(_Symbol, strategy_timeframe, shift_2); // perf-allowed: bounded H1 close window for prior regression channel, called only after framework QM_IsNewBar().
      if(y_1 <= 0.0 || y_2 <= 0.0)
         return false;
      sum_x += x;
      sum_x2 += x * x;
      sum_y_1 += y_1;
      sum_xy_1 += x * y_1;
      sum_y_2 += y_2;
      sum_xy_2 += x * y_2;
     }

   const double n = (double)strategy_lr_period;
   const double denom = n * sum_x2 - sum_x * sum_x;
   if(denom == 0.0)
      return false;

   const double slope_1 = (n * sum_xy_1 - sum_x * sum_y_1) / denom;
   const double intercept_1 = (sum_y_1 - slope_1 * sum_x) / n;
   const double slope_2 = (n * sum_xy_2 - sum_x * sum_y_2) / denom;
   const double intercept_2 = (sum_y_2 - slope_2 * sum_x) / n;
   g_lr_line_1 = intercept_1 + slope_1 * (n - 1.0);
   g_lr_line_2 = intercept_2 + slope_2 * (n - 1.0);

   double resid_sum_1 = 0.0;
   double resid_sum_2 = 0.0;
   for(int j = 0; j < strategy_lr_period; ++j)
     {
      const double x = (double)j;
      const int shift_1 = strategy_lr_period - j;
      const int shift_2 = strategy_lr_period + 1 - j;
      const double y_1 = iClose(_Symbol, strategy_timeframe, shift_1); // perf-allowed: bounded H1 close window for regression residual stdev.
      const double y_2 = iClose(_Symbol, strategy_timeframe, shift_2); // perf-allowed: bounded H1 close window for prior residual stdev.
      const double r_1 = y_1 - (intercept_1 + slope_1 * x);
      const double r_2 = y_2 - (intercept_2 + slope_2 * x);
      resid_sum_1 += r_1 * r_1;
      resid_sum_2 += r_2 * r_2;
     }

   const double stdev_1 = MathSqrt(resid_sum_1 / n);
   const double stdev_2 = MathSqrt(resid_sum_2 / n);
   if(stdev_1 <= 0.0 || stdev_2 <= 0.0)
      return false;

   g_lr_upper_1 = g_lr_line_1 + strategy_lr_dev * stdev_1;
   g_lr_upper_2 = g_lr_line_2 + strategy_lr_dev * stdev_2;
   g_lr_lower_1 = g_lr_line_1 - strategy_lr_dev * stdev_1;
   g_lr_lower_2 = g_lr_line_2 - strategy_lr_dev * stdev_2;
   g_lr_close_1 = iClose(_Symbol, strategy_timeframe, 1); // perf-allowed: closed signal-bar close for regression breakout.
   g_lr_close_2 = iClose(_Symbol, strategy_timeframe, 2); // perf-allowed: prior closed-bar close for regression breakout.
   if(g_lr_close_1 <= 0.0 || g_lr_close_2 <= 0.0)
      return false;
   g_lr_state_ready = true;

   const int magic = QM_FrameworkMagic();
   if(magic > 0 && QM_TM_OpenPositionCount(magic) > 0)
      return false;

   QM_OrderType side = QM_BUY;
   string reason = "";
   if(g_lr_close_1 > g_lr_upper_1 && g_lr_close_2 <= g_lr_upper_2)
     {
      side = QM_BUY;
      reason = "LR_CHANNEL_BREAKOUT_LONG";
     }
   else if(g_lr_close_1 < g_lr_lower_1 && g_lr_close_2 >= g_lr_lower_2)
     {
      side = QM_SELL;
      reason = "LR_CHANNEL_BREAKOUT_SHORT";
     }
   else
      return false;

   const double entry_price = QM_OrderTypeIsBuy(side)
                              ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                              : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, strategy_timeframe, strategy_atr_period, 1);
   if(entry_price <= 0.0 || atr <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = QM_StopATRFromValue(_Symbol, side, entry_price, atr, strategy_atr_sl_mult);
   req.tp = QM_TakeATRFromValue(_Symbol, side, entry_price, atr, strategy_atr_tp_mult);
   req.reason = reason;
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(strategy_max_hold_bars > 0)
        {
         const datetime opened = (datetime)PositionGetInteger(POSITION_TIME);
         const int seconds_per_bar = PeriodSeconds(strategy_timeframe);
         if(opened > 0 && seconds_per_bar > 0 &&
            TimeCurrent() - opened >= strategy_max_hold_bars * seconds_per_bar)
            return true;
        }

      if(!g_lr_state_ready)
         continue;

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && g_lr_close_1 < g_lr_line_1)
         return true;
      if(type == POSITION_TYPE_SELL && g_lr_close_1 > g_lr_line_1)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1165_unger-gold-linreg-trend\"}");
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
