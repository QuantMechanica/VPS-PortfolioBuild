#property strict
#property version   "5.0"
#property description "QM5_10495 MQL5 Separate Trade MA Cross Volatility Filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 10495;
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
input int    strategy_first_ma_period       = 20;
input int    strategy_second_ma_period      = 50;
input int    strategy_atr_period            = 14;
input int    strategy_stddev_period         = 20;
input double strategy_buy_min_ma_points     = 0.0;
input double strategy_sell_min_ma_points    = 0.0;
input double strategy_buy_min_atr_points    = 0.0;
input double strategy_sell_min_atr_points   = 0.0;
input double strategy_buy_min_std_points    = 0.0;
input double strategy_sell_min_std_points   = 0.0;
input double strategy_atr_sl_mult           = 1.5;
input double strategy_take_profit_rr        = 2.0;
input int    strategy_max_spread_points     = 30;

bool Strategy_HasOpenPosition()
  {
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return true;

   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points <= 0)
      return false;

   const long spread_points = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread_points <= 0)
      return true;

   return (spread_points > strategy_max_spread_points);
  }

int Strategy_MaCrossSignal()
  {
   const double first_now   = QM_EMA(_Symbol, _Period, strategy_first_ma_period, 1);
   const double second_now  = QM_EMA(_Symbol, _Period, strategy_second_ma_period, 1);
   const double first_prev  = QM_EMA(_Symbol, _Period, strategy_first_ma_period, 2);
   const double second_prev = QM_EMA(_Symbol, _Period, strategy_second_ma_period, 2);

   if(first_now <= 0.0 || second_now <= 0.0 || first_prev <= 0.0 || second_prev <= 0.0)
      return 0;

   if(first_prev <= second_prev && first_now > second_now)
      return 1;
   if(first_prev >= second_prev && first_now < second_now)
      return -1;

   return 0;
  }

bool Strategy_VolatilityPasses(const int signal)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return false;

   const double first_ma  = QM_EMA(_Symbol, _Period, strategy_first_ma_period, 1);
   const double second_ma = QM_EMA(_Symbol, _Period, strategy_second_ma_period, 1);
   const double atr       = QM_ATR(_Symbol, _Period, strategy_atr_period, 1);
   const double stddev    = QM_StdDev(_Symbol, _Period, strategy_stddev_period, 1);
   if(first_ma <= 0.0 || second_ma <= 0.0 || atr <= 0.0 || stddev <= 0.0)
      return false;

   const double ma_distance_points = MathAbs(first_ma - second_ma) / point;
   const double atr_points = atr / point;
   const double std_points = stddev / point;

   if(signal > 0)
      return (ma_distance_points >= strategy_buy_min_ma_points &&
              atr_points >= strategy_buy_min_atr_points &&
              std_points >= strategy_buy_min_std_points);

   if(signal < 0)
      return (ma_distance_points >= strategy_sell_min_ma_points &&
              atr_points >= strategy_sell_min_atr_points &&
              std_points >= strategy_sell_min_std_points);

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

   if(Strategy_HasOpenPosition())
      return false;

   if(strategy_first_ma_period <= 1 ||
      strategy_second_ma_period <= 1 ||
      strategy_atr_period <= 1 ||
      strategy_stddev_period <= 1 ||
      strategy_atr_sl_mult <= 0.0 ||
      strategy_take_profit_rr <= 0.0)
      return false;

   const int signal = Strategy_MaCrossSignal();
   if(signal == 0 || !Strategy_VolatilityPasses(signal))
      return false;

   req.type = (signal > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;

   const double entry = QM_EntryMarketPrice(req.type);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = QM_TakeRR(_Symbol, req.type, entry, req.sl, strategy_take_profit_rr);
   if(req.sl <= 0.0 || req.tp <= 0.0)
      return false;

   req.reason = (signal > 0) ? "QM5_10495_MA_CROSS_LONG" : "QM5_10495_MA_CROSS_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card disables trailing, partial close, and break-even for P2.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;

   const int signal = Strategy_MaCrossSignal();
   if(signal == 0)
      return false;

   const int magic = QM_FrameworkMagic();
   for(int i = 0; i < PositionsTotal(); ++i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY && signal < 0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && signal > 0)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10495_mql5-sep-trade\"}");
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
