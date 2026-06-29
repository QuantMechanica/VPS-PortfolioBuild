#property strict
#property version   "5.0"
#property description "QM5_12796 Carver vol-targeted trend D1"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 12796;
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
input ENUM_TIMEFRAMES strategy_tf              = PERIOD_D1;
input bool   strategy_use_multispeed           = true;
input int    strategy_fast_period_1            = 8;
input int    strategy_slow_period_1            = 32;
input int    strategy_fast_period_2            = 16;
input int    strategy_slow_period_2            = 64;
input int    strategy_fast_period_3            = 32;
input int    strategy_slow_period_3            = 128;
input int    strategy_vol_lookback             = 25;
input double strategy_forecast_multiplier      = 1.0;
input double strategy_forecast_cap             = 20.0;
input double strategy_entry_forecast           = 0.0;
input int    strategy_atr_period               = 20;
input double strategy_stop_atr_mult            = 3.0;
input bool   strategy_spread_filter            = true;
input double strategy_max_spread_atr_mult      = 0.05;

#define QM5_12796_SYMBOL_COUNT 7

string g_qm5_12796_symbols[QM5_12796_SYMBOL_COUNT] = {
   "NDX.DWX",
   "SP500.DWX",
   "GDAXI.DWX",
   "XAUUSD.DWX",
   "XAGUSD.DWX",
   "XTIUSD.DWX",
   "XNGUSD.DWX"
};

int g_qm5_12796_slots[QM5_12796_SYMBOL_COUNT] = {0, 1, 2, 3, 4, 5, 6};

int Strategy_SymbolIndex()
  {
   for(int i = 0; i < QM5_12796_SYMBOL_COUNT; ++i)
      if(g_qm5_12796_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_ExpectedSlot()
  {
   const int idx = Strategy_SymbolIndex();
   if(idx < 0)
      return -1;
   return g_qm5_12796_slots[idx];
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
   if(fast == 8 && slow == 32)
      return 5.3;
   if(fast == 16 && slow == 64)
      return 3.75;
   if(fast == 32 && slow == 128)
      return 2.65;
   return 1.0;
  }

bool Strategy_EwmacForecastFromCloses(const double &closes[],
                                      const int copied,
                                      const int fast_period,
                                      const int slow_period,
                                      const double sigma,
                                      double &out_forecast)
  {
   out_forecast = 0.0;
   if(fast_period < 2 || slow_period <= fast_period || sigma <= 0.0)
      return false;
   if(copied <= slow_period + strategy_vol_lookback + 2)
      return false;

   const double alpha_fast = 2.0 / ((double)fast_period + 1.0);
   const double alpha_slow = 2.0 / ((double)slow_period + 1.0);
   double fast_ema = closes[copied - 1];
   double slow_ema = closes[copied - 1];

   for(int i = copied - 2; i >= 0; --i)
     {
      fast_ema = alpha_fast * closes[i] + (1.0 - alpha_fast) * fast_ema;
      slow_ema = alpha_slow * closes[i] + (1.0 - alpha_slow) * slow_ema;
     }

   if(closes[0] <= 0.0)
      return false;

   const double normalized_diff = (fast_ema - slow_ema) / (closes[0] * sigma);
   out_forecast = Strategy_ForecastScalar(fast_period, slow_period) *
                  strategy_forecast_multiplier *
                  normalized_diff;
   return true;
  }

bool Strategy_CurrentForecast(const int signal_shift, double &out_forecast)
  {
   out_forecast = 0.0;

   if(strategy_vol_lookback < 2 || strategy_forecast_multiplier <= 0.0 ||
      strategy_forecast_cap <= 0.0)
      return false;

   const int max_slow = MathMax(strategy_slow_period_1,
                                MathMax(strategy_slow_period_2, strategy_slow_period_3));
   const int bars_needed = max_slow + strategy_vol_lookback + 40;

   double closes[];
   ArraySetAsSeries(closes, true);
   const int copied = CopyClose(_Symbol, strategy_tf, signal_shift, bars_needed + 1, closes); // perf-allowed: bounded D1 EWMAC/realized-vol sample, called only after the framework QM_IsNewBar gate.
   if(copied < bars_needed)
      return false;

   double ret_sum = 0.0;
   double ret_sum_sq = 0.0;
   int ret_n = 0;
   for(int i = 0; i < strategy_vol_lookback; ++i)
     {
      if(closes[i] <= 0.0 || closes[i + 1] <= 0.0)
         return false;
      const double ret = (closes[i] / closes[i + 1]) - 1.0;
      ret_sum += ret;
      ret_sum_sq += ret * ret;
      ret_n++;
     }
   if(ret_n < 2)
      return false;

   const double ret_mean = ret_sum / (double)ret_n;
   const double variance = (ret_sum_sq / (double)ret_n) - ret_mean * ret_mean;
   if(variance <= 0.0)
      return false;
   const double sigma = MathSqrt(variance);
   if(sigma <= 0.0)
      return false;

   double forecast_sum = 0.0;
   int forecast_count = 0;

   double f1 = 0.0;
   if(Strategy_EwmacForecastFromCloses(closes, copied,
                                       strategy_fast_period_1,
                                       strategy_slow_period_1,
                                       sigma, f1))
     {
      forecast_sum += f1;
      forecast_count++;
     }

   if(strategy_use_multispeed)
     {
      double f2 = 0.0;
      if(Strategy_EwmacForecastFromCloses(closes, copied,
                                          strategy_fast_period_2,
                                          strategy_slow_period_2,
                                          sigma, f2))
        {
         forecast_sum += f2;
         forecast_count++;
        }

      double f3 = 0.0;
      if(Strategy_EwmacForecastFromCloses(closes, copied,
                                          strategy_fast_period_3,
                                          strategy_slow_period_3,
                                          sigma, f3))
        {
         forecast_sum += f3;
         forecast_count++;
        }
     }

   if(forecast_count <= 0)
      return false;

   const double raw_forecast = forecast_sum / (double)forecast_count;
   const double cap = MathAbs(strategy_forecast_cap);
   out_forecast = Strategy_Clamp(raw_forecast, -cap, cap);
   return true;
  }

bool Strategy_SpreadAllowsEntry()
  {
   if(!strategy_spread_filter)
      return true;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;
   if(ask < bid)
      return false;
   if(ask == bid)
      return true;

   const double atr = QM_ATR(_Symbol, strategy_tf, strategy_atr_period, 1);
   if(atr <= 0.0 || strategy_max_spread_atr_mult <= 0.0)
      return true;
   return ((ask - bid) <= strategy_max_spread_atr_mult * atr);
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   const int expected_slot = Strategy_ExpectedSlot();
   if(expected_slot < 0)
      return true;
   if(qm_magic_slot_offset != expected_slot)
      return true;
   if((ENUM_TIMEFRAMES)_Period != strategy_tf)
      return true;
   if(strategy_fast_period_1 < 2 || strategy_slow_period_1 <= strategy_fast_period_1)
      return true;
   if(strategy_use_multispeed &&
      (strategy_fast_period_2 < 2 || strategy_slow_period_2 <= strategy_fast_period_2 ||
       strategy_fast_period_3 < 2 || strategy_slow_period_3 <= strategy_fast_period_3))
      return true;
   if(strategy_atr_period < 2 || strategy_stop_atr_mult <= 0.0)
      return true;
   if(strategy_entry_forecast < 0.0)
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
   if(!Strategy_CurrentForecast(1, forecast))
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
   req.tp = 0.0;
   req.reason = StringFormat("CARVER_EWMAC forecast=%.4f cap=%.1f", forecast, strategy_forecast_cap);
   return (req.sl > 0.0);
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies protective ATR stop plus forecast sign-flip exit.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   ENUM_POSITION_TYPE ptype;
   if(!Strategy_SelectPosition(ptype))
      return false;

   double forecast = 0.0;
   if(!Strategy_CurrentForecast(1, forecast))
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_12796\",\"ea\":\"carver-vol-trend\"}");
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

   if(!QM_IsNewBar(_Symbol, strategy_tf))
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
