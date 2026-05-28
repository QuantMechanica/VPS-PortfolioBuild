#property strict
#property version   "5.0"
#property description "QM5_1252 Carver handcrafted forecast ensemble"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1252;
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
input double strategy_entry_forecast      = 5.0;
input double strategy_exit_forecast       = 1.0;
input int    strategy_min_families        = 3;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 3.0;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_mult         = 2.0;
input double strategy_cost_limit          = 0.13;
input double strategy_ewmac_weight        = 0.28;
input double strategy_breakout_weight     = 0.22;
input double strategy_normmom_weight      = 0.16;
input double strategy_skew_weight         = 0.10;
input double strategy_mr_weight           = 0.14;
input double strategy_accel_weight        = 0.10;

#define QM5_1252_SYMBOL_COUNT 12

string g_symbols[QM5_1252_SYMBOL_COUNT] =
  {
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "AUDUSD.DWX",
   "USDCAD.DWX", "NZDUSD.DWX", "XAUUSD.DWX", "XTIUSD.DWX",
   "NDX.DWX", "WS30.DWX", "GDAXI.DWX", "UK100.DWX"
  };

int g_slots[QM5_1252_SYMBOL_COUNT] =
  {
   0, 1, 2, 3,
   4, 5, 6, 7,
   8, 9, 10, 11
  };

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar  = 0;
datetime g_last_exit_check_bar = 0;

double Strategy_ClampForecast(const double value)
  {
   return MathMax(-20.0, MathMin(20.0, value));
  }

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1252_SYMBOL_COUNT; ++i)
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

double Strategy_Median(double &values[], const int count)
  {
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

double Strategy_ATRPoints(const int shift)
  {
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, shift);
   if(atr <= 0.0 || _Point <= 0.0)
      return 0.0;
   return atr / _Point;
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

bool Strategy_CostAllowed(const double turnover)
  {
   if(strategy_cost_limit <= 0.0)
      return true;
   const double median_spread = Strategy_MedianSpreadPoints();
   const double atr_points = Strategy_ATRPoints(1);
   if(median_spread <= 0.0 || atr_points <= 0.0)
      return true;
   return (turnover * median_spread / atr_points <= strategy_cost_limit);
  }

double Strategy_Return(const int shift, const int bars)
  {
   const double c0 = iClose(_Symbol, PERIOD_D1, shift);
   const double c1 = iClose(_Symbol, PERIOD_D1, shift + bars);
   if(c0 <= 0.0 || c1 <= 0.0)
      return 0.0;
   return (c0 - c1) / c1;
  }

double Strategy_StdDevReturns(const int shift, const int period)
  {
   if(period <= 1 || period > 512)
      return 0.0;
   double values[];
   ArrayResize(values, period);
   double mean = 0.0;
   for(int i = 0; i < period; ++i)
     {
      values[i] = Strategy_Return(shift + i, 1);
      mean += values[i];
     }
   mean /= (double)period;
   double var = 0.0;
   for(int i = 0; i < period; ++i)
      var += (values[i] - mean) * (values[i] - mean);
   var /= (double)MathMax(period - 1, 1);
   return MathSqrt(var);
  }

double Strategy_EMA(const int period, const int shift)
  {
   if(period <= 1 || iBars(_Symbol, PERIOD_D1) < shift + period * 3)
      return 0.0;

   const int warmup = period * 3;
   const double alpha = 2.0 / ((double)period + 1.0);
   double ema = iClose(_Symbol, PERIOD_D1, shift + warmup);
   if(ema <= 0.0)
      return 0.0;

   for(int i = shift + warmup - 1; i >= shift; --i)
     {
      const double close = iClose(_Symbol, PERIOD_D1, i);
      if(close <= 0.0)
         return 0.0;
      ema = alpha * close + (1.0 - alpha) * ema;
     }
   return ema;
  }

double Strategy_EwmacOne(const int fast, const int slow)
  {
   if(!Strategy_CostAllowed(252.0 / (double)MathMax(fast, 1)))
      return 0.0;
   const int bars = iBars(_Symbol, PERIOD_D1);
   if(bars < slow + 80)
      return 0.0;
   const double fast_ma = Strategy_EMA(fast, 1);
   const double slow_ma = Strategy_EMA(slow, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(fast_ma <= 0.0 || slow_ma <= 0.0 || atr <= 0.0)
      return 0.0;
   return Strategy_ClampForecast(10.0 * (fast_ma - slow_ma) / atr);
  }

double Strategy_EwmacForecast(bool &valid)
  {
   int fasts[5] = {4, 8, 16, 32, 64};
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < 5; ++i)
     {
      const double value = Strategy_EwmacOne(fasts[i], fasts[i] * 4);
      if(value == 0.0)
         continue;
      sum += value;
      ++count;
     }
   valid = (count >= 2);
   return valid ? Strategy_ClampForecast(sum / (double)count) : 0.0;
  }

double Strategy_BreakoutOne(const int lookback)
  {
   if(!Strategy_CostAllowed(126.0 / (double)MathMax(lookback, 1)))
      return 0.0;
   if(iBars(_Symbol, PERIOD_D1) < lookback + 5)
      return 0.0;
   double high = -DBL_MAX;
   double low = DBL_MAX;
   for(int i = 1; i <= lookback; ++i)
     {
      high = MathMax(high, iHigh(_Symbol, PERIOD_D1, i));
      low = MathMin(low, iLow(_Symbol, PERIOD_D1, i));
     }
   const double close = iClose(_Symbol, PERIOD_D1, 1);
   if(high <= low || close <= 0.0)
      return 0.0;
   const double pos = ((close - low) / (high - low) - 0.5) * 40.0;
   return Strategy_ClampForecast(pos);
  }

double Strategy_BreakoutForecast(bool &valid)
  {
   int periods[6] = {10, 20, 40, 80, 160, 320};
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < 6; ++i)
     {
      const double value = Strategy_BreakoutOne(periods[i]);
      if(value == 0.0)
         continue;
      sum += value;
      ++count;
     }
   valid = (count >= 2);
   return valid ? Strategy_ClampForecast(sum / (double)count) : 0.0;
  }

double Strategy_NormMomentumOne(const int months)
  {
   const int bars = MathMax(2, months * 21);
   if(!Strategy_CostAllowed(12.0 / (double)MathMax(months, 1)))
      return 0.0;
   if(iBars(_Symbol, PERIOD_D1) < bars + 40)
      return 0.0;
   const double sd = Strategy_StdDevReturns(1, 25);
   if(sd <= 0.0)
      return 0.0;
   const double z = Strategy_Return(1, bars) / (sd * MathSqrt((double)bars));
   return Strategy_ClampForecast(z * 10.0);
  }

double Strategy_NormMomentumForecast(bool &valid)
  {
   int months[6] = {2, 4, 8, 16, 32, 64};
   double sum = 0.0;
   int count = 0;
   for(int i = 0; i < 6; ++i)
     {
      const double value = Strategy_NormMomentumOne(months[i]);
      if(value == 0.0)
         continue;
      sum += value;
      ++count;
     }
   valid = (count >= 2);
   return valid ? Strategy_ClampForecast(sum / (double)count) : 0.0;
  }

double Strategy_SkewForecast(bool &valid)
  {
   const int lookback = 180;
   if(iBars(_Symbol, PERIOD_D1) < lookback + 10)
     {
      valid = false;
      return 0.0;
     }
   double values[];
   ArrayResize(values, lookback);
   double mean = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      values[i] = Strategy_Return(1 + i, 1);
      mean += values[i];
     }
   mean /= (double)lookback;
   double v2 = 0.0;
   double v3 = 0.0;
   for(int i = 0; i < lookback; ++i)
     {
      const double d = values[i] - mean;
      v2 += d * d;
      v3 += d * d * d;
     }
   v2 /= (double)lookback;
   v3 /= (double)lookback;
   if(v2 <= 0.0)
     {
      valid = false;
      return 0.0;
     }
   const double skew = v3 / MathPow(v2, 1.5);
   valid = true;
   return Strategy_ClampForecast(-8.0 * skew);
  }

double Strategy_MeanReversionForecast(bool &valid)
  {
   const int lookback = 160;
   if(iBars(_Symbol, PERIOD_D1) < lookback + 30)
     {
      valid = false;
      return 0.0;
     }
   const double sd = Strategy_StdDevReturns(1, 25);
   if(sd <= 0.0)
     {
      valid = false;
      return 0.0;
     }
   const double z = Strategy_Return(1, lookback) / (sd * MathSqrt((double)lookback));
   valid = true;
   return Strategy_ClampForecast(-10.0 * z);
  }

double Strategy_AccelForecast(bool &valid)
  {
   const double fast = Strategy_NormMomentumOne(2);
   const double slow = Strategy_NormMomentumOne(8);
   if(fast == 0.0 || slow == 0.0)
     {
      valid = false;
      return 0.0;
     }
   valid = true;
   return Strategy_ClampForecast(fast - slow);
  }

bool Strategy_CombinedForecast(double &forecast, int &families)
  {
   forecast = 0.0;
   families = 0;

   double weighted = 0.0;
   double weights = 0.0;
   bool valid = false;

   const double ewmac = Strategy_EwmacForecast(valid);
   if(valid && strategy_ewmac_weight > 0.0)
     {
      weighted += strategy_ewmac_weight * ewmac;
      weights += strategy_ewmac_weight;
      ++families;
     }

   const double breakout = Strategy_BreakoutForecast(valid);
   if(valid && strategy_breakout_weight > 0.0)
     {
      weighted += strategy_breakout_weight * breakout;
      weights += strategy_breakout_weight;
      ++families;
     }

   const double normmom = Strategy_NormMomentumForecast(valid);
   if(valid && strategy_normmom_weight > 0.0)
     {
      weighted += strategy_normmom_weight * normmom;
      weights += strategy_normmom_weight;
      ++families;
     }

   const double skew = Strategy_SkewForecast(valid);
   if(valid && strategy_skew_weight > 0.0)
     {
      weighted += strategy_skew_weight * skew;
      weights += strategy_skew_weight;
      ++families;
     }

   const double mr = Strategy_MeanReversionForecast(valid);
   if(valid && strategy_mr_weight > 0.0)
     {
      weighted += strategy_mr_weight * mr;
      weights += strategy_mr_weight;
      ++families;
     }

   const double accel = Strategy_AccelForecast(valid);
   if(valid && strategy_accel_weight > 0.0)
     {
      weighted += strategy_accel_weight * accel;
      weights += strategy_accel_weight;
      ++families;
     }

   if(families < strategy_min_families || weights <= 0.0)
      return false;

   forecast = Strategy_ClampForecast(weighted / weights);
   return true;
  }

bool Strategy_InvalidInputs()
  {
   if(qm_ea_id != 1252)
      return true;
   if(strategy_min_families < 1)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_exit_forecast < 0.0 || strategy_exit_forecast >= strategy_entry_forecast)
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
   req.reason = "CARVER_HANDCRAFT_ENS";
   req.symbol_slot = Strategy_SlotForCurrentSymbol();
   req.expiration_seconds = 0;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_entry_bar || signal_bar == g_last_exit_bar)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double forecast = 0.0;
   int families = 0;
   if(!Strategy_CombinedForecast(forecast, families))
      return false;

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
   req.reason = long_signal ? "HANDCRAFT_ENS_LONG" : "HANDCRAFT_ENS_SHORT";
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

   double forecast = 0.0;
   int families = 0;
   if(!Strategy_CombinedForecast(forecast, families))
      return false;

   bool exit_now = false;
   if(direction > 0 && forecast <= strategy_exit_forecast)
      exit_now = true;
   if(direction < 0 && forecast >= -strategy_exit_forecast)
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1252\",\"ea\":\"carver-handcraft-ens\"}");
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
