#property strict
#property version   "5.0"
#property description "QM5_10010 Robot Wealth FX AR10 Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10010;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_PAUSE;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_atr_period         = 14;
input double strategy_entry_atr_frac     = 0.15;
input double strategy_sl_atr_mult        = 1.20;
input double strategy_spread_atr_frac    = 0.20;
input int    strategy_vol_lookback       = 60;
input int    strategy_hold_bars          = 6;
input int    strategy_ny_close_hour      = 23;
input int    strategy_ny_close_minute    = 50;
input double strategy_ar_intercept       = 0.0;
input double strategy_ar1                = -0.1000;
input double strategy_ar2                = -0.0500;
input double strategy_ar3                = -0.0250;
input double strategy_ar4                = -0.0125;
input double strategy_ar5                = -0.0063;
input double strategy_ar6                = 0.0000;
input double strategy_ar7                = 0.0000;
input double strategy_ar8                = 0.0000;
input double strategy_ar9                = 0.0000;
input double strategy_ar10               = 0.0000;

bool g_suppress_entry_this_bar = false;

double BarReturn(const int shift)
  {
   const double c0 = iClose(_Symbol, PERIOD_M10, shift);
   const double c1 = iClose(_Symbol, PERIOD_M10, shift + 1);
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;
   return (c0 / c1) - 1.0;
  }

double AR10PredictedReturn()
  {
   return strategy_ar_intercept
          + strategy_ar1  * BarReturn(1)
          + strategy_ar2  * BarReturn(2)
          + strategy_ar3  * BarReturn(3)
          + strategy_ar4  * BarReturn(4)
          + strategy_ar5  * BarReturn(5)
          + strategy_ar6  * BarReturn(6)
          + strategy_ar7  * BarReturn(7)
          + strategy_ar8  * BarReturn(8)
          + strategy_ar9  * BarReturn(9)
          + strategy_ar10 * BarReturn(10);
  }

bool RealizedVolatilityFilterPasses()
  {
   const int lookback = MathMax(10, strategy_vol_lookback);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_M10, 1, lookback + 2, rates); // perf-allowed: Strategy_EntrySignal is called only after QM_IsNewBar().
   if(copied < lookback + 2)
      return false;

   double abs_ret[];
   ArrayResize(abs_ret, lookback);
   for(int i = 0; i < lookback; ++i)
     {
      if(rates[i + 1].close <= 0.0)
         return false;
      abs_ret[i] = MathAbs((rates[i].close / rates[i + 1].close) - 1.0);
     }

   const double current = abs_ret[0];
   int below_or_equal = 0;
   for(int i = 0; i < lookback; ++i)
      if(abs_ret[i] <= current)
         below_or_equal++;

   const double percentile = 100.0 * (double)below_or_equal / (double)lookback;
   return (percentile > 50.0);
  }

bool HasOpenPositionForMagic()
  {
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
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

bool IsEndOfNewYorkSession(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   if(dt.hour > strategy_ny_close_hour)
      return true;
   if(dt.hour == strategy_ny_close_hour && dt.min >= strategy_ny_close_minute)
      return true;
   return false;
  }

bool IsFirstOrLastTenMinutesOfWeek(const datetime broker_time)
  {
   MqlDateTime dt;
   TimeToStruct(broker_time, dt);
   const int mins = dt.hour * 60 + dt.min;
   if(dt.day_of_week == 1 && mins < 10)
      return true;
   if(dt.day_of_week == 5 && mins >= (24 * 60 - 10))
      return true;
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   const datetime broker_now = TimeCurrent();
   if(IsFirstOrLastTenMinutesOfWeek(broker_now))
      return true;

   const double atr = QM_ATR(_Symbol, PERIOD_M10, strategy_atr_period, 1);
   if(atr <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return true;

   return ((ask - bid) > strategy_spread_atr_frac * atr);
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

   if(g_suppress_entry_this_bar)
     {
      g_suppress_entry_this_bar = false;
      return false;
     }

   if(HasOpenPositionForMagic())
      return false;
   if(IsEndOfNewYorkSession(TimeCurrent()))
      return false;
   if(!RealizedVolatilityFilterPasses())
      return false;

   const double close1 = iClose(_Symbol, PERIOD_M10, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M10, strategy_atr_period, 1);
   if(close1 <= 0.0 || atr <= 0.0)
      return false;

   const double pred_ret = AR10PredictedReturn();
   const double threshold = strategy_entry_atr_frac * atr / close1;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || threshold <= 0.0)
      return false;

   if(pred_ret >= threshold)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "AR10_REV_LONG";
      return (req.sl > 0.0);
     }

   if(pred_ret <= -threshold)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATRFromValue(_Symbol, req.type, req.price, atr, strategy_sl_atr_mult);
      req.tp = 0.0;
      req.reason = "AR10_REV_SHORT";
      return (req.sl > 0.0);
     }

   return false;
  }

void Strategy_ManageOpenPosition()
  {
   // Baseline card uses initial ATR SL plus forecast/time/session exits only.
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   const datetime broker_now = TimeCurrent();
   const double close1 = iClose(_Symbol, PERIOD_M10, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_M10, strategy_atr_period, 1);
   if(close1 <= 0.0 || atr <= 0.0)
      return false;

   const double threshold = strategy_entry_atr_frac * atr / close1;
   const double pred_ret = AR10PredictedReturn();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
      if(strategy_hold_bars > 0 && broker_now - open_time >= strategy_hold_bars * PeriodSeconds(PERIOD_M10))
         return true;

      if(IsEndOfNewYorkSession(broker_now))
         return true;

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && pred_ret <= -threshold)
        {
         g_suppress_entry_this_bar = true;
         return true;
        }
      if(ptype == POSITION_TYPE_SELL && pred_ret >= threshold)
        {
         g_suppress_entry_this_bar = true;
         return true;
        }
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"ea\":\"QM5_10010_rw-fx-ar10-rev\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

   if(!QM_IsNewBar(_Symbol, PERIOD_M10))
      return;

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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
