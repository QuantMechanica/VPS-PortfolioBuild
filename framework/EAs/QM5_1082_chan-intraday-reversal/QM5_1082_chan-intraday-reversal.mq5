#property strict
#property version   "5.0"
#property description "QM5_1082 Chan Intraday Cross-Sectional Reversal"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1082;
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
input int    strategy_rank_count         = 1;
input int    strategy_entry_hhmm         = 1700;
input int    strategy_close_hhmm         = 2255;
input int    strategy_open_delay_minutes = 30;
input int    strategy_atr_period         = 14;
input double strategy_atr_sl_mult        = 1.5;
input double strategy_max_spread_atr     = 0.10;

const int    STRATEGY_UNIVERSE_SIZE = 4;
string       g_universe[4] = {"SP500.DWX", "NDX.DWX", "WS30.DWX", "GDAXI.DWX"};
datetime     g_last_entry_bar_time = 0;
int          g_last_entry_day_key = 0;

int Hhmm(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.hour * 100 + dt.min);
  }

int DayKey(const datetime t)
  {
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 1000 + dt.day_of_year);
  }

int AddMinutesToHhmm(const int hhmm, const int minutes)
  {
   int total = (hhmm / 100) * 60 + (hhmm % 100) + minutes;
   while(total < 0)
      total += 24 * 60;
   total %= 24 * 60;
   return (total / 60) * 100 + (total % 60);
  }

bool TimeInWindow(const int hhmm, const int start_hhmm, const int end_hhmm)
  {
   if(start_hhmm <= end_hhmm)
      return (hhmm >= start_hhmm && hhmm < end_hhmm);
   return (hhmm >= start_hhmm || hhmm < end_hhmm);
  }

bool HasOurOpenPosition()
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

bool PriorOneDayReturn(const string symbol, double &ret)
  {
   ret = 0.0;
   const double c1 = iClose(symbol, PERIOD_D1, 1);
   const double c2 = iClose(symbol, PERIOD_D1, 2);
   if(c1 <= 0.0 || c2 <= 0.0)
      return false;
   ret = (c1 / c2) - 1.0;
   return true;
  }

int RankDirectionForSymbol(const string symbol)
  {
   double symbol_ret = 0.0;
   if(!PriorOneDayReturn(symbol, symbol_ret))
      return 0;

   int lower_count = 0;
   int higher_count = 0;
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
     {
      double r = 0.0;
      if(!PriorOneDayReturn(g_universe[i], r))
         return 0;
      if(r < symbol_ret)
         lower_count++;
      if(r > symbol_ret)
         higher_count++;
     }

   const int n = MathMax(1, MathMin(strategy_rank_count, STRATEGY_UNIVERSE_SIZE / 2));
   if(lower_count < n)
      return 1;
   if(higher_count < n)
      return -1;
   return 0;
  }

bool SpreadAllowed()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask <= bid)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_H1, strategy_atr_period, 1);
   if(atr <= 0.0)
      return false;
   return ((ask - bid) <= atr * strategy_max_spread_atr);
  }

bool Strategy_NoTradeFilter()
  {
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

   if(HasOurOpenPosition())
      return false;

   const datetime now = TimeCurrent();
   const int now_hhmm = Hhmm(now);
   const int earliest_entry = AddMinutesToHhmm(strategy_entry_hhmm, strategy_open_delay_minutes);
   if(!TimeInWindow(now_hhmm, earliest_entry, strategy_close_hhmm))
      return false;

   const datetime bar_time = iTime(_Symbol, _Period, 0);
   const int day_key = DayKey(now);
   if(g_last_entry_bar_time == bar_time || g_last_entry_day_key == day_key)
      return false;

   if(!SpreadAllowed())
      return false;

   const int direction = RankDirectionForSymbol(_Symbol);
   if(direction == 0)
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                        : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "QM5_1082_PRIOR_DAY_WORST_LONG" : "QM5_1082_PRIOR_DAY_BEST_SHORT";

   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   g_last_entry_bar_time = bar_time;
   g_last_entry_day_key = day_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   if(!HasOurOpenPosition())
      return false;
   return (Hhmm(TimeCurrent()) >= strategy_close_hhmm);
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      SymbolSelect(g_universe[i], true);

   if(!QM_FrameworkInit(qm_ea_id,
                        qm_magic_slot_offset,
                        RISK_PERCENT,
                        RISK_FIXED,
                        PORTFOLIO_WEIGHT,
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1082\",\"ea\":\"chan-intraday-reversal\"}");
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
