#property strict
#property version   "5.0"
#property description "QM5_1056 Moskowitz Time-Series Momentum Multi-Asset"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1056;
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
input int    strategy_lookback_d1_bars    = 252;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 4.0;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_mult         = 3.0;
input int    strategy_entry_offset_from_month_end = -1;
input int    strategy_exit_offset_from_month_end  = -1;
input bool   strategy_exit_on_session_close       = true;
input int    strategy_rebalance_interval_days     = 0;

const int STRATEGY_UNIVERSE_SIZE = 10;
string    g_universe_symbols[10] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX", "USDCAD.DWX",
   "XAUUSD.DWX", "XTIUSD.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX"
  };
int       g_universe_slots[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};
int       g_last_entry_rebalance_key = 0;
int       g_last_exit_rebalance_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_RebalanceKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_IntervalRebalanceKey(const datetime t)
  {
   if(strategy_rebalance_interval_days <= 0)
      return Strategy_RebalanceKey(t);
   const int interval_days = MathMax(2, strategy_rebalance_interval_days);
   return (int)(DateFloor(t) / 86400) / interval_days;
  }

bool Strategy_IsIntervalTimingWindow()
  {
   if(strategy_rebalance_interval_days <= 0)
      return false;
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;
   return (Strategy_IntervalRebalanceKey(current_d1) != Strategy_IntervalRebalanceKey(prior_d1));
  }

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

bool IsFirstTradingSessionOfMonth()
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   const datetime prior_d1 = iTime(_Symbol, PERIOD_D1, 1);
   if(current_d1 <= 0 || prior_d1 <= 0)
      return false;

   return (MonthOf(current_d1) != MonthOf(prior_d1));
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

bool IsLastTradingSessionBeforeMonthChange(const bool require_session_close)
  {
   const datetime current_d1 = iTime(_Symbol, PERIOD_D1, 0);
   if(current_d1 <= 0)
      return false;

   if(!IsLastScheduledTradingDayOfMonth(current_d1))
      return false;

   return (!require_session_close || IsNearD1SessionClose(current_d1));
  }

bool Strategy_IsMonthEndTimingWindow(const int offset_from_month_end, const bool require_session_close)
  {
   if(strategy_rebalance_interval_days > 0)
      return Strategy_IsIntervalTimingWindow();

   const int offset = MathMax(-1, MathMin(1, offset_from_month_end));
   if(offset > 0)
      return IsFirstTradingSessionOfMonth();

   return IsLastTradingSessionBeforeMonthChange(offset < 0 && require_session_close);
  }

int Strategy_TsmomDirection()
  {
   if(strategy_lookback_d1_bars <= 0)
      return 0;

   const double recent_close = iClose(_Symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(_Symbol, PERIOD_D1, 1 + strategy_lookback_d1_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return 0;

   if(recent_close > lookback_close)
      return 1;
   if(recent_close < lookback_close)
      return -1;
   return 0;
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

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      count++;
     }

   if(count <= 0)
      return 0.0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_SpreadAllowsEntry()
  {
   const double median_spread = Strategy_MedianDailySpreadPoints();
   if(median_spread <= 0.0 || strategy_spread_mult <= 0.0)
      return true;

   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   return ((double)current_spread <= median_spread * strategy_spread_mult);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
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
   req.reason = "QM5_1056_TSMOM_MONTHLY";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthEndTimingWindow(strategy_entry_offset_from_month_end, strategy_exit_on_session_close))
      return false;

   const datetime rebalance_bar = (strategy_entry_offset_from_month_end > 0 && strategy_rebalance_interval_days <= 0) ? iTime(_Symbol, PERIOD_D1, 1) : iTime(_Symbol, PERIOD_D1, 0);
   const int rebalance_key = Strategy_IntervalRebalanceKey(rebalance_bar);
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_TsmomDirection();
   if(direction == 0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.symbol_slot = qm_magic_slot_offset;
   req.reason = (direction > 0) ? "QM5_1056_TSMOM_LONG" : "QM5_1056_TSMOM_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, or partial close; hard ATR SL only.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsMonthEndTimingWindow(strategy_exit_offset_from_month_end, strategy_exit_on_session_close))
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const datetime rebalance_bar = (strategy_exit_offset_from_month_end > 0 && strategy_rebalance_interval_days <= 0) ? iTime(_Symbol, PERIOD_D1, 1) : iTime(_Symbol, PERIOD_D1, 0);
   const int rebalance_key = Strategy_IntervalRebalanceKey(rebalance_bar);
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   if(rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1056\",\"ea\":\"moskowitz-tsmom-multiasset\"}");
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
