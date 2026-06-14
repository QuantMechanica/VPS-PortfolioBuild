#property strict
#property version   "5.0"
#property description "QM5_1070 Carver Relative Carry Within FX Basket"

#include <QM/QM_Common.mqh>

#define STRATEGY_BASKET_SIZE 9

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1070;
input int    qm_magic_slot_offset       = 0;
input uint   qm_rng_seed                = 42;

input group "Risk"
input double RISK_PERCENT               = 0.0;
input double RISK_FIXED                 = 1000.0;
input double PORTFOLIO_WEIGHT           = 1.0;

input group "News"
input QM_NewsTemporalMode      qm_news_temporal   = QM_NEWS_TEMPORAL_PRE30_POST30;
input QM_NewsComplianceProfile qm_news_compliance = QM_NEWS_COMPLIANCE_DXZ;
input int    qm_news_stale_max_hours      = 336;
input string qm_news_min_impact           = "high";
input QM_NewsMode qm_news_mode_legacy     = QM_NEWS_OFF;

input group "Friday Close"
input bool   qm_friday_close_enabled    = true;
input int    qm_friday_close_hour_broker = 21;

input group "Stress"
input double qm_stress_reject_probability = 0.0;

input group "Strategy"
input double strategy_entry_forecast       = 2.0;
input int    strategy_vol_span_days        = 25;
input int    strategy_atr_period           = 20;
input double strategy_atr_stop_mult        = 2.5;
input int    strategy_min_valid_symbols    = 6;
input int    strategy_max_positions        = 4;
input int    strategy_spread_median_days   = 20;
input double strategy_spread_cap_mult      = 2.0;
input double strategy_forecast_scalar      = 30.0;
input double strategy_forecast_cap         = 20.0;
input double strategy_swap_days_per_year   = 256.0;
input int    strategy_rebalance_hour       = 1;

string g_basket_symbols[STRATEGY_BASKET_SIZE] =
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

double g_current_rel_forecast = 0.0;
bool   g_current_rel_forecast_valid = false;

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

bool CopyDailyWindow(const string symbol, const int bars_needed, MqlRates &rates[])
  {
   if(!SymbolSelect(symbol, true))
      return false;

   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: bounded D1 carry/spread window; called only after framework QM_IsNewBar().
   return (copied >= bars_needed);
  }

bool AbsoluteCarryForecast(const string symbol, double &forecast)
  {
   forecast = 0.0;

   const int vol_span = MathMax(2, strategy_vol_span_days);
   const int bars_needed = vol_span + 1;
   MqlRates rates[];
   if(!CopyDailyWindow(symbol, bars_needed, rates))
      return false;

   const double close_1 = rates[0].close;
   if(close_1 <= 0.0)
      return false;

   double ewma_var = 0.0;
   bool initialized = false;
   const double alpha = 2.0 / ((double)vol_span + 1.0);
   for(int i = vol_span; i >= 1; --i)
     {
      if(rates[i].close <= 0.0 || rates[i - 1].close <= 0.0)
         return false;

      const double ret = (rates[i - 1].close / rates[i].close) - 1.0;
      if(!initialized)
        {
         ewma_var = ret * ret;
         initialized = true;
        }
      else
         ewma_var = alpha * ret * ret + (1.0 - alpha) * ewma_var;
     }

   const double annualised_vol = MathSqrt(MathMax(0.0, ewma_var)) * MathSqrt(strategy_swap_days_per_year);
   const double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   const double swap_long = SymbolInfoDouble(symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(symbol, SYMBOL_SWAP_SHORT);
   if(point <= 0.0 || annualised_vol <= 0.0 || (swap_long == 0.0 && swap_short == 0.0))
      return false;

   const double annualised_carry = ((swap_long - swap_short) * point * strategy_swap_days_per_year) / close_1;
   forecast = strategy_forecast_scalar * (annualised_carry / annualised_vol);
   forecast = MathMin(strategy_forecast_cap, MathMax(-strategy_forecast_cap, forecast));
   return true;
  }

bool CurrentSpreadWithinCap()
  {
   const int days = MathMax(1, strategy_spread_median_days);
   MqlRates rates[];
   if(!CopyDailyWindow(_Symbol, days, rates))
      return false;

   int spreads[];
   ArrayResize(spreads, days);
   int count = 0;
   for(int i = 0; i < days; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[count] = rates[i].spread;
         count++;
        }
     }

   if(count <= 0)
      return false;

   ArrayResize(spreads, count);
   ArraySort(spreads);
   const double median_spread = (count % 2 == 1)
                                ? (double)spreads[count / 2]
                                : ((double)spreads[(count / 2) - 1] + (double)spreads[count / 2]) / 2.0;
   const long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread <= 0)
      return false;

   return ((double)current_spread <= strategy_spread_cap_mult * median_spread);
  }

bool RefreshCurrentRelativeForecast()
  {
   g_current_rel_forecast = 0.0;
   g_current_rel_forecast_valid = false;

   const int current_idx = BasketIndexForSymbol(_Symbol);
   if(current_idx < 0)
      return false;

   double abs_forecasts[STRATEGY_BASKET_SIZE];
   bool valid[STRATEGY_BASKET_SIZE];
   double sum = 0.0;
   int valid_count = 0;

   for(int i = 0; i < STRATEGY_BASKET_SIZE; ++i)
     {
      abs_forecasts[i] = 0.0;
      valid[i] = false;

      double forecast = 0.0;
      if(!AbsoluteCarryForecast(g_basket_symbols[i], forecast))
         continue;

      abs_forecasts[i] = forecast;
      valid[i] = true;
      sum += forecast;
      valid_count++;
     }

   if(valid_count < strategy_min_valid_symbols || !valid[current_idx])
      return false;

   const double mean_forecast = sum / (double)valid_count;
   g_current_rel_forecast = abs_forecasts[current_idx] - mean_forecast;
   g_current_rel_forecast_valid = true;
   return true;
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
      for(int slot = 0; slot < STRATEGY_BASKET_SIZE; ++slot)
        {
         if(magic == QM_Magic(qm_ea_id, slot))
           {
            count++;
            break;
           }
        }
     }
   return count;
  }

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter (time, spread, news).
bool Strategy_NoTradeFilter()
  {
   if(BasketIndexForSymbol(_Symbol) < 0)
      return true;
   if(BrokerHour() < strategy_rebalance_hour)
      return true;
   return false;
  }

// Trade Entry.
bool Strategy_EntrySignal(QM_EntryRequest &req)
  {
   req.type = QM_BUY;
   req.price = 0.0;
   req.sl = 0.0;
   req.tp = 0.0;
   req.reason = "";
   req.symbol_slot = qm_magic_slot_offset;
   req.expiration_seconds = 0;

   if(strategy_entry_forecast <= 0.0 ||
      strategy_vol_span_days < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_min_valid_symbols < 1 ||
      strategy_max_positions < 1 ||
      strategy_spread_median_days < 1 ||
      strategy_spread_cap_mult <= 0.0 ||
      strategy_forecast_scalar <= 0.0 ||
      strategy_forecast_cap <= 0.0 ||
      strategy_swap_days_per_year <= 0.0)
      return false;

   if(!RefreshCurrentRelativeForecast())
      return false;

   if(HasCurrentSymbolPosition())
      return false;
   if(PortfolioPositionCount() >= strategy_max_positions)
      return false;
   if(!CurrentSpreadWithinCap())
      return false;

   if(g_current_rel_forecast <= strategy_entry_forecast &&
      g_current_rel_forecast >= -strategy_entry_forecast)
      return false;

   req.type = (g_current_rel_forecast > strategy_entry_forecast) ? QM_BUY : QM_SELL;
   req.price = (req.type == QM_BUY)
               ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
               : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(req.price <= 0.0)
      return false;

   req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_stop_mult);
   if(req.sl <= 0.0)
      return false;

   req.reason = (req.type == QM_BUY) ? "CARVER_REL_CARRY_LONG" : "CARVER_REL_CARRY_SHORT";
   return true;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // The card specifies a hard 2.5 ATR emergency stop and no trailing,
   // break-even, partial-close, or thesis management beyond the zero-cross exit.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_current_rel_forecast_valid)
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
      if(pos_type == POSITION_TYPE_BUY && g_current_rel_forecast <= 0.0)
         return true;
      if(pos_type == POSITION_TYPE_SELL && g_current_rel_forecast >= 0.0)
         return true;
     }

   return false;
  }

// News Filter Hook.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   return false;
  }

// -----------------------------------------------------------------------------
// Framework wiring - do NOT edit below this line unless you know why.
// -----------------------------------------------------------------------------

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

   QM_LogEvent(QM_INFO, "INIT_OK", "{}");
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
         if(!PositionSelectByTicket(ticket))
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != magic)
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
