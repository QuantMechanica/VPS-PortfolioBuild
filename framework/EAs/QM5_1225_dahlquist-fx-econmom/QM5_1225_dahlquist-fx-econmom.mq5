#property strict
#property version   "5.0"
#property description "QM5_1225 Dahlquist-Hasseltoft FX Economic Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1225;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 500.0;
input double PORTFOLIO_WEIGHT            = 0.142857;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_OFF;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_NONE;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input string strategy_macro_csv_path      = "QM5_1225_fx_econmom.csv";
input int    strategy_macro_lookback_months = 6;
input int    strategy_rank_count_entry    = 1;
input int    strategy_rank_count_exit     = 2;
input int    strategy_macro_stale_days    = 45;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_min_eligible        = 5;

#define QM5_1225_SYMBOL_COUNT 7
#define QM5_1225_MAX_MACRO_ROWS 1024

string g_symbols[QM5_1225_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "NZDUSD.DWX",
   "USDCAD.DWX", "USDCHF.DWX", "USDJPY.DWX"
  };

string g_countries[QM5_1225_SYMBOL_COUNT] =
  {
   "EUR", "GBP", "AUD", "NZD", "CAD", "CHF", "JPY"
  };

int g_last_entry_month_key = 0;
int g_last_exit_month_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsUsdBaseSymbol(const string symbol)
  {
   return (symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX" || symbol == "USDJPY.DWX");
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

string Strategy_NormalizeKey(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   return s;
  }

bool Strategy_IsMonthOpenBar()
  {
   const datetime closed_day = iTime(_Symbol, PERIOD_D1, 1);
   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(closed_day <= 0 || current_day <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_day, closed_dt);
   TimeToStruct(current_day, current_dt);
   return (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon);
  }

int Strategy_MonthKey()
  {
   const datetime current_day = iTime(_Symbol, PERIOD_D1, 0);
   if(current_day <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(current_day, dt);
   return dt.year * 100 + dt.mon;
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
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return true;
     }
   return false;
  }

bool Strategy_ReadMacroTable(double &scores[], bool &eligible[], datetime &latest_obs)
  {
   ArrayInitialize(scores, 0.0);
   ArrayInitialize(eligible, false);
   latest_obs = 0;

   if(strategy_macro_csv_path == "")
      return false;

   int handle = FileOpen(strategy_macro_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_macro_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   datetime obs[QM5_1225_SYMBOL_COUNT][QM5_1225_MAX_MACRO_ROWS];
   double ip[QM5_1225_SYMBOL_COUNT][QM5_1225_MAX_MACRO_ROWS];
   double cpi[QM5_1225_SYMBOL_COUNT][QM5_1225_MAX_MACRO_ROWS];
   int counts[QM5_1225_SYMBOL_COUNT];
   ArrayInitialize(counts, 0);

   while(!FileIsEnding(handle))
     {
      const string country_field = FileReadString(handle);
      const string date_field = FileReadString(handle);
      const string ip_field = FileReadString(handle);
      const string cpi_field = FileReadString(handle);
      if(country_field == "" && date_field == "" && ip_field == "" && cpi_field == "")
         continue;

      const datetime date_value = Strategy_ParseDate(date_field);
      if(date_value <= 0 || date_value > TimeCurrent())
         continue;

      const string country = Strategy_NormalizeKey(country_field);
      int idx = -1;
      for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
         if(country == g_countries[i])
           {
            idx = i;
            break;
           }
      if(idx < 0)
         continue;

      int n = counts[idx];
      if(n >= QM5_1225_MAX_MACRO_ROWS)
        {
         for(int j = 1; j < QM5_1225_MAX_MACRO_ROWS; ++j)
           {
            obs[idx][j - 1] = obs[idx][j];
            ip[idx][j - 1] = ip[idx][j];
            cpi[idx][j - 1] = cpi[idx][j];
           }
         n = QM5_1225_MAX_MACRO_ROWS - 1;
        }
      obs[idx][n] = date_value;
      ip[idx][n] = StringToDouble(ip_field);
      cpi[idx][n] = StringToDouble(cpi_field);
      counts[idx] = n + 1;
     }

   FileClose(handle);

   double ip_change[QM5_1225_SYMBOL_COUNT];
   double cpi_change[QM5_1225_SYMBOL_COUNT];
   ArrayInitialize(ip_change, 0.0);
   ArrayInitialize(cpi_change, 0.0);

   int eligible_count = 0;
   const int lookback_days = MathMax(strategy_macro_lookback_months, 1) * 30;
   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
     {
      if(counts[i] < 2)
         continue;

      for(int a = 0; a < counts[i] - 1; ++a)
         for(int b = a + 1; b < counts[i]; ++b)
            if(obs[i][b] < obs[i][a])
              {
               const datetime tmp_obs = obs[i][a];
               obs[i][a] = obs[i][b];
               obs[i][b] = tmp_obs;
               const double tmp_ip = ip[i][a];
               ip[i][a] = ip[i][b];
               ip[i][b] = tmp_ip;
               const double tmp_cpi = cpi[i][a];
               cpi[i][a] = cpi[i][b];
               cpi[i][b] = tmp_cpi;
              }

      const int last = counts[i] - 1;
      if(latest_obs <= 0 || obs[i][last] < latest_obs)
         latest_obs = obs[i][last];

      int prev = -1;
      const datetime target = obs[i][last] - lookback_days * 86400;
      for(int j = last - 1; j >= 0; --j)
         if(obs[i][j] <= target)
           {
            prev = j;
            break;
           }

      if(prev < 0)
         continue;

      ip_change[i] = ip[i][last] - ip[i][prev];
      cpi_change[i] = cpi[i][last] - cpi[i][prev];
      eligible[i] = true;
      ++eligible_count;
     }

   if(eligible_count < strategy_min_eligible)
      return false;
   if(strategy_macro_stale_days > 0 && latest_obs > 0 && (TimeCurrent() - latest_obs) > strategy_macro_stale_days * 86400)
      return false;

   double mean_ip = 0.0;
   double mean_cpi = 0.0;
   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
      if(eligible[i])
        {
         mean_ip += ip_change[i];
         mean_cpi += cpi_change[i];
        }
   mean_ip /= eligible_count;
   mean_cpi /= eligible_count;

   double var_ip = 0.0;
   double var_cpi = 0.0;
   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
      if(eligible[i])
        {
         var_ip += MathPow(ip_change[i] - mean_ip, 2.0);
         var_cpi += MathPow(cpi_change[i] - mean_cpi, 2.0);
        }

   const double sd_ip = MathSqrt(var_ip / MathMax(eligible_count - 1, 1));
   const double sd_cpi = MathSqrt(var_cpi / MathMax(eligible_count - 1, 1));
   if(sd_ip <= 0.0 || sd_cpi <= 0.0)
      return false;

   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
      if(eligible[i])
         scores[i] = ((ip_change[i] - mean_ip) / sd_ip) + ((cpi_change[i] - mean_cpi) / sd_cpi);

   return true;
  }

int Strategy_RankForIndex(const int index, const double &scores[], const bool &eligible[])
  {
   if(index < 0 || index >= QM5_1225_SYMBOL_COUNT || !eligible[index])
      return 0;

   int rank = 1;
   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
      if(i != index && eligible[i] && scores[i] > scores[index])
         ++rank;
   return rank;
  }

int Strategy_DesiredDirection(const int rank_limit)
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return 0;

   double scores[QM5_1225_SYMBOL_COUNT];
   bool eligible[QM5_1225_SYMBOL_COUNT];
   datetime latest_obs = 0;
   if(!Strategy_ReadMacroTable(scores, eligible, latest_obs))
      return 0;

   const int rank = Strategy_RankForIndex(index, scores, eligible);
   if(rank <= 0)
      return 0;

   int eligible_count = 0;
   for(int i = 0; i < QM5_1225_SYMBOL_COUNT; ++i)
      if(eligible[i])
         ++eligible_count;

   int local_direction = 0;
   const int clamped_limit = MathMax(rank_limit, 1);
   if(rank <= clamped_limit)
      local_direction = 1;
   else if(rank > eligible_count - clamped_limit)
      local_direction = -1;

   if(local_direction == 0)
      return 0;
   return Strategy_IsUsdBaseSymbol(_Symbol) ? -local_direction : local_direction;
  }

bool Strategy_NoTradeFilter()
  {
   return (Strategy_CurrentSymbolIndex() < 0);
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "DAHLQUIST_FX_ECONMOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(_Period != PERIOD_D1 || !Strategy_IsMonthOpenBar())
      return false;

   const int month_key = Strategy_MonthKey();
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;

   const int direction = Strategy_DesiredDirection(strategy_rank_count_entry);
   if(direction == 0)
      return false;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   const int slot = Strategy_CurrentSymbolIndex();
   req.symbol_slot = slot;
   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = (direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (direction > 0) ? "ECONMOM_TOP_LONG_USD_PAIR" : "ECONMOM_BOTTOM_SHORT_USD_PAIR";
   if(req.sl <= 0.0)
      return false;

   g_last_entry_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies hard ATR stops and monthly rebalance exits only.
  }

bool Strategy_ExitSignal()
  {
   if(_Period != PERIOD_D1 || !Strategy_IsMonthOpenBar())
      return false;

   const int month_key = Strategy_MonthKey();
   if(month_key <= 0 || month_key == g_last_exit_month_key)
      return false;

   const int desired_direction = Strategy_DesiredDirection(strategy_rank_count_exit);
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

      const long pos_type = PositionGetInteger(POSITION_TYPE);
      const int current_direction = (pos_type == POSITION_TYPE_BUY) ? 1 : -1;
      if(desired_direction == 0 || desired_direction != current_direction)
        {
         g_last_exit_month_key = month_key;
         return true;
        }
     }

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
