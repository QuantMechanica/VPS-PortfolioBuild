#property strict
#property version   "5.0"
#property description "QM5_1208 Carver normalized momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1208;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours    = 336;
input string qm_news_min_impact         = "high";
input QM_NewsMode qm_news_mode_legacy   = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_period       = 16;
input int    strategy_slow_period       = 64;
input int    strategy_vol_lookback      = 25;
input double strategy_norm_return_cap   = 6.0;
input double strategy_entry_forecast    = 2.0;
input double strategy_forecast_cap      = 20.0;
input int    strategy_atr_period        = 20;
input double strategy_stop_atr_mult     = 2.5;
input bool   strategy_spread_filter     = true;
input int    strategy_spread_days       = 20;
input double strategy_spread_mult       = 2.0;

#define QM5_1208_SYMBOL_COUNT 7

string g_qm5_1208_symbols[QM5_1208_SYMBOL_COUNT] = {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "GDAXI.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX"
};

int g_qm5_1208_slots[QM5_1208_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

int Strategy_SymbolIndex()
  {
   for(int i = 0; i < QM5_1208_SYMBOL_COUNT; ++i)
      if(g_qm5_1208_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_ExpectedSlot()
  {
   const int idx = Strategy_SymbolIndex();
   if(idx < 0)
      return -1;
   return g_qm5_1208_slots[idx];
  }

bool Strategy_SelectPosition(ENUM_POSITION_TYPE &ptype)
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

      ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      return true;
     }
   return false;
  }

double Strategy_Clamp(const double value, const double lower, const double upper)
  {
   if(value < lower)
      return lower;
   if(value > upper)
      return upper;
   return value;
  }

double Strategy_ForecastScalar(const int fast, const int slow)
  {
   if(fast == 2 && slow == 8)
      return 10.6;
   if(fast == 4 && slow == 16)
      return 7.5;
   if(fast == 8 && slow == 32)
      return 5.3;
   if(fast == 16 && slow == 64)
      return 3.75;
   if(fast == 32 && slow == 128)
      return 2.65;
   if(fast == 64 && slow == 256)
      return 1.87;
   return 1.0;
  }

double Strategy_CurrentSpreadPoints()
  {
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return 0.0;
   if(ask < bid)
      return 0.0;
   return (ask - bid) / point;
  }

double Strategy_MedianSpreadPoints(const int days)
  {
   if(days <= 0)
      return 0.0;

   int spreads[];
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(_Symbol, PERIOD_D1, 1, days, spreads); // perf-allowed: bounded D1 spread sample, called only after the framework QM_IsNewBar gate.
   if(copied <= 0)
      return 0.0;

   for(int i = 0; i < copied - 1; ++i)
     {
      for(int j = i + 1; j < copied; ++j)
        {
         if(spreads[j] < spreads[i])
           {
            const int tmp = spreads[i];
            spreads[i] = spreads[j];
            spreads[j] = tmp;
           }
        }
     }

   const int mid = copied / 2;
   if((copied % 2) == 1)
      return (double)spreads[mid];
   return ((double)spreads[mid - 1] + (double)spreads[mid]) * 0.5;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(!strategy_spread_filter)
      return true;

   const double current = Strategy_CurrentSpreadPoints();
   const double median = Strategy_MedianSpreadPoints(strategy_spread_days);
   if(current <= 0.0 || median <= 0.0)
      return true;
   return (current <= median * strategy_spread_mult);
  }

bool Strategy_NormalizedForecast(const int signal_shift, double &out_forecast)
  {
   out_forecast = 0.0;

   const int fast = strategy_fast_period;
   const int slow = strategy_slow_period;
   const int vol_lookback = strategy_vol_lookback;
   if(fast < 2 || slow <= fast || vol_lookback < 2)
      return false;

   const int sample_count = slow + vol_lookback + 30;
   const int close_count = sample_count + vol_lookback + 2;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, signal_shift, close_count, closes); // perf-allowed: bounded D1 close sample for custom normalized-return series, called only after the framework QM_IsNewBar gate.
   if(copied < close_count)
      return false;

   double norm_price[];
   ArrayResize(norm_price, sample_count);

   double cumulative = 0.0;
   int out_idx = 0;
   for(int pos = sample_count - 1; pos >= 0; --pos)
     {
      double sum = 0.0;
      double sum_sq = 0.0;
      int n = 0;

      for(int j = 0; j < vol_lookback; ++j)
        {
         const int k = pos + j;
         const double c0 = closes[k];
         const double c1 = closes[k + 1];
         if(c0 <= 0.0 || c1 <= 0.0)
            return false;
         const double ret = c0 - c1;
         sum += ret;
         sum_sq += ret * ret;
         ++n;
        }

      if(n < 2)
         return false;

      const double mean = sum / n;
      const double variance = (sum_sq / n) - mean * mean;
      if(variance <= 0.0)
         return false;

      const double sigma = MathSqrt(variance);
      if(sigma <= 0.0)
         return false;

      const double raw_ret = closes[pos] - closes[pos + 1];
      const double cap = MathAbs(strategy_norm_return_cap);
      const double norm_ret = Strategy_Clamp(raw_ret / sigma, -cap, cap);
      cumulative += norm_ret;
      norm_price[out_idx] = cumulative;
      ++out_idx;
     }

   const double fast_alpha = 2.0 / ((double)fast + 1.0);
   const double slow_alpha = 2.0 / ((double)slow + 1.0);
   double fast_ema = norm_price[0];
   double slow_ema = norm_price[0];

   for(int i = 1; i < sample_count; ++i)
     {
      fast_ema = fast_alpha * norm_price[i] + (1.0 - fast_alpha) * fast_ema;
      slow_ema = slow_alpha * norm_price[i] + (1.0 - slow_alpha) * slow_ema;
     }

   double diff_sum = 0.0;
   double diff_sum_sq = 0.0;
   int diff_n = 0;
   const int first_diff = MathMax(1, sample_count - vol_lookback);
   for(int i = first_diff; i < sample_count; ++i)
     {
      const double d = norm_price[i] - norm_price[i - 1];
      diff_sum += d;
      diff_sum_sq += d * d;
      ++diff_n;
     }

   if(diff_n < 2)
      return false;

   const double diff_mean = diff_sum / diff_n;
   const double diff_var = (diff_sum_sq / diff_n) - diff_mean * diff_mean;
   if(diff_var <= 0.0)
      return false;

   const double denom = MathSqrt(diff_var);
   if(denom <= 0.0)
      return false;

   double forecast = Strategy_ForecastScalar(fast, slow) * (fast_ema - slow_ema) / denom;
   const double forecast_cap = MathAbs(strategy_forecast_cap);
   out_forecast = Strategy_Clamp(forecast, -forecast_cap, forecast_cap);
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   if(expected_slot < 0)
      return true;
   if(qm_magic_slot_offset != expected_slot)
      return true;
   if(strategy_fast_period < 2 || strategy_slow_period <= strategy_fast_period)
      return true;
   if(strategy_vol_lookback < 2 || strategy_norm_return_cap <= 0.0)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_forecast_cap <= 0.0)
      return true;
   if(strategy_atr_period < 2 || strategy_stop_atr_mult <= 0.0)
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
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   ENUM_POSITION_TYPE existing_type;
   if(Strategy_SelectPosition(existing_type))
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double forecast = 0.0;
   if(!Strategy_NormalizedForecast(1, forecast))
      return false;

   if(forecast > strategy_entry_forecast)
      req.type = QM_BUY;
   else if(forecast < -strategy_entry_forecast)
      req.type = QM_SELL;
   else
      return false;

   const double entry = (req.type == QM_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                             : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.price = 0.0;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(req.sl <= 0.0)
      return false;
   req.tp = 0.0;
   req.reason = StringFormat("NORMMOM forecast=%.4f fast=%d slow=%d", forecast, strategy_fast_period, strategy_slow_period);
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies no trailing, break-even, partial close, or pyramiding.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectPosition(ptype))
      return false;

   double forecast = 0.0;
   if(!Strategy_NormalizedForecast(1, forecast))
      return false;

   if(ptype == POSITION_TYPE_BUY && forecast < 0.0)
      return true;
   if(ptype == POSITION_TYPE_SELL && forecast > 0.0)
      return true;
   return false;
  }

// News Filter Hook
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1208\",\"ea\":\"carver-normmom\"}");
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

   if(!QM_IsNewBar(_Symbol, PERIOD_D1))
      return;

   QM_EquityStreamOnNewBar();

   Strategy_ManageOpenPosition();

   if(Strategy_ExitSignal())
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
         QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
        }
      return;
     }

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
