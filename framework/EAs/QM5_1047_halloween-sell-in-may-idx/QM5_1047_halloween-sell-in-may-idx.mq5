#property strict
#property version   "5.0"
#property description "QM5_1047 Halloween / Sell-in-May Equity Index Seasonality"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1047;
input int    qm_magic_slot_offset         = 0;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 1.0;

input group "News"
input QM_NewsMode qm_news_mode            = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = false;
input int    qm_friday_close_hour_broker  = 21;

input group "Strategy"
input int    strategy_entry_month         = 10;
input int    strategy_exit_month          = 4;
input int    strategy_atr_period          = 14;
input double strategy_atr_stop_mult       = 4.0;
input bool   strategy_momentum_overlay    = false;
input int    strategy_momentum_months     = 6;

datetime g_last_bar_time = 0;
datetime g_last_signal_bar_time = 0;
int      g_atr_handle = INVALID_HANDLE;

bool IsNewBar()
  {
   const datetime t0 = iTime(_Symbol, _Period, 0);
   if(t0 <= 0)
      return false;
   if(t0 == g_last_bar_time)
      return false;
   g_last_bar_time = t0;
   return true;
  }

int MonthOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

bool MonthTransitionFrom(const int prior_month)
  {
   const datetime current_bar = iTime(_Symbol, _Period, 0);
   const datetime prior_bar = iTime(_Symbol, _Period, 1);
   if(current_bar <= 0 || prior_bar <= 0)
      return false;
   if(current_bar == g_last_signal_bar_time)
      return false;
   if(MonthOf(prior_bar) != prior_month)
      return false;
   if(MonthOf(current_bar) == prior_month)
      return false;
   return true;
  }

void MarkSignalProcessed()
  {
   g_last_signal_bar_time = iTime(_Symbol, _Period, 0);
  }

bool ReadATR(const int shift, double &atr_value)
  {
   atr_value = 0.0;
   if(g_atr_handle == INVALID_HANDLE)
      return false;

   double buffer[1];
   if(CopyBuffer(g_atr_handle, 0, shift, 1, buffer) != 1)
      return false;
   if(buffer[0] <= 0.0)
      return false;

   atr_value = buffer[0];
   return true;
  }

bool MomentumOverlayAllowsEntry()
  {
   if(!strategy_momentum_overlay)
      return true;

   const int lookback_bars = MathMax(1, strategy_momentum_months) * 21;
   const double recent_close = iClose(_Symbol, PERIOD_D1, 1);
   const double past_close = iClose(_Symbol, PERIOD_D1, 1 + lookback_bars);
   if(recent_close <= 0.0 || past_close <= 0.0)
      return false;

   return (recent_close > past_close);
  }

bool GetOurPosition(ulong &ticket)
  {
   ticket = 0;
   const int magic = QM_FrameworkMagic();
   if(magic <= 0)
      return false;

   const int total = PositionsTotal();
   for(int i = 0; i < total; ++i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      return true;
     }

   return false;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(!QM_KillSwitchCheck())
      return true;
   if(!QM_NewsAllowsTrade(_Symbol, TimeCurrent(), qm_news_mode))
      return true;
   if(QM_FrameworkHandleFridayClose())
      return true;
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

   if(!MonthTransitionFrom(strategy_entry_month))
      return false;
   if(!MomentumOverlayAllowsEntry())
     {
      MarkSignalProcessed();
      return false;
     }

   double atr = 0.0;
   if(!ReadATR(1, atr))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.price = ask;
   req.sl = ask - (atr * strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = "HALLOWEEN_LONG_NOV_APR";
   return (req.sl > 0.0 && req.sl < ask);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card baseline has no trailing, partial close, or break-even management.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!MonthTransitionFrom(strategy_exit_month))
      return false;

   ulong ticket = 0;
   if(!GetOurPosition(ticket))
     {
      MarkSignalProcessed();
      return false;
     }

   MarkSignalProcessed();
   return QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
  }

// News Filter Hook (callable for P8 News Impact phase)
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return QM_NewsAllowsTrade(_Symbol, broker_time, qm_news_mode);
  }

int OnInit()
  {
   g_atr_handle = iATR(_Symbol, PERIOD_D1, strategy_atr_period);
   if(g_atr_handle == INVALID_HANDLE)
      return INIT_FAILED;

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1047\",\"ea\":\"halloween_sell_in_may_idx\"}");
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   if(g_atr_handle != INVALID_HANDLE)
     {
      IndicatorRelease(g_atr_handle);
      g_atr_handle = INVALID_HANDLE;
     }

   QM_LogEvent(QM_INFO, "DEINIT", StringFormat("{\"reason\":%d}", reason));
   QM_FrameworkShutdown();
  }

void OnTick()
  {
   if(Strategy_NoTradeFilter())
      return;

   ulong ticket = 0;
   const bool has_position = GetOurPosition(ticket);
   if(has_position)
      Strategy_ManageOpenPosition();

   if(!IsNewBar())
      return;

   if(Strategy_ExitSignal())
      return;

   if(has_position)
      return;

   QM_EntryRequest req;
   if(Strategy_EntrySignal(req))
     {
      ulong out_ticket = 0;
      QM_TM_OpenPosition(req, out_ticket);
      MarkSignalProcessed();
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
