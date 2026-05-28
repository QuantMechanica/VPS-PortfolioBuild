#property strict
#property version   "5.0"
#property description "QM5_1247 Fuertes Commodity TSMOM Term Structure"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1247;
input int    qm_magic_slot_offset        = 0;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.333333;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input string strategy_curve_csv_path       = "QM5_1247_comm_curve.csv";
input int    strategy_momentum_months      = 12;
input double strategy_term_threshold       = 0.0;
input int    strategy_min_daily_bars       = 252;
input int    strategy_curve_stale_months   = 1;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;
input int    strategy_max_spread_points    = 0;

#define QM5_1247_SYMBOL_COUNT 3

string g_symbols[QM5_1247_SYMBOL_COUNT] = {"XAUUSD.DWX", "XAGUSD.DWX", "XTIUSD.DWX"};
string g_roots[QM5_1247_SYMBOL_COUNT] = {"XAU", "XAG", "XTI"};
int g_slots[QM5_1247_SYMBOL_COUNT] = {0, 1, 2};

int g_last_entry_rebalance_key = 0;
int g_last_exit_rebalance_key = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1247_SYMBOL_COUNT; ++i)
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
   const int month = value % 100;
   if(value < 190001 || value > 209912 || month < 1 || month > 12)
      return 0;
   return value;
  }

int Strategy_MonthDistance(const int newer_key, const int older_key)
  {
   if(newer_key <= 0 || older_key <= 0)
      return 9999;
   return ((newer_key / 100) - (older_key / 100)) * 12 + ((newer_key % 100) - (older_key % 100));
  }

bool Strategy_FieldMatchesRoot(string field, const int index)
  {
   StringTrimLeft(field);
   StringTrimRight(field);
   StringToUpper(field);
   string root = g_roots[index];
   StringToUpper(root);
   string symbol = g_symbols[index];
   StringToUpper(symbol);
   return (field == root || field == symbol);
  }

bool Strategy_ReadTermSpread(const int index, const int rebalance_key, double &out_spread)
  {
   out_spread = 0.0;
   if(index < 0 || index >= QM5_1247_SYMBOL_COUNT || strategy_curve_csv_path == "")
      return false;

   int handle = FileOpen(strategy_curve_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_curve_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   int best_key = 0;
   double best_spread = 0.0;
   while(!FileIsEnding(handle))
     {
      const string root_field = FileReadString(handle);
      const string month_field = FileReadString(handle);
      const string near_field = FileReadString(handle);
      const string deferred_field = FileReadString(handle);

      if(root_field == "" && month_field == "" && near_field == "" && deferred_field == "")
         continue;
      if(!Strategy_FieldMatchesRoot(root_field, index))
         continue;

      const int month_key = Strategy_ParseMonthKey(month_field);
      if(month_key <= 0 || month_key > rebalance_key)
         continue;

      const double near_price = StringToDouble(near_field);
      const double deferred_price = StringToDouble(deferred_field);
      if(near_price <= 0.0 || deferred_price <= 0.0)
         continue;

      if(month_key > best_key)
        {
         best_key = month_key;
         best_spread = near_price / deferred_price - 1.0;
        }
     }

   FileClose(handle);

   if(best_key <= 0)
      return false;
   if(Strategy_MonthDistance(rebalance_key, best_key) > strategy_curve_stale_months)
      return false;

   out_spread = best_spread;
   return true;
  }

bool Strategy_Momentum(const string symbol, double &out_momentum)
  {
   out_momentum = 0.0;
   const int lookback_bars = MathMax(1, strategy_momentum_months) * 21;
   const int required = MathMax(strategy_min_daily_bars, lookback_bars + 2);
   SymbolSelect(symbol, true);
   if(iBars(symbol, PERIOD_D1) < required)
      return false;

   const double recent_close = iClose(symbol, PERIOD_D1, 1);
   const double lookback_close = iClose(symbol, PERIOD_D1, 1 + lookback_bars);
   if(recent_close <= 0.0 || lookback_close <= 0.0)
      return false;

   out_momentum = recent_close / lookback_close - 1.0;
   return true;
  }

void Strategy_RankAscending(const double &values[], int &ranks[])
  {
   for(int i = 0; i < QM5_1247_SYMBOL_COUNT; ++i)
      ranks[i] = 1;
   for(int i = 0; i < QM5_1247_SYMBOL_COUNT; ++i)
      for(int j = 0; j < QM5_1247_SYMBOL_COUNT; ++j)
         if(values[j] < values[i])
            ++ranks[i];
  }

bool Strategy_BuildSignals(double &momentum[], double &term_spread[], double &score[])
  {
   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0)
      return false;

   for(int i = 0; i < QM5_1247_SYMBOL_COUNT; ++i)
     {
      if(!Strategy_Momentum(g_symbols[i], momentum[i]))
         return false;
      if(!Strategy_ReadTermSpread(i, rebalance_key, term_spread[i]))
         return false;
     }

   int mom_rank[QM5_1247_SYMBOL_COUNT];
   int term_rank[QM5_1247_SYMBOL_COUNT];
   Strategy_RankAscending(momentum, mom_rank);
   Strategy_RankAscending(term_spread, term_rank);

   for(int i = 0; i < QM5_1247_SYMBOL_COUNT; ++i)
      score[i] = (double)(mom_rank[i] + term_rank[i]);

   return true;
  }

int Strategy_TargetDirection()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   double momentum[QM5_1247_SYMBOL_COUNT];
   double term_spread[QM5_1247_SYMBOL_COUNT];
   double score[QM5_1247_SYMBOL_COUNT];
   if(!Strategy_BuildSignals(momentum, term_spread, score))
      return 0;

   int top_index = 0;
   int bottom_index = 0;
   for(int i = 1; i < QM5_1247_SYMBOL_COUNT; ++i)
     {
      if(score[i] > score[top_index])
         top_index = i;
      if(score[i] < score[bottom_index])
         bottom_index = i;
     }

   const double threshold = MathMax(strategy_term_threshold, 0.0);
   if(current_index == top_index && momentum[current_index] > 0.0 && term_spread[current_index] > threshold)
      return 1;
   if(current_index == bottom_index && momentum[current_index] < 0.0 && term_spread[current_index] < -threshold)
      return -1;
   return 0;
  }

bool Strategy_SelectOurPosition(ulong &ticket, ENUM_POSITION_TYPE &ptype)
  {
   ticket = 0;
   ptype = POSITION_TYPE_BUY;
   const int magic = QM_FrameworkMagic();

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = t;
      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }

   return false;
  }

bool Strategy_HasOpenPosition()
  {
   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   return Strategy_SelectOurPosition(ticket, ptype);
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
   if(strategy_momentum_months <= 0 || strategy_min_daily_bars < 252)
      return true;
   if(strategy_curve_stale_months < 0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1247_COMM_TSMOM_TERM";
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

   const int direction = Strategy_TargetDirection();
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

   req.reason = (direction > 0) ? "QM5_1247_COMM_TSMOM_LONG" : "QM5_1247_COMM_TSMOM_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies fixed 3 ATR stop and monthly rebalance; no trailing layer.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1)
      return false;
   if(!Strategy_IsFirstTradableDayOfMonth())
      return false;

   ulong ticket = 0;
   ENUM_POSITION_TYPE ptype = POSITION_TYPE_BUY;
   if(!Strategy_SelectOurPosition(ticket, ptype))
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_rebalance_key)
      return false;
   g_last_exit_rebalance_key = rebalance_key;

   const int target = Strategy_TargetDirection();
   if(target == 0)
      return true;
   if(ptype == POSITION_TYPE_BUY && target < 0)
      return true;
   if(ptype == POSITION_TYPE_SELL && target > 0)
      return true;
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

   for(int i = 0; i < QM5_1247_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1247\",\"ea\":\"fuertes-comm-tsmom\"}");
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
