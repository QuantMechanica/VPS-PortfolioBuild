#property strict
#property version   "5.0"
#property description "QM5_1080 Allocate Smartly Sell in May / Halloween Indicator"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Strategy card: QM5_1080, Allocate Smartly Sell in May / Halloween Indicator.
// Long equity-index risk-on leg from the first tradable November session through
// the final tradable April session. Flat/cash May through October.
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1080;
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
input int    strategy_entry_month        = 10;
input int    strategy_exit_month         = 4;
input int    strategy_entry_offset_from_month_end = 1;
input int    strategy_exit_offset_from_month_end  = -1;
input bool   strategy_exit_on_session_close       = true;
input int    strategy_max_spread_points  = 0;

datetime g_last_entry_d1_bar = 0;
datetime g_last_exit_d1_bar  = 0;

int MonthOf(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.mon;
  }

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
   const datetime next_d1 = NextScheduledTradingDayAfter(current_d1);
   if(next_d1 <= 0)
      return false;

   return (TimeCurrent() >= next_d1 - 60);
  }

bool IsLastScheduledTradingDayOfMonth(const datetime current_d1)
  {
   const int current_month = MonthOf(current_d1);
   const datetime day_start = DateFloor(current_d1);
   for(int day = 1; day <= 10; ++day)
     {
      const datetime candidate = day_start + day * 86400;
      if(MonthOf(candidate) != current_month)
         return true;

      if(HasScheduledTradeSession(candidate))
         return false;
     }

   return false;
  }

bool IsFirstTradingSessionAfterMonth(const datetime current_d1, const int target_month)
  {
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;

   return (MonthOf(prior_d1) == target_month && MonthOf(current_d1) != target_month);
  }

bool IsMonthEndTimingWindow(const int target_month, const int offset_from_month_end, const bool require_session_close)
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0)
      return false;

   const int offset = MathMax(-1, MathMin(1, offset_from_month_end));
   if(offset > 0)
      return IsFirstTradingSessionAfterMonth(current_d1, target_month);

   if(MonthOf(current_d1) != target_month)
      return false;
   if(!IsLastScheduledTradingDayOfMonth(current_d1))
      return false;

   return (!require_session_close || IsNearD1SessionClose(current_d1));
  }

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

   if(!IsMonthEndTimingWindow(strategy_entry_month,
                              strategy_entry_offset_from_month_end,
                              strategy_exit_on_session_close))
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(ask <= 0.0)
      return false;

   req.price = ask;
   req.reason = "AS_SELL_MAY_LONG_NOV_APR";
   g_last_entry_d1_bar = current_d1;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Source rule is calendar-only. No trailing, partial close, or break-even.
  }

bool Strategy_ExitSignal()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0 || current_d1 == g_last_exit_d1_bar)
      return false;

   if(!GetOurPosition())
      return false;

   if(!IsMonthEndTimingWindow(strategy_exit_month,
                              strategy_exit_offset_from_month_end,
                              strategy_exit_on_session_close))
      return false;

   g_last_exit_d1_bar = current_d1;
   return true;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   if(broker_time <= 0)
      return false;
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1080_as_sell_may\"}");
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
