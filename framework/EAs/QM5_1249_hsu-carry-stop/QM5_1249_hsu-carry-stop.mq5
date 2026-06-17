#property strict
#property version   "5.0"
#property description "QM5_1249 Hsu-Taylor-Wang FX Carry With Fixed ATR Stop"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                     = 1249;
input int    qm_magic_slot_offset         = 0;
input uint   qm_rng_seed                  = 42;

input group "Risk"
input double RISK_PERCENT                 = 0.0;
input double RISK_FIXED                   = 1000.0;
input double PORTFOLIO_WEIGHT             = 0.166667;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled      = true;
input int    qm_friday_close_hour_broker  = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_rates_csv_path      = "QM5_1249_fx_monthly_rates.csv";
input int    strategy_rank_count          = 2;
input int    strategy_stale_calendar_days = 45;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_stop_mult       = 2.5;
input int    strategy_rebalance_months    = 1;
input int    strategy_rebalance_day_limit = 7;
input double strategy_max_spread_pips     = 0.0;

#define QM5_1249_SYMBOL_COUNT 6
#define QM5_1249_CCY_COUNT 8

string g_symbols[QM5_1249_SYMBOL_COUNT] =
  {
   "AUDJPY.DWX", "NZDJPY.DWX", "GBPJPY.DWX",
   "USDJPY.DWX", "AUDUSD.DWX", "NZDUSD.DWX"
  };

string g_base_ccy[QM5_1249_SYMBOL_COUNT] =
  {
   "AUD", "NZD", "GBP", "USD", "AUD", "NZD"
  };

string g_quote_ccy[QM5_1249_SYMBOL_COUNT] =
  {
   "JPY", "JPY", "JPY", "JPY", "USD", "USD"
  };

string g_rate_ccys[QM5_1249_CCY_COUNT] =
  {
   "USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"
  };

int g_last_entry_month_key = 0;
int g_last_exit_month_key = 0;
int g_stopped_month_key[QM5_1249_SYMBOL_COUNT];

int Strategy_CurrentMonthKey()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.year * 100 + dt.mon;
  }

int Strategy_CurrentDayOfMonth()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.day;
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1249_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_CcyIndex(const string ccy)
  {
   for(int i = 0; i < QM5_1249_CCY_COUNT; ++i)
      if(g_rate_ccys[i] == ccy)
         return i;
   return -1;
  }

datetime Strategy_ParseDate(const string raw)
  {
   string value = raw;
   StringTrimLeft(value);
   StringTrimRight(value);
   if(StringLen(value) < 10)
      return 0;
   StringReplace(value, "-", ".");
   return StringToTime(value + " 00:00");
  }

bool Strategy_ReadLatestRates(double &rates[])
  {
   ArrayInitialize(rates, 0.0);
   if(strategy_rates_csv_path == "")
      return false;

   int handle = FileOpen(strategy_rates_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_rates_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   datetime latest_date = 0;
   double latest_rates[QM5_1249_CCY_COUNT];
   ArrayInitialize(latest_rates, 0.0);

   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      double row_rates[QM5_1249_CCY_COUNT];
      bool valid = true;

      for(int i = 0; i < QM5_1249_CCY_COUNT; ++i)
        {
         if(FileIsEnding(handle))
           {
            valid = false;
            break;
           }
         row_rates[i] = StringToDouble(FileReadString(handle));
        }

      const datetime row_date = Strategy_ParseDate(date_field);
      if(!valid || row_date <= 0 || row_date > TimeCurrent())
         continue;

      if(row_date >= latest_date)
        {
         latest_date = row_date;
         for(int i = 0; i < QM5_1249_CCY_COUNT; ++i)
            latest_rates[i] = row_rates[i];
        }
     }

   FileClose(handle);
   if(latest_date <= 0)
      return false;

   const int stale_days = (int)((TimeCurrent() - latest_date) / 86400);
   if(strategy_stale_calendar_days > 0 && stale_days > strategy_stale_calendar_days)
      return false;

   for(int i = 0; i < QM5_1249_CCY_COUNT; ++i)
      rates[i] = latest_rates[i];
   return true;
  }

bool Strategy_RateDifferentials(double &diffs[])
  {
   ArrayInitialize(diffs, 0.0);

   double rates[QM5_1249_CCY_COUNT];
   if(!Strategy_ReadLatestRates(rates))
      return false;

   for(int i = 0; i < QM5_1249_SYMBOL_COUNT; ++i)
     {
      const int base_idx = Strategy_CcyIndex(g_base_ccy[i]);
      const int quote_idx = Strategy_CcyIndex(g_quote_ccy[i]);
      if(base_idx < 0 || quote_idx < 0)
         return false;
      diffs[i] = rates[base_idx] - rates[quote_idx];
      if(!MathIsValidNumber(diffs[i]))
         return false;
     }

   return true;
  }

int Strategy_DesiredDirectionForSymbol()
  {
   const int current = Strategy_CurrentSymbolIndex();
   if(current < 0)
      return 0;

   double diffs[QM5_1249_SYMBOL_COUNT];
   if(!Strategy_RateDifferentials(diffs))
      return 0;

   int rank_count = strategy_rank_count;
   if(rank_count < 1)
      rank_count = 1;
   if(rank_count > QM5_1249_SYMBOL_COUNT / 2)
      rank_count = QM5_1249_SYMBOL_COUNT / 2;

   int order[QM5_1249_SYMBOL_COUNT];
   for(int i = 0; i < QM5_1249_SYMBOL_COUNT; ++i)
      order[i] = i;

   for(int i = 0; i < QM5_1249_SYMBOL_COUNT - 1; ++i)
      for(int j = i + 1; j < QM5_1249_SYMBOL_COUNT; ++j)
         if(diffs[order[j]] > diffs[order[i]])
           {
            const int tmp = order[i];
            order[i] = order[j];
            order[j] = tmp;
           }

   for(int i = 0; i < rank_count; ++i)
      if(order[i] == current && diffs[current] > 0.0)
         return 1;

   for(int i = QM5_1249_SYMBOL_COUNT - rank_count; i < QM5_1249_SYMBOL_COUNT; ++i)
      if(order[i] == current && diffs[current] < 0.0)
         return -1;

   return 0;
  }

bool Strategy_HasOpenPosition(int &direction)
  {
   direction = 0;
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

      direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
  }

bool Strategy_IsMonthlyRebalanceWindow()
  {
   const int month_key = Strategy_CurrentMonthKey();
   if(month_key <= 0)
      return false;

   if(strategy_rebalance_months > 1 && (month_key % strategy_rebalance_months) != 0)
      return false;

   const int day = Strategy_CurrentDayOfMonth();
   if(strategy_rebalance_day_limit > 0 && day > strategy_rebalance_day_limit)
      return false;

   return true;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_pips <= 0.0)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(!(ask > bid))
      return true;

   const double cap = QM_StopRulesPipsToPriceDistance(_Symbol, (int)MathRound(strategy_max_spread_pips));
   if(cap <= 0.0)
      return true;
   return ((ask - bid) <= cap);
  }

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rebalance_months < 1)
      return true;
   if(strategy_atr_period_d1 < 1 || strategy_atr_stop_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "HSU_CARRY_STOP";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsMonthlyRebalanceWindow())
      return false;

   const int month_key = Strategy_CurrentMonthKey();
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   g_last_entry_month_key = month_key;

   int existing_direction = 0;
   if(Strategy_HasOpenPosition(existing_direction))
      return false;

   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0 || g_stopped_month_key[symbol_idx] == month_key)
      return false;

   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int desired_direction = Strategy_DesiredDirectionForSymbol();
   if(desired_direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   req.symbol_slot = symbol_idx;
   req.type = (desired_direction > 0) ? QM_BUY : QM_SELL;
   req.price = 0.0;
   const double stop_entry = (desired_direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, stop_entry, strategy_atr_period_d1, strategy_atr_stop_mult);
   req.tp = 0.0;
   req.reason = (desired_direction > 0) ? "HSU_CARRY_TOP2_POSITIVE" : "HSU_CARRY_BOTTOM2_NEGATIVE";
   return (req.sl > 0.0);
  }

void Strategy_ManageOpenPosition()
  {
   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0)
      return;

   const int magic = QM_FrameworkMagic();
   const int month_key = Strategy_CurrentMonthKey();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      const double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0)
         continue;

      const long type = PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((type == POSITION_TYPE_BUY && bid > 0.0 && bid <= sl) ||
         (type == POSITION_TYPE_SELL && ask > 0.0 && ask >= sl))
         g_stopped_month_key[symbol_idx] = month_key;
     }
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsMonthlyRebalanceWindow())
      return false;

   const int month_key = Strategy_CurrentMonthKey();
   if(month_key <= 0 || month_key == g_last_exit_month_key)
      return false;

   int current_direction = 0;
   if(!Strategy_HasOpenPosition(current_direction))
      return false;

   const int desired_direction = Strategy_DesiredDirectionForSymbol();
   if(desired_direction == 0 || desired_direction != current_direction)
     {
      g_last_exit_month_key = month_key;
      return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   ArrayInitialize(g_stopped_month_key, 0);

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
   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
