#property strict
#property version   "5.0"
#property description "QM5_12960 Keltner pullback swing"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12960;
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
input int    strategy_keltner_ema_period = 20;
input int    strategy_keltner_atr_period = 10;
input double strategy_keltner_mult       = 1.5;
input int    strategy_trend_ema_period   = 50;
input int    strategy_sl_atr_period      = 14;
input double strategy_sl_mult            = 1.5;

int Strategy_ExpectedSlot()
  {
   if(_Symbol == "SP500.DWX")
      return 0;
   if(_Symbol == "XAGUSD.DWX")
      return 1;
   return -1;
  }

bool Strategy_IsTarget()
  {
   return (_Period == PERIOD_H4 && Strategy_ExpectedSlot() == qm_magic_slot_offset);
  }

bool Strategy_HasOpenPosition()
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

bool Strategy_Keltner(const int shift, double &mid, double &upper, double &lower)
  {
   mid = QM_EMA(_Symbol, PERIOD_H4, strategy_keltner_ema_period, shift, PRICE_CLOSE);
   const double atr = QM_ATR(_Symbol, PERIOD_H4, strategy_keltner_atr_period, shift);
   if(mid <= 0.0 || atr <= 0.0)
      return false;
   upper = mid + atr * strategy_keltner_mult;
   lower = mid - atr * strategy_keltner_mult;
   return (upper > lower && lower > 0.0);
  }

bool Strategy_NoTradeFilter()
  {
   if(!Strategy_IsTarget())
      return true;
   if(strategy_keltner_ema_period <= 1 || strategy_keltner_atr_period <= 0)
      return true;
   if(strategy_keltner_mult <= 0.0 || strategy_trend_ema_period <= 1)
      return true;
   if(strategy_sl_atr_period <= 0 || strategy_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "KELTNER_REENTRY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;

   double mid1 = 0.0, upper1 = 0.0, lower1 = 0.0;
   double mid2 = 0.0, upper2 = 0.0, lower2 = 0.0;
   if(!Strategy_Keltner(1, mid1, upper1, lower1))
      return false;
   if(!Strategy_Keltner(2, mid2, upper2, lower2))
      return false;

   const double close1 = iClose(_Symbol, PERIOD_H4, 1);
   const double low2 = iLow(_Symbol, PERIOD_H4, 2);
   const double high2 = iHigh(_Symbol, PERIOD_H4, 2);
   const double trend_ema = QM_EMA(_Symbol, PERIOD_H4, strategy_trend_ema_period, 1, PRICE_CLOSE);
   if(close1 <= 0.0 || low2 <= 0.0 || high2 <= 0.0 || trend_ema <= 0.0)
      return false;

   int direction = 0;
   if(close1 > trend_ema && low2 <= lower2 && close1 > lower1)
      direction = 1;
   else if(close1 < trend_ema && high2 >= upper2 && close1 < upper1)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry_price = QM_EntryMarketPrice(req.type);
   if(entry_price <= 0.0)
      return false;
   req.sl = QM_StopATR(_Symbol, req.type, entry_price, strategy_sl_atr_period, strategy_sl_mult);
   if(req.sl <= 0.0)
      return false;
   req.reason = (direction > 0) ? "KELTNER_REENTRY_LONG" : "KELTNER_REENTRY_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   double mid1 = 0.0, upper1 = 0.0, lower1 = 0.0;
   if(!Strategy_Keltner(1, mid1, upper1, lower1))
      return false;
   const double high1 = iHigh(_Symbol, PERIOD_H4, 1);
   const double low1 = iLow(_Symbol, PERIOD_H4, 1);
   if(high1 <= 0.0 || low1 <= 0.0)
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
      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && high1 >= upper1)
         return true;
      if(type == POSITION_TYPE_SELL && low1 <= lower1)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12960\",\"ea\":\"keltner-pullback-swing\"}");
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
         if(ticket == 0 || !PositionSelectByTicket(ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
     }

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
