#property strict
#property version   "5.0"
#property description "QM5_1210 Carver slow absolute skew forecast"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1210;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

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
input int    strategy_timeframe_minutes       = 1440;
input int    strategy_skew_lookback_bars      = 365;
input int    strategy_abs_median_bars         = 252;
input double strategy_baseline_skew           = 0.0;
input double strategy_forecast_scalar         = 10.0;
input double strategy_entry_forecast          = 2.0;
input double strategy_forecast_cap            = 20.0;
input int    strategy_atr_period              = 20;
input double strategy_atr_sl_mult             = 3.0;
input int    strategy_spread_median_days      = 20;
input double strategy_spread_mult             = 2.0;
input int    strategy_max_lookback_guard      = 768;

#define QM5_1210_SYMBOL_COUNT 8

string g_symbols[QM5_1210_SYMBOL_COUNT] = {
   "GER40.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "XAUUSD.DWX",
   "XTIUSD.DWX"
};

int g_last_entry_bar_key = 0;
int g_last_exit_bar_key = 0;

ENUM_TIMEFRAMES Strategy_Timeframe()
  {
   return PERIOD_D1;
  }

int Strategy_SymbolSlot()
  {
   for(int i = 0; i < QM5_1210_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_BarKey(const datetime bar_time)
  {
   if(bar_time <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(bar_time, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
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

bool Strategy_SkewAtShift(const int base_shift, double &out_skew)
  {
   out_skew = 0.0;
   const int n = strategy_skew_lookback_bars;
   if(n < 20 || n > strategy_max_lookback_guard)
      return false;

   double returns[768];
   double sum = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double close_now = iClose(_Symbol, PERIOD_D1, base_shift + i);
      const double close_prev = iClose(_Symbol, PERIOD_D1, base_shift + i + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return false;
      const double ret = MathLog(close_now / close_prev);
      returns[i] = ret;
      sum += ret;
     }

   const double mean = sum / (double)n;
   double m2 = 0.0;
   double m3 = 0.0;
   for(int i = 0; i < n; ++i)
     {
      const double diff = returns[i] - mean;
      const double diff2 = diff * diff;
      m2 += diff2;
      m3 += diff2 * diff;
     }

   m2 /= (double)n;
   m3 /= (double)n;
   if(m2 <= 0.0)
      return false;

   out_skew = m3 / MathPow(MathSqrt(m2), 3.0);
   return MathIsValidNumber(out_skew);
  }

bool Strategy_RollingAbsMedianSignal(double &out_median)
  {
   out_median = 0.0;
   const int n = strategy_abs_median_bars;
   if(n < 20 || n > 512)
      return false;

   double values[512];
   int count = 0;
   for(int shift = 1; shift <= n; ++shift)
     {
      double skew = 0.0;
      if(!Strategy_SkewAtShift(shift, skew))
         return false;
      values[count] = MathAbs(skew - strategy_baseline_skew);
      ++count;
     }

   for(int i = 0; i < count - 1; ++i)
      for(int j = i + 1; j < count; ++j)
         if(values[j] < values[i])
           {
            const double tmp = values[i];
            values[i] = values[j];
            values[j] = tmp;
           }

   if((count % 2) == 1)
      out_median = values[count / 2];
   else
      out_median = 0.5 * (values[(count / 2) - 1] + values[count / 2]);

   return (out_median > 0.0 && MathIsValidNumber(out_median));
  }

bool Strategy_Forecast(double &out_forecast)
  {
   out_forecast = 0.0;
   double skew = 0.0;
   if(!Strategy_SkewAtShift(1, skew))
      return false;

   double abs_median = 0.0;
   if(!Strategy_RollingAbsMedianSignal(abs_median))
      return false;

   const double signal = skew - strategy_baseline_skew;
   out_forecast = strategy_forecast_scalar * signal / abs_median;
   const double cap = MathAbs(strategy_forecast_cap);
   if(cap > 0.0)
      out_forecast = MathMax(-cap, MathMin(cap, out_forecast));

   return MathIsValidNumber(out_forecast);
  }

bool Strategy_StopDistanceAllowed(const QM_OrderType side, const double entry, const double sl)
  {
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0 || entry <= 0.0 || sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
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
   if(_Period != Strategy_Timeframe())
      return true;
   if(strategy_skew_lookback_bars < 20 || strategy_skew_lookback_bars > strategy_max_lookback_guard)
      return true;
   if(strategy_abs_median_bars < 20 || strategy_abs_median_bars > 512)
      return true;
   if(strategy_atr_period < 2 || strategy_atr_sl_mult <= 0.0)
      return true;
   if(iBars(_Symbol, PERIOD_D1) < strategy_skew_lookback_bars + strategy_abs_median_bars + 5)
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

   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   const int signal_key = Strategy_BarKey(signal_bar);
   if(signal_key <= 0 || signal_key == g_last_entry_bar_key || signal_key == g_last_exit_bar_key)
      return false;
   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   double forecast = 0.0;
   if(!Strategy_Forecast(forecast))
      return false;

   QM_OrderType side = QM_BUY;
   if(forecast > strategy_entry_forecast)
      side = QM_BUY;
   else if(forecast < -strategy_entry_forecast)
      side = QM_SELL;
   else
      return false;

   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(!Strategy_StopDistanceAllowed(side, entry, sl))
      return false;

   req.type = side;
   req.price = entry;
   req.sl = sl;
   req.reason = (side == QM_BUY) ? "CARVER_SKEWABS_LONG" : "CARVER_SKEWABS_SHORT";
   g_last_entry_bar_key = signal_key;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card specifies a fixed emergency ATR stop and closed-bar forecast exits.
  }

bool Strategy_ExitSignal()
  {
   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   const int signal_key = Strategy_BarKey(signal_bar);
   if(signal_key <= 0 || signal_key == g_last_exit_bar_key)
      return false;

   double forecast = 0.0;
   if(!Strategy_Forecast(forecast))
      return false;

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
      if(pos_type == POSITION_TYPE_BUY && forecast < 0.0)
        {
         g_last_exit_bar_key = signal_key;
         return true;
        }
      if(pos_type == POSITION_TYPE_SELL && forecast > 0.0)
        {
         g_last_exit_bar_key = signal_key;
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

   for(int i = 0; i < QM5_1210_SYMBOL_COUNT; ++i)
      SymbolSelect(g_symbols[i], true);

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1210\",\"ea\":\"carver-skewabs\"}");
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
