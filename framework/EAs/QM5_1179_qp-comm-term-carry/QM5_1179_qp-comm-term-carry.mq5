#property strict
#property version   "5.0"
#property description "QM5_1179 Quantpedia Commodity Term-Structure Carry"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1179;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.50;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input string strategy_roll_yield_csv_path = "QM5_1179_commodity_roll_yield.csv";
input int    strategy_min_eligible        = 5;
input double strategy_bucket_pct          = 20.0;
input int    strategy_atr_period          = 20;
input double strategy_atr_sl_mult         = 2.5;
input int    strategy_max_spread_points   = 0;

#define QM5_1179_SYMBOL_COUNT 5

string g_symbols[QM5_1179_SYMBOL_COUNT] = {
   "XAUUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX",
   "XAGUSD.DWX",
   "XCUUSD.DWX"
};

int g_slots[QM5_1179_SYMBOL_COUNT] = {0, 1, 2, 3, 4};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1179_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return qm_magic_slot_offset;
   return g_slots[index];
  }

bool Strategy_IsFirstTradableDayOfMonth()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);
   return (closed_dt.mon != current_dt.mon || closed_dt.year != current_dt.year);
  }

int Strategy_RebalanceKey()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(current_bar, dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_PreviousMonthKey()
  {
   const datetime current_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(current_bar <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(current_bar, dt);
   int year = dt.year;
   int month = dt.mon - 1;
   if(month <= 0)
     {
      month = 12;
      --year;
     }
   return year * 100 + month;
  }

int Strategy_ParseMonthKey(string raw)
  {
   StringTrimLeft(raw);
   StringTrimRight(raw);
   StringReplace(raw, "-", "");
   StringReplace(raw, ".", "");
   StringReplace(raw, "/", "");
   StringReplace(raw, "_", "");
   if(StringLen(raw) < 6)
      return 0;
   const int value = (int)StringToInteger(StringSubstr(raw, 0, 6));
   if(value < 190001 || value > 209912)
      return 0;
   const int month = value % 100;
   if(month < 1 || month > 12)
      return 0;
   return value;
  }

bool Strategy_FieldMatchesSymbol(string field, const int index)
  {
   StringTrimLeft(field);
   StringTrimRight(field);
   StringToUpper(field);
   string symbol = g_symbols[index];
   StringToUpper(symbol);
   return (field == symbol);
  }

bool Strategy_ReadRollYield(const int index, const int month_key, double &out_roll_yield)
  {
   out_roll_yield = 0.0;
   if(index < 0 || index >= QM5_1179_SYMBOL_COUNT || month_key <= 0 || strategy_roll_yield_csv_path == "")
      return false;

   int handle = FileOpen(strategy_roll_yield_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_roll_yield_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   bool found = false;
   while(!FileIsEnding(handle))
     {
      const string symbol_field = FileReadString(handle);
      const string month_field = FileReadString(handle);
      FileReadString(handle);
      FileReadString(handle);
      const string roll_field = FileReadString(handle);

      if(symbol_field == "" && month_field == "" && roll_field == "")
         continue;
      if(!Strategy_FieldMatchesSymbol(symbol_field, index))
         continue;
      if(Strategy_ParseMonthKey(month_field) != month_key)
         continue;

      out_roll_yield = StringToDouble(roll_field);
      found = true;
     }

   FileClose(handle);
   return found;
  }

int Strategy_BuildRollYieldScores(const int month_key, bool &eligible[], double &scores[])
  {
   int count = 0;
   for(int i = 0; i < QM5_1179_SYMBOL_COUNT; ++i)
     {
      eligible[i] = false;
      scores[i] = 0.0;
      if(!SymbolSelect(g_symbols[i], true))
         continue;

      double roll_yield = 0.0;
      if(!Strategy_ReadRollYield(i, month_key, roll_yield))
         continue;

      eligible[i] = true;
      scores[i] = roll_yield;
      ++count;
     }
   return count;
  }

int Strategy_RankDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   const int month_key = Strategy_PreviousMonthKey();
   bool eligible[QM5_1179_SYMBOL_COUNT];
   double scores[QM5_1179_SYMBOL_COUNT];
   const int eligible_count = Strategy_BuildRollYieldScores(month_key, eligible, scores);
   if(eligible_count < strategy_min_eligible)
      return 0;

   int indexes[QM5_1179_SYMBOL_COUNT];
   double ranked_scores[QM5_1179_SYMBOL_COUNT];
   int count = 0;
   for(int i = 0; i < QM5_1179_SYMBOL_COUNT; ++i)
     {
      if(!eligible[i])
         continue;
      indexes[count] = i;
      ranked_scores[count] = scores[i];
      ++count;
     }

   int bucket_size = (int)MathFloor((double)count * strategy_bucket_pct / 100.0);
   if(bucket_size < 1)
      bucket_size = 1;
   if(bucket_size > count / 2)
      bucket_size = count / 2;
   if(bucket_size <= 0)
      return 0;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(ranked_scores[j] < ranked_scores[i])
           {
            const double tmp_score = ranked_scores[i];
            ranked_scores[i] = ranked_scores[j];
            ranked_scores[j] = tmp_score;
            const int tmp_index = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = tmp_index;
           }

   for(int i = 0; i < bucket_size; ++i)
      if(indexes[i] == current_index)
         return -1;

   for(int i = count - bucket_size; i < count; ++i)
      if(indexes[i] == current_index)
         return 1;

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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   return (spread > 0 && spread <= strategy_max_spread_points);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_min_eligible < 5)
      return true;
   if(strategy_bucket_pct <= 0.0 || strategy_bucket_pct > 50.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1179_COMM_TERM_CARRY";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!Strategy_IsFirstTradableDayOfMonth())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_rebalance_key)
      return false;
   g_last_entry_rebalance_key = rebalance_key;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_RankDirection();
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

   req.reason = (direction > 0) ? "QM5_1179_TERM_CARRY_LONG" : "QM5_1179_TERM_CARRY_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed ATR stop and next-month rebalance only.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsFirstTradableDayOfMonth())
      return false;
   if(!Strategy_HasOpenPosition())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;
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

   for(int i = 0; i < QM5_1179_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1179\",\"ea\":\"qp-comm-term-carry\"}");
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
