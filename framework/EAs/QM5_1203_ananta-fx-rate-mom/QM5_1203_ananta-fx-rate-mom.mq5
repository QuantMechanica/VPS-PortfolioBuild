#property strict
#property version   "5.0"
#property description "QM5_1203 ANANTA FX Rate Momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1203;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
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
input string strategy_rates_csv_path       = "QM5_1203_fx_rates.csv";
input int    strategy_rate_sma_days        = 15;
input int    strategy_min_observations     = 30;
input int    strategy_stale_business_days  = 3;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.0;
input int    strategy_rebalance_mode       = 2;       // 0 London, 1 New York, 2 both
input int    strategy_london_hour_broker   = 9;
input int    strategy_newyork_hour_broker  = 15;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_mult          = 3.0;
input double strategy_daily_loss_r_mult    = 2.0;

#define QM5_1203_SYMBOL_COUNT 7
#define QM5_1203_CCY_COUNT 8
#define QM5_1203_MAX_RATE_ROWS 512

string g_symbols[QM5_1203_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "NZDUSD.DWX", "USDCAD.DWX", "USDCHF.DWX"
  };

string g_local_ccy[QM5_1203_SYMBOL_COUNT] =
  {
   "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"
  };

string g_rate_ccys[QM5_1203_CCY_COUNT] =
  {
   "USD", "EUR", "GBP", "JPY", "AUD", "NZD", "CAD", "CHF"
  };

int g_last_entry_key = 0;
int g_last_exit_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1203_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

bool Strategy_IsUsdBaseSymbol(const string symbol)
  {
   return (symbol == "USDJPY.DWX" || symbol == "USDCAD.DWX" || symbol == "USDCHF.DWX");
  }

int Strategy_CcyIndex(const string ccy)
  {
   for(int i = 0; i < QM5_1203_CCY_COUNT; ++i)
      if(g_rate_ccys[i] == ccy)
         return i;
   return -1;
  }

datetime Strategy_ParseDate(const string raw)
  {
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(s + " 00:00");
  }

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_IsBusinessDay(const datetime value)
  {
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return (dt.day_of_week >= 1 && dt.day_of_week <= 5);
  }

int Strategy_BusinessDaysSince(const datetime obs_date)
  {
   if(obs_date <= 0)
      return 9999;

   const datetime now = TimeCurrent();
   if(obs_date > now)
      return 0;

   int count = 0;
   datetime cursor = obs_date + 86400;
   while(cursor <= now && count < 1000)
     {
      if(Strategy_IsBusinessDay(cursor))
         ++count;
      cursor += 86400;
     }
   return count;
  }

bool Strategy_IsScheduledRebalanceClosedBar()
  {
   if(_Period != PERIOD_H1 && _Period != PERIOD_D1)
      return false;

   const datetime closed_bar = iTime(_Symbol, _Period, 1);
   const datetime current_bar = iTime(_Symbol, _Period, 0);
   if(closed_bar <= 0 || current_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime current_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(current_bar, current_dt);

   const bool new_day = (closed_dt.year != current_dt.year || closed_dt.mon != current_dt.mon || closed_dt.day != current_dt.day);
   if(_Period == PERIOD_D1)
      return new_day;

   bool scheduled = false;
   if((strategy_rebalance_mode == 0 || strategy_rebalance_mode == 2) &&
      closed_dt.hour < strategy_london_hour_broker && current_dt.hour >= strategy_london_hour_broker)
      scheduled = true;
   if((strategy_rebalance_mode == 1 || strategy_rebalance_mode == 2) &&
      closed_dt.hour < strategy_newyork_hour_broker && current_dt.hour >= strategy_newyork_hour_broker)
      scheduled = true;

   return scheduled;
  }

int Strategy_RebalanceKey()
  {
   const datetime t = iTime(_Symbol, _Period, 0);
   if(t <= 0)
      return 0;

   MqlDateTime dt;
   TimeToStruct(t, dt);
   int session = 0;
   if(_Period == PERIOD_D1)
      session = 2;
   else if(dt.hour >= strategy_newyork_hour_broker)
      session = 2;
   else
      session = 1;
   return dt.year * 1000000 + dt.mon * 10000 + dt.day * 100 + session;
  }

bool Strategy_ReadRates(const string local_ccy, double &latest_diff, double &sma_diff, datetime &latest_obs)
  {
   latest_diff = 0.0;
   sma_diff = 0.0;
   latest_obs = 0;

   if(strategy_rates_csv_path == "")
      return false;

   int local_idx = Strategy_CcyIndex(local_ccy);
   int usd_idx = Strategy_CcyIndex("USD");
   if(local_idx < 0 || usd_idx < 0)
      return false;

   int handle = FileOpen(strategy_rates_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ, ',');
   if(handle == INVALID_HANDLE)
      handle = FileOpen(strategy_rates_csv_path, FILE_READ | FILE_CSV | FILE_ANSI | FILE_SHARE_READ | FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
      return false;

   datetime obs[QM5_1203_MAX_RATE_ROWS];
   double diffs[QM5_1203_MAX_RATE_ROWS];
   int count = 0;
   while(!FileIsEnding(handle))
     {
      const string date_field = FileReadString(handle);
      double rates[QM5_1203_CCY_COUNT];
      bool valid = true;
      for(int i = 0; i < QM5_1203_CCY_COUNT; ++i)
        {
         const string raw = FileReadString(handle);
         rates[i] = StringToDouble(raw);
         if(raw == "" && i == 0 && date_field == "")
           {
            valid = false;
            break;
           }
        }

      const datetime date_value = Strategy_ParseDate(date_field);
      if(!valid || date_value <= 0 || date_value > TimeCurrent())
         continue;

      if(count >= QM5_1203_MAX_RATE_ROWS)
        {
         for(int j = 1; j < QM5_1203_MAX_RATE_ROWS; ++j)
           {
            obs[j - 1] = obs[j];
            diffs[j - 1] = diffs[j];
           }
         count = QM5_1203_MAX_RATE_ROWS - 1;
        }

      obs[count] = date_value;
      diffs[count] = rates[local_idx] - rates[usd_idx];
      ++count;
     }

   FileClose(handle);

   const int sma_days = MathMax(strategy_rate_sma_days, 1);
   const int min_obs = MathMax(strategy_min_observations, sma_days);
   if(count < min_obs)
      return false;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(obs[j] < obs[i])
           {
            const datetime tmp_obs = obs[i];
            obs[i] = obs[j];
            obs[j] = tmp_obs;
            const double tmp_diff = diffs[i];
            diffs[i] = diffs[j];
            diffs[j] = tmp_diff;
           }

   latest_obs = obs[count - 1];
   latest_diff = diffs[count - 1];
   if(strategy_stale_business_days > 0 && Strategy_BusinessDaysSince(latest_obs) > strategy_stale_business_days)
      return false;

   double sum = 0.0;
   for(int i = count - sma_days; i < count; ++i)
      sum += diffs[i];
   sma_diff = sum / (double)sma_days;
   return MathIsValidNumber(latest_diff) && MathIsValidNumber(sma_diff);
  }

int Strategy_DirectionForSymbol()
  {
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return 0;

   double diff = 0.0;
   double sma = 0.0;
   datetime obs = 0;
   if(!Strategy_ReadRates(g_local_ccy[index], diff, sma, obs))
      return 0;

   int local_direction = 0;
   if(diff > sma)
      local_direction = 1;
   else if(diff < sma)
      local_direction = -1;

   if(local_direction == 0)
      return 0;
   return Strategy_IsUsdBaseSymbol(_Symbol) ? -local_direction : local_direction;
  }

double Strategy_MedianDailySpreadPoints()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_days > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= strategy_spread_median_days; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
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

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rebalance_mode < 0 || strategy_rebalance_mode > 2)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "ANANTA_FX_RATE_MOM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_IsScheduledRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_entry_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int direction = Strategy_DirectionForSymbol();
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
   req.reason = (direction > 0) ? "ANANTA_RATE_DIFF_ABOVE_SMA" : "ANANTA_RATE_DIFF_BELOW_SMA";
   if(req.sl <= 0.0)
      return false;

   g_last_entry_key = rebalance_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // The card specifies only hard ATR stop and scheduled rebalance exits.
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsScheduledRebalanceClosedBar())
      return false;

   const int rebalance_key = Strategy_RebalanceKey();
   if(rebalance_key <= 0 || rebalance_key == g_last_exit_key)
      return false;

   const int desired_direction = Strategy_DirectionForSymbol();
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
         g_last_exit_key = rebalance_key;
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
