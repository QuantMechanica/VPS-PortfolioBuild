#property strict
#property version   "5.0"
#property description "QM5_1208 Carver normalised momentum"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1208;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.142857;

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
input int    strategy_fast_period        = 16;
input int    strategy_slow_period        = 64;
input int    strategy_vol_lookback       = 25;
input double strategy_normret_cap        = 6.0;
input double strategy_forecast_scalar    = 10.0;
input double strategy_entry_forecast     = 2.0;
input double strategy_forecast_cap       = 20.0;
input int    strategy_atr_period         = 20;
input double strategy_stop_atr_mult      = 2.5;
input int    strategy_max_spread_points  = 0;
input bool   strategy_allow_ports        = true;

#define QM5_1208_SYMBOL_COUNT 7

string g_symbols[QM5_1208_SYMBOL_COUNT] = {
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDJPY.DWX",
   "GER40.DWX",
   "NDX.DWX",
   "WS30.DWX",
   "XAUUSD.DWX"
};

int g_slots[QM5_1208_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

datetime g_last_entry_bar = 0;
datetime g_last_exit_bar  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1208_SYMBOL_COUNT; ++i)
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

bool Strategy_SpreadAllowsEntry()
  {
   if(strategy_max_spread_points <= 0)
      return true;
   const long spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(spread <= 0)
      return true;
   return (spread <= strategy_max_spread_points);
  }

double Strategy_Clamp(const double value, const double lower, const double upper)
  {
   return MathMax(lower, MathMin(upper, value));
  }

double Strategy_ReturnStdDev(const int start_shift, const int lookback)
  {
   if(lookback < 2)
      return 0.0;

   double sum = 0.0;
   double sum_sq = 0.0;
   int count = 0;
   for(int i = 0; i < lookback; ++i)
     {
      const int shift = start_shift + i;
      const double c0 = iClose(_Symbol, PERIOD_D1, shift);
      const double c1 = iClose(_Symbol, PERIOD_D1, shift + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      const double ret = c0 - c1;
      sum += ret;
      sum_sq += ret * ret;
      ++count;
     }

   if(count < 2)
      return 0.0;

   const double mean = sum / count;
   const double variance = (sum_sq / count) - mean * mean;
   if(variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

bool Strategy_ForecastAtShift(const int signal_shift, double &out_forecast)
  {
   out_forecast = 0.0;

   const int fast = MathMax(2, strategy_fast_period);
   const int slow = MathMax(fast + 1, strategy_slow_period);
   const int vol_lookback = MathMax(2, strategy_vol_lookback);
   const int sample_count = slow + vol_lookback + 30;
   if(iBars(_Symbol, PERIOD_D1) < sample_count + signal_shift + vol_lookback + 2)
      return false;

   double norm_price[];
   ArrayResize(norm_price, sample_count);

   double cumulative = 0.0;
   for(int idx = 0; idx < sample_count; ++idx)
     {
      const int shift = signal_shift + sample_count - 1 - idx;
      const double c0 = iClose(_Symbol, PERIOD_D1, shift);
      const double c1 = iClose(_Symbol, PERIOD_D1, shift + 1);
      const double sigma = Strategy_ReturnStdDev(shift, vol_lookback);
      if(c0 <= 0.0 || c1 <= 0.0 || sigma <= 0.0)
         return false;

      const double norm_ret = Strategy_Clamp((c0 - c1) / sigma,
                                             -MathAbs(strategy_normret_cap),
                                             MathAbs(strategy_normret_cap));
      cumulative += norm_ret;
      norm_price[idx] = cumulative;
     }

   const double fast_alpha = 2.0 / (fast + 1.0);
   const double slow_alpha = 2.0 / (slow + 1.0);
   double fast_ema = norm_price[0];
   double slow_ema = norm_price[0];
   for(int i = 1; i < sample_count; ++i)
     {
      fast_ema = fast_alpha * norm_price[i] + (1.0 - fast_alpha) * fast_ema;
      slow_ema = slow_alpha * norm_price[i] + (1.0 - slow_alpha) * slow_ema;
     }

   double diff_sum = 0.0;
   double diff_sum_sq = 0.0;
   int diff_count = 0;
   const int first_diff = MathMax(1, sample_count - vol_lookback);
   for(int i = first_diff; i < sample_count; ++i)
     {
      const double diff = norm_price[i] - norm_price[i - 1];
      diff_sum += diff;
      diff_sum_sq += diff * diff;
      ++diff_count;
     }

   if(diff_count < 2)
      return false;

   const double diff_mean = diff_sum / diff_count;
   const double diff_var = (diff_sum_sq / diff_count) - diff_mean * diff_mean;
   if(diff_var <= 0.0)
      return false;

   const double denom = MathSqrt(diff_var);
   if(denom <= 0.0)
      return false;

   const double raw = fast_ema - slow_ema;
   out_forecast = Strategy_Clamp(strategy_forecast_scalar * raw / denom,
                                 -MathAbs(strategy_forecast_cap),
                                 MathAbs(strategy_forecast_cap));
   return true;
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(!strategy_allow_ports && Strategy_SlotForCurrentSymbol() > 2)
      return true;
   if(Strategy_SlotForCurrentSymbol() != qm_magic_slot_offset)
      return true;
   if(strategy_fast_period < 2 || strategy_slow_period <= strategy_fast_period)
      return true;
   if(strategy_vol_lookback < 2 || strategy_atr_period < 2)
      return true;
   if(strategy_entry_forecast <= 0.0 || strategy_stop_atr_mult <= 0.0)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "CARVER_NORMMOM";
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
   if(!Strategy_ForecastAtShift(1, forecast))
      return false;

   const bool long_signal = (forecast > strategy_entry_forecast);
   const bool short_signal = (forecast < -strategy_entry_forecast);
   if(!long_signal && !short_signal)
      return false;

   const QM_OrderType side = long_signal ? QM_BUY : QM_SELL;
   const double entry = QM_EntryMarketPrice(side);
   if(entry <= 0.0)
      return false;

   const double sl = QM_StopATR(_Symbol, side, entry, strategy_atr_period, strategy_stop_atr_mult);
   if(sl <= 0.0)
      return false;
   if(side == QM_BUY && sl >= entry)
      return false;
   if(side == QM_SELL && sl <= entry)
      return false;

   req.type = side;
   req.price = entry;
   req.sl = NormalizeDouble(sl, _Digits);
   req.reason = long_signal ? "NORMMOM_LONG" : "NORMMOM_SHORT";
   g_last_entry_bar = signal_bar;
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Card uses forecast-zero exits and an emergency ATR stop; no trailing rule.
  }

bool Strategy_ExitSignal()
  {
   const datetime signal_bar = iTime(_Symbol, PERIOD_D1, 1);
   if(signal_bar <= 0 || signal_bar == g_last_exit_bar)
      return false;

   double forecast = 0.0;
   if(!Strategy_ForecastAtShift(1, forecast))
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
         g_last_exit_bar = signal_bar;
         return true;
        }
      if(pos_type == POSITION_TYPE_SELL && forecast > 0.0)
        {
         g_last_exit_bar = signal_bar;
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
