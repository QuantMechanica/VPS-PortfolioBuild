#property strict
#property version   "5.0"
#property description "QM5_1067 Carver Vol-Normalised FX Carry"

#include <QM/QM_Common.mqh>

// =============================================================================
// QuantMechanica V5 EA SKELETON
// -----------------------------------------------------------------------------
// Fill in only the five Strategy_* hooks below. Everything else is framework
// boilerplate that MUST stay intact (OnInit/OnTick wiring, framework lifecycle,
// risk + magic + news + Friday-close guard rails).
// =============================================================================

input group "QuantMechanica V5 Framework"
input int    qm_ea_id                   = 1067;
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
input double strategy_forecast_scalar      = 30.0;
input double strategy_forecast_cap         = 20.0;
input int    strategy_spread_median_days   = 20;
input double strategy_swap_days_per_year   = 256.0;

double g_long_forecast = 0.0;
double g_short_forecast = 0.0;
bool   g_forecast_valid = false;

// -----------------------------------------------------------------------------
// Strategy hooks - implement these against the card mechanically.
// -----------------------------------------------------------------------------

// No Trade Filter: time, spread, news.
bool Strategy_NoTradeFilter()
  {
   // Time/news gates are handled by the V5 framework; spread is checked inside
   // the D1 entry hook after the 20-day median spread window is refreshed.
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

   g_forecast_valid = false;
   g_long_forecast = 0.0;
   g_short_forecast = 0.0;

   if(strategy_entry_forecast <= 0.0 ||
      strategy_vol_span_days < 2 ||
      strategy_atr_period < 1 ||
      strategy_atr_stop_mult <= 0.0 ||
      strategy_forecast_scalar <= 0.0 ||
      strategy_forecast_cap <= 0.0 ||
      strategy_spread_median_days < 1 ||
      strategy_swap_days_per_year <= 0.0)
      return false;

   const int bars_needed = MathMax(strategy_vol_span_days + 1, strategy_spread_median_days);
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   const int copied = CopyRates(_Symbol, PERIOD_D1, 1, bars_needed, rates); // perf-allowed: bounded D1 carry/spread window; called only after framework QM_IsNewBar().
   if(copied < bars_needed)
      return false;

   int spreads[];
   ArrayResize(spreads, strategy_spread_median_days);
   int spread_count = 0;
   for(int i = 0; i < strategy_spread_median_days; ++i)
     {
      if(rates[i].spread > 0)
        {
         spreads[spread_count] = rates[i].spread;
         spread_count++;
        }
     }
   if(spread_count <= 0)
      return false;

   ArrayResize(spreads, spread_count);
   ArraySort(spreads);
   const double median_spread = (spread_count % 2 == 1)
                                ? (double)spreads[spread_count / 2]
                                : ((double)spreads[(spread_count / 2) - 1] + (double)spreads[spread_count / 2]) / 2.0;
   const double current_spread = (double)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(median_spread <= 0.0 || current_spread > 2.0 * median_spread)
      return false;

   double ewma_mean = 0.0;
   double ewma_var = 0.0;
   bool initialized = false;
   const double alpha = 2.0 / ((double)strategy_vol_span_days + 1.0);

   for(int i = strategy_vol_span_days; i >= 1; --i)
     {
      const double ret = rates[i - 1].close - rates[i].close;
      if(!initialized)
        {
         ewma_mean = ret;
         ewma_var = 0.0;
         initialized = true;
         continue;
        }

      const double prev_mean = ewma_mean;
      ewma_mean = alpha * ret + (1.0 - alpha) * ewma_mean;
      const double diff = ret - prev_mean;
      ewma_var = (1.0 - alpha) * (ewma_var + alpha * diff * diff);
     }

   const double close_1 = rates[0].close;
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double daily_vol = MathSqrt(MathMax(0.0, ewma_var));
   const double ann_vol_return = (daily_vol / close_1) * MathSqrt(strategy_swap_days_per_year);
   if(close_1 <= 0.0 || point <= 0.0 || ann_vol_return <= 0.0)
      return false;

   const double swap_long = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_LONG);
   const double swap_short = SymbolInfoDouble(_Symbol, SYMBOL_SWAP_SHORT);
   if(swap_long == 0.0 && swap_short == 0.0)
      return false;

   if(swap_long > 0.0)
     {
      const double annualised_long = (swap_long * point * strategy_swap_days_per_year) / close_1;
      g_long_forecast = strategy_forecast_scalar * (annualised_long / ann_vol_return);
      g_long_forecast = MathMin(strategy_forecast_cap, MathMax(-strategy_forecast_cap, g_long_forecast));
     }
   else
      g_long_forecast = -0.0001;

   if(swap_short > 0.0)
     {
      const double annualised_short = (swap_short * point * strategy_swap_days_per_year) / close_1;
      g_short_forecast = -strategy_forecast_scalar * (annualised_short / ann_vol_return);
      g_short_forecast = MathMin(strategy_forecast_cap, MathMax(-strategy_forecast_cap, g_short_forecast));
     }
   else
      g_short_forecast = 0.0001;

   g_forecast_valid = true;

   const int magic = QM_FrameworkMagic();
   for(int i = PositionsTotal() - 1; i >= 0; --i)
     {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if((int)PositionGetInteger(POSITION_MAGIC) == magic)
         return false;
     }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return false;

   if(g_long_forecast > strategy_entry_forecast &&
      MathAbs(g_long_forecast) >= MathAbs(g_short_forecast))
     {
      req.type = QM_BUY;
      req.price = ask;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_stop_mult);
      req.reason = "CARVER_CARRY_LONG";
      return (req.sl > 0.0 && req.sl < req.price);
     }

   if(g_short_forecast < -strategy_entry_forecast)
     {
      req.type = QM_SELL;
      req.price = bid;
      req.sl = QM_StopATR(_Symbol, req.type, req.price, strategy_atr_period, strategy_atr_stop_mult);
      req.reason = "CARVER_CARRY_SHORT";
      return (req.sl > req.price);
     }

   return false;
  }

// Trade Management.
void Strategy_ManageOpenPosition()
  {
   // Carry is managed by the emergency ATR stop and forecast-sign exits.
  }

// Trade Close.
bool Strategy_ExitSignal()
  {
   if(!g_forecast_valid)
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

      const ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(type == POSITION_TYPE_BUY && (g_long_forecast < 0.0 || g_short_forecast < -strategy_entry_forecast))
         return true;
      if(type == POSITION_TYPE_SELL && (g_short_forecast > 0.0 || g_long_forecast > strategy_entry_forecast))
         return true;
     }

   return false;
  }

// News Filter Hook.
bool Strategy_NewsFilterHook(const datetime broker_time)
  {
   // Central-bank rate decision handling is delegated to the framework calendar.
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
