#property strict
#property version   "5.0"
#property description "QM5_1251 Carver trend-conversion asset filter"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1251;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.083333;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours     = 336;
input string qm_news_min_impact          = "high";
input QM_NewsMode qm_news_mode_legacy    = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input int    strategy_fast_ema_days      = 64;
input int    strategy_slow_ema_days      = 256;
input int    strategy_vol_ewma_days      = 25;
input int    strategy_conversion_lookback_days = 1500;
input double strategy_min_conversion_sr  = 0.05;
input double strategy_entry_forecast     = 4.0;
input double strategy_forecast_cap       = 20.0;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 2.0;
input int    strategy_min_group_members  = 3;

#define QM5_1251_SYMBOL_COUNT 12

string g_symbols[QM5_1251_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "USDCAD.DWX", "NZDUSD.DWX", "XAUUSD.DWX", "XTIUSD.DWX",
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"
  };

int g_slots[QM5_1251_SYMBOL_COUNT] =
  {
   0, 1, 2, 3,
   4, 5, 6, 7,
   8, 9, 10, 11
  };

int g_groups[QM5_1251_SYMBOL_COUNT] =
  {
   0, 0, 0, 0,
   0, 0, 1, 2,
   3, 3, 3, 3
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar  = 0;
datetime g_last_exit_check_bar = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1251_SYMBOL_COUNT; ++i)
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

      const ENUM_POSITION_TYPE pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(pos_type == POSITION_TYPE_BUY)
         return 1;
      if(pos_type == POSITION_TYPE_SELL)
         return -1;
     }
   return 0;
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

double Strategy_EwmaVolatility(const string symbol, const int shift)
  {
   const int period = MathMax(2, strategy_vol_ewma_days);
   if(iBars(symbol, PERIOD_D1) <= shift + period + 2)
      return 0.0;

   const double alpha = 2.0 / ((double)period + 1.0);
   double variance = 0.0;
   bool seeded = false;

   for(int i = shift + period - 1; i >= shift; --i)
     {
      const double c0 = iClose(symbol, PERIOD_D1, i);
      const double c1 = iClose(symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double r = (c0 - c1) / c1;
      const double r2 = r * r;
      if(!seeded)
        {
         variance = r2;
         seeded = true;
        }
      else
         variance = alpha * r2 + (1.0 - alpha) * variance;
     }

   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

double Strategy_EMA(const string symbol, const int period, const int shift)
  {
   const int p = MathMax(2, period);
   const int seed_shift = shift + p * 6;
   if(iBars(symbol, PERIOD_D1) <= seed_shift + 1)
      return 0.0;

   double ema = 0.0;
   for(int i = seed_shift + p - 1; i >= seed_shift; --i)
     {
      const double close = iClose(symbol, PERIOD_D1, i);
      if(close <= 0.0)
         return 0.0;
      ema += close;
     }
   ema /= (double)p;

   const double alpha = 2.0 / ((double)p + 1.0);
   for(int i = seed_shift - 1; i >= shift; --i)
     {
      const double close = iClose(symbol, PERIOD_D1, i);
      if(close <= 0.0)
         return 0.0;
      ema = alpha * close + (1.0 - alpha) * ema;
     }
   return ema;
  }

double Strategy_Forecast(const string symbol, const int shift)
  {
   const double close = iClose(symbol, PERIOD_D1, shift);
   if(close <= 0.0)
      return 0.0;

   const double fast = Strategy_EMA(symbol, strategy_fast_ema_days, shift);
   const double slow = Strategy_EMA(symbol, strategy_slow_ema_days, shift);
   const double vol = Strategy_EwmaVolatility(symbol, shift);
   if(fast <= 0.0 || slow <= 0.0 || vol <= 0.0)
      return 0.0;

   double forecast = ((fast - slow) / close) / vol;
   forecast *= 10.0;
   const double cap = MathMax(1.0, strategy_forecast_cap);
   return MathMax(-cap, MathMin(cap, forecast));
  }

bool Strategy_ConversionSRForSymbol(const string symbol, double &sr)
  {
   sr = 0.0;
   const int lookback = MathMax(60, strategy_conversion_lookback_days);
   const int warmup = lookback + strategy_slow_ema_days * 7 + strategy_vol_ewma_days + 5;
   if(iBars(symbol, PERIOD_D1) < warmup)
      return false;

   double sum = 0.0;
   double sum_sq = 0.0;
   int count = 0;

   for(int shift = lookback; shift >= 1; --shift)
     {
      const double c0 = iClose(symbol, PERIOD_D1, shift);
      const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         continue;

      const double lagged_forecast = Strategy_Forecast(symbol, shift + 1) / 20.0;
      const double next_return = (c0 - c1) / c1;
      const double converted = lagged_forecast * next_return;
      sum += converted;
      sum_sq += converted * converted;
      ++count;
     }

   if(count < MathMax(60, lookback / 2))
      return false;

   const double mean = sum / (double)count;
   double variance = (sum_sq / (double)count) - (mean * mean);
   if(variance <= 0.0)
      return false;

   sr = mean / MathSqrt(variance) * MathSqrt(252.0);
   return true;
  }

int Strategy_GroupForSymbolIndex(const int symbol_index)
  {
   if(symbol_index < 0 || symbol_index >= QM5_1251_SYMBOL_COUNT)
      return -1;
   return g_groups[symbol_index];
  }

bool Strategy_AssetClassConversionScore(const int symbol_index, double &score)
  {
   score = 0.0;
   const int group = Strategy_GroupForSymbolIndex(symbol_index);
   if(group < 0)
      return false;

   double values[];
   ArrayResize(values, QM5_1251_SYMBOL_COUNT);
   int count = 0;

   for(int i = 0; i < QM5_1251_SYMBOL_COUNT; ++i)
     {
      if(g_groups[i] != group)
         continue;
      double member_sr = 0.0;
      if(!Strategy_ConversionSRForSymbol(g_symbols[i], member_sr))
         continue;
      values[count] = member_sr;
      ++count;
     }

   if(count <= 0)
      return false;

   if(count < MathMax(1, strategy_min_group_members))
      return Strategy_ConversionSRForSymbol(g_symbols[symbol_index], score);

   score = Strategy_Median(values, count);
   return true;
  }

double Strategy_MedianSpreadPoints()
  {
   const int lookback = MathMax(2, strategy_spread_median_days);
   double spreads[];
   ArrayResize(spreads, lookback);
   int count = 0;
   for(int shift = 1; shift <= lookback; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[count] = (double)spread;
      ++count;
     }
   if(count <= 0)
      return 0.0;
   return Strategy_Median(spreads, count);
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_spread_mult <= 0.0)
      return true;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(current_spread <= 0)
      return true;
   const double median_spread = Strategy_MedianSpreadPoints();
   if(median_spread <= 0.0)
      return true;
   return ((double)current_spread <= strategy_spread_mult * median_spread);
  }

bool Strategy_InvalidInputs()
  {
   if(qm_ea_id != 1251)
      return true;
   if(strategy_fast_ema_days < 2 || strategy_slow_ema_days <= strategy_fast_ema_days)
      return true;
   if(strategy_vol_ewma_days < 2)
      return true;
   if(strategy_conversion_lookback_days < 60)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_forecast_cap < strategy_entry_forecast)
      return true;
   if(strategy_atr_period_d1 < 2 || strategy_atr_sl_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CARVER_TRENDCONVERT";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_bar || signal_bar == g_last_exit_bar)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const int symbol_index = Strategy_CurrentSymbolIndex();
   if(symbol_index < 0)
      return false;

   double conversion_score = 0.0;
   if(!Strategy_AssetClassConversionScore(symbol_index, conversion_score))
      return false;
   if(conversion_score <= strategy_min_conversion_sr)
      return false;

   const double forecast = Strategy_Forecast(_Symbol, 1);
   const bool long_signal = (forecast > strategy_entry_forecast);
   const bool short_signal = (forecast < -strategy_entry_forecast);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = long_signal ? "TRENDCONVERT_LONG" : "TRENDCONVERT_SHORT";
   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_exit_bar || signal_bar == g_last_exit_check_bar)
      return false;
   g_last_exit_check_bar = signal_bar;

   const int direction = Strategy_OpenPositionDirection();
   if(direction == 0)
      return false;

   const int symbol_index = Strategy_CurrentSymbolIndex();
   if(symbol_index < 0)
      return false;

   double conversion_score = 0.0;
   if(!Strategy_AssetClassConversionScore(symbol_index, conversion_score))
      return false;

   const double forecast = Strategy_Forecast(_Symbol, 1);
   bool exit_now = (conversion_score < 0.0);
   if(direction > 0 && forecast <= 0.0)
      exit_now = true;
   if(direction < 0 && forecast >= 0.0)
      exit_now = true;

   if(exit_now)
      g_last_exit_bar = signal_bar;
   return exit_now;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

int OnInit()
  {
   if(Strategy_InvalidInputs())
      return INIT_FAILED;

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1251\",\"ea\":\"carver-trendconvert\"}");
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
   if(QM_FrameworkFridayCloseNow(broker_now))
     {
      QM_FrameworkCloseAllByMagic(QM_FrameworkMagic(), "friday_close");
      return;
     }

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
