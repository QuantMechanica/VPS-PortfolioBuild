#property strict
#property version   "5.0"
#property description "QM5_1101 Turn-Around Tuesday"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                       = 1101;
input int    qm_magic_slot_offset           = 0;

input group "Risk"
input double RISK_PERCENT                   = 0.0;
input double RISK_FIXED                     = 1000.0;
input double PORTFOLIO_WEIGHT               = 1.0;

input group "News"
input QM_NewsMode qm_news_mode              = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled        = true;
input int    qm_friday_close_hour_broker    = 21;

input group "Strategy"
input double strategy_monday_threshold_pct  = 0.003;
input bool   strategy_enable_long           = true;
input bool   strategy_enable_short          = true;
input double strategy_max_stop_pct          = 0.015;
input int    strategy_max_hold_d1_bars      = 1;

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

bool IsFirstTradingSessionAfterFriday(const datetime current_d1)
  {
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(prior_d1 <= 0)
      return false;

   MqlDateTime prior_dt;
   TimeToStruct(prior_d1, prior_dt);
   if(prior_dt.day_of_week != 5)
      return false;

   const datetime expected = NextScheduledTradingDayAfter(prior_d1);
   return (expected > 0 && DateFloor(expected) == DateFloor(current_d1));
  }

bool IsPreviousBarFirstTradingSessionAfterFriday()
  {
   const datetime signal_d1 = iTime(_Symbol, PERIOD_D1, 1);
   const datetime friday_d1 = iTime(_Symbol, PERIOD_D1, 2);
   if(signal_d1 <= 0 || friday_d1 <= 0)
      return false;

   MqlDateTime friday_dt;
   TimeToStruct(friday_d1, friday_dt);

   const datetime expected = NextScheduledTradingDayAfter(friday_d1);
   if(expected > 0 && DateFloor(expected) == DateFloor(signal_d1))
      return true;

   if(friday_dt.day_of_week == 5)
      return true;

   return ((DateFloor(signal_d1) - DateFloor(friday_d1)) > 86400);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   return (_Period != PERIOD_D1);
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

   if(HasOpenPositionForMagic())
      return false;

   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_entry_d1_bar)
      return false;
   if(!IsPreviousBarFirstTradingSessionAfterFriday())
      return false;

   g_last_entry_d1_bar = current_d1;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double monday_close = iClose(_Symbol, PERIOD_D1, 1);
   const double friday_close = iClose(_Symbol, PERIOD_D1, 2);
   if(ask <= 0.0 || bid <= 0.0 || monday_close <= 0.0 || friday_close <= 0.0)
      return false;

   const double monday_return = (monday_close / friday_close) - 1.0;
   const double threshold = MathMax(0.0, strategy_monday_threshold_pct);
   const double stop_pct = MathMax(0.0, strategy_max_stop_pct);

   if(monday_return < -threshold && strategy_enable_long)
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = ask * (1.0 - stop_pct);
      req.reason = "QM5_1101_MONDAY_DOWN_TUESDAY_LONG";
      return (req.sl > 0.0 && req.sl < ask);
     }

   if(monday_return > threshold && strategy_enable_short)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = bid * (1.0 + stop_pct);
      req.reason = "QM5_1101_MONDAY_UP_TUESDAY_SHORT";
      return (req.sl > bid);
     }

   return false;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
  }

// Trade Close
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1101\",\"ea\":\"turn-around-tuesday\"}");
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
