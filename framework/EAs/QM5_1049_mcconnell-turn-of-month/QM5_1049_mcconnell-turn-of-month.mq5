#property strict
#property version   "5.0"
#property description "QM5_1049 McConnell-Xu Turn-of-the-Month Equity Index"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1049;
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
input int    strategy_atr_period         = 14;
input double strategy_atr_stop_mult      = 3.0;
input bool   strategy_regime_filter      = false;
input int    strategy_regime_sma_period  = 200;
input int    strategy_exit_trading_day   = 4;
input int    strategy_max_spread_points  = 0;

datetime g_last_entry_d1_bar = 0;
datetime g_last_exit_d1_bar  = 0;

int MonthOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

bool GetOurPosition()
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
      return true;
     }

   return false;
  }

bool IsFirstTradingSessionOfMonth()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;

   return (MonthOf(current_d1) != MonthOf(prior_d1));
  }

int TradingDayOrdinalInMonth(const int shift)
  {
   const datetime target = iTime(_Symbol, PERIOD_D1, shift);
   if(target <= 0)
      return 0;

   const int target_month = MonthOf(target);
   int ordinal = 0;
   for(int s = shift; s < shift + 32; ++s)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, s);
      if(bar_time <= 0 || MonthOf(bar_time) != target_month)
         break;
      ordinal++;
     }

   return ordinal;
  }

bool RegimeAllowsEntry()
  {
   if(!strategy_regime_filter)
      return true;

   const int p = MathMax(2, strategy_regime_sma_period);
   const double sma_recent = QM_SMA(_Symbol, PERIOD_D1, p, 1);
   const double sma_prior = QM_SMA(_Symbol, PERIOD_D1, p, 2);
   if(sma_recent <= 0.0 || sma_prior <= 0.0)
      return false;

   return (sma_recent >= sma_prior);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(strategy_max_spread_points > 0)
     {
      const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
      if(spread > strategy_max_spread_points)
         return true;
     }

   return false;
  }

// Trade Entry
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_entry_d1_bar)
      return false;

   if(GetOurPosition())
      return false;

   if(!IsFirstTradingSessionOfMonth())
      return false;

   g_last_entry_d1_bar = current_d1;
   if(!RegimeAllowsEntry())
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || point <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_atr_stop_mult <= 0.0)
      return false;

   req.price = ask;
   req.sl = ask - (atr * strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "MCCONNELL_TOM_T_MINUS_1_TO_T_PLUS_3";
   return (req.sl > 0.0 && req.sl < ask && ((ask - req.sl) / point) > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_exit_d1_bar)
      return false;

   if(!GetOurPosition())
      return false;

   const int exit_day = MathMax(2, strategy_exit_trading_day);
   if(TradingDayOrdinalInMonth(0) < exit_day)
      return false;

   g_last_exit_d1_bar = current_d1;
   return true;
  }

// News Filter Hook (callable for P8 News Impact phase)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1049\",\"ea\":\"mcconnell_turn_of_month\"}");
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

   if(!QM_IsNewBar())
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
