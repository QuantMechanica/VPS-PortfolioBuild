#property strict
#property version   "5.0"
#property description "QM5_1068 Carver Rolling-Range Breakout Forecast"

#include <QM/QM_Common.mqh>

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                      = 1068;
input int    qm_magic_slot_offset          = 0;

input group "Risk"
input double RISK_PERCENT                  = 0.0;
input double RISK_FIXED                    = 1000.0;
input double PORTFOLIO_WEIGHT              = 1.0;

input group "News"
input QM_NewsMode qm_news_mode             = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled       = true;
input int    qm_friday_close_hour_broker   = 21;

input group "Strategy"
input int    strategy_lookback_d1_bars     = 80;
input double strategy_entry_forecast       = 2.0;
input double strategy_forecast_scalar      = 40.0;
input double strategy_forecast_cap         = 20.0;
input int    strategy_atr_period           = 20;
input double strategy_atr_sl_mult          = 2.5;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_mult          = 2.0;

const int STRATEGY_UNIVERSE_SIZE = 8;
string g_universe_symbols[8] =
  {
   "GDAXI.DWX", "NDX.DWX", "WS30.DWX", "EURUSD.DWX",
   "GBPUSD.DWX", "USDJPY.DWX", "XAUUSD.DWX", "XTIUSD.DWX"
  };

datetime g_forecast_bar_time = 0;
datetime g_last_entry_bar_time = 0;
datetime g_last_exit_bar_time = 0;
double   g_cached_forecast = 0.0;
bool     g_cached_forecast_valid = false;

int Strategy_CurrentSymbolIndex()
  {
   for(int i = 0; i < STRATEGY_UNIVERSE_SIZE; ++i)
      if(g_universe_symbols[i] == _Symbol)
         return i;
   return -1;
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
      if((int)PositionGetInteger(POSITION_MAGIC) != magic)
         continue;
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
      count++;
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

bool Strategy_RefreshForecast()
  {
   const datetime bar_time = iTime(_Symbol, PERIOD_D1, 1);
   if(bar_time <= 0)
      return false;
   if(bar_time == g_forecast_bar_time)
      return g_cached_forecast_valid;

   g_forecast_bar_time = bar_time;
   g_cached_forecast = 0.0;
   g_cached_forecast_valid = false;

   if(strategy_lookback_d1_bars <= 1)
      return false;

   const double close_value = iClose(_Symbol, PERIOD_D1, 1);
   if(close_value <= 0.0)
      return false;

   double roll_max = -DBL_MAX;
   double roll_min = DBL_MAX;
   for(int shift = 1; shift <= strategy_lookback_d1_bars; ++shift)
     {
      const double close_i = iClose(_Symbol, PERIOD_D1, shift);
      if(close_i <= 0.0)
         return false;
      if(close_i > roll_max)
         roll_max = close_i;
      if(close_i < roll_min)
         roll_min = close_i;
     }

   if(roll_max <= roll_min)
      return false;

   const double roll_mean = 0.5 * (roll_max + roll_min);
   double forecast = strategy_forecast_scalar * (close_value - roll_mean) / (roll_max - roll_min);
   const double cap_abs = MathAbs(strategy_forecast_cap);
   if(cap_abs > 0.0)
      forecast = MathMax(-cap_abs, MathMin(cap_abs, forecast));

   g_cached_forecast = forecast;
   g_cached_forecast_valid = true;
   return true;
  }

// No Trade Filter (time, spread, news)
bool Strategy_NoTradeFilter()
  {
   if(Strategy_CurrentSymbolIndex() < 0)
      return true;
   if(strategy_lookback_d1_bars <= 1 || strategy_atr_period <= 0)
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
   req.reason = "QM5_1068_RANGE_BREAKOUT";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(!Strategy_RefreshForecast())
      return false;
   if(g_forecast_bar_time == g_last_entry_bar_time)
      return false;
   g_last_entry_bar_time = g_forecast_bar_time;

   if(Strategy_HasOpenPosition())
      return false;
   if(!Strategy_SpreadAllowsEntry())
      return false;

   const double threshold = MathAbs(strategy_entry_forecast);
   if(threshold <= 0.0)
      return false;

   int direction = 0;
   if(g_cached_forecast > threshold)
      direction = 1;
   else if(g_cached_forecast < -threshold)
      direction = -1;
   else
      return false;

   req.type = (direction > 0) ? QM_BUY : QM_SELL;
   const double entry = (direction > 0) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;
   if(req.type == QM_BUY && req.sl >= entry)
      return false;
   if(req.type == QM_SELL && req.sl <= entry)
      return false;

   req.reason = (direction > 0) ? "QM5_1068_FORECAST_LONG" : "QM5_1068_FORECAST_SHORT";
   return true;
  }

// Trade Management
void Strategy_ManageOpenPosition()
  {
   // Card specifies only the fixed emergency ATR stop; no trailing or partial exits.
  }

// Trade Close
bool Strategy_ExitSignal()
  {
   if(!Strategy_HasOpenPosition())
      return false;
   if(!Strategy_RefreshForecast())
      return false;
   if(g_forecast_bar_time == g_last_exit_bar_time)
      return false;
   g_last_exit_bar_time = g_forecast_bar_time;

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

      const ENUM_POSITION_TYPE ptype = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ptype == POSITION_TYPE_BUY && g_cached_forecast < 0.0)
         return true;
      if(ptype == POSITION_TYPE_SELL && g_cached_forecast > 0.0)
         return true;
     }

   return false;
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
                        qm_news_mode,
                        qm_friday_close_enabled,
                        qm_friday_close_hour_broker))
      return INIT_FAILED;

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1068\",\"ea\":\"carver-breakout-range\"}");
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
   if(!QM_NewsAllowsTrade(_Symbol, broker_now, qm_news_mode))
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

double OnTester()
  {
   QM_ChartUI_Refresh();
   return QM_DefaultObjective();
  }
