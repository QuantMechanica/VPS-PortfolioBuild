#property strict
#property version   "5.0"
#property description "QM5_11051 pysystemtrade volatility-attenuated breakout"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 11051;
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
input double strategy_entry_forecast       = 5.0;
input double strategy_exit_forecast        = 1.0;
input bool   strategy_use_attenuation      = true;
input bool   strategy_use_all_lookbacks    = true;
input int    strategy_daily_vol_period     = 25;
input int    strategy_vol_sma_period       = 2500;
input int    strategy_vol_atten_ema_period = 10;
input int    strategy_spread_median_days   = 60;
input double strategy_spread_mult          = 2.0;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 3.0;

#define QM5_11051_SYMBOL_COUNT 7
#define QM5_11051_LOOKBACK_COUNT 6

string g_symbols[QM5_11051_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "NDX.DWX",
   "WS30.DWX", "XAUUSD.DWX", "XTIUSD.DWX"
  };

int g_slots[QM5_11051_SYMBOL_COUNT] =
  {
   0, 1, 2, 3, 4, 5, 6
  };

int g_lookbacks[QM5_11051_LOOKBACK_COUNT] =
  {
   10, 20, 40, 80, 160, 320
  };

double g_scalars[QM5_11051_LOOKBACK_COUNT] =
  {
   0.6031, 0.6743, 0.7037, 0.7263, 0.7388, 0.7366
  };

datetime g_forecast_bar_time = 0;
datetime g_entry_bar_time = 0;
datetime g_exit_bar_time = 0;
double   g_cached_forecast = 0.0;
bool     g_cached_forecast_valid = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_11051_SYMBOL_COUNT; ++i)
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

int Strategy_OpenPositionDirection()
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
      return (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
     }
   return 0;
  }

double Strategy_ClampForecast(const double value)
  {
   return MathMax(-20.0, MathMin(20.0, value));
  }

double Strategy_Median(double &values[], const int count)
  {
   if(count <= 0)
      return 0.0;
   ArrayResize(values, count);
   ArraySort(values);
   if((count % 2) == 1)
      return values[count / 2];
   return 0.5 * (values[(count / 2) - 1] + values[count / 2]);
  }

bool Strategy_LoadClosedCloses(const int requested_count, const int min_count, double &closes[])
  {
   if(requested_count <= 0 || min_count <= 0)
      return false;
   ArrayResize(closes, requested_count);
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, PERIOD_D1, 1, requested_count, closes); // perf-allowed: gated/cached D1 rolling breakout math
   if(copied < min_count)
      return false;
   ArrayResize(closes, copied);
   return true;
  }

double Strategy_RawBreakout(double &closes[], const int start_shift, const int lookback, bool &valid)
  {
   valid = false;
   if(lookback < 2 || ArraySize(closes) < start_shift + lookback)
      return 0.0;

   double roll_max = -DBL_MAX;
   double roll_min = DBL_MAX;
   int populated = 0;
   for(int i = start_shift; i < start_shift + lookback; ++i)
     {
      const double close_i = closes[i];
      if(close_i <= 0.0)
         continue;
      roll_max = MathMax(roll_max, close_i);
      roll_min = MathMin(roll_min, close_i);
      ++populated;
     }

   if(populated < (lookback + 1) / 2 || roll_max <= roll_min)
      return 0.0;

   const double close_now = closes[start_shift];
   const double roll_mean = 0.5 * (roll_max + roll_min);
   valid = true;
   return 40.0 * ((close_now - roll_mean) / (roll_max - roll_min));
  }

bool Strategy_SmoothedBreakout(double &closes[], const int lookback, const double scalar, double &forecast)
  {
   forecast = 0.0;
   const int smooth = MathMax(lookback / 4, 1);
   const int warmup = MathMax(smooth * 3, 1);
   if(ArraySize(closes) < lookback + warmup)
      return false;

   bool valid = false;
   double ema = Strategy_RawBreakout(closes, warmup - 1, lookback, valid);
   if(!valid)
      return false;

   const double alpha = 2.0 / ((double)smooth + 1.0);
   for(int shift = warmup - 2; shift >= 0; --shift)
     {
      const double raw = Strategy_RawBreakout(closes, shift, lookback, valid);
      if(!valid)
         return false;
      ema = alpha * raw + (1.0 - alpha) * ema;
     }

   forecast = Strategy_ClampForecast(ema * scalar);
   return true;
  }

double Strategy_VolAttenuation(double &closes[])
  {
   if(!strategy_use_attenuation)
      return 1.0;

   const int vol_period = MathMax(2, strategy_daily_vol_period);
   const int sma_period = MathMax(20, strategy_vol_sma_period);
   const int ema_period = MathMax(1, strategy_vol_atten_ema_period);
   const int normal_count = ema_period + sma_period;
   const int vol_count = normal_count + sma_period;
   const int returns_count = vol_count + vol_period;
   if(ArraySize(closes) < returns_count + 1)
      return 1.0;

   double prefix_sum[];
   double prefix_sq[];
   ArrayResize(prefix_sum, returns_count + 1);
   ArrayResize(prefix_sq, returns_count + 1);
   prefix_sum[0] = 0.0;
   prefix_sq[0] = 0.0;
   for(int i = 0; i < returns_count; ++i)
     {
      const double c0 = closes[i];
      const double c1 = closes[i + 1];
      if(c0 <= 0.0 || c1 <= 0.0)
         return 1.0;
      const double r = (c0 - c1) / c1;
      prefix_sum[i + 1] = prefix_sum[i] + r;
      prefix_sq[i + 1] = prefix_sq[i] + r * r;
     }

   double daily_vol[];
   ArrayResize(daily_vol, vol_count);
   for(int shift = 0; shift < vol_count; ++shift)
     {
      const double sum = prefix_sum[shift + vol_period] - prefix_sum[shift];
      const double sq = prefix_sq[shift + vol_period] - prefix_sq[shift];
      const double mean = sum / (double)vol_period;
      double var = (sq / (double)vol_period) - mean * mean;
      if(var < 0.0)
         var = 0.0;
      daily_vol[shift] = MathSqrt(var);
     }

   double vol_prefix[];
   ArrayResize(vol_prefix, vol_count + 1);
   vol_prefix[0] = 0.0;
   for(int i = 0; i < vol_count; ++i)
      vol_prefix[i + 1] = vol_prefix[i] + daily_vol[i];

   double normalised[];
   ArrayResize(normalised, normal_count);
   for(int shift = 0; shift < normal_count; ++shift)
     {
      const double avg_vol = (vol_prefix[shift + sma_period] - vol_prefix[shift]) / (double)sma_period;
      if(avg_vol <= 0.0 || daily_vol[shift] <= 0.0)
         return 1.0;
      normalised[shift] = daily_vol[shift] / avg_vol;
     }

   const double alpha = 2.0 / ((double)ema_period + 1.0);
   double ema = 1.0;
   bool seeded = false;

   for(int shift = ema_period - 1; shift >= 0; --shift)
     {
      const double current = normalised[shift];
      int less_equal = 0;
      for(int i = shift + 1; i <= shift + sma_period; ++i)
         if(normalised[i] <= current)
            ++less_equal;
      const double quantile = (double)less_equal / (double)sma_period;
      const double raw = 2.0 - 1.5 * quantile;
      if(!seeded)
        {
         ema = raw;
         seeded = true;
        }
      else
         ema = alpha * raw + (1.0 - alpha) * ema;
     }

   if(!seeded)
      return 1.0;
   return MathMax(0.0, ema);
  }

bool Strategy_RefreshForecast()
  {
   datetime signal_times[1];
   ArraySetAsSeries(signal_times, true);
   if(CopyTime(_Symbol, PERIOD_D1, 1, 1, signal_times) != 1) // perf-allowed: cached D1 signal-bar identity
      return false;

   const datetime signal_bar = signal_times[0];
   if(signal_bar == g_forecast_bar_time)
      return g_cached_forecast_valid;

   g_forecast_bar_time = signal_bar;
   g_cached_forecast = 0.0;
   g_cached_forecast_valid = false;

   const int vol_need = strategy_use_attenuation
                        ? (strategy_vol_sma_period * 2 + strategy_daily_vol_period + strategy_vol_atten_ema_period + 4)
                        : 0;
   const int breakout_need = 320 + MathMax(320 / 4, 1) * 3 + 4;
   const int copy_count = MathMax(breakout_need, vol_need);

   double closes[];
   if(!Strategy_LoadClosedCloses(copy_count, breakout_need, closes))
      return false;

   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < QM5_11051_LOOKBACK_COUNT; ++i)
     {
      const int lookback = g_lookbacks[i];
      if(!strategy_use_all_lookbacks && (lookback == 10 || lookback == 320))
         continue;

      double component = 0.0;
      if(!Strategy_SmoothedBreakout(closes, lookback, g_scalars[i], component))
         continue;
      component = Strategy_ClampForecast(component * Strategy_VolAttenuation(closes));
      sum += component;
      ++count;
     }

   if(count <= 0)
      return false;

   g_cached_forecast = sum / (double)count;
   g_cached_forecast_valid = true;
   return true;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_mult <= 0.0)
      return true;

   const int lookback = MathMax(2, MathMin(strategy_spread_median_days, 256));
   long spreads[];
   ArrayResize(spreads, lookback);
   ArraySetAsSeries(spreads, true);
   const int copied = CopySpread(_Symbol, PERIOD_D1, 1, lookback, spreads); // perf-allowed: entry-only median spread filter from card
   if(copied <= 0)
      return true;

   double values[];
   ArrayResize(values, copied);
   int count = 0;
   for(int i = 0; i < copied; ++i)
     {
      if(spreads[i] <= 0)
         continue;
      values[count] = (double)spreads[i];
      ++count;
     }

   const double median_spread = Strategy_Median(values, count);
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread <= 0)
      return true;
   return ((double)current_spread <= strategy_spread_mult * median_spread);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 11051)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(Strategy_SlotForCurrentSymbol() != qm_magic_slot_offset)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_exit_forecast < 0.0 || strategy_exit_forecast >= strategy_entry_forecast)
      return true;
   if(strategy_atr_period < 2 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(strategy_daily_vol_period < 2 || strategy_vol_sma_period < 20 || strategy_vol_atten_ema_period < 1)
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
   req.reason = "PST_VOLATTEN_BREAK";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   if(!Strategy_RefreshForecast())
      return false;
   if(g_forecast_bar_time == g_entry_bar_time || g_forecast_bar_time == g_exit_bar_time)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const bool long_signal = (g_cached_forecast >= strategy_entry_forecast);
   const bool short_signal = (g_cached_forecast <= -strategy_entry_forecast);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = long_signal ? "PST_VOLATTEN_LONG" : "PST_VOLATTEN_SHORT";
   g_entry_bar_time = g_forecast_bar_time;
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
   const int direction = Strategy_OpenPositionDirection();
   if(direction == 0)
      return false;
   if(!Strategy_RefreshForecast())
      return false;
   if(g_forecast_bar_time == g_exit_bar_time)
      return false;

   bool exit_now = false;
   if(direction > 0 && g_cached_forecast <= strategy_exit_forecast)
      exit_now = true;
   if(direction < 0 && g_cached_forecast >= -strategy_exit_forecast)
      exit_now = true;

   if(exit_now)
      g_exit_bar_time = g_forecast_bar_time;
   return exit_now;
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_11051\",\"ea\":\"pst-volatten-break\"}");
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
