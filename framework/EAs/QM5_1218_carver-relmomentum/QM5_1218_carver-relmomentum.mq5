#property strict
#property version   "5.0"
#property description "QM5_1218 Carver Relative Momentum Within Asset Class"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1218;
input int    qm_magic_slot_offset        = 0;
input uint   qm_rng_seed                 = 42;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 0.1111;

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
input int    strategy_horizon_d1          = 40;
input int    strategy_ema_span            = 10;
input int    strategy_norm_stddev_days    = 25;
input double strategy_forecast_scalar     = 10.0;
input double strategy_entry_forecast      = 2.0;
input int    strategy_max_slots_per_group = 2;
input int    strategy_atr_period_d1       = 20;
input double strategy_atr_sl_mult         = 2.5;
input double strategy_break_atr_mult      = 3.5;
input int    strategy_break_block_bars    = 20;
input int    strategy_spread_median_days  = 20;
input double strategy_spread_mult         = 2.0;

#define QM5_1218_SYMBOL_COUNT 11
#define QM5_1218_MAX_GROUP    6
#define QM5_1218_MAX_SPAN     128
#define QM5_1218_BLOCK_COUNT  11

string g_symbols[QM5_1218_SYMBOL_COUNT] =
  {
   "GER40.DWX", "NDX.DWX", "WS30.DWX", "UK100.DWX", "FRA40.DWX",
   "EURUSD.DWX", "GBPUSD.DWX", "AUDUSD.DWX", "USDJPY.DWX", "USDCHF.DWX", "USDCAD.DWX"
  };

int g_groups[QM5_1218_SYMBOL_COUNT] =
  {
   0, 0, 0, 0, 0,
   1, 1, 1, 1, 1, 1
  };

int g_block_until_bar[QM5_1218_BLOCK_COUNT];
int g_last_entry_key = 0;
int g_last_exit_key  = 0;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < QM5_1218_SYMBOL_COUNT; ++i)
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
   for(int i = 0; i < QM5_1218_SYMBOL_COUNT; ++i)
      ok = (SymbolSelect(g_symbols[i], true) && ok);
   return ok;
  }

int Strategy_GroupMembers(const int group_id, string &members[])
  {
   int count = 0;
   for(int i = 0; i < QM5_1218_SYMBOL_COUNT; ++i)
     {
      if(g_groups[i] != group_id)
         continue;
      members[count] = g_symbols[i];
      ++count;
     }
   return count;
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

double Strategy_StdDevReturns(const string symbol, const int shift, const int period)
  {
   if(period <= 1)
      return 0.0;
   double vals[128];
   int count = 0;
   const int max_period = MathMin(period, 128);
   for(int i = shift; i < shift + max_period; ++i)
     {
      const double c0 = iClose(symbol, PERIOD_D1, i);
      const double c1 = iClose(symbol, PERIOD_D1, i + 1);
      if(c0 <= 0.0 || c1 <= 0.0)
         return 0.0;
      vals[count] = (c0 - c1) / c1;
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

double Strategy_NormalizedReturn(const string symbol, const int shift)
  {
   const double c0 = iClose(symbol, PERIOD_D1, shift);
   const double c1 = iClose(symbol, PERIOD_D1, shift + 1);
   const double sd = Strategy_StdDevReturns(symbol, shift, strategy_norm_stddev_days);
   if(c0 <= 0.0 || c1 <= 0.0 || sd <= 0.0)
      return 0.0;
   const double raw = ((c0 - c1) / c1) / sd;
   return MathMax(-6.0, MathMin(6.0, raw));
  }

double Strategy_NormalizedMove(const string symbol, const int shift)
  {
   double sum = 0.0;
   for(int i = shift; i < shift + strategy_horizon_d1; ++i)
      sum += Strategy_NormalizedReturn(symbol, i);
   return sum;
  }

bool Strategy_GroupDValues(const int group_id, const int shift, string &members[], const int member_count, double &d_values[])
  {
   if(member_count < 4)
      return false;
   double out_now[QM5_1218_MAX_GROUP];
   double out_old[QM5_1218_MAX_GROUP];
   double sum_now = 0.0;
   double sum_old = 0.0;
   for(int i = 0; i < member_count; ++i)
     {
      if(Bars(members[i], PERIOD_D1) < (strategy_horizon_d1 * 2) + strategy_ema_span + strategy_norm_stddev_days + 10)
         return false;
      out_now[i] = Strategy_NormalizedMove(members[i], shift);
      out_old[i] = Strategy_NormalizedMove(members[i], shift + strategy_horizon_d1);
      sum_now += out_now[i];
      sum_old += out_old[i];
     }
   const double group_now = sum_now / (double)member_count;
   const double group_old = sum_old / (double)member_count;
   for(int i = 0; i < member_count; ++i)
      d_values[i] = ((out_now[i] - group_now) - (out_old[i] - group_old)) / (double)MathMax(strategy_horizon_d1, 1);
   return true;
  }

bool Strategy_ForecastsForGroup(const int group_id, string &members[], int &member_count, double &forecasts[])
  {
   member_count = Strategy_GroupMembers(group_id, members);
   if(member_count < 4)
      return false;

   const int span = MathMax(2, MathMin(strategy_ema_span, QM5_1218_MAX_SPAN));
   const double alpha = 2.0 / ((double)span + 1.0);

   double ema[QM5_1218_MAX_GROUP];
   for(int i = 0; i < member_count; ++i)
      ema[i] = 0.0;

   bool seeded = false;
   for(int shift = span; shift >= 1; --shift)
     {
      double d_values[QM5_1218_MAX_GROUP];
      if(!Strategy_GroupDValues(group_id, shift, members, member_count, d_values))
         return false;
      for(int i = 0; i < member_count; ++i)
        {
         if(!seeded)
            ema[i] = d_values[i];
         else
            ema[i] = alpha * d_values[i] + (1.0 - alpha) * ema[i];
        }
      seeded = true;
     }

   double raw[QM5_1218_MAX_GROUP];
   double abs_sum = 0.0;
   int abs_count = 0;
   for(int i = 0; i < member_count; ++i)
     {
      raw[i] = ema[i] * strategy_forecast_scalar;
      abs_sum += MathAbs(raw[i]);
      ++abs_count;
     }
   const double scale = (abs_count > 0) ? MathMax(abs_sum / (double)abs_count, 1.0) : 1.0;
   for(int i = 0; i < member_count; ++i)
      forecasts[i] = MathMax(-20.0, MathMin(20.0, raw[i] / scale * strategy_forecast_scalar));
   return true;
  }

bool Strategy_IsAllowedSlot(const string symbol, string &members[], const int member_count, double &forecasts[], const int direction)
  {
   int own = -1;
   for(int i = 0; i < member_count; ++i)
      if(members[i] == symbol)
         own = i;
   if(own < 0)
      return false;

   int rank = 1;
   for(int i = 0; i < member_count; ++i)
     {
      if(i == own)
         continue;
      if(direction > 0 && forecasts[i] > forecasts[own])
         ++rank;
      if(direction < 0 && forecasts[i] < forecasts[own])
         ++rank;
     }
   return (rank <= MathMax(1, strategy_max_slots_per_group));
  }

int Strategy_CurrentForecast(double &forecast)
  {
   forecast = 0.0;
   const int current_index = Strategy_CurrentSymbolIndex();
   if(current_index < 0)
      return 0;

   string members[QM5_1218_MAX_GROUP];
   double forecasts[QM5_1218_MAX_GROUP];
   int member_count = 0;
   if(!Strategy_ForecastsForGroup(g_groups[current_index], members, member_count, forecasts))
      return 0;

   for(int i = 0; i < member_count; ++i)
      if(members[i] == _Symbol)
         forecast = forecasts[i];

   if(forecast > strategy_entry_forecast)
     {
      if(Strategy_IsAllowedSlot(_Symbol, members, member_count, forecasts, 1))
         return 1;
     }
   if(forecast < -strategy_entry_forecast)
     {
      if(Strategy_IsAllowedSlot(_Symbol, members, member_count, forecasts, -1))
         return -1;
     }
   return 0;
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

void Strategy_UpdateStructuralBreak()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0 || idx >= QM5_1218_BLOCK_COUNT)
      return;

   ulong ticket = 0;
   int direction = 0;
   if(!Strategy_HasOpenPosition(ticket, direction))
      return;

   const double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
   const double close_price = iClose(_Symbol, PERIOD_D1, 1);
   const double atr = QM_ATR(_Symbol, PERIOD_D1, strategy_atr_period_d1, 1);
   if(open_price <= 0.0 || close_price <= 0.0 || atr <= 0.0)
      return;

   const double adverse = (direction > 0) ? (open_price - close_price) : (close_price - open_price);
   if(adverse > strategy_break_atr_mult * atr)
     {
      g_block_until_bar[idx] = Bars(_Symbol, PERIOD_D1) + MathMax(strategy_break_block_bars, 1);
      QM_TM_ClosePosition(ticket, QM_EXIT_STRATEGY);
     }
  }

bool Strategy_StructuralBlockActive()
  {
   const int idx = Strategy_CurrentSymbolIndex();
   if(idx < 0 || idx >= QM5_1218_BLOCK_COUNT)
      return true;
   return (Bars(_Symbol, PERIOD_D1) < g_block_until_bar[idx]);
  }

bool Strategy_NoTradeFilter()
  {
   if(_Period != PERIOD_D1)
      return true;
   if(qm_ea_id != 1218)
      return true;
   const int index = Strategy_CurrentSymbolIndex();
   if(index < 0)
      return true;
   if(qm_magic_slot_offset != index)
      return true;
   if(strategy_horizon_d1 < 10 || strategy_ema_span < 2 || strategy_norm_stddev_days < 5 || strategy_forecast_scalar <= 0.0)
      return true;
   if(strategy_atr_period_d1 <= 0 || strategy_atr_sl_mult <= 0.0)
      return true;
   return !Strategy_SelectSymbols();
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "QM5_1218_CARVER_RELMOMENTUM";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   const int key = Strategy_DayKey(iTime(_Symbol, PERIOD_D1, 1));
   if(key <= 0 || key == g_last_entry_key)
      return false;
   if(Strategy_StructuralBlockActive())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   ulong ticket = 0;
   int open_direction = 0;
   if(Strategy_HasOpenPosition(ticket, open_direction))
      return false;

   double forecast = 0.0;
   const int direction = Strategy_CurrentForecast(forecast);
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
   QM_LogEvent(QM_INFO, "CARVER_RELMOMENTUM_SIGNAL_ON",
               StringFormat("{\"symbol\":\"%s\",\"slot\":%d,\"forecast\":%.4f,\"direction\":%d}",
                            _Symbol, req.symbol_slot, forecast, direction));
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   Strategy_UpdateStructuralBreak();
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
   Strategy_CurrentForecast(forecast);
   if((open_direction > 0 && forecast < 0.0) || (open_direction < 0 && forecast > 0.0))
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
   ArrayInitialize(g_block_until_bar, 0);
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
   QM_BasketWarmupHistory(g_symbols, PERIOD_D1, strategy_horizon_d1 + strategy_ema_span + strategy_norm_stddev_days + 20);
   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1218\",\"strategy\":\"carver-relmomentum\"}");
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

