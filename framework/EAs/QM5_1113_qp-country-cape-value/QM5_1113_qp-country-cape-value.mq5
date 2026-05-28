#property strict
#property version   "5.0"
#property description "QM5_1113 Quantpedia Country CAPE Value"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1113;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal        = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance      = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_cape_csv_path       = "QM5_1113_country_cape.csv";
input double strategy_cape_threshold      = 15.0;
input double strategy_bucket_pct          = 33.0;
input int    strategy_min_eligible        = 3;
input int    strategy_csv_stale_days      = 800;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 5.0;

#define QM5_1113_SYMBOL_COUNT 7

string g_symbols[QM5_1113_SYMBOL_COUNT] = {
   "NDX.DWX",
   "WS30.DWX",
   "GDAXI.DWX",
   "UK100.DWX",
   "JPN225.DWX",
   "AUS200.DWX",
   "SP500.DWX"
};
string g_countries[QM5_1113_SYMBOL_COUNT] = {
   "US_NASDAQ",
   "US_DOW",
   "GERMANY",
   "UK",
   "JAPAN",
   "AUSTRALIA",
   "US_SP500"
};
int g_slots[QM5_1113_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

datetime g_last_entry_rebalance_day = 0;
datetime g_last_exit_rebalance_day = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1113_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_SlotForCurrentSymbol()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0)
      return qm_magic_slot_offset;
   return g_slots[idx];
  }

datetime Strategy_LastClosedD1Time()
  {
   return iTime(_Symbol, PERIOD_D1, 1);
  }

bool Strategy_IsYearEndRebalanceDay(const datetime closed_day)
  {
   if(closed_day <= 0)
      return false;

   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_day, closed_dt);
   TimeToStruct(current_day, current_dt);
   return (closed_dt.year != current_dt.year);
  }

datetime Strategy_ParseDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(StringSubstr(s, 0, 10) + " 00:00");
  }

bool Strategy_FieldMatchesSymbolOrCountry(const string field, const int index)
  {
   string f = field;
   StringTrimLeft(f);
   StringTrimRight(f);
   StringToUpper(f);

   string symbol = g_symbols[index];
   string country = g_countries[index];
   StringToUpper(symbol);
   StringToUpper(country);

   return (f == symbol || f == country);
  }

bool Strategy_ReadLatestCape(const int index,
                             const datetime as_of,
                             double &out_cape,
                             datetime &out_obs_date)
  {
   out_cape = 0.0;
   out_obs_date = 0;
   if(index < 0 || index >= QM5_1113_SYMBOL_COUNT || strategy_cape_csv_path == "")
      return false;

   int handle = FileOpen(strategy_cape_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_cape_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      const string key_field = FileReadString(handle);
      const string third_field = FileReadString(handle);
      string fourth_field = "";
      if(!FileIsLineEnding(handle) && !FileIsEnding(handle))
         fourth_field = FileReadString(handle);

      const datetime obs_date = Strategy_ParseDate(date_field);
      if(obs_date <= 0 || obs_date > as_of)
         continue;

      double cape = 0.0;
      bool matched = false;
      if(Strategy_FieldMatchesSymbolOrCountry(key_field, index))
        {
         cape = StringToDouble(third_field);
         matched = true;
        }
      else if(Strategy_FieldMatchesSymbolOrCountry(third_field, index))
        {
         cape = StringToDouble(fourth_field);
         matched = true;
        }

      if(!matched || cape <= 0.0)
         continue;

      if(obs_date >= out_obs_date)
        {
         out_obs_date = obs_date;
         out_cape = cape;
        }
     }

   FileClose(handle);
   if(out_cape <= 0.0 || out_obs_date <= 0)
      return false;

   if(strategy_csv_stale_days > 0 && (as_of - out_obs_date) > strategy_csv_stale_days * 86400)
      return false;

   return true;
  }

void Strategy_SortAscending(double &scores[], int &indexes[], const int count)
  {
   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(scores[j] < scores[i])
           {
            const double score_tmp = scores[i];
            scores[i] = scores[j];
            scores[j] = score_tmp;

            const int index_tmp = indexes[i];
            indexes[i] = indexes[j];
            indexes[j] = index_tmp;
           }
  }

bool Strategy_CurrentSymbolSelected()
  {
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0 || strategy_bucket_pct <= 0.0 || strategy_cape_threshold <= 0.0)
      return false;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(rebalance_day <= 0)
      return false;

   double scores[QM5_1113_SYMBOL_COUNT];
   int indexes[QM5_1113_SYMBOL_COUNT];
   int count = 0;

   for(int i = 0; i < QM5_1113_SYMBOL_COUNT; ++i)
     {
      double cape = 0.0;
      datetime obs_date = 0;
      if(!Strategy_ReadLatestCape(i, rebalance_day, cape, obs_date))
         continue;
      if(cape >= strategy_cape_threshold)
         continue;

      scores[count] = cape;
      indexes[count] = i;
      ++count;
     }

   if(count < strategy_min_eligible)
      return false;

   Strategy_SortAscending(scores, indexes, count);
   int bucket = (int)MathCeil((double)count * strategy_bucket_pct / 100.0);
   bucket = MathMax(1, MathMin(bucket, count));

   for(int i = 0; i < bucket; ++i)
      if(indexes[i] == current_index)
         return true;

   return false;
  }

bool Strategy_TradingStatusValid(const string symbol)
  {
   if(!SymbolSelect(symbol, true))
      return false;
   return (SymbolInfoInteger(symbol, SYMBOL_TRADE_MODE) != SYMBOL_TRADE_MODE_DISABLED);
  }

bool Strategy_HasOpenPosition(ulong &ticket, datetime &opened_at)
  {
   ticket = 0;
   opened_at = 0;

   const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
   if(magic <= 0)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      ticket = pos_ticket;
      opened_at = (datetime)PositionGetInteger(POSITION_TIME);
      return true;
     }

   return false;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsYearEndRebalanceDay(rebalance_day) || g_last_entry_rebalance_day == rebalance_day)
      return false;

   ulong ticket = 0;
   datetime opened_at = 0;
   if(Strategy_HasOpenPosition(ticket, opened_at))
      return false;
   if(!Strategy_CurrentSymbolSelected())
      return false;

   const double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(entry <= 0.0)
      return false;

   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   const double sl = QM_StopATRFromValue(_Symbol, QM_BUY, entry, atr, strategy_atr_sl_mult);
   if(sl <= 0.0 || sl >= entry)
      return false;

   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = sl;
   req.tp = 0.0;
   req.reason = "QM5_1113_COUNTRY_CAPE_VALUE_LONG";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   g_last_entry_rebalance_day = rebalance_day;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   datetime opened_at = 0;
   if(!Strategy_HasOpenPosition(ticket, opened_at))
      return false;
   if(!Strategy_TradingStatusValid(_Symbol))
      return true;

   const datetime rebalance_day = Strategy_LastClosedD1Time();
   if(!Strategy_IsYearEndRebalanceDay(rebalance_day) || g_last_exit_rebalance_day == rebalance_day)
      return false;
   if(opened_at >= rebalance_day)
      return false;
   if(Strategy_CurrentSymbolSelected())
      return false;

   g_last_exit_rebalance_day = rebalance_day;
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
                        qm_news_mode_legacy,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker,
                        30,
                        30,
                        qm_news_stale_max_hours,
                        qm_news_min_impact,
                        qm_rng_seed,
                        qm_stress_reject_probability,
                        qm_news_temporal,
                        qm_news_compliance))
      return INIT_FAILED;

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_atr_period_d1 + 5);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1113_qp-country-cape-value\"}");
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

   bool news_allows = true;
   if(qm_news_temporal != QM_NEWS_TEMPORAL_OFF || qm_news_compliance != QM_NEWS_COMPLIANCE_NONE)
      news_allows = QM_NewsAllowsTrade2(_Symbol, broker_now, qm_news_temporal, qm_news_compliance);
   else
      news_allows = QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode_legacy);
   if(!news_allows)
      return;

   if(QM_FrameworkHandleFridayClose())
      return;
   if(Strategy_NoTradeFilter())
      return;

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
     {
      const int magic = QM_Magic(qm_ea_id, Strategy_SlotForCurrentSymbol());
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

   QM_EquityStreamOnNewBar();

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

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   QM_FrameworkOnTradeTransaction(trans, request, result);
  }

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
