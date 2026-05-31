#property strict
#property version   "5.0"
#property description "QM5_10581 mql5-lr-slope"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10581;
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
input int    strategy_lr_period          = 25;
input int    strategy_signal_period      = 9;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 2.0;
input double strategy_take_profit_rr     = 1.5;
input int    strategy_max_spread_points  = 40;

double NormalizeStrategyPrice(const double price)
  {
   if(price <= 0.0)
      return 0.0;
   return NormalizeDouble(price, _Digits);
  }

double LinearRegSlopeValue(const int shift)
  {
   const int period = MathMax(2, strategy_lr_period);
   if(shift < 0)
      return 0.0;

   double sum_x = 0.0;
   double sum_y = 0.0;
   double sum_xy = 0.0;
   double sum_x2 = 0.0;

   for(int i = 0; i < period; ++i)
     {
      const double x = (double)i;
      const double y = iClose(_Symbol, _Period, shift + period - 1 - i);
      if(y <= 0.0)
         return 0.0;

      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
     }

   const double n = (double)period;
   const double denominator = n * sum_x2 - sum_x * sum_x;
   if(denominator == 0.0)
      return 0.0;

   return (n * sum_xy - sum_x * sum_y) / denominator;
  }

double LinearRegSlopeSignal(const int shift)
  {
   const int period = MathMax(1, strategy_signal_period);
   double sum = 0.0;
   int samples = 0;

   for(int i = 0; i < period; ++i)
     {
      const double slope = LinearRegSlopeValue(shift + i);
      if(slope == 0.0)
         continue;

      sum += slope;
      ++samples;
     }

   if(samples <= 0)
      return 0.0;
   return sum / (double)samples;
  }

int LinearRegSlopeCrossSignal()
  {
   if(strategy_lr_period < 2 || strategy_signal_period < 1)
      return 0;

   const double osc_1 = LinearRegSlopeValue(1);
   const double sig_1 = LinearRegSlopeSignal(1);
   const double osc_2 = LinearRegSlopeValue(2);
   const double sig_2 = LinearRegSlopeSignal(2);

   if((osc_1 == 0.0 && sig_1 == 0.0) || (osc_2 == 0.0 && sig_2 == 0.0))
      return 0;

   if(osc_2 <= sig_2 && osc_1 > sig_1)
      return 1;
   if(osc_2 >= sig_2 && osc_1 < sig_1)
      return -1;
   return 0;
  }

bool HasOurPosition()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      return true;
     }
   return false;
  }

bool OurPositionType(ENUM_POSITION_TYPE &type)
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const int spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
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

   if(HasOurPosition())
      return false;
   if(strategy_lr_period < 2 || strategy_signal_period < 1 ||
      strategy_atr_period < 1 || strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   const int signal = LinearRegSlopeCrossSignal();
   if(signal == 0)
      return false;

   const QM_OrderType side = (signal > 0) ? QM_BUY : QM_SELL;
   const double entry = (side == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                         : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double atr = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = QM_StopATRFromValue(_Symbol, side, entry, atr, strategy_atr_sl_mult);
   const double tp = QM_TakeRR(_Symbol, side, entry, sl, strategy_take_profit_rr);
   if(sl <= 0.0 || tp <= 0.0)
      return false;

   req.type = side;
   req.price = 0.0;
   req.sl = NormalizeStrategyPrice(sl);
   req.tp = NormalizeStrategyPrice(tp);
   req.reason = (signal > 0) ? "LR_SLOPE_BULL_CROSS" : "LR_SLOPE_BEAR_CROSS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE position_type = POSITION_TYPE_BUY;
   if(!OurPositionType(position_type))
      return false;

   const int signal = LinearRegSlopeCrossSignal();
   if(position_type == POSITION_TYPE_BUY && signal < 0)
      return true;
   if(position_type == POSITION_TYPE_SELL && signal > 0)
      return true;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10581\",\"strategy\":\"mql5-lr-slope\"}");
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
