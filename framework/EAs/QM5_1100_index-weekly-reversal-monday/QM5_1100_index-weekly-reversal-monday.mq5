#property strict
#property version   "5.0"
#property description "QM5_1100 Index Weekly Reversal Monday"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                         = 1100;
input int    qm_magic_slot_offset             = 0;

input group "Risk"
input double RISK_PERCENT                     = 0.0;
input double RISK_FIXED                       = 1000.0;
input double PORTFOLIO_WEIGHT                 = 1.0;

input group "News"
input QM_NewsMode qm_news_mode                = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled          = false;
input int    qm_friday_close_hour_broker      = 21;

input group "Strategy"
input int    strategy_weekly_return_bars      = 5;
input double strategy_weekly_return_threshold = 0.0;
input int    strategy_max_hold_d1_bars        = 1;
input double strategy_max_stop_pct            = 0.02;
input bool   strategy_long_only               = true;

datetime g_last_entry_d1_bar = 0;
datetime g_last_exit_d1_bar = 0;

datetime DateFloor(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;
   return StructToTime(dt);
  }

bool HasScheduledTradeSession(const datetime date_time)
  {
   MqlDateTime dt;
   TimeToStruct(date_time, dt);

   datetime session_from = 0;
   datetime session_to = 0;
   for(uint session = 0; session < 10; ++session)
     {
      if(SymbolInfoSessionTrade(_Symbol, (ENUM_DAY_OF_WEEK)dt.day_of_week, session, session_from, session_to))
         return true;
     }

   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

datetime NextScheduledTradingDayAfter(const datetime bar_time)
  {
   const datetime day_start = DateFloor(bar_time);
   for(int day = 1; day <= 10; ++day)
     {
      const datetime candidate = day_start + day * 86400;
      if(HasScheduledTradeSession(candidate))
         return candidate;
     }
   return 0;
  }

bool IsNearD1SessionClose(const datetime current_d1)
  {
   if(current_d1 <= 0)
      return false;

   const datetime nominal_close = current_d1 + PeriodSeconds(PERIOD_D1);
   return (TimeCurrent() >= nominal_close - 60);
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

datetime GetOurPositionOpenTime()
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
         return (datetime)PositionGetInteger(POSITION_TIME);
     }
   return 0;
  }

int TradingBarsSinceOpen(const datetime open_time, const datetime current_d1)
  {
   const datetime open_day = DateFloor(open_time);
   int bars = 0;
   for(int shift = 0; shift < 32; ++shift)
     {
      const datetime bar_time = iTime(_Symbol, PERIOD_D1, shift);
      if(bar_time <= 0)
         break;
      if(bar_time <= open_day)
         break;
      if(bar_time <= current_d1)
         bars++;
     }
   return bars;
  }

bool IsFridayBar(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.day_of_week == 5);
  }

bool IsLastTradingSessionBeforeWeekend(const datetime signal_d1, const datetime next_d1)
  {
   if(signal_d1 <= 0 || next_d1 <= 0)
      return false;
   if(IsFridayBar(signal_d1))
      return true;
   return ((DateFloor(next_d1) - DateFloor(signal_d1)) > 86400);
  }

bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
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

   if(!strategy_long_only)
      return false;
   if(HasOpenPositionForMagic())
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime signal_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || signal_d1 <= 0 || current_d1 == g_last_entry_d1_bar)
      return false;
   if(!IsLastTradingSessionBeforeWeekend(signal_d1, current_d1))
      return false;

   g_last_entry_d1_bar = current_d1;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const int lookback = MathMax(1, strategy_weekly_return_bars);
   const double friday_close = iClose(_Symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(_Symbol, PERIOD_D1, 1 + lookback);
   if(entry <= 0.0 || friday_close <= 0.0 || lookback_close <= 0.0)
      return false;

   const double weekly_return = (friday_close / lookback_close) - 1.0;
   if(weekly_return >= strategy_weekly_return_threshold)
      return false;

   req.price = entry;
   req.sl = entry * (1.0 - MathMax(0.0, strategy_max_stop_pct));
   req.tp = 0.0;
   req.reason = "QM5_1100_FRIDAY_NEG_WEEK_LONG";
   return (req.sl > 0.0 && req.sl < entry);
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasOpenPositionForMagic())
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_exit_d1_bar)
      return false;

   const datetime open_time = GetOurPositionOpenTime();
   if(open_time <= 0)
      return false;

   const int hold_bars = TradingBarsSinceOpen(open_time, current_d1);
   if(hold_bars < MathMax(1, strategy_max_hold_d1_bars))
      return false;

   g_last_exit_d1_bar = current_d1;
   return true;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1100\",\"ea\":\"index-weekly-reversal-monday\"}");
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
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
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

   if(!QM_IsNewBar())
      return;
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
