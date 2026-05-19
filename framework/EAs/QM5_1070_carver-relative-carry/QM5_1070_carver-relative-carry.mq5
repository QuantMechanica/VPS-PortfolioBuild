#property strict
#property version   "5.0"
#property description "QM5_1070 Carver Relative Carry Within FX Basket"

#include <QM/QM_Common.mqh>

#define STRATEGY_BASKET_SIZE 9

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                    = 1070;
input int    qm_magic_slot_offset        = 6;

input group "Risk"
input double RISK_PERCENT                = 0.0;
input double RISK_FIXED                  = 1000.0;
input double PORTFOLIO_WEIGHT            = 1.0;

input group "News"
input QM_NewsMode qm_news_mode           = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled     = true;
input int    qm_friday_close_hour_broker = 21;

input group "Strategy"
input double strategy_entry_forecast     = 2.0;
input int    strategy_vol_span_days      = 25;
input int    strategy_atr_period         = 20;
input double strategy_atr_sl_mult        = 2.5;
input int    strategy_min_valid_symbols  = 6;
input int    strategy_max_positions      = 4;
input int    strategy_spread_median_days = 20;
input double strategy_spread_cap_mult    = 2.0;
input int    strategy_rebalance_hour     = 1;

string   g_basket_symbols[STRATEGY_BASKET_SIZE] =
  {
   "AUDJPY.DWX",
   "NZDJPY.DWX",
   "AUDUSD.DWX",
   "NZDUSD.DWX",
   "USDJPY.DWX",
   "GBPJPY.DWX",
   "EURUSD.DWX",
   "GBPUSD.DWX",
   "USDCAD.DWX"
  };

double   g_rel_forecasts[STRATEGY_BASKET_SIZE];
bool     g_valid_forecasts[STRATEGY_BASKET_SIZE];
datetime g_forecast_d1_bar = 0;
int      g_valid_forecast_count = 0;
bool     g_forecast_ready = false;

int BasketIndexForSymbol(const string symbol)
  {
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      if(g_basket_symbols[i] == symbol)
         return i;
     }
   return -1;
  }

int BrokerHour()
  {
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return dt.hour;
  }

double EwmaDailyReturnVol(const string symbol)
  {
   const int span = MathMax(2, strategy_vol_span_days);
   const double alpha = 2.0 / (span + 1.0);
   double variance = 0.0;
   bool have_sample = false;

   for(int shift = span; shift >= 1; --shift)
     {
      const double close_now = iClose(symbol, PERIOD_D1, shift);
      const double close_prev = iClose(symbol, PERIOD_D1, shift + 1);
      if(close_now <= 0.0 || close_prev <= 0.0)
         return 0.0;

      const double r = (close_now / close_prev) - 1.0;
      if(!have_sample)
        {
         variance = r * r;
         have_sample = true;
        }
      else
         variance = alpha * r * r + (1.0 - alpha) * variance;
     }

   if(!have_sample || variance <= 0.0)
      return 0.0;
   return MathSqrt(variance);
  }

double AnnualisedCarryReturn(const string symbol)
  {
   const double swap_long = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   if(swap_long == 0.0 && swap_short == 0.0)
      return 0.0;

   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double close_price = iClose(symbol, PERIOD_D1, 1);
   if(point <= 0.0 || close_price <= 0.0)
      return 0.0;

   const double signed_daily_carry_points = swap_long - swap_short;
   return (signed_daily_carry_points * point * 256.0) / close_price;
  }

bool AbsoluteCarryForecast(const string symbol, double &forecast)
  {
   forecast = 0.0;

   const double ann_carry = AnnualisedCarryReturn(symbol);
   const double daily_vol = EwmaDailyReturnVol(symbol);
   if(ann_carry == 0.0 || daily_vol <= 0.0)
      return false;

   const double ann_vol = daily_vol * MathSqrt(256.0);
   if(ann_vol <= 0.0)
      return false;

   forecast = 30.0 * (ann_carry / ann_vol);
   forecast = MathMax(-20.0, MathMin(20.0, forecast));
   return true;
  }

bool RefreshForecasts()
  {
   const datetime d1_bar = iTime(_Symbol, PERIOD_D1, 0);
   if(d1_bar <= 0)
      return false;
   if(g_forecast_d1_bar == d1_bar)
      return g_forecast_ready;
   if(BrokerHour() < strategy_rebalance_hour)
      return false;

   double abs_forecasts[STRATEGY_BASKET_SIZE];
   double sum = 0.0;
   int valid = 0;

   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      g_valid_forecasts[i] = false;
      g_rel_forecasts[i] = 0.0;
      abs_forecasts[i] = 0.0;

      if(!SymbolSelect(g_basket_symbols[i], true))
         continue;

      double f = 0.0;
      if(!AbsoluteCarryForecast(g_basket_symbols[i], f))
         continue;

      abs_forecasts[i] = f;
      g_valid_forecasts[i] = true;
      sum += f;
      valid++;
     }

   g_forecast_d1_bar = d1_bar;
   g_valid_forecast_count = valid;
   g_forecast_ready = (valid >= strategy_min_valid_symbols);
   if(!g_forecast_ready)
      return false;

   const double mean_forecast = sum / valid;
   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      if(g_valid_forecasts[i])
         g_rel_forecasts[i] = abs_forecasts[i] - mean_forecast;
     }

   return true;
  }

bool CurrentRelativeForecast(double &rel_forecast)
  {
   rel_forecast = 0.0;
   if(!RefreshForecasts())
      return false;

   const int idx = BasketIndexForSymbol(_Symbol);
   if(idx < 0 || !g_valid_forecasts[idx])
      return false;

   rel_forecast = g_rel_forecasts[idx];
   return true;
  }

bool SpreadWithinCap()
  {
   const int days = MathMax(1, strategy_spread_median_days);
   int spreads[];
   ArrayResize(spreads, days);
   int samples = 0;

   for(int shift = 1; shift <= days; ++shift)
     {
      const int spread = (int)iSpread(_Symbol, PERIOD_D1, shift);
      if(spread <= 0)
         continue;
      spreads[samples] = spread;
      samples++;
     }

   if(samples <= 0)
      return false;

   ArrayResize(spreads, samples);
   ArraySort(spreads);

   const double median = (samples % 2 == 1)
      ? (double)spreads[samples / 2]
      : ((double)spreads[(samples / 2) - 1] + (double)spreads[samples / 2]) * 0.5;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

   if(median <= 0.0 || current_spread <= 0)
      return false;
   return ((double)current_spread <= strategy_spread_cap_mult * median);
  }

bool HasCurrentSymbolPosition()
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

int PortfolioPositionCount()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const int magic = (int)PositionGetInteger(POSITION_MAGIC);
      if(magic >= 10700000 && magic <= 10709999)
         count++;
     }
   return count;
  }

bool Strategy_NoTradeFilter()
  {
   // No Trade Filter (time, spread, news): rebalance only after rollover spread normalises.
   if(BasketIndexForSymbol(_Symbol) < 0)
      return true;
   if(BrokerHour() < strategy_rebalance_hour)
      return true;
   return false;
  }

bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   // Trade Entry: closed-D1 relative carry de-mean forecast, threshold entry, ATR emergency stop.
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(HasCurrentSymbolPosition())
      return false;
   if(PortfolioPositionCount() >= strategy_max_positions)
      return false;
   if(!SpreadWithinCap())
      return false;

   double rel_forecast = 0.0;
   if(!CurrentRelativeForecast(rel_forecast))
      return false;

   if(rel_forecast <= strategy_entry_forecast && rel_forecast >= -strategy_entry_forecast)
      return false;

   req.type = (rel_forecast > strategy_entry_forecast) ? QM_BUY : QM_SELL;
   req.price = 0.0;

   const double entry = (req.type == QM_BUY)
      ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
      : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(entry <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, entry, strategy_atr_period, strategy_atr_sl_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (req.type == QM_BUY) ? "REL_CARRY_LONG" : "REL_CARRY_SHORT";
   return true;
  }

void Strategy_ManageOpenPosition()
  {
   // Trade Management: no trailing, break-even, partial-close, or thesis management beyond the hard ATR stop.
   // Card specifies no trailing, break-even, partial-close, or thesis management beyond the hard ATR stop.
  }

bool Strategy_ExitSignal()
  {
   // Trade Close: close longs at relative forecast <= 0 and shorts at relative forecast >= 0.
   double rel_forecast = 0.0;
   if(!CurrentRelativeForecast(rel_forecast))
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
      if(pos_type == POSITION_TYPE_BUY && rel_forecast <= 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && rel_forecast >= 0.0)
         return true;
     }

   return false;
  }

bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // News Filter Hook: central-bank rate decisions and CPI/NFP are delegated to the framework calendar.
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

   QM_LogEvent(QM_INFO, "INIT_OK", "{\"card\":\"QM5_1070\",\"ea\":\"carver-relative-carry\"}");
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
