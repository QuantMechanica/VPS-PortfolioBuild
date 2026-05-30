#property strict
#property version   "5.0"
#property description "QM5_1220 Carver Mean Reversion In The Wings"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1220;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.1429;

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
input int    strategy_lfast_d1           = 4;
input int    strategy_lslow_mult         = 4;
input int    strategy_change_std_days    = 25;
input int    strategy_wing_std_lookback  = 5000;
input double strategy_wing_sigma         = 3.0;
input double strategy_exit_sigma         = 2.0;
input double strategy_forecast_scalar    = 1.0;
input double strategy_entry_forecast     = 2.0;
input int    strategy_atr_period_d1      = 20;
input double strategy_atr_sl_mult        = 3.0;
input int    strategy_spread_median_days = 20;
input double strategy_spread_mult        = 2.0;

#define QM5_1220_SYMBOL_COUNT 7
#define QM5_1220_MAX_SPREAD_DAYS 64

string g_symbols[QM5_1220_SYMBOL_COUNT] =
  {
   "GER40.DWX", "NDX.DWX", "WS30.DWX",
   "EURUSD.DWX", "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX"
  };

int g_last_entry_key = 0;
int g_last_exit_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1220_SYMBOL_COUNT; ++i)
      if(g_symbols[i] == _Symbol)
         return i;
   return -1;
  }

int Strategy_DayKey(const datetime value)
  {
   if(value <= 0)
      return 0;
   MqlDateTime dt;
   TimeToStruct(value, dt);
   return dt.year * 10000 + dt.mon * 100 + dt.day;
  }

bool Strategy_SelectSymbols()
  {
   bool ok = true;
   for(int i = 0; i < QM5_1220_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

bool Strategy_HasOpenPosition(ulong &ticket, int &direction)
  {
   ticket = 0;
   direction = 0;
   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong pos_ticket = PositionGetTicket(i);
      if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
      ticket = pos_ticket;
      direction = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      return true;
     }
   return false;
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

int Strategy_Lslow()
  {
   return MathMax(strategy_lfast_d1 + 1, strategy_lfast_d1 * MathMax(strategy_lslow_mult, 2));
  }

double Strategy_EMAOnClose(const int period, const int shift)
  {
   if(period <= 0 || shift < 0)
      return 0.0;
   if(Bars(_Symbol, PERIOD_D1) <= shift + period + 2)
      return 0.0;

   const double alpha = 2.0 / ((double)period + 1.0);
   double ema = iClose(_Symbol, PERIOD_D1, shift + period - 1);
   if(ema <= 0.0)
      return 0.0;

   for(int i = shift + period - 2; i >= shift; --i)
     {
      const double close = iClose(_Symbol, PERIOD_D1, i);
      if(close <= 0.0)
         return 0.0;
      ema = alpha * close + (1.0 - alpha) * ema;
     }
   return ema;
  }

double Strategy_StdDevCloseChanges(const int shift, const int period)
  {
   if(period <= 1)
      return 0.0;
   double vals[128];
   int count = 0;
   const int max_period = MathMin(period, 128);
   for(int i = shift; i < shift + max_period; ++i)
     {
      const double c0 = iClose(_Symbol, PERIOD_D1, i);
      const double c1 = iClose(_Symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      vals[count] = c0 - c1;
      ++count;
     }

   double mean = 0.0;
   for(int i = 0; i < count; ++i)
      mean += vals[i];
   mean /= (double)count;

   double var = 0.0;
   for(int i = 0; i < count; ++i)
      var += (vals[i] - mean) * (vals[i] - mean);
   var /= (double)MathMax(count - 1, 1);
   return MathSqrt(var);
  }

double Strategy_Ewmac(const int shift)
  {
   const int lslow = Strategy_Lslow();
   const double fast = Strategy_EMAOnClose(strategy_lfast_d1, shift);
   const double slow = Strategy_EMAOnClose(lslow, shift);
   const double sd = Strategy_StdDevCloseChanges(shift, strategy_change_std_days);
   if(fast <= 0.0 || slow <= 0.0 || sd <= 0.0)
      return 0.0;
   return (fast - slow) / sd;
  }

double Strategy_WingStdDev(const int shift)
  {
   const int lookback = MathMax(strategy_wing_std_lookback, 50);
   double sum = 0.0;
   double sum2 = 0.0;
   int count = 0;

   for(int i = shift; i < shift + lookback; ++i)
     {
      const double value = Strategy_Ewmac(i);
      sum += value;
      sum2 += value * value;
      ++count;
     }

   if(count <= 1)
      return 0.0;
   const double mean = sum / (double)count;
   const double var = MathMax((sum2 / (double)count) - mean * mean, 0.0);
   return MathSqrt(var);
  }

bool Strategy_Forecast(const int shift, double &forecast, double &ewmac, double &wing_std)
  {
   forecast = 0.0;
   ewmac = Strategy_Ewmac(shift);
   wing_std = Strategy_WingStdDev(shift);
   if(wing_std <= 0.0)
      return false;

   if(MathAbs(ewmac) < strategy_wing_sigma * wing_std)
      return true;

   const double raw_signal = -ewmac;
   forecast = MathMax(-20.0, MathMin(20.0, strategy_forecast_scalar * raw_signal));
   return true;
  }

double Strategy_MedianDailySpreadPoints()
  {
   if(strategy_spread_median_days <= 0 || strategy_spread_median_days > QM5_1220_MAX_SPREAD_DAYS)
      return 0.0;
   double values[QM5_1220_MAX_SPREAD_DAYS];
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
   return Strategy_Median(values, count);
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

bool Strategy_StopDistanceAllowed(const ENUM_ORDER_TYPE type, const double entry, const double sl)
  {
   if(entry <= 0.0 || sl <= 0.0)
      return false;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const long stops = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(point <= 0.0 || stops <= 0)
      return true;
   const double min_dist = (double)stops * point;
   if(type == ORDER_TYPE_BUY)
      return (entry - sl >= min_dist);
   return (sl - entry >= min_dist);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 1220)
      return true;
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(qm_magic_slot_offset != index)
      return true;
   if(strategy_lfast_d1 < 2 || Strategy_Lslow() <= strategy_lfast_d1)
      return true;
   if(strategy_change_std_days < 5 || strategy_wing_std_lookback < 50)
      return true;
   if(strategy_wing_sigma <= 0.0 || strategy_exit_sigma <= 0.0 || strategy_forecast_scalar <= 0.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   const int required = strategy_wing_std_lookback + Strategy_Lslow() + strategy_change_std_days + 10;
   if(Bars(_Symbol, PERIOD_D1) < required)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1220_CARVER_MRWINGS";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int key = Strategy_DayKey(iTime(_Symbol, PERIOD_D1, 1));
   if(key <= 0 || key == g_last_entry_key)
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   ulong ticket = 0;
   int open_direction = 0;
   if(Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   double forecast = 0.0;
   double ewmac = 0.0;
   double wing_std = 0.0;
   if(!Strategy_Forecast(1, forecast, ewmac, wing_std))
      return false;

   int direction = 0;
   if(forecast > strategy_entry_forecast)
      direction = 1;
   else if(forecast < -strategy_entry_forecast)
      direction = -1;
   if(direction == 0)
      return false;

   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   req.price = entry;
   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period_d1, strategy_atr_sl_mult);
   req.symbol_slot = qm_magic_slot_offset;
   if(!Strategy_StopDistanceAllowed((direction > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL), entry, req.sl))
      return false;

   g_last_entry_key = key;
   QM_LogEvent(QM_INFO, "CARVER_MRWINGS_SIGNAL_ON",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"forecast\":%.4f,\"ewmac\":%.4f,\"wing_std\":%.4f,\"direction\":%d}",
                            _Symbol, req.symbol_slot, forecast, ewmac, wing_std, direction));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
  }

bool Strategy_ExitSignal()
  {
   ulong ticket = 0;
   int open_direction = 0;
   if(!Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   const int key = Strategy_DayKey(iTime(_Symbol, PERIOD_D1, 1));
   if(key <= 0 || key == g_last_exit_key)
      return false;

   double forecast = 0.0;
   double ewmac = 0.0;
   double wing_std = 0.0;
   if(!Strategy_Forecast(1, forecast, ewmac, wing_std))
      return false;

   const bool neutral_wing = (MathAbs(ewmac) < strategy_exit_sigma * wing_std);
   const bool long_exit = (open_direction > 0 && (forecast <= 0.0 || neutral_wing));
   const bool short_exit = (open_direction < 0 && (forecast >= 0.0 || neutral_wing));
   if(long_exit || short_exit)
     {
      g_last_exit_key = key;
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
   Strategy_SelectSymbols();

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

   QM_SymbolGuardInit(g_symbols);
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_wing_std_lookback + Strategy_Lslow() + strategy_change_std_days + 10);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1220\",\"strategy\":\"carver-mrwings\"}");
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
         const ulong pos_ticket = PositionGetTicket(i);
         if(pos_ticket == 0 || !PositionSelectByTicket(pos_ticket))
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if((int)PositionGetInteger(POSITION_MAGIC) != magic)
            continue;
         QM_TM_ClosePosition(pos_ticket, QM_EXIT_STRATEGY);
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

