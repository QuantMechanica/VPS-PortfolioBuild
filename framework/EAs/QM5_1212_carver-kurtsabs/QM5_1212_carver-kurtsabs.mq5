#property strict
#property version   "5.0"
#property description "QM5_1212 Carver absolute kurtosis-conditioned skew"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1212;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    strategy_lookback_bars          = 180;
input int    strategy_median_lookback_bars   = 252;
input double strategy_baseline_skew          = 0.0;
input double strategy_baseline_kurtosis      = 0.0;
input double strategy_forecast_scalar        = 1.0;
input double strategy_entry_forecast         = 2.0;
input double strategy_forecast_cap           = 20.0;
input int    strategy_exit_confirm_bars      = 3;
input int    strategy_atr_period             = 20;
input double strategy_atr_stop_mult          = 3.0;
input int    strategy_spread_median_days     = 20;
input double strategy_spread_mult            = 2.0;
input bool   strategy_allow_ports            = true;

#define QM5_1212_SYMBOL_COUNT 8

string g_symbols[QM5_1212_SYMBOL_COUNT] = {
   "GER40.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
};

datetime g_last_signal_bar = 0;

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   return PERIOD_D1;
  }

int Strategy_SymbolSlot()
  {
   for(int i = 0; i < QM5_1212_SYMBOL_COUNT; ++i)
      if(_Symbol == g_symbols[i])
         return i;
   return -1;
  }

bool Strategy_TimeframeSupported()
  {
   return (_Period == Strategy_Timeframe());
  }

int Strategy_MinBars()
  {
   return strategy_lookback_bars + strategy_median_lookback_bars + 3;
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

double Strategy_MedianArray(double &values[], const int count)
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

double Strategy_MedianDailySpreadPoints()
  {
   const int n = strategy_spread_median_days;
   if(n <= 0 || n > 64)
      return 0.0;

   double values[64];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      const long spread = iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      values[count] = (double)spread;
      ++count;
     }

   return Strategy_MedianArray(values, count);
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

bool Strategy_RawSignalAtShift(const int shift, double &out_raw, double &out_kurt_gate)
  {
   out_raw = 0.0;
   out_kurt_gate = 0.0;

   const int n = strategy_lookback_bars;
   if(n < 20 || n > 512)
      return false;
   if(iBars(_Symbol, PERIOD_D1) < shift + n + 2)
      return false;

   double returns[512];
   double sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double close_now = iClose(_Symbol, PERIOD_D1, shift + i);
      const double close_prev = iClose(_Symbol, PERIOD_D1, shift + i + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;
      const double r = MathLog(close_now / close_prev);
      returns[i] = r;
      sum += r;
     }

   const double mean = sum / (double)n;
   double variance = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double diff = returns[i] - mean;
      variance += diff * diff;
     }

   if(variance <= 0.0)
      return false;

   const double stdev = MathSqrt(variance / (double)n);
   if(stdev <= 0.0)
      return false;

   double m3 = 0.0;
   double m4 = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double z = (returns[i] - mean) / stdev;
      const double z2 = z * z;
      m3 += z2 * z;
      m4 += z2 * z2;
     }

   const double skew = m3 / (double)n;
   const double excess_kurtosis = (m4 / (double)n) - 3.0;
   const double skew_signal = skew - strategy_baseline_skew;
   out_kurt_gate = excess_kurtosis - strategy_baseline_kurtosis;
   out_raw = skew_signal * MathMax(out_kurt_gate, 0.0);
   return MathIsValidNumber(out_raw) && MathIsValidNumber(out_kurt_gate);
  }

bool Strategy_RollingAbsMedianRaw(const int shift, double &out_median)
  {
   out_median = 0.0;
   const int n = strategy_median_lookback_bars;
   if(n < 20 || n > 512)
      return false;

   double values[512];
   int count = 0;
   for(int i = 0; i < n; ++i)
     {
      double raw = 0.0;
      double gate = 0.0;
      if(!Strategy_RawSignalAtShift(shift + i, raw, gate))
         return false;
      values[count] = MathAbs(raw);
      ++count;
     }

   out_median = Strategy_MedianArray(values, count);
   return (out_median > 0.0 && MathIsValidNumber(out_median));
  }

bool Strategy_ForecastAtShift(const int shift, double &out_forecast, double &out_kurt_gate)
  {
   out_forecast = 0.0;
   out_kurt_gate = 0.0;

   double raw = 0.0;
   if(!Strategy_RawSignalAtShift(shift, raw, out_kurt_gate))
      return false;

   double median_abs_raw = 0.0;
   if(!Strategy_RollingAbsMedianRaw(shift, median_abs_raw))
      return false;

   double forecast = strategy_forecast_scalar * raw / median_abs_raw;
   const double cap = MathAbs(strategy_forecast_cap);
   if(cap > 0.0)
      forecast = MathMax(-cap, MathMin(cap, forecast));

   out_forecast = forecast;
   return MathIsValidNumber(out_forecast);
  }

bool Strategy_StopDistanceAllowed(const QM_OrderType type, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(type == QM_BUY && sl >= entry)
      return false;
   if(type == QM_SELL && sl <= entry)
      return false;

   const int stops_level = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double stop_points = MathAbs(entry - sl) / point;
   return (stops_level <= 0 || stop_points > (double)stops_level);
  }

bool Strategy_NoTradeFilter()
  {
   const int slot = Strategy_SymbolSlot();
   if(slot < 0 || slot != qm_magic_slot_offset)
      return true;
   if(!Strategy_TimeframeSupported())
      return true;
   if(strategy_lookback_bars < 20 || strategy_lookback_bars > 512)
      return true;
   if(strategy_median_lookback_bars < 20 || strategy_median_lookback_bars > 512)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_atr_period < 2 || strategy_atr_stop_mult <= 0.0)
      return true;
   if(strategy_exit_confirm_bars < 1 || strategy_exit_confirm_bars > 20)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(Strategy_HasOpenPosition())
      return false;
   if(iBars(_Symbol, PERIOD_D1) < Strategy_MinBars())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_signal_bar)
      return false;

   double forecast = 0.0;
   double kurt_gate = 0.0;
   if(!Strategy_ForecastAtShift(1, forecast, kurt_gate))
      return false;
   if(kurt_gate <= 0.0)
      return false;

   const bool long_signal = (forecast > strategy_entry_forecast);
   const bool short_signal = (forecast < -strategy_entry_forecast);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period, 1);
   if(entry <= 0.0 || atr <= 0.0)
      return false;

   const double sl = NormalizeDouble(side == QM_BUY
                                     ? entry - atr * strategy_atr_stop_mult
                                     : entry + atr * strategy_atr_stop_mult,
                                     _Digits);
   if(!Strategy_StopDistanceAllowed(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.reason = long_signal ? "CARVER_KURTSABS_LONG" : "CARVER_KURTSABS_SHORT";
   g_last_signal_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   const int magic = QM_FrameworkMagic();
   bool has_position = false;
   ENUM_POSITION_TYPE pos_type = POSITION_TYPE_BUY;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      pos_type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      has_position = true;
      break;
     }

   if(!has_position)
      return false;
   if(iBars(_Symbol, PERIOD_D1) < Strategy_MinBars())
      return false;

   double forecast = 0.0;
   double kurt_gate = 0.0;
   if(!Strategy_ForecastAtShift(1, forecast, kurt_gate))
      return false;

   if(pos_type == POSITION_TYPE_BUY && forecast < 0.0)
      return true;
   if(pos_type == POSITION_TYPE_SELL && forecast > 0.0)
      return true;

   for(int shift = 1; shift <= strategy_exit_confirm_bars; ++shift)
     {
      double raw = 0.0;
      double gate = 0.0;
      if(!Strategy_RawSignalAtShift(shift, raw, gate))
         return false;
      if(gate > 0.0)
         return false;
     }

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1212\",\"ea\":\"carver-kurtsabs\"}");
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
