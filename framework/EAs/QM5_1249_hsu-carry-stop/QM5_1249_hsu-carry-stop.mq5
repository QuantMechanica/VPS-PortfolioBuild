#property strict
#property version   "5.0"
#property description "QM5_1249 Hsu Carry Stop"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1249;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.166667;

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
input string strategy_rates_csv_path       = "QM5_1249_fx_monthly_rates.csv";
input int    strategy_rank_count           = 2;
input int    strategy_stale_calendar_days  = 45;
input int    strategy_atr_period_d1        = 20;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_rebalance_months     = 1;
input bool   strategy_vol_filter_enabled   = false;
input int    strategy_vol_window_d1        = 20;
input int    strategy_vol_baseline_d1      = 252;
input double strategy_vol_percentile       = 80.0;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_mult          = 3.0;

#define QM5_1249_SYMBOL_COUNT 6
#define QM5_1249_CCY_COUNT 8
#define QM5_1249_MAX_RATE_ROWS 512

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
int g_last_exit_month_key  = 0;
int g_stopped_month_key[QM5_1249_SYMBOL_COUNT];

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
   string s = raw;
   StringTrimLeft(s);
   StringTrimRight(s);
   if(StringLen(s) < 10)
      return 0;
   StringReplace(s, "-", ".");
   return StringToTime(s + " 00:00");
  }

int Strategy_MonthKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 100 + dt.mon;
  }

bool Strategy_IsFirstTradingDayOfMonth()
  {
   const datetime closed_bar = iTime(_Symbol, PERIOD_D1, 1);
   const datetime previous_bar = iTime(_Symbol, PERIOD_D1, 2);
   if(closed_bar <= 0 || previous_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime previous_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(previous_bar, previous_dt);
   return (closed_dt.mon != previous_dt.mon || closed_dt.year != previous_dt.year);
  }

bool Strategy_IsScheduledRebalanceClosedBar()
  {
   if(_Period != PERIOD_D1 && _Period != PERIOD_H1)
      return false;

   if(_Period == PERIOD_D1)
      return Strategy_IsFirstTradingDayOfMonth();

   const datetime closed_bar = iTime(_Symbol, PERIOD_H1, 1);
   const datetime previous_bar = iTime(_Symbol, PERIOD_H1, 2);
   if(closed_bar <= 0 || previous_bar <= 0)
      return false;

   MqlDateTime closed_dt;
   MqlDateTime previous_dt;
   TimeToStruct(closed_bar, closed_dt);
   TimeToStruct(previous_bar, previous_dt);
   return (closed_dt.mon != previous_dt.mon || closed_dt.year != previous_dt.year);
  }

bool Strategy_ReadLatestRates(double &rates[], datetime &latest_obs)
  {
   latest_obs = 0;
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
         const string raw_rate = FileReadString(handle);
         row_rates[i] = StringToDouble(raw_rate);
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

   latest_obs = latest_date;
   for(int i = 0; i < QM5_1249_CCY_COUNT; ++i)
      rates[i] = latest_rates[i];
   return true;
  }

bool Strategy_RateDifferentials(double &diffs[])
  {
   ArrayInitialize(diffs, 0.0);

   double rates[QM5_1249_CCY_COUNT];
   datetime latest_obs = 0;
   if(!Strategy_ReadLatestRates(rates, latest_obs))
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

bool Strategy_RealizedVol(const string symbol, const int end_shift, double &out_vol)
  {
   out_vol = 0.0;
   if(strategy_vol_window_d1 < 2 || strategy_vol_window_d1 > 128 || end_shift < 1)
      return false;

   SymbolSelect(symbol, true);
   if(Bars(symbol, PERIOD_D1) < end_shift + strategy_vol_window_d1 + 2)
      return false;

   double returns[128];
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < strategy_vol_window_d1; ++i)
     {
      const int shift = end_shift + i;
      const double close_now = iClose(symbol, PERIOD_D1, shift);
      const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;
      const double r = MathLog(close_now / close_prev);
      returns[count] = r;
      sum += r;
      ++count;
     }

   const double mean = sum / (double)count;
   double var_sum = 0.0;
   for(int i = 0; i < count; ++i)
     {
      const double diff = returns[i] - mean;
      var_sum += diff * diff;
     }

   out_vol = MathSqrt(var_sum / (double)(count - 1)) * MathSqrt(252.0);
   return (out_vol > 0.0);
  }

bool Strategy_BasketVolAtShift(const int end_shift, double &out_vol)
  {
   out_vol = 0.0;
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < QM5_1249_SYMBOL_COUNT; ++i)
     {
      double vol = 0.0;
      if(!Strategy_RealizedVol(g_symbols[i], end_shift, vol))
         continue;
      sum += vol;
      ++count;
     }

   if(count < QM5_1249_SYMBOL_COUNT)
      return false;
   out_vol = sum / (double)count;
   return (out_vol > 0.0);
  }

bool Strategy_VolFilterAllowsEntry()
  {
   if(!strategy_vol_filter_enabled)
      return true;

   if(strategy_vol_baseline_d1 < strategy_vol_window_d1 + 20)
      return false;

   double current_vol = 0.0;
   if(!Strategy_BasketVolAtShift(1, current_vol))
      return false;

   double vols[512];
   int count = 0;
   const int max_points = MathMin(strategy_vol_baseline_d1, 512);
   for(int shift = 2; shift <= max_points + 1; ++shift)
     {
      double vol = 0.0;
      if(!Strategy_BasketVolAtShift(shift, vol))
         continue;
      vols[count] = vol;
      ++count;
     }

   if(count < 50)
      return false;

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(vols[j] < vols[i])
           {
            const double tmp = vols[i];
            vols[i] = vols[j];
            vols[j] = tmp;
           }

   double pct = strategy_vol_percentile;
   if(pct < 1.0)
      pct = 1.0;
   if(pct > 99.0)
      pct = 99.0;
   const int idx = (int)MathFloor((pct / 100.0) * (double)(count - 1));
   return (current_vol <= vols[idx]);
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

bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_rebalance_months < 1)
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

   if(!Strategy_IsScheduledRebalanceClosedBar())
      return false;

   const datetime rebalance_time = iTime(_Symbol, _Period, 1);
   const int month_key = Strategy_MonthKey(rebalance_time);
   if(month_key <= 0 || month_key == g_last_entry_month_key)
      return false;
   if(strategy_rebalance_months > 1 && (month_key % strategy_rebalance_months) != 0)
      return false;

   int existing_direction = 0;
   if(Strategy_HasOpenPosition(existing_direction))
      return false;

   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0 || g_stopped_month_key[symbol_idx] == month_key)
      return false;

   if(!Strategy_VolFilterAllowsEntry())
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
   req.price = (desired_direction > 0) ? ask : bid;
   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.tp = 0.0;
   req.reason = (desired_direction > 0) ? "HSU_CARRY_TOP_RANK" : "HSU_CARRY_BOTTOM_RANK";
   if(req.sl <= 0.0)
      return false;

   g_last_entry_month_key = month_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   const int symbol_idx = Strategy_CurrentSymbolIndex();
   if(symbol_idx < 0)
      return;

   const int current_month = Strategy_MonthKey(TimeCurrent());
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

      const double sl = PositionGetDouble(POSITION_SL);
      if(sl <= 0.0)
         continue;
      const long type = PositionGetInteger(POSITION_TYPE);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      if((type == POSITION_TYPE_BUY && bid <= sl) ||
         (type == POSITION_TYPE_SELL && ask >= sl))
         g_stopped_month_key[symbol_idx] = current_month;
     }
  }

bool Strategy_ExitSignal()
  {
   if(!Strategy_IsScheduledRebalanceClosedBar())
      return false;

   const datetime rebalance_time = iTime(_Symbol, _Period, 1);
   const int month_key = Strategy_MonthKey(rebalance_time);
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
