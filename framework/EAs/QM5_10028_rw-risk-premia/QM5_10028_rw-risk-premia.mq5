#property strict
#property version   "5.0"
#property description "QM5_10028 Robot Wealth Risk Premia Harvesting"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 10028;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = false;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input int    strategy_vol_lookback_days  = 63;
input int    strategy_momentum_days      = 126;
input int    strategy_gold_momentum_days = 63;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 4.0;
input int    strategy_min_eligible       = 2;
input double strategy_max_spread_points  = 0.0;

string StrategySymbolBySlot(const int slot)
  {
   switch(slot)
     {
      case 0: return "SP500.DWX";
      case 1: return "NDX.DWX";
      case 2: return "WS30.DWX";
      case 3: return "XAUUSD.DWX";
      case 4: return "XTIUSD.DWX";
     }
   return "";
  }

bool StrategySymbolInBasket(const string symbol)
  {
   for(int i = 0; i < 5; ++i)
      if(symbol == StrategySymbolBySlot(i))
         return true;
   return false;
  }

bool StrategyIsFirstSessionAfterMonthEnd()
  {
   return true; // OnTick gates monthly evaluation with QM_IsNewBar(PERIOD_MN1).
  }

double StrategyReturn(const string symbol, const int lookback_days)
  {
   if(lookback_days <= 0)
      return 0.0;
   if(Bars(symbol, PERIOD_D1) < lookback_days + 2)
      return 0.0;

   const double recent = QM_SMA(symbol, PERIOD_D1, 1, 1);
   const double past = QM_SMA(symbol, PERIOD_D1, 1, 1 + lookback_days);
   if(recent <= 0.0 || past <= 0.0)
      return 0.0;
   return (recent / past) - 1.0;
  }

double StrategyRealizedVol(const string symbol, const int lookback_days)
  {
   if(lookback_days < 2)
      return 0.0;

   double sum = 0.0;
   double sumsq = 0.0;
   int samples = 0;
   for(int i = 1; i <= lookback_days; ++i)
     {
      const double c0 = QM_SMA(symbol, PERIOD_D1, 1, i);
      const double c1 = QM_SMA(symbol, PERIOD_D1, 1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;

      const double r = MathLog(c0 / c1);
      sum += r;
      sumsq += r * r;
      samples++;
     }

   if(samples < 2)
      return 0.0;
   const double mean = sum / samples;
   const double variance = (sumsq / samples) - (mean * mean);
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

bool StrategySymbolEligible(const string symbol)
  {
   if(!StrategySymbolInBasket(symbol))
      return false;

   const double vol = StrategyRealizedVol(symbol, strategy_vol_lookback_days);
   if(vol <= 0.0)
      return false;

   if(symbol == "XAUUSD.DWX")
      return (StrategyReturn(symbol, strategy_gold_momentum_days) > 0.0);

   return (StrategyReturn(symbol, strategy_momentum_days) > 0.0);
  }

int StrategyEligibleCount()
  {
   int count = 0;
   for(int i = 0; i < 5; ++i)
      if(StrategySymbolEligible(StrategySymbolBySlot(i)))
         count++;
   return count;
  }

bool StrategyHasOpenPosition()
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(!StrategySymbolInBasket(_Symbol))
      return true;

   if(strategy_max_spread_points > 0.0)
     {
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
         return true;
      if((ask - bid) / point > strategy_max_spread_points)
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
   req.reason = "RW_RISK_PREMIA_MONTHLY_LONG";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!StrategyIsFirstSessionAfterMonthEnd())
      return false;
   if(StrategyHasOpenPosition())
      return false;
   if(StrategyEligibleCount() < strategy_min_eligible)
      return false;
   if(!StrategySymbolEligible(_Symbol))
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, QM_BUY, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, partial close, or break-even management.
  }

bool Strategy_ExitSignal()
  {
   if(!StrategyIsFirstSessionAfterMonthEnd())
      return false;
   if(!StrategyHasOpenPosition())
      return false;
   if(StrategyEligibleCount() < strategy_min_eligible)
      return true;
   return !StrategySymbolEligible(_Symbol);
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_10028\",\"ea\":\"QM5_10028_rw-risk-premia\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_MN1))
      return;

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
